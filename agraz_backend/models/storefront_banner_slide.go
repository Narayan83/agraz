package models

import (
	"time"

	"gorm.io/gorm"
)

// StorefrontBannerSlide is one carousel slide on the public storefront home hero.
type StorefrontBannerSlide struct {
	ID uint `json:"id" gorm:"primaryKey"`

	TenantID uint `json:"tenant_id" gorm:"not null;default:1;index"`
	Slot     string `json:"slot" gorm:"type:varchar(32);not null;default:home;index"`
	SortOrder int    `json:"sort_order" gorm:"not null;default:0;index"`

	ImageURL string `json:"image_url" gorm:"type:text;not null"`
	Title    string `json:"title" gorm:"type:text;not null"`
	Subtitle string `json:"subtitle" gorm:"type:text;not null"`
	CTALabel string `json:"cta_label" gorm:"type:varchar(120);not null;default:'Explore Our Products'"`
	CTAHref  string `json:"cta_href" gorm:"type:varchar(255);not null;default:'#products'"`

	IsActive bool `json:"is_active" gorm:"not null;default:true;index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
}

func (StorefrontBannerSlide) TableName() string {
	return "storefront_banner_slides"
}
