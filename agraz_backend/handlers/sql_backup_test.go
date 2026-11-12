package handler

import "testing"

func TestParsePGConnKeyword(t *testing.T) {
	c, err := parsePGConn(`host=localhost port=5432 user=agraz_user password=p@ss word dbname=agraz sslmode=disable`)
	if err != nil {
		t.Fatal(err)
	}
	if c.Host != "localhost" || c.Port != "5432" || c.User != "agraz_user" || c.DBName != "agraz" || c.SSLMode != "disable" {
		t.Fatalf("parsed %+v", c)
	}
	if c.Password != "p@ss" {
		t.Fatalf("password = %q", c.Password)
	}
}

func TestParsePGConnQuotedPassword(t *testing.T) {
	c, err := parsePGConn(`host=127.0.0.1 user=agraz_user password="secret pass" dbname=agraz`)
	if err != nil {
		t.Fatal(err)
	}
	if c.Password != "secret pass" || c.Port != "5432" || c.DBName != "agraz" {
		t.Fatalf("parsed %+v", c)
	}
}

func TestParsePGConnURL(t *testing.T) {
	c, err := parsePGConn(`postgres://agraz_user:p%40ss@db.internal:5433/agraz?sslmode=require`)
	if err != nil {
		t.Fatal(err)
	}
	if c.User != "agraz_user" || c.Password != "p@ss" || c.Host != "db.internal" || c.Port != "5433" || c.DBName != "agraz" || c.SSLMode != "require" {
		t.Fatalf("parsed %+v", c)
	}
}

func TestSQLLiteral(t *testing.T) {
	if got := sqlLiteral("O'Brien"); got != "'O''Brien'" {
		t.Fatalf("got %s", got)
	}
}

func TestQuoteIdentRejectsUnsafe(t *testing.T) {
	if _, ok := quoteIdent(`users"; drop`); ok {
		t.Fatal("expected reject")
	}
	if got, ok := quoteIdent("labors"); !ok || got != `"labors"` {
		t.Fatalf("got %s ok=%v", got, ok)
	}
}
