package models

import (
	"time"

	"gorm.io/gorm"
)

type EcomCart struct {
	ID uint `json:"id" gorm:"primaryKey;autoIncrement"`

	TenantID uint `json:"tenant_id" gorm:"not null;default:1;index"`
	UserID   uint `json:"user_id" gorm:"not null;index"`
	Status string `json:"status" gorm:"not null;default:'open';index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`

	CreatedAt time.Time `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`
}

func (EcomCart) TableName() string { return "carts" }

