package handler

import (
	"math"
	"strings"
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
	Type          string          `json:"type"`
	Category      string          `json:"category"`
	SubCategory   string          `json:"sub_category"`
	SubCategories []string        `json:"sub_categories"` // optional multi-select
	Amount        decimal.Decimal `json:"amount"`
	Narration     *string         `json:"narration"`
	Mobile        string          `json:"mobile"`
	Date          time.Time       `json:"date"`
	Name          string          `json:"name"`
	Village       *string         `json:"village"`
	Post          *string         `json:"post"`
	Taluk         *string         `json:"taluk"`
	District      *string         `json:"district"`
	ExtraAddr     *string         `json:"extra_address"`
	Pincode       *string         `json:"pincode"`
}

// normalizeIESubCategories merges SubCategories + SubCategory into a unique trimmed list.
func normalizeIESubCategories(subs []string, single string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0)
	for _, s := range subs {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		if _, ok := seen[s]; ok {
			continue
		}
		seen[s] = struct{}{}
		out = append(out, s)
	}
	if len(out) == 0 {
		s := strings.TrimSpace(single)
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}

// splitAmountWholeRupees splits amount into n whole-rupee parts.
// base = floor(amount/n); remainder goes to the FIRST part.
// Example: 100 / 3 → 34, 33, 33
func splitAmountWholeRupees(amount decimal.Decimal, n int) []decimal.Decimal {
	if n <= 0 {
		return nil
	}
	if n == 1 {
		return []decimal.Decimal{amount}
	}
	total := int64(math.Floor(amount.InexactFloat64()))
	if total < 0 {
		total = 0
	}
	base := total / int64(n)
	rem := total % int64(n)
	out := make([]decimal.Decimal, n)
	for i := 0; i < n; i++ {
		v := base
		if i == 0 {
			v += rem
		}
		out[i] = decimal.NewFromInt(v)
	}
	return out
}

func CreateIncomeExpense(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body incomeExpensePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if !validIncomeExpenseType(body.Type) {
		return c.Status(400).JSON(fiber.Map{"error": "type must be Income or Expense"})
	}
	subs := normalizeIESubCategories(body.SubCategories, body.SubCategory)
	if body.Category == "" || len(subs) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "category and sub_category (or sub_categories) are required"})
	}
	if body.Date.IsZero() {
		return c.Status(400).JSON(fiber.Map{"error": "date is required"})
	}
	if body.Amount.LessThanOrEqual(decimal.Zero) {
		return c.Status(400).JSON(fiber.Map{"error": "amount must be greater than zero"})
	}

	baseRow := models.IncomeExpense{
		UserID:    uid,
		Type:      body.Type,
		Category:  body.Category,
		Narration: body.Narration,
		Mobile:    body.Mobile,
		Date:      body.Date,
		Name:      body.Name,
		Village:   body.Village,
		Post:      body.Post,
		Taluk:     body.Taluk,
		District:  body.District,
		ExtraAddr: body.ExtraAddr,
		Pincode:   body.Pincode,
	}

	if len(subs) >= 2 {
		amounts := splitAmountWholeRupees(body.Amount, len(subs))
		rows := make([]models.IncomeExpense, 0, len(subs))
		for i, sub := range subs {
			row := baseRow
			row.SubCategory = sub
			row.Amount = amounts[i]
			if row.Amount.LessThanOrEqual(decimal.Zero) {
				continue
			}
			rows = append(rows, row)
		}
		if len(rows) == 0 {
			return c.Status(400).JSON(fiber.Map{"error": "split amounts are zero; increase amount or reduce sub_categories"})
		}
		if err := incomeExpenseDB.Create(&rows).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "Failed to create records", "details": err.Error()})
		}
		return c.Status(201).JSON(fiber.Map{
			"data":    rows,
			"message": "Created split income/expense entries",
		})
	}

	row := baseRow
	row.SubCategory = subs[0]
	row.Amount = body.Amount
	if err := incomeExpenseDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create record", "details": err.Error()})
	}
	return c.Status(201).JSON(row)
}

func GetIncomeExpenses(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	offset := (page - 1) * limit

	var rows []models.IncomeExpense
	var total int64
	q := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid)
	if t := c.Query("type"); t != "" {
		q = q.Where("type = ?", t)
	}
	if cat := c.Query("category"); cat != "" {
		q = q.Where("category ILIKE ?", "%"+cat+"%")
	}
	if sub := c.Query("sub_category"); sub != "" {
		q = q.Where("sub_category ILIKE ?", "%"+sub+"%")
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
	if n := c.Query("name"); n != "" {
		q = q.Where("name ILIKE ?", "%"+n+"%")
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
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.IncomeExpense
	if err := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}
	return c.JSON(row)
}

func UpdateIncomeExpense(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body incomeExpensePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	var row models.IncomeExpense
	if err := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
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
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	res := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid).
		Delete(&models.IncomeExpense{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}
