package handler

import (
	"testing"
)

func TestNormalizeLaborEntryKind(t *testing.T) {
	cases := map[string]string{
		"":        "payable",
		"paid":     "payment",
		"PAYMENT":  "payment",
		"tally":    "tally",
		"opening":  "opening",
		"payable":  "payable",
	}
	for in, want := range cases {
		got := normalizeLaborEntryKind(in)
		if got != want {
			t.Fatalf("normalizeLaborEntryKind(%q)=%q want %q", in, got, want)
		}
	}
}

func TestValidateLaborTally(t *testing.T) {
	body := laborPayload{
		Name:      "Ramu",
		EntryKind: "tally",
		Narration: "Settled up to today",
		Date:      flexibleTime{},
	}
	// zero date should fail
	if msg := validateLaborPayload(&body); msg == "" {
		t.Fatal("expected date required for tally")
	}
	body.Date.Time = body.Date.Time.AddDate(2026, 0, 0) // still zero-ish; set properly below
	body.Date.UnmarshalJSON([]byte(`"2026-08-16"`))
	if msg := validateLaborPayload(&body); msg != "" {
		t.Fatalf("unexpected tally validation error: %s", msg)
	}
	if body.Wage != 0 || body.Category != "Tally" {
		t.Fatalf("tally defaults wrong: wage=%v cat=%s", body.Wage, body.Category)
	}
}

func TestValidateLaborPayable(t *testing.T) {
	body := laborPayload{
		Name:     "Ramu",
		Wage:     500,
		Hours:    1,
		Shift:    "fullday",
		Category: "Plucking",
		Gender:   "Male",
		WorkType: "Daily Wages",
		Location: "Farm",
		Rent:     50,
		Food:     20,
		Bonus:    10,
	}
	_ = body.Date.UnmarshalJSON([]byte(`"2026-08-16"`))
	if msg := validateLaborPayload(&body); msg != "" {
		t.Fatalf("payable validation failed: %s", msg)
	}
}

func TestNormalizeLaborWorkKind(t *testing.T) {
	if normalizeLaborWorkKind("") != "receivable" {
		t.Fatal("default should be receivable")
	}
	if normalizeLaborWorkKind("payment") != "receipt" {
		t.Fatal("payment should map to receipt")
	}
}
