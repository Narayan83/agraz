package models

import "time"

type UserHierarchy struct {
	ID           uint   `gorm:"primaryKey"`
	ParentID     uint   `json:"parent_id"`
	ChildID      uint   `json:"child_id"`
	RelationType string `json:"relation_type"` // e.g., "Distributor-Dealer", "Dealer-Customer"
	CreatedAt    time.Time
}
