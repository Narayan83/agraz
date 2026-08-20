package handler

import (
	"testing"
)

func TestGenerateResetCode(t *testing.T) {
	seen := map[string]bool{}
	for i := 0; i < 30; i++ {
		code, err := generateResetCode()
		if err != nil {
			t.Fatalf("generateResetCode: %v", err)
		}
		if len(code) != 6 {
			t.Fatalf("len=%d code=%q", len(code), code)
		}
		for _, r := range code {
			if r < '0' || r > '9' {
				t.Fatalf("non-digit code %q", code)
			}
		}
		seen[code] = true
	}
	if len(seen) < 2 {
		t.Fatal("expected some variation in generated codes")
	}
}

func TestNormalizeResetEmail(t *testing.T) {
	got := normalizeResetEmail("  NanuNandi@Gmail.com  ")
	if got != "nanunandi@gmail.com" {
		t.Fatalf("got %q", got)
	}
}

func TestMatchResetCodeRejectsEmpty(t *testing.T) {
	if matchResetCode(nil, "123456") {
		t.Fatal("nil row should not match")
	}
}
