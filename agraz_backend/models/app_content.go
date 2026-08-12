package models

import "time"

// AppContent is CMS text for menus (labour help, I&E help, home blurbs, etc.).
type AppContent struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	MenuKey   string    `gorm:"type:varchar(100);not null;uniqueIndex" json:"menu_key"`
	Title     string    `gorm:"type:varchar(255);not null;default:''" json:"title"`
	Body      string    `gorm:"type:text;not null;default:''" json:"body"`
	Locale    string    `gorm:"type:varchar(10);not null;default:'en'" json:"locale"`
	IsActive  bool      `gorm:"not null;default:true" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (AppContent) TableName() string {
	return "app_contents"
}
