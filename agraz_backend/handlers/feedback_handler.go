package handler

import (
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var feedbackDB *gorm.DB

func SetFeedbackDB(db *gorm.DB) {
	feedbackDB = db
}

type feedbackCreateBody struct {
	Subject string `json:"subject"`
	Message string `json:"message"`
	Menu    string `json:"menu"`
}

func loadFeedbackUserMeta(uid uint) (name, email, phone string) {
	var u models.User
	if err := userDB.First(&u, uid).Error; err != nil {
		return "", "", ""
	}
	name = strings.TrimSpace(u.Firstname + " " + u.Lastname)
	if name == "" {
		name = strings.TrimSpace(u.Username)
	}
	email = strings.TrimSpace(u.Email)
	if u.MobileNumber != nil {
		phone = strings.TrimSpace(*u.MobileNumber)
	}
	return name, email, phone
}

// CreateFeedback handles POST /api/feedbacks (auth required).
func CreateFeedback(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body feedbackCreateBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	msg := strings.TrimSpace(body.Message)
	if msg == "" {
		return c.Status(400).JSON(fiber.Map{"error": "message is required"})
	}
	name, email, phone := loadFeedbackUserMeta(uid)
	row := models.AppFeedback{
		UserID:    uid,
		UserName:  name,
		UserEmail: email,
		UserPhone: phone,
		Subject:   strings.TrimSpace(body.Subject),
		Message:   msg,
		Menu:      strings.TrimSpace(body.Menu),
		Verified:  false,
	}
	if err := feedbackDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create feedback", "details": err.Error()})
	}
	return c.Status(201).JSON(row)
}

// ListMyFeedback handles GET /api/feedbacks — current user's feedbacks.
func ListMyFeedback(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	var rows []models.AppFeedback
	var total int64
	q := feedbackDB.Model(&models.AppFeedback{}).Where("user_id = ?", uid)
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

// ListAllFeedbackPublic handles GET /api/feedbacks/all — all feedbacks for app "see all".
func ListAllFeedbackPublic(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
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

	var rows []models.AppFeedback
	var total int64
	q := feedbackDB.Model(&models.AppFeedback{})
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

// AdminListFeedback handles GET /api/admin/feedbacks?verified=true|false|all
func AdminListFeedback(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 50)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 50
	}
	offset := (page - 1) * limit

	verified := strings.ToLower(strings.TrimSpace(c.Query("verified", "all")))
	q := feedbackDB.Model(&models.AppFeedback{})
	switch verified {
	case "true", "1", "yes":
		q = q.Where("verified = ?", true)
	case "false", "0", "no":
		q = q.Where("verified = ?", false)
	case "all", "":
		// no filter
	default:
		return c.Status(400).JSON(fiber.Map{"error": "verified must be true, false, or all"})
	}

	var rows []models.AppFeedback
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit, "verified": verified})
}

type feedbackVerifyBody struct {
	Verified bool `json:"verified"`
}

// AdminSetFeedbackVerified handles PATCH /api/admin/feedbacks/:id/verify
func AdminSetFeedbackVerified(c *fiber.Ctx) error {
	var body feedbackVerifyBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	var row models.AppFeedback
	if err := feedbackDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Feedback not found"})
	}
	updates := map[string]interface{}{"verified": body.Verified}
	if body.Verified {
		now := time.Now()
		updates["verified_at"] = &now
	} else {
		updates["verified_at"] = nil
	}
	if err := feedbackDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update", "details": err.Error()})
	}
	feedbackDB.First(&row, row.ID)
	return c.JSON(row)
}
