package handler

import (
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var appContentDB *gorm.DB

func SetAppContentDB(db *gorm.DB) {
	appContentDB = db
}

type appContentBody struct {
	MenuKey  string `json:"menu_key"`
	Title    string `json:"title"`
	Body     string `json:"body"`
	Locale   string `json:"locale"`
	IsActive *bool  `json:"is_active"`
}

// ListAppContentsPublic handles GET /api/app_contents (active only).
func ListAppContentsPublic(c *fiber.Ctx) error {
	var rows []models.AppContent
	q := appContentDB.Model(&models.AppContent{}).Where("is_active = ?", true)
	if loc := strings.TrimSpace(c.Query("locale")); loc != "" {
		q = q.Where("locale = ?", loc)
	}
	if err := q.Order("menu_key ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

// GetAppContentByKey handles GET /api/app_contents/:menu_key
func GetAppContentByKey(c *fiber.Ctx) error {
	key := strings.TrimSpace(c.Params("menu_key"))
	if key == "" {
		return c.Status(400).JSON(fiber.Map{"error": "menu_key is required"})
	}
	var row models.AppContent
	q := appContentDB.Where("menu_key = ?", key)
	// Public fetch prefers active; admin can pass include_inactive=1
	if c.Query("include_inactive") != "1" {
		q = q.Where("is_active = ?", true)
	}
	if loc := strings.TrimSpace(c.Query("locale")); loc != "" {
		q = q.Where("locale = ?", loc)
	}
	if err := q.First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Content not found"})
	}
	return c.JSON(row)
}

// AdminListAppContents handles GET /api/admin/app_contents
func AdminListAppContents(c *fiber.Ctx) error {
	var rows []models.AppContent
	q := appContentDB.Model(&models.AppContent{})
	if loc := strings.TrimSpace(c.Query("locale")); loc != "" {
		q = q.Where("locale = ?", loc)
	}
	if active := strings.TrimSpace(c.Query("active")); active != "" {
		switch strings.ToLower(active) {
		case "true", "1", "yes":
			q = q.Where("is_active = ?", true)
		case "false", "0", "no":
			q = q.Where("is_active = ?", false)
		}
	}
	if err := q.Order("menu_key ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

// AdminCreateAppContent handles POST /api/admin/app_contents
func AdminCreateAppContent(c *fiber.Ctx) error {
	var body appContentBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	key := strings.TrimSpace(body.MenuKey)
	if key == "" {
		return c.Status(400).JSON(fiber.Map{"error": "menu_key is required"})
	}
	locale := strings.TrimSpace(body.Locale)
	if locale == "" {
		locale = "en"
	}
	active := true
	if body.IsActive != nil {
		active = *body.IsActive
	}
	row := models.AppContent{
		MenuKey:  key,
		Title:    strings.TrimSpace(body.Title),
		Body:     body.Body,
		Locale:   locale,
		IsActive: active,
	}
	if err := appContentDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create", "details": err.Error()})
	}
	return c.Status(201).JSON(row)
}

// AdminUpdateAppContent handles PUT /api/admin/app_contents/:id
func AdminUpdateAppContent(c *fiber.Ctx) error {
	var row models.AppContent
	if err := appContentDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Content not found"})
	}
	var body appContentBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	updates := map[string]interface{}{}
	if k := strings.TrimSpace(body.MenuKey); k != "" {
		updates["menu_key"] = k
	}
	updates["title"] = strings.TrimSpace(body.Title)
	updates["body"] = body.Body
	if loc := strings.TrimSpace(body.Locale); loc != "" {
		updates["locale"] = loc
	}
	if body.IsActive != nil {
		updates["is_active"] = *body.IsActive
	}
	if err := appContentDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update", "details": err.Error()})
	}
	appContentDB.First(&row, row.ID)
	return c.JSON(row)
}

// AdminDeleteAppContent handles DELETE /api/admin/app_contents/:id
func AdminDeleteAppContent(c *fiber.Ctx) error {
	res := appContentDB.Delete(&models.AppContent{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Content not found"})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}
