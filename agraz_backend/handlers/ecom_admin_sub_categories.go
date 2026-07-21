package handler

import (
	"errors"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

type ecomSubCategoryCreateRequest struct {
	CategoryID  uint    `json:"category_id"`
	Name        string  `json:"name"`
	Slug        string  `json:"slug"`
	Description *string `json:"description"`
	Status      string  `json:"status"`
}

type ecomSubCategoryUpdateRequest struct {
	CategoryID  *uint   `json:"category_id"`
	Name        *string `json:"name"`
	Slug        *string `json:"slug"`
	Description *string `json:"description"`
	Status      *string `json:"status"`
}

func AdminGetSubCategories(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 10
	}
	offset := (page - 1) * limit

	categoryIDStr := c.Query("category_id", "")
	status := c.Query("status", "")
	q := c.Query("q", "")
	tid := tenantIDFromCtx(c)

	query := ecomDB.Model(&models.EcomSubCategory{}).Where("tenant_id = ?", tid)
	if categoryIDStr != "" {
		query = query.Where("category_id = ?", categoryIDStr)
	}
	if status != "" {
		query = query.Where("status = ?", status)
	}
	if q != "" {
		like := "%" + q + "%"
		query = query.Where("name ILIKE ? OR slug ILIKE ?", like, like)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var rows []models.EcomSubCategory
	if err := query.
		Order("id DESC").
		Limit(limit).
		Offset(offset).
		Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func AdminGetSubCategory(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var row models.EcomSubCategory
	if err := ecomDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "sub-category not found"})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminCreateSubCategory(c *fiber.Ctx) error {
	var body ecomSubCategoryCreateRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}
	if body.CategoryID == 0 || body.Name == "" || body.Slug == "" {
		return c.Status(400).JSON(fiber.Map{"error": "category_id, name, slug are required"})
	}
	if body.Status == "" {
		body.Status = "active"
	}

	tid := tenantIDFromCtx(c)
	var parent models.EcomCategory
	if err := ecomDB.Where("id = ? AND tenant_id = ?", body.CategoryID, tid).First(&parent).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(400).JSON(fiber.Map{"error": "category not found for this tenant"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	row := models.EcomSubCategory{
		TenantID:    tid,
		CategoryID:  body.CategoryID,
		Name:        body.Name,
		Slug:        body.Slug,
		Description: body.Description,
		Status:      body.Status,
	}

	if err := ecomDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateSubCategory(c *fiber.Ctx) error {
	var body ecomSubCategoryUpdateRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body"})
	}

	tid := tenantIDFromCtx(c)
	var row models.EcomSubCategory
	if err := ecomDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "sub-category not found"})
	}

	updates := map[string]interface{}{}
	if body.CategoryID != nil {
		var parent models.EcomCategory
		if err := ecomDB.Where("id = ? AND tenant_id = ?", *body.CategoryID, tid).First(&parent).Error; err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "category not found for this tenant"})
		}
		updates["category_id"] = *body.CategoryID
	}
	if body.Name != nil {
		updates["name"] = *body.Name
	}
	if body.Slug != nil {
		updates["slug"] = *body.Slug
	}
	if body.Description != nil {
		updates["description"] = body.Description
	}
	if body.Status != nil {
		updates["status"] = *body.Status
	}

	if len(updates) == 0 {
		return c.JSON(fiber.Map{"data": row})
	}

	if err := ecomDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteSubCategory(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var row models.EcomSubCategory
	if err := ecomDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "sub-category not found"})
	}

	newSlug := slugAfterSoftDelete(row.Slug, row.ID)
	if err := ecomDB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&row).Update("slug", newSlug).Error; err != nil {
			return err
		}
		return tx.Delete(&row).Error
	}); err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "sub-category not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "sub-category deleted"})
}

