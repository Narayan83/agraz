package models

import (
	"time"
)



type User struct {
	ID            uint      `gorm:"primaryKey" json:"id"`
	TenantID      uint      `gorm:"not null;default:1;index" json:"tenant_id"`
	Usercode      *string   `gorm:"uniqueIndex;size:100" json:"usercode,omitempty"`
	Firstname     string    `json:"firstname"`
	Lastname      string    `json:"lastname"`
	Username      string    `json:"username,omitempty"`
	// MobileNumber optional; used by Agraz/mobile registration (public /api/mobile/register).
	MobileNumber *string `gorm:"type:varchar(20);index" json:"mobile_number,omitempty"`
	Email         string    `gorm:"unique;not null" json:"email"`
	Password      string    `json:"-"`                        // hashed password, never return to frontend
	PlainPassword string    `json:"plain_password,omitempty"` // plain text password for display
	Active        bool      `json:"active"`
	// Approved: mobile self-registrations start false (cooling period) until admin verifies.
	// Existing / admin-created users default true so they keep access after migrate.
	Approved      bool      `gorm:"not null;default:true" json:"approved"`
	VendorID      *uint     `gorm:"index" json:"vendor_id,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

