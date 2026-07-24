package models

import "time"

// GovDepartment is a government department (e.g. Horticulture).
type GovDepartment struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID  uint      `gorm:"not null;default:1;index" json:"tenant_id"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
	Slug      string    `gorm:"type:varchar(255);not null;index" json:"slug"`
	Status    string    `gorm:"type:varchar(20);not null;default:active" json:"status"`
	SortOrder int       `gorm:"not null;default:0" json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (GovDepartment) TableName() string { return "gov_departments" }

// GovCrop is a crop filter for government facilities.
type GovCrop struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID  uint      `gorm:"not null;default:1;index" json:"tenant_id"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
	Slug      string    `gorm:"type:varchar(255);not null;index" json:"slug"`
	Status    string    `gorm:"type:varchar(20);not null;default:active" json:"status"`
	SortOrder int       `gorm:"not null;default:0" json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (GovCrop) TableName() string { return "gov_crops" }

// GovFacility is one scheme/facility (loan, insurance, or grant) under department + crop.
// Multiple rows may share the same department/crop/category (e.g. multiple loans).
type GovFacility struct {
	ID              uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID        uint       `gorm:"not null;default:1;index" json:"tenant_id"`
	DepartmentID    uint       `gorm:"not null;index" json:"department_id"`
	CropID          uint       `gorm:"not null;index" json:"crop_id"`
	Category        string     `gorm:"type:varchar(50);not null;index" json:"category"` // loans | insurance | grants
	Title           string     `gorm:"type:varchar(255);not null" json:"title"`
	Description     string     `gorm:"type:text;not null;default:''" json:"description"`
	Place           string     `gorm:"type:varchar(255);not null;default:''" json:"place"`
	ContactPerson   string     `gorm:"type:varchar(255);not null;default:''" json:"contact_person"`
	Email           string     `gorm:"type:varchar(255);not null;default:''" json:"email"`
	Website         string     `gorm:"type:varchar(512);not null;default:''" json:"website"`
	Phone           string     `gorm:"type:varchar(50);not null;default:''" json:"phone"`
	ApplicationURL  string     `gorm:"type:varchar(512);not null;default:''" json:"application_url"`
	ValidFrom       *time.Time `json:"valid_from,omitempty"`
	ValidTo         *time.Time `json:"valid_to,omitempty"`
	Notes           string     `gorm:"type:text;not null;default:''" json:"notes"`
	Status          string     `gorm:"type:varchar(20);not null;default:active" json:"status"`
	SortOrder       int        `gorm:"not null;default:0" json:"sort_order"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`

	Department *GovDepartment `gorm:"foreignKey:DepartmentID" json:"department,omitempty"`
	Crop       *GovCrop       `gorm:"foreignKey:CropID" json:"crop,omitempty"`
}

func (GovFacility) TableName() string { return "gov_facilities" }
