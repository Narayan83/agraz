package handler

import (
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// requireUserID returns the authenticated user id or a 401 Fiber error.
func requireUserID(c *fiber.Ctx) (uint, error) {
	uid, ok := userIDFromCtx(c)
	if !ok || uid == 0 {
		return 0, fiber.NewError(fiber.StatusUnauthorized, "Login required")
	}
	return uid, nil
}

func scopeByUserID(q *gorm.DB, userID uint) *gorm.DB {
	return q.Where("user_id = ?", userID)
}
