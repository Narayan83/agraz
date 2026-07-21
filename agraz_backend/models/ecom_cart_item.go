package models

import (
	"time"

	"gorm.io/gorm"
)

type EcomCartItem struct {
	ID uint `json:"id" gorm:"primaryKey;autoIncrement"`

	CartID    uint `json:"cart_id" gorm:"not null;index;uniqueIndex:uk_cart_variant"`
	VariantID uint `json:"variant_id" gorm:"not null;index;uniqueIndex:uk_cart_variant"`
	Quantity  int  `json:"quantity" gorm:"not null;default:1"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`

	CreatedAt time.Time `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`

	Variant EcomVariant `json:"variant,omitempty" gorm:"foreignKey:VariantID"`
}

func (EcomCartItem) TableName() string { return "cart_items" }

