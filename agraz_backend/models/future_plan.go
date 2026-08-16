package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// FuturePlan is a planning document with multiple description/estimate lines.
type FuturePlan struct {
	ID           uint              `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID       uint              `gorm:"not null;index;default:0" json:"user_id"`
	PlanName     string            `gorm:"type:varchar(255);not null" json:"plan_name"`
	EntryDate    time.Time         `gorm:"not null;index" json:"entry_date"`
	PlanYear     int               `gorm:"not null;default:0" json:"plan_year"`
	PlanMonth    int               `gorm:"not null;default:0" json:"plan_month"`
	LineCount    int               `gorm:"not null;default:1" json:"line_count"`
	Status       string            `gorm:"type:varchar(50);not null;default:'planned'" json:"status"`
	EndDate      *time.Time        `json:"end_date,omitempty"`
	ActualCost   *decimal.Decimal  `gorm:"type:numeric(15,2)" json:"actual_cost,omitempty"`
	Lines        []FuturePlanLine  `gorm:"foreignKey:PlanID;constraint:OnDelete:CASCADE" json:"lines,omitempty"`
	CreatedAt    time.Time         `json:"created_at"`
	UpdatedAt    time.Time         `json:"updated_at"`
}

func (FuturePlan) TableName() string {
	return "future_plans"
}

// FuturePlanLine is one description + estimated cost row under a plan.
type FuturePlanLine struct {
	ID           uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	PlanID       uint            `gorm:"not null;index" json:"plan_id"`
	LineNo       int             `gorm:"not null;default:1" json:"line_no"`
	Description  string          `gorm:"type:text;not null;default:''" json:"description"`
	EstimateCost decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"estimate_cost"`
	CreatedAt    time.Time       `json:"created_at"`
	UpdatedAt    time.Time       `json:"updated_at"`
}

func (FuturePlanLine) TableName() string {
	return "future_plan_lines"
}
