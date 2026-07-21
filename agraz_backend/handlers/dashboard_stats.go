package handler

import (
	"encoding/json"
	"strconv"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
)

type dashboardActivity struct {
	Type      string    `json:"type"`
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
}

func countGrantedPermissions() (int64, error) {
	var rows []models.RoleManagement
	if err := rolemanageDB.Find(&rows).Error; err != nil {
		return 0, err
	}

	var count int64
	for _, row := range rows {
		if len(row.RoleManagementPermissions) == 0 {
			continue
		}
		var perms map[string]interface{}
		if err := json.Unmarshal(row.RoleManagementPermissions, &perms); err != nil {
			continue
		}
		for _, v := range perms {
			permMap, ok := v.(map[string]interface{})
			if !ok {
				continue
			}
			for _, flag := range permMap {
				if b, ok := flag.(bool); ok && b {
					count++
				}
			}
		}
	}
	return count, nil
}

func countUpdatedSince(model interface{}, tid uint, since time.Time, tenantScoped bool) (int64, error) {
	var n int64
	q := userDB.Model(model).Where("updated_at >= ?", since)
	if tenantScoped {
		q = q.Where("tenant_id = ?", tid)
	}
	if err := q.Count(&n).Error; err != nil {
		return 0, err
	}
	return n, nil
}

func recentDashboardActivity(tid uint, limit int) ([]dashboardActivity, error) {
	var items []dashboardActivity

	var users []models.User
	if err := userDB.Where("tenant_id = ?", tid).
		Order("updated_at DESC").
		Limit(limit).
		Find(&users).Error; err != nil {
		return nil, err
	}
	for _, u := range users {
		name := u.Firstname
		if u.Lastname != "" {
			name += " " + u.Lastname
		}
		if name == "" {
			name = u.Email
		}
		items = append(items, dashboardActivity{
			Type:      "user",
			Message:   "User " + name + " was updated.",
			Timestamp: u.UpdatedAt,
		})
	}

	var roles []models.Role
	if err := rolesDB.Order("updated_at DESC").Limit(limit).Find(&roles).Error; err != nil {
		return nil, err
	}
	for _, r := range roles {
		items = append(items, dashboardActivity{
			Type:      "role",
			Message:   "Role " + r.RoleName + " was updated.",
			Timestamp: r.UpdatedAt,
		})
	}

	var menus []models.Menu
	if err := menusDB.Order("updated_at DESC").Limit(limit).Find(&menus).Error; err != nil {
		return nil, err
	}
	for _, m := range menus {
		items = append(items, dashboardActivity{
			Type:      "menu",
			Message:   "Menu item " + m.MenuName + " was updated.",
			Timestamp: m.UpdatedAt,
		})
	}

	// Sort newest first (simple insertion sort for small slices).
	for i := 1; i < len(items); i++ {
		for j := i; j > 0 && items[j].Timestamp.After(items[j-1].Timestamp); j-- {
			items[j], items[j-1] = items[j-1], items[j]
		}
	}

	if len(items) > limit {
		items = items[:limit]
	}
	return items, nil
}

// GetDashboardStats returns live counts for the admin dashboard.
func GetDashboardStats(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	now := time.Now()

	if vid := scopedVendorID(c); vid != nil && !userIsSuperAdmin(mustUserID(c)) {
		return getVendorDashboardStats(c, tid, *vid, now)
	}

	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	var usersTotal, usersActive int64
	if err := userDB.Model(&models.User{}).Where("tenant_id = ?", tid).Count(&usersTotal).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to count users"})
	}
	if err := userDB.Model(&models.User{}).Where("tenant_id = ? AND active = ?", tid, true).Count(&usersActive).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to count active users"})
	}

	var rolesActive int64
	if err := rolesDB.Model(&models.Role{}).Where("is_active = ?", true).Count(&rolesActive).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to count roles"})
	}

	var menusActive int64
	if err := menusDB.Model(&models.Menu{}).Where("is_active = ?", true).Count(&menusActive).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to count menus"})
	}

	permissionsGranted, err := countGrantedPermissions()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to count permissions"})
	}

	userUpdates, _ := countUpdatedSince(&models.User{}, tid, startOfDay, true)
	roleUpdates, _ := countUpdatedSince(&models.Role{}, tid, startOfDay, false)
	menuUpdates, _ := countUpdatedSince(&models.Menu{}, tid, startOfDay, false)
	dailyActivity := userUpdates + roleUpdates + menuUpdates

	activity, err := recentDashboardActivity(tid, 5)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to load recent activity"})
	}

	return c.JSON(fiber.Map{
		"users_total":           usersTotal,
		"users_active":          usersActive,
		"roles_active":          rolesActive,
		"menus_active":          menusActive,
		"permissions_granted":   permissionsGranted,
		"daily_activity":        dailyActivity,
		"recent_activity":       activity,
		"updated_at":            now,
		"is_vendor_dashboard":   false,
	})
}

func getVendorDashboardStats(c *fiber.Ctx, tid, vendorID uint, now time.Time) error {
	var vendor models.Vendor
	if err := vendorDB.Where("id = ? AND tenant_id = ?", vendorID, tid).First(&vendor).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Vendor not found"})
	}

	var productCount int64
	if err := vendorDB.Model(&models.VendorProductMapping{}).Where("vendor_id = ?", vendorID).Count(&productCount).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to count products"})
	}

	var totalUnits int64
	vendorDB.Model(&models.VendorProductMapping{}).Where("vendor_id = ?", vendorID).
		Select("COALESCE(SUM(quantity), 0)").Scan(&totalUnits)

	activity := make([]dashboardActivity, 0)
	var mappings []models.VendorProductMapping
	if err := vendorDB.Where("vendor_id = ?", vendorID).Preload("Product").Order("updated_at DESC").Limit(5).Find(&mappings).Error; err == nil {
		for _, m := range mappings {
			name := m.Product.Name
			if name == "" {
				name = "Product"
			}
			activity = append(activity, dashboardActivity{
				Type:      "product",
				Message:   name + " — qty " + formatInt(m.Quantity),
				Timestamp: m.UpdatedAt,
			})
		}
	}

	return c.JSON(fiber.Map{
		"is_vendor_dashboard": true,
		"vendor_id":             vendor.ID,
		"vendor_name":           vendor.BusinessName,
		"products_total":        productCount,
		"inventory_units":       totalUnits,
		"total_sales":           0,
		"users_total":           0,
		"users_active":          0,
		"roles_active":          0,
		"menus_active":          0,
		"permissions_granted":   0,
		"daily_activity":        productCount,
		"recent_activity":       activity,
		"updated_at":            now,
	})
}

func formatInt(n int) string {
	return strconv.Itoa(n)
}
