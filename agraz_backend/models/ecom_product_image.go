package models

import (
	"time"

	"gorm.io/gorm"
)

type EcomProductImage struct {
	ID uint `json:"id" gorm:"primaryKey;autoIncrement"`

	ProductID uint `json:"product_id" gorm:"not null;index"`
	VariantID *uint `json:"variant_id,omitempty" gorm:"index"`

	ImageURL  string `json:"image_url" gorm:"type:text;not null"`
	IsPrimary bool   `json:"is_primary" gorm:"not null;default:false;index"`
	SortOrder int    `json:"sort_order" gorm:"not null;default:0;index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`

	CreatedAt time.Time `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`
}

func (EcomProductImage) TableName() string {
	return "product_images"
}

