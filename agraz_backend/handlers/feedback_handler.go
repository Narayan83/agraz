package handler

import (
	"fmt"
	"regexp"
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

type feedbackUpdateBody struct {
	Subject  *string `json:"subject"`
	Message  *string `json:"message"`
	Menu     *string `json:"menu"`
	Verified *bool   `json:"verified"`
}

var surveyBracketPrefix = regexp.MustCompile(`(?s)^\s*\[[^\]]*\]\s*`)

// CleanSurveyMessage strips survey question prompts like "[What would you improve]" from imported text.
func CleanSurveyMessage(raw string) string {
	s := strings.TrimSpace(raw)
	for {
		next := surveyBracketPrefix.ReplaceAllString(s, "")
		if next == s {
			break
		}
		s = strings.TrimSpace(next)
	}
	return s
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
	q := feedbackDB.Model(&models.AppFeedback{}).Where("verified = ?", true)
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

// AdminUpdateFeedback handles PUT /api/admin/feedbacks/:id
func AdminUpdateFeedback(c *fiber.Ctx) error {
	var body feedbackUpdateBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	var row models.AppFeedback
	if err := feedbackDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Feedback not found"})
	}
	updates := map[string]interface{}{}
	if body.Subject != nil {
		updates["subject"] = strings.TrimSpace(*body.Subject)
	}
	if body.Message != nil {
		msg := CleanSurveyMessage(*body.Message)
		if msg == "" {
			return c.Status(400).JSON(fiber.Map{"error": "message is required"})
		}
		updates["message"] = msg
	}
	if body.Menu != nil {
		updates["menu"] = strings.TrimSpace(*body.Menu)
	}
	if body.Verified != nil {
		updates["verified"] = *body.Verified
		if *body.Verified {
			now := time.Now()
			updates["verified_at"] = &now
		} else {
			updates["verified_at"] = nil
		}
	}
	if len(updates) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "No fields to update"})
	}
	if err := feedbackDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update", "details": err.Error()})
	}
	feedbackDB.First(&row, row.ID)
	return c.JSON(row)
}

// AdminDeleteFeedback soft-deletes feedback and writes a deletion log entry.
func AdminDeleteFeedback(c *fiber.Ctx) error {
	adminID, _ := requireUserID(c)
	var row models.AppFeedback
	if err := feedbackDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Feedback not found"})
	}
	now := time.Now()
	logRow := models.AppFeedbackDeletionLog{
		FeedbackID:      row.ID,
		UserID:          row.UserID,
		UserName:        row.UserName,
		UserEmail:       row.UserEmail,
		UserPhone:       row.UserPhone,
		Subject:         row.Subject,
		Message:         row.Message,
		Menu:            row.Menu,
		Verified:        row.Verified,
		DeletedByUserID: adminID,
		DeletedAt:       now,
	}
	if err := feedbackDB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&logRow).Error; err != nil {
			return err
		}
		return tx.Delete(&row).Error
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to delete feedback", "details": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true, "deletion_log_id": logRow.ID, "feedback_id": row.ID})
}

// AdminListFeedbackDeletionLogs lists soft-deleted feedback logs that can be revoked.
func AdminListFeedbackDeletionLogs(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 50)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 50
	}
	offset := (page - 1) * limit

	onlyOpen := strings.ToLower(strings.TrimSpace(c.Query("open", "true")))
	q := feedbackDB.Model(&models.AppFeedbackDeletionLog{})
	if onlyOpen == "true" || onlyOpen == "1" || onlyOpen == "yes" {
		q = q.Where("restored_at IS NULL")
	}

	var rows []models.AppFeedbackDeletionLog
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

// AdminRevokeFeedbackDeletion restores a soft-deleted feedback from its deletion log.
func AdminRevokeFeedbackDeletion(c *fiber.Ctx) error {
	var logRow models.AppFeedbackDeletionLog
	if err := feedbackDB.First(&logRow, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Deletion log not found"})
	}
	if logRow.RestoredAt != nil {
		return c.Status(400).JSON(fiber.Map{"error": "This deletion was already revoked"})
	}

	var restored models.AppFeedback
	err := feedbackDB.Transaction(func(tx *gorm.DB) error {
		var existing models.AppFeedback
		findErr := tx.Unscoped().First(&existing, logRow.FeedbackID).Error
		if findErr == nil {
			if err := tx.Unscoped().Model(&existing).Update("deleted_at", nil).Error; err != nil {
				return err
			}
			restored = existing
			restored.DeletedAt = gorm.DeletedAt{}
		} else if findErr == gorm.ErrRecordNotFound {
			restored = models.AppFeedback{
				UserID:    logRow.UserID,
				UserName:  logRow.UserName,
				UserEmail: logRow.UserEmail,
				UserPhone: logRow.UserPhone,
				Subject:   logRow.Subject,
				Message:   logRow.Message,
				Menu:      logRow.Menu,
				Verified:  logRow.Verified,
			}
			if err := tx.Create(&restored).Error; err != nil {
				return err
			}
		} else {
			return findErr
		}
		now := time.Now()
		return tx.Model(&logRow).Update("restored_at", &now).Error
	})
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to revoke deletion", "details": err.Error()})
	}
	feedbackDB.First(&restored, restored.ID)
	return c.JSON(fiber.Map{"ok": true, "feedback": restored, "deletion_log_id": logRow.ID})
}

type appSurveyImportBody struct {
	Rows []map[string]interface{} `json:"rows"`
}

func pickSurveyString(row map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		if v, ok := row[key]; ok && v != nil {
			s := strings.TrimSpace(fmt.Sprint(v))
			if s != "" && s != "<nil>" {
				return s
			}
		}
	}
	return ""
}

func pickSurveyUint(row map[string]interface{}, keys ...string) uint {
	for _, key := range keys {
		if v, ok := row[key]; ok && v != nil {
			switch n := v.(type) {
			case float64:
				if n > 0 {
					return uint(n)
				}
			case int:
				if n > 0 {
					return uint(n)
				}
			case int64:
				if n > 0 {
					return uint(n)
				}
			case string:
				s := strings.TrimSpace(n)
				if s == "" {
					continue
				}
				var parsed uint
				if _, err := fmt.Sscanf(s, "%d", &parsed); err == nil && parsed > 0 {
					return parsed
				}
			}
		}
	}
	return 0
}

// AdminImportAppSurvey imports rows from JSON body and/or existing app_survey table.
// Survey question prompts in square brackets are stripped from messages.
func AdminImportAppSurvey(c *fiber.Ctx) error {
	var body appSurveyImportBody
	_ = c.BodyParser(&body)

	rows := body.Rows
	if len(rows) == 0 && feedbackDB.Migrator().HasTable("app_survey") {
		raw := []map[string]interface{}{}
		if err := feedbackDB.Table("app_survey").Find(&raw).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "Failed to read app_survey", "details": err.Error()})
		}
		rows = raw
	}
	if len(rows) == 0 {
		return c.Status(400).JSON(fiber.Map{
			"error": "No rows to import. Send {\"rows\":[...]} or create an app_survey table.",
		})
	}

	imported := 0
	skipped := 0
	for _, row := range rows {
		msg := CleanSurveyMessage(pickSurveyString(row,
			"message", "feedback", "comment", "answer", "response", "text", "content", "suggestion",
		))
		if msg == "" {
			skipped++
			continue
		}
		item := models.AppFeedback{
			UserID:    pickSurveyUint(row, "user_id", "userid", "uid"),
			UserName:  pickSurveyString(row, "user_name", "name", "username", "full_name"),
			UserEmail: pickSurveyString(row, "user_email", "email"),
			UserPhone: pickSurveyString(row, "user_phone", "phone", "mobile", "mobile_number"),
			Subject:   pickSurveyString(row, "subject", "title"),
			Message:   msg,
			Menu:      pickSurveyString(row, "menu", "screen", "page", "source"),
			Verified:  false,
		}
		if item.Menu == "" {
			item.Menu = "app_survey"
		}
		if item.Subject == "" {
			item.Subject = "Imported survey"
		}
		if err := feedbackDB.Create(&item).Error; err != nil {
			skipped++
			continue
		}
		imported++
	}
	return c.JSON(fiber.Map{"ok": true, "imported": imported, "skipped": skipped, "total": len(rows)})
}
