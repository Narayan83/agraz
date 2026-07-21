package models

import (
	"time"

	"github.com/shopspring/decimal"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type EcomProduct struct {
	ID uint `json:"id" gorm:"primaryKey"`

	TenantID uint `json:"tenant_id" gorm:"not null;default:1;index;uniqueIndex:ux_products_tenant_slug"`
	VendorID *uint `json:"vendor_id,omitempty" gorm:"index"`

	Name        string `json:"name" gorm:"type:text;not null"`
	Description *string `json:"description,omitempty" gorm:"type:text"`
	Slug        string `json:"slug" gorm:"type:varchar(255);not null;uniqueIndex:ux_products_tenant_slug"`

	// VendorRef is populated on store/marketplace API responses only (not persisted).
	VendorRef *VendorRefJSON `json:"vendor,omitempty" gorm:"-"`

	Price          decimal.Decimal  `json:"price" gorm:"type:numeric(15,2);not null;default:0"`
	CompareAtPrice *decimal.Decimal `json:"compare_at_price,omitempty" gorm:"type:numeric(15,2)"`
	Cost           decimal.Decimal  `json:"cost" gorm:"type:numeric(15,2);not null;default:0"`

	SKU     *string `json:"sku,omitempty" gorm:"type:varchar(100);uniqueIndex"`
	Barcode *string `json:"barcode,omitempty" gorm:"type:varchar(100);uniqueIndex"`

	Quantity              int  `json:"quantity" gorm:"not null;default:0"`
	LowStockThreshold     int  `json:"low_stock_threshold" gorm:"not null;default:0"`
	Status                string `json:"status" gorm:"type:varchar(20);not null;default:'active';index"`
	IsFeatured            bool   `json:"is_featured" gorm:"not null;default:false;index"`

	Weight     decimal.Decimal `json:"weight" gorm:"type:numeric(10,2);not null;default:0"`
	Dimensions datatypes.JSON  `json:"dimensions,omitempty" gorm:"type:jsonb;default:'[]'"`

	SEOCodeTitle       *string `json:"seo_title,omitempty" gorm:"type:varchar(255)"`
	SEODescription     *string `json:"seo_description,omitempty" gorm:"type:text"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`
	CreatedAt time.Time  `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time  `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`

	// Associations (used for store/cart endpoints)
	Variants          []EcomVariant          `json:"variants,omitempty" gorm:"foreignKey:ProductID"`
	Images            []EcomProductImage     `json:"images,omitempty" gorm:"foreignKey:ProductID"`
	ProductCategories []EcomProductCategory  `json:"product_categories,omitempty" gorm:"foreignKey:ProductID"`
}

func (EcomProduct) TableName() string {
	return "products"
}

