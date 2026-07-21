package handler

import (
	"strconv"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var userRoleMappingDB *gorm.DB

func SetUserRoleMappingDB(db *gorm.DB) {
	userRoleMappingDB = db
}

// GetUserRoles - Get all roles for a specific user
func GetUserRoles(c *fiber.Ctx) error {
	userID := c.Params("user_id")

	var userRoleMappings []models.UserRoleMapping
	if err := userRoleMappingDB.
		Where("user_id = ?", userID).
		Preload("Role").
		Find(&userRoleMappings).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	// Extract roles from mappings
	roles := make([]models.Role, len(userRoleMappings))
	for i, mapping := range userRoleMappings {
		roles[i] = mapping.Role
	}

	return c.JSON(roles)
}

// AssignRoleToUser - Assign a role to a user
func AssignRoleToUser(c *fiber.Ctx) error {
	userID := c.Params("user_id")
	roleID := c.Params("role_id")

	// Convert IDs to uint
	userIDUint, err := strconv.ParseUint(userID, 10, 32)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}

	roleIDUint, err := strconv.ParseUint(roleID, 10, 32)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid role ID"})
	}

	// Check if mapping already exists
	var existingMapping models.UserRoleMapping
	result := userRoleMappingDB.
		Where("user_id = ? AND role_id = ?", userIDUint, roleIDUint).
		First(&existingMapping)

	if result.Error == nil {
		return c.Status(409).JSON(fiber.Map{"error": "Role already assigned to user"})
	}

	// Create new mapping
	mapping := models.UserRoleMapping{
		UserID: uint(userIDUint),
		RoleID: uint(roleIDUint),
	}

	if err := userRoleMappingDB.Create(&mapping).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(201).JSON(fiber.Map{
		"message": "Role assigned to user successfully",
		"mapping": mapping,
	})
}

// RemoveRoleFromUser - Remove a role from a user
func RemoveRoleFromUser(c *fiber.Ctx) error {
	userID := c.Params("user_id")
	roleID := c.Params("role_id")

	// Convert IDs to uint
	userIDUint, err := strconv.ParseUint(userID, 10, 32)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}

	roleIDUint, err := strconv.ParseUint(roleID, 10, 32)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid role ID"})
	}

	// Delete the mapping
	result := userRoleMappingDB.
		Where("user_id = ? AND role_id = ?", userIDUint, roleIDUint).
		Delete(&models.UserRoleMapping{})

	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": result.Error.Error()})
	}

	if result.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Role mapping not found"})
	}

	return c.JSON(fiber.Map{"message": "Role removed from user successfully"})
}

// GetUsersByRole - Get all users for a specific role
func GetUsersByRole(c *fiber.Ctx) error {
	roleID := c.Params("role_id")

	var userRoleMappings []models.UserRoleMapping
	if err := userRoleMappingDB.
		Where("role_id = ?", roleID).
		Preload("User").
		Find(&userRoleMappings).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	// Extract users from mappings
	users := make([]models.User, len(userRoleMappings))
	for i, mapping := range userRoleMappings {
		users[i] = mapping.User
	}

	return c.JSON(users)
}

// UpdateUserRoles - Replace all roles for a user (bulk update)
func UpdateUserRoles(c *fiber.Ctx) error {
	userID := c.Params("user_id")

	// Convert userID to uint
	userIDUint, err := strconv.ParseUint(userID, 10, 32)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}

	// Parse request body
	var request struct {
		RoleIDs []uint `json:"role_ids"`
	}

	if err := c.BodyParser(&request); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request data"})
	}

	// Start transaction
	tx := userRoleMappingDB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Remove existing roles for this user
	if err := tx.Where("user_id = ?", userIDUint).Delete(&models.UserRoleMapping{}).Error; err != nil {
		tx.Rollback()
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	// Add new roles
	for _, roleID := range request.RoleIDs {
		mapping := models.UserRoleMapping{
			UserID: uint(userIDUint),
			RoleID: roleID,
		}
		if err := tx.Create(&mapping).Error; err != nil {
			tx.Rollback()
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}

	// Commit transaction
	if err := tx.Commit().Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{
		"message":  "User roles updated successfully",
		"user_id":  userIDUint,
		"role_ids": request.RoleIDs,
	})
}
