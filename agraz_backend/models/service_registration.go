package models

import (
	"time"

	"gorm.io/datatypes"
)

type ServiceRegistration struct {
	ID           uint   `gorm:"primaryKey;autoIncrement" json:"id"`
	Mobile       string `gorm:"type:varchar(15);not null" json:"mobile"`
	Name         string `gorm:"type:varchar(255);not null" json:"name"`
	MainCategory string `gorm:"type:varchar(100);not null" json:"main_category"`
	SubCategory  *string `gorm:"type:varchar(100)" json:"sub_category,omitempty"`
	BusinessName string `gorm:"type:varchar(255);not null" json:"business_name"`

	BusinessAddress  *string `gorm:"type:text" json:"business_address,omitempty"`
	CustomerAddress  *string `gorm:"type:text" json:"customer_address,omitempty"`
	ServiceProviderPhoto *string `gorm:"size:512" json:"service_provider_photo,omitempty"`
	Aadhar           *string `gorm:"size:20" json:"aadhar,omitempty"`
	// CustomServices: JSON array e.g. [{"name":"Plumbing","image_url":"/uploads/..."}]
	CustomServices datatypes.JSON `gorm:"type:jsonb;default:'[]'" json:"custom_services,omitempty"`

	Latitude  *float64 `gorm:"type:double precision" json:"latitude,omitempty"`
	Longitude *float64 `gorm:"type:double precision" json:"longitude,omitempty"`

	SecondaryContact *string `gorm:"size:20" json:"secondary_contact,omitempty"`
	Whatsapp         *string `gorm:"size:20" json:"whatsapp,omitempty"`
	Email            *string `gorm:"size:255" json:"email,omitempty"`
	Remarks          *string `gorm:"type:text" json:"remarks,omitempty"`

	SocialFacebook  *string `gorm:"size:512" json:"social_facebook,omitempty"`
	SocialWebsite   *string `gorm:"size:512" json:"social_website,omitempty"`
	SocialInstagram *string `gorm:"size:512" json:"social_instagram,omitempty"`
	SocialYoutube   *string `gorm:"size:512" json:"social_youtube,omitempty"`

	// ImagePaths: JSON array of URL paths, e.g. ["/uploads/service-registrations/12/uuid.jpg"]
	ImagePaths datatypes.JSON `gorm:"type:jsonb" json:"image_paths,omitempty"`
	// CoverImage optional denormalized first image for lists (synced when image_paths changes).
	CoverImage *string `gorm:"size:512" json:"cover_image,omitempty"`
	Approved   bool    `gorm:"not null;default:false;index" json:"approved"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

func (ServiceRegistration) TableName() string {
	return "service_registrations"
}
