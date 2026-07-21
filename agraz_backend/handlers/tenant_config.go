package handler

import "github.com/gofiber/fiber/v2"

// GetTenantConfig returns tenant feature flags for storefront, admin, and mobile clients.
func GetTenantConfig(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"is_marketplace": tenantIsMarketplace(c)})
}
