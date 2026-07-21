package seeds

import (
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
)

// EnsureDefaultTenant creates a single default tenant when the table is empty.
// All legacy rows are backfilled to tenant_id = 1 via migrations / defaults.
func EnsureDefaultTenant() {
	var n int64
	if err := initializers.DB.Model(&models.Tenant{}).Count(&n).Error; err != nil {
		log.Printf("tenant seed: count: %v", err)
		return
	}
	if n > 0 {
		return
	}
	t := models.Tenant{Name: "Default", Domain: nil, IsMarketplace: true}
	if err := initializers.DB.Create(&t).Error; err != nil {
		log.Printf("tenant seed: create: %v", err)
	}
}

// EnsureMarketplaceMode turns on multi-vendor marketplace for the default tenant.
func EnsureMarketplaceMode() {
	res := initializers.DB.Model(&models.Tenant{}).
		Where("id = ? AND is_marketplace = ?", 1, false).
		Update("is_marketplace", true)
	if res.Error != nil {
		log.Printf("tenant seed: enable marketplace: %v", res.Error)
		return
	}
	if res.RowsAffected > 0 {
		log.Printf("tenant seed: marketplace mode enabled for tenant 1")
	}
}
