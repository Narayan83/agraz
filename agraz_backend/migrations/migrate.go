package main

import (
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
)

func init() {
	initializers.LoadEnviromentVariables()
	initializers.ConnectToDb()
}

func main() {
	log.Println("Starting RBAC migration...")

	err := initializers.DB.AutoMigrate(
		&models.Tenant{},
		&models.User{},
		&models.Role{},
		&models.Menu{},
		&models.RoleManagement{},
		&models.UserRoleMapping{},
		&models.UserHierarchy{},
		&models.Employee{},
		&models.IncomeExpense{},
		&models.Labor{},
		&models.LaborRate{},
		&models.LaborExtra{},
		&models.DiaryLabel{},
		&models.DiaryEntry{},
		&models.FuturePlan{},
		&models.FuturePlanLine{},
		&models.LaborWorkEntry{},
		&models.AppFeedback{},
		&models.AppContent{},
		&models.ServiceRegistration{},
		&models.Vendor{},
		// E-commerce catalog
		&models.EcomCategory{},
		&models.EcomSubCategory{},
		&models.EcomProduct{},
		&models.EcomProductCategory{},
		&models.VendorProductMapping{},
		&models.EcomColor{},
		&models.EcomVariant{},
		&models.EcomProductImage{},
		&models.EcomStockMovement{},
		// Cart
		&models.EcomCart{},
		&models.EcomCartItem{},
		&models.StorefrontBannerSlide{},
		&models.GovDepartment{},
		&models.GovCrop{},
		&models.GovFacility{},
	)

	if err != nil {
		log.Fatal("Migration failed:", err)
	}

	log.Println("RBAC migration completed successfully.")
}
