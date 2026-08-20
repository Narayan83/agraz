package models

import "time"

// PasswordResetCode is a one-time email code used to reset a forgotten password.
type PasswordResetCode struct {
	ID        uint       `gorm:"primaryKey" json:"id"`
	TenantID  uint       `gorm:"not null;default:1;index" json:"tenant_id"`
	UserID    uint       `gorm:"not null;index" json:"user_id"`
	Email     string     `gorm:"size:255;not null;index" json:"email"`
	CodeHash  string     `gorm:"size:255;not null" json:"-"`
	Attempts  int        `gorm:"not null;default:0" json:"-"`
	ExpiresAt time.Time  `gorm:"not null;index" json:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}
