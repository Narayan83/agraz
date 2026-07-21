package models

import (
	"time"

	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

type EcomVariant struct {
	ID uint `json:"id" gorm:"primaryKey"`

	ProductID uint `json:"product_id" gorm:"not null;index"`
	ColorID   uint `json:"color_id" gorm:"not null;index"`

	SKU     string `json:"sku" gorm:"type:varchar(100);not null;uniqueIndex;index"`
	Barcode *string `json:"barcode,omitempty" gorm:"type:varchar(100)"`

	Price          decimal.Decimal  `json:"price" gorm:"type:numeric(15,2);not null;default:0"`
	CompareAtPrice *decimal.Decimal `json:"compare_at_price,omitempty" gorm:"type:numeric(15,2)"`
	Quantity       int             `json:"quantity" gorm:"not null;default:0"`

	ImageURL *string `json:"image_url,omitempty" gorm:"type:text"`
	Status   string  `json:"status" gorm:"type:varchar(20);not null;default:'active';index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`
	CreatedAt time.Time  `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time  `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`

	// Associations (store/cart endpoints)
	Color *EcomColor `json:"color,omitempty" gorm:"foreignKey:ColorID"`
	Product *EcomProduct `json:"product,omitempty" gorm:"foreignKey:ProductID"`
}

func (EcomVariant) TableName() string { return "variants" }

