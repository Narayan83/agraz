package handler

import (
	"strings"
	"testing"
)

func TestNormalizeDairyKind(t *testing.T) {
	cases := map[[2]string]string{
		{"milk_given", ""}:        dairyKindGiven,
		{"given", ""}:             dairyKindGiven,
		{"sold", ""}:              dairyKindGiven,
		{"milk_bought", ""}:       dairyKindBought,
		{"collected", ""}:         dairyKindBought,
		{"payment_received", ""}:  dairyKindPayRecv,
		{"received", ""}:          dairyKindPayRecv,
		{"payment_made", ""}:      dairyKindPayMade,
		{"paid", ""}:              dairyKindPayMade,
		{"", "purchased"}:         dairyKindBought,
		{"unknown", ""}:           "",
	}
	for in, want := range cases {
		got := normalizeDairyKind(in[0], in[1])
		if got != want {
			t.Fatalf("normalizeDairyKind(%q,%q)=%q want %q", in[0], in[1], got, want)
		}
	}
}

func TestNormalizeDairyShift(t *testing.T) {
	if normalizeDairyShift("Morning") != dairyShiftMorning {
		t.Fatal("expected morning")
	}
	if normalizeDairyShift("evening") != dairyShiftEvening {
		t.Fatal("expected evening")
	}
	if normalizeDairyShift("noon") != "" {
		t.Fatal("invalid shift should be empty")
	}
}

func TestReverseDairyKind(t *testing.T) {
	if reverseDairyKind(dairyKindGiven) != dairyKindBought {
		t.Fatal("given should reverse to bought")
	}
	if reverseDairyKind(dairyKindPayRecv) != dairyKindPayMade {
		t.Fatal("received should reverse to paid")
	}
}

func TestParseDairyDate(t *testing.T) {
	got, err := parseDairyDate("2026-08-19")
	if err != nil {
		t.Fatal(err)
	}
	if got.Year() != 2026 || got.Month() != 8 || got.Day() != 19 {
		t.Fatalf("got %v", got)
	}
	if _, err := parseDairyDate("19-08-2026"); err == nil {
		t.Fatal("expected invalid date error")
	}
}

func TestNormalizeDiaryKind(t *testing.T) {
	if normalizeDiaryKind("LIST") != "list" {
		t.Fatal("expected list")
	}
	if normalizeDiaryKind("note") != "note" {
		t.Fatal("expected note")
	}
	if normalizeDiaryKind("") != "note" {
		t.Fatal("blank should default to note")
	}
}

func TestMarshalCheckItemsDropsEmpty(t *testing.T) {
	raw := marshalCheckItems([]diaryCheckItem{
		{Text: " Urea ", Done: true},
		{Text: "  ", Value: "  "},
		{Value: "DAP"},
	})
	if string(raw) == "[]" {
		t.Fatal("expected two items")
	}
	if !strings.Contains(string(raw), "Urea") || !strings.Contains(string(raw), "DAP") {
		t.Fatalf("unexpected json %s", raw)
	}
}
