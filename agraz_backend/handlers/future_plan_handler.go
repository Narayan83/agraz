package handler

import (
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var futurePlanDB *gorm.DB

func SetFuturePlanDB(db *gorm.DB) {
	futurePlanDB = db
}

type futurePlanLinePayload struct {
	Description  string  `json:"description"`
	EstimateCost float64 `json:"estimate_cost"`
}

type futurePlanPayload struct {
	PlanName   string                  `json:"plan_name"`
	EntryDate  flexibleTime            `json:"entry_date"`
	PlanYear   int                     `json:"plan_year"`
	PlanMonth  *int                    `json:"plan_month"`
	LineCount  int                     `json:"line_count"`
	Status     string                  `json:"status"`
	EndDate    *flexibleTime           `json:"end_date"`
	ActualCost *float64                `json:"actual_cost"`
	Lines      []futurePlanLinePayload `json:"lines"`
}

func ListFuturePlans(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(futurePlanDB.Model(&models.FuturePlan{}), uid)
	if y := c.QueryInt("year", 0); y > 0 {
		q = q.Where("plan_year = ?", y)
	}
	if m := c.QueryInt("month", 0); m > 0 {
		q = q.Where("plan_month = ?", m)
	}
	if s := strings.TrimSpace(c.Query("status")); s != "" {
		q = q.Where("status = ?", s)
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		q = q.Where("plan_name ILIKE ?", "%"+search+"%")
	}
	var rows []models.FuturePlan
	if err := q.Preload("Lines", func(db *gorm.DB) *gorm.DB {
		return db.Order("line_no ASC")
	}).Order("entry_date DESC, id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func GetFuturePlan(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.FuturePlan
	if err := scopeByUserID(futurePlanDB.Model(&models.FuturePlan{}), uid).
		Preload("Lines", func(db *gorm.DB) *gorm.DB {
			return db.Order("line_no ASC")
		}).First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Plan not found"})
	}
	return c.JSON(row)
}

func CreateFuturePlan(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body futurePlanPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	name := strings.TrimSpace(body.PlanName)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "plan_name is required"})
	}
	if body.EntryDate.Time.IsZero() {
		body.EntryDate.Time = time.Now()
	}
	if body.PlanYear <= 0 {
		body.PlanYear = body.EntryDate.Time.Year()
	}
	planMonth := 0
	if body.PlanMonth != nil {
		planMonth = *body.PlanMonth
	}
	if planMonth < 0 || planMonth > 12 {
		return c.Status(400).JSON(fiber.Map{"error": "plan_month must be 0-12"})
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "planned"
	}
	lines := body.Lines
	if len(lines) == 0 && body.LineCount > 0 {
		lines = make([]futurePlanLinePayload, body.LineCount)
	}
	if len(lines) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "at least one line is required"})
	}

	row := models.FuturePlan{
		UserID:    uid,
		PlanName:  name,
		EntryDate: body.EntryDate.Time,
		PlanYear:  body.PlanYear,
		PlanMonth: planMonth,
		LineCount: len(lines),
		Status:    status,
	}
	if err := futurePlanDB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&row).Error; err != nil {
			return err
		}
		for i, ln := range lines {
			line := models.FuturePlanLine{
				PlanID:       row.ID,
				LineNo:       i + 1,
				Description:  strings.TrimSpace(ln.Description),
				EstimateCost: decimal.NewFromFloat(ln.EstimateCost),
			}
			if err := tx.Create(&line).Error; err != nil {
				return err
			}
			row.Lines = append(row.Lines, line)
		}
		return nil
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Plan created", "data": row})
}

func UpdateFuturePlan(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body futurePlanPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	var row models.FuturePlan
	if err := scopeByUserID(futurePlanDB.Model(&models.FuturePlan{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Plan not found"})
	}
	if n := strings.TrimSpace(body.PlanName); n != "" {
		row.PlanName = n
	}
	if !body.EntryDate.Time.IsZero() {
		row.EntryDate = body.EntryDate.Time
	}
	if body.PlanYear > 0 {
		row.PlanYear = body.PlanYear
	}
	if body.PlanMonth != nil {
		if *body.PlanMonth < 0 || *body.PlanMonth > 12 {
			return c.Status(400).JSON(fiber.Map{"error": "plan_month must be 0-12"})
		}
		row.PlanMonth = *body.PlanMonth
	}
	if s := strings.TrimSpace(body.Status); s != "" {
		row.Status = s
	}
	if body.EndDate != nil && !body.EndDate.Time.IsZero() {
		t := body.EndDate.Time
		row.EndDate = &t
	}
	if body.ActualCost != nil {
		d := decimal.NewFromFloat(*body.ActualCost)
		row.ActualCost = &d
	}

	if err := futurePlanDB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(&row).Error; err != nil {
			return err
		}
		if len(body.Lines) > 0 {
			if err := tx.Where("plan_id = ?", row.ID).Delete(&models.FuturePlanLine{}).Error; err != nil {
				return err
			}
			row.Lines = nil
			for i, ln := range body.Lines {
				line := models.FuturePlanLine{
					PlanID:       row.ID,
					LineNo:       i + 1,
					Description:  strings.TrimSpace(ln.Description),
					EstimateCost: decimal.NewFromFloat(ln.EstimateCost),
				}
				if err := tx.Create(&line).Error; err != nil {
					return err
				}
				row.Lines = append(row.Lines, line)
			}
			row.LineCount = len(body.Lines)
			return tx.Model(&row).Update("line_count", row.LineCount).Error
		}
		return nil
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = futurePlanDB.Preload("Lines", func(db *gorm.DB) *gorm.DB {
		return db.Order("line_no ASC")
	}).First(&row, row.ID)
	return c.JSON(fiber.Map{"message": "Plan updated", "data": row})
}

func DeleteFuturePlan(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(futurePlanDB.Model(&models.FuturePlan{}), uid).
		Delete(&models.FuturePlan{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Plan not found"})
	}
	return c.JSON(fiber.Map{"message": "Plan deleted"})
}
