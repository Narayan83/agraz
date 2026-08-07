package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// MarketAgent is a commission agent / agency (TSS, TMS, TUMCOS).
type MarketAgent struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID  uint      `gorm:"not null;default:1;index" json:"tenant_id"`
	Name      string    `gorm:"type:varchar(100);not null" json:"name"`
	Code      string    `gorm:"type:varchar(50);not null;index" json:"code"`
	Status    string    `gorm:"type:varchar(20);not null;default:active" json:"status"`
	SortOrder int       `gorm:"not null;default:0" json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (MarketAgent) TableName() string { return "market_agents" }

// MarketAPMC is an Agricultural Produce Market Committee yard.
type MarketAPMC struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID  uint      `gorm:"not null;default:1;index" json:"tenant_id"`
	Name      string    `gorm:"type:varchar(100);not null" json:"name"`
	Taluk     string    `gorm:"type:varchar(100);not null;default:'';index" json:"taluk"`
	District  string    `gorm:"type:varchar(100);not null;default:''" json:"district"`
	Status    string    `gorm:"type:varchar(20);not null;default:active" json:"status"`
	SortOrder int       `gorm:"not null;default:0" json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (MarketAPMC) TableName() string { return "market_apmcs" }

// MarketVariety is an item / variety (Rashi, Chali, Pepper).
type MarketVariety struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID  uint      `gorm:"not null;default:1;index" json:"tenant_id"`
	Name      string    `gorm:"type:varchar(100);not null" json:"name"`
	Status    string    `gorm:"type:varchar(20);not null;default:active" json:"status"`
	SortOrder int       `gorm:"not null;default:0" json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (MarketVariety) TableName() string { return "market_varieties" }

// MarketDailyPrice is the daily min/max/average rate for a variety at an APMC/agent.
type MarketDailyPrice struct {
	ID        uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID  uint            `gorm:"not null;default:1;index" json:"tenant_id"`
	Date      time.Time       `gorm:"type:date;not null;index" json:"date"`
	VarietyID uint            `gorm:"not null;index" json:"variety_id"`
	AgentID   uint            `gorm:"not null;index" json:"agent_id"`
	APMCID    uint            `gorm:"not null;index" json:"apmc_id"`
	Taluk     string          `gorm:"type:varchar(100);not null;default:'';index" json:"taluk"`
	MinPrice  decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"min_price"`
	MaxPrice  decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"max_price"`
	AvgPrice  decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"avg_price"`
	Notes     string          `gorm:"type:text;not null;default:''" json:"notes"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`

	Variety *MarketVariety `gorm:"foreignKey:VarietyID" json:"variety,omitempty"`
	Agent   *MarketAgent   `gorm:"foreignKey:AgentID" json:"agent,omitempty"`
	APMC    *MarketAPMC    `gorm:"foreignKey:APMCID" json:"apmc,omitempty"`
}

func (MarketDailyPrice) TableName() string { return "market_daily_prices" }

// MarketLot is an individual lot sale entry.
type MarketLot struct {
	ID         uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID   uint            `gorm:"not null;default:1;index" json:"tenant_id"`
	Date       time.Time       `gorm:"type:date;not null;index" json:"date"`
	LotNo      string          `gorm:"type:varchar(100);not null;index" json:"lot_no"`
	Price      decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"price"`
	Quantity   decimal.Decimal `gorm:"type:numeric(15,3);not null" json:"quantity"`
	Purchaser  string          `gorm:"type:varchar(255);not null;default:''" json:"purchaser"`
	VarietyID  uint            `gorm:"not null;index" json:"variety_id"`
	AgentID    uint            `gorm:"not null;index" json:"agent_id"`
	APMCID     uint            `gorm:"not null;index" json:"apmc_id"`
	Taluk      string          `gorm:"type:varchar(100);not null;default:'';index" json:"taluk"`
	Notes      string          `gorm:"type:text;not null;default:''" json:"notes"`
	CreatedAt  time.Time       `json:"created_at"`
	UpdatedAt  time.Time       `json:"updated_at"`

	Variety *MarketVariety `gorm:"foreignKey:VarietyID" json:"variety,omitempty"`
	Agent   *MarketAgent   `gorm:"foreignKey:AgentID" json:"agent,omitempty"`
	APMC    *MarketAPMC    `gorm:"foreignKey:APMCID" json:"apmc,omitempty"`
}

func (MarketLot) TableName() string { return "market_lots" }

// MarketQuantity tracks arrival, trade, and stock quantities for a day.
type MarketQuantity struct {
	ID          uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID    uint            `gorm:"not null;default:1;index" json:"tenant_id"`
	Date        time.Time       `gorm:"type:date;not null;index" json:"date"`
	VarietyID   uint            `gorm:"not null;index" json:"variety_id"`
	AgentID     uint            `gorm:"not null;index" json:"agent_id"`
	APMCID      uint            `gorm:"not null;index" json:"apmc_id"`
	Taluk       string          `gorm:"type:varchar(100);not null;default:'';index" json:"taluk"`
	ArrivalQty  decimal.Decimal `gorm:"type:numeric(15,3);not null;default:0" json:"arrival_qty"`
	TradeQty    decimal.Decimal `gorm:"type:numeric(15,3);not null;default:0" json:"trade_qty"`
	StockQty    decimal.Decimal `gorm:"type:numeric(15,3);not null;default:0" json:"stock_qty"`
	Notes       string          `gorm:"type:text;not null;default:''" json:"notes"`
	CreatedAt   time.Time       `json:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at"`

	Variety *MarketVariety `gorm:"foreignKey:VarietyID" json:"variety,omitempty"`
	Agent   *MarketAgent   `gorm:"foreignKey:AgentID" json:"agent,omitempty"`
	APMC    *MarketAPMC    `gorm:"foreignKey:APMCID" json:"apmc,omitempty"`
}

func (MarketQuantity) TableName() string { return "market_quantities" }
