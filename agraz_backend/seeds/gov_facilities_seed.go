package seeds

import (
	"log"
	"time"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"gorm.io/gorm"
)

func SeedGovFacilities() {
	const tenantID = uint(1)

	depts := []struct {
		Name, Slug string
		Order      int
	}{
		{"Horticulture", "horticulture", 1},
		{"Agriculture", "agriculture", 2},
	}
	for _, d := range depts {
		var row models.GovDepartment
		err := initializers.DB.Where("tenant_id = ? AND slug = ?", tenantID, d.Slug).First(&row).Error
		if err == gorm.ErrRecordNotFound {
			row = models.GovDepartment{
				TenantID:  tenantID,
				Name:      d.Name,
				Slug:      d.Slug,
				Status:    "active",
				SortOrder: d.Order,
			}
			if err := initializers.DB.Create(&row).Error; err != nil {
				log.Printf("gov seed: department %s: %v", d.Slug, err)
			}
		}
	}

	crops := []struct {
		Name, Slug string
		Order      int
	}{
		{"Arecanut", "arecanut", 1},
		{"Paddy", "paddy", 2},
		{"Banana", "banana", 3},
		{"Pepper", "pepper", 4},
		{"Cocoa", "cocoa", 5},
		{"Cardamom", "cardamom", 6},
	}
	for _, cr := range crops {
		var row models.GovCrop
		err := initializers.DB.Where("tenant_id = ? AND slug = ?", tenantID, cr.Slug).First(&row).Error
		if err == gorm.ErrRecordNotFound {
			row = models.GovCrop{
				TenantID:  tenantID,
				Name:      cr.Name,
				Slug:      cr.Slug,
				Status:    "active",
				SortOrder: cr.Order,
			}
			if err := initializers.DB.Create(&row).Error; err != nil {
				log.Printf("gov seed: crop %s: %v", cr.Slug, err)
			}
		}
	}

	// One sample facility so the mobile flow is testable immediately.
	var hort models.GovDepartment
	var areca models.GovCrop
	if err := initializers.DB.Where("tenant_id = ? AND slug = ?", tenantID, "horticulture").First(&hort).Error; err != nil {
		return
	}
	if err := initializers.DB.Where("tenant_id = ? AND slug = ?", tenantID, "arecanut").First(&areca).Error; err != nil {
		return
	}

	var existing models.GovFacility
	err := initializers.DB.Where(
		"tenant_id = ? AND department_id = ? AND crop_id = ? AND category = ? AND title = ?",
		tenantID, hort.ID, areca.ID, "loans", "Arecanut Crop Loan Scheme",
	).First(&existing).Error
	if err == gorm.ErrRecordNotFound {
		from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
		to := time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC)
		sample := models.GovFacility{
			TenantID:       tenantID,
			DepartmentID:   hort.ID,
			CropID:         areca.ID,
			Category:       "loans",
			Title:          "Arecanut Crop Loan Scheme",
			Description:    "Short-term crop loan for arecanut farmers under the Horticulture department. Eligible farmers can apply through the district office with land records and KYC documents.",
			Place:          "District Horticulture Office, Main Road",
			ContactPerson:  "Agricultural Officer",
			Email:          "horticulture@example.gov.in",
			Website:        "https://www.example.gov.in/horticulture",
			Phone:          "+91-9876543210",
			ApplicationURL: "",
			ValidFrom:      &from,
			ValidTo:        &to,
			Notes:          "Carry Aadhaar, land passbook, and bank passbook when applying.",
			Status:         "active",
			SortOrder:      1,
		}
		if err := initializers.DB.Create(&sample).Error; err != nil {
			log.Printf("gov seed: sample facility: %v", err)
		}
	}
}
