package models

import (
	"time"

	"gorm.io/datatypes"
)

type RoleManagement struct {
	ID                        uint           `json:"id" gorm:"primaryKey"`
	RoleID                    uint           `json:"role_id"`
	MenuID                    uint           `json:"menu_id"`
	RoleManagementPermissions datatypes.JSON `json:"permissions" gorm:"type:jsonb;default:'{}'"`
	CreatedAt                 time.Time      `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt                 time.Time      `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`
}
