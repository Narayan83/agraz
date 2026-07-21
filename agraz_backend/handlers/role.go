package handler

import (
	"encoding/json"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var rolesDB *gorm.DB

func SetRolesDB(db *gorm.DB) {
	rolesDB = db
}

func GetAllRoles(c *fiber.Ctx) error {
	var items []models.Role
	var total int64

	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	filter := c.Query("filter")
	isActive := c.Query("is_active")

	if page < 1 {
		page = 1
	}
	offset := (page - 1) * limit

	query := rolesDB.Model(&models.Role{})

	if filter != "" {
		query = query.Where("role_name ILIKE ? OR description ILIKE ?", "%"+filter+"%", "%"+filter+"%")
	}

	if isActive != "" {
		if isActive == "true" {
			query = query.Where("is_active = ?", true)
		} else if isActive == "false" {
			query = query.Where("is_active = ?", false)
		}
	}

	if err := query.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to count records"})
	}

	if err := query.
		Order("role_name").
		Limit(limit).
		Offset(offset).
		Find(&items).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{
		"data":  items,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}

func GetRoleByID(c *fiber.Ctx) error {
	id := c.Params("id")
	var item models.Role
	if err := rolesDB.First(&item, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Role not found"})
	}
	return c.JSON(item)
}

func CreateRole(c *fiber.Ctx) error {
	var item models.Role
	if err := c.BodyParser(&item); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid input"})
	}

	if item.RoleName == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Role name is required"})
	}

	var existingRole models.Role
	if err := rolesDB.Where("role_name = ?", item.RoleName).First(&existingRole).Error; err == nil {
		return c.Status(400).JSON(fiber.Map{"error": "Role name already exists"})
	}

	if item.Permissions == nil {
		defaultPerms := map[string]interface{}{}
		permsBytes, _ := json.Marshal(defaultPerms)
		item.Permissions = permsBytes
	}

	if err := rolesDB.Create(&item).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(201).JSON(item)
}

func UpdateRole(c *fiber.Ctx) error {
	id := c.Params("id")
	var item models.Role

	if err := rolesDB.First(&item, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Role not found"})
	}

	var updateData models.Role
	if err := c.BodyParser(&updateData); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid input"})
	}

	if updateData.RoleName != "" && updateData.RoleName != item.RoleName {
		var existingRole models.Role
		if err := rolesDB.Where("role_name = ? AND id != ?", updateData.RoleName, id).First(&existingRole).Error; err == nil {
			return c.Status(400).JSON(fiber.Map{"error": "Role name already exists"})
		}
	}

	if err := rolesDB.Model(&item).Updates(updateData).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(item)
}

func DeleteRole(c *fiber.Ctx) error {
	id := c.Params("id")

	var item models.Role
	if err := rolesDB.First(&item, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Role not found"})
	}

	if err := rolesDB.Delete(&item).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.SendStatus(204)
}
