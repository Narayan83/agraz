package handler

import (
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
	"strconv"
)

func dedupeVendorMappingLines(lines []vendorProductMappingLine) []vendorProductMappingLine {
	byProduct := map[uint]int{}
	order := []uint{}
	for _, line := range lines {
		if line.ProductID == 0 {
			continue
		}
		qty := line.Quantity
		if qty < 1 {
			qty = 1
		}
		if _, ok := byProduct[line.ProductID]; !ok {
			order = append(order, line.ProductID)
		}
		byProduct[line.ProductID] = qty
	}
	out := make([]vendorProductMappingLine, 0, len(order))
	for _, pid := range order {
		out = append(out, vendorProductMappingLine{ProductID: pid, Quantity: byProduct[pid]})
	}
	return out
}

type vendorProductMappingLine struct {
	ProductID uint `json:"product_id"`
	Quantity  int  `json:"quantity"`
}

type replaceVendorMappingsPayload struct {
	Mappings []vendorProductMappingLine `json:"mappings"`
}

func GetVendorProductMappings(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit
	tid := tenantIDFromCtx(c)

	q := vendorDB.Model(&models.VendorProductMapping{}).
		Joins("JOIN vendors ON vendors.id = vendor_product_mappings.vendor_id AND vendors.tenant_id = ?", tid).
		Preload("Product").Preload("Vendor")
	if vid := scopedVendorID(c); vid != nil && !userIsSuperAdmin(mustUserID(c)) {
		q = q.Where("vendor_id = ?", *vid)
	} else if vid := c.QueryInt("vendor_id", 0); vid > 0 {
		q = q.Where("vendor_id = ?", uint(vid))
	}
	if pid := c.QueryInt("product_id", 0); pid > 0 {
		q = q.Where("product_id = ?", uint(pid))
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var rows []models.VendorProductMapping
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func CreateVendorProductMapping(c *fiber.Ctx) error {
	var body struct {
		VendorID  uint `json:"vendor_id"`
		ProductID uint `json:"product_id"`
		Quantity  int  `json:"quantity"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if sv := scopedVendorID(c); sv != nil && !userIsSuperAdmin(mustUserID(c)) {
		body.VendorID = *sv
	}
	if body.VendorID == 0 || body.ProductID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "vendor_id and product_id are required"})
	}
	qty := body.Quantity
	if qty < 1 {
		qty = 1
	}
	tid := tenantIDFromCtx(c)
	var v models.Vendor
	if err := vendorDB.Where("id = ? AND tenant_id = ?", body.VendorID, tid).First(&v).Error; err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "vendor not found"})
	}
	var p models.EcomProduct
	if err := ecomDB.Where("id = ? AND tenant_id = ?", body.ProductID, tid).First(&p).Error; err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "product not found"})
	}
	row := models.VendorProductMapping{VendorID: body.VendorID, ProductID: body.ProductID, Quantity: qty}
	if err := vendorDB.Create(&row).Error; err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Could not create mapping (duplicate vendor+product?)", "details": err.Error()})
	}
	vendorDB.Preload("Product").Preload("Vendor").First(&row, row.ID)
	return c.Status(201).JSON(row)
}

func UpdateVendorProductMapping(c *fiber.Ctx) error {
	var body struct {
		Quantity int `json:"quantity"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if body.Quantity < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "quantity must be at least 1"})
	}
	tid := tenantIDFromCtx(c)
	var row models.VendorProductMapping
	if err := vendorDB.
		Joins("JOIN vendors ON vendors.id = vendor_product_mappings.vendor_id AND vendors.tenant_id = ?", tid).
		Where("vendor_product_mappings.id = ?", c.Params("id")).
		First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Mapping not found"})
	}
	if err := vendorDB.Model(&row).Update("quantity", body.Quantity).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	vendorDB.Preload("Product").Preload("Vendor").First(&row, row.ID)
	return c.JSON(row)
}

func DeleteVendorProductMapping(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var row models.VendorProductMapping
	if err := vendorDB.
		Joins("JOIN vendors ON vendors.id = vendor_product_mappings.vendor_id AND vendors.tenant_id = ?", tid).
		Where("vendor_product_mappings.id = ?", c.Params("id")).
		First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Mapping not found"})
	}
	if err := vendorDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}

// ReplaceVendorProductMappings sets all product lines for one vendor (transactional).
func ReplaceVendorProductMappings(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	vendorParam := c.Params("id")
	if sv := scopedVendorID(c); sv != nil && !userIsSuperAdmin(mustUserID(c)) {
		vendorParam = strconv.FormatUint(uint64(*sv), 10)
	}
	var v models.Vendor
	if err := vendorDB.Where("id = ? AND tenant_id = ?", vendorParam, tid).First(&v).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Vendor not found"})
	}
	var body replaceVendorMappingsPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	lines := dedupeVendorMappingLines(body.Mappings)

	err := vendorDB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("vendor_id = ?", v.ID).Delete(&models.VendorProductMapping{}).Error; err != nil {
			return err
		}
		for _, line := range lines {
			var p models.EcomProduct
			if err := tx.Where("id = ? AND tenant_id = ?", line.ProductID, tid).First(&p).Error; err != nil {
				return err
			}
			m := models.VendorProductMapping{VendorID: v.ID, ProductID: line.ProductID, Quantity: line.Quantity}
			if err := tx.Create(&m).Error; err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Failed to save mappings", "details": err.Error()})
	}
	var out []models.VendorProductMapping
	vendorDB.Where("vendor_id = ?", v.ID).Preload("Product").Order("id ASC").Find(&out)
	return c.JSON(fiber.Map{"data": out})
}
