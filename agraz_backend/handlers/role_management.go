package handler

import (
	"encoding/json"
	"strconv"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var rolemanageDB *gorm.DB

func SetRolesManagementDB(db *gorm.DB) {
	rolemanageDB = db
}

// GetRolePermissions - Get all permissions for a specific role
func GetRolePermissions(c *fiber.Ctx) error {
	roleID := c.Params("id")

	var rolemanagement models.RoleManagement
	result := rolemanageDB.Where("role_id = ?", roleID).Find(&rolemanagement)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": result.Error.Error()})
	}
	if result.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Role permissions not found"})
	}

	// Parse permissions JSON
	var permissions map[string]interface{}
	if len(rolemanagement.RoleManagementPermissions) > 0 {
		if err := json.Unmarshal(rolemanagement.RoleManagementPermissions, &permissions); err != nil {
			permissions = make(map[string]interface{})
		}
	} else {
		permissions = make(map[string]interface{})
	}

	return c.JSON(fiber.Map{
		"role_id":     rolemanagement.RoleID,
		"menu_id":     rolemanagement.MenuID,
		"permissions": permissions,
	})
}

// UpdateRolePermissions - Update permissions for a role
func UpdateRolePermissions(c *fiber.Ctx) error {
	roleID := c.Params("id")

	// Convert roleID to uint
	roleIDUint, err := strconv.ParseUint(roleID, 10, 32)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid role ID"})
	}

	// Parse the permissions JSON
	var permissionsData map[string]interface{}
	if err := c.BodyParser(&permissionsData); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid permissions data"})
	}

	// Convert incoming keys to menu IDs (strings). If a key is non-numeric, try to find menu by name.
	converted := make(map[string]interface{})
	var unknownKeys []string
	for k, v := range permissionsData {
		if _, err := strconv.ParseUint(k, 10, 64); err == nil {
			// already numeric key - keep as-is
			converted[k] = v
			continue
		}
		// try to find menu by menu_name or name
		var menu models.Menu
		if err := rolemanageDB.Where("menu_name = ? OR name = ?", k, k).First(&menu).Error; err != nil {
			// not found - record unknown key
			unknownKeys = append(unknownKeys, k)
			continue
		}
		key := strconv.FormatUint(uint64(menu.ID), 10)
		converted[key] = v
	}

	if len(unknownKeys) > 0 {
		// refuse to save mixed name keys; require frontend to send valid menu IDs or correct names
		return c.Status(400).JSON(fiber.Map{
			"error":        "Some permission keys could not be mapped to menu IDs",
			"unknown_keys": unknownKeys,
		})
	}

	// Convert to JSONB
	permsBytes, err := json.Marshal(converted)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid permissions format"})
	}

	// Check if record exists, if not create it
	var rolemanagement models.RoleManagement
	result := rolemanageDB.Where("role_id = ?", roleIDUint).Find(&rolemanagement)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": result.Error.Error()})
	}

	if result.RowsAffected == 0 {
		// Create new record
		rolemanagement = models.RoleManagement{
			RoleID:                    uint(roleIDUint),
			RoleManagementPermissions: permsBytes,
		}

		// Find any existing menu ID to satisfy NOT NULL + FK constraints.
		var anyMenu models.Menu
		menuResult := rolemanageDB.Select("id").Where("is_active = true").Order("id").Limit(1).Find(&anyMenu)
		if menuResult.Error != nil {
			return c.Status(500).JSON(fiber.Map{"error": menuResult.Error.Error()})
		}
		if menuResult.RowsAffected == 0 {
			return c.Status(500).JSON(fiber.Map{"error": "no menus found; create at least one menu before adding role permissions"})
		}

		rolemanagement.MenuID = anyMenu.ID

		if err := rolemanageDB.Create(&rolemanagement).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	} else {
		// Update existing record
		if err := rolemanageDB.Model(&rolemanagement).Update("role_management_permissions", permsBytes).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}

	return c.JSON(fiber.Map{
		"message":     "Permissions updated successfully",
		"role_id":     roleIDUint,
		"permissions": converted,
	})
}

// GetRoleMenuTreeWithPermissions - Get menu tree with permissions for a specific role
func GetRoleMenuTreeWithPermissions(c *fiber.Ctx) error {
	roleID := c.Params("id")

	// Convert roleID to uint
	roleIDUint, err := strconv.ParseUint(roleID, 10, 32)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid role ID"})
	}

	// Get role permissions. If no record exists, continue with empty permissions
	var rolemanagement models.RoleManagement
	var permissions map[string]interface{}
	result := rolemanageDB.Where("role_id = ?", roleIDUint).Find(&rolemanagement)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": result.Error.Error()})
	}
	if result.RowsAffected == 0 {
		// no saved permissions for this role yet; use empty permissions map
		permissions = make(map[string]interface{})
	} else {
		// Parse permissions JSON
		if len(rolemanagement.RoleManagementPermissions) > 0 {
			if err := json.Unmarshal(rolemanagement.RoleManagementPermissions, &permissions); err != nil {
				permissions = make(map[string]interface{})
			}
		} else {
			permissions = make(map[string]interface{})
		}
	}

	// Get all menus with their parent-child structure
	var menus []models.Menu
	if err := rolemanageDB.
		Where("parent_id IS NULL AND is_active = true").
		Preload("Children", func(db *gorm.DB) *gorm.DB {
			return db.Where("is_active = true").Order("sort_order")
		}).
		Order("sort_order").
		Find(&menus).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	// helper: default perms
	defaultPerms := map[string]bool{
		"can_view":   false,
		"can_create": false,
		"can_update": false,
		"can_delete": false,
		"can_all":    false,
	}

	// recursive builder: convert a models.Menu into a map with permissions and children
	var build func(m models.Menu) (map[string]interface{}, error)
	build = func(m models.Menu) (map[string]interface{}, error) {
		// marshal menu to generic map to avoid tight coupling with model fields
		b, _ := json.Marshal(m)
		var mm map[string]interface{}
		if err := json.Unmarshal(b, &mm); err != nil {
			mm = make(map[string]interface{})
		}

		// determine permission key by ID first, then by menu_name/name in the marshalled map
		menuIDStr := strconv.FormatUint(uint64(m.ID), 10)
		var perm interface{}
		if p, ok := permissions[menuIDStr]; ok {
			perm = p
		} else {
			// try by menu_name or name
			if nameVal, ok := mm["menu_name"].(string); ok {
				if p, ok := permissions[nameVal]; ok {
					perm = p
				}
			}
			if perm == nil {
				if nameVal, ok := mm["name"].(string); ok {
					if p, ok := permissions[nameVal]; ok {
						perm = p
					}
				}
			}
		}
		if perm == nil {
			perm = defaultPerms
		}
		mm["permissions"] = perm

		// handle children recursively (if present)
		if len(m.Children) > 0 {
			children := make([]map[string]interface{}, 0, len(m.Children))
			for _, ch := range m.Children {
				cm, err := build(ch)
				if err != nil {
					// continue on child error but include minimal child info
					childMap := map[string]interface{}{"id": ch.ID, "permissions": defaultPerms}
					children = append(children, childMap)
					continue
				}
				children = append(children, cm)
			}
			mm["children"] = children
		}

		return mm, nil
	}

	// Build response with permissions attached to every menu node
	var resultMenus []map[string]interface{}
	for _, menu := range menus {
		mmap, err := build(menu)
		if err != nil {
			// fallback: include menu ID with default perms
			mmap = map[string]interface{}{"id": menu.ID, "permissions": defaultPerms}
		}
		resultMenus = append(resultMenus, mmap)
	}

	return c.JSON(resultMenus)
}

// ResetRolePermissions - Reset all permissions for a role to default (empty)
func ResetRolePermissions(c *fiber.Ctx) error {
	roleID := c.Params("id")

	// Convert roleID to uint
	roleIDUint, err := strconv.ParseUint(roleID, 10, 32)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid role ID"})
	}

	var rolemanagement models.RoleManagement
	result := rolemanageDB.Where("role_id = ?", roleIDUint).Find(&rolemanagement)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": result.Error.Error()})
	}
	if result.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Role permissions not found"})
	}

	// Set permissions to empty JSON
	emptyPerms := make(map[string]interface{})
	permsBytes, _ := json.Marshal(emptyPerms)

	if err := rolemanageDB.Model(&rolemanagement).Update("role_management_permissions", permsBytes).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"message": "Permissions reset successfully"})
}
