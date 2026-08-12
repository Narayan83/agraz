package models

import "time"

// Organization is a user-owned book (e.g. TSS, TMS).
type Organization struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index;uniqueIndex:idx_org_user_name" json:"user_id"`
	Name      string    `gorm:"type:varchar(100);not null;uniqueIndex:idx_org_user_name" json:"name"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Organization) TableName() string {
	return "organizations"
}

// OrgLedger is a chart-of-accounts entry for a user (shared across all their orgs).
type OrgLedger struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index;uniqueIndex:idx_ledger_user_name" json:"user_id"`
	Name      string    `gorm:"type:varchar(100);not null;uniqueIndex:idx_ledger_user_name" json:"name"`
	IsSystem  bool      `gorm:"not null;default:false" json:"is_system"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (OrgLedger) TableName() string {
	return "org_ledgers"
}

// OrgTransaction records income/expense/transfer against an organization + ledger.
type OrgTransaction struct {
	ID                      uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID                  uint      `gorm:"not null;index" json:"user_id"`
	OrganizationID          uint      `gorm:"not null;index" json:"organization_id"`
	LedgerID                uint      `gorm:"not null;index" json:"ledger_id"`
	Type                    string    `gorm:"type:varchar(20);not null" json:"type"` // Income | Expense
	TransactionMode         string    `gorm:"type:varchar(20);not null;default:'Cash'" json:"transaction_mode"` // Cash | Transfer
	TransferToOrganizationID *uint    `gorm:"index" json:"transfer_to_organization_id,omitempty"`
	Amount                  float64   `gorm:"type:numeric(15,2);not null" json:"amount"`
	Narration               *string   `gorm:"type:text" json:"narration,omitempty"`
	Date                    time.Time `gorm:"not null;index" json:"date"`
	LinkedIncomeExpenseID   *uint     `gorm:"index" json:"linked_income_expense_id,omitempty"`
	CounterpartTxnID        *uint     `gorm:"index" json:"counterpart_txn_id,omitempty"`
	CreatedAt               time.Time `json:"created_at"`
	UpdatedAt               time.Time `json:"updated_at"`

	Organization          *Organization `gorm:"foreignKey:OrganizationID" json:"organization,omitempty"`
	Ledger                *OrgLedger    `gorm:"foreignKey:LedgerID" json:"ledger,omitempty"`
	TransferToOrganization *Organization `gorm:"foreignKey:TransferToOrganizationID" json:"transfer_to_organization,omitempty"`
}

func (OrgTransaction) TableName() string {
	return "org_transactions"
}
