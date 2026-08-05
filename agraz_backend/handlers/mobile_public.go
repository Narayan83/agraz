package handler

import (
	"encoding/json"
	"errors"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

// --- Agraz / Flutter mobile public API (no JWT). Same DB as admin & storefront. ---

type registerBusinessPayload struct {
	Mobile       string   `json:"mobile"`
	Name         string   `json:"name"`
	MainCategory string   `json:"main_category"`
	SubCategory  *string  `json:"sub_category,omitempty"`
	BusinessName string   `json:"business_name"`
	Email        *string  `json:"email,omitempty"`
	Remarks      *string  `json:"remarks,omitempty"`
	ImagePaths   []string `json:"image_paths"`
}

// RegisterBusinessPublic handles POST /api/register-business (Agraz app).
func RegisterBusinessPublic(c *fiber.Ctx) error {
	var body registerBusinessPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if body.Mobile == "" || body.Name == "" || body.MainCategory == "" || body.BusinessName == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Missing required fields: mobile, name, main_category, business_name"})
	}
	raw, err := json.Marshal(body.ImagePaths)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to process image paths", "details": err.Error()})
	}
	row := models.ServiceRegistration{
		Mobile:       body.Mobile,
		Name:         body.Name,
		MainCategory: body.MainCategory,
		SubCategory:  body.SubCategory,
		BusinessName: body.BusinessName,
		ImagePaths:   datatypes.JSON(raw),
		Approved:     false,
	}
	if body.Email != nil {
		email := strings.TrimSpace(*body.Email)
		if email != "" {
			row.Email = &email
		}
	}
	if body.Remarks != nil {
		remarks := strings.TrimSpace(*body.Remarks)
		if remarks != "" {
			row.Remarks = &remarks
		}
	}
	if err := serviceRegistrationDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to save service registration", "details": err.Error()})
	}
	_ = syncCoverImageForRow(row.ID, row.ImagePaths)
	serviceRegistrationDB.First(&row, row.ID)
	return c.Status(200).JSON(fiber.Map{
		"success": true,
		"message": "Business registered successfully",
		"data":    row,
	})
}

// ListApprovedServicesPublic handles GET /api/services — approved registrations for Flutter General Services.
func ListApprovedServicesPublic(c *fiber.Ctx) error {
	var rows []models.ServiceRegistration
	q := serviceRegistrationDB.Model(&models.ServiceRegistration{}).Where("approved = ?", true)
	if mc := c.Query("main_category"); mc != "" {
		q = q.Where("main_category ILIKE ?", "%"+mc+"%")
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where(
			"business_name ILIKE ? OR name ILIKE ? OR main_category ILIKE ? OR COALESCE(sub_category,'') ILIKE ? OR COALESCE(business_address,'') ILIKE ?",
			like, like, like, like, like,
		)
	}
	if err := q.Order("main_category ASC, sub_category ASC, business_name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": len(rows)})
}

type mobileRegisterRequest struct {
	Firstname       string `json:"firstname"`
	Lastname        string `json:"lastname"`
	Email           string `json:"email"`
	Password        string `json:"password"`
	Phone           string `json:"phone"`
	ConfirmPassword string `json:"confirmPassword"`
}

// MobileRegisterUser handles POST /api/mobile/register (Agraz app; avoids conflicting with admin-only POST /api/users).
func MobileRegisterUser(c *fiber.Ctx) error {
	var body mobileRegisterRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if strings.TrimSpace(body.Firstname) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "firstname is required"})
	}
	if strings.TrimSpace(body.Email) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "email is required"})
	}
	if body.Password == "" {
		return c.Status(400).JSON(fiber.Map{"error": "password is required"})
	}
	if body.ConfirmPassword != "" && body.ConfirmPassword != body.Password {
		return c.Status(400).JSON(fiber.Map{"error": "passwords do not match"})
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "password hash failed"})
	}
	phone := strings.TrimSpace(body.Phone)
	var mobilePtr *string
	if phone != "" {
		mobilePtr = &phone
	}
	user := models.User{
		TenantID:      tenantIDFromCtx(c),
		Firstname:     strings.TrimSpace(body.Firstname),
		Lastname:      strings.TrimSpace(body.Lastname),
		Email:         strings.TrimSpace(body.Email),
		Password:      string(hash),
		PlainPassword: body.Password,
		Active:        true,
		MobileNumber:  mobilePtr,
	}
	if err := userDB.Create(&user).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create user", "details": err.Error()})
	}
	var role models.Role
	if err := userDB.Where("role_name = ?", "User").First(&role).Error; err == nil {
		_ = userDB.Create(&models.UserRoleMapping{UserID: user.ID, RoleID: role.ID}).Error
	}
	user.Password = ""
	user.PlainPassword = ""
	return c.Status(201).JSON(fiber.Map{
		"message": "Registration successful",
		"user":    user,
	})
}

// CreateIncomeExpenseMobile handles POST /api/income_expense (camelCase body from Flutter).
func CreateIncomeExpenseMobile(c *fiber.Ctx) error {
	var raw map[string]interface{}
	if err := json.Unmarshal(c.Body(), &raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid JSON", "details": err.Error()})
	}
	typeStr, _ := raw["type"].(string)
	if typeStr == "" {
		return c.Status(400).JSON(fiber.Map{"error": "type is required"})
	}
	typeStr = strings.TrimSpace(typeStr)
	if typeStr != "Income" && typeStr != "Expense" {
		return c.Status(400).JSON(fiber.Map{"error": "type must be Income or Expense"})
	}
	cat, _ := raw["category"].(string)
	sub := ""
	if v, ok := raw["subCategory"].(string); ok && v != "" {
		sub = v
	} else if v, ok := raw["sub_category"].(string); ok {
		sub = v
	}
	if strings.TrimSpace(cat) == "" || strings.TrimSpace(sub) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "category and subCategory are required"})
	}
	amtF, ok := toFloat64(raw["amount"])
	if !ok || amtF <= 0 {
		return c.Status(400).JSON(fiber.Map{"error": "amount must be greater than 0"})
	}
	mobile, _ := raw["mobile"].(string)
	name, _ := raw["name"].(string)
	// mobile and name are optional for income/expense entries
	var dt time.Time
	if ds, ok := raw["date"].(string); ok && strings.TrimSpace(ds) != "" {
		var parseErr error
		dt = time.Time{}
		for _, layout := range []string{time.RFC3339, "2006-01-02T15:04:05.999999", "2006-01-02T15:04:05", "2006-01-02"} {
			dt, parseErr = time.Parse(layout, strings.TrimSpace(ds))
			if parseErr == nil {
				break
			}
		}
		if dt.IsZero() {
			return c.Status(400).JSON(fiber.Map{"error": "invalid date format"})
		}
	} else {
		dt = time.Now()
	}
	narr := strFromAny(raw["narration"])
	village := strFromAny(raw["village"])
	post := strFromAny(raw["post"])
	taluk := strFromAny(raw["taluk"])
	district := strFromAny(raw["district"])
	extra := strFromAny(raw["extraAddress"])
	if extra == "" {
		extra = strFromAny(raw["extra_address"])
	}
	pin := strFromAny(raw["pincode"])
	amt := decimal.NewFromFloat(amtF)
	row := models.IncomeExpense{
		Type:        typeStr,
		Category:    strings.TrimSpace(cat),
		SubCategory: strings.TrimSpace(sub),
		Amount:      amt,
		Mobile:      strings.TrimSpace(mobile),
		Date:        dt,
		Name:        strings.TrimSpace(name),
	}
	if narr != "" {
		row.Narration = &narr
	}
	if village != "" {
		row.Village = &village
	}
	if post != "" {
		row.Post = &post
	}
	if taluk != "" {
		row.Taluk = &taluk
	}
	if district != "" {
		row.District = &district
	}
	if extra != "" {
		row.ExtraAddr = &extra
	}
	if pin != "" {
		row.Pincode = &pin
	}
	if err := incomeExpenseDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create record", "details": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Transaction created successfully", "data": row})
}

func toFloat64(v interface{}) (float64, bool) {
	switch t := v.(type) {
	case float64:
		return t, true
	case float32:
		return float64(t), true
	case int:
		return float64(t), true
	case json.Number:
		f, err := t.Float64()
		return f, err == nil
	default:
		return 0, false
	}
}

func strFromAny(v interface{}) string {
	if v == nil {
		return ""
	}
	s, _ := v.(string)
	return strings.TrimSpace(s)
}

// GetIncomeExpenseSummaryPublic handles GET /api/income_expense/summary
func GetIncomeExpenseSummaryPublic(c *fiber.Ctx) error {
	type sumRow struct {
		Type        string  `json:"type"`
		TotalAmount float64 `gorm:"column:total_amount"`
		Count       int64   `gorm:"column:count"`
	}
	var rows []sumRow
	if err := incomeExpenseDB.Model(&models.IncomeExpense{}).
		Select("type, SUM(amount)::float8 as total_amount, COUNT(*) as count").
		Group("type").
		Scan(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	out := make([]fiber.Map, 0, len(rows))
	for _, r := range rows {
		out = append(out, fiber.Map{
			"type":         r.Type,
			"total_amount": r.TotalAmount,
			"count":        r.Count,
		})
	}
	return c.JSON(fiber.Map{"summary": out})
}

// GetIncomeExpensesByMobilePublic handles GET /api/income_expense/mobile/:mobile
func GetIncomeExpensesByMobilePublic(c *fiber.Ctx) error {
	mobile := c.Params("mobile")
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	offset := (page - 1) * limit
	var rows []models.IncomeExpense
	var total int64
	q := incomeExpenseDB.Model(&models.IncomeExpense{}).Where("mobile = ?", mobile)
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("date DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

// GetUserByMobilePublic handles GET /api/mobile/users/by-phone/:phone (optional; for future app flows).
func GetUserByMobilePublic(c *fiber.Ctx) error {
	phone := strings.TrimSpace(c.Params("phone"))
	if phone == "" {
		return c.Status(400).JSON(fiber.Map{"error": "phone is required"})
	}
	var user models.User
	tid := tenantIDFromCtx(c)
	if err := userDB.Where("mobile_number = ? AND tenant_id = ?", phone, tid).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "User not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	user.Password = ""
	user.PlainPassword = ""
	return c.JSON(user)
}
