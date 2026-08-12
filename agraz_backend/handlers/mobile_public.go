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
	phone = strings.TrimLeft(phone, "+")
	if phone == "" {
		return c.Status(400).JSON(fiber.Map{"error": "phone is required"})
	}
	tid := tenantIDFromCtx(c)
	var existing models.User
	if err := userDB.Where("mobile_number = ? AND tenant_id = ?", phone, tid).First(&existing).Error; err == nil {
		return c.Status(409).JSON(fiber.Map{"error": "This mobile number is already registered"})
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to validate mobile number", "details": err.Error()})
	}
	user := models.User{
		TenantID:      tid,
		Firstname:     strings.TrimSpace(body.Firstname),
		Lastname:      strings.TrimSpace(body.Lastname),
		Email:         strings.TrimSpace(body.Email),
		Password:      string(hash),
		PlainPassword: body.Password,
		Active:        true,
		Approved:      true, // auto-approved on registration; can log in immediately
		MobileNumber:  &phone,
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
		"message":  "Registration successful. You can log in now.",
		"code":     "approved",
		"approved": true,
		"user":     user,
	})
}

// CreateIncomeExpenseMobile handles POST /api/income_expense (camelCase body from Flutter).
func CreateIncomeExpenseMobile(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error":   "Login required",
			"message": "Login required",
		})
	}
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
	var subList []string
	if arr, ok := raw["subCategories"].([]interface{}); ok {
		for _, item := range arr {
			if s, ok := item.(string); ok {
				subList = append(subList, s)
			}
		}
	} else if arr, ok := raw["sub_categories"].([]interface{}); ok {
		for _, item := range arr {
			if s, ok := item.(string); ok {
				subList = append(subList, s)
			}
		}
	}
	subs := normalizeIESubCategories(subList, sub)
	if strings.TrimSpace(cat) == "" || len(subs) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "category and subCategory (or subCategories) are required"})
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

	txnMode, _ := raw["transaction_mode"].(string)
	if txnMode == "" {
		txnMode, _ = raw["transactionMode"].(string)
	}
	txnMode = strings.TrimSpace(txnMode)
	if txnMode == "" {
		txnMode = "Cash"
	}
	if txnMode != "Cash" && txnMode != "Transfer" {
		return c.Status(400).JSON(fiber.Map{"error": "transaction_mode must be Cash or Transfer"})
	}
	var orgIDPtr *uint
	if txnMode == "Transfer" {
		oid, ok := uintFromAny(raw["organization_id"])
		if !ok {
			if v, ok2 := uintFromAny(raw["organizationId"]); ok2 {
				oid, ok = v, true
			}
		}
		if !ok {
			return c.Status(400).JSON(fiber.Map{"error": "organization_id is required when transaction_mode is Transfer"})
		}
		orgIDPtr = &oid
	} else if oid, ok := uintFromAny(raw["organization_id"]); ok {
		orgIDPtr = &oid
	} else if v, ok := uintFromAny(raw["organizationId"]); ok {
		orgIDPtr = &v
	}

	baseRow := models.IncomeExpense{
		UserID:          uid,
		Type:            typeStr,
		Category:        strings.TrimSpace(cat),
		Mobile:          strings.TrimSpace(mobile),
		Date:            dt,
		Name:            strings.TrimSpace(name),
		TransactionMode: txnMode,
		OrganizationID:  orgIDPtr,
	}
	if narr != "" {
		baseRow.Narration = &narr
	}
	if village != "" {
		baseRow.Village = &village
	}
	if post != "" {
		baseRow.Post = &post
	}
	if taluk != "" {
		baseRow.Taluk = &taluk
	}
	if district != "" {
		baseRow.District = &district
	}
	if extra != "" {
		baseRow.ExtraAddr = &extra
	}
	if pin != "" {
		baseRow.Pincode = &pin
	}

	if len(subs) >= 2 {
		amounts := splitAmountWholeRupees(amt, len(subs))
		rows := make([]models.IncomeExpense, 0, len(subs))
		for i, s := range subs {
			row := baseRow
			row.SubCategory = s
			row.Amount = amounts[i]
			if row.Amount.LessThanOrEqual(decimal.Zero) {
				continue
			}
			rows = append(rows, row)
		}
		if len(rows) == 0 {
			return c.Status(400).JSON(fiber.Map{"error": "split amounts are zero; increase amount or reduce subCategories"})
		}
		if err := incomeExpenseDB.Create(&rows).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "Failed to create records", "details": err.Error()})
		}
		for i := range rows {
			syncIETransferToOrg(uid, &rows[i])
		}
		return c.Status(201).JSON(fiber.Map{
			"message": "Transactions created successfully",
			"data":    rows,
		})
	}

	row := baseRow
	row.SubCategory = subs[0]
	row.Amount = amt
	if err := incomeExpenseDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create record", "details": err.Error()})
	}
	syncIETransferToOrg(uid, &row)
	return c.Status(201).JSON(fiber.Map{"message": "Transaction created successfully", "data": row})
}

// UpdateIncomeExpenseMobile handles PUT /api/income_expense/:id (camelCase body from Flutter).
func UpdateIncomeExpenseMobile(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var row models.IncomeExpense
	if err := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid).
		First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}
	var raw map[string]interface{}
	if err := json.Unmarshal(c.Body(), &raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid JSON", "details": err.Error()})
	}
	if v, ok := raw["type"].(string); ok && strings.TrimSpace(v) != "" {
		t := strings.TrimSpace(v)
		if t != "Income" && t != "Expense" {
			return c.Status(400).JSON(fiber.Map{"error": "type must be Income or Expense"})
		}
		row.Type = t
	}
	if v, ok := raw["category"].(string); ok && strings.TrimSpace(v) != "" {
		row.Category = strings.TrimSpace(v)
	}
	sub := ""
	if v, ok := raw["subCategory"].(string); ok && v != "" {
		sub = v
	} else if v, ok := raw["sub_category"].(string); ok {
		sub = v
	}
	if strings.TrimSpace(sub) != "" {
		row.SubCategory = strings.TrimSpace(sub)
	}
	if amtF, ok := toFloat64(raw["amount"]); ok {
		if amtF <= 0 {
			return c.Status(400).JSON(fiber.Map{"error": "amount must be greater than 0"})
		}
		row.Amount = decimal.NewFromFloat(amtF)
	}
	if v, ok := raw["mobile"].(string); ok {
		row.Mobile = strings.TrimSpace(v)
	}
	if v, ok := raw["name"].(string); ok {
		row.Name = strings.TrimSpace(v)
	}
	if ds, ok := raw["date"].(string); ok && strings.TrimSpace(ds) != "" {
		var dt time.Time
		var parseErr error
		for _, layout := range []string{time.RFC3339, "2006-01-02T15:04:05.999999", "2006-01-02T15:04:05", "2006-01-02"} {
			dt, parseErr = time.Parse(layout, strings.TrimSpace(ds))
			if parseErr == nil {
				break
			}
		}
		if dt.IsZero() {
			return c.Status(400).JSON(fiber.Map{"error": "invalid date format"})
		}
		row.Date = dt
	}
	if _, ok := raw["narration"]; ok {
		narr := strFromAny(raw["narration"])
		if narr == "" {
			row.Narration = nil
		} else {
			row.Narration = &narr
		}
	}
	if _, ok := raw["village"]; ok {
		v := strFromAny(raw["village"])
		if v == "" {
			row.Village = nil
		} else {
			row.Village = &v
		}
	}
	if _, ok := raw["post"]; ok {
		v := strFromAny(raw["post"])
		if v == "" {
			row.Post = nil
		} else {
			row.Post = &v
		}
	}
	if _, ok := raw["taluk"]; ok {
		v := strFromAny(raw["taluk"])
		if v == "" {
			row.Taluk = nil
		} else {
			row.Taluk = &v
		}
	}
	if _, ok := raw["district"]; ok {
		v := strFromAny(raw["district"])
		if v == "" {
			row.District = nil
		} else {
			row.District = &v
		}
	}
	if _, hasCamel := raw["extraAddress"]; hasCamel {
		extra := strFromAny(raw["extraAddress"])
		if extra == "" {
			row.ExtraAddr = nil
		} else {
			row.ExtraAddr = &extra
		}
	} else if _, hasSnake := raw["extra_address"]; hasSnake {
		extra := strFromAny(raw["extra_address"])
		if extra == "" {
			row.ExtraAddr = nil
		} else {
			row.ExtraAddr = &extra
		}
	}
	if _, ok := raw["pincode"]; ok {
		v := strFromAny(raw["pincode"])
		if v == "" {
			row.Pincode = nil
		} else {
			row.Pincode = &v
		}
	}
	if v, ok := raw["transaction_mode"].(string); ok && strings.TrimSpace(v) != "" {
		m := strings.TrimSpace(v)
		if m != "Cash" && m != "Transfer" {
			return c.Status(400).JSON(fiber.Map{"error": "transaction_mode must be Cash or Transfer"})
		}
		row.TransactionMode = m
	} else if v, ok := raw["transactionMode"].(string); ok && strings.TrimSpace(v) != "" {
		m := strings.TrimSpace(v)
		if m != "Cash" && m != "Transfer" {
			return c.Status(400).JSON(fiber.Map{"error": "transaction_mode must be Cash or Transfer"})
		}
		row.TransactionMode = m
	}
	if _, has := raw["organization_id"]; has {
		if oid, ok := uintFromAny(raw["organization_id"]); ok {
			row.OrganizationID = &oid
		} else {
			row.OrganizationID = nil
		}
	} else if _, has := raw["organizationId"]; has {
		if oid, ok := uintFromAny(raw["organizationId"]); ok {
			row.OrganizationID = &oid
		} else {
			row.OrganizationID = nil
		}
	}
	if row.TransactionMode == "Transfer" && row.OrganizationID == nil {
		return c.Status(400).JSON(fiber.Map{"error": "organization_id is required when transaction_mode is Transfer"})
	}
	if err := incomeExpenseDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update", "details": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Transaction updated successfully", "data": row})
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
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	type sumRow struct {
		Type        string  `json:"type"`
		TotalAmount float64 `gorm:"column:total_amount"`
		Count       int64   `gorm:"column:count"`
	}
	var rows []sumRow
	if err := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid).
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
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	mobile := c.Params("mobile")
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	offset := (page - 1) * limit
	var rows []models.IncomeExpense
	var total int64
	q := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid).Where("mobile = ?", mobile)
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("date DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

// GetPartyBalancePublic handles GET /api/income_expense/balance/:mobile
// Balance = Income - Expense. Positive => credit (party paid us more), negative => debit.
func GetPartyBalancePublic(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	mobile := strings.TrimSpace(c.Params("mobile"))
	if mobile == "" {
		return c.Status(400).JSON(fiber.Map{"error": "mobile is required"})
	}
	type sumRow struct {
		Type        string  `gorm:"column:type"`
		TotalAmount float64 `gorm:"column:total_amount"`
	}
	var rows []sumRow
	if err := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid).
		Select("type, COALESCE(SUM(amount),0)::float8 as total_amount").
		Where("mobile = ?", mobile).
		Group("type").
		Scan(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var income, expense float64
	for _, r := range rows {
		switch strings.TrimSpace(r.Type) {
		case "Income":
			income = r.TotalAmount
		case "Expense":
			expense = r.TotalAmount
		}
	}
	balance := income - expense
	side := "settled"
	if balance > 0 {
		side = "credit"
	} else if balance < 0 {
		side = "debit"
	}
	return c.JSON(fiber.Map{
		"mobile":  mobile,
		"income":  income,
		"expense": expense,
		"balance": balance,
		"side":    side,
		"amount":  absFloat(balance),
	})
}

func absFloat(v float64) float64 {
	if v < 0 {
		return -v
	}
	return v
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
