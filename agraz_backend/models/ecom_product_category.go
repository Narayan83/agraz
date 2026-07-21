package models

import (
	"time"

	"gorm.io/gorm"
)

type EcomProductCategory struct {
	ID uint `json:"id" gorm:"primaryKey"`

	ProductID     uint  `json:"product_id" gorm:"not null;index;uniqueIndex:uk_prod_cat_sub"`
	CategoryID    uint  `json:"category_id" gorm:"not null;index;uniqueIndex:uk_prod_cat_sub"`
	SubCategoryID *uint `json:"sub_category_id,omitempty" gorm:"index;uniqueIndex:uk_prod_cat_sub"`

	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`

	CreatedAt time.Time `json:"created_at" gorm:"default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updated_at" gorm:"default:CURRENT_TIMESTAMP"`

	Category    *EcomCategory    `json:"category,omitempty" gorm:"foreignKey:CategoryID"`
	SubCategory *EcomSubCategory `json:"sub_category,omitempty" gorm:"foreignKey:SubCategoryID"`
}

func (EcomProductCategory) TableName() string {
	return "product_categories"
}

