package handler

import (
	"fmt"
	"strconv"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var userDB *gorm.DB

func SetUserDB(db *gorm.DB) {
	userDB = db
}

type CreateUserRequest struct {
	Usercode      *string `json:"usercode"`
	Firstname     string  `json:"firstname"`
	Lastname      string  `json:"lastname"`
	Username      *string `json:"username"`
	Email         string  `json:"email"`
	Password      string  `json:"password"`
	Active        *bool   `json:"active"`
	VendorID      *uint   `json:"vendor_id"`
}

type UpdateUserRequest struct {
	Usercode      *string `json:"usercode"`
	Firstname     *string `json:"firstname"`
	Lastname      *string `json:"lastname"`
	Email         *string `json:"email"`
	Password      *string `json:"password"`
	Username      *string `json:"username"`
	Active        *bool   `json:"active"`
	VendorID      *uint   `json:"vendor_id"`
	ClearVendor   *bool   `json:"clear_vendor"`
}


// AddressPayload represents an address item that can be created/updated
// together with the user payload.



func hashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

func CreateUser(c *fiber.Ctx) error {
	var body CreateUserRequest

	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"error":   "Invalid Request",
			"message": "Failed to parse request body",
			"details": err.Error(),
		})
	}

	// Validate required fields
	if body.Firstname == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Firstname is required"})
	}
	if body.Email == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Email is required"})
	}
	if body.Password == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Password is required"})
	}
	if body.VendorID != nil && *body.VendorID > 0 {
		var v models.Vendor
		if err := vendorDB.Where("id = ? AND tenant_id = ?", *body.VendorID, tenantIDFromCtx(c)).First(&v).Error; err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "vendor_id is invalid"})
		}
	}

	hashedPassword, err := hashPassword(body.Password)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Password encryption failed"})
	}

	active := true
	if body.Active != nil {
		active = *body.Active
	}

	user := models.User{
		TenantID:      tenantIDFromCtx(c),
		Usercode:      body.Usercode,
		Firstname:     body.Firstname,
		Lastname:      body.Lastname,
		Username:      stringPtrToString(body.Username),
		Email:         body.Email,
		Password:      hashedPassword,
		PlainPassword: body.Password,
		Active:        active,
		VendorID:      body.VendorID,
	}

	if err := userDB.Create(&user).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create user", "details": err.Error()})
	}

	return c.Status(201).JSON(user)
}


// Helper function to convert string pointer to string
func stringPtrToString(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func boolPtrToBool(b *bool) bool {
	if b == nil {
		return true // default to active
	}
	return *b
}

func GetUsers(c *fiber.Ctx) error {
	if err := forbidVendorPortal(c); err != nil {
		return err
	}
	pageStr := c.Query("page", "1")
	limitStr := c.Query("limit", "10")
	search := c.Query("filter", "")

	page := 1
	limit := 10
	if p, err := strconv.Atoi(pageStr); err == nil && p > 0 {
		page = p
	}
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
		limit = l
	}
	offset := (page - 1) * limit

	var users []models.User
	var total int64
	tid := tenantIDFromCtx(c)
	query := userDB.Model(&models.User{}).Where("tenant_id = ?", tid)

	if search != "" {
		searchTerm := "%" + search + "%"
		query = query.Where("firstname ILIKE ? OR lastname ILIKE ? OR email ILIKE ? OR username ILIKE ?", searchTerm, searchTerm, searchTerm, searchTerm)
	}

	if err := query.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	if err := query.Limit(limit).Offset(offset).Find(&users).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{
		"data":  users,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}


func GetUser(c *fiber.Ctx) error {
	id := c.Params("id")
	tid := tenantIDFromCtx(c)
	var user models.User
	if err := userDB.Where("id = ? AND tenant_id = ?", id, tid).First(&user).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}
	return c.JSON(user)
}


func UpdateUser(c *fiber.Ctx) error {
	id := c.Params("id")

	var body UpdateUserRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	tid := tenantIDFromCtx(c)
	var user models.User
	if err := userDB.Where("id = ? AND tenant_id = ?", id, tid).First(&user).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}

	updateData := map[string]interface{}{}

	if body.Usercode != nil {
		updateData["usercode"] = *body.Usercode
	}
	if body.Firstname != nil {
		updateData["firstname"] = *body.Firstname
	}
	if body.Lastname != nil {
		updateData["lastname"] = *body.Lastname
	}
	if body.Email != nil {
		updateData["email"] = *body.Email
	}
	if body.Username != nil {
		updateData["username"] = *body.Username
	}
	if body.Active != nil {
		updateData["active"] = *body.Active
	}
	if body.ClearVendor != nil && *body.ClearVendor {
		updateData["vendor_id"] = nil
	} else if body.VendorID != nil {
		if *body.VendorID == 0 {
			updateData["vendor_id"] = nil
		} else {
			var v models.Vendor
			if err := vendorDB.Where("id = ? AND tenant_id = ?", *body.VendorID, tid).First(&v).Error; err != nil {
				return c.Status(400).JSON(fiber.Map{"error": "vendor_id is invalid"})
			}
			updateData["vendor_id"] = *body.VendorID
		}
	}

	if body.Password != nil && *body.Password != "" {
		hashed, err := hashPassword(*body.Password)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "Password encryption failed"})
		}
		updateData["password"] = hashed
		updateData["plain_password"] = *body.Password
	}

	if len(updateData) > 0 {
		updateData["updated_at"] = time.Now()
		if err := userDB.Model(&user).Updates(updateData).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "Failed to update user"})
		}
	}

	userDB.Where("id = ? AND tenant_id = ?", id, tid).First(&user)
	return c.JSON(user)
}


func DeleteUser(c *fiber.Ctx) error {
	id := c.Params("id")
	tid := tenantIDFromCtx(c)
	if err := userDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.User{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to delete user", "details": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "User deleted"})
}


func RestoreUser(c *fiber.Ctx) error {
	id := c.Params("id")

	tid := tenantIDFromCtx(c)
	if err := userDB.Unscoped().Model(&models.User{}).
		Where("id = ? AND tenant_id = ?", id, tid).
		Update("deleted_at", nil).Error; err != nil {

		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"message": "User restored"})
}

func ForceDeleteUser(c *fiber.Ctx) error {
	id := c.Params("id")
	tid := tenantIDFromCtx(c)

	if err := userDB.Unscoped().Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.User{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"message": "User permanently deleted"})
}

func ImportUsers(c *fiber.Ctx) error {
	var users []CreateUserRequest
	tid := tenantIDFromCtx(c)

	if err := c.BodyParser(&users); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid Request"})
	}

	var successCount int
	var errorMsgs []string

	for i, body := range users {
		if body.Email == "" {
			errorMsgs = append(errorMsgs, fmt.Sprintf("Row %d: Email is required", i+1))
			continue
		}

		hashedPassword, _ := hashPassword("default123")
		if body.Password != "" {
			hashedPassword, _ = hashPassword(body.Password)
		}

		user := models.User{
			TenantID:      tid,
			Usercode:      body.Usercode,
			Firstname:     body.Firstname,
			Lastname:      body.Lastname,
			Username:      stringPtrToString(body.Username),
			Email:         body.Email,
			Password:      hashedPassword,
			PlainPassword: body.Password,
			Active:        boolPtrToBool(body.Active),
		}

		if err := userDB.Create(&user).Error; err != nil {
			errorMsgs = append(errorMsgs, fmt.Sprintf("Row %d: Failed to create user - %s", i+1, err.Error()))
			continue
		}
		successCount++
	}

	return c.JSON(fiber.Map{
		"imported": successCount,
		"errors":   errorMsgs,
		"total":    len(users),
	})
}

// GetVendorUsers lists users mapped to a vendor (platform admin).
func GetVendorUsers(c *fiber.Ctx) error {
	if err := forbidVendorPortal(c); err != nil {
		return err
	}
	tid := tenantIDFromCtx(c)
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	q := userDB.Model(&models.User{}).Where("tenant_id = ? AND vendor_id IS NOT NULL", tid)
	if vid := c.QueryInt("vendor_id", 0); vid > 0 {
		q = q.Where("vendor_id = ?", uint(vid))
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var rows []models.User
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	type rowOut struct {
		models.User
		VendorName string `json:"vendor_name,omitempty"`
	}
	out := make([]rowOut, 0, len(rows))
	for _, u := range rows {
		item := rowOut{User: u}
		if u.VendorID != nil {
			var v models.Vendor
			if err := vendorDB.Where("id = ? AND tenant_id = ?", *u.VendorID, tid).First(&v).Error; err == nil {
				item.VendorName = v.BusinessName
			}
		}
		out = append(out, item)
	}
	return c.JSON(fiber.Map{"data": out, "total": total, "page": page, "limit": limit})
}

