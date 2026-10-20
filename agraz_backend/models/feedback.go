package models

import (
	"time"

	"gorm.io/gorm"
)

// AppFeedback stores in-app feedback from mobile users.
type AppFeedback struct {
	ID         uint           `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint           `gorm:"not null;index;default:0" json:"user_id"`
	UserName   string         `gorm:"type:varchar(255);not null;default:''" json:"user_name"`
	UserEmail  string         `gorm:"type:varchar(255);not null;default:''" json:"user_email"`
	UserPhone  string         `gorm:"type:varchar(20);not null;default:''" json:"user_phone"`
	Subject    string         `gorm:"type:varchar(255);not null;default:''" json:"subject"`
	Message    string         `gorm:"type:text;not null" json:"message"`
	Menu       string         `gorm:"type:varchar(100);not null;default:''" json:"menu"`
	Verified   bool           `gorm:"not null;default:false;index" json:"verified"`
	VerifiedAt *time.Time     `json:"verified_at,omitempty"`
	CreatedAt  time.Time      `json:"created_at"`
	UpdatedAt  time.Time      `json:"updated_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
}

func (AppFeedback) TableName() string {
	return "app_feedbacks"
}

// AppFeedbackDeletionLog keeps a snapshot when feedback is soft-deleted (for audit / revoke UI).
type AppFeedbackDeletionLog struct {
	ID              uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	FeedbackID      uint       `gorm:"not null;index" json:"feedback_id"`
	UserID          uint       `gorm:"not null;default:0" json:"user_id"`
	UserName        string     `gorm:"type:varchar(255);not null;default:''" json:"user_name"`
	UserEmail       string     `gorm:"type:varchar(255);not null;default:''" json:"user_email"`
	UserPhone       string     `gorm:"type:varchar(20);not null;default:''" json:"user_phone"`
	Subject         string     `gorm:"type:varchar(255);not null;default:''" json:"subject"`
	Message         string     `gorm:"type:text;not null" json:"message"`
	Menu            string     `gorm:"type:varchar(100);not null;default:''" json:"menu"`
	Verified        bool       `gorm:"not null;default:false" json:"verified"`
	DeletedByUserID uint       `gorm:"not null;default:0" json:"deleted_by_user_id"`
	DeletedAt       time.Time  `gorm:"not null;index" json:"deleted_at"`
	RestoredAt      *time.Time `json:"restored_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

func (AppFeedbackDeletionLog) TableName() string {
	return "app_feedback_deletion_logs"
}
