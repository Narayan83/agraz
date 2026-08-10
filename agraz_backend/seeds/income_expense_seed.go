package seeds

import (
	"fmt"
	"log"
	"time"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"github.com/shopspring/decimal"
)

const adminDemoMobile = "9999999999"
const adminDemoName = "System Admin"

// SeedIncomeExpenses adds sample income/expense rows for admin@admin.com demo party.
// Seeds only when no rows exist for the admin demo mobile (safe on restart).
func SeedIncomeExpenses() {
	ensureAdminDemoMobile()

	var count int64
	_ = initializers.DB.Model(&models.IncomeExpense{}).
		Where("mobile = ?", adminDemoMobile).
		Count(&count).Error
	if count > 0 {
		return
	}

	village := "Sirsi"
	post := "Sirsi"
	taluk := "Sirsi"
	district := "Uttara Kannada"
	pincode := "581401"

	type item struct {
		typ, cat, sub string
		amount        float64
		daysAgo       int
		narration     string
	}

	// Spread across ~6 months for monthly/weekly/trend reports (relative to today).
	items := []item{
		// --- Income ---
		{"Income", "Farming Income", "Agriculture Production", 45000, 5, "Arecanut harvest sale"},
		{"Income", "Farming Income", "Agriculture Production", 32000, 28, "Pepper sale"},
		{"Income", "Farming Income", "By-products", 8500, 35, "Husk & by-product sale"},
		{"Income", "Farming Income", "Livestock & Dairy", 12000, 42, "Milk collection"},
		{"Income", "Farming Income", "Rental / Service", 6000, 55, "Tractor rental income"},
		{"Income", "Non-Farming Income", "Government / Subsidy", 15000, 70, "Crop insurance claim"},
		{"Income", "Farming Income", "Agriculture Production", 38000, 95, "Coffee cherry sale"},
		{"Income", "Farming Income", "Livestock & Dairy", 9500, 110, "Dairy fortnight"},
		{"Income", "Non-Farming Income", "Asset & Miscellaneous", 5000, 130, "Scrap sale"},
		{"Income", "Farming Income", "Agriculture Production", 41000, 150, "Banana bunch sale"},
		{"Income", "Farming Income", "Rental / Service", 4500, 165, "Sprayer hire"},

		// --- Farming Expense ---
		{"Expense", "Farming Expense", "Labour", 8500, 3, "Harvest labour"},
		{"Expense", "Farming Expense", "Manure", 4200, 12, "Organic manure"},
		{"Expense", "Farming Expense", "Chemicals", 3100, 18, "Fungicide spray"},
		{"Expense", "Farming Expense", "Machinery Rent", 2500, 22, "Tiller rent"},
		{"Expense", "Farming Expense", "Irrigation", 1800, 40, "Drip maintenance"},
		{"Expense", "Farming Expense", "Cattle Feed", 3600, 48, "Cattle feed bags"},
		{"Expense", "Farming Expense", "Vet Medicines and Care", 1200, 60, "Vet visit"},
		{"Expense", "Farming Expense", "Labour", 7200, 85, "Weeding labour"},
		{"Expense", "Farming Expense", "Implements", 4500, 100, "Sickle & tools"},
		{"Expense", "Farming Expense", "Vehicle Rent", 2000, 120, "Tempo for market"},
		{"Expense", "Farming Expense", "Special Works", 15000, 140, "Pond desilting"},

		// --- Living Expense ---
		{"Expense", "Living Expense", "Grocery", 4500, 2, "Monthly grocery"},
		{"Expense", "Living Expense", "Fruits & Veg", 1200, 7, "Weekly vegetables"},
		{"Expense", "Living Expense", "Milk & Ghee", 800, 8, "Milk & ghee"},
		{"Expense", "Living Expense", "Electricity", 2100, 15, "BESCOM bill"},
		{"Expense", "Living Expense", "Gas", 1100, 20, "LPG refill"},
		{"Expense", "Living Expense", "Education", 5000, 25, "School fees"},
		{"Expense", "Living Expense", "Medicine", 950, 33, "Pharmacy"},
		{"Expense", "Living Expense", "Mobile & Currency", 499, 38, "Mobile recharge"},
		{"Expense", "Living Expense", "Transportation Expense", 1500, 50, "Bus & fuel"},
		{"Expense", "Living Expense", "Pooja", 700, 65, "Temple offerings"},
		{"Expense", "Living Expense", "Grocery", 4800, 80, "Monthly grocery"},
		{"Expense", "Living Expense", "Entertainment", 600, 90, "Family outing"},
		{"Expense", "Living Expense", "Repair", 3200, 105, "Home plumbing"},
		{"Expense", "Living Expense", "Tour & Travel", 8500, 125, "Pilgrimage trip"},
		{"Expense", "Living Expense", "Lifestyle", 2200, 145, "Clothes"},
		{"Expense", "Living Expense", "Electricity", 1950, 155, "BESCOM bill"},
	}

	now := time.Now()
	rows := make([]models.IncomeExpense, 0, len(items))
	for _, it := range items {
		d := now.AddDate(0, 0, -it.daysAgo)
		// Normalize to noon local to avoid timezone edge issues
		d = time.Date(d.Year(), d.Month(), d.Day(), 12, 0, 0, 0, time.Local)
		narr := it.narration
		rows = append(rows, models.IncomeExpense{
			Type:        it.typ,
			Category:    it.cat,
			SubCategory: it.sub,
			Amount:      decimal.NewFromFloat(it.amount),
			Narration:   &narr,
			Mobile:      adminDemoMobile,
			Date:        d,
			Name:        adminDemoName,
			Village:     &village,
			Post:        &post,
			Taluk:       &taluk,
			District:    &district,
			Pincode:     &pincode,
		})
	}

	if err := initializers.DB.CreateInBatches(rows, 50).Error; err != nil {
		log.Printf("income/expense seed failed: %v", err)
		return
	}
	fmt.Printf("Seeded %d income/expense demo rows for admin@admin.com (mobile %s)\n", len(rows), adminDemoMobile)
}

func ensureAdminDemoMobile() {
	var user models.User
	if err := initializers.DB.Where("email = ?", "admin@admin.com").First(&user).Error; err != nil {
		return
	}
	if user.MobileNumber == nil || *user.MobileNumber == "" {
		m := adminDemoMobile
		_ = initializers.DB.Model(&user).Update("mobile_number", m).Error
		fmt.Printf("Linked admin@admin.com mobile to %s\n", adminDemoMobile)
	}
}
