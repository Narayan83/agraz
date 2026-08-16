package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// LaborWorkEntry is labourer self-accounting (receivable / receipt), separate from owner labour mgmt.
// EntryKind: receivable (default work accrual) | receipt (money received).
type LaborWorkEntry struct {
	ID              uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID          uint            `gorm:"not null;index;default:0" json:"user_id"`
	Name            string          `gorm:"type:varchar(255);not null" json:"name"`
	Wage            decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"wage"`
	Hours           decimal.Decimal `gorm:"type:numeric(10,2);not null" json:"hours"`
	NumberOfLabours int             `gorm:"not null;default:1" json:"number_of_labours"`
	Shift           string          `gorm:"type:varchar(50);not null;default:'fullday'" json:"shift"`
	Category        string          `gorm:"type:varchar(100);not null" json:"category"`
	Gender          string          `gorm:"type:varchar(20);not null;default:''" json:"gender"`
	WorkType        string          `gorm:"type:varchar(50);not null;default:''" json:"work_type"`
	Location        string          `gorm:"type:varchar(255);not null;default:''" json:"location"`
	Narration       string          `gorm:"type:text;not null;default:''" json:"narration"`
	Date            time.Time       `gorm:"not null;index" json:"date"`
	Mobile          *string         `gorm:"type:varchar(15)" json:"mobile,omitempty"`
	EntryKind       string          `gorm:"type:varchar(20);not null;default:'receivable';index" json:"entry_kind"`
	CreatedAt       time.Time       `json:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at"`
}

func (LaborWorkEntry) TableName() string {
	return "labor_work_entries"
}
