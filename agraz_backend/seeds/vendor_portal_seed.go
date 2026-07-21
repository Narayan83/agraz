package seeds

import (
	"fmt"
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

const defaultTenantID = uint(1)

// EnsureVendorPortalSample creates sample vendor + vendor@admin.com user + product mappings.
func EnsureVendorPortalSample() {
	EnsureVendorRole()

	var vendor models.Vendor
	err := initializers.DB.Where("business_name = ? AND tenant_id = ?", "Vendor One Trading", defaultTenantID).First(&vendor).Error
	if err == gorm.ErrRecordNotFound {
		vendor = models.Vendor{
			TenantID:     defaultTenantID,
			Status:       "active",
			BusinessType: "individual",
			BusinessName: "Vendor One Trading",
			Address:      "123 Market Street, Business District",
			PhoneNumber:  "9876543210",
			MobileNumber: "9876543210",
			OwnerName:    "Vendor One",
		}
		if err := initializers.DB.Create(&vendor).Error; err != nil {
			log.Printf("vendor portal seed: create vendor: %v", err)
			return
		}
		fmt.Println("Seeded vendor: Vendor One Trading")
	} else if err != nil {
		log.Printf("vendor portal seed: vendor lookup: %v", err)
		return
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
	var user models.User
	sampleEmail := "vendor@admin.com"
	err = initializers.DB.Where("email = ? AND tenant_id = ?", sampleEmail, defaultTenantID).First(&user).Error
	if err == gorm.ErrRecordNotFound {
		// Migrate legacy seed email if present.
		var legacy models.User
		if err := initializers.DB.Where("email = ? AND tenant_id = ?", "vendor1@admin.com", defaultTenantID).First(&legacy).Error; err == nil {
			initializers.DB.Model(&legacy).Updates(map[string]interface{}{
				"email": sampleEmail, "vendor_id": vendor.ID, "plain_password": "admin123",
				"password": string(hash), "active": true,
			})
			user = legacy
			user.Email = sampleEmail
			fmt.Println("Updated vendor user email to vendor@admin.com / admin123")
		} else {
		vid := vendor.ID
		user = models.User{
			TenantID:      defaultTenantID,
			Firstname:     "Vendor",
			Lastname:      "One",
			Email:         sampleEmail,
			Password:      string(hash),
			PlainPassword: "admin123",
			Active:        true,
			VendorID:      &vid,
		}
		if err := initializers.DB.Create(&user).Error; err != nil {
			log.Printf("vendor portal seed: create user: %v", err)
			return
		}
		fmt.Println("Seeded vendor user: vendor@admin.com / admin123")
		}
	} else if err != nil {
		log.Printf("vendor portal seed: user lookup: %v", err)
		return
	} else {
		vid := vendor.ID
		initializers.DB.Model(&user).Updates(map[string]interface{}{
			"vendor_id":      vid,
			"plain_password": "admin123",
			"password":       string(hash),
			"active":         true,
		})
	}

	assignVendorRole(user.ID)
	ensureVendorUserMappingMenu()

	var productIDs []uint
	initializers.DB.Model(&models.EcomProduct{}).Where("tenant_id = ? AND status = ?", defaultTenantID, "active").
		Order("id DESC").Limit(3).Pluck("id", &productIDs)
	for i, pid := range productIDs {
		qty := 20 - i*5
		if qty < 5 {
			qty = 5
		}
		var existing models.VendorProductMapping
		if err := initializers.DB.Where("vendor_id = ? AND product_id = ?", vendor.ID, pid).First(&existing).Error; err == gorm.ErrRecordNotFound {
			_ = initializers.DB.Create(&models.VendorProductMapping{
				VendorID: vendor.ID, ProductID: pid, Quantity: qty,
			}).Error
		}
	}
}

func EnsureVendorRole() {
	var role models.Role
	if err := initializers.DB.Where("role_name = ?", "Vendor").First(&role).Error; err == gorm.ErrRecordNotFound {
		role = models.Role{RoleName: "Vendor", Description: "Marketplace vendor portal access", IsActive: true}
		if err := initializers.DB.Create(&role).Error; err != nil {
			log.Printf("vendor portal seed: role: %v", err)
			return
		}
		fmt.Println("Seeded Role: Vendor")
	}
}

func assignVendorRole(userID uint) {
	var role models.Role
	if err := initializers.DB.Where("role_name = ?", "Vendor").First(&role).Error; err != nil {
		return
	}
	var n int64
	initializers.DB.Model(&models.UserRoleMapping{}).Where("user_id = ? AND role_id = ?", userID, role.ID).Count(&n)
	if n > 0 {
		return
	}
	_ = initializers.DB.Create(&models.UserRoleMapping{UserID: userID, RoleID: role.ID}).Error
}

func ensureVendorUserMappingMenu() {
	var parent models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Marketplace", "/marketplace").First(&parent).Error; err != nil {
		return
	}
	var existing models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Vendor & user mapping", "/vendor-user-mapping").First(&existing).Error; err == gorm.ErrRecordNotFound {
		child := models.Menu{
			MenuName: "Vendor & user mapping", URL: "/vendor-user-mapping", Icon: "Users",
			SortOrder: 3, IsActive: true, MenuType: "main", ParentID: &parent.ID,
		}
		_ = initializers.DB.Create(&child).Error
	}
}
