package handler

import (
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var employeeDB *gorm.DB

func SetEmployeeDB(db *gorm.DB) {
	employeeDB = db
}

type createEmployeeRequest struct {
	UserID   uint    `json:"user_id"`
	EmpCode  *string `json:"emp_code"`
	Position *string `json:"position"`
}

type updateEmployeeRequest struct {
	UserID   *uint   `json:"user_id"`
	EmpCode  *string `json:"emp_code"`
	Position *string `json:"position"`
}

func CreateEmployee(c *fiber.Ctx) error {
	var body createEmployeeRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if body.UserID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "user_id is required"})
	}

	var u models.User
	if err := employeeDB.First(&u, body.UserID).Error; err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "user not found"})
	}

	emp := models.Employee{
		UserID:   body.UserID,
		EmpCode:  body.EmpCode,
		Position: body.Position,
	}
	if err := employeeDB.Create(&emp).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create employee", "details": err.Error()})
	}
	employeeDB.Preload("User").First(&emp, emp.ID)
	return c.Status(201).JSON(emp)
}

func GetEmployees(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	offset := (page - 1) * limit

	var rows []models.Employee
	var total int64
	q := employeeDB.Model(&models.Employee{}).Preload("User")
	if uid := c.Query("user_id"); uid != "" {
		q = q.Where("user_id = ?", uid)
	}
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetEmployee(c *fiber.Ctx) error {
	var row models.Employee
	if err := employeeDB.Preload("User").First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Employee not found"})
	}
	return c.JSON(row)
}

func UpdateEmployee(c *fiber.Ctx) error {
	var body updateEmployeeRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	var row models.Employee
	if err := employeeDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Employee not found"})
	}

	updates := map[string]interface{}{}
	if body.UserID != nil {
		var u models.User
		if err := employeeDB.First(&u, *body.UserID).Error; err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "user not found"})
		}
		updates["user_id"] = *body.UserID
	}
	if body.EmpCode != nil {
		updates["emp_code"] = body.EmpCode
	}
	if body.Position != nil {
		updates["position"] = body.Position
	}
	if len(updates) == 0 {
		employeeDB.Preload("User").First(&row, row.ID)
		return c.JSON(row)
	}
	if err := employeeDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update", "details": err.Error()})
	}
	employeeDB.Preload("User").First(&row, row.ID)
	return c.JSON(row)
}

func DeleteEmployee(c *fiber.Ctx) error {
	res := employeeDB.Delete(&models.Employee{}, c.Params("id"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Employee not found"})
	}
	return c.JSON(fiber.Map{"message": "Employee deleted"})
}
