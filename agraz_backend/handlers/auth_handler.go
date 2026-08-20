package handler

import (
	"errors"
	"os"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func Login(c *fiber.Ctx) error {
	type LoginInput struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	var input LoginInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"message": "Invalid request body"})
	}

	email := strings.TrimSpace(strings.ToLower(input.Email))
	password := input.Password
	if email == "" || password == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"message": "Email and password are required"})
	}

	tid := tenantIDFromCtx(c)
	var user models.User
	// Case-insensitive email match (stored emails may vary in casing).
	if err := userDB.Where("LOWER(email) = ? AND tenant_id = ?", email, tid).First(&user).Error; err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"message": "Invalid email or password"})
	}

	// Compare password
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)); err != nil {
		// Fallback for plain text passwords (if any, during migration)
		if user.Password != password {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"message": "Invalid email or password"})
		}
	}

	if !user.Approved {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"message":  "You are in cooling period. Please wait for approval.",
			"code":     "cooling_period",
			"approved": false,
		})
	}

	if !user.Active {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"message": "User is inactive"})
	}

	if user.ParentUserID != nil && *user.ParentUserID > 0 {
		var parent models.User
		if err := userDB.Where("id = ? AND tenant_id = ?", *user.ParentUserID, tid).First(&parent).Error; err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"message": "Main account is no longer available"})
		}
		if !parent.Approved {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"message":  "You are in cooling period. Please wait for approval.",
				"code":     "cooling_period",
				"approved": false,
			})
		}
		if !parent.Active {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"message": "Main account is inactive"})
		}
	}

	// Create JWT Token
	token := jwt.New(jwt.SigningMethodHS256)
	claims := token.Claims.(jwt.MapClaims)
	claims["user_id"] = user.ID
	claims["email"] = user.Email
	if user.VendorID != nil && *user.VendorID > 0 {
		claims["vendor_id"] = *user.VendorID
	}
	claims["exp"] = time.Now().Add(time.Hour * 72).Unix() // 3 days

	t, err := token.SignedString([]byte(os.Getenv("JWT_SECRET")))
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"message": "Could not generate token"})
	}

	return c.JSON(fiber.Map{
		"token": t,
		"user":  accountSessionPayload(user),
	})
}

// ChangeMyPassword handles PUT /api/me/password (authenticated).
func ChangeMyPassword(c *fiber.Ctx) error {
	uid, ok := userIDFromCtx(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "Unauthorized"})
	}
	type bodyIn struct {
		CurrentPassword string `json:"current_password"`
		NewPassword     string `json:"new_password"`
	}
	var body bodyIn
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	if strings.TrimSpace(body.NewPassword) == "" || len(body.NewPassword) < 6 {
		return c.Status(400).JSON(fiber.Map{"error": "New password must be at least 6 characters"})
	}
	tid := tenantIDFromCtx(c)
	var user models.User
	if err := userDB.Where("id = ? AND tenant_id = ?", uid, tid).First(&user).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(body.CurrentPassword)); err != nil {
		if user.Password != body.CurrentPassword {
			return c.Status(400).JSON(fiber.Map{"error": "Current password is incorrect"})
		}
	}
	hashed, err := hashPassword(body.NewPassword)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Password encryption failed"})
	}
	if err := userDB.Model(&user).Updates(map[string]interface{}{
		"password":       hashed,
		"plain_password": body.NewPassword,
		"updated_at":     time.Now(),
	}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update password"})
	}
	return c.JSON(fiber.Map{"message": "Password updated successfully"})
}

// UpdateMe handles PUT /api/me (authenticated profile edit).
func UpdateMe(c *fiber.Ctx) error {
	uid, ok := userIDFromCtx(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "Unauthorized"})
	}
	if isSubUser(c) {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"error":   "Only the main account holder can update account details",
			"message": "Only the main account holder can update account details",
		})
	}
	type bodyIn struct {
		Firstname    *string `json:"firstname"`
		Lastname     *string `json:"lastname"`
		MobileNumber *string `json:"mobile_number"`
	}
	var body bodyIn
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	tid := tenantIDFromCtx(c)
	var user models.User
	if err := userDB.Where("id = ? AND tenant_id = ?", uid, tid).First(&user).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}
	updates := map[string]interface{}{"updated_at": time.Now()}
	if body.Firstname != nil {
		fn := strings.TrimSpace(*body.Firstname)
		if fn == "" {
			return c.Status(400).JSON(fiber.Map{"error": "firstname cannot be empty"})
		}
		updates["firstname"] = fn
	}
	if body.Lastname != nil {
		updates["lastname"] = strings.TrimSpace(*body.Lastname)
	}
	if body.MobileNumber != nil {
		phone := strings.TrimSpace(*body.MobileNumber)
		phone = strings.TrimLeft(phone, "+")
		if phone == "" {
			updates["mobile_number"] = nil
		} else {
			var other models.User
			if err := userDB.Where("mobile_number = ? AND tenant_id = ? AND id <> ?", phone, tid, uid).First(&other).Error; err == nil {
				return c.Status(409).JSON(fiber.Map{"error": "This mobile number is already registered"})
			} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
				return c.Status(500).JSON(fiber.Map{"error": "Failed to validate mobile number"})
			}
			updates["mobile_number"] = phone
		}
	}
	if err := userDB.Model(&user).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update profile"})
	}
	userDB.Where("id = ? AND tenant_id = ?", uid, tid).First(&user)
	return c.JSON(accountSessionPayload(user))
}
