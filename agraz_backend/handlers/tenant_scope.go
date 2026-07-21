package handler

import (
	"erp.local/backend/middleware"
	"github.com/gofiber/fiber/v2"
)

func tenantIDFromCtx(c *fiber.Ctx) uint {
	if v := c.Locals(middleware.CtxTenantID); v != nil {
		if id, ok := v.(uint); ok {
			return id
		}
	}
	return 1
}

func tenantIsMarketplace(c *fiber.Ctx) bool {
	if v := c.Locals(middleware.CtxTenantIsMarketplace); v != nil {
		if b, ok := v.(bool); ok {
			return b
		}
	}
	return false
}
