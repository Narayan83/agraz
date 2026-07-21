package models

import (
	"time"

	"gorm.io/gorm"
)

type EcomStockMovement struct {
	ID uint `json:"id" gorm:"primaryKey;autoIncrement"`

	ProductID uint `json:"product_id" gorm:"not null;index"`
	VariantID *uint `json:"variant_id,omitempty" gorm:"index"`

	QuantityChange int    `json:"quantity_change" gorm:"not null"`
	Type            string `json:"type" gorm:"type:varchar(10);not null;index"` // in/out
	Reason          *string `json:"reason,omitempty" gorm:"type:text"`
	ReferenceID     *string `json:"reference_id,omitempty" gorm:"type:text"`

	CreatedBy uint `json:"created_by" gorm:"not null;index"`
	CreatedAt time.Time `json:"created_at" gorm:"default:CURRENT_TIMESTAMP;index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`
}

func (EcomStockMovement) TableName() string {
	return "stock_movements"
}

