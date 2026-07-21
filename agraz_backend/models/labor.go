package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// Labor maps to public.labors — daily labour entries from the Agraz mobile app.
type Labor struct {
	ID              uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	Name            string          `gorm:"type:varchar(255);not null" json:"name"`
	Wage            decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"wage"`
	Hours           decimal.Decimal `gorm:"type:numeric(10,2);not null" json:"hours"`
	NumberOfLabours int             `gorm:"not null;default:1" json:"number_of_labours"`
	Shift           string          `gorm:"type:varchar(50);not null" json:"shift"`
	Category        string          `gorm:"type:varchar(100);not null" json:"category"`
	Narration       string          `gorm:"type:text;not null" json:"narration"`
	Date            time.Time       `gorm:"not null" json:"date"`
	Mobile          *string         `gorm:"type:varchar(15)" json:"mobile,omitempty"`
	CreatedAt       time.Time       `json:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at"`
}

func (Labor) TableName() string {
	return "labors"
}
