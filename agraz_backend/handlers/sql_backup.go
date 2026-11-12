package handler

import (
	"bytes"
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
)

// userIsStrictSuperAdmin is the Super Admin role only. The Admin role is not enough.
func userIsStrictSuperAdmin(userID uint) bool {
	if userID == 0 || userDB == nil {
		return false
	}
	var n int64
	err := userDB.Model(&models.UserRoleMapping{}).
		Joins("JOIN roles ON roles.id = user_role_mappings.role_id").
		Where("user_role_mappings.user_id = ? AND roles.role_name = ?", userID, "Super Admin").
		Count(&n).Error
	return err == nil && n > 0
}

// DownloadSQLBackup streams a .sql dump. Super Admin only.
func DownloadSQLBackup(c *fiber.Ctx) error {
	uid, ok := userIDFromCtx(c)
	if !ok || !userIsStrictSuperAdmin(uid) {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"error": "Only Super Admin can download a database backup",
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	data, err := dumpWithPgDump(ctx)
	if err != nil {
		log.Printf("sql backup: pg_dump unavailable (%v); using built-in dump", err)
		sqlDB, dbErr := initializers.DB.DB()
		if dbErr != nil {
			log.Printf("sql backup: db handle: %v", dbErr)
			return c.Status(500).JSON(fiber.Map{"error": "Could not create the SQL backup"})
		}
		data, err = buildSQLBackup(ctx, sqlDB)
		if err != nil {
			log.Printf("sql backup: built-in dump failed: %v", err)
			return c.Status(500).JSON(fiber.Map{"error": "Could not create the SQL backup"})
		}
	}

	name := fmt.Sprintf("agraz-backup-%s.sql", time.Now().Format("2006-01-02-150405"))
	c.Set("Content-Type", "application/sql; charset=utf-8")
	c.Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, name))
	return c.Send(data)
}

type pgConn struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

func parsePGConn(raw string) (pgConn, error) {
	s := strings.TrimSpace(raw)
	if len(s) >= 2 && ((s[0] == '"' && s[len(s)-1] == '"') || (s[0] == '\'' && s[len(s)-1] == '\'')) {
		s = s[1 : len(s)-1]
	}
	if strings.HasPrefix(s, "postgres://") || strings.HasPrefix(s, "postgresql://") {
		u, err := url.Parse(s)
		if err != nil {
			return pgConn{}, err
		}
		pass, _ := u.User.Password()
		port := u.Port()
		if port == "" {
			port = "5432"
		}
		db := strings.TrimPrefix(u.Path, "/")
		if u.Hostname() == "" || u.User.Username() == "" || db == "" {
			return pgConn{}, fmt.Errorf("incomplete database url")
		}
		return pgConn{
			Host: u.Hostname(), Port: port, User: u.User.Username(),
			Password: pass, DBName: db, SSLMode: u.Query().Get("sslmode"),
		}, nil
	}

	vals := map[string]string{}
	for _, tok := range splitConnTokens(s) {
		i := strings.IndexByte(tok, '=')
		if i <= 0 {
			continue
		}
		k := strings.ToLower(strings.TrimSpace(tok[:i]))
		v := strings.TrimSpace(tok[i+1:])
		v = strings.Trim(v, `"'`)
		vals[k] = v
	}
	c := pgConn{
		Host: vals["host"], Port: vals["port"], User: firstNonEmpty(vals["user"], vals["username"]),
		Password: vals["password"], DBName: firstNonEmpty(vals["dbname"], vals["database"]),
		SSLMode: vals["sslmode"],
	}
	if c.Host == "" {
		c.Host = "127.0.0.1"
	}
	if c.Port == "" {
		c.Port = "5432"
	}
	if c.User == "" || c.DBName == "" {
		return pgConn{}, fmt.Errorf("database connection is missing user or dbname")
	}
	return c, nil
}

func splitConnTokens(s string) []string {
	var out []string
	var b strings.Builder
	var quote byte
	for i := 0; i < len(s); i++ {
		ch := s[i]
		if quote != 0 {
			if ch == quote {
				quote = 0
			}
			b.WriteByte(ch)
			continue
		}
		if ch == '\'' || ch == '"' {
			quote = ch
			b.WriteByte(ch)
			continue
		}
		if ch == ' ' || ch == '\t' || ch == '\n' {
			if b.Len() > 0 {
				out = append(out, b.String())
				b.Reset()
			}
			continue
		}
		b.WriteByte(ch)
	}
	if b.Len() > 0 {
		out = append(out, b.String())
	}
	return out
}

func findPgDump() (string, error) {
	if p, err := exec.LookPath("pg_dump"); err == nil {
		return p, nil
	}
	candidates := []string{"/usr/bin/pg_dump", "/usr/local/bin/pg_dump"}
	if matches, err := filepath.Glob("/usr/lib/postgresql/*/bin/pg_dump"); err == nil {
		candidates = append(candidates, matches...)
	}
	for _, p := range candidates {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p, nil
		}
	}
	return "", fmt.Errorf("pg_dump not found")
}

func dumpWithPgDump(ctx context.Context) ([]byte, error) {
	conn, err := parsePGConn(os.Getenv("DB_CONNECTION_STRING"))
	if err != nil {
		return nil, err
	}
	bin, err := findPgDump()
	if err != nil {
		return nil, err
	}
	cmd := exec.CommandContext(ctx, bin,
		"-h", conn.Host,
		"-p", conn.Port,
		"-U", conn.User,
		"-d", conn.DBName,
		"-F", "p",
		"--no-owner",
		"--no-acl",
	)
	cmd.Env = append(os.Environ(), "PGPASSWORD="+conn.Password)
	if conn.SSLMode != "" {
		cmd.Env = append(cmd.Env, "PGSSLMODE="+conn.SSLMode)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		msg := strings.TrimSpace(stderr.String())
		if len(msg) > 300 {
			msg = msg[:300]
		}
		if msg == "" {
			msg = err.Error()
		}
		return nil, fmt.Errorf("%s", msg)
	}
	if stdout.Len() == 0 {
		return nil, fmt.Errorf("pg_dump produced an empty file")
	}
	return stdout.Bytes(), nil
}

var identRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

func quoteIdent(name string) (string, bool) {
	if !identRe.MatchString(name) {
		return "", false
	}
	return `"` + name + `"`, true
}

func sqlLiteral(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

func buildSQLBackup(ctx context.Context, db *sql.DB) ([]byte, error) {
	tables, err := listPublicTables(ctx, db)
	if err != nil {
		return nil, err
	}
	if len(tables) == 0 {
		return nil, fmt.Errorf("no tables found")
	}
	var buf bytes.Buffer
	fmt.Fprintf(&buf, "-- Agraz SQL backup\n-- Generated: %s\n", time.Now().UTC().Format(time.RFC3339))
	buf.WriteString("-- Built-in dump (pg_dump was not available on the server).\n")
	buf.WriteString("-- Restore into an empty database, for example: psql -d agraz -f this-file.sql\n\n")
	buf.WriteString("BEGIN;\n\n")
	for _, table := range tables {
		ddl, err := createTableSQL(ctx, db, table)
		if err != nil {
			return nil, err
		}
		buf.WriteString(ddl)
		buf.WriteString("\n")
	}
	buf.WriteString("\n")
	for _, table := range tables {
		if err := writeTableInserts(ctx, db, &buf, table); err != nil {
			return nil, err
		}
	}
	if err := writeSequenceSetvals(ctx, db, &buf); err != nil {
		return nil, err
	}
	buf.WriteString("\nCOMMIT;\n")
	return buf.Bytes(), nil
}

func listPublicTables(ctx context.Context, db *sql.DB) ([]string, error) {
	rows, err := db.QueryContext(ctx, `
		SELECT c.relname
		FROM pg_class c
		JOIN pg_namespace n ON n.oid = c.relnamespace
		WHERE n.nspname = 'public' AND c.relkind = 'r'
		ORDER BY c.relname`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tables []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		if _, ok := quoteIdent(name); ok {
			tables = append(tables, name)
		}
	}
	return tables, rows.Err()
}

type columnDef struct {
	Name    string
	Type    string
	NotNull bool
	Default sql.NullString
}

func createTableSQL(ctx context.Context, db *sql.DB, table string) (string, error) {
	qt, ok := quoteIdent(table)
	if !ok {
		return "", fmt.Errorf("unsafe table name")
	}
	rows, err := db.QueryContext(ctx, `
		SELECT a.attname,
		       format_type(a.atttypid, a.atttypmod),
		       a.attnotnull,
		       pg_get_expr(d.adbin, d.adrelid)
		FROM pg_attribute a
		JOIN pg_class c ON c.oid = a.attrelid
		JOIN pg_namespace n ON n.oid = c.relnamespace
		LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
		WHERE n.nspname = 'public' AND c.relname = $1
		  AND a.attnum > 0 AND NOT a.attisdropped
		ORDER BY a.attnum`, table)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	var cols []columnDef
	for rows.Next() {
		var col columnDef
		if err := rows.Scan(&col.Name, &col.Type, &col.NotNull, &col.Default); err != nil {
			return "", err
		}
		if _, ok := quoteIdent(col.Name); !ok {
			return "", fmt.Errorf("unsafe column name on %s", table)
		}
		cols = append(cols, col)
	}
	if err := rows.Err(); err != nil {
		return "", err
	}
	if len(cols) == 0 {
		return "", fmt.Errorf("table %s has no columns", table)
	}
	pks, err := primaryKeyColumns(ctx, db, table)
	if err != nil {
		return "", err
	}
	var b strings.Builder
	fmt.Fprintf(&b, "CREATE TABLE IF NOT EXISTS %s (\n", qt)
	for i, col := range cols {
		qn, _ := quoteIdent(col.Name)
		fmt.Fprintf(&b, "  %s %s", qn, col.Type)
		if col.NotNull {
			b.WriteString(" NOT NULL")
		}
		if col.Default.Valid && col.Default.String != "" {
			b.WriteString(" DEFAULT ")
			b.WriteString(col.Default.String)
		}
		if i < len(cols)-1 || len(pks) > 0 {
			b.WriteString(",")
		}
		b.WriteString("\n")
	}
	if len(pks) > 0 {
		quoted := make([]string, 0, len(pks))
		for _, pk := range pks {
			qn, ok := quoteIdent(pk)
			if !ok {
				return "", fmt.Errorf("unsafe primary key on %s", table)
			}
			quoted = append(quoted, qn)
		}
		fmt.Fprintf(&b, "  PRIMARY KEY (%s)\n", strings.Join(quoted, ", "))
	}
	b.WriteString(");\n")
	return b.String(), nil
}

func primaryKeyColumns(ctx context.Context, db *sql.DB, table string) ([]string, error) {
	rows, err := db.QueryContext(ctx, `
		SELECT a.attname
		FROM pg_index i
		JOIN pg_class c ON c.oid = i.indrelid
		JOIN pg_namespace n ON n.oid = c.relnamespace
		JOIN LATERAL unnest(i.indkey) WITH ORDINALITY AS k(attnum, ord) ON true
		JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = k.attnum
		WHERE n.nspname = 'public' AND c.relname = $1 AND i.indisprimary
		ORDER BY k.ord`, table)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var cols []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		cols = append(cols, name)
	}
	return cols, rows.Err()
}

func writeTableInserts(ctx context.Context, db *sql.DB, buf *bytes.Buffer, table string) error {
	qt, ok := quoteIdent(table)
	if !ok {
		return fmt.Errorf("unsafe table name")
	}
	colRows, err := db.QueryContext(ctx, `
		SELECT column_name
		FROM information_schema.columns
		WHERE table_schema = 'public' AND table_name = $1
		ORDER BY ordinal_position`, table)
	if err != nil {
		return err
	}
	var cols []string
	for colRows.Next() {
		var name string
		if err := colRows.Scan(&name); err != nil {
			colRows.Close()
			return err
		}
		qn, ok := quoteIdent(name)
		if !ok {
			colRows.Close()
			return fmt.Errorf("unsafe column on %s", table)
		}
		cols = append(cols, qn)
	}
	if err := colRows.Err(); err != nil {
		colRows.Close()
		return err
	}
	colRows.Close()
	if len(cols) == 0 {
		return nil
	}
	selects := make([]string, len(cols))
	for i, col := range cols {
		selects[i] = col + "::text"
	}
	q := fmt.Sprintf("SELECT %s FROM public.%s", strings.Join(selects, ", "), qt)
	rows, err := db.QueryContext(ctx, q)
	if err != nil {
		return err
	}
	defer rows.Close()

	const batch = 100
	pending := make([][]sql.NullString, 0, batch)
	flush := func() {
		if len(pending) == 0 {
			return
		}
		fmt.Fprintf(buf, "INSERT INTO %s (%s) VALUES\n", qt, strings.Join(cols, ", "))
		for i, row := range pending {
			if i > 0 {
				buf.WriteString(",\n")
			}
			buf.WriteByte('(')
			for j, v := range row {
				if j > 0 {
					buf.WriteByte(',')
				}
				if !v.Valid {
					buf.WriteString("NULL")
				} else {
					buf.WriteString(sqlLiteral(v.String))
				}
			}
			buf.WriteByte(')')
		}
		buf.WriteString(";\n")
		pending = pending[:0]
	}
	for rows.Next() {
		vals := make([]sql.NullString, len(cols))
		ptrs := make([]any, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return err
		}
		pending = append(pending, vals)
		if len(pending) >= batch {
			flush()
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	flush()
	return nil
}

func writeSequenceSetvals(ctx context.Context, db *sql.DB, buf *bytes.Buffer) error {
	rows, err := db.QueryContext(ctx, `
		SELECT c.relname, a.attname,
		       pg_get_serial_sequence(format('%I.%I', n.nspname, c.relname), a.attname)
		FROM pg_class c
		JOIN pg_namespace n ON n.oid = c.relnamespace
		JOIN pg_attribute a ON a.attrelid = c.oid
		WHERE n.nspname = 'public' AND c.relkind = 'r'
		  AND a.attnum > 0 AND NOT a.attisdropped
		  AND pg_get_serial_sequence(format('%I.%I', n.nspname, c.relname), a.attname) IS NOT NULL
		ORDER BY c.relname, a.attname`)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var table, column, seq string
		if err := rows.Scan(&table, &column, &seq); err != nil {
			return err
		}
		qt, okT := quoteIdent(table)
		qc, okC := quoteIdent(column)
		if !okT || !okC || strings.ContainsAny(seq, "';") {
			continue
		}
		fmt.Fprintf(buf, "SELECT setval(%s, COALESCE((SELECT MAX(%s) FROM %s), 1), true);\n",
			sqlLiteral(seq), qc, qt)
	}
	return rows.Err()
}
