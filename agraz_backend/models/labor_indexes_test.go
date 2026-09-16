package models

import (
	"strings"
	"testing"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func TestEnsureLaborSearchIndexesNoopsOnSQLite(t *testing.T) {
	db, err := gorm.Open(sqlite.Open("file:labor-idx-"+t.Name()+"?mode=memory&cache=shared"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&Labor{}, &LaborWorkEntry{}); err != nil {
		t.Fatal(err)
	}
	if err := EnsureLaborSearchIndexes(db); err != nil {
		t.Fatalf("sqlite should no-op, got %v", err)
	}
}

func TestLaborPersonKeySQLOnMatchesBase(t *testing.T) {
	if strings.TrimSpace(LaborPersonKeySQL) == "" {
		t.Fatal("LaborPersonKeySQL empty")
	}
	if got := LaborPersonKeySQLOn(""); got != LaborPersonKeySQL {
		t.Fatalf("unqualified alias should match base expr")
	}
	on := LaborPersonKeySQLOn("labors")
	if !strings.Contains(on, "labors.mobile") || !strings.Contains(on, "labors.name") {
		t.Fatalf("qualified expr missing table prefix: %s", on)
	}
}
