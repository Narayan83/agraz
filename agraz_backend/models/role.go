package models

import (
	"time"

	"gorm.io/datatypes"
)

type Role struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	RoleName    string         `json:"role_name" gorm:"type:varchar(255);not null;unique"`
	Description string         `json:"description"`
	Permissions datatypes.JSON `json:"permissions" gorm:"type:jsonb;default:'{}'"`
	IsActive    bool           `json:"is_active" gorm:"default:true"`
	CreatedAt   time.Time      `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt   time.Time      `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`
}
