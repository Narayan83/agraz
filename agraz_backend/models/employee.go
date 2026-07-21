package models

type Employee struct {
	ID       uint    `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID   uint    `gorm:"not null;index" json:"user_id"`
	EmpCode  *string `gorm:"type:text" json:"emp_code,omitempty"`
	Position *string `gorm:"column:position;type:text" json:"position,omitempty"`

	User *User `gorm:"foreignKey:UserID;references:ID" json:"user,omitempty"`
}

func (Employee) TableName() string {
	return "employees"
}
