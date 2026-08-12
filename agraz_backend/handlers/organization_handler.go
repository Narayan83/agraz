package handler

import (
	"encoding/json"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var organizationDB *gorm.DB

func SetOrganizationDB(db *gorm.DB) {
	organizationDB = db
}

var defaultOrgNames = []string{"TSS", "TMS"}
var defaultLedgerNames = []string{
	"Saving Bank",
	"Vikri Account",
	"Assami Account",
	"Fixed Deposit",
	"Cash Certificate",
}

const savingBankLedgerName = "Saving Bank"

func ensureUserOrgDefaults(uid uint) error {
	for _, name := range defaultOrgNames {
		var n int64
		if err := organizationDB.Model(&models.Organization{}).
			Where("user_id = ? AND LOWER(name) = ?", uid, strings.ToLower(name)).
			Count(&n).Error; err != nil {
			return err
		}
		if n == 0 {
			if err := organizationDB.Create(&models.Organization{UserID: uid, Name: name}).Error; err != nil {
				return err
			}
		}
	}
	for _, name := range defaultLedgerNames {
		var n int64
		if err := organizationDB.Model(&models.OrgLedger{}).
			Where("user_id = ? AND LOWER(name) = ?", uid, strings.ToLower(name)).
			Count(&n).Error; err != nil {
			return err
		}
		if n == 0 {
			if err := organizationDB.Create(&models.OrgLedger{
				UserID:   uid,
				Name:     name,
				IsSystem: true,
			}).Error; err != nil {
				return err
			}
		}
	}
	return nil
}

func findSavingBankLedger(uid uint) (*models.OrgLedger, error) {
	var led models.OrgLedger
	err := organizationDB.Where("user_id = ? AND LOWER(name) = ?", uid, strings.ToLower(savingBankLedgerName)).
		First(&led).Error
	if err != nil {
		return nil, err
	}
	return &led, nil
}

func parseOrgDate(raw map[string]interface{}) (time.Time, error) {
	if ds, ok := raw["date"].(string); ok && strings.TrimSpace(ds) != "" {
		for _, layout := range []string{time.RFC3339, "2006-01-02T15:04:05.999999", "2006-01-02T15:04:05", "2006-01-02"} {
			if dt, err := time.Parse(layout, strings.TrimSpace(ds)); err == nil {
				return dt, nil
			}
		}
		return time.Time{}, fiber.NewError(400, "invalid date format")
	}
	return time.Now(), nil
}

func uintFromAny(v interface{}) (uint, bool) {
	switch t := v.(type) {
	case float64:
		if t <= 0 {
			return 0, false
		}
		return uint(t), true
	case json.Number:
		i, err := t.Int64()
		if err != nil || i <= 0 {
			return 0, false
		}
		return uint(i), true
	case int:
		if t <= 0 {
			return 0, false
		}
		return uint(t), true
	case int64:
		if t <= 0 {
			return 0, false
		}
		return uint(t), true
	case string:
		s := strings.TrimSpace(t)
		if s == "" {
			return 0, false
		}
		var n float64
		if _, err := json.Number(s).Float64(); err == nil {
			f, _ := json.Number(s).Float64()
			if f <= 0 {
				return 0, false
			}
			return uint(f), true
		}
		_ = n
	}
	return 0, false
}

// --- Organizations CRUD ---

func ListOrganizations(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	if err := ensureUserOrgDefaults(uid); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to init defaults", "details": err.Error()})
	}
	var rows []models.Organization
	if err := organizationDB.Where("user_id = ?", uid).Order("name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": len(rows)})
}

func CreateOrganization(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	var body struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row := models.Organization{UserID: uid, Name: name}
	if err := organizationDB.Create(&row).Error; err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "duplicate") || strings.Contains(err.Error(), "unique") {
			return c.Status(409).JSON(fiber.Map{"error": "Organization already exists"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func UpdateOrganization(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	var row models.Organization
	if err := organizationDB.Where("user_id = ?", uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Organization not found"})
	}
	var body struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row.Name = name
	if err := organizationDB.Save(&row).Error; err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "duplicate") || strings.Contains(err.Error(), "unique") {
			return c.Status(409).JSON(fiber.Map{"error": "Organization already exists"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func DeleteOrganization(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	var row models.Organization
	if err := organizationDB.Where("user_id = ?", uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Organization not found"})
	}
	var txnCount int64
	organizationDB.Model(&models.OrgTransaction{}).
		Where("user_id = ? AND (organization_id = ? OR transfer_to_organization_id = ?)", uid, row.ID, row.ID).
		Count(&txnCount)
	if txnCount > 0 {
		return c.Status(400).JSON(fiber.Map{"error": "Cannot delete organization with transactions"})
	}
	if err := organizationDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}

// --- Ledgers CRUD ---

func ListOrgLedgers(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	if err := ensureUserOrgDefaults(uid); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to init defaults", "details": err.Error()})
	}
	var rows []models.OrgLedger
	if err := organizationDB.Where("user_id = ?", uid).Order("is_system DESC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": len(rows)})
}

func CreateOrgLedger(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	var body struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row := models.OrgLedger{UserID: uid, Name: name, IsSystem: false}
	if err := organizationDB.Create(&row).Error; err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "duplicate") || strings.Contains(err.Error(), "unique") {
			return c.Status(409).JSON(fiber.Map{"error": "Ledger already exists"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func UpdateOrgLedger(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	var row models.OrgLedger
	if err := organizationDB.Where("user_id = ?", uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Ledger not found"})
	}
	var body struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row.Name = name
	if err := organizationDB.Save(&row).Error; err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "duplicate") || strings.Contains(err.Error(), "unique") {
			return c.Status(409).JSON(fiber.Map{"error": "Ledger already exists"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func DeleteOrgLedger(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	var row models.OrgLedger
	if err := organizationDB.Where("user_id = ?", uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Ledger not found"})
	}
	if row.IsSystem {
		return c.Status(400).JSON(fiber.Map{"error": "Cannot delete system ledger"})
	}
	var txnCount int64
	organizationDB.Model(&models.OrgTransaction{}).
		Where("user_id = ? AND ledger_id = ?", uid, row.ID).Count(&txnCount)
	if txnCount > 0 {
		return c.Status(400).JSON(fiber.Map{"error": "Cannot delete ledger with transactions"})
	}
	if err := organizationDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}

// --- Org transactions ---

func ListOrgTransactions(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	q := organizationDB.Model(&models.OrgTransaction{}).Where("user_id = ?", uid)
	if orgID := c.Query("organization_id"); orgID != "" {
		q = q.Where("organization_id = ?", orgID)
	}
	if ledID := c.Query("ledger_id"); ledID != "" {
		q = q.Where("ledger_id = ?", ledID)
	}
	if t := strings.TrimSpace(c.Query("type")); t != "" {
		q = q.Where("type = ?", t)
	}
	if m := strings.TrimSpace(c.Query("transaction_mode")); m != "" {
		q = q.Where("transaction_mode = ?", m)
	}
	if from := strings.TrimSpace(c.Query("from")); from != "" {
		q = q.Where("date >= ?", from)
	}
	if to := strings.TrimSpace(c.Query("to")); to != "" {
		q = q.Where("date < ?", to+" 23:59:59.999")
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var rows []models.OrgTransaction
	if err := q.Preload("Organization").Preload("Ledger").Preload("TransferToOrganization").
		Order("date DESC, id DESC").
		Offset((page - 1) * limit).Limit(limit).
		Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func CreateOrgTransaction(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	if err := ensureUserOrgDefaults(uid); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var raw map[string]interface{}
	if err := json.Unmarshal(c.Body(), &raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid JSON"})
	}

	typeStr, _ := raw["type"].(string)
	typeStr = strings.TrimSpace(typeStr)
	if typeStr != "Income" && typeStr != "Expense" {
		return c.Status(400).JSON(fiber.Map{"error": "type must be Income or Expense"})
	}
	mode, _ := raw["transaction_mode"].(string)
	if mode == "" {
		mode, _ = raw["transactionMode"].(string)
	}
	mode = strings.TrimSpace(mode)
	if mode == "" {
		mode = "Cash"
	}
	if mode != "Cash" && mode != "Transfer" {
		return c.Status(400).JSON(fiber.Map{"error": "transaction_mode must be Cash or Transfer"})
	}

	orgID, ok := uintFromAny(raw["organization_id"])
	if !ok {
		if v, ok2 := uintFromAny(raw["organizationId"]); ok2 {
			orgID, ok = v, true
		}
	}
	if !ok {
		return c.Status(400).JSON(fiber.Map{"error": "organization_id is required"})
	}
	ledID, ok := uintFromAny(raw["ledger_id"])
	if !ok {
		if v, ok2 := uintFromAny(raw["ledgerId"]); ok2 {
			ledID, ok = v, true
		}
	}
	if !ok {
		return c.Status(400).JSON(fiber.Map{"error": "ledger_id is required"})
	}
	amtF, ok := toFloat64(raw["amount"])
	if !ok || amtF <= 0 {
		return c.Status(400).JSON(fiber.Map{"error": "amount must be greater than 0"})
	}
	dt, err := parseOrgDate(raw)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	narr := strFromAny(raw["narration"])

	var org models.Organization
	if err := organizationDB.Where("user_id = ?", uid).First(&org, orgID).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Organization not found"})
	}
	var led models.OrgLedger
	if err := organizationDB.Where("user_id = ?", uid).First(&led, ledID).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Ledger not found"})
	}

	var transferToID *uint
	if mode == "Transfer" {
		toID, ok := uintFromAny(raw["transfer_to_organization_id"])
		if !ok {
			if v, ok2 := uintFromAny(raw["transferToOrganizationId"]); ok2 {
				toID, ok = v, true
			}
		}
		if !ok {
			return c.Status(400).JSON(fiber.Map{"error": "transfer_to_organization_id is required for Transfer"})
		}
		if toID == orgID {
			return c.Status(400).JSON(fiber.Map{"error": "Cannot transfer to the same organization"})
		}
		var dest models.Organization
		if err := organizationDB.Where("user_id = ?", uid).First(&dest, toID).Error; err != nil {
			return c.Status(404).JSON(fiber.Map{"error": "Transfer destination organization not found"})
		}
		transferToID = &toID
	}

	tx := organizationDB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	srcType := typeStr
	if mode == "Transfer" {
		// Transfer always leaves source org and enters destination Saving Bank.
		srcType = "Expense"
	}

	src := models.OrgTransaction{
		UserID:                   uid,
		OrganizationID:           orgID,
		LedgerID:                 ledID,
		Type:                     srcType,
		TransactionMode:          mode,
		TransferToOrganizationID: transferToID,
		Amount:                   amtF,
		Date:                     dt,
	}
	if narr != "" {
		src.Narration = &narr
	}

	// Cash + Expense → also mirror into income_expenses
	if mode == "Cash" && typeStr == "Expense" {
		ieNarr := narr
		if ieNarr == "" {
			ieNarr = "Organization expense: " + org.Name
		}
		ie := models.IncomeExpense{
			UserID:          uid,
			Type:            "Expense",
			Category:        "Organization Expense",
			SubCategory:     led.Name,
			Amount:          decimal.NewFromFloat(amtF),
			Mobile:          "",
			Date:            dt,
			Name:            org.Name,
			TransactionMode: "Cash",
			OrganizationID:  &orgID,
		}
		ie.Narration = &ieNarr
		if err := tx.Create(&ie).Error; err != nil {
			tx.Rollback()
			return c.Status(500).JSON(fiber.Map{"error": "Failed to create income/expense mirror", "details": err.Error()})
		}
		src.LinkedIncomeExpenseID = &ie.ID
	}

	if err := tx.Create(&src).Error; err != nil {
		tx.Rollback()
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create transaction", "details": err.Error()})
	}

	var counterpart *models.OrgTransaction
	if mode == "Transfer" && transferToID != nil {
		sb, err := findSavingBankLedger(uid)
		if err != nil {
			tx.Rollback()
			return c.Status(500).JSON(fiber.Map{"error": "Saving Bank ledger missing"})
		}
		destNarr := "Transfer from " + org.Name
		if narr != "" {
			destNarr = narr + " (from " + org.Name + ")"
		}
		cp := models.OrgTransaction{
			UserID:          uid,
			OrganizationID:  *transferToID,
			LedgerID:        sb.ID,
			Type:            "Income",
			TransactionMode: "Transfer",
			Amount:          amtF,
			Date:            dt,
			CounterpartTxnID: &src.ID,
		}
		cp.Narration = &destNarr
		// Destination receives into Saving Bank; no reverse transfer_to pointer.
		if err := tx.Create(&cp).Error; err != nil {
			tx.Rollback()
			return c.Status(500).JSON(fiber.Map{"error": "Failed to create transfer counterpart", "details": err.Error()})
		}
		src.CounterpartTxnID = &cp.ID
		if err := tx.Model(&src).Update("counterpart_txn_id", cp.ID).Error; err != nil {
			tx.Rollback()
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		counterpart = &cp
	}

	if err := tx.Commit().Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	organizationDB.Preload("Organization").Preload("Ledger").Preload("TransferToOrganization").First(&src, src.ID)
	resp := fiber.Map{"data": src, "message": "Transaction created"}
	if counterpart != nil {
		organizationDB.Preload("Organization").Preload("Ledger").First(counterpart, counterpart.ID)
		resp["counterpart"] = counterpart
	}
	return c.Status(201).JSON(resp)
}

func DeleteOrgTransaction(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	var row models.OrgTransaction
	if err := organizationDB.Where("user_id = ?", uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Transaction not found"})
	}
	tx := organizationDB.Begin()
	if row.CounterpartTxnID != nil {
		tx.Where("user_id = ? AND id = ?", uid, *row.CounterpartTxnID).Delete(&models.OrgTransaction{})
	}
	tx.Where("user_id = ? AND counterpart_txn_id = ?", uid, row.ID).Delete(&models.OrgTransaction{})
	if row.LinkedIncomeExpenseID != nil {
		tx.Where("user_id = ? AND id = ?", uid, *row.LinkedIncomeExpenseID).Delete(&models.IncomeExpense{})
	}
	if err := tx.Delete(&row).Error; err != nil {
		tx.Rollback()
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := tx.Commit().Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}

func GetOrgSummary(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	_ = ensureUserOrgDefaults(uid)

	type agg struct {
		Income  float64
		Expense float64
	}
	var a agg
	organizationDB.Model(&models.OrgTransaction{}).
		Select("COALESCE(SUM(CASE WHEN type = 'Income' THEN amount ELSE 0 END),0) as income, COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount ELSE 0 END),0) as expense").
		Where("user_id = ?", uid).
		Scan(&a)

	orgID := c.Query("organization_id")
	if orgID != "" {
		organizationDB.Model(&models.OrgTransaction{}).
			Select("COALESCE(SUM(CASE WHEN type = 'Income' THEN amount ELSE 0 END),0) as income, COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount ELSE 0 END),0) as expense").
			Where("user_id = ? AND organization_id = ?", uid, orgID).
			Scan(&a)
	}

	return c.JSON(fiber.Map{
		"income":  a.Income,
		"expense": a.Expense,
		"balance": a.Income - a.Expense,
	})
}

func GetOrgReports(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "Login required"})
	}
	_ = ensureUserOrgDefaults(uid)

	orgID := strings.TrimSpace(c.Query("organization_id"))
	ledgerID := strings.TrimSpace(c.Query("ledger_id"))
	from := strings.TrimSpace(c.Query("from"))
	to := strings.TrimSpace(c.Query("to"))

	base := organizationDB.Model(&models.OrgTransaction{}).Where("user_id = ?", uid)
	if orgID != "" {
		base = base.Where("organization_id = ?", orgID)
	}
	if ledgerID != "" {
		base = base.Where("ledger_id = ?", ledgerID)
	}
	if from != "" {
		base = base.Where("date >= ?", from)
	}
	if to != "" {
		base = base.Where("date < ?", to+" 23:59:59.999")
	}

	type tot struct {
		Income  float64 `json:"income"`
		Expense float64 `json:"expense"`
	}
	var overview tot
	base.Session(&gorm.Session{}).
		Select("COALESCE(SUM(CASE WHEN type = 'Income' THEN amount ELSE 0 END),0) as income, COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount ELSE 0 END),0) as expense").
		Scan(&overview)

	type monthRow struct {
		Month   string  `json:"month"`
		Income  float64 `json:"income"`
		Expense float64 `json:"expense"`
	}
	var monthly []monthRow
	base.Session(&gorm.Session{}).
		Select("to_char(date, 'YYYY-MM') as month, COALESCE(SUM(CASE WHEN type = 'Income' THEN amount ELSE 0 END),0) as income, COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount ELSE 0 END),0) as expense").
		Group("to_char(date, 'YYYY-MM')").
		Order("month ASC").
		Limit(24).
		Scan(&monthly)

	type weekRow struct {
		Week    string  `json:"week"`
		Income  float64 `json:"income"`
		Expense float64 `json:"expense"`
	}
	var weekly []weekRow
	base.Session(&gorm.Session{}).
		Select("to_char(date, 'IYYY-IW') as week, COALESCE(SUM(CASE WHEN type = 'Income' THEN amount ELSE 0 END),0) as income, COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount ELSE 0 END),0) as expense").
		Group("to_char(date, 'IYYY-IW')").
		Order("week ASC").
		Limit(24).
		Scan(&weekly)

	type orgBal struct {
		OrganizationID   uint    `json:"organization_id"`
		OrganizationName string  `json:"organization_name"`
		Income           float64 `json:"income"`
		Expense          float64 `json:"expense"`
		Balance          float64 `json:"balance"`
	}
	var orgBalances []orgBal
	organizationDB.Raw(`
		SELECT o.id as organization_id, o.name as organization_name,
			COALESCE(SUM(CASE WHEN t.type = 'Income' THEN t.amount ELSE 0 END),0) as income,
			COALESCE(SUM(CASE WHEN t.type = 'Expense' THEN t.amount ELSE 0 END),0) as expense,
			COALESCE(SUM(CASE WHEN t.type = 'Income' THEN t.amount ELSE 0 END),0) -
			COALESCE(SUM(CASE WHEN t.type = 'Expense' THEN t.amount ELSE 0 END),0) as balance
		FROM organizations o
		LEFT JOIN org_transactions t ON t.organization_id = o.id AND t.user_id = o.user_id
			AND (? = '' OR CAST(t.ledger_id AS TEXT) = ?)
			AND (? = '' OR t.date::date >= ?::date)
			AND (? = '' OR t.date::date <= ?::date)
		WHERE o.user_id = ?
		  AND (? = '' OR CAST(o.id AS TEXT) = ?)
		GROUP BY o.id, o.name
		ORDER BY o.name
	`, ledgerID, ledgerID, from, nullIfEmpty(from, "1900-01-01"), to, nullIfEmpty(to, "2999-12-31"), uid, orgID, orgID).Scan(&orgBalances)

	type ledBal struct {
		LedgerID   uint    `json:"ledger_id"`
		LedgerName string  `json:"ledger_name"`
		Income     float64 `json:"income"`
		Expense    float64 `json:"expense"`
		Balance    float64 `json:"balance"`
	}
	var ledgerBalances []ledBal
	organizationDB.Raw(`
		SELECT l.id as ledger_id, l.name as ledger_name,
			COALESCE(SUM(CASE WHEN t.type = 'Income' THEN t.amount ELSE 0 END),0) as income,
			COALESCE(SUM(CASE WHEN t.type = 'Expense' THEN t.amount ELSE 0 END),0) as expense,
			COALESCE(SUM(CASE WHEN t.type = 'Income' THEN t.amount ELSE 0 END),0) -
			COALESCE(SUM(CASE WHEN t.type = 'Expense' THEN t.amount ELSE 0 END),0) as balance
		FROM org_ledgers l
		LEFT JOIN org_transactions t ON t.ledger_id = l.id AND t.user_id = l.user_id
			AND (? = '' OR CAST(t.organization_id AS TEXT) = ?)
			AND (? = '' OR t.date::date >= ?::date)
			AND (? = '' OR t.date::date <= ?::date)
		WHERE l.user_id = ?
		  AND (? = '' OR CAST(l.id AS TEXT) = ?)
		GROUP BY l.id, l.name
		ORDER BY l.name
	`, orgID, orgID, from, nullIfEmpty(from, "1900-01-01"), to, nullIfEmpty(to, "2999-12-31"), uid, ledgerID, ledgerID).Scan(&ledgerBalances)

	return c.JSON(fiber.Map{
		"overview": fiber.Map{
			"income":  overview.Income,
			"expense": overview.Expense,
			"balance": overview.Income - overview.Expense,
		},
		"monthly":               monthly,
		"weekly":                weekly,
		"organization_balances": orgBalances,
		"ledger_balances":       ledgerBalances,
	})
}

func nullIfEmpty(v, fallback string) string {
	if strings.TrimSpace(v) == "" {
		return fallback
	}
	return v
}

// --- Admin ---

func AdminListOrganizations(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	q := organizationDB.Model(&models.Organization{})
	if uid := c.Query("user_id"); uid != "" {
		q = q.Where("user_id = ?", uid)
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		q = q.Where("name ILIKE ?", "%"+search+"%")
	}
	var total int64
	q.Count(&total)
	var rows []models.Organization
	q.Order("id DESC").Offset((page - 1) * limit).Limit(limit).Find(&rows)

	type rowOut struct {
		models.Organization
		UserName  string  `json:"user_name"`
		UserEmail string  `json:"user_email"`
		Balance   float64 `json:"balance"`
	}
	out := make([]rowOut, 0, len(rows))
	for _, r := range rows {
		item := rowOut{Organization: r}
		var u models.User
		if organizationDB.First(&u, r.UserID).Error == nil {
			item.UserName = strings.TrimSpace(u.Firstname + " " + u.Lastname)
			item.UserEmail = u.Email
		}
		var a struct{ Income, Expense float64 }
		organizationDB.Model(&models.OrgTransaction{}).
			Select("COALESCE(SUM(CASE WHEN type = 'Income' THEN amount ELSE 0 END),0) as income, COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount ELSE 0 END),0) as expense").
			Where("organization_id = ?", r.ID).Scan(&a)
		item.Balance = a.Income - a.Expense
		out = append(out, item)
	}
	return c.JSON(fiber.Map{"data": out, "total": total, "page": page, "limit": limit})
}

func AdminListOrgLedgers(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	q := organizationDB.Model(&models.OrgLedger{})
	if uid := c.Query("user_id"); uid != "" {
		q = q.Where("user_id = ?", uid)
	}
	var total int64
	q.Count(&total)
	var rows []models.OrgLedger
	q.Order("user_id ASC, is_system DESC, name ASC").Offset((page - 1) * limit).Limit(limit).Find(&rows)

	type rowOut struct {
		models.OrgLedger
		UserName  string `json:"user_name"`
		UserEmail string `json:"user_email"`
	}
	out := make([]rowOut, 0, len(rows))
	for _, r := range rows {
		item := rowOut{OrgLedger: r}
		var u models.User
		if organizationDB.First(&u, r.UserID).Error == nil {
			item.UserName = strings.TrimSpace(u.Firstname + " " + u.Lastname)
			item.UserEmail = u.Email
		}
		out = append(out, item)
	}
	return c.JSON(fiber.Map{"data": out, "total": total, "page": page, "limit": limit})
}

func AdminListOrgTransactions(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	q := organizationDB.Model(&models.OrgTransaction{})
	if uid := c.Query("user_id"); uid != "" {
		q = q.Where("user_id = ?", uid)
	}
	if orgID := c.Query("organization_id"); orgID != "" {
		q = q.Where("organization_id = ?", orgID)
	}
	if from := strings.TrimSpace(c.Query("from")); from != "" {
		q = q.Where("date >= ?", from)
	}
	if to := strings.TrimSpace(c.Query("to")); to != "" {
		q = q.Where("date < ?", to+" 23:59:59.999")
	}
	var total int64
	q.Count(&total)
	var rows []models.OrgTransaction
	q.Preload("Organization").Preload("Ledger").Preload("TransferToOrganization").
		Order("date DESC, id DESC").
		Offset((page - 1) * limit).Limit(limit).
		Find(&rows)

	type rowOut struct {
		models.OrgTransaction
		UserName  string `json:"user_name"`
		UserEmail string `json:"user_email"`
	}
	out := make([]rowOut, 0, len(rows))
	for _, r := range rows {
		item := rowOut{OrgTransaction: r}
		var u models.User
		if organizationDB.First(&u, r.UserID).Error == nil {
			item.UserName = strings.TrimSpace(u.Firstname + " " + u.Lastname)
			item.UserEmail = u.Email
		}
		out = append(out, item)
	}
	return c.JSON(fiber.Map{"data": out, "total": total, "page": page, "limit": limit})
}

// syncIETransferToOrg posts Transfer-mode I/E onto the org Saving Bank ledger.
func syncIETransferToOrg(uid uint, ie *models.IncomeExpense) {
	if ie == nil || ie.TransactionMode != "Transfer" || ie.OrganizationID == nil || organizationDB == nil {
		return
	}
	_ = ensureUserOrgDefaults(uid)
	sb, err := findSavingBankLedger(uid)
	if err != nil {
		return
	}
	amt, _ := ie.Amount.Float64()
	if amt <= 0 {
		return
	}
	narr := "From Income & Expense"
	if ie.Narration != nil && *ie.Narration != "" {
		narr = *ie.Narration
	}
	ot := models.OrgTransaction{
		UserID:                uid,
		OrganizationID:        *ie.OrganizationID,
		LedgerID:              sb.ID,
		Type:                  ie.Type,
		TransactionMode:       "Transfer",
		Amount:                amt,
		Date:                  ie.Date,
		LinkedIncomeExpenseID: &ie.ID,
		Narration:             &narr,
	}
	_ = organizationDB.Create(&ot).Error
}
