package handler

import (
	"encoding/json"
	"fmt"
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

func cmAudit(uid, actor uint, entity string, entityID uint, action, summary string, detail any) {
	if cmDB == nil {
		return
	}
	var det string
	if detail != nil {
		if b, err := json.Marshal(detail); err == nil {
			det = string(b)
		}
	}
	_ = cmDB.Create(&models.CmAuditLog{
		UserID:     uid,
		ActorID:    actor,
		EntityType: entity,
		EntityID:   entityID,
		Action:     action,
		Summary:    summary,
		Detail:     det,
	}).Error
}

func cmActor(c *fiber.Ctx) uint {
	id, err := actorUserID(c)
	if err != nil {
		return 0
	}
	return id
}

// ---------- Labour works (site deployment) ----------

type cmLabourWorkPayload struct {
	ProjectID  uint         `json:"project_id"`
	SupplierID uint         `json:"supplier_id"`
	WorkDate   flexibleTime `json:"work_date"`
	MenCount   int          `json:"men_count"`
	WomenCount int          `json:"women_count"`
	MenRate    float64      `json:"men_rate"`
	WomenRate  float64      `json:"women_rate"`
	DaysWorked float64      `json:"days_worked"`
	Amount     float64      `json:"amount"`
	PaidAmount float64      `json:"paid_amount"`
	ExtraPaid  float64      `json:"extra_paid"`
	Status     string       `json:"status"`
	Notes      string       `json:"notes"`
}

func cmCalcLabourAmount(men, women int, menRate, womenRate, days float64) decimal.Decimal {
	if days <= 0 {
		days = 1
	}
	raw := (float64(men)*menRate + float64(women)*womenRate) * days
	return cmDec(raw)
}

func ListCmLabourWorks(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmLabourWork{}), uid)
	if pid := c.QueryInt("project_id", 0); pid > 0 {
		q = q.Where("project_id = ?", pid)
	}
	if sid := c.QueryInt("supplier_id", 0); sid > 0 {
		q = q.Where("supplier_id = ?", sid)
	}
	var rows []models.CmLabourWork
	if err := q.Order("work_date DESC, id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmLabourWork(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmLabourWorkPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if body.ProjectID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "project_id is required"})
	}
	if body.SupplierID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "supplier_id (labour lead) is required"})
	}
	if body.MenCount < 0 || body.WomenCount < 0 {
		return c.Status(400).JSON(fiber.Map{"error": "counts cannot be negative"})
	}
	if body.MenCount+body.WomenCount == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "at least one man or woman labour is required"})
	}
	var proj models.CmProject
	if err := scopeByUserID(cmDB.Model(&models.CmProject{}), uid).First(&proj, body.ProjectID).Error; err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid project_id"})
	}
	var sup models.CmLabourSupplier
	if err := scopeByUserID(cmDB.Model(&models.CmLabourSupplier{}), uid).First(&sup, body.SupplierID).Error; err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid supplier_id"})
	}
	days := body.DaysWorked
	if days <= 0 {
		days = 1
	}
	amt := cmCalcLabourAmount(body.MenCount, body.WomenCount, body.MenRate, body.WomenRate, days)
	if body.Amount > 0 {
		amt = cmDec(body.Amount)
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "open"
	}
	row := models.CmLabourWork{
		UserID:     uid,
		ProjectID:  body.ProjectID,
		SupplierID: body.SupplierID,
		WorkDate:   cmDateOrNow(body.WorkDate),
		MenCount:   body.MenCount,
		WomenCount: body.WomenCount,
		MenRate:    cmDec(body.MenRate),
		WomenRate:  cmDec(body.WomenRate),
		DaysWorked: cmDec(days),
		Amount:     amt,
		PaidAmount: cmDec(body.PaidAmount),
		ExtraPaid:  cmDec(body.ExtraPaid),
		Status:     status,
		Notes:      strings.TrimSpace(body.Notes),
	}
	if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAudit(uid, cmActor(c), "labour_work", row.ID, "create",
		fmt.Sprintf("Labour work on project #%d: %d men + %d women", row.ProjectID, row.MenCount, row.WomenCount), row)
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmLabourWork(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmLabourWork
	if err := scopeByUserID(cmDB.Model(&models.CmLabourWork{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmLabourWorkPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if body.ProjectID > 0 {
		row.ProjectID = body.ProjectID
	}
	if body.SupplierID > 0 {
		row.SupplierID = body.SupplierID
	}
	if !body.WorkDate.Time.IsZero() {
		row.WorkDate = body.WorkDate.Time
	}
	row.MenCount = body.MenCount
	row.WomenCount = body.WomenCount
	row.MenRate = cmDec(body.MenRate)
	row.WomenRate = cmDec(body.WomenRate)
	days := body.DaysWorked
	if days <= 0 {
		days = 1
	}
	row.DaysWorked = cmDec(days)
	amt := cmCalcLabourAmount(body.MenCount, body.WomenCount, body.MenRate, body.WomenRate, days)
	if body.Amount > 0 {
		amt = cmDec(body.Amount)
	}
	row.Amount = amt
	row.PaidAmount = cmDec(body.PaidAmount)
	row.ExtraPaid = cmDec(body.ExtraPaid)
	if s := strings.TrimSpace(body.Status); s != "" {
		row.Status = s
	}
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAudit(uid, cmActor(c), "labour_work", row.ID, "update", "Labour work updated", row)
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmLabourWork(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmLabourWork
	if err := scopeByUserID(cmDB.Model(&models.CmLabourWork{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err := cmDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAudit(uid, cmActor(c), "labour_work", row.ID, "delete", "Labour work deleted", row)
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Stock issues ----------

type cmStockIssuePayload struct {
	ProjectID    uint         `json:"project_id"`
	MaterialID   uint         `json:"material_id"`
	CustomerID   *uint        `json:"customer_id"`
	IssueDate    flexibleTime `json:"issue_date"`
	Quantity     float64      `json:"quantity"`
	FromLocation string       `json:"from_location"`
	Purpose      string       `json:"purpose"`
	Notes        string       `json:"notes"`
}

func ListCmStockIssues(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmStockIssue{}), uid)
	if pid := c.QueryInt("project_id", 0); pid > 0 {
		q = q.Where("project_id = ?", pid)
	}
	var rows []models.CmStockIssue
	if err := q.Order("issue_date DESC, id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmStockIssue(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmStockIssuePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if body.ProjectID == 0 || body.MaterialID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "project_id and material_id are required"})
	}
	qty := cmDec(body.Quantity)
	if !qty.IsPositive() {
		return c.Status(400).JSON(fiber.Map{"error": "quantity must be > 0"})
	}
	from := strings.TrimSpace(body.FromLocation)
	if from == "" {
		from = "own"
	}
	purpose := strings.TrimSpace(body.Purpose)
	if purpose == "" {
		purpose = "site_use"
	}
	var proj models.CmProject
	if err := scopeByUserID(cmDB.Model(&models.CmProject{}), uid).First(&proj, body.ProjectID).Error; err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid project_id"})
	}
	custID := body.CustomerID
	if custID == nil {
		custID = proj.CustomerID
	}

	row := models.CmStockIssue{
		UserID:       uid,
		ProjectID:    body.ProjectID,
		MaterialID:   body.MaterialID,
		CustomerID:   custID,
		IssueDate:    cmDateOrNow(body.IssueDate),
		Quantity:     qty,
		FromLocation: from,
		Purpose:      purpose,
		Notes:        strings.TrimSpace(body.Notes),
	}

	if err := cmDB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&row).Error; err != nil {
			return err
		}
		// Deduct from source location
		srcCust := custID
		if from == "own" {
			srcCust = nil
		}
		if err := cmApplyStock(tx, uid, body.MaterialID, from, srcCust, &body.ProjectID, qty.Neg()); err != nil {
			return err
		}
		// If transferring to customer site, add there
		if purpose == "transfer_to_customer" {
			if custID == nil || *custID == 0 {
				return fiber.NewError(400, "customer_id required for transfer_to_customer")
			}
			if err := cmApplyStock(tx, uid, body.MaterialID, "customer", custID, &body.ProjectID, qty); err != nil {
				return err
			}
		}
		if purpose == "return_to_own" {
			if err := cmApplyStock(tx, uid, body.MaterialID, "own", nil, &body.ProjectID, qty); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		if e, ok := err.(*fiber.Error); ok {
			return c.Status(e.Code).JSON(fiber.Map{"error": e.Message})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAudit(uid, cmActor(c), "stock_issue", row.ID, "create",
		fmt.Sprintf("Stock issue project #%d material #%d qty %s", row.ProjectID, row.MaterialID, row.Quantity.String()), row)
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func DeleteCmStockIssue(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmStockIssue
	if err := scopeByUserID(cmDB.Model(&models.CmStockIssue{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err := cmDB.Transaction(func(tx *gorm.DB) error {
		srcCust := row.CustomerID
		if row.FromLocation == "own" {
			srcCust = nil
		}
		// reverse: add back to source
		if err := cmApplyStock(tx, uid, row.MaterialID, row.FromLocation, srcCust, &row.ProjectID, row.Quantity); err != nil {
			return err
		}
		if row.Purpose == "transfer_to_customer" {
			if err := cmApplyStock(tx, uid, row.MaterialID, "customer", row.CustomerID, &row.ProjectID, row.Quantity.Neg()); err != nil {
				return err
			}
		}
		if row.Purpose == "return_to_own" {
			if err := cmApplyStock(tx, uid, row.MaterialID, "own", nil, &row.ProjectID, row.Quantity.Neg()); err != nil {
				return err
			}
		}
		return tx.Delete(&row).Error
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAudit(uid, cmActor(c), "stock_issue", row.ID, "delete", "Stock issue deleted", row)
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Project end-to-end ledger ----------

func GetCmProject(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var proj models.CmProject
	if err := scopeByUserID(cmDB.Model(&models.CmProject{}), uid).First(&proj, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "project not found"})
	}
	var customer *models.CmCustomer
	if proj.CustomerID != nil {
		var cust models.CmCustomer
		if err := scopeByUserID(cmDB.Model(&models.CmCustomer{}), uid).First(&cust, *proj.CustomerID).Error; err == nil {
			customer = &cust
		}
	}
	return c.JSON(fiber.Map{"data": proj, "customer": customer})
}

func GetCmProjectLedger(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	pid := c.Params("id")
	var proj models.CmProject
	if err := scopeByUserID(cmDB.Model(&models.CmProject{}), uid).First(&proj, pid).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "project not found"})
	}

	var customer any
	if proj.CustomerID != nil {
		var cust models.CmCustomer
		if err := scopeByUserID(cmDB.Model(&models.CmCustomer{}), uid).First(&cust, *proj.CustomerID).Error; err == nil {
			customer = cust
		}
	}

	var works []models.CmLabourWork
	_ = scopeByUserID(cmDB.Model(&models.CmLabourWork{}), uid).Where("project_id = ?", proj.ID).Order("work_date DESC").Find(&works).Error

	var payments []models.CmPayment
	_ = scopeByUserID(cmDB.Model(&models.CmPayment{}), uid).Where("project_id = ?", proj.ID).Order("entry_date DESC").Find(&payments).Error

	var purchases []models.CmPurchase
	_ = scopeByUserID(cmDB.Model(&models.CmPurchase{}), uid).Where("project_id = ?", proj.ID).Preload("Items").Order("purchase_date DESC").Find(&purchases).Error

	var issues []models.CmStockIssue
	_ = scopeByUserID(cmDB.Model(&models.CmStockIssue{}), uid).Where("project_id = ?", proj.ID).Order("issue_date DESC").Find(&issues).Error

	menDays := 0
	womenDays := 0
	labourAmt := decimal.Zero
	labourPaid := decimal.Zero
	labourExtra := decimal.Zero
	for _, w := range works {
		d := int(w.DaysWorked.IntPart())
		if d < 1 {
			d = 1
		}
		menDays += w.MenCount * d
		womenDays += w.WomenCount * d
		labourAmt = labourAmt.Add(w.Amount)
		labourPaid = labourPaid.Add(w.PaidAmount)
		labourExtra = labourExtra.Add(w.ExtraPaid)
	}

	custAdvance := decimal.Zero
	custReceived := decimal.Zero
	dealerPaid := decimal.Zero
	labourLeadPaid := decimal.Zero
	commission := decimal.Zero
	for _, p := range payments {
		switch p.Kind {
		case "customer_advance":
			custAdvance = custAdvance.Add(p.PaidAmount)
			if p.PaidAmount.IsZero() {
				custAdvance = custAdvance.Add(p.Amount)
			}
		case "receivable", "customer_receipt":
			custReceived = custReceived.Add(p.PaidAmount)
		case "payable", "dealer_payment":
			dealerPaid = dealerPaid.Add(p.PaidAmount)
			if p.PaidAmount.IsZero() && p.Status == "closed" {
				dealerPaid = dealerPaid.Add(p.Amount)
			}
		case "labour_payment", "labour_extra":
			labourLeadPaid = labourLeadPaid.Add(p.PaidAmount)
			if p.PaidAmount.IsZero() && p.Status == "closed" {
				labourLeadPaid = labourLeadPaid.Add(p.Amount)
			}
			if p.Kind == "labour_extra" {
				labourExtra = labourExtra.Add(p.Amount)
			}
		case "commission":
			commission = commission.Add(p.Amount)
		}
	}

	purchaseTotal := decimal.Zero
	for _, p := range purchases {
		purchaseTotal = purchaseTotal.Add(p.TotalAmount)
	}

	return c.JSON(fiber.Map{
		"project":   proj,
		"customer":  customer,
		"labour_works": works,
		"payments":  payments,
		"purchases": purchases,
		"stock_issues": issues,
		"totals": fiber.Map{
			"men_labour_days":      menDays,
			"women_labour_days":    womenDays,
			"total_labour_count":   menDays + womenDays,
			"labour_amount":        labourAmt,
			"labour_paid":          labourPaid,
			"labour_balance":       labourAmt.Sub(labourPaid),
			"labour_extra":         labourExtra,
			"customer_advance":     custAdvance,
			"customer_received":    custReceived,
			"customer_total_in":    custAdvance.Add(custReceived),
			"dealer_paid":          dealerPaid,
			"labour_lead_paid":     labourLeadPaid,
			"commission":           commission,
			"purchase_total":       purchaseTotal,
			"contract_amt":         proj.ContractAmt,
			"open_receivable":      proj.ContractAmt.Sub(custAdvance.Add(custReceived)),
		},
	})
}

func ListCmAuditLogs(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmAuditLog{}), uid)
	if et := strings.TrimSpace(c.Query("entity_type")); et != "" {
		q = q.Where("entity_type = ?", et)
	}
	if eid := c.QueryInt("entity_id", 0); eid > 0 {
		q = q.Where("entity_id = ?", eid)
	}
	limit := c.QueryInt("limit", 100)
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	var rows []models.CmAuditLog
	if err := q.Order("id DESC").Limit(limit).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

// Hook audits into existing create/update/delete for projects (call from updated handlers).
func cmAuditProjectChange(uid, actor uint, action string, row models.CmProject) {
	cmAudit(uid, actor, "project", row.ID, action, fmt.Sprintf("Project %s (%s)", row.Name, row.Status), row)
}
