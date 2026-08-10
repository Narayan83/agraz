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
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := scopeByUserID(laborRateDB.Model(&models.LaborRate{}), uid)
	mobile := strings.TrimSpace(c.Query("mobile"))
	name := strings.TrimSpace(c.Query("name"))
	if mobile != "" {
		q = q.Where("mobile = ?", mobile)
		if name != "" {
			q = q.Where("name ILIKE ?", "%"+name+"%")
		}
	} else if name != "" {
		// Name-only lookups (no mobile on file) are scoped to the
		// mobile-less rows so they don't collide with a real mobile's rates.
		q = q.Where("mobile = ? AND name ILIKE ?", "", "%"+name+"%")
	}
	var rows []models.LaborRate
	if err := q.Order("category ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

// UpsertLaborRates handles PUT /api/labor_rates — body: { mobile, name, rates: [{category, rate}, ...] }
func UpsertLaborRates(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
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
	name := strings.TrimSpace(body.Name)
	if mobile == "" && name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "mobile or name is required"})
	}
	if len(body.Rates) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "rates are required"})
	}

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
		lookup := laborRateDB.Where("user_id = ? AND category = ?", uid, cat)
		if mobile != "" {
			lookup = lookup.Where("mobile = ?", mobile)
		} else {
			// No mobile on file — settings for this labourer live under the
			// mobile-less row for this category, matched by name.
			lookup = lookup.Where("mobile = ? AND name = ?", "", name)
		}
		err := lookup.First(&row).Error
		if err != nil && err != gorm.ErrRecordNotFound {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		if err == gorm.ErrRecordNotFound {
			row = models.LaborRate{
				UserID:   uid,
				Mobile:   mobile,
				Name:     name,
				Category: cat,
				Rate:     decimal.NewFromFloat(item.Rate),
			}
			if createErr := laborRateDB.Create(&row).Error; createErr != nil {
				if mobile == "" {
					// Unique (user_id, mobile, category) collision: another
					// mobile-less labourer already has a setting for this
					// category — reuse/overwrite that row instead of failing.
					var existing models.LaborRate
					if findErr := laborRateDB.Where(
						"user_id = ? AND mobile = ? AND category = ?", uid, "", cat,
					).First(&existing).Error; findErr == nil {
						existing.Name = name
						existing.Rate = decimal.NewFromFloat(item.Rate)
						if saveErr := laborRateDB.Save(&existing).Error; saveErr != nil {
							return c.Status(500).JSON(fiber.Map{"error": saveErr.Error()})
						}
						out = append(out, existing)
						continue
					}
				}
				return c.Status(500).JSON(fiber.Map{"error": createErr.Error()})
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
