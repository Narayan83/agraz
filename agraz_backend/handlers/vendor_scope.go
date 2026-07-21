package handler

import (
	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
)

func userIDFromCtx(c *fiber.Ctx) (uint, bool) {
	v := c.Locals("user_id")
	if v == nil {
		return 0, false
	}
	switch id := v.(type) {
	case float64:
		return uint(id), true
	case int:
		return uint(id), true
	case uint:
		return id, true
	default:
		return 0, false
	}
}

func scopedVendorID(c *fiber.Ctx) *uint {
	if v := c.Locals(middleware.CtxVendorID); v != nil {
		if id, ok := v.(uint); ok && id > 0 {
			u := id
			return &u
		}
	}
	return nil
}

func userIsSuperAdmin(userID uint) bool {
	var roleMappings []models.UserRoleMapping
	if err := userDB.Where("user_id = ?", userID).Find(&roleMappings).Error; err != nil || len(roleMappings) == 0 {
		return false
	}
	roleIDs := make([]uint, 0, len(roleMappings))
	for _, m := range roleMappings {
		roleIDs = append(roleIDs, m.RoleID)
	}
	var roles []models.Role
	if err := userDB.Where("id IN ?", roleIDs).Find(&roles).Error; err != nil {
		return false
	}
	for _, r := range roles {
		if r.RoleName == "Super Admin" || r.RoleName == "Admin" {
			return true
		}
	}
	return false
}

func isVendorPortalUser(c *fiber.Ctx) bool {
	uid, ok := userIDFromCtx(c)
	if !ok {
		return false
	}
	if userIsSuperAdmin(uid) {
		return false
	}
	return scopedVendorID(c) != nil
}

func vendorProductIDs(vendorID uint) ([]uint, error) {
	var ids []uint
	if err := ecomDB.Model(&models.VendorProductMapping{}).
		Where("vendor_id = ?", vendorID).
		Pluck("product_id", &ids).Error; err != nil {
		return nil, err
	}
	seen := map[uint]struct{}{}
	out := make([]uint, 0, len(ids))
	for _, id := range ids {
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	return out, nil
}

func vendorCanAccessProduct(c *fiber.Ctx, productID uint) bool {
	vid := scopedVendorID(c)
	if vid == nil {
		return true
	}
	if userIsSuperAdmin(mustUserID(c)) {
		return true
	}
	ids, err := vendorProductIDs(*vid)
	if err != nil {
		return false
	}
	for _, id := range ids {
		if id == productID {
			return true
		}
	}
	return false
}

func mustUserID(c *fiber.Ctx) uint {
	id, _ := userIDFromCtx(c)
	return id
}

func forbidVendorPortal(c *fiber.Ctx) error {
	if isVendorPortalUser(c) {
		return c.Status(403).JSON(fiber.Map{"error": "Forbidden for vendor accounts"})
	}
	return nil
}
