package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// DairyCustomer is a dairy owner's customer directory (farmers who supply or buy milk).
type DairyCustomer struct {
	ID          uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID      uint            `gorm:"not null;index" json:"user_id"`
	Name        string          `gorm:"type:varchar(255);not null" json:"name"`
	Mobile      string          `gorm:"type:varchar(20);not null;default:'';index" json:"mobile"`
	Village     string          `gorm:"type:varchar(255);not null;default:''" json:"village"`
	DefaultRate decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"default_rate"`
	Notes       string          `gorm:"type:text;not null;default:''" json:"notes"`
	CreatedAt   time.Time       `json:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at"`
}

func (DairyCustomer) TableName() string {
	return "dairy_customers"
}

// DairyEntry is a milk or payment row on the recorder's books.
//
// Kind (recorder's perspective):
//   milk_given        — recorder supplied milk (receivable)
//   milk_bought       — recorder purchased milk (payable)
//   payment_received  — recorder received money
//   payment_made      — recorder paid money
//
// Origin:
//   farmer — entered by the farmer on their own dairy page
//   dairy  — entered by a dairy owner (or admin on their behalf)
//
// Farmers see dairy-origin rows whose party_mobile matches their account,
// so they never re-enter milk the dairy already recorded.
type DairyEntry struct {
	ID             uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID         uint            `gorm:"not null;index" json:"user_id"`
	Origin         string          `gorm:"type:varchar(20);not null;default:'farmer';index" json:"origin"`
	Kind           string          `gorm:"type:varchar(30);not null;index" json:"kind"`
	PartyName      string          `gorm:"type:varchar(255);not null" json:"party_name"`
	PartyMobile    string          `gorm:"type:varchar(20);not null;default:'';index" json:"party_mobile"`
	CustomerID     *uint           `gorm:"index" json:"customer_id,omitempty"`
	Date           time.Time       `gorm:"not null;index" json:"date"`
	Shift          string          `gorm:"type:varchar(20);not null;default:''" json:"shift"`
	QuantityLiters decimal.Decimal `gorm:"type:numeric(12,3);not null;default:0" json:"quantity_liters"`
	RatePerLiter   decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"rate_per_liter"`
	Amount         decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"amount"`
	FatPercent     decimal.Decimal `gorm:"type:numeric(6,2);not null;default:0" json:"fat_percent"`
	Narration      string          `gorm:"type:text;not null;default:''" json:"narration"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

func (DairyEntry) TableName() string {
	return "dairy_entries"
}
