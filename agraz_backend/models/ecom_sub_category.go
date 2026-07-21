package models

import (
	"time"

	"gorm.io/gorm"
)

type EcomSubCategory struct {
	ID          uint       `json:"id" gorm:"primaryKey"`
	TenantID    uint       `json:"tenant_id" gorm:"not null;default:1;index;uniqueIndex:ux_subcategories_tenant_slug"`
	CategoryID  uint       `json:"category_id" gorm:"not null;index"`
	Name        string     `json:"name" gorm:"type:varchar(255);not null"`
	Slug        string     `json:"slug" gorm:"type:varchar(255);not null;uniqueIndex:ux_subcategories_tenant_slug"`
	Description *string    `json:"description,omitempty" gorm:"type:text"`
	Status      string     `json:"status" gorm:"type:varchar(20);not null;default:'active';index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`

	CreatedAt time.Time `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`
}

func (EcomSubCategory) TableName() string {
	return "sub_categories"
}

