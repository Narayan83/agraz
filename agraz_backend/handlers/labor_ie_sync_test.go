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

func setupLaborIEApp(t *testing.T, uid uint) (*fiber.App, *gorm.DB) {
	t.Helper()
	dsn := fmt.Sprintf("file:labor-ie-%s?mode=memory&cache=shared",
		strings.ReplaceAll(t.Name(), "/", "_"))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(
		&models.Labor{},
		&models.LaborExtra{},
		&models.LaborShare{},
		&models.IncomeExpense{},
		&models.IncomeExpenseProductLine{},
	); err != nil {
		t.Fatal(err)
	}
	SetLaborDB(db)
	SetIncomeExpenseDB(db)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", uid)
		c.Locals(middleware.CtxOwnerUserID, uid)
		return c.Next()
	})
	api := app.Group("/api")
	api.Post("/labors", CreateLabor)
	api.Put("/labors/:id", UpdateLabor)
	api.Delete("/labors/:id", DeleteLabor)
	api.Get("/labors/:id", GetLabor)
	api.Put("/income_expense/:id", UpdateIncomeExpenseMobile)
	api.Delete("/income_expense/:id", DeleteIncomeExpense)
	return app, db
}

func laborIEReq(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any) {
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

func laborIEData(t *testing.T, body map[string]any) map[string]any {
	t.Helper()
	data, _ := body["data"].(map[string]any)
	if data == nil {
		t.Fatalf("missing data: %v", body)
	}
	return data
}

func laborIEID(t *testing.T, data map[string]any) string {
	t.Helper()
	id := fmt.Sprint(data["id"])
	if id == "" || id == "<nil>" || id == "0" {
		t.Fatalf("bad id in %v", data)
	}
	return id
}

func findIEByID(t *testing.T, db *gorm.DB, id uint) (models.IncomeExpense, bool) {
	t.Helper()
	var row models.IncomeExpense
	err := db.First(&row, id).Error
	if err == gorm.ErrRecordNotFound {
		return row, false
	}
	if err != nil {
		t.Fatal(err)
	}
	return row, true
}

func TestLaborPaymentCreateSyncsIncomeExpense(t *testing.T) {
	const uid = uint(42)
	app, db := setupLaborIEApp(t, uid)
	mobile := "9876543210"

	code, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Ramu",
		"mobile":     mobile,
		"wage":       3000,
		"hours":      1,
		"entry_kind": "payment",
		"date":       "2026-09-10",
		"narration":  "Weekly settlement",
		"category":   "Payment",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	if code != 201 {
		t.Fatalf("create payment status=%d body=%v", code, body)
	}
	data := laborIEData(t, body)
	ieRaw, ok := data["income_expense_id"]
	if !ok || ieRaw == nil {
		t.Fatalf("payment missing income_expense_id: %v", data)
	}
	ieID := uint(ieRaw.(float64))
	ie, found := findIEByID(t, db, ieID)
	if !found {
		t.Fatal("linked income/expense row missing")
	}
	if ie.Type != "Expense" || ie.Category != "Farming Expense" || ie.SubCategory != "Labour" {
		t.Fatalf("IE classification wrong: %+v", ie)
	}
	if !ie.Amount.Equal(decimal.NewFromInt(3000)) {
		t.Fatalf("IE amount=%s want 3000", ie.Amount)
	}
	if ie.Name != "Ramu" || ie.Mobile != mobile {
		t.Fatalf("IE party mismatch: name=%q mobile=%q", ie.Name, ie.Mobile)
	}
	if ie.Date.Format("2006-01-02") != "2026-09-10" {
		t.Fatalf("IE date=%v", ie.Date)
	}
}

func TestLaborPayableWithPaidAmountCreatesPaymentAndIE(t *testing.T) {
	const uid = uint(43)
	app, db := setupLaborIEApp(t, uid)

	code, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":        "Sita",
		"mobile":      "9123456780",
		"wage":        500,
		"hours":       4,
		"paid_amount": 1000,
		"entry_kind":  "payable",
		"date":        "2026-09-11",
		"category":    "Weeding",
		"shift":       "fullday",
		"gender":      "Female",
		"work_type":   "Daily Wages",
		"location":    "Farm",
	})
	if code != 201 {
		t.Fatalf("create payable status=%d body=%v", code, body)
	}
	pay, _ := body["payment"].(map[string]any)
	if pay == nil {
		t.Fatalf("expected nested payment: %v", body)
	}
	ieID := uint(pay["income_expense_id"].(float64))
	ie, found := findIEByID(t, db, ieID)
	if !found {
		t.Fatal("IE for paid_amount missing")
	}
	if !ie.Amount.Equal(decimal.NewFromInt(1000)) {
		t.Fatalf("IE amount=%s want 1000", ie.Amount)
	}

	var payableCount int64
	db.Model(&models.Labor{}).Where("user_id = ? AND entry_kind = ?", uid, "payable").Count(&payableCount)
	var paymentCount int64
	db.Model(&models.Labor{}).Where("user_id = ? AND entry_kind = ?", uid, "payment").Count(&paymentCount)
	if payableCount != 1 || paymentCount != 1 {
		t.Fatalf("payable=%d payment=%d", payableCount, paymentCount)
	}
}

func TestLaborPaymentUpdateSyncsIncomeExpense(t *testing.T) {
	const uid = uint(44)
	app, db := setupLaborIEApp(t, uid)
	mobile := "9000000001"

	_, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Ramu",
		"mobile":     mobile,
		"wage":       2000,
		"hours":      1,
		"entry_kind": "payment",
		"date":       "2026-09-01",
		"narration":  "First pay",
		"category":   "Payment",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	data := laborIEData(t, body)
	laborID := laborIEID(t, data)
	ieID := uint(data["income_expense_id"].(float64))

	newMobile := "9000000002"
	code, upd := laborIEReq(t, app, "PUT", "/api/labors/"+laborID, map[string]any{
		"name":       "Ramu Gowda",
		"mobile":     newMobile,
		"wage":       3500,
		"hours":      1,
		"entry_kind": "payment",
		"date":       "2026-09-15",
		"narration":  "Adjusted pay",
		"category":   "Payment",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	if code != 200 {
		t.Fatalf("update status=%d body=%v", code, upd)
	}

	ie, found := findIEByID(t, db, ieID)
	if !found {
		t.Fatal("linked IE was deleted on update")
	}
	if !ie.Amount.Equal(decimal.NewFromInt(3500)) {
		t.Fatalf("IE amount not synced: got %s want 3500", ie.Amount)
	}
	if ie.Name != "Ramu Gowda" {
		t.Fatalf("IE name not synced: %q", ie.Name)
	}
	if ie.Mobile != newMobile {
		t.Fatalf("IE mobile not synced: %q", ie.Mobile)
	}
	if ie.Date.Format("2006-01-02") != "2026-09-15" {
		t.Fatalf("IE date not synced: %v", ie.Date)
	}
	if ie.Narration == nil || *ie.Narration != "Adjusted pay" {
		t.Fatalf("IE narration not synced: %v", ie.Narration)
	}
}

func TestLaborPaymentDeleteRemovesIncomeExpense(t *testing.T) {
	const uid = uint(45)
	app, db := setupLaborIEApp(t, uid)

	_, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Lakshmi",
		"mobile":     "9111111111",
		"wage":       1500,
		"hours":      1,
		"entry_kind": "payment",
		"date":       "2026-09-05",
		"category":   "Payment",
		"shift":      "fullday",
		"gender":     "Female",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	data := laborIEData(t, body)
	laborID := laborIEID(t, data)
	ieID := uint(data["income_expense_id"].(float64))

	code, _ := laborIEReq(t, app, "DELETE", "/api/labors/"+laborID, nil)
	if code != 200 {
		t.Fatalf("delete status=%d", code)
	}
	if _, found := findIEByID(t, db, ieID); found {
		t.Fatal("linked income/expense should be deleted with labour payment")
	}
	var labor models.Labor
	if err := db.First(&labor, laborID).Error; err != gorm.ErrRecordNotFound {
		t.Fatalf("labour row should be gone, err=%v", err)
	}
}

func TestLaborPayableUpdateDoesNotCreateIncomeExpense(t *testing.T) {
	const uid = uint(46)
	app, db := setupLaborIEApp(t, uid)

	_, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Kumar",
		"mobile":     "9222222222",
		"wage":       400,
		"hours":      2,
		"entry_kind": "payable",
		"date":       "2026-09-08",
		"category":   "Harvest",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	data := laborIEData(t, body)
	laborID := laborIEID(t, data)

	code, _ := laborIEReq(t, app, "PUT", "/api/labors/"+laborID, map[string]any{
		"name":       "Kumar",
		"mobile":     "9222222222",
		"wage":       450,
		"hours":      3,
		"entry_kind": "payable",
		"date":       "2026-09-08",
		"category":   "Harvest",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	if code != 200 {
		t.Fatalf("update payable status=%d", code)
	}
	var ieCount int64
	db.Model(&models.IncomeExpense{}).Where("user_id = ?", uid).Count(&ieCount)
	if ieCount != 0 {
		t.Fatalf("payable edit should not create I&E, got %d", ieCount)
	}
}

func TestLaborOpeningAndTallyDoNotCreateIncomeExpense(t *testing.T) {
	const uid = uint(47)
	app, db := setupLaborIEApp(t, uid)

	code, _ := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Ramu",
		"mobile":     "9333333333",
		"wage":       5000,
		"hours":      1,
		"entry_kind": "opening",
		"date":       "2026-09-01",
		"narration":  "Opening Balance",
		"category":   "Opening Balance",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	if code != 201 {
		t.Fatalf("opening status=%d", code)
	}
	code, _ = laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Ramu",
		"mobile":     "9333333333",
		"wage":       0,
		"hours":      1,
		"entry_kind": "tally",
		"date":       "2026-09-20",
		"narration":  "Settled up to today",
		"category":   "Tally",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	if code != 201 {
		t.Fatalf("tally status=%d", code)
	}
	var ieCount int64
	db.Model(&models.IncomeExpense{}).Where("user_id = ?", uid).Count(&ieCount)
	if ieCount != 0 {
		t.Fatalf("opening/tally must not create I&E, got %d", ieCount)
	}
}

func TestLaborChangePaymentToPayableRemovesIncomeExpense(t *testing.T) {
	const uid = uint(48)
	app, db := setupLaborIEApp(t, uid)

	_, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Ravi",
		"mobile":     "9444444444",
		"wage":       800,
		"hours":      1,
		"entry_kind": "payment",
		"date":       "2026-09-12",
		"category":   "Payment",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	data := laborIEData(t, body)
	laborID := laborIEID(t, data)
	ieID := uint(data["income_expense_id"].(float64))

	code, _ := laborIEReq(t, app, "PUT", "/api/labors/"+laborID, map[string]any{
		"name":       "Ravi",
		"mobile":     "9444444444",
		"wage":       800,
		"hours":      1,
		"entry_kind": "payable",
		"date":       "2026-09-12",
		"category":   "Weeding",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	if code != 200 {
		t.Fatalf("kind change status=%d", code)
	}
	if _, found := findIEByID(t, db, ieID); found {
		t.Fatal("IE should be removed when payment becomes payable")
	}
	var labor models.Labor
	if err := db.First(&labor, laborID).Error; err != nil {
		t.Fatal(err)
	}
	if labor.IncomeExpenseID != nil {
		t.Fatalf("labor.income_expense_id should be cleared, got %v", *labor.IncomeExpenseID)
	}
}

func TestLaborChangePayableToPaymentCreatesIncomeExpense(t *testing.T) {
	const uid = uint(49)
	app, db := setupLaborIEApp(t, uid)

	_, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Gita",
		"mobile":     "9555555555",
		"wage":       600,
		"hours":      1,
		"entry_kind": "payable",
		"date":       "2026-09-13",
		"category":   "Weeding",
		"shift":      "fullday",
		"gender":     "Female",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	data := laborIEData(t, body)
	laborID := laborIEID(t, data)

	code, upd := laborIEReq(t, app, "PUT", "/api/labors/"+laborID, map[string]any{
		"name":       "Gita",
		"mobile":     "9555555555",
		"wage":       600,
		"hours":      1,
		"entry_kind": "payment",
		"date":       "2026-09-13",
		"category":   "Payment",
		"shift":      "fullday",
		"gender":     "Female",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	if code != 200 {
		t.Fatalf("kind change status=%d body=%v", code, upd)
	}
	updData := laborIEData(t, upd)
	ieRaw := updData["income_expense_id"]
	if ieRaw == nil {
		t.Fatalf("expected income_expense_id after converting to payment: %v", updData)
	}
	ieID := uint(ieRaw.(float64))
	ie, found := findIEByID(t, db, ieID)
	if !found {
		t.Fatal("IE not created when converting payable→payment")
	}
	if !ie.Amount.Equal(decimal.NewFromInt(600)) {
		t.Fatalf("IE amount=%s want 600", ie.Amount)
	}
}

func TestLaborSeedFromResetAndBalanceMath(t *testing.T) {
	// Pure calculation: opening credit/debit + later work/payment.
	p, d := laborSeedFromReset("opening", 3000)
	if p != 3000 || d != 0 {
		t.Fatalf("credit opening seed p=%v d=%v", p, d)
	}
	p, d = laborSeedFromReset("opening", -1500)
	if p != 0 || d != 1500 {
		t.Fatalf("debit opening seed p=%v d=%v", p, d)
	}
	p, d = laborSeedFromReset("tally", 0)
	if p != 0 || d != 0 {
		t.Fatalf("tally seed p=%v d=%v", p, d)
	}

	// Simulate post-reset ledger: seed 3000 payable, +1000 work, -1000 payment → balance 3000
	seedP, seedD := laborSeedFromReset("opening", 3000)
	work, paid := 1000.0, 1000.0
	bal := (seedP + work) - (seedD + paid)
	if bal != 3000 {
		t.Fatalf("balance=%v want 3000", bal)
	}
}

func TestIncomeExpenseUpdateSyncsLaborPayment(t *testing.T) {
	const uid = uint(50)
	app, db := setupLaborIEApp(t, uid)

	_, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Ramu",
		"mobile":     "9666666666",
		"wage":       2000,
		"hours":      1,
		"entry_kind": "payment",
		"date":       "2026-09-01",
		"category":   "Payment",
		"shift":      "fullday",
		"gender":     "Male",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	data := laborIEData(t, body)
	laborID := laborIEID(t, data)
	ieID := fmt.Sprint(uint(data["income_expense_id"].(float64)))

	code, _ := laborIEReq(t, app, "PUT", "/api/income_expense/"+ieID, map[string]any{
		"amount":    2750,
		"name":      "Ramu Updated",
		"mobile":    "9666666667",
		"date":      "2026-09-18",
		"narration": "Edited in I&E",
	})
	if code != 200 {
		t.Fatalf("IE update status=%d", code)
	}

	var labor models.Labor
	if err := db.First(&labor, laborID).Error; err != nil {
		t.Fatal(err)
	}
	if !labor.Wage.Equal(decimal.NewFromInt(2750)) {
		t.Fatalf("labor wage not synced from IE: %s", labor.Wage)
	}
	if labor.Name != "Ramu Updated" {
		t.Fatalf("labor name=%q", labor.Name)
	}
	if labor.Mobile == nil || *labor.Mobile != "9666666667" {
		t.Fatalf("labor mobile=%v", labor.Mobile)
	}
	if labor.Date.Format("2006-01-02") != "2026-09-18" {
		t.Fatalf("labor date=%v", labor.Date)
	}
	if labor.Narration != "Edited in I&E" {
		t.Fatalf("labor narration=%q", labor.Narration)
	}
}

func TestIncomeExpenseDeleteRemovesLaborPayment(t *testing.T) {
	const uid = uint(51)
	app, db := setupLaborIEApp(t, uid)

	_, body := laborIEReq(t, app, "POST", "/api/labors", map[string]any{
		"name":       "Suma",
		"mobile":     "9777777777",
		"wage":       1200,
		"hours":      1,
		"entry_kind": "payment",
		"date":       "2026-09-07",
		"category":   "Payment",
		"shift":      "fullday",
		"gender":     "Female",
		"work_type":  "Daily Wages",
		"location":   "Farm",
	})
	data := laborIEData(t, body)
	laborID := laborIEID(t, data)
	ieID := fmt.Sprint(uint(data["income_expense_id"].(float64)))

	code, _ := laborIEReq(t, app, "DELETE", "/api/income_expense/"+ieID, nil)
	if code != 200 {
		t.Fatalf("IE delete status=%d", code)
	}
	var labor models.Labor
	if err := db.First(&labor, laborID).Error; err != gorm.ErrRecordNotFound {
		t.Fatalf("linked labour payment should be deleted, err=%v", err)
	}
}
