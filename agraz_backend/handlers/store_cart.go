package handler

import (
	"errors"
	"fmt"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

func currentUserID(c *fiber.Ctx) (uint, error) {
	v := c.Locals("user_id")
	if v == nil {
		return 0, errors.New("unauthorized")
	}
	switch t := v.(type) {
	case uint:
		return t, nil
	case int:
		if t < 0 {
			return 0, errors.New("invalid user_id")
		}
		return uint(t), nil
	case int64:
		if t < 0 {
			return 0, errors.New("invalid user_id")
		}
		return uint(t), nil
	case float64:
		if t < 0 {
			return 0, errors.New("invalid user_id")
		}
		return uint(t), nil
	default:
		return 0, errors.New("invalid user_id type")
	}
}

func getOrCreateOpenCart(c *fiber.Ctx, userID uint) (models.EcomCart, error) {
	tid := tenantIDFromCtx(c)
	var cart models.EcomCart
	err := ecomDB.
		Where("user_id = ? AND tenant_id = ? AND status = ?", userID, tid, "open").
		First(&cart).Error
	if err == nil {
		return cart, nil
	}
	if errors.Is(err, gorm.ErrRecordNotFound) {
		cart = models.EcomCart{UserID: userID, TenantID: tid, Status: "open"}
		if err2 := ecomDB.Create(&cart).Error; err2 != nil {
			return models.EcomCart{}, err2
		}
		return cart, nil
	}
	return models.EcomCart{}, err
}

type addCartItemRequest struct {
	VariantID uint `json:"variant_id"`
	Quantity  int  `json:"quantity"`
}

type cartLineItem struct {
	ID         uint           `json:"id"`
	Quantity   int            `json:"quantity"`
	Variant    models.EcomVariant `json:"variant"`
	LineTotal  string         `json:"line_total"`
}

type cartResponse struct {
	CartID     uint            `json:"cart_id"`
	Status     string          `json:"status"`
	ItemCount  int             `json:"item_count"`
	Subtotal   string          `json:"subtotal"`
	Items      []cartLineItem `json:"items"`
}

func toCartResponse(cart models.EcomCart) (cartResponse, error) {
	var items []models.EcomCartItem
	if err := ecomDB.
		Where("cart_id = ?", cart.ID).
		Preload("Variant.Color").
		Preload("Variant.Product").
		Find(&items).Error; err != nil {
		return cartResponse{}, err
	}

	subtotal := decimal.Zero
	itemCount := 0
	respItems := make([]cartLineItem, 0, len(items))
	for _, it := range items {
		itemCount += it.Quantity
		line := it.Variant.Price.Mul(decimal.NewFromInt(int64(it.Quantity)))
		subtotal = subtotal.Add(line)
		respItems = append(respItems, cartLineItem{
			ID:        it.ID,
			Quantity:  it.Quantity,
			Variant:   it.Variant,
			LineTotal: line.String(),
		})
	}

	return cartResponse{
		CartID:    cart.ID,
		Status:    cart.Status,
		ItemCount: itemCount,
		Subtotal:  subtotal.String(),
		Items:     respItems,
	}, nil
}

func GetStoreCart(c *fiber.Ctx) error {
	uid, err := currentUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	cart, err := getOrCreateOpenCart(c, uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	resp, err := toCartResponse(cart)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"data": resp})
}

func AddStoreCartItem(c *fiber.Ctx) error {
	uid, err := currentUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var body addCartItemRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	if body.VariantID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "variant_id is required"})
	}
	if body.Quantity < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "quantity must be at least 1"})
	}

	tid := tenantIDFromCtx(c)
	var variant models.EcomVariant
	if err := ecomDB.
		Joins("JOIN products ON products.id = variants.product_id").
		Where("variants.id = ? AND variants.status = ? AND products.tenant_id = ?", body.VariantID, "active", tid).
		First(&variant).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "variant not found"})
	}

	if variant.Quantity < body.Quantity {
		return c.Status(400).JSON(fiber.Map{"error": fmt.Sprintf("Insufficient stock. Available: %d", variant.Quantity)})
	}

	cart, err := getOrCreateOpenCart(c, uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var item models.EcomCartItem
	err = ecomDB.
		Where("cart_id = ? AND variant_id = ?", cart.ID, body.VariantID).
		First(&item).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			item = models.EcomCartItem{CartID: cart.ID, VariantID: body.VariantID, Quantity: body.Quantity}
			if err2 := ecomDB.Create(&item).Error; err2 != nil {
				return c.Status(500).JSON(fiber.Map{"error": err2.Error()})
			}
		} else {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	} else {
		// item exists: overwrite quantity to requested amount
		if item.Quantity == body.Quantity {
			return c.JSON(fiber.Map{"data": item})
		}
		if variant.Quantity < body.Quantity {
			return c.Status(400).JSON(fiber.Map{"error": "insufficient stock"})
		}
		if err := ecomDB.Model(&item).Update("quantity", body.Quantity).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}

	resp, err := toCartResponse(cart)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": resp})
}

type updateCartItemRequest struct {
	Quantity int `json:"quantity"`
}

func UpdateStoreCartItem(c *fiber.Ctx) error {
	uid, err := currentUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var body updateCartItemRequest
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	if body.Quantity < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "quantity must be at least 1"})
	}

	variantID := c.Params("variant_id")
	if variantID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "variant_id is required"})
	}

	tid := tenantIDFromCtx(c)
	var cart models.EcomCart
	if err := ecomDB.
		Where("user_id = ? AND tenant_id = ? AND status = ?", uid, tid, "open").
		First(&cart).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "cart not found"})
	}

	var variant models.EcomVariant
	if err := ecomDB.
		Joins("JOIN products ON products.id = variants.product_id").
		Where("variants.id = ? AND variants.status = ? AND products.tenant_id = ?", variantID, "active", tid).
		First(&variant).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "variant not found"})
	}
	if variant.Quantity < body.Quantity {
		return c.Status(400).JSON(fiber.Map{"error": "insufficient stock"})
	}

	if err := ecomDB.
		Where("cart_id = ? AND variant_id = ?", cart.ID, variantID).
		Updates(map[string]interface{}{"quantity": body.Quantity}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	resp, err := toCartResponse(cart)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": resp})
}

func DeleteStoreCartItem(c *fiber.Ctx) error {
	uid, err := currentUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	variantID := c.Params("variant_id")
	if variantID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "variant_id is required"})
	}

	tid := tenantIDFromCtx(c)
	var cart models.EcomCart
	if err := ecomDB.
		Where("user_id = ? AND tenant_id = ? AND status = ?", uid, tid, "open").
		First(&cart).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "cart not found"})
	}

	if err := ecomDB.
		Where("cart_id = ? AND variant_id = ?", cart.ID, variantID).
		Delete(&models.EcomCartItem{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	resp, err := toCartResponse(cart)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": resp})
}

