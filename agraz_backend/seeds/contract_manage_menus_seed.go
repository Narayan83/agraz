package seeds

import (
	"encoding/json"
	"fmt"
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
)

// SeedContractManageMenus creates Contract Manage parent + child menus (idempotent).
func SeedContractManageMenus() {
	parent := models.Menu{
		MenuName:  "Contract Manage",
		URL:       "/contract-manage",
		Icon:      "Wrench",
		SortOrder: 6,
		IsActive:  true,
		MenuType:  "main",
		Children: []models.Menu{
			{MenuName: "Projects", URL: "/contract-manage/projects", Icon: "Briefcase", SortOrder: 1, IsActive: true, MenuType: "main"},
			{MenuName: "Customers", URL: "/contract-manage/customers", Icon: "Users", SortOrder: 2, IsActive: true, MenuType: "main"},
			{MenuName: "Customer Summary", URL: "/contract-manage/customer-summary", Icon: "BarChart3", SortOrder: 3, IsActive: true, MenuType: "main"},
			{MenuName: "Dealers", URL: "/contract-manage/dealers", Icon: "Store", SortOrder: 4, IsActive: true, MenuType: "main"},
			{MenuName: "Labour Suppliers", URL: "/contract-manage/labour-suppliers", Icon: "Users", SortOrder: 5, IsActive: true, MenuType: "main"},
			{MenuName: "Labours", URL: "/contract-manage/labours", Icon: "ClipboardList", SortOrder: 6, IsActive: true, MenuType: "main"},
			{MenuName: "Labour Work", URL: "/contract-manage/labour-works", Icon: "ClipboardList", SortOrder: 7, IsActive: true, MenuType: "main"},
			{MenuName: "Materials", URL: "/contract-manage/materials", Icon: "Package", SortOrder: 8, IsActive: true, MenuType: "main"},
			{MenuName: "Purchases / Stock", URL: "/contract-manage/purchases", Icon: "Package", SortOrder: 9, IsActive: true, MenuType: "main"},
			{MenuName: "Stock Issues", URL: "/contract-manage/stock-issues", Icon: "Package", SortOrder: 10, IsActive: true, MenuType: "main"},
			{MenuName: "Stock Report", URL: "/contract-manage/stock-report", Icon: "BarChart3", SortOrder: 11, IsActive: true, MenuType: "main"},
			{MenuName: "Payments", URL: "/contract-manage/payments", Icon: "Wallet", SortOrder: 12, IsActive: true, MenuType: "main"},
			{MenuName: "Assets", URL: "/contract-manage/assets", Icon: "Wrench", SortOrder: 13, IsActive: true, MenuType: "main"},
			{MenuName: "Audit Log", URL: "/contract-manage/audit", Icon: "FileClock", SortOrder: 14, IsActive: true, MenuType: "main"},
		},
	}

	var existing models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", parent.MenuName, parent.URL).First(&existing).Error; err != nil {
		if err := initializers.DB.Create(&parent).Error; err != nil {
			log.Printf("Failed to seed Contract Manage menu: %v", err)
			return
		}
		fmt.Printf("Seeded Menu: %s\n", parent.MenuName)
		SeedUserRoleContractManagePermissions()
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
	SeedUserRoleContractManagePermissions()
}

// SeedUserRoleContractManagePermissions grants User role full access to Contract Manage menus.
func SeedUserRoleContractManagePermissions() {
	var role models.Role
	if err := initializers.DB.Where("role_name = ?", "User").First(&role).Error; err != nil {
		log.Printf("SeedUserRoleContractManagePermissions: User role missing: %v", err)
		return
	}

	var parent models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Contract Manage", "/contract-manage").
		Preload("Children").First(&parent).Error; err != nil {
		log.Printf("SeedUserRoleContractManagePermissions: menu missing: %v", err)
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
		log.Printf("SeedUserRoleContractManagePermissions: lookup failed: %v", result.Error)
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
		log.Printf("SeedUserRoleContractManagePermissions: marshal: %v", err)
		return
	}
	if result.RowsAffected == 0 {
		rm = models.RoleManagement{
			RoleID:                    role.ID,
			MenuID:                    parent.ID,
			RoleManagementPermissions: bytes,
		}
		if err := initializers.DB.Create(&rm).Error; err != nil {
			log.Printf("SeedUserRoleContractManagePermissions: create: %v", err)
			return
		}
	} else {
		if err := initializers.DB.Model(&rm).Update("role_management_permissions", bytes).Error; err != nil {
			log.Printf("SeedUserRoleContractManagePermissions: update: %v", err)
			return
		}
	}
	fmt.Printf("Seeded User role permissions for Contract Manage (%d menus)\n", len(menuIDs))
}
