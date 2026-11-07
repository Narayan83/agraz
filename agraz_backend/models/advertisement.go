package models

import (
	"time"

	"gorm.io/gorm"
)

// Advertisement is a home-screen carousel slide managed from the admin panel.
type Advertisement struct {
	ID uint `json:"id" gorm:"primaryKey"`

	TenantID uint `json:"tenant_id" gorm:"not null;default:1;index"`

	Title    string  `json:"title" gorm:"type:varchar(80);not null"`
	Subtitle *string `json:"subtitle,omitempty" gorm:"type:varchar(120)"`
	Tag      *string `json:"tag,omitempty" gorm:"type:varchar(32)"`

	ImageURL string `json:"image_url" gorm:"type:text;not null"`

	// LinkType: none | external_url | in_app_screen
	LinkType  string  `json:"link_type" gorm:"type:varchar(32);not null;default:none"`
	LinkValue *string `json:"link_value,omitempty" gorm:"type:varchar(512)"`

	SortOrder int  `json:"sort_order" gorm:"not null;default:0;index"`
	IsActive  bool `json:"is_active" gorm:"not null;default:true;index"`

	StartDate *time.Time `json:"start_date,omitempty" gorm:"index"`
	EndDate   *time.Time `json:"end_date,omitempty" gorm:"index"`

	Impressions int64 `json:"impressions" gorm:"not null;default:0"`
	Clicks      int64 `json:"clicks" gorm:"not null;default:0"`

	CreatedBy *uint `json:"created_by,omitempty" gorm:"index"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
}

func (Advertisement) TableName() string {
	return "advertisements"
}
