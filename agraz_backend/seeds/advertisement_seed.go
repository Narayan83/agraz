package seeds

import (
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"log"
	"os"
	"path/filepath"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
)

const advertisementDefaultRel = "/uploads/advertisements/default-smart-farming.jpg"

// EnsureAdvertisementDefaultImage writes a simple branded placeholder for the seeded ad.
func EnsureAdvertisementDefaultImage() error {
	dir := filepath.Join("uploads", "advertisements")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	dest := filepath.Join(dir, "default-smart-farming.jpg")
	if st, err := os.Stat(dest); err == nil && st.Size() > 0 {
		return nil
	}
	img := image.NewRGBA(image.Rect(0, 0, 1170, 658))
	green := color.RGBA{R: 20, G: 96, B: 63, A: 255}
	greenLite := color.RGBA{R: 37, G: 134, B: 90, A: 255}
	for y := 0; y < 658; y++ {
		for x := 0; x < 1170; x++ {
			if x < 585 {
				img.Set(x, y, green)
			} else {
				img.Set(x, y, greenLite)
			}
		}
	}
	f, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer f.Close()
	return jpeg.Encode(f, img, &jpeg.Options{Quality: 85})
}

// SeedAdvertisements creates the default "Smart Farming, Simplified" slide when none exist.
func SeedAdvertisements() {
	const defaultTenant = uint(1)
	var total int64
	initializers.DB.Model(&models.Advertisement{}).Where("tenant_id = ?", defaultTenant).Count(&total)
	if total > 0 {
		return
	}
	if err := EnsureAdvertisementDefaultImage(); err != nil {
		log.Printf("advertisement seed: default image: %v", err)
		return
	}
	sub := "Agriculture ERP for modern farms"
	tag := "AD"
	row := models.Advertisement{
		TenantID:  defaultTenant,
		Title:     "Smart Farming, Simplified",
		Subtitle:  &sub,
		Tag:       &tag,
		ImageURL:  advertisementDefaultRel,
		LinkType:  "none",
		SortOrder: 10,
		IsActive:  true,
	}
	if err := initializers.DB.Create(&row).Error; err != nil {
		log.Printf("advertisement seed: create: %v", err)
		return
	}
	fmt.Println("Seeded advertisement: Smart Farming, Simplified")
}

// SeedAdvertisementMenu adds Advertisements under Tools for admin sidebar.
func SeedAdvertisementMenu() {
	var parent models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Tools", "/tools").First(&parent).Error; err != nil {
		return
	}
	ensureToolsChild(parent.ID, "Advertisements", "/advertisements", "Megaphone", 13)
}
