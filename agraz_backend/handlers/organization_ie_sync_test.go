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

func setupOrgIEApp(t *testing.T, uid uint) (*fiber.App, *gorm.DB) {
	t.Helper()
	dsn := fmt.Sprintf("file:org-ie-%s?mode=memory&cache=shared",
		strings.ReplaceAll(t.Name(), "/", "_"))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(
		&models.Organization{},
		&models.OrgLedger{},
		&models.OrgTransaction{},
		&models.IncomeExpense{},
	); err != nil {
		t.Fatal(err)
	}
	SetOrganizationDB(db)
	SetIncomeExpenseDB(db)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", uid)
		c.Locals(middleware.CtxOwnerUserID, uid)
		return c.Next()
	})
	api := app.Group("/api")
	api.Post("/organizations", CreateOrganization)
	api.Get("/org_ledgers", ListOrgLedgers)
	api.Post("/org_transactions", CreateOrgTransaction)
	api.Delete("/org_transactions/:id", DeleteOrgTransaction)
	return app, db
}

func orgIEReq(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any) {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		rdr = bytes.NewReader(raw)
	}
	req := httptest.NewRequest(method, path, rdr)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := app.Test(req, 8000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	out := map[string]any{}
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &out)
	}
	if resp.StatusCode >= 400 {
		t.Logf("%s %s -> %d %s", method, path, resp.StatusCode, string(raw))
	}
	return resp.StatusCode, out
}

func orgIEData(t *testing.T, body map[string]any) map[string]any {
	t.Helper()
	data, _ := body["data"].(map[string]any)
	if data == nil {
		t.Fatalf("missing data: %v", body)
	}
	return data
}

func seedOrgAndLedger(t *testing.T, db *gorm.DB, uid uint, orgName string) (models.Organization, models.OrgLedger) {
	t.Helper()
	if err := ensureUserOrgDefaults(uid); err != nil {
		t.Fatal(err)
	}
	org := models.Organization{UserID: uid, Name: orgName}
	if err := db.Create(&org).Error; err != nil {
		t.Fatal(err)
	}
	var led models.OrgLedger
	if err := db.Where("user_id = ?", uid).First(&led).Error; err != nil {
		t.Fatal(err)
	}
	return org, led
}

func TestOrgCashExpenseMirrorsIncomeExpense(t *testing.T) {
	const uid = uint(70)
	app, db := setupOrgIEApp(t, uid)
	org, led := seedOrgAndLedger(t, db, uid, "Farm Co")

	code, txn := orgIEReq(t, app, "POST", "/api/org_transactions", map[string]any{
		"type":             "Expense",
		"transaction_mode": "Cash",
		"organization_id":  org.ID,
		"ledger_id":        led.ID,
		"amount":           2500,
		"date":             "2026-09-10",
		"narration":        "Diesel",
	})
	if code != 201 {
		t.Fatalf("create txn status=%d body=%v", code, txn)
	}
	data := orgIEData(t, txn)
	linked := data["linked_income_expense_id"]
	if linked == nil {
		t.Fatalf("expected linked_income_expense_id: %v", data)
	}
	ieID := uint(linked.(float64))
	var ie models.IncomeExpense
	if err := db.First(&ie, ieID).Error; err != nil {
		t.Fatal(err)
	}
	if ie.Category != "Organization Expense" {
		t.Fatalf("category=%q", ie.Category)
	}
	if !ie.Amount.Equal(decimal.NewFromInt(2500)) {
		t.Fatalf("amount=%s", ie.Amount)
	}
	if ie.SubCategory != led.Name {
		t.Fatalf("sub_category=%q want %q", ie.SubCategory, led.Name)
	}

	txnID := fmt.Sprint(data["id"])
	code, _ = orgIEReq(t, app, "DELETE", "/api/org_transactions/"+txnID, nil)
	if code != 200 {
		t.Fatalf("delete status=%d", code)
	}
	if err := db.First(&ie, ieID).Error; err != gorm.ErrRecordNotFound {
		t.Fatalf("IE should be deleted with org txn, err=%v", err)
	}
}

func TestOrgCashIncomeDoesNotMirrorIncomeExpense(t *testing.T) {
	const uid = uint(71)
	app, db := setupOrgIEApp(t, uid)
	org, led := seedOrgAndLedger(t, db, uid, "Shop")

	code, _ := orgIEReq(t, app, "POST", "/api/org_transactions", map[string]any{
		"type":             "Income",
		"transaction_mode": "Cash",
		"organization_id":  org.ID,
		"ledger_id":        led.ID,
		"amount":           1000,
		"date":             "2026-09-11",
	})
	if code != 201 {
		t.Fatalf("create income status=%d", code)
	}
	var ieCount int64
	db.Model(&models.IncomeExpense{}).Where("user_id = ?", uid).Count(&ieCount)
	if ieCount != 0 {
		t.Fatalf("cash income should not mirror to I&E, got %d", ieCount)
	}
}

func TestOrgTransferCreatesCounterpartNoIE(t *testing.T) {
	const uid = uint(72)
	app, db := setupOrgIEApp(t, uid)
	_ = ensureUserOrgDefaults(uid)

	orgA := models.Organization{UserID: uid, Name: "OrgA"}
	orgB := models.Organization{UserID: uid, Name: "OrgB"}
	if err := db.Create(&orgA).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&orgB).Error; err != nil {
		t.Fatal(err)
	}
	var srcLed models.OrgLedger
	if err := db.Where("user_id = ?", uid).First(&srcLed).Error; err != nil {
		t.Fatal(err)
	}

	code, txn := orgIEReq(t, app, "POST", "/api/org_transactions", map[string]any{
		"type":                        "Expense",
		"transaction_mode":            "Transfer",
		"organization_id":             orgA.ID,
		"ledger_id":                   srcLed.ID,
		"transfer_to_organization_id": orgB.ID,
		"amount":                      500,
		"date":                        "2026-09-12",
	})
	if code != 201 {
		t.Fatalf("transfer status=%d body=%v", code, txn)
	}

	var txnCount int64
	db.Model(&models.OrgTransaction{}).Where("user_id = ?", uid).Count(&txnCount)
	if txnCount != 2 {
		t.Fatalf("transfer should create 2 txns, got %d", txnCount)
	}
	var ieCount int64
	db.Model(&models.IncomeExpense{}).Where("user_id = ?", uid).Count(&ieCount)
	if ieCount != 0 {
		t.Fatalf("transfer should not create I&E, got %d", ieCount)
	}
}
