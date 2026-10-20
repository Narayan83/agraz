package seeds

import (
	"encoding/json"
	"fmt"
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
)

var fullMenuPerms = map[string]bool{
	"can_view":   true,
	"can_create": true,
	"can_update": true,
	"can_delete": true,
	"can_all":    true,
}

// SeedTransactionsMenus creates the end-user "Transactions" group (app-parity entry screens).
func SeedTransactionsMenus() {
	parent := models.Menu{
		MenuName:  "Transactions",
		URL:       "/transactions",
		Icon:      "Wallet",
		SortOrder: 5,
		IsActive:  true,
		MenuType:  "main",
		Children: []models.Menu{
			{MenuName: "Income & Expenses", URL: "/transactions/income-expense", Icon: "Wallet", SortOrder: 1, IsActive: true, MenuType: "main"},
			{MenuName: "Manage Organization", URL: "/transactions/organizations", Icon: "Building2", SortOrder: 2, IsActive: true, MenuType: "main"},
			{MenuName: "Labour Entry", URL: "/transactions/labour", Icon: "Briefcase", SortOrder: 3, IsActive: true, MenuType: "main"},
			{MenuName: "Labour Work Entry", URL: "/transactions/labour-work", Icon: "ClipboardList", SortOrder: 4, IsActive: true, MenuType: "main"},
			{MenuName: "Dairy", URL: "/transactions/dairy", Icon: "Milk", SortOrder: 5, IsActive: true, MenuType: "main"},
			{MenuName: "Dairy Owner", URL: "/transactions/dairy-owner", Icon: "Milk", SortOrder: 6, IsActive: true, MenuType: "main"},
			{MenuName: "Notes", URL: "/transactions/notes", Icon: "FileText", SortOrder: 7, IsActive: true, MenuType: "main"},
			{MenuName: "Future Plans", URL: "/transactions/future-plans", Icon: "CalendarDays", SortOrder: 8, IsActive: true, MenuType: "main"},
			{MenuName: "RTC Entry", URL: "/transactions/rtc", Icon: "Map", SortOrder: 9, IsActive: true, MenuType: "main"},
			{MenuName: "Documents", URL: "/transactions/documents", Icon: "FolderOpen", SortOrder: 10, IsActive: true, MenuType: "main"},
			{MenuName: "Event Manage", URL: "/transactions/events", Icon: "CalendarDays", SortOrder: 11, IsActive: true, MenuType: "main"},
		},
	}

	var existing models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", parent.MenuName, parent.URL).First(&existing).Error; err != nil {
		if err := initializers.DB.Create(&parent).Error; err != nil {
			log.Printf("Failed to seed Transactions menu: %v", err)
			return
		}
		fmt.Printf("Seeded Menu: %s\n", parent.MenuName)
		return
	}

	initializers.DB.Model(&existing).Updates(models.Menu{
		MenuType:  parent.MenuType,
		IsActive:  true,
		Icon:      parent.Icon,
		SortOrder: parent.SortOrder,
	})
	for _, child := range parent.Children {
		ensureMenuChild(existing.ID, child.MenuName, child.URL, child.Icon, child.SortOrder)
	}
}

func ensureMenuChild(parentID uint, name, url, icon string, sort int) {
	var existing models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", name, url).First(&existing).Error; err != nil {
		child := models.Menu{
			MenuName:  name,
			URL:       url,
			Icon:      icon,
			SortOrder: sort,
			IsActive:  true,
			MenuType:  "main",
			ParentID:  &parentID,
		}
		if err := initializers.DB.Create(&child).Error; err != nil {
			log.Printf("Failed to seed %s menu: %v", name, err)
		} else {
			fmt.Printf("Seeded Menu: %s\n", name)
		}
		return
	}
	initializers.DB.Model(&existing).Updates(models.Menu{
		ParentID:  &parentID,
		Icon:      icon,
		SortOrder: sort,
		IsActive:  true,
		MenuType:  "main",
	})
}

// SeedUserRoleTransactionPermissions grants the User role view/create/update/delete
// on the Transactions menu tree (idempotent merge).
func SeedUserRoleTransactionPermissions() {
	var role models.Role
	if err := initializers.DB.Where("role_name = ?", "User").First(&role).Error; err != nil {
		log.Printf("SeedUserRoleTransactionPermissions: User role missing: %v", err)
		return
	}

	var parent models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Transactions", "/transactions").
		Preload("Children").First(&parent).Error; err != nil {
		log.Printf("SeedUserRoleTransactionPermissions: Transactions menu missing: %v", err)
		return
	}

	menuIDs := []uint{parent.ID}
	seen := map[uint]bool{parent.ID: true}
	for _, ch := range parent.Children {
		if !seen[ch.ID] {
			menuIDs = append(menuIDs, ch.ID)
			seen[ch.ID] = true
		}
	}
	// Also pick up children that may not be preloaded (ensure by parent_id).
	var children []models.Menu
	_ = initializers.DB.Where("parent_id = ? AND is_active = true", parent.ID).Find(&children).Error
	for _, ch := range children {
		if !seen[ch.ID] {
			menuIDs = append(menuIDs, ch.ID)
			seen[ch.ID] = true
		}
	}

	perms := make(map[string]map[string]bool)
	var rm models.RoleManagement
	result := initializers.DB.Where("role_id = ?", role.ID).Find(&rm)
	if result.Error != nil {
		log.Printf("SeedUserRoleTransactionPermissions: lookup failed: %v", result.Error)
		return
	}
	if result.RowsAffected > 0 && len(rm.RoleManagementPermissions) > 0 {
		_ = json.Unmarshal(rm.RoleManagementPermissions, &perms)
	}
	if perms == nil {
		perms = make(map[string]map[string]bool)
	}

	for _, id := range menuIDs {
		key := fmt.Sprintf("%d", id)
		perms[key] = fullMenuPerms
	}

	bytes, err := json.Marshal(perms)
	if err != nil {
		log.Printf("SeedUserRoleTransactionPermissions: marshal: %v", err)
		return
	}

	if result.RowsAffected == 0 {
		rm = models.RoleManagement{
			RoleID:                    role.ID,
			MenuID:                    parent.ID,
			RoleManagementPermissions: bytes,
		}
		if err := initializers.DB.Create(&rm).Error; err != nil {
			log.Printf("SeedUserRoleTransactionPermissions: create: %v", err)
			return
		}
	} else {
		if err := initializers.DB.Model(&rm).Update("role_management_permissions", bytes).Error; err != nil {
			log.Printf("SeedUserRoleTransactionPermissions: update: %v", err)
			return
		}
	}
	fmt.Printf("Seeded User role permissions for Transactions (%d menus)\n", len(menuIDs))
}

// EnsureDefaultUserRoleAssignments assigns the User role to every account that has no role yet.
func EnsureDefaultUserRoleAssignments() {
	var role models.Role
	if err := initializers.DB.Where("role_name = ?", "User").First(&role).Error; err != nil {
		log.Printf("EnsureDefaultUserRoleAssignments: User role missing: %v", err)
		return
	}

	var users []models.User
	if err := initializers.DB.Select("id").Find(&users).Error; err != nil {
		log.Printf("EnsureDefaultUserRoleAssignments: list users: %v", err)
		return
	}

	assigned := 0
	for _, u := range users {
		var count int64
		initializers.DB.Model(&models.UserRoleMapping{}).Where("user_id = ?", u.ID).Count(&count)
		if count > 0 {
			continue
		}
		m := models.UserRoleMapping{UserID: u.ID, RoleID: role.ID}
		if err := initializers.DB.Create(&m).Error; err != nil {
			log.Printf("EnsureDefaultUserRoleAssignments: user %d: %v", u.ID, err)
			continue
		}
		assigned++
	}
	if assigned > 0 {
		fmt.Printf("Assigned User role to %d existing user(s) without roles\n", assigned)
	}
}
