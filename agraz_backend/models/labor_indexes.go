package models

import (
	"database/sql"
	"fmt"
	"log"
	"strings"

	"gorm.io/gorm"
)

// LaborPersonKeySQL groups labour rows by mobile when present, else by name.
// Keep this identical to the expression used in labour people/balance queries
// so the matching btree index can be used for GROUP BY / DISTINCT ON.
const LaborPersonKeySQL = `CASE
	WHEN mobile IS NOT NULL AND TRIM(mobile) <> '' THEN 'm:' || TRIM(mobile)
	ELSE 'n:' || LOWER(TRIM(name))
END`

// LaborPersonKeySQLOn is LaborPersonKeySQL qualified with a table alias.
func LaborPersonKeySQLOn(table string) string {
	if table == "" {
		return LaborPersonKeySQL
	}
	return fmt.Sprintf(`CASE
	WHEN %[1]s.mobile IS NOT NULL AND TRIM(%[1]s.mobile) <> '' THEN 'm:' || TRIM(%[1]s.mobile)
	ELSE 'n:' || LOWER(TRIM(%[1]s.name))
END`, table)
}

// EnsureLaborSearchIndexes adds btree + trigram indexes used by labour list,
// typeahead, and people search. Postgres only; SQLite tests are a no-op.
// Safe to run on every startup (IF NOT EXISTS).
func EnsureLaborSearchIndexes(db *gorm.DB) error {
	if db == nil || db.Dialector == nil || db.Dialector.Name() != "postgres" {
		return nil
	}
	sqlDB, err := db.DB()
	if err != nil {
		return err
	}

	pgTrgm := true
	if _, err := sqlDB.Exec(`CREATE EXTENSION IF NOT EXISTS pg_trgm`); err != nil {
		log.Printf("labor indexes: pg_trgm extension not available (%v); substring search will stay sequential", err)
		pgTrgm = false
	}

	btreeGin := false
	if pgTrgm {
		if _, err := sqlDB.Exec(`CREATE EXTENSION IF NOT EXISTS btree_gin`); err != nil {
			log.Printf("labor indexes: btree_gin not available (%v); using separate trigram indexes", err)
		} else {
			btreeGin = true
		}
	}

	stmts := []string{
		`CREATE INDEX IF NOT EXISTS idx_labors_user_date_id ON labors (user_id, date DESC, id DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_labors_user_mobile ON labors (user_id, mobile)`,
		`CREATE INDEX IF NOT EXISTS idx_labors_user_name_lower ON labors (user_id, (LOWER(TRIM(name))))`,
		`CREATE INDEX IF NOT EXISTS idx_labors_user_kind_date ON labors (user_id, entry_kind, date DESC, id DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_labors_user_person_key ON labors (user_id, (` + LaborPersonKeySQL + `))`,
		`CREATE INDEX IF NOT EXISTS idx_labors_user_reset_person ON labors (user_id, (` + LaborPersonKeySQL + `), date DESC, id DESC) WHERE COALESCE(entry_kind, 'payable') IN ('tally', 'opening')`,
		`CREATE INDEX IF NOT EXISTS idx_labor_work_user_date_id ON labor_work_entries (user_id, date DESC, id DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_labor_work_user_name_lower ON labor_work_entries (user_id, (LOWER(TRIM(name))))`,
		`CREATE INDEX IF NOT EXISTS idx_labor_work_user_kind_date ON labor_work_entries (user_id, entry_kind, date DESC, id DESC)`,
	}

	if pgTrgm && btreeGin {
		stmts = append(stmts,
			`CREATE INDEX IF NOT EXISTS idx_labors_user_name_trgm ON labors USING gin (user_id, name gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labors_user_mobile_trgm ON labors USING gin (user_id, mobile gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labors_user_location_trgm ON labors USING gin (user_id, location gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labors_user_narration_trgm ON labors USING gin (user_id, narration gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labors_user_category_trgm ON labors USING gin (user_id, category gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labor_work_user_name_trgm ON labor_work_entries USING gin (user_id, name gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labor_work_user_narration_trgm ON labor_work_entries USING gin (user_id, narration gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labor_work_user_category_trgm ON labor_work_entries USING gin (user_id, category gin_trgm_ops)`,
		)
	} else if pgTrgm {
		stmts = append(stmts,
			`CREATE INDEX IF NOT EXISTS idx_labors_name_trgm ON labors USING gin (name gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labors_mobile_trgm ON labors USING gin (mobile gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labors_location_trgm ON labors USING gin (location gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labors_narration_trgm ON labors USING gin (narration gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labors_category_trgm ON labors USING gin (category gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labor_work_name_trgm ON labor_work_entries USING gin (name gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labor_work_narration_trgm ON labor_work_entries USING gin (narration gin_trgm_ops)`,
			`CREATE INDEX IF NOT EXISTS idx_labor_work_category_trgm ON labor_work_entries USING gin (category gin_trgm_ops)`,
		)
	}

	var firstErr error
	for _, stmt := range stmts {
		if err := execLaborIndex(sqlDB, stmt); err != nil {
			log.Printf("labor indexes: %v", err)
			if firstErr == nil {
				firstErr = err
			}
		}
	}
	if firstErr == nil {
		log.Println("Labor search indexes ensured")
	}
	return firstErr
}

func execLaborIndex(sqlDB *sql.DB, stmt string) error {
	trimmed := strings.TrimSpace(stmt)
	if strings.HasPrefix(strings.ToUpper(trimmed), "CREATE INDEX") {
		concurrent := strings.Replace(trimmed, "CREATE INDEX IF NOT EXISTS", "CREATE INDEX CONCURRENTLY IF NOT EXISTS", 1)
		if _, err := sqlDB.Exec(concurrent); err == nil {
			return nil
		} else if _, err2 := sqlDB.Exec(trimmed); err2 != nil {
			return fmt.Errorf("%v (also without CONCURRENTLY: %v)", err, err2)
		}
		return nil
	}
	if _, err := sqlDB.Exec(trimmed); err != nil {
		return err
	}
	return nil
}
