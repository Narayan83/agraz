package handler

import (
	"strconv"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

type ecomCategoryCreateRequest struct {
	Name        string  `json:"name"`
	Slug        string  `json:"slug"`
	Description *string `json:"description"`
	ParentID    *uint   `json:"parent_id"`
	Image       *string `json:"image"`
	Status      string  `json:"status"`
}

type ecomCategoryUpdateRequest struct {
	Name        *string `json:"name"`
	Slug        *string `json:"slug"`
	Description *string `json:"description"`
	ParentID    *uint   `json:"parent_id"`
	Image       *string `json:"image"`
	Status      *string `json:"status"`
}

func AdminGetCategories(c *fiber.Ctx) error {
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
	q := c.Query("q", "")
	parentID := c.Query("parent_id", "")
	tid := tenantIDFromCtx(c)

	query := ecomDB.Model(&models.EcomCategory{}).Where("tenant_id = ?", tid)
	if status != "" {
		query = query.Where("status = ?", status)
	}
	if parentID != "" {
		query = query.Where("parent_id = ?", parentID)
	}
	if q != "" {
		like := "%" + q + "%"
		query = query.Where("name ILIKE ? OR slug ILIKE ?", like, like)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var rows []models.EcomCategory
	if err := query.
		Order("id DESC").
		Limit(limit).
		Offset(offset).
		Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func AdminGetCategory(c *fiber.Ctx) error {
	id := c.Params("id")
	tid := tenantIDFromCtx(c)
	var row models.EcomCategory
	if err := ecomDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "category not found"})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminCreateCategory(c *fiber.Ctx) error {
	var body ecomCategoryCreateRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}
	if body.Name == "" || body.Slug == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name and slug are required"})
	}
	if body.Status == "" {
		body.Status = "active"
	}

	row := models.EcomCategory{
		TenantID:    tenantIDFromCtx(c),
		Name:        body.Name,
		Slug:        body.Slug,
		Description: body.Description,
		ParentID:    body.ParentID,
		Image:       body.Image,
		Status:      body.Status,
	}

	if err := ecomDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateCategory(c *fiber.Ctx) error {
	id := c.Params("id")

	var body ecomCategoryUpdateRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}

	tid := tenantIDFromCtx(c)
	var row models.EcomCategory
	if err := ecomDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "category not found"})
	}

	updates := map[string]interface{}{}
	if body.Name != nil {
		updates["name"] = *body.Name
	}
	if body.Slug != nil {
		updates["slug"] = *body.Slug
	}
	if body.Description != nil {
		updates["description"] = body.Description
	}
	if body.ParentID != nil {
		updates["parent_id"] = body.ParentID
	}
	if body.Image != nil {
		updates["image"] = body.Image
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

func AdminDeleteCategory(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := strconv.Atoi(idStr)
	if err != nil || id <= 0 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}

	tid := tenantIDFromCtx(c)
	var row models.EcomCategory
	if err := ecomDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "category not found"})
	}

	newSlug := slugAfterSoftDelete(row.Slug, row.ID)
	if err := ecomDB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&row).Update("slug", newSlug).Error; err != nil {
			return err
		}
		return tx.Delete(&row).Error
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "category deleted"})
}

