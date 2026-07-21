package middleware

import (
	"strconv"
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// Context keys for tenant resolution (used by handlers).
const (
	CtxTenantID            = "tenant_id"
	CtxTenantIsMarketplace = "tenant_is_marketplace"
	CtxTenantName          = "tenant_name"
	CtxVendorID            = "vendor_id"
)

// TenantResolver attaches the current tenant to each /api request.
// Resolution order: X-Tenant-ID header, Host matching tenants.domain, else default tenant id 1.
func TenantResolver(db *gorm.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		tid := uint(1)
		isMarketplace := false
		name := "Default"

		if hdr := strings.TrimSpace(c.Get("X-Tenant-ID")); hdr != "" {
			if parsed, err := strconv.ParseUint(hdr, 10, 32); err == nil && parsed > 0 {
				var t models.Tenant
				if result := db.Limit(1).Find(&t, uint(parsed)); result.Error == nil && result.RowsAffected > 0 {
					tid = t.ID
					isMarketplace = t.IsMarketplace
					name = t.Name
					setTenantLocals(c, tid, isMarketplace, name)
					return c.Next()
				}
			}
		}

		host := strings.ToLower(strings.TrimSpace(strings.Split(c.Hostname(), ":")[0]))
		if host != "" {
			var t models.Tenant
			if result := db.Where("LOWER(domain) = ?", host).Limit(1).Find(&t); result.Error == nil && result.RowsAffected > 0 {
				tid = t.ID
				isMarketplace = t.IsMarketplace
				name = t.Name
				setTenantLocals(c, tid, isMarketplace, name)
				return c.Next()
			}
		}

		var def models.Tenant
		if result := db.Limit(1).Find(&def, 1); result.Error == nil && result.RowsAffected > 0 {
			tid = def.ID
			isMarketplace = def.IsMarketplace
			name = def.Name
		}

		setTenantLocals(c, tid, isMarketplace, name)
		return c.Next()
	}
}

func setTenantLocals(c *fiber.Ctx, id uint, isMarketplace bool, name string) {
	c.Locals(CtxTenantID, id)
	c.Locals(CtxTenantIsMarketplace, isMarketplace)
	c.Locals(CtxTenantName, name)
}
