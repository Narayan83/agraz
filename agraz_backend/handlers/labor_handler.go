package handler

import (
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var laborDB *gorm.DB

func SetLaborDB(db *gorm.DB) {
	laborDB = db
}

var validShifts = map[string]bool{
	"Morning":   true,
	"Afternoon": true,
	"Night":     true,
	"Full Day":  true,
}

type laborPayload struct {
	Name            string          `json:"name"`
	Wage            decimal.Decimal `json:"wage"`
	Hours           decimal.Decimal `json:"hours"`
	NumberOfLabours int             `json:"number_of_labours"`
	Shift           string          `json:"shift"`
	Category        string          `json:"category"`
	Narration       string          `json:"narration"`
	Date            time.Time       `json:"date"`
	Mobile          *string         `json:"mobile"`
}

func validateLaborPayload(body *laborPayload) string {
	if strings.TrimSpace(body.Name) == "" {
		return "name is required"
	}
	if body.Wage.LessThanOrEqual(decimal.Zero) {
		return "wage must be greater than zero"
	}
	if body.Hours.LessThanOrEqual(decimal.Zero) {
		return "hours must be greater than zero"
	}
	if body.NumberOfLabours < 1 {
		return "number_of_labours must be at least 1"
	}
	shift := strings.TrimSpace(body.Shift)
	if !validShifts[shift] {
		return "shift must be Morning, Afternoon, Night, or Full Day"
	}
	body.Shift = shift
	if strings.TrimSpace(body.Category) == "" {
		return "category is required"
	}
	if strings.TrimSpace(body.Narration) == "" {
		return "narration is required"
	}
	if body.Date.IsZero() {
		return "date is required"
	}
	return ""
}

func CreateLabor(c *fiber.Ctx) error {
	var body laborPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if msg := validateLaborPayload(&body); msg != "" {
		return c.Status(400).JSON(fiber.Map{"error": msg})
	}

	row := models.Labor{
		Name:            strings.TrimSpace(body.Name),
		Wage:            body.Wage,
		Hours:           body.Hours,
		NumberOfLabours: body.NumberOfLabours,
		Shift:           body.Shift,
		Category:        strings.TrimSpace(body.Category),
		Narration:       strings.TrimSpace(body.Narration),
		Date:            body.Date,
		Mobile:          body.Mobile,
	}
	if err := laborDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create labor record", "details": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Laborer added successfully", "data": row})
}

func GetLabors(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 50)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 50
	}
	offset := (page - 1) * limit

	var rows []models.Labor
	var total int64
	q := laborDB.Model(&models.Labor{})
	if m := c.Query("mobile"); m != "" {
		q = q.Where("mobile = ?", m)
	}
	if shift := c.Query("shift"); shift != "" {
		q = q.Where("shift = ?", shift)
	}
	if cat := c.Query("category"); cat != "" {
		q = q.Where("category ILIKE ?", "%"+cat+"%")
	}
	if from := c.Query("from"); from != "" {
		q = q.Where("date >= ?", from)
	}
	if to := c.Query("to"); to != "" {
		q = q.Where("date <= ?", to)
	}
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("date DESC, id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetLabor(c *fiber.Ctx) error {
	var row models.Labor
	if err := laborDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Labor record not found"})
	}
	return c.JSON(row)
}

func UpdateLabor(c *fiber.Ctx) error {
	var body laborPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if msg := validateLaborPayload(&body); msg != "" {
		return c.Status(400).JSON(fiber.Map{"error": msg})
	}

	var row models.Labor
	if err := laborDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Labor record not found"})
	}

	row.Name = strings.TrimSpace(body.Name)
	row.Wage = body.Wage
	row.Hours = body.Hours
	row.NumberOfLabours = body.NumberOfLabours
	row.Shift = body.Shift
	row.Category = strings.TrimSpace(body.Category)
	row.Narration = strings.TrimSpace(body.Narration)
	row.Date = body.Date
	row.Mobile = body.Mobile

	if err := laborDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update labor record", "details": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Labor record updated", "data": row})
}

func DeleteLabor(c *fiber.Ctx) error {
	res := laborDB.Delete(&models.Labor{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Labor record not found"})
	}
	return c.JSON(fiber.Map{"message": "Labor record deleted"})
}
