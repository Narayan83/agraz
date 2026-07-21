package handler

import (
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var menusDB *gorm.DB

func SetMenusDB(db *gorm.DB) {
	menusDB = db
}

func GetAllMenus(c *fiber.Ctx) error {
	var items []models.Menu
	var total int64

	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	filter := c.Query("filter")
	menuType := c.Query("menu_type")
	isActive := c.Query("is_active")

	if page < 1 {
		page = 1
	}
	offset := (page - 1) * limit

	query := menusDB.Model(&models.Menu{}).Preload("Children")

	if filter != "" {
		query = query.Where("menu_name ILIKE ? OR description ILIKE ?", "%"+filter+"%", "%"+filter+"%")
	}

	if menuType != "" {
		query = query.Where("menu_type = ?", menuType)
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
		Order("menu_type, sort_order, menu_name").
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

func GetMenuByID(c *fiber.Ctx) error {
	id := c.Params("id")
	var item models.Menu
	if err := menusDB.Preload("Children").First(&item, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Menu not found"})
	}
	return c.JSON(item)
}

func CreateMenu(c *fiber.Ctx) error {
	var item models.Menu
	if err := c.BodyParser(&item); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid input"})
	}
	if item.MenuName == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Menu name is required"})
	}

	if err := menusDB.Create(&item).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	if err := menusDB.Preload("Children").First(&item, item.ID).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to load created menu"})
	}

	return c.Status(201).JSON(item)
}

func UpdateMenu(c *fiber.Ctx) error {
	id := c.Params("id")
	var item models.Menu

	if err := menusDB.First(&item, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Menu not found"})
	}

	var updateData models.Menu
	if err := c.BodyParser(&updateData); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid input"})
	}

	if err := menusDB.Model(&item).Updates(updateData).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	if err := menusDB.Preload("Children").First(&item, id).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to load updated menu"})
	}

	return c.JSON(item)
}

func DeleteMenu(c *fiber.Ctx) error {
	id := c.Params("id")

	var item models.Menu
	if err := menusDB.First(&item, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Menu not found"})
	}

	if err := menusDB.Delete(&item).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.SendStatus(204)
}

func GetMenuTree(c *fiber.Ctx) error {
	var allMenus []models.Menu
	
	// Fetch all menus to build tree in memory (handles infinite depth)
	query := menusDB.Model(&models.Menu{})
	
	menuType := c.Query("menu_type")
	isActive := c.Query("is_active")

	if menuType != "" {
		query = query.Where("menu_type = ?", menuType)
	}

	if isActive != "" {
		if isActive == "true" {
			query = query.Where("is_active = ?", true)
		} else if isActive == "false" {
			query = query.Where("is_active = ?", false)
		}
	}

	if err := query.Order("sort_order, menu_name").Find(&allMenus).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	// Map to track children
	childrenMap := make(map[uint][]models.Menu)
	var roots []models.Menu

	for _, m := range allMenus {
		if m.ParentID == nil || *m.ParentID == 0 {
			roots = append(roots, m)
		} else {
			childrenMap[*m.ParentID] = append(childrenMap[*m.ParentID], m)
		}
	}

	// Recursive function to attach children
	var attachChildren func(menu *models.Menu)
	attachChildren = func(menu *models.Menu) {
		if children, ok := childrenMap[menu.ID]; ok {
			for i := range children {
				attachChildren(&children[i])
			}
			menu.Children = children
		} else {
			menu.Children = []models.Menu{} // Ensure empty array instead of null
		}
	}

	for i := range roots {
		attachChildren(&roots[i])
	}

	return c.JSON(roots)
}

func ReorderMenus(c *fiber.Ctx) error {
	type MenuOrder struct {
		ID        uint `json:"id"`
		SortOrder int  `json:"sort_order"`
	}

	var orders []MenuOrder
	if err := c.BodyParser(&orders); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid input"})
	}

	tx := menusDB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	for _, order := range orders {
		if err := tx.Model(&models.Menu{}).
			Where("id = ?", order.ID).
			Update("sort_order", order.SortOrder).Error; err != nil {
			tx.Rollback()
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}

	if err := tx.Commit().Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"message": "Menus reordered successfully"})
}
