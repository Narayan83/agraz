package handler

import (
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var vendorDB *gorm.DB

func SetVendorDB(db *gorm.DB) {
	vendorDB = db
}

const (
	vendorBusinessIndividual  = "individual"
	vendorBusinessSole        = "sole_proprietorship"
	vendorBusinessPartnership = "partnership"
)

func isValidVendorBusinessType(s string) bool {
	switch strings.TrimSpace(strings.ToLower(s)) {
	case vendorBusinessIndividual, vendorBusinessSole, vendorBusinessPartnership:
		return true
	default:
		return false
	}
}

type vendorCreatePayload struct {
	BusinessType    string  `json:"business_type"`
	BusinessName    string  `json:"business_name"`
	Address         string  `json:"address"`
	PhoneNumber     string  `json:"phone_number"`
	MobileNumber    string  `json:"mobile_number"`
	WhatsappNumber  *string `json:"whatsapp_number"`
	Location        *string `json:"location"`
	Pincode         *string `json:"pincode"`
	OwnerName       string  `json:"owner_name"`
	OwnerAddress    *string `json:"owner_address"`
	OwnerPhone      *string `json:"owner_phone"`
	OwnerWhatsapp   *string `json:"owner_whatsapp"`
}

type vendorUpdatePayload struct {
	BusinessType    *string `json:"business_type"`
	BusinessName    *string `json:"business_name"`
	Address         *string `json:"address"`
	PhoneNumber     *string `json:"phone_number"`
	MobileNumber    *string `json:"mobile_number"`
	WhatsappNumber  *string `json:"whatsapp_number"`
	Location        *string `json:"location"`
	Pincode         *string `json:"pincode"`
	OwnerName       *string `json:"owner_name"`
	OwnerAddress    *string `json:"owner_address"`
	OwnerPhone      *string `json:"owner_phone"`
	OwnerWhatsapp   *string `json:"owner_whatsapp"`
}

func CreateVendor(c *fiber.Ctx) error {
	if err := forbidVendorPortal(c); err != nil {
		return err
	}
	var body vendorCreatePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	bt := strings.TrimSpace(strings.ToLower(body.BusinessType))
	if !isValidVendorBusinessType(bt) {
		return c.Status(400).JSON(fiber.Map{"error": "business_type must be individual, sole_proprietorship, or partnership"})
	}
	if strings.TrimSpace(body.BusinessName) == "" || strings.TrimSpace(body.Address) == "" ||
		strings.TrimSpace(body.PhoneNumber) == "" || strings.TrimSpace(body.MobileNumber) == "" ||
		strings.TrimSpace(body.OwnerName) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "business_name, address, phone_number, mobile_number, and owner_name are required"})
	}
	row := models.Vendor{
		TenantID:        tenantIDFromCtx(c),
		Status:          "active",
		BusinessType:    bt,
		BusinessName:    strings.TrimSpace(body.BusinessName),
		Address:         strings.TrimSpace(body.Address),
		PhoneNumber:     strings.TrimSpace(body.PhoneNumber),
		MobileNumber:    strings.TrimSpace(body.MobileNumber),
		WhatsappNumber:  trimStringPtr(body.WhatsappNumber),
		Location:        trimStringPtr(body.Location),
		Pincode:         trimStringPtr(body.Pincode),
		OwnerName:       strings.TrimSpace(body.OwnerName),
		OwnerAddress:    trimStringPtr(body.OwnerAddress),
		OwnerPhone:      trimStringPtr(body.OwnerPhone),
		OwnerWhatsapp:   trimStringPtr(body.OwnerWhatsapp),
	}
	if err := vendorDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create vendor", "details": err.Error()})
	}
	return c.Status(201).JSON(row)
}

func GetVendors(c *fiber.Ctx) error {
	if vid := scopedVendorID(c); vid != nil && !userIsSuperAdmin(mustUserID(c)) {
		tid := tenantIDFromCtx(c)
		var row models.Vendor
		if err := vendorDB.Where("id = ? AND tenant_id = ?", *vid, tid).First(&row).Error; err != nil {
			return c.Status(404).JSON(fiber.Map{"error": "Vendor not found"})
		}
		return c.JSON(fiber.Map{"data": []models.Vendor{row}, "total": 1, "page": 1, "limit": 1})
	}

	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 10
	}
	offset := (page - 1) * limit

	tid := tenantIDFromCtx(c)
	var rows []models.Vendor
	var total int64
	q := vendorDB.Model(&models.Vendor{}).Where("tenant_id = ?", tid)
	if s := strings.TrimSpace(c.Query("search")); s != "" {
		like := "%" + s + "%"
		q = q.Where("business_name ILIKE ? OR owner_name ILIKE ? OR mobile_number ILIKE ?", like, like, like)
	}
	if bt := strings.TrimSpace(strings.ToLower(c.Query("business_type"))); bt != "" {
		q = q.Where("business_type = ?", bt)
	}
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetVendor(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var row models.Vendor
	if err := vendorDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Vendor not found"})
	}
	return c.JSON(row)
}

func UpdateVendor(c *fiber.Ctx) error {
	if err := forbidVendorPortal(c); err != nil {
		return err
	}
	var body vendorUpdatePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	tid := tenantIDFromCtx(c)
	var row models.Vendor
	if err := vendorDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Vendor not found"})
	}
	updates := map[string]interface{}{}
	if body.BusinessType != nil {
		bt := strings.TrimSpace(strings.ToLower(*body.BusinessType))
		if !isValidVendorBusinessType(bt) {
			return c.Status(400).JSON(fiber.Map{"error": "business_type must be individual, sole_proprietorship, or partnership"})
		}
		updates["business_type"] = bt
	}
	if body.BusinessName != nil {
		updates["business_name"] = strings.TrimSpace(*body.BusinessName)
	}
	if body.Address != nil {
		updates["address"] = strings.TrimSpace(*body.Address)
	}
	if body.PhoneNumber != nil {
		updates["phone_number"] = strings.TrimSpace(*body.PhoneNumber)
	}
	if body.MobileNumber != nil {
		updates["mobile_number"] = strings.TrimSpace(*body.MobileNumber)
	}
	if body.WhatsappNumber != nil {
		updates["whatsapp_number"] = trimStringPtr(body.WhatsappNumber)
	}
	if body.Location != nil {
		updates["location"] = trimStringPtr(body.Location)
	}
	if body.Pincode != nil {
		updates["pincode"] = trimStringPtr(body.Pincode)
	}
	if body.OwnerName != nil {
		updates["owner_name"] = strings.TrimSpace(*body.OwnerName)
	}
	if body.OwnerAddress != nil {
		updates["owner_address"] = trimStringPtr(body.OwnerAddress)
	}
	if body.OwnerPhone != nil {
		updates["owner_phone"] = trimStringPtr(body.OwnerPhone)
	}
	if body.OwnerWhatsapp != nil {
		updates["owner_whatsapp"] = trimStringPtr(body.OwnerWhatsapp)
	}
	if len(updates) == 0 {
		return c.JSON(row)
	}
	if err := vendorDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update vendor", "details": err.Error()})
	}
	vendorDB.First(&row, row.ID)
	return c.JSON(row)
}

func DeleteVendor(c *fiber.Ctx) error {
	if err := forbidVendorPortal(c); err != nil {
		return err
	}
	tid := tenantIDFromCtx(c)
	var row models.Vendor
	if err := vendorDB.Where("id = ? AND tenant_id = ?", c.Params("id"), tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Vendor not found"})
	}
	if err := vendorDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}

func trimStringPtr(p *string) *string {
	if p == nil {
		return nil
	}
	s := strings.TrimSpace(*p)
	if s == "" {
		return nil
	}
	return &s
}
