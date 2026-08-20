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

// accountSessionPayload returns the shared farm account details. Sub-users see
// the main holder's profile so family members work on one set of books.
func accountSessionPayload(loginUser models.User) fiber.Map {
	account := loginUser
	isSub := false
	disabled := []string{}
	if loginUser.ParentUserID != nil && *loginUser.ParentUserID > 0 {
		var parent models.User
		if err := userDB.Where("id = ?", *loginUser.ParentUserID).First(&parent).Error; err == nil {
			account = parent
			isSub = true
			disabled = parseDisabledFeatureList(loginUser.DisabledFeatures)
		}
	}
	out := userVendorPayload(account)
	out["is_sub_user"] = isSub
	out["can_manage_family"] = !isSub
	out["disabled_features"] = disabled
	out["member_id"] = loginUser.ID
	if isSub {
		out["parent_user_id"] = *loginUser.ParentUserID
		out["member"] = fiber.Map{
			"id":            loginUser.ID,
			"firstname":     loginUser.Firstname,
			"lastname":      loginUser.Lastname,
			"email":         loginUser.Email,
			"mobile_number": loginUser.MobileNumber,
			"active":        loginUser.Active,
		}
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
	return c.JSON(accountSessionPayload(user))
}
