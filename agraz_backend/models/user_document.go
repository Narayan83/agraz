package models

import (
	"time"

	"gorm.io/datatypes"
)

// DocumentFolder groups personal papers (Aadhaar, PAN, etc.) by person or topic.
type DocumentFolder struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index" json:"user_id"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	// DocumentCount is filled by handlers; not a DB column.
	DocumentCount int `gorm:"-" json:"document_count"`
}

func (DocumentFolder) TableName() string {
	return "document_folders"
}

// UserDocument is a named paper with one or more scanned images.
// FolderID is nil when the document sits at the account root.
type UserDocument struct {
	ID        uint           `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`
	FolderID  *uint          `gorm:"index" json:"folder_id,omitempty"`
	Name      string         `gorm:"type:varchar(255);not null" json:"name"`
	Images    datatypes.JSON `gorm:"type:jsonb;not null;default:'[]'" json:"images"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
}

func (UserDocument) TableName() string {
	return "user_documents"
}
