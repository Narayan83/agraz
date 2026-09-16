package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http/httptest"
	"strings"
	"testing"

	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"github.com/glebarez/sqlite"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func TestParseIEProductLinesComputesPriceFromTotal(t *testing.T) {
	raw := map[string]interface{}{
		"product_lines": []interface{}{
			map[string]interface{}{
				"product":  "rashi",
				"quantity": 10.0,
				"unit":     "kg",
				"total":    250.0,
			},
		},
	}
	lines := parseIEProductLines(raw)
	if len(lines) != 1 {
		t.Fatalf("len=%d want 1", len(lines))
	}
	if !lines[0].UnitPrice.Equal(decimal.NewFromInt(25)) {
		t.Fatalf("unit_price=%s want 25", lines[0].UnitPrice)
	}
	if !lines[0].Total.Equal(decimal.NewFromInt(250)) {
		t.Fatalf("total=%s want 250", lines[0].Total)
	}
}

func TestParseIEProductLinesComputesTotalFromPrice(t *testing.T) {
	raw := map[string]interface{}{
		"product_lines": []interface{}{
			map[string]interface{}{
				"product":    "rashi",
				"quantity":   4.0,
				"unit":       "kg",
				"unit_price": 12.5,
			},
		},
	}
	lines := parseIEProductLines(raw)
	if len(lines) != 1 {
		t.Fatalf("len=%d want 1", len(lines))
	}
	if !lines[0].Total.Equal(decimal.NewFromInt(50)) {
		t.Fatalf("total=%s want 50", lines[0].Total)
	}
}

func TestCreateIncomeExpenseMobileSavesProductLineFromTotal(t *testing.T) {
	const uid uint = 42
	dsn := fmt.Sprintf("file:ie-prod-%s?mode=memory&cache=shared",
		strings.ReplaceAll(t.Name(), "/", "_"))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.IncomeExpense{}, &models.IncomeExpenseProductLine{}); err != nil {
		t.Fatal(err)
	}
	SetIncomeExpenseDB(db)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", uid)
		c.Locals(middleware.CtxOwnerUserID, uid)
		return c.Next()
	})
	app.Post("/api/income_expense", CreateIncomeExpenseMobile)

	body, _ := json.Marshal(map[string]any{
		"type":        "Income",
		"category":    "Farming Income",
		"subCategory": "Arecanut",
		"amount":      1,
		"date":        "2026-09-15",
		"name":        "hapcins",
		"mobile":      "9999999999",
		"product_lines": []map[string]any{
			{
				"product":  "rashi",
				"quantity": 10,
				"unit":     "kg",
				"total":    250,
			},
		},
	})
	req := httptest.NewRequest("POST", "/api/income_expense", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 8000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 201 {
		t.Fatalf("status=%d body=%s", resp.StatusCode, raw)
	}
	out := map[string]any{}
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	data, _ := out["data"].(map[string]any)
	if data == nil {
		t.Fatalf("missing data: %s", raw)
	}

	var row models.IncomeExpense
	if err := db.Preload("ProductLines").First(&row, data["id"]).Error; err != nil {
		t.Fatal(err)
	}
	if row.SubCategory != "Arecanut" {
		t.Fatalf("sub_category=%q", row.SubCategory)
	}
	if !row.Amount.Equal(decimal.NewFromInt(250)) {
		t.Fatalf("amount=%s want 250", row.Amount)
	}
	if len(row.ProductLines) != 1 {
		t.Fatalf("product lines=%d", len(row.ProductLines))
	}
	ln := row.ProductLines[0]
	if ln.Product != "rashi" {
		t.Fatalf("product=%q", ln.Product)
	}
	if !ln.UnitPrice.Equal(decimal.NewFromInt(25)) {
		t.Fatalf("unit_price=%s want 25", ln.UnitPrice)
	}
	if !ln.Total.Equal(decimal.NewFromInt(250)) {
		t.Fatalf("total=%s want 250", ln.Total)
	}
}
