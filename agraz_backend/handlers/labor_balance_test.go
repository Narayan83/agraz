package handler

import (
	"testing"
	"time"

	"erp.local/backend/models"
	"github.com/shopspring/decimal"
)

func TestLaborAccountTotalsResetExtrasAndSeparatePhones(t *testing.T) {
	mob := "9999999999"
	day := func(m, d int) time.Time {
		return time.Date(2026, time.Month(m), d, 0, 0, 0, 0, time.UTC)
	}
	rows := []models.Labor{
		{ID: 1, Name: "Manjunath Patagar", EntryKind: "payable", Wage: decimal.NewFromInt(800), Hours: decimal.NewFromInt(5), Date: day(7, 1)},
		{ID: 2, Name: "Manjunath Patagar", EntryKind: "opening", Wage: decimal.NewFromInt(3000), Hours: decimal.NewFromInt(1), Date: day(8, 1)},
		{
			ID: 3, Name: "Manjunath Patagar", EntryKind: "payable", Wage: decimal.NewFromInt(400), Hours: decimal.NewFromInt(1), Date: day(8, 4),
			Extra: &models.LaborExtra{Rent: decimal.NewFromInt(50)},
		},
		{ID: 4, Name: "Manjunath Patagar", EntryKind: "payment", Wage: decimal.NewFromInt(1000), Hours: decimal.NewFromInt(1), Date: day(8, 10)},
		{ID: 5, Name: "Manjunath Patagar", Mobile: &mob, EntryKind: "payment", Wage: decimal.NewFromInt(9000), Hours: decimal.NewFromInt(1), Date: day(8, 11)},
	}

	nameOnly := laborOneAccountTotals(rows[:4], nil, nil)
	if nameOnly.Payable != 3450 || nameOnly.Paid != 1000 || nameOnly.Hours != 1 {
		t.Fatalf("name account payable=%v paid=%v hours=%v", nameOnly.Payable, nameOnly.Paid, nameOnly.Hours)
	}

	all := laborAccountTotals(rows, nil, nil)
	if all.Payable != 3450 || all.Paid != 10000 {
		t.Fatalf("split accounts payable=%v paid=%v", all.Payable, all.Paid)
	}

	from := day(9, 1)
	to := day(9, 30)
	rows = append(rows, models.Labor{
		ID: 6, Name: "Manjunath Patagar", EntryKind: "payable",
		Wage: decimal.NewFromInt(200), Hours: decimal.NewFromInt(1), Date: day(9, 2),
	})
	sept := laborAccountTotals(rows, &from, &to)
	if sept.Payable != 200 || sept.Paid != 0 {
		t.Fatalf("september window payable=%v paid=%v", sept.Payable, sept.Paid)
	}
}

func TestLaborAccountTotalsTallyClearsEarlierBalance(t *testing.T) {
	day := func(d int) time.Time {
		return time.Date(2026, 9, d, 0, 0, 0, 0, time.UTC)
	}
	rows := []models.Labor{
		{ID: 1, Name: "A", EntryKind: "payable", Wage: decimal.NewFromInt(1000), Hours: decimal.NewFromInt(5), Date: day(1)},
		{ID: 2, Name: "A", EntryKind: "tally", Wage: decimal.Zero, Hours: decimal.NewFromInt(1), Date: day(15)},
		{ID: 3, Name: "A", EntryKind: "payable", Wage: decimal.NewFromInt(100), Hours: decimal.NewFromInt(1), Date: day(20)},
		{ID: 4, Name: "A", EntryKind: "payment", Wage: decimal.NewFromInt(40), Hours: decimal.NewFromInt(1), Date: day(21)},
	}
	got := laborOneAccountTotals(rows, nil, nil)
	if got.Payable != 100 || got.Paid != 40 || got.Payable-got.Paid != 60 {
		t.Fatalf("after tally %+v", got)
	}
}
