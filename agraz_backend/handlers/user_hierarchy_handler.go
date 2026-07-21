package handler

import (
	"errors"
	"time"

	"erp.local/backend/models"

	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var userRelationDB *gorm.DB

func SetUserRelationDB(db *gorm.DB) {
	userRelationDB = db
}

// Request DTOs
type CreateUserRelationRequest struct {
	ParentID     uint   `json:"parent_id"`
	ChildID      uint   `json:"child_id"`
	RelationType string `json:"relation_type"`
}

type UpdateUserRelationRequest struct {
	RelationType *string `json:"relation_type"`
}

// ✅ Create new relation
func CreateUserRelation(c *fiber.Ctx) error {
	var body CreateUserRelationRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	if body.ParentID == 0 || body.ChildID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "ParentID and ChildID are required"})
	}

	if body.ParentID == body.ChildID {
		return c.Status(400).JSON(fiber.Map{"error": "Parent and child cannot be the same"})
	}

	relation := models.UserHierarchy{
		ParentID:     body.ParentID,
		ChildID:      body.ChildID,
		RelationType: body.RelationType,
	}

	if err := userRelationDB.Create(&relation).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(201).JSON(relation)
}

// ✅ Get all relations (optionally filter by parent or child)
func GetUserRelations(c *fiber.Ctx) error {
	parentID := c.Query("parent_id")
	childID := c.Query("child_id")

	var relations []models.UserHierarchy
	// No preloads defined on UserHierarchy model; query plain table
	query := userRelationDB.Model(&models.UserHierarchy{})

	if parentID != "" {
		query = query.Where("parent_id = ?", parentID)
	}
	if childID != "" {
		query = query.Where("child_id = ?", childID)
	}

	if err := query.Find(&relations).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(relations)
}

// ✅ Get single relation by ID
func GetUserRelation(c *fiber.Ctx) error {
	id := c.Params("id")

	var relation models.UserHierarchy
	if err := userRelationDB.First(&relation, id).Error; err != nil {

		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "Relation not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(relation)
}

// ✅ Update relation type
func UpdateUserRelation(c *fiber.Ctx) error {
	id := c.Params("id")
	var body UpdateUserRelationRequest

	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	var relation models.UserHierarchy
	if err := userRelationDB.First(&relation, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Relation not found"})
	}

	updateData := map[string]interface{}{}
	if body.RelationType != nil {
		updateData["relation_type"] = *body.RelationType
		updateData["updated_at"] = time.Now()
	}

	if len(updateData) > 0 {
		if err := userRelationDB.Model(&relation).Updates(updateData).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}

	return c.JSON(relation)
}

// ✅ Delete (soft delete optional)
func DeleteUserRelation(c *fiber.Ctx) error {
	id := c.Params("id")

	if err := userRelationDB.Delete(&models.UserHierarchy{}, id).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"message": "Relation deleted"})
}
