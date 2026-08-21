package middleware

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

func bearerToken(authHeader string) string {
	authHeader = strings.TrimSpace(authHeader)
	if authHeader == "" {
		return ""
	}
	if len(authHeader) >= 7 && strings.EqualFold(authHeader[:7], "bearer ") {
		return strings.TrimSpace(authHeader[7:])
	}
	// Some clients send the raw JWT with no scheme.
	if !strings.Contains(authHeader, " ") {
		return authHeader
	}
	return ""
}

func Protected() fiber.Handler {
	return func(c *fiber.Ctx) error {
		tokenString := bearerToken(c.Get("Authorization"))
		if tokenString == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error":   "Missing or malformed JWT",
				"message": "Missing or malformed JWT",
			})
		}

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			secret := strings.TrimSpace(os.Getenv("JWT_SECRET"))
			return []byte(secret), nil
		})

		if err != nil || token == nil || !token.Valid {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error":   "Invalid or expired JWT",
				"message": "Invalid or expired JWT",
			})
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error":   "Invalid or expired JWT",
				"message": "Invalid or expired JWT",
			})
		}
		c.Locals("user_id", claims["user_id"])
		c.Locals("email", claims["email"])

		if uid, ok := claims["user_id"].(float64); ok && uid > 0 {
			var u models.User
			if err := initializers.DB.Select("id", "vendor_id").First(&u, uint(uid)).Error; err == nil && u.VendorID != nil && *u.VendorID > 0 {
				c.Locals(CtxVendorID, *u.VendorID)
			}
		}

		return c.Next()
	}
}

// CheckPermission checks if the user has the required permission for a menu/resource.
// menuIdentifier can be the menu ID or Name.
// action is one of: can_view, can_create, can_update, can_delete
func CheckPermission(menuIdentifier string, action string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userIDVal := c.Locals("user_id")
		if userIDVal == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
		}
		userID := uint(userIDVal.(float64))

		// Get all Role IDs assigned to the user
		var roleMappings []models.UserRoleMapping
		if err := initializers.DB.Where("user_id = ?", userID).Find(&roleMappings).Error; err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to verify permissions"})
		}

		if len(roleMappings) == 0 {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Forbidden - No roles assigned"})
		}

		roleIDs := make([]uint, 0)
		for _, mapn := range roleMappings {
			roleIDs = append(roleIDs, mapn.RoleID)
		}

		// Check for Super Admin role
		var roles []models.Role
		if err := initializers.DB.Where("id IN ?", roleIDs).Find(&roles).Error; err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to verify roles"})
		}

		for _, r := range roles {
			if r.RoleName == "Super Admin" {
				return c.Next() // Bypass permission check
			}
		}

		var roleManagements []models.RoleManagement
		if err := initializers.DB.Where("role_id IN ?", roleIDs).Find(&roleManagements).Error; err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to fetch permissions"})
		}

		hasPermission := false

		for _, rm := range roleManagements {
			if len(rm.RoleManagementPermissions) > 0 {
				var perms map[string]map[string]bool
				if err := json.Unmarshal(rm.RoleManagementPermissions, &perms); err == nil {
					// Check by menuIdentifier (assuming key in JSON is menu ID or Name)
					// We might need to resolve menuIdentifier to ID if it's a name and stored by ID.
					// But lets assume consistency for now or check both.

					// Direct check
					if p, ok := perms[menuIdentifier]; ok {
						if allowed, ok2 := p[action]; ok2 && allowed {
							hasPermission = true
							break
						}
					}
				}
			}
		}

		if !hasPermission {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Forbidden - Insufficient permissions"})
		}

		return c.Next()
	}
}
