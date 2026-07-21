package seeds

import (
	"errors"
	"fmt"
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"github.com/shopspring/decimal"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

// Arica storefront seed: categories, sub-categories, colors, products, variants, and gallery images.
// Image files live under backend/uploads/ecom/arica/ (copy from Arica src/assets/product).

type aricaSeedProduct struct {
	Slug         string
	Name         string
	Short        string
	Details      string
	CategorySlug string
	Price        string
	CompareAt    string
	SKU          string
	Images       []string
}

func aricaImageURL(filename string) string {
	return "/uploads/ecom/arica/" + filename
}

func SeedAricaCatalog() {
	const defaultTenant = uint(1)
	var probe models.EcomProduct
	if err := initializers.DB.Where("slug = ? AND tenant_id = ?", "wooden-hamsa", defaultTenant).First(&probe).Error; err == nil {
		return
	}

	cats := []struct {
		Name string
		Slug string
	}{
		{"Frames", "frames"},
		{"Oils", "oils"},
		{"Snacks", "snacks"},
	}
	catID := map[string]uint{}
	for _, c := range cats {
		var row models.EcomCategory
		err := initializers.DB.Where("slug = ? AND tenant_id = ?", c.Slug, defaultTenant).First(&row).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			row = models.EcomCategory{TenantID: defaultTenant, Name: c.Name, Slug: c.Slug, Status: "active"}
			if err2 := initializers.DB.Create(&row).Error; err2 != nil {
				log.Printf("arica seed: category %s: %v", c.Slug, err2)
				return
			}
		} else if err != nil {
			log.Printf("arica seed: category lookup %s: %v", c.Slug, err)
			return
		}
		catID[c.Slug] = row.ID
	}

	subSlugByCat := map[string]string{
		"frames": "frames-handcrafted",
		"oils":   "oils-handcrafted",
		"snacks": "snacks-handcrafted",
	}
	subID := map[string]uint{}
	for catSlug, subSlug := range subSlugByCat {
		var sub models.EcomSubCategory
		err := initializers.DB.Where("slug = ? AND tenant_id = ?", subSlug, defaultTenant).First(&sub).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			sub = models.EcomSubCategory{
				TenantID:   defaultTenant,
				CategoryID: catID[catSlug],
				Name:       "Handcrafted",
				Slug:       subSlug,
				Status:     "active",
			}
			if err2 := initializers.DB.Create(&sub).Error; err2 != nil {
				log.Printf("arica seed: subcategory %s: %v", subSlug, err2)
				return
			}
		} else if err != nil {
			log.Printf("arica seed: subcategory lookup %s: %v", subSlug, err)
			return
		}
		subID[catSlug] = sub.ID
	}

	var natColor models.EcomColor
	if err := initializers.DB.Where("hex_code = ? AND tenant_id = ?", "#c4a574", defaultTenant).First(&natColor).Error; errors.Is(err, gorm.ErrRecordNotFound) {
		natColor = models.EcomColor{TenantID: defaultTenant, Name: "Natural Wood", HexCode: "#c4a574", Status: "active"}
		if err2 := initializers.DB.Create(&natColor).Error; err2 != nil {
			log.Printf("arica seed: color: %v", err2)
			return
		}
	} else if err != nil {
		log.Printf("arica seed: color lookup: %v", err)
		return
	}

	prods := []aricaSeedProduct{
		{"wooden-hamsa", "Wooden Hamsa", "Hand-carved Hamsa wall panel for protection and decor", "A hand-carved wooden wall panel featuring an intricately detailed Hamsa, symbolizing protection and good fortune. Perfect for home decor or gifting.", "frames", "587", "734", "ARICA-001", []string{"swan_square_full.jpeg", "swan_square_small.jpeg", "flower_pot_verticle.jpg"}},
		{"wooden-swan-square", "Wooden Swan Square", "Hand-carved swan wall panel for decorative elegance", "A meticulously carved wooden wall panel featuring a graceful swan among ornate foliage.", "frames", "635", "794", "ARICA-002", []string{"swan_square_small.jpeg", "flower_pot_verticle.jpg", "ganapathi.jpeg"}},
		{"vertical-floral-wooden-panel", "Vertical Floral Wooden Panel", "Hand-carved vertical floral wall panel for traditional and modern decor.", "A beautifully hand-carved wooden panel featuring intricate floral vine patterns.", "frames", "763", "954", "ARICA-003", []string{"flower_pot_verticle.jpg", "ganapathi.jpeg", "buddha.jpeg"}},
		{"lord-ganesha-wooden-panel", "Lord Ganesha Wooden Panel", "Intricately carved wooden wall panel of Lord Ganesha with elephants.", "A divine wooden carving of Lord Ganesha seated in the center, flanked by two majestic elephants.", "frames", "811", "1014", "ARICA-004", []string{"ganapathi.jpeg", "buddha.jpeg", "cow.jpeg"}},
		{"buddha-wooden-panel", "Buddha Wooden Panel", "Hand-carved wooden wall panel depicting Lord Buddha in meditation.", "A serene wooden carving of Lord Buddha seated in meditation, radiating peace and harmony.", "frames", "851", "1064", "ARICA-005", []string{"buddha.jpeg", "cow.jpeg", "rama.jpeg"}},
		{"sacred-cow-and-calf-wooden-panel", "Sacred Cow and Calf Wooden Panel", "Hand-carved wooden panel depicting a cow and calf, symbolizing nurturing and abundance.", "A traditional wooden carving showcasing a sacred cow with her calf.", "frames", "803", "1004", "ARICA-006", []string{"cow.jpeg", "rama.jpeg", "elephant.jpeg"}},
		{"sri-rama-temple-panel", "Sri Rama Temple Panel", "Rama in temple-style relief artwork", "Carved Rama figure with arch and attendants. Represents devotion and tradition.", "frames", "827", "1034", "ARICA-007", []string{"rama.jpeg", "elephant.jpeg", "laxmi.jpeg"}},
		{"decorated-elephant-wooden-panel", "Decorated Elephant Wooden Panel", "Artistic wooden wall panel of a decorated elephant for regal home decor.", "A majestic wooden carving of an elephant adorned with intricate designs.", "oils", "755", "944", "ARICA-008", []string{"elephant.jpeg", "laxmi.jpeg", "peacock.jpeg"}},
		{"lakshmi-with-elephants", "Lakshmi with Elephants", "Prosperity motif with Lakshmi and elephants", "Finished wall panel showing Lakshmi on lotus with elephants.", "snacks", "683", "854", "ARICA-009", []string{"laxmi.jpeg", "peacock.jpeg", "kalash.jpeg"}},
		{"ornate-peacock-panel", "Ornate Peacock Panel", "Decorative panel with detailed peacock carving", "Handcrafted peacock wall panel featuring intricate feathers.", "snacks", "755", "944", "ARICA-010", []string{"peacock.jpeg", "kalash.jpeg", "swan_square_small.jpeg"}},
		{"kalash-floral-design", "Kalash Floral Design", "Wall plaque of Kalash and floral accents", "Kalash centerpiece with decorative flowers. Signifies abundance and purity.", "snacks", "875", "1094", "ARICA-011", []string{"kalash.jpeg", "swan_square_small.jpeg", "flower_pot_verticle.jpg"}},
	}

	for _, p := range prods {
		price, err := decimal.NewFromString(p.Price)
		if err != nil {
			log.Printf("arica seed bad price %s: %v", p.Slug, err)
			continue
		}
		cmp, err := decimal.NewFromString(p.CompareAt)
		if err != nil {
			log.Printf("arica seed bad compare %s: %v", p.Slug, err)
			continue
		}
		desc := p.Short
		details := p.Details
		txErr := initializers.DB.Transaction(func(tx *gorm.DB) error {
			prod := models.EcomProduct{
				TenantID:       defaultTenant,
				Name:           p.Name,
				Description:    &desc,
				Slug:           p.Slug,
				Price:          price,
				CompareAtPrice: &cmp,
				Cost:           decimal.Zero,
				Status:         "active",
				IsFeatured:     false,
				Quantity:       0,
				Weight:         decimal.Zero,
				Dimensions:     datatypes.JSON([]byte("[]")),
				SEOCodeTitle:   &p.Name,
				SEODescription: &details,
			}
			if err := tx.Create(&prod).Error; err != nil {
				return err
			}
			cid := catID[p.CategorySlug]
			sid := subID[p.CategorySlug]
			pc := models.EcomProductCategory{
				ProductID:     prod.ID,
				CategoryID:    cid,
				SubCategoryID: &sid,
			}
			if err := tx.Create(&pc).Error; err != nil {
				return err
			}
			v := models.EcomVariant{
				ProductID:      prod.ID,
				ColorID:        natColor.ID,
				SKU:            p.SKU,
				Price:          price,
				CompareAtPrice: &cmp,
				Quantity:       40,
				Status:         "active",
			}
			if err := tx.Create(&v).Error; err != nil {
				return err
			}
			for i, fn := range p.Images {
				url := aricaImageURL(fn)
				img := models.EcomProductImage{
					ProductID: prod.ID,
					ImageURL:  url,
					IsPrimary: i == 0,
					SortOrder: i,
				}
				if err := tx.Create(&img).Error; err != nil {
					return err
				}
			}
			return tx.Model(&models.EcomProduct{}).Where("id = ?", prod.ID).Update("quantity", 40).Error
		})
		if txErr != nil {
			log.Printf("arica seed product %s: %v", p.Slug, txErr)
		}
	}
	fmt.Println("Seeded Arica catalog (products, categories, images).")
}
