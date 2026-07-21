package handler

import (
	"errors"
	"strconv"
	"strings"

	"erp.local/backend/models"
	"erp.local/backend/seeds"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var storefrontBannerDB *gorm.DB

func SetStorefrontBannerDB(db *gorm.DB) {
	storefrontBannerDB = db
}

func slotOrDefault(c *fiber.Ctx) string {
	s := strings.TrimSpace(c.Query("slot"))
	if s == "" {
		return "home"
	}
	return s
}

// GetStoreBannersPublic returns active slides for the storefront carousel (no auth).
func GetStoreBannersPublic(c *fiber.Ctx) error {
	slot := slotOrDefault(c)
	tid := tenantIDFromCtx(c)
	var rows []models.StorefrontBannerSlide
	err := storefrontBannerDB.
		Where("tenant_id = ? AND slot = ? AND is_active = ?", tid, slot, true).
		Order("sort_order ASC, id ASC").
		Find(&rows).Error
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if len(rows) == 0 {
		_ = seeds.EnsureStorefrontDefaultBannerFile()
		def := fiber.Map{
			"id":         0,
			"slot":       slot,
			"sort_order": 0,
			"image_url":  seeds.StorefrontDefaultHeroURL(),
			"title":      "Welcome to ARICA..!",
			"subtitle":   "Discover the charm of handcrafted elegance, made to adorn your space.",
			"cta_label":  "Explore Our Products",
			"cta_href":   "#featured-products",
			"is_active":  true,
			"is_default": true,
		}
		return c.JSON(fiber.Map{"data": []fiber.Map{def}})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func AdminListStorefrontBanners(c *fiber.Ctx) error {
	slot := slotOrDefault(c)
	tid := tenantIDFromCtx(c)
	var rows []models.StorefrontBannerSlide
	if err := storefrontBannerDB.
		Where("tenant_id = ? AND slot = ?", tid, slot).
		Order("sort_order ASC, id ASC").
		Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

type storefrontBannerCreateBody struct {
	Slot      string  `json:"slot"`
	SortOrder *int    `json:"sort_order"`
	ImageURL  string  `json:"image_url"`
	Title     *string `json:"title"`
	Subtitle  *string `json:"subtitle"`
	CTALabel  *string `json:"cta_label"`
	CTAHref   *string `json:"cta_href"`
	IsActive  *bool   `json:"is_active"`
}

func AdminCreateStorefrontBanner(c *fiber.Ctx) error {
	var body storefrontBannerCreateBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body", "details": err.Error()})
	}
	slot := strings.TrimSpace(body.Slot)
	if slot == "" {
		slot = "home"
	}
	img := strings.TrimSpace(body.ImageURL)
	if img == "" {
		return c.Status(400).JSON(fiber.Map{"error": "image_url is required"})
	}
	title := "Welcome to ARICA..!"
	if body.Title != nil && strings.TrimSpace(*body.Title) != "" {
		title = strings.TrimSpace(*body.Title)
	}
	sub := "Discover the charm of handcrafted elegance, made to adorn your space."
	if body.Subtitle != nil && strings.TrimSpace(*body.Subtitle) != "" {
		sub = strings.TrimSpace(*body.Subtitle)
	}
	cta := "Explore Our Products"
	if body.CTALabel != nil && strings.TrimSpace(*body.CTALabel) != "" {
		cta = strings.TrimSpace(*body.CTALabel)
	}
	href := "#products"
	if body.CTAHref != nil && strings.TrimSpace(*body.CTAHref) != "" {
		href = strings.TrimSpace(*body.CTAHref)
	}
	active := true
	if body.IsActive != nil {
		active = *body.IsActive
	}
	order := 0
	if body.SortOrder != nil {
		order = *body.SortOrder
	}
	tid := tenantIDFromCtx(c)
	if order == 0 {
		var last models.StorefrontBannerSlide
		err := storefrontBannerDB.Where("tenant_id = ? AND slot = ?", tid, slot).Order("sort_order DESC").First(&last).Error
		if err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				order = 10
			} else {
				return c.Status(500).JSON(fiber.Map{"error": err.Error()})
			}
		} else {
			order = last.SortOrder + 10
		}
	}
	row := models.StorefrontBannerSlide{
		TenantID:  tid,
		Slot:      slot,
		SortOrder: order,
		ImageURL:  img,
		Title:     title,
		Subtitle:  sub,
		CTALabel:  cta,
		CTAHref:   href,
		IsActive:  active,
	}
	if err := storefrontBannerDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

type storefrontBannerUpdateBody struct {
	ImageURL  *string `json:"image_url"`
	Title     *string `json:"title"`
	Subtitle  *string `json:"subtitle"`
	CTALabel  *string `json:"cta_label"`
	CTAHref   *string `json:"cta_href"`
	IsActive  *bool   `json:"is_active"`
	SortOrder *int    `json:"sort_order"`
}

func AdminUpdateStorefrontBanner(c *fiber.Ctx) error {
	id64, err := strconv.ParseUint(c.Params("id"), 10, 32)
	if err != nil || id64 == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	id := uint(id64)
	tid := tenantIDFromCtx(c)

	var body storefrontBannerUpdateBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body", "details": err.Error()})
	}

	var row models.StorefrontBannerSlide
	if err := storefrontBannerDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	updates := map[string]interface{}{}
	if body.ImageURL != nil {
		if s := strings.TrimSpace(*body.ImageURL); s != "" {
			updates["image_url"] = s
		}
	}
	if body.Title != nil {
		if s := strings.TrimSpace(*body.Title); s != "" {
			updates["title"] = s
		}
	}
	if body.Subtitle != nil {
		if s := strings.TrimSpace(*body.Subtitle); s != "" {
			updates["subtitle"] = s
		}
	}
	if body.CTALabel != nil {
		if s := strings.TrimSpace(*body.CTALabel); s != "" {
			updates["cta_label"] = s
		}
	}
	if body.CTAHref != nil {
		if s := strings.TrimSpace(*body.CTAHref); s != "" {
			updates["cta_href"] = s
		}
	}
	if body.IsActive != nil {
		updates["is_active"] = *body.IsActive
	}
	if body.SortOrder != nil {
		updates["sort_order"] = *body.SortOrder
	}
	if len(updates) == 0 {
		return c.JSON(fiber.Map{"data": row})
	}
	if err := storefrontBannerDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	storefrontBannerDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row)
	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteStorefrontBanner(c *fiber.Ctx) error {
	id64, err := strconv.ParseUint(c.Params("id"), 10, 32)
	if err != nil || id64 == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	id := uint(id64)
	tid := tenantIDFromCtx(c)
	res := storefrontBannerDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.StorefrontBannerSlide{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"ok": true})
}

type storefrontBannerReorderBody struct {
	Slot string `json:"slot"`
	IDs  []uint `json:"ids"`
}

func AdminReorderStorefrontBanners(c *fiber.Ctx) error {
	var body storefrontBannerReorderBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body", "details": err.Error()})
	}
	slot := strings.TrimSpace(body.Slot)
	if slot == "" {
		slot = "home"
	}
	if len(body.IDs) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "ids is required"})
	}
	tid := tenantIDFromCtx(c)
	if err := storefrontBannerDB.Transaction(func(tx *gorm.DB) error {
		for i, id := range body.IDs {
			if id == 0 {
				continue
			}
			order := (i + 1) * 10
			r := tx.Model(&models.StorefrontBannerSlide{}).
				Where("id = ? AND slot = ? AND tenant_id = ?", id, slot, tid).
				Update("sort_order", order)
			if r.Error != nil {
				return r.Error
			}
		}
		return nil
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}
