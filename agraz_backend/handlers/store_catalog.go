package handler

import (
	"strconv"
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

func enrichProductsVendorField(c *fiber.Ctx, rows []models.EcomProduct) {
	if !tenantIsMarketplace(c) {
		return
	}
	tid := tenantIDFromCtx(c)
	ids := make([]uint, 0)
	seen := map[uint]struct{}{}
	for i := range rows {
		if rows[i].VendorID == nil {
			continue
		}
		vid := *rows[i].VendorID
		if _, ok := seen[vid]; ok {
			continue
		}
		seen[vid] = struct{}{}
		ids = append(ids, vid)
	}
	byID := map[uint]models.Vendor{}
	if len(ids) > 0 {
		var vendors []models.Vendor
		if err := ecomDB.Where("id IN ? AND tenant_id = ?", ids, tid).Find(&vendors).Error; err == nil {
			for _, v := range vendors {
				byID[v.ID] = v
			}
		}
	}
	for i := range rows {
		if rows[i].VendorID == nil {
			continue
		}
		if v, ok := byID[*rows[i].VendorID]; ok {
			rows[i].VendorRef = &models.VendorRefJSON{ID: v.ID, Name: v.BusinessName}
		}
	}

	// When browsing a vendor's storefront, show that vendor on mapped products too.
	vendorFilter := strings.TrimSpace(c.Query("vendor_id", ""))
	if vendorFilter == "" {
		return
	}
	vid64, err := strconv.ParseUint(vendorFilter, 10, 32)
	if err != nil || vid64 == 0 {
		return
	}
	filterVendorID := uint(vid64)
	var filterVendor models.Vendor
	if err := ecomDB.Where("id = ? AND tenant_id = ? AND status = ?", filterVendorID, tid, "active").First(&filterVendor).Error; err != nil {
		return
	}
	for i := range rows {
		if rows[i].VendorRef != nil {
			continue
		}
		var n int64
		ecomDB.Model(&models.VendorProductMapping{}).
			Where("vendor_id = ? AND product_id = ?", filterVendorID, rows[i].ID).
			Count(&n)
		if n > 0 {
			rows[i].VendorRef = &models.VendorRefJSON{ID: filterVendor.ID, Name: filterVendor.BusinessName}
		}
	}
}

func productVendorOffers(c *fiber.Ctx, productID uint) []models.VendorOfferJSON {
	if !tenantIsMarketplace(c) {
		return nil
	}
	tid := tenantIDFromCtx(c)
	offers := make([]models.VendorOfferJSON, 0)
	seen := map[uint]struct{}{}

	var product models.EcomProduct
	if err := ecomDB.Where("id = ? AND tenant_id = ?", productID, tid).First(&product).Error; err == nil {
		if product.VendorID != nil {
			var v models.Vendor
			if err := ecomDB.Where("id = ? AND tenant_id = ? AND status = ?", *product.VendorID, tid, "active").First(&v).Error; err == nil {
				offers = append(offers, models.VendorOfferJSON{ID: v.ID, Name: v.BusinessName, Quantity: 0})
				seen[v.ID] = struct{}{}
			}
		}
	}

	var mappings []models.VendorProductMapping
	ecomDB.
		Joins("JOIN vendors ON vendors.id = vendor_product_mappings.vendor_id AND vendors.tenant_id = ? AND vendors.status = ?", tid, "active").
		Where("vendor_product_mappings.product_id = ?", productID).
		Preload("Vendor").
		Order("vendors.business_name ASC").
		Find(&mappings)

	for _, m := range mappings {
		if _, ok := seen[m.VendorID]; ok {
			continue
		}
		name := m.Vendor.BusinessName
		if name == "" {
			continue
		}
		offers = append(offers, models.VendorOfferJSON{ID: m.VendorID, Name: name, Quantity: m.Quantity})
		seen[m.VendorID] = struct{}{}
	}
	return offers
}

func GetStoreVendors(c *fiber.Ctx) error {
	if !tenantIsMarketplace(c) {
		return c.JSON(fiber.Map{"data": []models.VendorRefJSON{}, "total": 0})
	}
	tid := tenantIDFromCtx(c)
	var rows []models.Vendor
	q := ecomDB.Model(&models.Vendor{}).Where("tenant_id = ? AND status = ?", tid, "active")
	if s := strings.TrimSpace(c.Query("search")); s != "" {
		like := "%" + s + "%"
		q = q.Where("business_name ILIKE ? OR owner_name ILIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("business_name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	out := make([]models.VendorRefJSON, 0, len(rows))
	for _, v := range rows {
		out = append(out, models.VendorRefJSON{ID: v.ID, Name: v.BusinessName})
	}
	return c.JSON(fiber.Map{"data": out, "total": total})
}

var ecomDB *gorm.DB

func SetEcomDB(db *gorm.DB) {
	ecomDB = db
}

func GetStoreCategories(c *fiber.Ctx) error {
	status := c.Query("status", "active")
	tid := tenantIDFromCtx(c)

	var rows []models.EcomCategory
	q := ecomDB.Model(&models.EcomCategory{}).Where("tenant_id = ?", tid)
	if status != "" {
		q = q.Where("status = ?", status)
	}

	if err := q.Order("id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"data": rows})
}

func GetStoreSubCategories(c *fiber.Ctx) error {
	categoryIDStr := c.Query("category_id", "")
	if categoryIDStr == "" {
		return c.Status(400).JSON(fiber.Map{"error": "category_id is required"})
	}

	tid := tenantIDFromCtx(c)
	var rows []models.EcomSubCategory
	if err := ecomDB.
		Model(&models.EcomSubCategory{}).
		Where("tenant_id = ? AND category_id = ? AND status = ?", tid, categoryIDStr, "active").
		Order("id DESC").
		Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"data": rows})
}

func GetStoreColors(c *fiber.Ctx) error {
	status := c.Query("status", "active")
	tid := tenantIDFromCtx(c)

	var rows []models.EcomColor
	q := ecomDB.Model(&models.EcomColor{}).Where("tenant_id = ?", tid)
	if status != "" {
		q = q.Where("status = ?", status)
	}

	if err := q.Order("id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"data": rows})
}

func GetStoreProducts(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 10
	}
	offset := (page - 1) * limit

	status := c.Query("status", "active")
	inStock := c.Query("in_stock", "")
	categoryID := c.Query("category_id", "")
	subCategoryID := c.Query("sub_category_id", "")
	search := c.Query("search", "")
	tid := tenantIDFromCtx(c)
	vendorFilter := c.Query("vendor_id", "")

	q := ecomDB.Model(&models.EcomProduct{}).Distinct("products.id").Where("products.tenant_id = ?", tid)
	if status != "" {
		q = q.Where("products.status = ?", status)
	}

	if categoryID != "" {
		q = q.Joins("JOIN product_categories pc ON pc.product_id = products.id AND pc.category_id = ?", categoryID)
	}
	if subCategoryID != "" {
		q = q.Joins("JOIN product_categories pc ON pc.product_id = products.id AND pc.sub_category_id = ?", subCategoryID)
	}

	if inStock == "true" {
		q = q.Where("id IN (SELECT product_id FROM variants WHERE quantity > 0 AND status = 'active')")
	} else if inStock == "false" {
		q = q.Where("id IN (SELECT product_id FROM variants WHERE quantity <= 0 OR status <> 'active')")
	}

	if search != "" {
		like := "%" + search + "%"
		q = q.Where("products.name ILIKE ? OR products.slug ILIKE ?", like, like)
	}

	switch strings.ToLower(strings.TrimSpace(c.Query("featured", ""))) {
	case "true":
		q = q.Where("products.is_featured = ?", true)
	case "false":
		q = q.Where("products.is_featured = ?", false)
	}

	if tenantIsMarketplace(c) && strings.TrimSpace(vendorFilter) != "" {
		if vid, err := strconv.ParseUint(strings.TrimSpace(vendorFilter), 10, 32); err == nil && vid > 0 {
			v := uint(vid)
			q = q.Where(
				"(products.vendor_id = ? OR products.id IN (SELECT product_id FROM vendor_product_mappings WHERE vendor_id = ?))",
				v, v,
			)
		}
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var rows []models.EcomProduct
	// Preload active variants and their colors for the cart UI.
	if err := q.
		Preload("Variants", "status = ?", "active").
		Preload("Variants.Color").
		Preload("Images", func(db *gorm.DB) *gorm.DB {
			return db.Order("is_primary DESC, sort_order ASC, id ASC")
		}).
		Preload("ProductCategories").
		Preload("ProductCategories.Category").
		Preload("ProductCategories.SubCategory").
		Order("products.id DESC").
		Limit(limit).
		Offset(offset).
		Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	enrichProductsVendorField(c, rows)

	return c.JSON(fiber.Map{
		"data":  rows,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}

func GetStoreProductByID(c *fiber.Ctx) error {
	idStr := c.Params("id")
	if idStr == "" {
		return c.Status(400).JSON(fiber.Map{"error": "id is required"})
	}
	// Validate numeric id early (prevents noisy gorm errors).
	if _, err := strconv.ParseUint(idStr, 10, 64); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}

	tid := tenantIDFromCtx(c)
	var row models.EcomProduct
	if err := ecomDB.
		Where("id = ? AND tenant_id = ? AND status = ?", idStr, tid, "active").
		Preload("Variants", "status = ?", "active").
		Preload("Variants.Color").
		Preload("Images", func(db *gorm.DB) *gorm.DB {
			return db.Order("is_primary DESC, sort_order ASC, id ASC")
		}).
		Preload("ProductCategories").
		Preload("ProductCategories.Category").
		Preload("ProductCategories.SubCategory").
		First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "product not found"})
	}

	out := []models.EcomProduct{row}
	enrichProductsVendorField(c, out)
	sellers := productVendorOffers(c, row.ID)

	return c.JSON(fiber.Map{"data": out[0], "sellers": sellers})
}

