package models

import "time"

// VendorProductMapping links a catalog product to a vendor with a quantity.
// The same product_id may appear for different vendors; (vendor_id, product_id) is unique per row.
type VendorProductMapping struct {
	ID        uint `gorm:"primaryKey;autoIncrement" json:"id"`
	VendorID  uint `gorm:"not null;index;uniqueIndex:ux_vendor_product" json:"vendor_id"`
	ProductID uint `gorm:"not null;index;uniqueIndex:ux_vendor_product" json:"product_id"`
	Quantity  int  `gorm:"not null;default:1" json:"quantity"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	Vendor  Vendor      `json:"vendor,omitempty" gorm:"foreignKey:VendorID"`
	Product EcomProduct `json:"product,omitempty" gorm:"foreignKey:ProductID"`
}

func (VendorProductMapping) TableName() string {
	return "vendor_product_mappings"
}
