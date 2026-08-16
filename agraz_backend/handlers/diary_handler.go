package handler

import (
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var diaryDB *gorm.DB

func SetDiaryDB(db *gorm.DB) {
	diaryDB = db
}

type diaryLabelPayload struct {
	Name string `json:"name"`
	Icon string `json:"icon"`
}

type diaryEntryPayload struct {
	LabelID *uint    `json:"label_id"`
	Title   string   `json:"title"`
	Content string   `json:"content"`
	Amount  *float64 `json:"amount"`
	NumDays *float64 `json:"num_days"`
	Date    flexibleTime `json:"date"`
}

func ListDiaryLabels(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var rows []models.DiaryLabel
	if err := scopeByUserID(diaryDB.Model(&models.DiaryLabel{}), uid).
		Order("name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func CreateDiaryLabel(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body diaryLabelPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	icon := strings.TrimSpace(body.Icon)
	if icon == "" {
		icon = "label"
	}
	row := models.DiaryLabel{UserID: uid, Name: name, Icon: icon}
	if err := diaryDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Label created", "data": row})
}

func UpdateDiaryLabel(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body diaryLabelPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	var row models.DiaryLabel
	if err := scopeByUserID(diaryDB.Model(&models.DiaryLabel{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Label not found"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	if i := strings.TrimSpace(body.Icon); i != "" {
		row.Icon = i
	}
	if err := diaryDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Label updated", "data": row})
}

func DeleteDiaryLabel(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(diaryDB.Model(&models.DiaryLabel{}), uid).
		Delete(&models.DiaryLabel{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Label not found"})
	}
	// Unlink entries that used this label.
	_ = scopeByUserID(diaryDB.Model(&models.DiaryEntry{}), uid).
		Where("label_id = ?", c.Params("id")).
		Update("label_id", nil)
	return c.JSON(fiber.Map{"message": "Label deleted"})
}

func ListDiaryEntries(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
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

	q := scopeByUserID(diaryDB.Model(&models.DiaryEntry{}), uid)
	if from := c.Query("from"); from != "" {
		q = q.Where("date >= ?", from)
	}
	if to := c.Query("to"); to != "" {
		q = q.Where("date <= ?", to)
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("content ILIKE ? OR title ILIKE ?", like, like)
	}
	if labelID := c.Query("label_id"); labelID != "" {
		q = q.Where("label_id = ?", labelID)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var rows []models.DiaryEntry
	if err := q.Preload("Label").Order("date DESC, id DESC").
		Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func CreateDiaryEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body diaryEntryPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	content := strings.TrimSpace(body.Content)
	if content == "" {
		return c.Status(400).JSON(fiber.Map{"error": "content is required"})
	}
	if body.Date.Time.IsZero() {
		body.Date.Time = time.Now()
	}
	row := models.DiaryEntry{
		UserID:  uid,
		LabelID: body.LabelID,
		Title:   strings.TrimSpace(body.Title),
		Content: content,
		Amount:  body.Amount,
		NumDays: body.NumDays,
		Date:    body.Date.Time,
	}
	if err := diaryDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = diaryDB.Preload("Label").First(&row, row.ID)
	return c.Status(201).JSON(fiber.Map{"message": "Diary entry created", "data": row})
}

func UpdateDiaryEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body diaryEntryPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	var row models.DiaryEntry
	if err := scopeByUserID(diaryDB.Model(&models.DiaryEntry{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Entry not found"})
	}
	if content := strings.TrimSpace(body.Content); content != "" {
		row.Content = content
	}
	row.Title = strings.TrimSpace(body.Title)
	row.LabelID = body.LabelID
	row.Amount = body.Amount
	row.NumDays = body.NumDays
	if !body.Date.Time.IsZero() {
		row.Date = body.Date.Time
	}
	if err := diaryDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = diaryDB.Preload("Label").First(&row, row.ID)
	return c.JSON(fiber.Map{"message": "Diary entry updated", "data": row})
}

func DeleteDiaryEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(diaryDB.Model(&models.DiaryEntry{}), uid).
		Delete(&models.DiaryEntry{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Entry not found"})
	}
	return c.JSON(fiber.Map{"message": "Diary entry deleted"})
}
