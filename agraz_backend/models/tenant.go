package models

import "time"

// Tenant isolates catalog, carts, and storefront data. Single deployment can serve
// multiple tenants; optional marketplace mode enables vendor-scoped catalog logic.
type Tenant struct {
	ID             uint   `gorm:"primaryKey" json:"id"`
	Name           string `gorm:"type:varchar(255);not null" json:"name"`
	Domain         *string `gorm:"type:varchar(255);uniqueIndex" json:"domain,omitempty"`
	IsMarketplace  bool   `gorm:"not null;default:false;index" json:"is_marketplace"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Tenant) TableName() string { return "tenants" }
