package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type ecomProductCategoryInput struct {
	CategoryID    uint  `json:"category_id"`
	SubCategoryID *uint `json:"sub_category_id"`
}

type ecomProductImageInput struct {
	ImageURL  string `json:"image_url"`
	IsPrimary *bool   `json:"is_primary"`
	SortOrder *int    `json:"sort_order"`
	VariantID  *uint  `json:"variant_id"`
}

type ecomVariantInput struct {
	ColorID        uint            `json:"color_id"`
	SKU             string          `json:"sku"`
	Barcode        *string         `json:"barcode"`
	Price          decimal.Decimal `json:"price"`
	CompareAtPrice *decimal.Decimal `json:"compare_at_price"`
	Quantity       int             `json:"quantity"`
	ImageURL       *string        `json:"image_url"`
	Status         string          `json:"status"`
}

type ecomProductCreateRequest struct {
	Name             string                `json:"name"`
	Description      *string               `json:"description"`
	Slug             string                `json:"slug"`

	Price            decimal.Decimal      `json:"price"`
	CompareAtPrice   *decimal.Decimal    `json:"compare_at_price"`
	Cost             decimal.Decimal      `json:"cost"`
	SKU              *string              `json:"sku"`
	Barcode         *string              `json:"barcode"`

	Quantity         *int                 `json:"quantity"`
	LowStockThreshold *int               `json:"low_stock_threshold"`
	Status           string               `json:"status"`
	IsFeatured       *bool                `json:"is_featured"`
	Weight           decimal.Decimal     `json:"weight"`
	Dimensions       *json.RawMessage    `json:"dimensions"`

	SEOCodeTitle     *string              `json:"seo_title"`
	SEODescription   *string              `json:"seo_description"`

	Categories       []ecomProductCategoryInput `json:"categories"`
	Variants         []ecomVariantInput          `json:"variants"`
	ProductImages    []ecomProductImageInput    `json:"product_images"`

	// Optional seller (marketplace); ignored in single-store UX when is_marketplace is false.
	VendorID *uint `json:"vendor_id"`
}

type ecomProductUpdateRequest = ecomProductCreateRequest

type ecomProductAdminListResponse struct {
	Data  []models.EcomProduct `json:"data"`
	Total int64                 `json:"total"`
	Page  int                   `json:"page"`
	Limit int                   `json:"limit"`
}

func AdminGetProducts(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 10
	}
	offset := (page - 1) * limit

	status := c.Query("status", "")
	inStock := c.Query("in_stock", "")
	search := c.Query("search", "")
	tid := tenantIDFromCtx(c)

	q := ecomDB.Model(&models.EcomProduct{}).Where("tenant_id = ?", tid)
	if sv := scopedVendorID(c); sv != nil && !userIsSuperAdmin(mustUserID(c)) {
		ids, err := vendorProductIDs(*sv)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		if len(ids) == 0 {
			return c.JSON(ecomProductAdminListResponse{Data: []models.EcomProduct{}, Total: 0, Page: page, Limit: limit})
		}
		q = q.Where("id IN ?", ids)
	}
	if status != "" {
		q = q.Where("status = ?", status)
	}
	if search != "" {
		like := "%" + strings.TrimSpace(search) + "%"
		q = q.Where("name ILIKE ? OR slug ILIKE ?", like, like)
	}
	if inStock == "true" {
		q = q.Where("id IN (SELECT product_id FROM variants WHERE quantity > 0 AND status = 'active' AND deleted_at IS NULL)")
	} else if inStock == "false" {
		q = q.Where("id IN (SELECT product_id FROM variants WHERE (quantity <= 0 OR status <> 'active') AND deleted_at IS NULL)")
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var rows []models.EcomProduct
	if err := q.
		Preload("Images", func(db *gorm.DB) *gorm.DB {
			return db.Order("is_primary DESC, sort_order ASC, id ASC")
		}).
		Preload("Variants", "status = ?", "active").
		Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(ecomProductAdminListResponse{
		Data:  rows,
		Total: total,
		Page:  page,
		Limit: limit,
	})
}

func AdminGetProduct(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var row models.EcomProduct
	if err := ecomDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "product not found"})
	}
	if !vendorCanAccessProduct(c, row.ID) {
		return c.Status(403).JSON(fiber.Map{"error": "Product not linked to your vendor account"})
	}

	var categories []models.EcomProductCategory
	_ = ecomDB.Where("product_id = ?", row.ID).Find(&categories).Error

	var variants []models.EcomVariant
	if err := ecomDB.Where("product_id = ?", row.ID).Preload("Color").Find(&variants).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var images []models.EcomProductImage
	_ = ecomDB.Where("product_id = ?", row.ID).Find(&images).Error

	return c.JSON(fiber.Map{
		"product":    row,
		"categories": categories,
		"variants":   variants,
		"images":     images,
	})
}

func (req *ecomProductCreateRequest) validate() error {
	if strings.TrimSpace(req.Name) == "" {
		return fiber.NewError(http.StatusBadRequest, "name is required")
	}
	if strings.TrimSpace(req.Slug) == "" {
		return fiber.NewError(http.StatusBadRequest, "slug is required")
	}
	if len(req.Categories) == 0 {
		return fiber.NewError(http.StatusBadRequest, "categories is required")
	}
	if len(req.Variants) == 0 {
		return fiber.NewError(http.StatusBadRequest, "variants is required")
	}
	return nil
}

func computeVariantQuantitySum(variants []ecomVariantInput) int {
	sum := 0
	for _, v := range variants {
		if v.Quantity > 0 {
			sum += v.Quantity
		}
	}
	return sum
}

func AdminCreateProduct(c *fiber.Ctx) error {
	if err := forbidVendorPortal(c); err != nil {
		return err
	}
	var body ecomProductCreateRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body", "details": err.Error()})
	}
	if err := body.validate(); err != nil {
		if ferr, ok := err.(*fiber.Error); ok {
			return c.Status(ferr.Code).JSON(fiber.Map{"error": ferr.Message})
		}
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	status := body.Status
	if status == "" {
		status = "active"
	}

	isFeatured := false
	if body.IsFeatured != nil {
		isFeatured = *body.IsFeatured
	}

	quantity := computeVariantQuantitySum(body.Variants)
	if body.Quantity != nil {
		quantity = *body.Quantity
	}
	lowStock := 0
	if body.LowStockThreshold != nil {
		lowStock = *body.LowStockThreshold
	}

	// Dimensions: store raw json if provided, else defaults to [] via model default.
	var dimensionsPtr *json.RawMessage
	if body.Dimensions != nil {
		dimensionsPtr = body.Dimensions
	}

	tid := tenantIDFromCtx(c)

	txErr := ecomDB.Transaction(func(tx *gorm.DB) error {
		if body.VendorID != nil && *body.VendorID > 0 {
			var v models.Vendor
			if err := tx.Where("id = ? AND tenant_id = ?", *body.VendorID, tid).First(&v).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					return fiber.NewError(http.StatusBadRequest, "vendor not found for this tenant")
				}
				return err
			}
		}

		for _, pc := range body.Categories {
			var cat models.EcomCategory
			if err := tx.Where("id = ? AND tenant_id = ?", pc.CategoryID, tid).First(&cat).Error; err != nil {
				return fiber.NewError(http.StatusBadRequest, "invalid category for this tenant")
			}
			if pc.SubCategoryID != nil {
				var sub models.EcomSubCategory
				if err := tx.Where("id = ? AND tenant_id = ?", *pc.SubCategoryID, tid).First(&sub).Error; err != nil {
					return fiber.NewError(http.StatusBadRequest, "invalid sub-category for this tenant")
				}
			}
		}

		for _, v := range body.Variants {
			var col models.EcomColor
			if err := tx.Where("id = ? AND tenant_id = ?", v.ColorID, tid).First(&col).Error; err != nil {
				return fiber.NewError(http.StatusBadRequest, "invalid color for this tenant")
			}
		}

		product := models.EcomProduct{
			TenantID:    tid,
			Name:        body.Name,
			Description: body.Description,
			Slug:        body.Slug,
			VendorID:    body.VendorID,

			Price:        body.Price,
			CompareAtPrice: body.CompareAtPrice,
			Cost:         body.Cost,
			SKU:          body.SKU,
			Barcode:      body.Barcode,

			Quantity:          quantity,
			LowStockThreshold: lowStock,
			Status:            status,
			IsFeatured:        isFeatured,
			Weight:            body.Weight,
			SEOCodeTitle:      body.SEOCodeTitle,
			SEODescription:    body.SEODescription,
		}

		if dimensionsPtr != nil {
			// store any valid json; keep it as-is in jsonb
			product.Dimensions = datatypes.JSON(*dimensionsPtr)
		}

		if err := tx.Create(&product).Error; err != nil {
			return err
		}

		// Product category mappings
		for _, pc := range body.Categories {
			m := models.EcomProductCategory{
				ProductID:     product.ID,
				CategoryID:    pc.CategoryID,
				SubCategoryID: pc.SubCategoryID,
			}
			if err := tx.Create(&m).Error; err != nil {
				return err
			}
		}

		// Variants
		for _, v := range body.Variants {
			varStatus := v.Status
			if varStatus == "" {
				varStatus = "active"
			}
			variant := models.EcomVariant{
				ProductID:     product.ID,
				ColorID:       v.ColorID,
				SKU:           v.SKU,
				Barcode:       v.Barcode,
				Price:         v.Price,
				CompareAtPrice: v.CompareAtPrice,
				Quantity:      v.Quantity,
				ImageURL:      v.ImageURL,
				Status:        varStatus,
			}
			if err := tx.Create(&variant).Error; err != nil {
				return err
			}
		}

		// Product images (no uploads here yet; just store urls).
		for _, img := range body.ProductImages {
			if strings.TrimSpace(img.ImageURL) == "" {
				continue
			}
			isPrimary := false
			if img.IsPrimary != nil {
				isPrimary = *img.IsPrimary
			}
			sortOrder := 0
			if img.SortOrder != nil {
				sortOrder = *img.SortOrder
			}
			row := models.EcomProductImage{
				ProductID:  product.ID,
				VariantID:  img.VariantID,
				ImageURL:  img.ImageURL,
				IsPrimary: isPrimary,
				SortOrder: sortOrder,
			}
			if err := tx.Create(&row).Error; err != nil {
				return err
			}
		}

		// Sync product quantity from variant sum (best effort).
		return tx.Model(&models.EcomProduct{}).Where("id = ?", product.ID).
			Update("quantity", computeVariantQuantitySum(body.Variants)).Error
	})

	if txErr != nil {
		if ferr, ok := txErr.(*fiber.Error); ok {
			return c.Status(ferr.Code).JSON(fiber.Map{"error": ferr.Message})
		}
		return c.Status(500).JSON(fiber.Map{"error": txErr.Error()})
	}

	var created models.EcomProduct
	if err := ecomDB.Where("slug = ? AND tenant_id = ?", body.Slug, tid).First(&created).Error; err != nil {
		return c.Status(201).JSON(fiber.Map{"message": "created", "data": body})
	}
	variants := []models.EcomVariant{}
	_ = ecomDB.Where("product_id = ?", created.ID).Preload("Color").Find(&variants).Error
	cats := []models.EcomProductCategory{}
	_ = ecomDB.Where("product_id = ?", created.ID).Find(&cats).Error

	return c.Status(201).JSON(fiber.Map{
		"product":    created,
		"categories": cats,
		"variants":   variants,
	})
}

func AdminUpdateProduct(c *fiber.Ctx) error {
	if err := forbidVendorPortal(c); err != nil {
		return err
	}
	id := c.Params("id")
	var body ecomProductUpdateRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid request body", "details": err.Error()})
	}
	if err := body.validate(); err != nil {
		if ferr, ok := err.(*fiber.Error); ok {
			return c.Status(ferr.Code).JSON(fiber.Map{"error": ferr.Message})
		}
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	tid := tenantIDFromCtx(c)

	txErr := ecomDB.Transaction(func(tx *gorm.DB) error {
		var product models.EcomProduct
		if err := tx.Where("id = ? AND tenant_id = ?", id, tid).First(&product).Error; err != nil {
			return err
		}

		if body.VendorID != nil {
			if *body.VendorID == 0 {
				product.VendorID = nil
			} else {
				var v models.Vendor
				if err := tx.Where("id = ? AND tenant_id = ?", *body.VendorID, tid).First(&v).Error; err != nil {
					return fiber.NewError(http.StatusBadRequest, "vendor not found for this tenant")
				}
				product.VendorID = body.VendorID
			}
		}

		for _, pc := range body.Categories {
			var cat models.EcomCategory
			if err := tx.Where("id = ? AND tenant_id = ?", pc.CategoryID, tid).First(&cat).Error; err != nil {
				return fiber.NewError(http.StatusBadRequest, "invalid category for this tenant")
			}
			if pc.SubCategoryID != nil {
				var sub models.EcomSubCategory
				if err := tx.Where("id = ? AND tenant_id = ?", *pc.SubCategoryID, tid).First(&sub).Error; err != nil {
					return fiber.NewError(http.StatusBadRequest, "invalid sub-category for this tenant")
				}
			}
		}
		for _, v := range body.Variants {
			var col models.EcomColor
			if err := tx.Where("id = ? AND tenant_id = ?", v.ColorID, tid).First(&col).Error; err != nil {
				return fiber.NewError(http.StatusBadRequest, "invalid color for this tenant")
			}
		}

		status := body.Status
		if status == "" {
			status = product.Status
		}
		isFeatured := body.IsFeatured
		featuredVal := product.IsFeatured
		if isFeatured != nil {
			featuredVal = *isFeatured
		}

		quantity := computeVariantQuantitySum(body.Variants)
		lowStock := 0
		if body.LowStockThreshold != nil {
			lowStock = *body.LowStockThreshold
		}
		if body.Quantity != nil {
			quantity = *body.Quantity
		}

		product.Name = body.Name
		product.Description = body.Description
		product.Slug = body.Slug
		product.Price = body.Price
		product.CompareAtPrice = body.CompareAtPrice
		product.Cost = body.Cost
		product.SKU = body.SKU
		product.Barcode = body.Barcode
		product.Quantity = quantity
		product.LowStockThreshold = lowStock
		product.Status = status
		product.IsFeatured = featuredVal
		product.Weight = body.Weight
		product.SEOCodeTitle = body.SEOCodeTitle
		product.SEODescription = body.SEODescription
		if body.Dimensions != nil {
			// best-effort store raw json (no schema validation)
			product.Dimensions = datatypes.JSON(*body.Dimensions)
		}

		if err := tx.Save(&product).Error; err != nil {
			return err
		}

		// Replace nested mappings.
		if err := tx.Where("product_id = ?", product.ID).Delete(&models.EcomProductCategory{}).Error; err != nil {
			return err
		}
		if err := tx.Where("product_id = ?", product.ID).Delete(&models.EcomVariant{}).Error; err != nil {
			return err
		}
		if err := tx.Where("product_id = ?", product.ID).Delete(&models.EcomProductImage{}).Error; err != nil {
			return err
		}

		for _, pc := range body.Categories {
			m := models.EcomProductCategory{
				ProductID:     product.ID,
				CategoryID:    pc.CategoryID,
				SubCategoryID: pc.SubCategoryID,
			}
			if err := tx.Create(&m).Error; err != nil {
				return err
			}
		}

		for _, v := range body.Variants {
			varStatus := v.Status
			if varStatus == "" {
				varStatus = "active"
			}
			variant := models.EcomVariant{
				ProductID:        product.ID,
				ColorID:          v.ColorID,
				SKU:              v.SKU,
				Barcode:          v.Barcode,
				Price:            v.Price,
				CompareAtPrice:  v.CompareAtPrice,
				Quantity:        v.Quantity,
				ImageURL:        v.ImageURL,
				Status:           varStatus,
			}
			if err := tx.Create(&variant).Error; err != nil {
				return err
			}
		}

		for _, img := range body.ProductImages {
			if strings.TrimSpace(img.ImageURL) == "" {
				continue
			}
			isPrimary := false
			if img.IsPrimary != nil {
				isPrimary = *img.IsPrimary
			}
			sortOrder := 0
			if img.SortOrder != nil {
				sortOrder = *img.SortOrder
			}
			row := models.EcomProductImage{
				ProductID:  product.ID,
				VariantID:  img.VariantID,
				ImageURL:  img.ImageURL,
				IsPrimary: isPrimary,
				SortOrder: sortOrder,
			}
			if err := tx.Create(&row).Error; err != nil {
				return err
			}
		}

		return nil
	})

	if txErr != nil {
		if ferr, ok := txErr.(*fiber.Error); ok {
			return c.Status(ferr.Code).JSON(fiber.Map{"error": ferr.Message})
		}
		return c.Status(500).JSON(fiber.Map{"error": txErr.Error()})
	}

	return AdminGetProduct(c)
}

func AdminDeleteProduct(c *fiber.Ctx) error {
	if err := forbidVendorPortal(c); err != nil {
		return err
	}
	tid := tenantIDFromCtx(c)
	var row models.EcomProduct
	if err := ecomDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "product not found"})
	}

	// Soft delete product itself and nested rows.
	if err := ecomDB.Where("product_id = ?", row.ID).Delete(&models.EcomVariant{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = ecomDB.Where("product_id = ?", row.ID).Delete(&models.EcomProductCategory{}).Error
	_ = ecomDB.Where("product_id = ?", row.ID).Delete(&models.EcomProductImage{}).Error

	if err := ecomDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"message": "product deleted"})
}

