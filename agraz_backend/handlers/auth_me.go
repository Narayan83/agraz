package handler

import (
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
)

func userVendorPayload(user models.User) fiber.Map {
	out := fiber.Map{
		"id":            user.ID,
		"firstname":     user.Firstname,
		"lastname":      user.Lastname,
		"email":         user.Email,
		"mobile_number": user.MobileNumber,
		"active":        user.Active,
		"approved":      user.Approved,
		"created_at":    user.CreatedAt,
		"vendor_id":     user.VendorID,
	}
	if user.VendorID != nil && *user.VendorID > 0 {
		var v models.Vendor
		if err := vendorDB.Where("id = ? AND tenant_id = ?", *user.VendorID, user.TenantID).First(&v).Error; err == nil {
			out["vendor_name"] = v.BusinessName
			out["is_vendor_user"] = true
		}
	} else {
		out["is_vendor_user"] = false
	}
	return out
}

func GetMe(c *fiber.Ctx) error {
	uid, ok := userIDFromCtx(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "Unauthorized"})
	}
	tid := tenantIDFromCtx(c)
	var user models.User
	if err := userDB.Where("id = ? AND tenant_id = ?", uid, tid).First(&user).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}
	return c.JSON(userVendorPayload(user))
}
