package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// CmProject is an end-to-end civil contract / site job.
type CmProject struct {
	ID           uint             `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID       uint             `gorm:"not null;index;default:0" json:"user_id"`
	CustomerID   *uint            `gorm:"index" json:"customer_id,omitempty"`
	Name         string           `gorm:"type:varchar(255);not null" json:"name"`
	Code         string           `gorm:"type:varchar(80);default:''" json:"code"`
	Location     string           `gorm:"type:varchar(255);default:''" json:"location"`
	Status       string           `gorm:"type:varchar(40);not null;default:'active'" json:"status"`
	StartDate    *time.Time       `json:"start_date,omitempty"`
	EndDate      *time.Time       `json:"end_date,omitempty"`
	EstimateAmt  decimal.Decimal  `gorm:"type:numeric(15,2);not null;default:0" json:"estimate_amt"`
	ContractAmt  decimal.Decimal  `gorm:"type:numeric(15,2);not null;default:0" json:"contract_amt"`
	CommissionPct decimal.Decimal `gorm:"type:numeric(8,2);not null;default:0" json:"commission_pct"`
	Notes        string           `gorm:"type:text;default:''" json:"notes"`
	CreatedAt    time.Time        `json:"created_at"`
	UpdatedAt    time.Time        `json:"updated_at"`
}

func (CmProject) TableName() string { return "cm_projects" }

// CmCustomer is the project client / site owner.
type CmCustomer struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index;default:0" json:"user_id"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
	Mobile    string    `gorm:"type:varchar(20);default:''" json:"mobile"`
	Address   string    `gorm:"type:text;default:''" json:"address"`
	Village   string    `gorm:"type:varchar(120);default:''" json:"village"`
	Notes     string    `gorm:"type:text;default:''" json:"notes"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (CmCustomer) TableName() string { return "cm_customers" }

// CmDealer is a material supplier (sand, cement, etc.).
type CmDealer struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index;default:0" json:"user_id"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
	Mobile    string    `gorm:"type:varchar(20);default:''" json:"mobile"`
	Address   string    `gorm:"type:text;default:''" json:"address"`
	Material  string    `gorm:"type:varchar(120);default:''" json:"material"`
	Notes     string    `gorm:"type:text;default:''" json:"notes"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (CmDealer) TableName() string { return "cm_dealers" }

// CmLabourSupplier is a labour lead / gang supplier.
type CmLabourSupplier struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index;default:0" json:"user_id"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
	Mobile    string    `gorm:"type:varchar(20);default:''" json:"mobile"`
	Address   string    `gorm:"type:text;default:''" json:"address"`
	Notes     string    `gorm:"type:text;default:''" json:"notes"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (CmLabourSupplier) TableName() string { return "cm_labour_suppliers" }

// CmLabour is a worker under a labour supplier lead.
type CmLabour struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint      `gorm:"not null;index;default:0" json:"user_id"`
	SupplierID uint      `gorm:"not null;index;default:0" json:"supplier_id"`
	Name       string    `gorm:"type:varchar(255);not null" json:"name"`
	Mobile     string    `gorm:"type:varchar(20);default:''" json:"mobile"`
	Skill      string    `gorm:"type:varchar(120);default:''" json:"skill"`
	DailyWage  decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"daily_wage"`
	Notes      string    `gorm:"type:text;default:''" json:"notes"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

func (CmLabour) TableName() string { return "cm_labours" }

// CmMaterial is a stock master (sand, cement, steel, etc.).
type CmMaterial struct {
	ID        uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint            `gorm:"not null;index;default:0" json:"user_id"`
	Name      string          `gorm:"type:varchar(255);not null" json:"name"`
	Unit      string          `gorm:"type:varchar(40);not null;default:'bag'" json:"unit"`
	Category  string          `gorm:"type:varchar(80);default:''" json:"category"`
	Notes     string          `gorm:"type:text;default:''" json:"notes"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}

func (CmMaterial) TableName() string { return "cm_materials" }

// CmPurchase is a materials purchase for a project (or own stock).
type CmPurchase struct {
	ID          uint              `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID      uint              `gorm:"not null;index;default:0" json:"user_id"`
	DealerID    *uint             `gorm:"index" json:"dealer_id,omitempty"`
	ProjectID   *uint             `gorm:"index" json:"project_id,omitempty"`
	CustomerID  *uint             `gorm:"index" json:"customer_id,omitempty"`
	PurchaseDate time.Time        `gorm:"not null;index" json:"purchase_date"`
	InvoiceNo   string            `gorm:"type:varchar(80);default:''" json:"invoice_no"`
	// StockLocation: own | customer
	StockLocation string          `gorm:"type:varchar(20);not null;default:'own'" json:"stock_location"`
	TotalAmount decimal.Decimal   `gorm:"type:numeric(15,2);not null;default:0" json:"total_amount"`
	PaidAmount  decimal.Decimal   `gorm:"type:numeric(15,2);not null;default:0" json:"paid_amount"`
	Notes       string            `gorm:"type:text;default:''" json:"notes"`
	Items       []CmPurchaseItem  `gorm:"foreignKey:PurchaseID;constraint:OnDelete:CASCADE" json:"items,omitempty"`
	CreatedAt   time.Time         `json:"created_at"`
	UpdatedAt   time.Time         `json:"updated_at"`
}

func (CmPurchase) TableName() string { return "cm_purchases" }

type CmPurchaseItem struct {
	ID         uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	PurchaseID uint            `gorm:"not null;index" json:"purchase_id"`
	MaterialID uint            `gorm:"not null;index" json:"material_id"`
	Quantity   decimal.Decimal `gorm:"type:numeric(15,3);not null;default:0" json:"quantity"`
	Rate       decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"rate"`
	Amount     decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"amount"`
	CreatedAt  time.Time       `json:"created_at"`
	UpdatedAt  time.Time       `json:"updated_at"`
}

func (CmPurchaseItem) TableName() string { return "cm_purchase_items" }

// CmStockBalance tracks material qty at contractor yard or customer site.
type CmStockBalance struct {
	ID         uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint            `gorm:"not null;index;default:0" json:"user_id"`
	MaterialID uint            `gorm:"not null;index" json:"material_id"`
	// LocationType: own | customer
	LocationType string        `gorm:"type:varchar(20);not null;default:'own';index" json:"location_type"`
	CustomerID *uint           `gorm:"index" json:"customer_id,omitempty"`
	ProjectID  *uint           `gorm:"index" json:"project_id,omitempty"`
	Quantity   decimal.Decimal `gorm:"type:numeric(15,3);not null;default:0" json:"quantity"`
	UpdatedAt  time.Time       `json:"updated_at"`
	CreatedAt  time.Time       `json:"created_at"`
}

func (CmStockBalance) TableName() string { return "cm_stock_balances" }

// CmPayment covers receivables from customers, payables to dealers/labour leads, and commission.
type CmPayment struct {
	ID         uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint            `gorm:"not null;index;default:0" json:"user_id"`
	ProjectID  *uint           `gorm:"index" json:"project_id,omitempty"`
	// Kind: receivable | payable | commission
	Kind       string          `gorm:"type:varchar(30);not null;index" json:"kind"`
	// PartyType: customer | dealer | labour_supplier
	PartyType  string          `gorm:"type:varchar(30);not null;default:''" json:"party_type"`
	PartyID    *uint           `gorm:"index" json:"party_id,omitempty"`
	PartyName  string          `gorm:"type:varchar(255);default:''" json:"party_name"`
	EntryDate  time.Time       `gorm:"not null;index" json:"entry_date"`
	DueDate    *time.Time      `json:"due_date,omitempty"`
	Amount     decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"amount"`
	PaidAmount decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"paid_amount"`
	Status     string          `gorm:"type:varchar(30);not null;default:'open'" json:"status"`
	Notes      string          `gorm:"type:text;default:''" json:"notes"`
	CreatedAt  time.Time       `json:"created_at"`
	UpdatedAt  time.Time       `json:"updated_at"`
}

func (CmPayment) TableName() string { return "cm_payments" }

// CmAsset is contractor equipment (JCB, mixer, etc.) with purchase details.
type CmAsset struct {
	ID            uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID        uint            `gorm:"not null;index;default:0" json:"user_id"`
	Name          string          `gorm:"type:varchar(255);not null" json:"name"`
	AssetType     string          `gorm:"type:varchar(80);default:''" json:"asset_type"`
	PurchaseDate  *time.Time      `json:"purchase_date,omitempty"`
	PurchaseAmt   decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"purchase_amt"`
	VendorName    string          `gorm:"type:varchar(255);default:''" json:"vendor_name"`
	SerialNo      string          `gorm:"type:varchar(120);default:''" json:"serial_no"`
	Status        string          `gorm:"type:varchar(40);not null;default:'active'" json:"status"`
	Notes         string          `gorm:"type:text;default:''" json:"notes"`
	CreatedAt     time.Time       `json:"created_at"`
	UpdatedAt     time.Time       `json:"updated_at"`
}

func (CmAsset) TableName() string { return "cm_assets" }

// CmLabourWork is daily labour deployment to a project site.
type CmLabourWork struct {
	ID         uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint            `gorm:"not null;index;default:0" json:"user_id"`
	ProjectID  uint            `gorm:"not null;index" json:"project_id"`
	SupplierID uint            `gorm:"not null;index;default:0" json:"supplier_id"`
	WorkDate   time.Time       `gorm:"not null;index" json:"work_date"`
	MenCount   int             `gorm:"not null;default:0" json:"men_count"`
	WomenCount int             `gorm:"not null;default:0" json:"women_count"`
	MenRate    decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"men_rate"`
	WomenRate  decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"women_rate"`
	// DaysWorked supports half-days (0.5).
	DaysWorked decimal.Decimal `gorm:"type:numeric(8,2);not null;default:1" json:"days_worked"`
	Amount     decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"amount"`
	PaidAmount decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"paid_amount"`
	ExtraPaid  decimal.Decimal `gorm:"type:numeric(15,2);not null;default:0" json:"extra_paid"`
	Status     string          `gorm:"type:varchar(30);not null;default:'open'" json:"status"`
	Notes      string          `gorm:"type:text;default:''" json:"notes"`
	CreatedAt  time.Time       `json:"created_at"`
	UpdatedAt  time.Time       `json:"updated_at"`
}

func (CmLabourWork) TableName() string { return "cm_labour_works" }

// CmStockIssue records stock moved/consumed for a project.
// FromLocation / Purpose:
//   own -> site_use | transfer_to_customer
//   customer -> site_use | return_to_own
type CmStockIssue struct {
	ID           uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID       uint            `gorm:"not null;index;default:0" json:"user_id"`
	ProjectID    uint            `gorm:"not null;index" json:"project_id"`
	MaterialID   uint            `gorm:"not null;index" json:"material_id"`
	CustomerID   *uint           `gorm:"index" json:"customer_id,omitempty"`
	IssueDate    time.Time       `gorm:"not null;index" json:"issue_date"`
	Quantity     decimal.Decimal `gorm:"type:numeric(15,3);not null;default:0" json:"quantity"`
	FromLocation string          `gorm:"type:varchar(20);not null;default:'own'" json:"from_location"`
	Purpose      string          `gorm:"type:varchar(40);not null;default:'site_use'" json:"purpose"`
	Notes        string          `gorm:"type:text;default:''" json:"notes"`
	CreatedAt    time.Time       `json:"created_at"`
	UpdatedAt    time.Time       `json:"updated_at"`
}

func (CmStockIssue) TableName() string { return "cm_stock_issues" }

// CmAuditLog stores create/update/delete history for contract module.
type CmAuditLog struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint      `gorm:"not null;index;default:0" json:"user_id"`
	ActorID    uint      `gorm:"not null;index;default:0" json:"actor_id"`
	EntityType string    `gorm:"type:varchar(60);not null;index" json:"entity_type"`
	EntityID   uint      `gorm:"not null;index;default:0" json:"entity_id"`
	Action     string    `gorm:"type:varchar(20);not null" json:"action"`
	Summary    string    `gorm:"type:varchar(500);default:''" json:"summary"`
	Detail     string    `gorm:"type:text;default:''" json:"detail"`
	CreatedAt  time.Time `json:"created_at"`
}

func (CmAuditLog) TableName() string { return "cm_audit_logs" }

