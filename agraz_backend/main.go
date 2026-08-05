package main

import (
	"fmt"
	"log"
	"os"

	handler "erp.local/backend/handlers"
	"erp.local/backend/initializers"
	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"erp.local/backend/seeds"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
)

func init() {

	initializers.LoadEnviromentVariables()
	initializers.ConnectToDb()
	// Ensure e-commerce tables exist on startup.
	// This project uses AutoMigrate only in a separate migration entrypoint today,
	// so we keep e-commerce initialization self-contained for the shopping cart feature.
	_ = initializers.DB.AutoMigrate(
		&models.Tenant{},
		&models.User{},
		&models.UserRoleMapping{},
		&models.ServiceRegistration{},
		&models.Vendor{},
		&models.Labor{},
		&models.EcomCategory{},
		&models.EcomSubCategory{},
		&models.EcomProduct{},
		&models.EcomProductCategory{},
		&models.VendorProductMapping{},
		&models.EcomColor{},
		&models.EcomVariant{},
		&models.EcomProductImage{},
		&models.EcomStockMovement{},
		&models.EcomCart{},
		&models.EcomCartItem{},
		&models.StorefrontBannerSlide{},
		&models.GovDepartment{},
		&models.GovCrop{},
		&models.GovFacility{},
	)
	seeds.SeedAll()
}

// func welcome(c *fiber.Ctx) error {
// 	return c.SendString("Welcome to app")
// }

func main() {
	fmt.Println("Hello welcome, main is runnings")

	// Set DB in handlers
	handler.SetUserDB(initializers.DB)
	handler.SetRolesDB(initializers.DB)
	handler.SetRolesManagementDB(initializers.DB)
	handler.SetMenusDB(initializers.DB)
	handler.SetUserRoleMappingDB(initializers.DB)
	handler.SetEmployeeDB(initializers.DB)
	handler.SetIncomeExpenseDB(initializers.DB)
	handler.SetLaborDB(initializers.DB)
	handler.SetServiceRegistrationDB(initializers.DB)
	handler.SetEcomDB(initializers.DB)
	handler.SetVendorDB(initializers.DB)
	handler.SetStorefrontBannerDB(initializers.DB)
	handler.SetGovDB(initializers.DB)

	// set up fiber (large body limit for multi-image uploads)
	app := fiber.New(fiber.Config{
		BodyLimit: 64 * 1024 * 1024,
	})

	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowMethods: "GET,POST,PUT,PATCH,DELETE,OPTIONS,HEAD",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization, X-Tenant-ID",
	}))

	app.Static("/uploads", "./uploads")

	api := app.Group("/api")
	api.Use(middleware.TenantResolver(initializers.DB))

	// Public Routes
	api.Get("/tenant/config", handler.GetTenantConfig)
	api.Post("/login", handler.Login)
	api.Post("/login/", handler.Login)

	// Agraz / Flutter mobile (public JSON API; same DB as admin)
	api.Post("/mobile/register", handler.MobileRegisterUser)
	api.Get("/mobile/users/by-phone/:phone", handler.GetUserByMobilePublic)
	api.Post("/register-business", handler.RegisterBusinessPublic)
	api.Get("/services", handler.ListApprovedServicesPublic)
	api.Get("/income_expense/summary", handler.GetIncomeExpenseSummaryPublic)
	api.Get("/income_expense/mobile/:mobile", handler.GetIncomeExpensesByMobilePublic)
	api.Get("/income_expense", handler.GetIncomeExpenses)
	api.Get("/income_expense/:id", handler.GetIncomeExpense)
	api.Post("/income_expense", handler.CreateIncomeExpenseMobile)
	api.Put("/income_expense/:id", handler.UpdateIncomeExpense)
	api.Delete("/income_expense/:id", handler.DeleteIncomeExpense)

	// Labor management (public JSON API for Flutter app)
	api.Get("/labors", handler.GetLabors)
	api.Post("/labors/batch", handler.CreateLaborsBatch)
	api.Post("/labors", handler.CreateLabor)
	api.Get("/labors/:id", handler.GetLabor)
	api.Put("/labors/:id", handler.UpdateLabor)
	api.Delete("/labors/:id", handler.DeleteLabor)

	// Public storefront catalog (no JWT; same data admin manages)
	api.Get("/store/categories", handler.GetStoreCategories)
	api.Get("/store/sub-categories", handler.GetStoreSubCategories)
	api.Get("/store/colors", handler.GetStoreColors)
	api.Get("/store/products", handler.GetStoreProducts)
	api.Get("/store/products/:id", handler.GetStoreProductByID)
	api.Get("/store/vendors", handler.GetStoreVendors)
	api.Get("/store/banners", handler.GetStoreBannersPublic)

	// Government facilities (public browse for Flutter)
	api.Get("/gov/departments", handler.GetGovDepartments)
	api.Get("/gov/crops", handler.GetGovCrops)
	api.Get("/gov/categories", handler.GetGovCategories)
	api.Get("/gov/facilities", handler.GetGovFacilities)
	api.Get("/gov/facilities/:id", handler.GetGovFacility)

	// Use Middleware
	api.Use(middleware.Protected())

	// Authenticated Routes
	api.Get("/me", handler.GetMe)
	api.Get("/my-menus", handler.GetCurrentUserMenuTree)
	api.Get("/dashboard/stats", handler.GetDashboardStats)

	// Users
	api.Get("/vendor-users", handler.GetVendorUsers)
	api.Post("/users", handler.CreateUser)
	api.Get("/users", handler.GetUsers)
	api.Get("/users/:id", handler.GetUser)
	api.Put("/users/:id", handler.UpdateUser)
	api.Delete("/users/:id", handler.DeleteUser)
	api.Put("/users/restore/:id", handler.RestoreUser)
	api.Delete("/users/force/:id", handler.ForceDeleteUser)
	api.Post("/users/import", handler.ImportUsers)

	// Menus
	api.Get("/loadMenus", handler.GetAllMenus)
	api.Get("/menus/tree", handler.GetMenuTree)
	api.Get("/menus/:id", handler.GetMenuByID)
	api.Post("/menus", handler.CreateMenu)
	api.Put("/menus/:id", handler.UpdateMenu)
	api.Delete("/menus/:id", handler.DeleteMenu)
	api.Patch("/menus/reorder", handler.ReorderMenus)

	// Roles
	api.Get("/roles", handler.GetAllRoles)
	api.Get("/roles/:id", handler.GetRoleByID)
	api.Post("/roles", handler.CreateRole)
	api.Put("/roles/:id", handler.UpdateRole)
	api.Delete("/roles/:id", handler.DeleteRole)

	// Role permissions
	api.Get("/roles/:id/permissions", handler.GetRolePermissions)
	api.Get("/roles/:id/permissions/menu-tree", handler.GetRoleMenuTreeWithPermissions)
	api.Put("/roles/:id/permissions", handler.UpdateRolePermissions)
	api.Delete("/roles/:id/permissions", handler.ResetRolePermissions)

	// User-Role mapping
	api.Get("/user/:user_id", handler.GetUserRoles)
	api.Post("/user/:user_id/role/:role_id", handler.AssignRoleToUser)
	api.Delete("/user/:user_id/role/:role_id", handler.RemoveRoleFromUser)
	api.Get("/role/:role_id/users", handler.GetUsersByRole)
	api.Put("/user/:user_id", handler.UpdateUserRoles)

	// Employees
	api.Get("/employees", handler.GetEmployees)
	api.Get("/employees/:id", handler.GetEmployee)
	api.Post("/employees", handler.CreateEmployee)
	api.Put("/employees/:id", handler.UpdateEmployee)
	api.Delete("/employees/:id", handler.DeleteEmployee)

	// Income & expenses
	api.Get("/income-expenses", handler.GetIncomeExpenses)
	api.Get("/income-expenses/:id", handler.GetIncomeExpense)
	api.Post("/income-expenses", handler.CreateIncomeExpense)
	api.Put("/income-expenses/:id", handler.UpdateIncomeExpense)
	api.Delete("/income-expenses/:id", handler.DeleteIncomeExpense)

	// Service registrations (static paths before :id)
	api.Get("/service-registrations", handler.GetServiceRegistrations)
	api.Post("/service-registrations/images", handler.UploadServiceRegistrationImages)
	api.Post("/service-registrations/:id/provider-photo", handler.UploadServiceProviderPhoto)
	api.Post("/service-registrations/:id/custom-service-image", handler.UploadCustomServiceImage)
	api.Get("/service-registrations/:id", handler.GetServiceRegistration)
	api.Post("/service-registrations", handler.CreateServiceRegistration)
	api.Put("/service-registrations/:id", handler.UpdateServiceRegistration)
	api.Delete("/service-registrations/:id/images", handler.RemoveServiceRegistrationImage)
	api.Delete("/service-registrations/:id", handler.DeleteServiceRegistration)

	// Vendors (static paths before :id)
	api.Get("/vendor-product-mappings", handler.GetVendorProductMappings)
	api.Post("/vendor-product-mappings", handler.CreateVendorProductMapping)
	api.Put("/vendor-product-mappings/:id", handler.UpdateVendorProductMapping)
	api.Delete("/vendor-product-mappings/:id", handler.DeleteVendorProductMapping)

	api.Get("/vendors", handler.GetVendors)
	api.Post("/vendors", handler.CreateVendor)
	api.Put("/vendors/:id/product-mappings", handler.ReplaceVendorProductMappings)
	api.Get("/vendors/:id", handler.GetVendor)
	api.Put("/vendors/:id", handler.UpdateVendor)
	api.Delete("/vendors/:id", handler.DeleteVendor)

	// Store cart (requires login — storefront uses local cart)
	api.Get("/store/cart", handler.GetStoreCart)
	api.Post("/store/cart/items", handler.AddStoreCartItem)
	api.Put("/store/cart/items/:variant_id", handler.UpdateStoreCartItem)
	api.Delete("/store/cart/items/:variant_id", handler.DeleteStoreCartItem)

	// Admin e-commerce (catalog management)
	api.Get("/admin/ecom/categories", handler.AdminGetCategories)
	api.Get("/admin/ecom/categories/:id", handler.AdminGetCategory)
	api.Post("/admin/ecom/categories", handler.AdminCreateCategory)
	api.Put("/admin/ecom/categories/:id", handler.AdminUpdateCategory)
	api.Delete("/admin/ecom/categories/:id", handler.AdminDeleteCategory)

	api.Get("/admin/ecom/sub-categories", handler.AdminGetSubCategories)
	api.Get("/admin/ecom/sub-categories/:id", handler.AdminGetSubCategory)
	api.Post("/admin/ecom/sub-categories", handler.AdminCreateSubCategory)
	api.Put("/admin/ecom/sub-categories/:id", handler.AdminUpdateSubCategory)
	api.Delete("/admin/ecom/sub-categories/:id", handler.AdminDeleteSubCategory)

	api.Get("/admin/ecom/colors", handler.AdminGetColors)
	api.Get("/admin/ecom/colors/:id", handler.AdminGetColor)
	api.Post("/admin/ecom/colors", handler.AdminCreateColor)
	api.Put("/admin/ecom/colors/:id", handler.AdminUpdateColor)
	api.Delete("/admin/ecom/colors/:id", handler.AdminDeleteColor)

	api.Get("/admin/ecom/products", handler.AdminGetProducts)
	api.Get("/admin/ecom/products/:id", handler.AdminGetProduct)
	api.Post("/admin/ecom/products", handler.AdminCreateProduct)
	api.Put("/admin/ecom/products/:id", handler.AdminUpdateProduct)
	api.Delete("/admin/ecom/products/:id", handler.AdminDeleteProduct)

	// Admin e-commerce image upload (expects already-cropped image)
	api.Post("/admin/ecom/images/upload", handler.UploadAdminEcomImage)

	api.Get("/admin/storefront/banners", handler.AdminListStorefrontBanners)
	api.Post("/admin/storefront/banners", handler.AdminCreateStorefrontBanner)
	api.Put("/admin/storefront/banners/reorder", handler.AdminReorderStorefrontBanners)
	api.Put("/admin/storefront/banners/:id", handler.AdminUpdateStorefrontBanner)
	api.Delete("/admin/storefront/banners/:id", handler.AdminDeleteStorefrontBanner)

	// Admin government facilities
	api.Get("/admin/gov/departments", handler.AdminGetGovDepartments)
	api.Post("/admin/gov/departments", handler.AdminCreateGovDepartment)
	api.Put("/admin/gov/departments/:id", handler.AdminUpdateGovDepartment)
	api.Delete("/admin/gov/departments/:id", handler.AdminDeleteGovDepartment)

	api.Get("/admin/gov/crops", handler.AdminGetGovCrops)
	api.Post("/admin/gov/crops", handler.AdminCreateGovCrop)
	api.Put("/admin/gov/crops/:id", handler.AdminUpdateGovCrop)
	api.Delete("/admin/gov/crops/:id", handler.AdminDeleteGovCrop)

	api.Get("/admin/gov/facilities", handler.AdminGetGovFacilities)
	api.Get("/admin/gov/facilities/:id", handler.AdminGetGovFacility)
	api.Post("/admin/gov/facilities", handler.AdminCreateGovFacility)
	api.Put("/admin/gov/facilities/:id", handler.AdminUpdateGovFacility)
	api.Delete("/admin/gov/facilities/:id", handler.AdminDeleteGovFacility)
	api.Post("/admin/gov/facilities/upload", handler.UploadGovFacilityApplication)

	// start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}
	addr := fmt.Sprintf(":%s", port)
	log.Printf("Listening on %s", addr)
	log.Fatal(app.Listen(addr))
}
