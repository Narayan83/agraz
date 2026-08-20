package models

import "time"

// ManagedEvent is a personal reminder (birthday, insurance renewal, etc.).
type ManagedEvent struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint      `gorm:"not null;index" json:"user_id"`
	Name       string    `gorm:"type:varchar(255);not null" json:"name"`
	EventDate  time.Time `gorm:"type:date;not null;index" json:"event_date"`
	Recurrence string    `gorm:"type:varchar(20);not null;default:'yearly';index" json:"recurrence"`
	NotifyTime string    `gorm:"type:varchar(8);not null;default:'09:00'" json:"notify_time"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

func (ManagedEvent) TableName() string {
	return "managed_events"
}
