package seeds

import (
	_ "embed"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
)

//go:embed data/arica-banner-wood.png
var aricaBannerWoodPNG []byte

const storefrontDefaultHeroRel = "/uploads/storefront/default-hero.png"

// EnsureStorefrontDefaultBannerFile writes the canonical default hero image served by the API
// (used when there are no DB slides and for first-time seed). Safe to call on every startup.
func EnsureStorefrontDefaultBannerFile() error {
	dir := filepath.Join("uploads", "storefront")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	dest := filepath.Join(dir, "default-hero.png")
	if st, err := os.Stat(dest); err == nil && st.Size() > 0 {
		return nil
	}
	if len(aricaBannerWoodPNG) == 0 {
		return fmt.Errorf("embedded arica-banner-wood.png is empty")
	}
	return os.WriteFile(dest, aricaBannerWoodPNG, 0644)
}

// StorefrontDefaultHeroURL is the URL path returned by GET /api/store/banners when the catalog is empty.
func StorefrontDefaultHeroURL() string {
	return storefrontDefaultHeroRel
}

// SeedStorefrontBanners seeds one home slide from the Arica storefront wood texture
// (same asset as frontend/src/assets/wood.png — no browser chrome baked in).
// Removes legacy screenshot file hero-default.png if present.
func SeedStorefrontBanners() {
	legacyShot := filepath.Join("uploads", "storefront", "hero-default.png")
	if err := os.Remove(legacyShot); err != nil && !os.IsNotExist(err) {
		log.Printf("storefront banner seed: remove legacy screenshot: %v", err)
	}

	const defaultTenant = uint(1)
	// Re-seed only when there is nothing to show (no active slides for home).
	var active int64
	initializers.DB.Model(&models.StorefrontBannerSlide{}).
		Where("tenant_id = ? AND slot = ? AND is_active = ?", defaultTenant, "home", true).
		Count(&active)
	if active > 0 {
		return
	}
	var total int64
	initializers.DB.Model(&models.StorefrontBannerSlide{}).Where("tenant_id = ? AND slot = ?", defaultTenant, "home").Count(&total)
	if total > 0 {
		// Slides exist but all inactive — do not create duplicates; admin must enable one.
		return
	}
	if err := EnsureStorefrontDefaultBannerFile(); err != nil {
		log.Printf("storefront banner seed: default image: %v", err)
		return
	}
	row := models.StorefrontBannerSlide{
		TenantID:  defaultTenant,
		Slot:      "home",
		SortOrder: 10,
		ImageURL:  storefrontDefaultHeroRel,
		Title:     "Welcome to ARICA..!",
		Subtitle:  "Discover the charm of handcrafted elegance, made to adorn your space.",
		CTALabel:  "Explore Our Products",
		CTAHref:   "#featured-products",
		IsActive:  true,
	}
	if err := initializers.DB.Create(&row).Error; err != nil {
		log.Printf("storefront banner seed: create: %v", err)
		return
	}
	fmt.Println("Seeded storefront home banner slides (Arica wood texture)")
}

// SeedStorefrontBannerMenu adds the admin sidebar entry under Store & Catalog when the parent exists.
func SeedStorefrontBannerMenu() {
	var parent models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Store & Catalog", "/ecom-admin").First(&parent).Error; err != nil {
		return
	}
	var existing models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Home banners", "/storefront-hero").First(&existing).Error; err == nil {
		return
	}
	var legacy models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Home banner", "/storefront-hero").First(&legacy).Error; err == nil {
		_ = initializers.DB.Model(&legacy).Updates(map[string]interface{}{
			"menu_name": "Home banners",
			"icon":      "Images",
		}).Error
		return
	}
	pid := parent.ID
	m := models.Menu{
		MenuName:  "Home banners",
		URL:       "/storefront-hero",
		Icon:      "Images",
		SortOrder: 5,
		IsActive:  true,
		MenuType:  "main",
		ParentID:  &pid,
	}
	if err := initializers.DB.Create(&m).Error; err != nil {
		log.Printf("storefront banner menu seed: %v", err)
		return
	}
	fmt.Println("Seeded menu: Home banners")
}
