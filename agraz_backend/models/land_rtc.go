package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// LandRtc stores Karnataka RTC / land-record entries per user.
type LandRtc struct {
	ID           uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID       uint            `gorm:"not null;index;default:0" json:"user_id"`
	State        string          `gorm:"type:varchar(100);not null;default:'Karnataka'" json:"state"`
	District     string          `gorm:"type:varchar(100);not null;default:'Uttara Kannada'" json:"district"`
	Taluk        string          `gorm:"type:varchar(100);not null;default:''" json:"taluk"`
	Hobli        string          `gorm:"type:varchar(100);not null;default:''" json:"hobli"`
	SurveyNumber string          `gorm:"type:varchar(100);not null;default:''" json:"survey_number"`
	Hissa        string          `gorm:"type:varchar(50);not null;default:''" json:"hissa"`
	Acre         int             `gorm:"not null;default:0" json:"acre"`
	Gunta        int             `gorm:"not null;default:0" json:"gunta"`
	Ana          int             `gorm:"not null;default:0" json:"ana"`
	TotalAcres   decimal.Decimal `gorm:"type:numeric(14,6);not null;default:0" json:"total_acres"`
	Details      string          `gorm:"type:text;not null;default:''" json:"details"`
	DocumentURL  string          `gorm:"type:varchar(500);not null;default:''" json:"document_url"`
	CreatedAt    time.Time       `json:"created_at"`
	UpdatedAt    time.Time       `json:"updated_at"`

	// Populated for admin list only (not a DB column).
	UserName  string `gorm:"-" json:"user_name,omitempty"`
	UserPhone string `gorm:"-" json:"user_phone,omitempty"`
}

func (LandRtc) TableName() string {
	return "land_rtcs"
}

// ComputeTotalAcres: 40 gunta = 1 acre, 4 ana = 1 gunta → acres = acre + gunta/40 + ana/160.
func ComputeTotalAcres(acre, gunta, ana int) decimal.Decimal {
	a := decimal.NewFromInt(int64(acre))
	g := decimal.NewFromInt(int64(gunta)).Div(decimal.NewFromInt(40))
	n := decimal.NewFromInt(int64(ana)).Div(decimal.NewFromInt(160))
	return a.Add(g).Add(n).Round(6)
}
