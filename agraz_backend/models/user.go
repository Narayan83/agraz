package models

import (
	"time"

	"gorm.io/datatypes"
)



type User struct {
	ID            uint      `gorm:"primaryKey" json:"id"`
	TenantID      uint      `gorm:"not null;default:1;index;uniqueIndex:idx_users_tenant_mobile" json:"tenant_id"`
	Usercode      *string   `gorm:"uniqueIndex;size:100" json:"usercode,omitempty"`
	Firstname     string    `json:"firstname"`
	Lastname      string    `json:"lastname"`
	Username      string    `json:"username,omitempty"`
	// MobileNumber used by Agraz/mobile registration (public /api/mobile/register).
	// Unique per tenant when set (NULLs allowed for non-mobile users).
	MobileNumber *string `gorm:"type:varchar(20);uniqueIndex:idx_users_tenant_mobile" json:"mobile_number,omitempty"`
	Email         string    `gorm:"unique;not null" json:"email"`
	Password      string    `json:"-"`                        // hashed password, never return to frontend
	PlainPassword string    `json:"plain_password,omitempty"` // plain text password for display
	Active        bool      `json:"active"`
	// Approved: new users (mobile + admin) are auto-approved; admin can still revoke.
	Approved      bool      `gorm:"not null;default:true" json:"approved"`
	VendorID      *uint     `gorm:"index" json:"vendor_id,omitempty"`
	// ParentUserID is set for family sub-accounts. Their farm data is stored
	// on the parent (main) account. Empty means this user is a main holder.
	ParentUserID *uint `gorm:"index" json:"parent_user_id,omitempty"`
	// DisabledFeatures is a JSON string array of app option keys the main
	// holder has turned off for this sub-member. Empty/[] means all options.
	DisabledFeatures datatypes.JSON `gorm:"type:jsonb;not null;default:'[]'" json:"disabled_features,omitempty"`
	CreatedAt        time.Time      `json:"created_at"`
	UpdatedAt        time.Time      `json:"updated_at"`
}

