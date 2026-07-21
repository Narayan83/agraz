package models

import "time"

// Vendor stores business and owner contact details for a vendor.
type Vendor struct {
	ID uint `gorm:"primaryKey;autoIncrement" json:"id"`

	TenantID uint   `gorm:"not null;default:1;index" json:"tenant_id"`
	Status   string `gorm:"type:varchar(20);not null;default:'active';index" json:"status"`

	BusinessType string `gorm:"type:varchar(40);not null;index" json:"business_type"` // individual | sole_proprietorship | partnership
	BusinessName string `gorm:"type:varchar(255);not null" json:"business_name"`
	Address      string `gorm:"type:text;not null" json:"address"`

	PhoneNumber    string  `gorm:"type:varchar(20);not null" json:"phone_number"`
	MobileNumber   string  `gorm:"type:varchar(20);not null" json:"mobile_number"`
	WhatsappNumber *string `gorm:"type:varchar(20)" json:"whatsapp_number,omitempty"`

	Location *string `gorm:"type:varchar(255)" json:"location,omitempty"`
	Pincode  *string `gorm:"type:varchar(20)" json:"pincode,omitempty"`

	OwnerName       string  `gorm:"type:varchar(255);not null" json:"owner_name"`
	OwnerAddress    *string `gorm:"type:text" json:"owner_address,omitempty"`
	OwnerPhone      *string `gorm:"type:varchar(20)" json:"owner_phone,omitempty"`
	OwnerWhatsapp   *string `gorm:"type:varchar(20)" json:"owner_whatsapp,omitempty"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Vendor) TableName() string {
	return "vendors"
}
