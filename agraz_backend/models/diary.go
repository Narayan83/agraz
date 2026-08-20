package models

import (
	"time"

	"gorm.io/datatypes"
)

// DiaryLabel is a user-defined tag/icon for notes and lists.
type DiaryLabel struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index;default:0" json:"user_id"`
	Name      string    `gorm:"type:varchar(100);not null" json:"name"`
	Icon      string    `gorm:"type:varchar(50);not null;default:'label'" json:"icon"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (DiaryLabel) TableName() string {
	return "diary_labels"
}

// DiaryListItem is a reusable checklist item the user can pick onto a list,
// managed the same way as labels.
type DiaryListItem struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index;default:0" json:"user_id"`
	Name      string    `gorm:"type:varchar(200);not null" json:"name"`
	Icon      string    `gorm:"type:varchar(50);not null;default:'check'" json:"icon"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (DiaryListItem) TableName() string {
	return "diary_list_items"
}

// DiaryEntry is a note or a checklist, with optional label and numeric fields.
type DiaryEntry struct {
	ID        uint           `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint           `gorm:"not null;index;default:0" json:"user_id"`
	LabelID   *uint          `gorm:"index" json:"label_id,omitempty"`
	Label     *DiaryLabel    `gorm:"foreignKey:LabelID" json:"label,omitempty"`
	Kind      string         `gorm:"type:varchar(20);not null;default:'note';index" json:"kind"`
	Title     string         `gorm:"type:varchar(255);not null;default:''" json:"title"`
	Content   string         `gorm:"type:text;not null;default:''" json:"content"`
	ListItems datatypes.JSON `gorm:"type:jsonb;not null;default:'[]'" json:"list_items"`
	Amount    *float64       `gorm:"type:numeric(15,2)" json:"amount,omitempty"`
	NumDays   *float64       `gorm:"type:numeric(10,2)" json:"num_days,omitempty"`
	Date      time.Time      `gorm:"not null;index" json:"date"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
}

func (DiaryEntry) TableName() string {
	return "diary_entries"
}
