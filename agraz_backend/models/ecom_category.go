package models

import (
	"time"

	"gorm.io/gorm"
)

type EcomCategory struct {
	ID          uint       `json:"id" gorm:"primaryKey"`
	TenantID    uint       `json:"tenant_id" gorm:"not null;default:1;index;uniqueIndex:ux_categories_tenant_slug"`
	Name        string     `json:"name" gorm:"type:varchar(255);not null"`
	Slug        string     `json:"slug" gorm:"type:varchar(255);not null;uniqueIndex:ux_categories_tenant_slug"`
	Description *string    `json:"description,omitempty" gorm:"type:text"`
	ParentID    *uint      `json:"parent_id,omitempty" gorm:"index"`
	Image       *string    `json:"image,omitempty" gorm:"type:text"`
	Status      string     `json:"status" gorm:"type:varchar(20);not null;default:'active';index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`

	CreatedAt time.Time `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`
}

func (EcomCategory) TableName() string {
	return "categories"
}

