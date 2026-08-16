package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// LaborExtra stores rent/food/bonus amounts linked to a labour work entry.
type LaborExtra struct {
	ID        uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint            `gorm:"not null;index;default:0" json:"user_id"`
	LaborID   uint            `gorm:"not null;uniqueIndex;index" json:"labor_id"`
	Rent      decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"rent"`
	Food      decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"food"`
	Bonus     decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"bonus"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}

func (LaborExtra) TableName() string {
	return "labor_extras"
}

// OthersSum returns rent + food + bonus.
func (e LaborExtra) OthersSum() decimal.Decimal {
	return e.Rent.Add(e.Food).Add(e.Bonus)
}
