package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"erp.local/backend/models"
	"github.com/glebarez/sqlite"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupEntryAnalyticsEntriesApp(t *testing.T) (*fiber.App, *gorm.DB) {
	t.Helper()
	db, err := gorm.Open(sqlite.Open("file:entry-analytics-"+t.Name()+"?mode=memory&cache=shared"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.IncomeExpense{}, &models.Labor{}, &models.LaborExtra{}); err != nil {
		t.Fatal(err)
	}
	SetIncomeExpenseDB(db)
	SetLaborDB(db)

	app := fiber.New()
	app.Get("/api/admin/entry-analytics/entries", AdminEntryAnalyticsEntries)
	return app, db
}

func getAnalyticsEntries(t *testing.T, app *fiber.App, path string) map[string]any {
	t.Helper()
	resp, err := app.Test(httptest.NewRequest(http.MethodGet, path, nil), 5000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status=%d body=%v", resp.StatusCode, body)
	}
	return body
}

func TestEntryAnalyticsLaborReturnsAllRowsAndFiltersByPerson(t *testing.T) {
	app, db := setupEntryAnalyticsEntriesApp(t)
	day := time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC)
	for i := 0; i < 16; i++ {
		name := "Geeta Manjunath Patagar"
		if i >= 12 {
			name = "Manjunath Patagar"
		}
		row := models.Labor{
			UserID: 53, Name: name, Wage: decimal.NewFromInt(500), Hours: decimal.NewFromInt(1),
			Shift: "fullday", Category: "Harvest", Date: day.AddDate(0, 0, i), EntryKind: "payable",
		}
		if err := db.Create(&row).Error; err != nil {
			t.Fatal(err)
		}
	}

	all := getAnalyticsEntries(t, app, "/api/admin/entry-analytics/entries?menu=labor&user_id=53&page=1&limit=20")
	if all["total"].(float64) != 16 || len(all["data"].([]any)) != 16 {
		t.Fatalf("expected all 16 entries, got total=%v data=%d", all["total"], len(all["data"].([]any)))
	}
	if len(all["people"].([]any)) != 2 {
		t.Fatalf("expected two labourers, got %v", all["people"])
	}

	filtered := getAnalyticsEntries(t, app, "/api/admin/entry-analytics/entries?menu=labor&user_id=53&person=Manjunath%20Patagar")
	if filtered["total"].(float64) != 4 || len(filtered["data"].([]any)) != 4 {
		t.Fatalf("expected four filtered entries, got total=%v data=%d", filtered["total"], len(filtered["data"].([]any)))
	}
}

func TestEntryAnalyticsIncomeExpenseFiltersByPerson(t *testing.T) {
	app, db := setupEntryAnalyticsEntriesApp(t)
	for i, name := range []string{"Buyer One", "Buyer Two", "Buyer One"} {
		row := models.IncomeExpense{
			UserID: 36, Type: "Income", Category: "Crop", SubCategory: "Sale",
			Amount: decimal.NewFromInt(int64(100 + i)), Mobile: fmt.Sprintf("900000000%d", i),
			Date: time.Date(2026, 8, 1+i, 0, 0, 0, 0, time.UTC), Name: name, TransactionMode: "Cash",
		}
		if err := db.Create(&row).Error; err != nil {
			t.Fatal(err)
		}
	}

	body := getAnalyticsEntries(t, app, "/api/admin/entry-analytics/entries?menu=income_expense&user_id=36&person=Buyer%20One")
	if body["total"].(float64) != 2 || len(body["data"].([]any)) != 2 {
		t.Fatalf("expected two filtered entries, got total=%v data=%d", body["total"], len(body["data"].([]any)))
	}
	if len(body["people"].([]any)) != 2 {
		t.Fatalf("expected two people, got %v", body["people"])
	}
}
