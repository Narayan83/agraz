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

var validWorkTypes = map[string]bool{
	"Daily Wages": true,
	"Contract":    true,
}

var validGenders = map[string]bool{
	"Male":   true,
	"Female": true,
}

type laborPayload struct {
	Name            string  `json:"name"`
	Wage            float64 `json:"wage"`
	Hours           float64 `json:"hours"`
	NumberOfLabours int     `json:"number_of_labours"`
	Shift           string  `json:"shift"`
	Category        string  `json:"category"`
	Gender          string  `json:"gender"`
	WorkType        string  `json:"work_type"`
	LabourHead      string  `json:"labour_head"`
	Location        string  `json:"location"`
	Narration       string  `json:"narration"`
	// Date accepts RFC3339 and common Flutter layouts (with/without timezone).
	Date   flexibleTime `json:"date"`
	Mobile *string      `json:"mobile"`
}

// flexibleTime unmarshals common date strings Flutter may send.
type flexibleTime struct {
	time.Time
}

func (t *flexibleTime) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), `"`)
	if s == "" || s == "null" {
		t.Time = time.Time{}
		return nil
	}
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05.999999999Z07:00",
		"2006-01-02T15:04:05.999999",
		"2006-01-02T15:04:05",
		"2006-01-02 15:04:05",
		"2006-01-02",
	}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, s); err == nil {
			t.Time = parsed
			return nil
		}
	}
	return fiber.NewError(400, "invalid date format: "+s)
}

func validateLaborPayload(body *laborPayload) string {
	if strings.TrimSpace(body.Name) == "" {
		return "name is required"
	}
	if body.Wage <= 0 {
		return "rate (wage) must be greater than zero"
	}
	if body.Hours <= 0 {
		return "days/hour must be greater than zero"
	}
	if body.NumberOfLabours < 1 {
		body.NumberOfLabours = 1
	}
	shift := strings.TrimSpace(body.Shift)
	if shift == "" {
		return "shift is required"
	}
	body.Shift = shift
	if strings.TrimSpace(body.Category) == "" {
		return "category is required"
	}
	gender := strings.TrimSpace(body.Gender)
	if !validGenders[gender] {
		return "gender must be Male or Female"
	}
	body.Gender = gender
	workType := strings.TrimSpace(body.WorkType)
	if !validWorkTypes[workType] {
		return "work_type must be Daily Wages or Contract"
	}
	body.WorkType = workType
	body.LabourHead = strings.TrimSpace(body.LabourHead)
	if workType == "Contract" && body.LabourHead == "" {
		return "labour_head is required for Contract work type"
	}
	if workType == "Daily Wages" {
		body.LabourHead = ""
	}
	if strings.TrimSpace(body.Location) == "" {
		return "location is required"
	}
	// Narration is optional — trimmed value (possibly empty) is stored as-is.
	body.Narration = strings.TrimSpace(body.Narration)
	if body.Date.Time.IsZero() {
		return "date is required"
	}
	return ""
}

func applyLaborPayload(row *models.Labor, body *laborPayload) {
	row.Name = strings.TrimSpace(body.Name)
	row.Wage = decimal.NewFromFloat(body.Wage)
	row.Hours = decimal.NewFromFloat(body.Hours)
	row.NumberOfLabours = body.NumberOfLabours
	row.Shift = body.Shift
	row.Category = strings.TrimSpace(body.Category)
	row.Gender = body.Gender
	row.WorkType = body.WorkType
	row.LabourHead = body.LabourHead
	row.Location = strings.TrimSpace(body.Location)
	row.Narration = strings.TrimSpace(body.Narration)
	row.Date = body.Date.Time
	row.Mobile = body.Mobile
}

func CreateLabor(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body laborPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if msg := validateLaborPayload(&body); msg != "" {
		return c.Status(400).JSON(fiber.Map{"error": msg})
	}

	row := models.Labor{UserID: uid}
	applyLaborPayload(&row, &body)
	if err := laborDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create labor record", "details": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Laborer added successfully", "data": row})
}

func CreateLaborsBatch(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error":   "Login required",
			"message": "Login required",
		})
	}
	var bodies []laborPayload
	if err := c.BodyParser(&bodies); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"error":   "Invalid request body",
			"message": "Invalid request body",
			"details": err.Error(),
		})
	}
	if len(bodies) == 0 {
		return c.Status(400).JSON(fiber.Map{
			"error":   "at least one labour row is required",
			"message": "at least one labour row is required",
		})
	}

	rows := make([]models.Labor, 0, len(bodies))
	for i := range bodies {
		if msg := validateLaborPayload(&bodies[i]); msg != "" {
			return c.Status(400).JSON(fiber.Map{"error": msg, "message": msg, "row": i + 1})
		}
		row := models.Labor{UserID: uid}
		applyLaborPayload(&row, &bodies[i])
		rows = append(rows, row)
	}

	if err := laborDB.Create(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{
			"error":   "Failed to create labor records",
			"message": "Failed to create labor records",
			"details": err.Error(),
		})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Labourers added successfully", "data": rows})
}

func GetLabors(c *fiber.Ctx) error {
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

	var rows []models.Labor
	var total int64
	q := scopeByUserID(laborDB.Model(&models.Labor{}), uid)
	if m := c.Query("mobile"); m != "" {
		q = q.Where("mobile = ?", m)
	}
	if name := strings.TrimSpace(c.Query("name")); name != "" {
		q = q.Where("name ILIKE ?", "%"+name+"%")
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("name ILIKE ? OR COALESCE(mobile,'') ILIKE ? OR location ILIKE ? OR narration ILIKE ?", like, like, like, like)
	}
	if shift := c.Query("shift"); shift != "" {
		q = q.Where("shift = ?", shift)
	}
	if cat := c.Query("category"); cat != "" {
		q = q.Where("category ILIKE ?", "%"+cat+"%")
	}
	if workType := c.Query("work_type"); workType != "" {
		q = q.Where("work_type = ?", workType)
	}
	if location := c.Query("location"); location != "" {
		q = q.Where("location ILIKE ?", "%"+location+"%")
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
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.Labor
	if err := scopeByUserID(laborDB.Model(&models.Labor{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Labor record not found"})
	}
	return c.JSON(row)
}

func UpdateLabor(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body laborPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if msg := validateLaborPayload(&body); msg != "" {
		return c.Status(400).JSON(fiber.Map{"error": msg})
	}

	var row models.Labor
	if err := scopeByUserID(laborDB.Model(&models.Labor{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Labor record not found"})
	}

	applyLaborPayload(&row, &body)

	if err := laborDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update labor record", "details": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Labor record updated", "data": row})
}

func DeleteLabor(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(laborDB.Model(&models.Labor{}), uid).
		Delete(&models.Labor{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Labor record not found"})
	}
	return c.JSON(fiber.Map{"message": "Labor record deleted"})
}
