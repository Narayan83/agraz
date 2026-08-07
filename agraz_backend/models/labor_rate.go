package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// LaborRate stores a fixed wage rate per labourer (mobile) and work category.
type LaborRate struct {
	ID        uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	Mobile    string          `gorm:"type:varchar(15);not null;uniqueIndex:idx_labor_rate_mobile_cat" json:"mobile"`
	Name      string          `gorm:"type:varchar(255);not null;default:''" json:"name"`
	Category  string          `gorm:"type:varchar(100);not null;uniqueIndex:idx_labor_rate_mobile_cat" json:"category"`
	Rate      decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"rate"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}

func (LaborRate) TableName() string {
	return "labor_rates"
}
