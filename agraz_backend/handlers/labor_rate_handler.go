package handler

import (
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var laborRateDB *gorm.DB

func SetLaborRateDB(db *gorm.DB) {
	laborRateDB = db
}

// GetLaborRates handles GET /api/labor_rates?mobile=&name=
func GetLaborRates(c *fiber.Ctx) error {
	q := laborRateDB.Model(&models.LaborRate{})
	if m := strings.TrimSpace(c.Query("mobile")); m != "" {
		q = q.Where("mobile = ?", m)
	}
	if n := strings.TrimSpace(c.Query("name")); n != "" {
		q = q.Where("name ILIKE ?", "%"+n+"%")
	}
	var rows []models.LaborRate
	if err := q.Order("category ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

// UpsertLaborRates handles PUT /api/labor_rates — body: { mobile, name, rates: [{category, rate}, ...] }
func UpsertLaborRates(c *fiber.Ctx) error {
	var body struct {
		Mobile string `json:"mobile"`
		Name   string `json:"name"`
		Rates  []struct {
			Category string  `json:"category"`
			Rate     float64 `json:"rate"`
		} `json:"rates"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid JSON body"})
	}
	mobile := strings.TrimSpace(body.Mobile)
	if mobile == "" {
		return c.Status(400).JSON(fiber.Map{"error": "mobile is required"})
	}
	if len(body.Rates) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "rates are required"})
	}

	name := strings.TrimSpace(body.Name)
	out := make([]models.LaborRate, 0, len(body.Rates))
	for _, item := range body.Rates {
		cat := strings.TrimSpace(item.Category)
		if cat == "" {
			continue
		}
		if item.Rate < 0 {
			return c.Status(400).JSON(fiber.Map{"error": "rate must be >= 0 for " + cat})
		}
		var row models.LaborRate
		err := laborRateDB.Where("mobile = ? AND category = ?", mobile, cat).First(&row).Error
		if err != nil && err != gorm.ErrRecordNotFound {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		if err == gorm.ErrRecordNotFound {
			row = models.LaborRate{
				Mobile:   mobile,
				Name:     name,
				Category: cat,
				Rate:     decimal.NewFromFloat(item.Rate),
			}
			if err := laborRateDB.Create(&row).Error; err != nil {
				return c.Status(500).JSON(fiber.Map{"error": err.Error()})
			}
		} else {
			row.Rate = decimal.NewFromFloat(item.Rate)
			if name != "" {
				row.Name = name
			}
			if err := laborRateDB.Save(&row).Error; err != nil {
				return c.Status(500).JSON(fiber.Map{"error": err.Error()})
			}
		}
		out = append(out, row)
	}
	return c.JSON(fiber.Map{"message": "Rates saved", "data": out})
}
