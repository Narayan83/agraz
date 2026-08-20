package handler

import (
	"encoding/json"
	"errors"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

const maxFamilyMembers = 10

type familyMemberIn struct {
	Firstname        string   `json:"firstname"`
	Lastname         string   `json:"lastname"`
	Email            string   `json:"email"`
	Phone            string   `json:"phone"`
	Password         string   `json:"password"`
	ConfirmPassword  string   `json:"confirm_password"`
	Active           *bool    `json:"active"`
	DisabledFeatures []string `json:"disabled_features"`
}

func ListAppFeatures(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"features": models.AppFeatures})
}

func ListFamilyMembers(c *fiber.Ctx) error {
	ownerID, err := requireMainAccount(c)
	if err != nil {
		return err
	}
	tid := tenantIDFromCtx(c)
	var members []models.User
	if err := userDB.Where("parent_user_id = ? AND tenant_id = ?", ownerID, tid).
		Order("created_at ASC").Find(&members).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to load family members"})
	}
	out := make([]fiber.Map, 0, len(members))
	for _, m := range members {
		out = append(out, familyMemberPayload(m))
	}
	return c.JSON(fiber.Map{
		"members": out,
		"total":   len(out),
		"limit":   maxFamilyMembers,
	})
}

func CreateFamilyMember(c *fiber.Ctx) error {
	ownerID, err := requireMainAccount(c)
	if err != nil {
		return err
	}
	var body familyMemberIn
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	firstname := strings.TrimSpace(body.Firstname)
	email := strings.ToLower(strings.TrimSpace(body.Email))
	phone := normalizeFamilyPhone(body.Phone)
	if firstname == "" {
		return c.Status(400).JSON(fiber.Map{"error": "firstname is required"})
	}
	if email == "" {
		return c.Status(400).JSON(fiber.Map{"error": "email is required"})
	}
	if phone == "" {
		return c.Status(400).JSON(fiber.Map{"error": "phone is required"})
	}
	if body.Password == "" || len(body.Password) < 6 {
		return c.Status(400).JSON(fiber.Map{"error": "Password must be at least 6 characters"})
	}
	if body.ConfirmPassword != "" && body.ConfirmPassword != body.Password {
		return c.Status(400).JSON(fiber.Map{"error": "passwords do not match"})
	}

	tid := tenantIDFromCtx(c)
	var count int64
	if err := userDB.Model(&models.User{}).
		Where("parent_user_id = ? AND tenant_id = ?", ownerID, tid).
		Count(&count).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to validate family size"})
	}
	if count >= maxFamilyMembers {
		return c.Status(400).JSON(fiber.Map{"error": "Maximum family members reached"})
	}

	var existing models.User
	if err := userDB.Where("LOWER(email) = ?", email).First(&existing).Error; err == nil {
		return c.Status(409).JSON(fiber.Map{"error": "This email is already registered"})
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to validate email"})
	}
	if err := userDB.Where("mobile_number = ? AND tenant_id = ?", phone, tid).First(&existing).Error; err == nil {
		return c.Status(409).JSON(fiber.Map{"error": "This mobile number is already registered"})
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to validate mobile number"})
	}

	hash, err := hashPassword(body.Password)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Password encryption failed"})
	}
	parentID := ownerID
	user := models.User{
		TenantID:         tid,
		Firstname:        firstname,
		Lastname:         strings.TrimSpace(body.Lastname),
		Email:            email,
		Password:         hash,
		PlainPassword:    body.Password,
		Active:           true,
		Approved:         true,
		MobileNumber:     &phone,
		ParentUserID:     &parentID,
		DisabledFeatures: marshalDisabledFeatures(body.DisabledFeatures),
	}
	if err := userDB.Create(&user).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create family member", "details": err.Error()})
	}
	var role models.Role
	if err := userDB.Where("role_name = ?", "User").First(&role).Error; err == nil {
		_ = userDB.Create(&models.UserRoleMapping{UserID: user.ID, RoleID: role.ID}).Error
	}
	return c.Status(201).JSON(fiber.Map{
		"message": "Family member created. They can log in with this email and password.",
		"member":  familyMemberPayload(user),
	})
}

func UpdateFamilyMember(c *fiber.Ctx) error {
	ownerID, err := requireMainAccount(c)
	if err != nil {
		return err
	}
	member, err := familyMemberOfOwner(c, ownerID)
	if err != nil {
		return err
	}
	var body familyMemberIn
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}

	tid := tenantIDFromCtx(c)
	updates := map[string]interface{}{"updated_at": time.Now()}
	if strings.TrimSpace(body.Firstname) != "" {
		updates["firstname"] = strings.TrimSpace(body.Firstname)
		updates["lastname"] = strings.TrimSpace(body.Lastname)
	}
	if phone := normalizeFamilyPhone(body.Phone); phone != "" {
		var other models.User
		if err := userDB.Where("mobile_number = ? AND tenant_id = ? AND id <> ?", phone, tid, member.ID).
			First(&other).Error; err == nil {
			return c.Status(409).JSON(fiber.Map{"error": "This mobile number is already registered"})
		} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(500).JSON(fiber.Map{"error": "Failed to validate mobile number"})
		}
		updates["mobile_number"] = phone
	}
	if email := strings.ToLower(strings.TrimSpace(body.Email)); email != "" &&
		!strings.EqualFold(email, member.Email) {
		var other models.User
		if err := userDB.Where("LOWER(email) = ? AND id <> ?", email, member.ID).First(&other).Error; err == nil {
			return c.Status(409).JSON(fiber.Map{"error": "This email is already registered"})
		} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(500).JSON(fiber.Map{"error": "Failed to validate email"})
		}
		updates["email"] = email
	}
	if body.Active != nil {
		updates["active"] = *body.Active
	}
	if body.DisabledFeatures != nil {
		updates["disabled_features"] = marshalDisabledFeatures(body.DisabledFeatures)
	}
	if body.Password != "" {
		if len(body.Password) < 6 {
			return c.Status(400).JSON(fiber.Map{"error": "Password must be at least 6 characters"})
		}
		if body.ConfirmPassword != "" && body.ConfirmPassword != body.Password {
			return c.Status(400).JSON(fiber.Map{"error": "passwords do not match"})
		}
		hash, err := hashPassword(body.Password)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "Password encryption failed"})
		}
		updates["password"] = hash
		updates["plain_password"] = body.Password
	}
	if err := userDB.Model(&member).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update family member"})
	}
	userDB.First(&member, member.ID)
	return c.JSON(fiber.Map{"member": familyMemberPayload(member)})
}

func DeleteFamilyMember(c *fiber.Ctx) error {
	ownerID, err := requireMainAccount(c)
	if err != nil {
		return err
	}
	member, err := familyMemberOfOwner(c, ownerID)
	if err != nil {
		return err
	}
	if err := userDB.Model(&member).Updates(map[string]interface{}{
		"active":     false,
		"updated_at": time.Now(),
	}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to remove family member"})
	}
	userDB.First(&member, member.ID)
	return c.JSON(fiber.Map{
		"message": "Family member access has been disabled",
		"member":  familyMemberPayload(member),
	})
}

func requireMainAccount(c *fiber.Ctx) (uint, error) {
	uid, err := actorUserID(c)
	if err != nil {
		return 0, err
	}
	var u models.User
	tid := tenantIDFromCtx(c)
	if err := userDB.Where("id = ? AND tenant_id = ?", uid, tid).First(&u).Error; err != nil {
		return 0, fiber.NewError(fiber.StatusNotFound, "User not found")
	}
	if u.ParentUserID != nil && *u.ParentUserID > 0 {
		return 0, fiber.NewError(fiber.StatusForbidden, "Only the main account holder can manage family members")
	}
	return uid, nil
}

func familyMemberOfOwner(c *fiber.Ctx, ownerID uint) (models.User, error) {
	var member models.User
	id, err := c.ParamsInt("id")
	if err != nil || id <= 0 {
		return member, fiber.NewError(fiber.StatusBadRequest, "invalid member id")
	}
	tid := tenantIDFromCtx(c)
	if err := userDB.Where("id = ? AND parent_user_id = ? AND tenant_id = ?", id, ownerID, tid).
		First(&member).Error; err != nil {
		return member, fiber.NewError(fiber.StatusNotFound, "Family member not found")
	}
	return member, nil
}

func familyMemberPayload(u models.User) fiber.Map {
	return fiber.Map{
		"id":                 u.ID,
		"firstname":          u.Firstname,
		"lastname":           u.Lastname,
		"email":              u.Email,
		"mobile_number":      u.MobileNumber,
		"active":             u.Active,
		"approved":           u.Approved,
		"parent_user_id":     u.ParentUserID,
		"disabled_features":  parseDisabledFeatureList(u.DisabledFeatures),
		"created_at":         u.CreatedAt,
	}
}

func normalizeFamilyPhone(phone string) string {
	phone = strings.TrimSpace(phone)
	phone = strings.TrimLeft(phone, "+")
	return strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, phone)
}

func parseDisabledFeatureList(raw datatypes.JSON) []string {
	if len(raw) == 0 {
		return []string{}
	}
	var keys []string
	if err := json.Unmarshal(raw, &keys); err != nil || keys == nil {
		return []string{}
	}
	out := make([]string, 0, len(keys))
	seen := map[string]bool{}
	for _, k := range keys {
		k = strings.TrimSpace(k)
		if k == "" || seen[k] || !models.IsKnownAppFeature(k) {
			continue
		}
		seen[k] = true
		out = append(out, k)
	}
	return out
}

func marshalDisabledFeatures(keys []string) datatypes.JSON {
	clean := parseDisabledFeatureList(mustJSON(keys))
	raw, err := json.Marshal(clean)
	if err != nil {
		return datatypes.JSON([]byte("[]"))
	}
	return datatypes.JSON(raw)
}

func mustJSON(keys []string) datatypes.JSON {
	if keys == nil {
		keys = []string{}
	}
	raw, err := json.Marshal(keys)
	if err != nil {
		return datatypes.JSON([]byte("[]"))
	}
	return datatypes.JSON(raw)
}
