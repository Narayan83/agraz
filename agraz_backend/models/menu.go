package models

import (
	"time"

	"gorm.io/datatypes"
)

type Menu struct {
	ID           uint           `json:"id" gorm:"primaryKey"`
	MenuName     string         `json:"menu_name" gorm:"type:varchar(255);not null"`
	Description  string         `json:"description"`
	URL          string         `json:"url" gorm:"type:varchar(500)"`
	Icon         string         `json:"icon" gorm:"type:varchar(100)"`
	ParentID     *uint          `json:"parent_id"`
	Parent       *Menu          `json:"parent,omitempty" gorm:"foreignKey:ParentID"`
	Children     []Menu         `json:"children,omitempty" gorm:"foreignKey:ParentID"`
	SortOrder    int            `json:"sort_order" gorm:"default:0"`
	MenuType     string         `json:"menu_type" gorm:"type:varchar(50);default:'main'"`
	IsActive     bool           `json:"is_active" gorm:"default:true"`
	RequiresAuth bool           `json:"requires_auth" gorm:"default:false"`
	Permissions  datatypes.JSON `json:"permissions"`
	CreatedAt    time.Time      `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt    time.Time      `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`
}
