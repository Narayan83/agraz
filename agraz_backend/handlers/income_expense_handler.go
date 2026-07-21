package handler

import (
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var incomeExpenseDB *gorm.DB

func SetIncomeExpenseDB(db *gorm.DB) {
	incomeExpenseDB = db
}

func validIncomeExpenseType(t string) bool {
	return t == "Income" || t == "Expense"
}

type incomeExpensePayload struct {
	Type        string          `json:"type"`
	Category    string          `json:"category"`
	SubCategory string          `json:"sub_category"`
	Amount      decimal.Decimal `json:"amount"`
	Narration   *string         `json:"narration"`
	Mobile      string          `json:"mobile"`
	Date        time.Time       `json:"date"`
	Name        string          `json:"name"`
	Village     *string         `json:"village"`
	Post        *string         `json:"post"`
	Taluk       *string         `json:"taluk"`
	District    *string         `json:"district"`
	ExtraAddr   *string         `json:"extra_address"`
	Pincode     *string         `json:"pincode"`
}

func CreateIncomeExpense(c *fiber.Ctx) error {
	var body incomeExpensePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if !validIncomeExpenseType(body.Type) {
		return c.Status(400).JSON(fiber.Map{"error": "type must be Income or Expense"})
	}
	if body.Category == "" || body.SubCategory == "" || body.Mobile == "" || body.Name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "category, sub_category, mobile, and name are required"})
	}
	if body.Date.IsZero() {
		return c.Status(400).JSON(fiber.Map{"error": "date is required"})
	}
	if body.Amount.LessThanOrEqual(decimal.Zero) {
		return c.Status(400).JSON(fiber.Map{"error": "amount must be greater than zero"})
	}

	row := models.IncomeExpense{
		Type:        body.Type,
		Category:    body.Category,
		SubCategory: body.SubCategory,
		Amount:      body.Amount,
		Narration:   body.Narration,
		Mobile:      body.Mobile,
		Date:        body.Date,
		Name:        body.Name,
		Village:     body.Village,
		Post:        body.Post,
		Taluk:       body.Taluk,
		District:    body.District,
		ExtraAddr:   body.ExtraAddr,
		Pincode:     body.Pincode,
	}
	if err := incomeExpenseDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create record", "details": err.Error()})
	}
	return c.Status(201).JSON(row)
}

func GetIncomeExpenses(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	offset := (page - 1) * limit

	var rows []models.IncomeExpense
	var total int64
	q := incomeExpenseDB.Model(&models.IncomeExpense{})
	if t := c.Query("type"); t != "" {
		q = q.Where("type = ?", t)
	}
	if cat := c.Query("category"); cat != "" {
		q = q.Where("category ILIKE ?", "%"+cat+"%")
	}
	if from := c.Query("from"); from != "" {
		q = q.Where("date >= ?", from)
	}
	if to := c.Query("to"); to != "" {
		q = q.Where("date <= ?", to)
	}
	// Agraz Flutter list screen uses start_date / end_date
	if sd := c.Query("start_date"); sd != "" {
		q = q.Where("date >= ?", sd)
	}
	if ed := c.Query("end_date"); ed != "" {
		q = q.Where("date <= ?", ed)
	}
	if m := c.Query("mobile"); m != "" {
		q = q.Where("mobile = ?", m)
	}
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("date DESC, id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetIncomeExpense(c *fiber.Ctx) error {
	var row models.IncomeExpense
	if err := incomeExpenseDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}
	return c.JSON(row)
}

func UpdateIncomeExpense(c *fiber.Ctx) error {
	var body incomeExpensePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	var row models.IncomeExpense
	if err := incomeExpenseDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}

	if body.Type != "" && !validIncomeExpenseType(body.Type) {
		return c.Status(400).JSON(fiber.Map{"error": "type must be Income or Expense"})
	}

	updates := map[string]interface{}{}
	if body.Type != "" {
		updates["type"] = body.Type
	}
	if body.Category != "" {
		updates["category"] = body.Category
	}
	if body.SubCategory != "" {
		updates["sub_category"] = body.SubCategory
	}
	if !body.Amount.IsZero() {
		if body.Amount.LessThanOrEqual(decimal.Zero) {
			return c.Status(400).JSON(fiber.Map{"error": "amount must be greater than zero"})
		}
		updates["amount"] = body.Amount
	}
	if body.Narration != nil {
		updates["narration"] = body.Narration
	}
	if body.Mobile != "" {
		updates["mobile"] = body.Mobile
	}
	if !body.Date.IsZero() {
		updates["date"] = body.Date
	}
	if body.Name != "" {
		updates["name"] = body.Name
	}
	if body.Village != nil {
		updates["village"] = body.Village
	}
	if body.Post != nil {
		updates["post"] = body.Post
	}
	if body.Taluk != nil {
		updates["taluk"] = body.Taluk
	}
	if body.District != nil {
		updates["district"] = body.District
	}
	if body.ExtraAddr != nil {
		updates["extra_address"] = body.ExtraAddr
	}
	if body.Pincode != nil {
		updates["pincode"] = body.Pincode
	}

	if len(updates) == 0 {
		return c.JSON(row)
	}
	if err := incomeExpenseDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update", "details": err.Error()})
	}
	incomeExpenseDB.First(&row, row.ID)
	return c.JSON(row)
}

func DeleteIncomeExpense(c *fiber.Ctx) error {
	res := incomeExpenseDB.Delete(&models.IncomeExpense{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}
