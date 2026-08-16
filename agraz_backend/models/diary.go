package models

import "time"

// DiaryLabel is a user-defined tag/icon for diary entries.
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

// DiaryEntry is a free-form diary note with optional label and numeric fields.
type DiaryEntry struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index;default:0" json:"user_id"`
	LabelID   *uint     `gorm:"index" json:"label_id,omitempty"`
	Label     *DiaryLabel `gorm:"foreignKey:LabelID" json:"label,omitempty"`
	Title     string    `gorm:"type:varchar(255);not null;default:''" json:"title"`
	Content   string    `gorm:"type:text;not null;default:''" json:"content"`
	Amount    *float64  `gorm:"type:numeric(15,2)" json:"amount,omitempty"`
	NumDays   *float64  `gorm:"type:numeric(10,2)" json:"num_days,omitempty"`
	Date      time.Time `gorm:"not null;index" json:"date"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (DiaryEntry) TableName() string {
	return "diary_entries"
}
