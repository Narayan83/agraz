package handler

import (
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var laborWorkDB *gorm.DB

func SetLaborWorkDB(db *gorm.DB) {
	laborWorkDB = db
}

type laborWorkPayload struct {
	Name            string  `json:"name"`
	Wage            float64 `json:"wage"`
	Hours           float64 `json:"hours"`
	NumberOfLabours int     `json:"number_of_labours"`
	Shift           string  `json:"shift"`
	Category        string  `json:"category"`
	Gender          string  `json:"gender"`
	WorkType        string  `json:"work_type"`
	Location        string  `json:"location"`
	Narration       string  `json:"narration"`
	EntryKind       string  `json:"entry_kind"`
	Date            flexibleTime `json:"date"`
	Mobile          *string `json:"mobile"`
}

func normalizeLaborWorkKind(kind string) string {
	k := strings.ToLower(strings.TrimSpace(kind))
	if k == "" || k == "payable" {
		return "receivable"
	}
	if k == "payment" || k == "paid" {
		return "receipt"
	}
	return k
}

func validateLaborWorkPayload(body *laborWorkPayload) string {
	kind := normalizeLaborWorkKind(body.EntryKind)
	if kind != "receivable" && kind != "receipt" {
		return "entry_kind must be receivable or receipt"
	}
	body.EntryKind = kind
	if strings.TrimSpace(body.Name) == "" {
		return "name is required"
	}
	if body.Wage <= 0 {
		return "rate (wage) must be greater than zero"
	}
	if kind == "receipt" {
		if body.Hours <= 0 {
			body.Hours = 1
		}
		if strings.TrimSpace(body.Shift) == "" {
			body.Shift = "fullday"
		}
		if strings.TrimSpace(body.Category) == "" {
			body.Category = "Receipt"
		}
		if strings.TrimSpace(body.Gender) == "" {
			body.Gender = "Male"
		}
		if strings.TrimSpace(body.WorkType) == "" {
			body.WorkType = "Daily Wages"
		}
		if strings.TrimSpace(body.Location) == "" {
			body.Location = "Farm"
		}
	} else {
		if body.Hours <= 0 {
			return "days/hour must be greater than zero"
		}
		if strings.TrimSpace(body.Shift) == "" {
			return "shift is required"
		}
		if strings.TrimSpace(body.Category) == "" {
			return "category is required"
		}
		if strings.TrimSpace(body.Gender) == "" {
			body.Gender = "Male"
		}
		if strings.TrimSpace(body.WorkType) == "" {
			body.WorkType = "Daily Wages"
		}
		if strings.TrimSpace(body.Location) == "" {
			body.Location = "Farm"
		}
	}
	if body.NumberOfLabours < 1 {
		body.NumberOfLabours = 1
	}
	body.Narration = strings.TrimSpace(body.Narration)
	if body.Date.Time.IsZero() {
		return "date is required"
	}
	return ""
}

func applyLaborWorkPayload(row *models.LaborWorkEntry, body *laborWorkPayload) {
	row.Name = strings.TrimSpace(body.Name)
	row.Wage = decimal.NewFromFloat(body.Wage)
	row.Hours = decimal.NewFromFloat(body.Hours)
	row.NumberOfLabours = body.NumberOfLabours
	row.Shift = strings.TrimSpace(body.Shift)
	row.Category = strings.TrimSpace(body.Category)
	row.Gender = strings.TrimSpace(body.Gender)
	row.WorkType = strings.TrimSpace(body.WorkType)
	row.Location = strings.TrimSpace(body.Location)
	row.Narration = body.Narration
	row.Date = body.Date.Time
	row.Mobile = body.Mobile
	row.EntryKind = body.EntryKind
}

func CreateLaborWork(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body laborWorkPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if msg := validateLaborWorkPayload(&body); msg != "" {
		return c.Status(400).JSON(fiber.Map{"error": msg})
	}
	row := models.LaborWorkEntry{UserID: uid}
	applyLaborWorkPayload(&row, &body)
	if err := laborWorkDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Work entry created", "data": row})
}

func CreateLaborWorksBatch(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var bodies []laborWorkPayload
	if err := c.BodyParser(&bodies); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	if len(bodies) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "at least one row is required"})
	}
	rows := make([]models.LaborWorkEntry, 0, len(bodies))
	for i := range bodies {
		if msg := validateLaborWorkPayload(&bodies[i]); msg != "" {
			return c.Status(400).JSON(fiber.Map{"error": msg, "row": i + 1})
		}
		row := models.LaborWorkEntry{UserID: uid}
		applyLaborWorkPayload(&row, &bodies[i])
		if err := laborWorkDB.Create(&row).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error(), "row": i + 1})
		}
		rows = append(rows, row)
	}
	return c.Status(201).JSON(fiber.Map{"message": "Work entries created", "data": rows})
}

func GetLaborWorks(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 50)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 50
	}
	offset := (page - 1) * limit
	q := scopeByUserID(laborWorkDB.Model(&models.LaborWorkEntry{}), uid)
	if name := strings.TrimSpace(c.Query("name")); name != "" {
		q = q.Where("name ILIKE ?", "%"+name+"%")
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR narration ILIKE ? OR category ILIKE ?", like, like, like)
	}
	if ek := strings.TrimSpace(c.Query("entry_kind")); ek != "" {
		q = q.Where("entry_kind = ?", normalizeLaborWorkKind(ek))
	}
	if from := c.Query("from"); from != "" {
		q = q.Where("date >= ?", from)
	}
	if to := c.Query("to"); to != "" {
		q = q.Where("date <= ?", to)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var rows []models.LaborWorkEntry
	if err := q.Order("date DESC, id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetLaborWork(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.LaborWorkEntry
	if err := scopeByUserID(laborWorkDB.Model(&models.LaborWorkEntry{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Entry not found"})
	}
	return c.JSON(row)
}

func UpdateLaborWork(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body laborWorkPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	if msg := validateLaborWorkPayload(&body); msg != "" {
		return c.Status(400).JSON(fiber.Map{"error": msg})
	}
	var row models.LaborWorkEntry
	if err := scopeByUserID(laborWorkDB.Model(&models.LaborWorkEntry{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Entry not found"})
	}
	applyLaborWorkPayload(&row, &body)
	if err := laborWorkDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Entry updated", "data": row})
}

func DeleteLaborWork(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(laborWorkDB.Model(&models.LaborWorkEntry{}), uid).
		Delete(&models.LaborWorkEntry{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Entry not found"})
	}
	return c.JSON(fiber.Map{"message": "Entry deleted"})
}

// GetLaborWorkReportsPublic returns summary + list aggregates for self work entries.
func GetLaborWorkReportsPublic(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	base := scopeByUserID(laborWorkDB.Model(&models.LaborWorkEntry{}), uid)
	if name := strings.TrimSpace(c.Query("name")); name != "" {
		base = base.Where("name ILIKE ?", "%"+name+"%")
	}
	if from := c.Query("from"); from != "" {
		base = base.Where("date >= ?", from)
	}
	if to := c.Query("to"); to != "" {
		base = base.Where("date <= ?", to)
	}

	type sums struct {
		TotalReceivable float64 `gorm:"column:total_receivable"`
		TotalReceived   float64 `gorm:"column:total_received"`
		EntryCount      int64   `gorm:"column:entry_count"`
	}
	var s sums
	_ = base.Select(`
		COALESCE(SUM(CASE WHEN entry_kind = 'receivable' THEN wage * hours ELSE 0 END),0)::float8 as total_receivable,
		COALESCE(SUM(CASE WHEN entry_kind = 'receipt' THEN wage * hours ELSE 0 END),0)::float8 as total_received,
		COUNT(*) as entry_count
	`).Scan(&s)

	type monthRow struct {
		Month      string  `gorm:"column:month"`
		Receivable float64 `gorm:"column:receivable"`
		Received   float64 `gorm:"column:received"`
	}
	var monthly []monthRow
	_ = base.Select(`
		to_char(date, 'YYYY-MM') as month,
		COALESCE(SUM(CASE WHEN entry_kind = 'receivable' THEN wage * hours ELSE 0 END),0)::float8 as receivable,
		COALESCE(SUM(CASE WHEN entry_kind = 'receipt' THEN wage * hours ELSE 0 END),0)::float8 as received
	`).Group("to_char(date, 'YYYY-MM')").Order("month DESC").Limit(24).Scan(&monthly)

	return c.JSON(fiber.Map{
		"summary": fiber.Map{
			"total_receivable": s.TotalReceivable,
			"total_received":   s.TotalReceived,
			"balance":          s.TotalReceivable - s.TotalReceived,
			"entry_count":      s.EntryCount,
		},
		"monthly": monthly,
	})
}
