package seeds

import (
	"encoding/json"
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

// SeedSirsiServiceRegistrations adds 3 approved agriculture-related services for Sirsi, Karnataka.
// Idempotent: skips rows that already exist (same business_name + mobile).
func SeedSirsiServiceRegistrations() {
	type seedItem struct {
		Mobile, Name, MainCategory, SubCategory, BusinessName, Email, Address, Cover string
		Lat, Lng                                                                     float64
	}

	items := []seedItem{
		{
			Mobile:       "9480123456",
			Name:         "Ramesh Hegde",
			MainCategory: "Farming Services",
			SubCategory:  "Harvesting-Manual",
			BusinessName: "Sirsi Arecanut Harvesting Team",
			Email:        "areca.sirsi@example.com",
			Address:      "Near Marikamba Temple, Sirsi, Uttara Kannada, Karnataka 581401",
			Cover:        "https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=800&q=80",
			Lat:          14.6195,
			Lng:          74.8354,
		},
		{
			Mobile:       "9480654321",
			Name:         "Suresh Naik",
			MainCategory: "Farming Services",
			SubCategory:  "Agri Input Suppliers",
			BusinessName: "Malnad Pepper & Spice Inputs - Sirsi",
			Email:        "pepper.sirsi@example.com",
			Address:      "Hubli Road, Sirsi, Uttara Kannada, Karnataka 581401",
			Cover:        "https://images.unsplash.com/photo-1599599810769-628cd3f7d9c4?w=800&q=80",
			Lat:          14.6220,
			Lng:          74.8400,
		},
		{
			Mobile:       "9480987654",
			Name:         "Ganesh Bhat",
			MainCategory: "Farming Services",
			SubCategory:  "Tractor",
			BusinessName: "Sirsi Paddy Tractor & Hire Services",
			Email:        "paddy.sirsi@example.com",
			Address:      "Banavasi Road, Sirsi, Uttara Kannada, Karnataka 581401",
			Cover:        "https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=800&q=80",
			Lat:          14.6150,
			Lng:          74.8300,
		},
	}

	for _, it := range items {
		var existing models.ServiceRegistration
		err := initializers.DB.Where("mobile = ? AND business_name = ?", it.Mobile, it.BusinessName).
			First(&existing).Error
		if err == nil {
			continue
		}
		if err != gorm.ErrRecordNotFound {
			log.Printf("service seed: lookup %s: %v", it.BusinessName, err)
			continue
		}

		sub := it.SubCategory
		email := it.Email
		addr := it.Address
		cover := it.Cover
		lat := it.Lat
		lng := it.Lng
		paths, _ := json.Marshal([]string{it.Cover})
		row := models.ServiceRegistration{
			Mobile:          it.Mobile,
			Name:            it.Name,
			MainCategory:    it.MainCategory,
			SubCategory:     &sub,
			BusinessName:    it.BusinessName,
			Email:           &email,
			BusinessAddress: &addr,
			ImagePaths:      datatypes.JSON(paths),
			CoverImage:      &cover,
			Latitude:        &lat,
			Longitude:       &lng,
			Approved:        true,
		}
		if err := initializers.DB.Create(&row).Error; err != nil {
			log.Printf("service seed: create %s: %v", it.BusinessName, err)
		} else {
			log.Printf("service seed: created %s (id=%d)", it.BusinessName, row.ID)
		}
	}
}
