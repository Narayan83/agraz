package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// IncomeExpense maps to public.income_expenses (type must be Income or Expense per DB check).
type IncomeExpense struct {
	ID          uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	Type        string          `gorm:"type:varchar(20);not null" json:"type"`
	Category    string          `gorm:"type:varchar(100);not null" json:"category"`
	SubCategory string          `gorm:"type:varchar(100);not null" json:"sub_category"`
	Amount      decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"amount"`
	Narration   *string         `gorm:"type:text" json:"narration,omitempty"`
	Mobile      string          `gorm:"type:varchar(15);not null" json:"mobile"`
	Date        time.Time       `gorm:"not null" json:"date"`
	Name        string          `gorm:"type:varchar(255);not null" json:"name"`
	Village     *string         `gorm:"type:varchar(255)" json:"village,omitempty"`
	Post        *string         `gorm:"type:varchar(100)" json:"post,omitempty"`
	Taluk       *string         `gorm:"type:varchar(100)" json:"taluk,omitempty"`
	District    *string         `gorm:"type:varchar(100)" json:"district,omitempty"`
	ExtraAddr   *string         `gorm:"column:extra_address;type:text" json:"extra_address,omitempty"`
	Pincode     *string    `gorm:"type:varchar(20)" json:"pincode,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

func (IncomeExpense) TableName() string {
	return "income_expenses"
}
