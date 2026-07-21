package models

import (
	"time"

	"gorm.io/gorm"
)

type EcomColor struct {
	ID       uint   `json:"id" gorm:"primaryKey"`
	TenantID uint   `json:"tenant_id" gorm:"not null;default:1;index;uniqueIndex:ux_colors_tenant_hex"`
	Name     string `json:"name" gorm:"type:varchar(100);not null"`
	HexCode  string `json:"hex_code" gorm:"type:varchar(20);not null;uniqueIndex:ux_colors_tenant_hex"`
	Status  string `json:"status" gorm:"type:varchar(20);not null;default:'active';index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`

	CreatedAt time.Time `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`
}

func (EcomColor) TableName() string {
	return "colors"
}
