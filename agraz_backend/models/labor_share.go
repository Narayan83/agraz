package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// LaborShare is a reverse copy of a farmer labour entry, offered to the
// labourer (matched by mobile) for confirmation before it posts to their
// Labour Work books.
//
// Status: pending | accepted | rejected
type LaborShare struct {
	ID            uint   `gorm:"primaryKey;autoIncrement" json:"id"`
	SourceLaborID uint   `gorm:"not null;uniqueIndex;index" json:"source_labor_id"`
	SourceUserID  uint   `gorm:"not null;index" json:"source_user_id"`
	TargetUserID  uint   `gorm:"not null;index" json:"target_user_id"`
	Status        string `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`
	LaborWorkID   *uint  `gorm:"index" json:"labor_work_id,omitempty"`

	// Snapshot the labourer will confirm (farmer as counterparty).
	Name            string          `gorm:"type:varchar(255);not null" json:"name"`
	Mobile          *string         `gorm:"type:varchar(15)" json:"mobile,omitempty"`
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
	EntryKind       string          `gorm:"type:varchar(20);not null;default:'receivable'" json:"entry_kind"`
	Rent            decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"rent"`
	Food            decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"food"`
	Bonus           decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"bonus"`
	// Name the farmer typed for the labourer (shown on the confirm card).
	RecordedAs string `gorm:"type:varchar(255);not null;default:''" json:"recorded_as"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (LaborShare) TableName() string {
	return "labor_shares"
}
