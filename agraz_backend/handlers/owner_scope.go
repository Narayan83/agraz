package handler

import (
	"erp.local/backend/middleware"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// requireUserID returns the farm owner id (main account). Family sub-users
// share the parent's books, so all data queries/writes use this id.
func requireUserID(c *fiber.Ctx) (uint, error) {
	if v := c.Locals(middleware.CtxOwnerUserID); v != nil {
		if id, ok := v.(uint); ok && id > 0 {
			return id, nil
		}
	}
	uid, ok := userIDFromCtx(c)
	if !ok || uid == 0 {
		return 0, fiber.NewError(fiber.StatusUnauthorized, "Login required")
	}
	return uid, nil
}

func actorUserID(c *fiber.Ctx) (uint, error) {
	uid, ok := userIDFromCtx(c)
	if !ok || uid == 0 {
		return 0, fiber.NewError(fiber.StatusUnauthorized, "Login required")
	}
	return uid, nil
}

func isSubUser(c *fiber.Ctx) bool {
	v := c.Locals(middleware.CtxIsSubUser)
	b, _ := v.(bool)
	return b
}

func scopeByUserID(q *gorm.DB, userID uint) *gorm.DB {
	return q.Where("user_id = ?", userID)
}
