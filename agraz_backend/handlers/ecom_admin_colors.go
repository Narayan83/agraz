package handler

import (
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

type ecomColorCreateRequest struct {
	Name    string  `json:"name"`
	HexCode string  `json:"hex_code"`
	Status  string  `json:"status"`
}

type ecomColorUpdateRequest struct {
	Name    *string `json:"name"`
	HexCode *string `json:"hex_code"`
	Status  *string `json:"status"`
}

func AdminGetColors(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 10
	}
	offset := (page - 1) * limit

	status := c.Query("status", "")
	tid := tenantIDFromCtx(c)
	q := ecomDB.Model(&models.EcomColor{}).Where("tenant_id = ?", tid)
	if status != "" {
		q = q.Where("status = ?", status)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var rows []models.EcomColor
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func AdminGetColor(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var row models.EcomColor
	if err := ecomDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "color not found"})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminCreateColor(c *fiber.Ctx) error {
	var body ecomColorCreateRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}
	if body.Name == "" || body.HexCode == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name and hex_code are required"})
	}
	if body.Status == "" {
		body.Status = "active"
	}

	row := models.EcomColor{
		TenantID: tenantIDFromCtx(c),
		Name:     body.Name, HexCode: body.HexCode, Status: body.Status,
	}
	if err := ecomDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateColor(c *fiber.Ctx) error {
	var body ecomColorUpdateRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}
	tid := tenantIDFromCtx(c)
	var row models.EcomColor
	if err := ecomDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "color not found"})
	}

	updates := map[string]interface{}{}
	if body.Name != nil {
		updates["name"] = *body.Name
	}
	if body.HexCode != nil {
		updates["hex_code"] = *body.HexCode
	}
	if body.Status != nil {
		updates["status"] = *body.Status
	}

	if len(updates) > 0 {
		if err := ecomDB.Model(&row).Updates(updates).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}

	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteColor(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var row models.EcomColor
	if err := ecomDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "color not found"})
	}
	if err := ecomDB.Delete(&row).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "color not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "color deleted"})
}

