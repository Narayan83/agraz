package handler

import (
	"fmt"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var cmDB *gorm.DB

func SetContractManageDB(db *gorm.DB) {
	cmDB = db
}

func cmDec(v float64) decimal.Decimal {
	return decimal.NewFromFloat(v)
}

func cmParseDate(ft *flexibleTime) *time.Time {
	if ft == nil || ft.Time.IsZero() {
		return nil
	}
	t := ft.Time
	return &t
}

func cmDateOrNow(ft flexibleTime) time.Time {
	if ft.Time.IsZero() {
		return time.Now()
	}
	return ft.Time
}

// ---------- Projects ----------

type cmProjectPayload struct {
	Name          string        `json:"name"`
	Code          string        `json:"code"`
	Location      string        `json:"location"`
	Status        string        `json:"status"`
	CustomerID    *uint         `json:"customer_id"`
	StartDate     *flexibleTime `json:"start_date"`
	EndDate       *flexibleTime `json:"end_date"`
	EstimateAmt   float64       `json:"estimate_amt"`
	ContractAmt   float64       `json:"contract_amt"`
	CommissionPct float64       `json:"commission_pct"`
	Notes         string        `json:"notes"`
}

func ListCmProjects(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmProject{}), uid)
	if s := strings.TrimSpace(c.Query("status")); s != "" {
		q = q.Where("status = ?", s)
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR code ILIKE ? OR location ILIKE ?", like, like, like)
	}
	var rows []models.CmProject
	if err := q.Order("id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmProject(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmProjectPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "active"
	}
	row := models.CmProject{
		UserID:        uid,
		CustomerID:    body.CustomerID,
		Name:          name,
		Code:          strings.TrimSpace(body.Code),
		Location:      strings.TrimSpace(body.Location),
		Status:        status,
		StartDate:     cmParseDate(body.StartDate),
		EndDate:       cmParseDate(body.EndDate),
		EstimateAmt:   cmDec(body.EstimateAmt),
		ContractAmt:   cmDec(body.ContractAmt),
		CommissionPct: cmDec(body.CommissionPct),
		Notes:         strings.TrimSpace(body.Notes),
	}
	if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAuditProjectChange(uid, cmActor(c), "create", row)
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmProject(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmProject
	if err := scopeByUserID(cmDB.Model(&models.CmProject{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmProjectPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	row.Code = strings.TrimSpace(body.Code)
	row.Location = strings.TrimSpace(body.Location)
	if s := strings.TrimSpace(body.Status); s != "" {
		row.Status = s
	}
	row.CustomerID = body.CustomerID
	row.StartDate = cmParseDate(body.StartDate)
	row.EndDate = cmParseDate(body.EndDate)
	row.EstimateAmt = cmDec(body.EstimateAmt)
	row.ContractAmt = cmDec(body.ContractAmt)
	row.CommissionPct = cmDec(body.CommissionPct)
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAuditProjectChange(uid, cmActor(c), "update", row)
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmProject(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmProject
	if err := scopeByUserID(cmDB.Model(&models.CmProject{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err := cmDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAuditProjectChange(uid, cmActor(c), "delete", row)
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Customers ----------

type cmPartyPayload struct {
	Name     string  `json:"name"`
	Mobile   string  `json:"mobile"`
	Address  string  `json:"address"`
	Village  string  `json:"village"`
	Material string  `json:"material"`
	Notes    string  `json:"notes"`
	Skill    string  `json:"skill"`
	DailyWage float64 `json:"daily_wage"`
	SupplierID uint  `json:"supplier_id"`
	Unit     string  `json:"unit"`
	Category string  `json:"category"`
}

func ListCmCustomers(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmCustomer{}), uid)
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR mobile ILIKE ? OR village ILIKE ?", like, like, like)
	}
	var rows []models.CmCustomer
	if err := q.Order("name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmCustomer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row := models.CmCustomer{
		UserID:  uid,
		Name:    name,
		Mobile:  strings.TrimSpace(body.Mobile),
		Address: strings.TrimSpace(body.Address),
		Village: strings.TrimSpace(body.Village),
		Notes:   strings.TrimSpace(body.Notes),
	}
	if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmCustomer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmCustomer
	if err := scopeByUserID(cmDB.Model(&models.CmCustomer{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	row.Mobile = strings.TrimSpace(body.Mobile)
	row.Address = strings.TrimSpace(body.Address)
	row.Village = strings.TrimSpace(body.Village)
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmCustomer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(cmDB.Model(&models.CmCustomer{}), uid).Delete(&models.CmCustomer{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// Customer summary: projects + payments + stock at customer place
func GetCmCustomerSummary(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	cid := c.Params("id")
	var cust models.CmCustomer
	if err := scopeByUserID(cmDB.Model(&models.CmCustomer{}), uid).First(&cust, cid).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "customer not found"})
	}
	var projects []models.CmProject
	_ = scopeByUserID(cmDB.Model(&models.CmProject{}), uid).Where("customer_id = ?", cust.ID).Order("id DESC").Find(&projects).Error

	var payments []models.CmPayment
	_ = scopeByUserID(cmDB.Model(&models.CmPayment{}), uid).
		Where("party_type = ? AND party_id = ?", "customer", cust.ID).
		Order("entry_date DESC").Find(&payments).Error

	type stockRow struct {
		MaterialID   uint            `json:"material_id"`
		MaterialName string          `json:"material_name"`
		Unit         string          `json:"unit"`
		Quantity     decimal.Decimal `json:"quantity"`
		ProjectID    *uint           `json:"project_id,omitempty"`
	}
	var stocks []stockRow
	rows, err := cmDB.Raw(`
		SELECT b.material_id, COALESCE(m.name,'') AS material_name, COALESCE(m.unit,'') AS unit,
		       b.quantity, b.project_id
		FROM cm_stock_balances b
		LEFT JOIN cm_materials m ON m.id = b.material_id
		WHERE b.user_id = ? AND b.location_type = 'customer' AND b.customer_id = ?
		ORDER BY m.name ASC
	`, uid, cust.ID).Rows()
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var s stockRow
			_ = rows.Scan(&s.MaterialID, &s.MaterialName, &s.Unit, &s.Quantity, &s.ProjectID)
			stocks = append(stocks, s)
		}
	}

	recvOpen := decimal.Zero
	recvPaid := decimal.Zero
	comm := decimal.Zero
	for _, p := range payments {
		switch p.Kind {
		case "receivable":
			recvOpen = recvOpen.Add(p.Amount.Sub(p.PaidAmount))
			recvPaid = recvPaid.Add(p.PaidAmount)
		case "commission":
			comm = comm.Add(p.Amount)
		}
	}

	return c.JSON(fiber.Map{
		"customer": cust,
		"projects": projects,
		"payments": payments,
		"stock_at_site": stocks,
		"totals": fiber.Map{
			"receivable_open": recvOpen,
			"receivable_paid": recvPaid,
			"commission":      comm,
			"project_count":   len(projects),
		},
	})
}

// ---------- Dealers ----------

func ListCmDealers(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmDealer{}), uid)
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR mobile ILIKE ? OR material ILIKE ?", like, like, like)
	}
	var rows []models.CmDealer
	if err := q.Order("name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmDealer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row := models.CmDealer{
		UserID:   uid,
		Name:     name,
		Mobile:   strings.TrimSpace(body.Mobile),
		Address:  strings.TrimSpace(body.Address),
		Material: strings.TrimSpace(body.Material),
		Notes:    strings.TrimSpace(body.Notes),
	}
	if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmDealer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmDealer
	if err := scopeByUserID(cmDB.Model(&models.CmDealer{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	row.Mobile = strings.TrimSpace(body.Mobile)
	row.Address = strings.TrimSpace(body.Address)
	row.Material = strings.TrimSpace(body.Material)
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmDealer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(cmDB.Model(&models.CmDealer{}), uid).Delete(&models.CmDealer{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Labour suppliers ----------

func ListCmLabourSuppliers(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmLabourSupplier{}), uid)
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR mobile ILIKE ?", like, like)
	}
	var rows []models.CmLabourSupplier
	if err := q.Order("name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmLabourSupplier(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row := models.CmLabourSupplier{
		UserID:  uid,
		Name:    name,
		Mobile:  strings.TrimSpace(body.Mobile),
		Address: strings.TrimSpace(body.Address),
		Notes:   strings.TrimSpace(body.Notes),
	}
	if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmLabourSupplier(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmLabourSupplier
	if err := scopeByUserID(cmDB.Model(&models.CmLabourSupplier{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	row.Mobile = strings.TrimSpace(body.Mobile)
	row.Address = strings.TrimSpace(body.Address)
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmLabourSupplier(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(cmDB.Model(&models.CmLabourSupplier{}), uid).Delete(&models.CmLabourSupplier{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Labours ----------

func ListCmLabours(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmLabour{}), uid)
	if sid := c.QueryInt("supplier_id", 0); sid > 0 {
		q = q.Where("supplier_id = ?", sid)
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR mobile ILIKE ? OR skill ILIKE ?", like, like, like)
	}
	var rows []models.CmLabour
	if err := q.Order("name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmLabour(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	if body.SupplierID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "supplier_id is required"})
	}
	var sup models.CmLabourSupplier
	if err := scopeByUserID(cmDB.Model(&models.CmLabourSupplier{}), uid).First(&sup, body.SupplierID).Error; err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid supplier_id"})
	}
	row := models.CmLabour{
		UserID:     uid,
		SupplierID: body.SupplierID,
		Name:       name,
		Mobile:     strings.TrimSpace(body.Mobile),
		Skill:      strings.TrimSpace(body.Skill),
		DailyWage:  cmDec(body.DailyWage),
		Notes:      strings.TrimSpace(body.Notes),
	}
	if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmLabour(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmLabour
	if err := scopeByUserID(cmDB.Model(&models.CmLabour{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	if body.SupplierID > 0 {
		row.SupplierID = body.SupplierID
	}
	row.Mobile = strings.TrimSpace(body.Mobile)
	row.Skill = strings.TrimSpace(body.Skill)
	row.DailyWage = cmDec(body.DailyWage)
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmLabour(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(cmDB.Model(&models.CmLabour{}), uid).Delete(&models.CmLabour{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Materials ----------

func ListCmMaterials(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmMaterial{}), uid)
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR category ILIKE ?", like, like)
	}
	var rows []models.CmMaterial
	if err := q.Order("name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmMaterial(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	unit := strings.TrimSpace(body.Unit)
	if unit == "" {
		unit = "bag"
	}
	row := models.CmMaterial{
		UserID:   uid,
		Name:     name,
		Unit:     unit,
		Category: strings.TrimSpace(body.Category),
		Notes:    strings.TrimSpace(body.Notes),
	}
	if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmMaterial(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmMaterial
	if err := scopeByUserID(cmDB.Model(&models.CmMaterial{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmPartyPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	if u := strings.TrimSpace(body.Unit); u != "" {
		row.Unit = u
	}
	row.Category = strings.TrimSpace(body.Category)
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmMaterial(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(cmDB.Model(&models.CmMaterial{}), uid).Delete(&models.CmMaterial{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Purchases + stock ----------

type cmPurchaseItemPayload struct {
	MaterialID uint    `json:"material_id"`
	Quantity   float64 `json:"quantity"`
	Rate       float64 `json:"rate"`
	Amount     float64 `json:"amount"`
}

type cmPurchasePayload struct {
	DealerID      *uint                   `json:"dealer_id"`
	ProjectID     *uint                   `json:"project_id"`
	CustomerID    *uint                   `json:"customer_id"`
	PurchaseDate  flexibleTime            `json:"purchase_date"`
	InvoiceNo     string                  `json:"invoice_no"`
	StockLocation string                  `json:"stock_location"`
	TotalAmount   float64                 `json:"total_amount"`
	PaidAmount    float64                 `json:"paid_amount"`
	Notes         string                  `json:"notes"`
	Items         []cmPurchaseItemPayload `json:"items"`
}

func cmApplyStock(tx *gorm.DB, uid uint, materialID uint, loc string, customerID, projectID *uint, qty decimal.Decimal) error {
	q := tx.Where("user_id = ? AND material_id = ? AND location_type = ?", uid, materialID, loc)
	if loc == "customer" && customerID != nil {
		q = q.Where("customer_id = ?", *customerID)
	} else {
		q = q.Where("customer_id IS NULL")
	}
	if projectID != nil {
		q = q.Where("project_id = ?", *projectID)
	} else {
		q = q.Where("project_id IS NULL")
	}
	var bal models.CmStockBalance
	err := q.First(&bal).Error
	if err == gorm.ErrRecordNotFound {
		bal = models.CmStockBalance{
			UserID:       uid,
			MaterialID:   materialID,
			LocationType: loc,
			CustomerID:   customerID,
			ProjectID:    projectID,
			Quantity:     qty,
		}
		return tx.Create(&bal).Error
	}
	if err != nil {
		return err
	}
	bal.Quantity = bal.Quantity.Add(qty)
	return tx.Save(&bal).Error
}

func ListCmPurchases(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmPurchase{}), uid)
	if pid := c.QueryInt("project_id", 0); pid > 0 {
		q = q.Where("project_id = ?", pid)
	}
	if did := c.QueryInt("dealer_id", 0); did > 0 {
		q = q.Where("dealer_id = ?", did)
	}
	var rows []models.CmPurchase
	if err := q.Preload("Items").Order("purchase_date DESC, id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmPurchase(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmPurchasePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if len(body.Items) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "at least one item is required"})
	}
	loc := strings.TrimSpace(body.StockLocation)
	if loc == "" {
		loc = "own"
	}
	if loc != "own" && loc != "customer" {
		return c.Status(400).JSON(fiber.Map{"error": "stock_location must be own or customer"})
	}
	if loc == "customer" && (body.CustomerID == nil || *body.CustomerID == 0) {
		return c.Status(400).JSON(fiber.Map{"error": "customer_id required when stock is at customer place"})
	}

	total := decimal.Zero
	items := make([]models.CmPurchaseItem, 0, len(body.Items))
	for _, it := range body.Items {
		if it.MaterialID == 0 {
			return c.Status(400).JSON(fiber.Map{"error": "material_id required on items"})
		}
		qty := cmDec(it.Quantity)
		rate := cmDec(it.Rate)
		amt := cmDec(it.Amount)
		if amt.IsZero() {
			amt = qty.Mul(rate)
		}
		total = total.Add(amt)
		items = append(items, models.CmPurchaseItem{
			MaterialID: it.MaterialID,
			Quantity:   qty,
			Rate:       rate,
			Amount:     amt,
		})
	}
	if body.TotalAmount > 0 {
		total = cmDec(body.TotalAmount)
	}

	row := models.CmPurchase{
		UserID:        uid,
		DealerID:      body.DealerID,
		ProjectID:     body.ProjectID,
		CustomerID:    body.CustomerID,
		PurchaseDate:  cmDateOrNow(body.PurchaseDate),
		InvoiceNo:     strings.TrimSpace(body.InvoiceNo),
		StockLocation: loc,
		TotalAmount:   total,
		PaidAmount:    cmDec(body.PaidAmount),
		Notes:         strings.TrimSpace(body.Notes),
	}

	if err := cmDB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&row).Error; err != nil {
			return err
		}
		for i := range items {
			items[i].PurchaseID = row.ID
			if err := tx.Create(&items[i]).Error; err != nil {
				return err
			}
			custID := body.CustomerID
			if loc != "customer" {
				custID = nil
			}
			if err := cmApplyStock(tx, uid, items[i].MaterialID, loc, custID, body.ProjectID, items[i].Quantity); err != nil {
				return err
			}
		}
		row.Items = items

		// Auto payable to dealer for unpaid portion
		unpaid := row.TotalAmount.Sub(row.PaidAmount)
		if body.DealerID != nil && unpaid.IsPositive() {
			pay := models.CmPayment{
				UserID:     uid,
				ProjectID:  body.ProjectID,
				Kind:       "payable",
				PartyType:  "dealer",
				PartyID:    body.DealerID,
				EntryDate:  row.PurchaseDate,
				Amount:     unpaid,
				PaidAmount: decimal.Zero,
				Status:     "open",
				Notes:      "Auto from purchase #" + strings.TrimSpace(body.InvoiceNo),
			}
			if err := tx.Create(&pay).Error; err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func DeleteCmPurchase(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmPurchase
	if err := scopeByUserID(cmDB.Model(&models.CmPurchase{}), uid).Preload("Items").First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err := cmDB.Transaction(func(tx *gorm.DB) error {
		for _, it := range row.Items {
			custID := row.CustomerID
			if row.StockLocation != "customer" {
				custID = nil
			}
			neg := it.Quantity.Neg()
			if err := cmApplyStock(tx, uid, it.MaterialID, row.StockLocation, custID, row.ProjectID, neg); err != nil {
				return err
			}
		}
		if err := tx.Where("purchase_id = ?", row.ID).Delete(&models.CmPurchaseItem{}).Error; err != nil {
			return err
		}
		return tx.Delete(&row).Error
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

func GetCmStockReport(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	loc := strings.TrimSpace(c.Query("location_type"))
	type row struct {
		ID           uint            `json:"id"`
		MaterialID   uint            `json:"material_id"`
		MaterialName string          `json:"material_name"`
		Unit         string          `json:"unit"`
		LocationType string          `json:"location_type"`
		CustomerID   *uint           `json:"customer_id,omitempty"`
		CustomerName string          `json:"customer_name"`
		ProjectID    *uint           `json:"project_id,omitempty"`
		ProjectName  string          `json:"project_name"`
		Quantity     decimal.Decimal `json:"quantity"`
	}
	sql := `
		SELECT b.id, b.material_id, COALESCE(m.name,'') AS material_name, COALESCE(m.unit,'') AS unit,
		       b.location_type, b.customer_id, COALESCE(c.name,'') AS customer_name,
		       b.project_id, COALESCE(p.name,'') AS project_name, b.quantity
		FROM cm_stock_balances b
		LEFT JOIN cm_materials m ON m.id = b.material_id
		LEFT JOIN cm_customers c ON c.id = b.customer_id
		LEFT JOIN cm_projects p ON p.id = b.project_id
		WHERE b.user_id = ?`
	args := []interface{}{uid}
	if loc != "" {
		sql += ` AND b.location_type = ?`
		args = append(args, loc)
	}
	sql += ` ORDER BY b.location_type, m.name`
	var out []row
	if err := cmDB.Raw(sql, args...).Scan(&out).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": out})
}

// ---------- Payments ----------

type cmPaymentPayload struct {
	ProjectID  *uint         `json:"project_id"`
	Kind       string        `json:"kind"`
	PartyType  string        `json:"party_type"`
	PartyID    *uint         `json:"party_id"`
	PartyName  string        `json:"party_name"`
	EntryDate  flexibleTime  `json:"entry_date"`
	DueDate    *flexibleTime `json:"due_date"`
	Amount     float64       `json:"amount"`
	PaidAmount float64       `json:"paid_amount"`
	Status     string        `json:"status"`
	Notes      string        `json:"notes"`
}

func ListCmPayments(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmPayment{}), uid)
	if k := strings.TrimSpace(c.Query("kind")); k != "" {
		q = q.Where("kind = ?", k)
	}
	if pt := strings.TrimSpace(c.Query("party_type")); pt != "" {
		q = q.Where("party_type = ?", pt)
	}
	if st := strings.TrimSpace(c.Query("status")); st != "" {
		q = q.Where("status = ?", st)
	}
	if pid := c.QueryInt("project_id", 0); pid > 0 {
		q = q.Where("project_id = ?", pid)
	}
	var rows []models.CmPayment
	if err := q.Order("entry_date DESC, id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmPayment(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmPaymentPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	kind := strings.TrimSpace(body.Kind)
	if kind == "" {
		return c.Status(400).JSON(fiber.Map{"error": "kind is required (receivable|payable|commission)"})
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "open"
	}
	row := models.CmPayment{
		UserID:     uid,
		ProjectID:  body.ProjectID,
		Kind:       kind,
		PartyType:  strings.TrimSpace(body.PartyType),
		PartyID:    body.PartyID,
		PartyName:  strings.TrimSpace(body.PartyName),
		EntryDate:  cmDateOrNow(body.EntryDate),
		DueDate:    cmParseDate(body.DueDate),
		Amount:     cmDec(body.Amount),
		PaidAmount: cmDec(body.PaidAmount),
		Status:     status,
		Notes:      strings.TrimSpace(body.Notes),
	}
  if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	cmAudit(uid, cmActor(c), "payment", row.ID, "create", fmt.Sprintf("Payment %s ₹%s", row.Kind, row.Amount.String()), row)
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmPayment(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmPayment
	if err := scopeByUserID(cmDB.Model(&models.CmPayment{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmPaymentPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if k := strings.TrimSpace(body.Kind); k != "" {
		row.Kind = k
	}
	row.ProjectID = body.ProjectID
	row.PartyType = strings.TrimSpace(body.PartyType)
	row.PartyID = body.PartyID
	row.PartyName = strings.TrimSpace(body.PartyName)
	if !body.EntryDate.Time.IsZero() {
		row.EntryDate = body.EntryDate.Time
	}
	row.DueDate = cmParseDate(body.DueDate)
	row.Amount = cmDec(body.Amount)
	row.PaidAmount = cmDec(body.PaidAmount)
	if s := strings.TrimSpace(body.Status); s != "" {
		row.Status = s
	}
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmPayment(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(cmDB.Model(&models.CmPayment{}), uid).Delete(&models.CmPayment{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Assets ----------

type cmAssetPayload struct {
	Name         string        `json:"name"`
	AssetType    string        `json:"asset_type"`
	PurchaseDate *flexibleTime `json:"purchase_date"`
	PurchaseAmt  float64       `json:"purchase_amt"`
	VendorName   string        `json:"vendor_name"`
	SerialNo     string        `json:"serial_no"`
	Status       string        `json:"status"`
	Notes        string        `json:"notes"`
}

func ListCmAssets(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(cmDB.Model(&models.CmAsset{}), uid)
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR asset_type ILIKE ? OR vendor_name ILIKE ?", like, like, like)
	}
	var rows []models.CmAsset
	if err := q.Order("id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateCmAsset(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body cmAssetPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "active"
	}
	row := models.CmAsset{
		UserID:       uid,
		Name:         name,
		AssetType:    strings.TrimSpace(body.AssetType),
		PurchaseDate: cmParseDate(body.PurchaseDate),
		PurchaseAmt:  cmDec(body.PurchaseAmt),
		VendorName:   strings.TrimSpace(body.VendorName),
		SerialNo:     strings.TrimSpace(body.SerialNo),
		Status:       status,
		Notes:        strings.TrimSpace(body.Notes),
	}
	if err := cmDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "created", "data": row})
}

func UpdateCmAsset(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.CmAsset
	if err := scopeByUserID(cmDB.Model(&models.CmAsset{}), uid).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body cmAssetPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	row.AssetType = strings.TrimSpace(body.AssetType)
	row.PurchaseDate = cmParseDate(body.PurchaseDate)
	row.PurchaseAmt = cmDec(body.PurchaseAmt)
	row.VendorName = strings.TrimSpace(body.VendorName)
	row.SerialNo = strings.TrimSpace(body.SerialNo)
	if s := strings.TrimSpace(body.Status); s != "" {
		row.Status = s
	}
	row.Notes = strings.TrimSpace(body.Notes)
	if err := cmDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "updated", "data": row})
}

func DeleteCmAsset(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(cmDB.Model(&models.CmAsset{}), uid).Delete(&models.CmAsset{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// Dashboard snapshot for hub screens
func GetCmDashboard(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	count := func(model interface{}) int64 {
		var n int64
		scopeByUserID(cmDB.Model(model), uid).Count(&n)
		return n
	}
	var recv, pay decimal.Decimal
	_ = cmDB.Raw(`SELECT COALESCE(SUM(amount - paid_amount),0) FROM cm_payments WHERE user_id=? AND kind='receivable' AND status<>'closed'`, uid).Scan(&recv)
	_ = cmDB.Raw(`SELECT COALESCE(SUM(amount - paid_amount),0) FROM cm_payments WHERE user_id=? AND kind='payable' AND status<>'closed'`, uid).Scan(&pay)
	return c.JSON(fiber.Map{
		"projects":         count(&models.CmProject{}),
		"customers":        count(&models.CmCustomer{}),
		"dealers":          count(&models.CmDealer{}),
		"labour_suppliers": count(&models.CmLabourSupplier{}),
		"labours":          count(&models.CmLabour{}),
		"materials":        count(&models.CmMaterial{}),
		"assets":           count(&models.CmAsset{}),
		"open_receivable":  recv,
		"open_payable":     pay,
	})
}
