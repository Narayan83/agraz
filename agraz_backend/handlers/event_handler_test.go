package handler

import "testing"

func TestNormalizeEventRecurrence(t *testing.T) {
	cases := map[string]string{
		"yearly":   eventRecurYearly,
		"Year":     eventRecurYearly,
		"annual":   eventRecurYearly,
		"monthly":  eventRecurMonthly,
		"week":     eventRecurWeekly,
		"daily":    eventRecurDaily,
		"DAY":      eventRecurDaily,
		"unknown":  "",
		"":         "",
	}
	for in, want := range cases {
		if got := normalizeEventRecurrence(in); got != want {
			t.Fatalf("normalizeEventRecurrence(%q)=%q want %q", in, got, want)
		}
	}
}

func TestNormalizeNotifyTime(t *testing.T) {
	got, ok := normalizeNotifyTime("")
	if !ok || got != "09:00" {
		t.Fatalf("blank should default to 09:00, got %q ok=%v", got, ok)
	}
	got, ok = normalizeNotifyTime("7:30")
	if !ok || got != "07:30" {
		t.Fatalf("got %q ok=%v", got, ok)
	}
	got, ok = normalizeNotifyTime("18:05")
	if !ok || got != "18:05" {
		t.Fatalf("got %q ok=%v", got, ok)
	}
	if _, ok := normalizeNotifyTime("25:00"); ok {
		t.Fatal("invalid time should fail")
	}
}

func TestParseEventDate(t *testing.T) {
	got, err := parseEventDate("2026-08-20")
	if err != nil {
		t.Fatal(err)
	}
	if got.Year() != 2026 || got.Month() != 8 || got.Day() != 20 {
		t.Fatalf("got %v", got)
	}
	if _, err := parseEventDate("20-08-2026"); err == nil {
		t.Fatal("expected invalid date")
	}
	if _, err := parseEventDate(""); err == nil {
		t.Fatal("expected required date")
	}
}
