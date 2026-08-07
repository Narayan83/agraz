package seeds

import (
	"fmt"
	"log"
	"time"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"github.com/shopspring/decimal"
)

// SeedMarketReports seeds masters + actual arecanut daily prices from Aug 2026 sheet.
// Masters are upserted; transactional rows are seeded only when the prices table is empty
// (so admin CRUD data is not wiped on every restart).
func SeedMarketReports() {
	const tenantID = uint(1)

	agents := []models.MarketAgent{
		{TenantID: tenantID, Name: "TSS", Code: "TSS", Status: "active", SortOrder: 1},
		{TenantID: tenantID, Name: "TMS", Code: "TMS", Status: "active", SortOrder: 2},
		{TenantID: tenantID, Name: "TUMCOS", Code: "TUMCOS", Status: "active", SortOrder: 3},
	}
	for _, a := range agents {
		var existing models.MarketAgent
		if err := initializers.DB.Where("tenant_id = ? AND code = ?", tenantID, a.Code).First(&existing).Error; err != nil {
			if err := initializers.DB.Create(&a).Error; err != nil {
				log.Printf("market seed agent %s: %v", a.Code, err)
			}
		} else {
			_ = initializers.DB.Model(&existing).Updates(map[string]interface{}{
				"name": a.Name, "status": "active", "sort_order": a.SortOrder,
			}).Error
		}
	}

	apmcs := []models.MarketAPMC{
		{TenantID: tenantID, Name: "Sirsi", Taluk: "Sirsi", District: "Uttara Kannada", Status: "active", SortOrder: 1},
		{TenantID: tenantID, Name: "Siddapur", Taluk: "Siddapur", District: "Uttara Kannada", Status: "active", SortOrder: 2},
		{TenantID: tenantID, Name: "Tumkur", Taluk: "Tumkur", District: "Tumakuru", Status: "active", SortOrder: 3},
	}
	for _, a := range apmcs {
		var existing models.MarketAPMC
		if err := initializers.DB.Where("tenant_id = ? AND name = ?", tenantID, a.Name).First(&existing).Error; err != nil {
			if err := initializers.DB.Create(&a).Error; err != nil {
				log.Printf("market seed apmc %s: %v", a.Name, err)
			}
		} else {
			_ = initializers.DB.Model(&existing).Updates(map[string]interface{}{
				"taluk": a.Taluk, "district": a.District, "status": "active", "sort_order": a.SortOrder,
			}).Error
		}
	}

	varieties := []models.MarketVariety{
		{TenantID: tenantID, Name: "Rashi", Status: "active", SortOrder: 1},
		{TenantID: tenantID, Name: "Chali", Status: "active", SortOrder: 2},
		{TenantID: tenantID, Name: "Pepper", Status: "active", SortOrder: 3},
	}
	for _, v := range varieties {
		var existing models.MarketVariety
		if err := initializers.DB.Where("tenant_id = ? AND name = ?", tenantID, v.Name).First(&existing).Error; err != nil {
			if err := initializers.DB.Create(&v).Error; err != nil {
				log.Printf("market seed variety %s: %v", v.Name, err)
			}
		} else {
			_ = initializers.DB.Model(&existing).Updates(map[string]interface{}{
				"status": "active", "sort_order": v.SortOrder,
			}).Error
		}
	}

	SeedMarketReportMenu()

	var priceCount int64
	_ = initializers.DB.Model(&models.MarketDailyPrice{}).Where("tenant_id = ?", tenantID).Count(&priceCount).Error
	if priceCount > 0 {
		return
	}

	var agentTSS models.MarketAgent
	var apmcSirsi models.MarketAPMC
	var vRashi, vChali, vPepper models.MarketVariety
	_ = initializers.DB.Where("tenant_id = ? AND code = ?", tenantID, "TSS").First(&agentTSS).Error
	_ = initializers.DB.Where("tenant_id = ? AND name = ?", tenantID, "Sirsi").First(&apmcSirsi).Error
	_ = initializers.DB.Where("tenant_id = ? AND name = ?", tenantID, "Rashi").First(&vRashi).Error
	_ = initializers.DB.Where("tenant_id = ? AND name = ?", tenantID, "Chali").First(&vChali).Error
	_ = initializers.DB.Where("tenant_id = ? AND name = ?", tenantID, "Pepper").First(&vPepper).Error

	if agentTSS.ID == 0 || apmcSirsi.ID == 0 || vRashi.ID == 0 {
		log.Printf("market seed: missing masters, skip prices")
		return
	}

	// Actual sheet rows (Aug 2026) — Agent TSS / Sirsi APMC.
	type priceRow struct {
		day, month, year int
		varietyID        uint
		min, max, avg    int64
	}
	rows := []priceRow{
		{1, 8, 2026, vRashi.ID, 50850, 51999, 51420},
		{1, 8, 2026, vChali.ID, 43200, 45850, 44510},
		{1, 8, 2026, vPepper.ID, 61200, 63800, 62500},
		{2, 8, 2026, vRashi.ID, 51020, 52150, 51610},
		{2, 8, 2026, vChali.ID, 43450, 46100, 44740},
		{2, 8, 2026, vPepper.ID, 61500, 64100, 62800},
		{3, 8, 2026, vRashi.ID, 51200, 52300, 51780},
		{3, 8, 2026, vChali.ID, 43600, 46250, 44900},
		{3, 8, 2026, vPepper.ID, 61800, 64400, 63100},
		{4, 8, 2026, vRashi.ID, 51350, 52420, 51910},
		{4, 8, 2026, vChali.ID, 43800, 46400, 45080},
		{4, 8, 2026, vPepper.ID, 62000, 64650, 63320},
		{5, 8, 2026, vRashi.ID, 51500, 52500, 52040},
		{5, 8, 2026, vChali.ID, 43950, 46550, 45220},
		{5, 8, 2026, vPepper.ID, 62250, 64800, 63500},
		{6, 8, 2026, vRashi.ID, 51699, 52599, 52219},
		{6, 8, 2026, vChali.ID, 44100, 46700, 45380},
		{6, 8, 2026, vPepper.ID, 62500, 65100, 63800},
	}

	for _, r := range rows {
		d := time.Date(r.year, time.Month(r.month), r.day, 0, 0, 0, 0, time.UTC)
		p := models.MarketDailyPrice{
			TenantID:  tenantID,
			Date:      d,
			VarietyID: r.varietyID,
			AgentID:   agentTSS.ID,
			APMCID:    apmcSirsi.ID,
			Taluk:     "Sirsi",
			MinPrice:  decimal.NewFromInt(r.min),
			MaxPrice:  decimal.NewFromInt(r.max),
			AvgPrice:  decimal.NewFromInt(r.avg),
		}
		if err := initializers.DB.Create(&p).Error; err != nil {
			log.Printf("market seed price: %v", err)
		}
	}

	d6 := time.Date(2026, 8, 6, 0, 0, 0, 0, time.UTC)
	lots := []models.MarketLot{
		{TenantID: tenantID, Date: d6, LotNo: "L-101", Price: decimal.NewFromInt(52200), Quantity: decimal.NewFromInt(12), Purchaser: "Local Trader", VarietyID: vRashi.ID, AgentID: agentTSS.ID, APMCID: apmcSirsi.ID, Taluk: "Sirsi"},
		{TenantID: tenantID, Date: d6, LotNo: "L-102", Price: decimal.NewFromInt(45400), Quantity: decimal.NewFromInt(8), Purchaser: "Wholesale Buyer", VarietyID: vChali.ID, AgentID: agentTSS.ID, APMCID: apmcSirsi.ID, Taluk: "Sirsi"},
		{TenantID: tenantID, Date: d6, LotNo: "L-103", Price: decimal.NewFromInt(63800), Quantity: decimal.NewFromInt(5), Purchaser: "Spice Merchant", VarietyID: vPepper.ID, AgentID: agentTSS.ID, APMCID: apmcSirsi.ID, Taluk: "Sirsi"},
	}
	for _, l := range lots {
		_ = initializers.DB.Create(&l).Error
	}

	qtys := []models.MarketQuantity{
		{TenantID: tenantID, Date: d6, VarietyID: vRashi.ID, AgentID: agentTSS.ID, APMCID: apmcSirsi.ID, Taluk: "Sirsi", ArrivalQty: decimal.NewFromInt(120), TradeQty: decimal.NewFromInt(95), StockQty: decimal.NewFromInt(25)},
		{TenantID: tenantID, Date: d6, VarietyID: vChali.ID, AgentID: agentTSS.ID, APMCID: apmcSirsi.ID, Taluk: "Sirsi", ArrivalQty: decimal.NewFromInt(80), TradeQty: decimal.NewFromInt(70), StockQty: decimal.NewFromInt(10)},
		{TenantID: tenantID, Date: d6, VarietyID: vPepper.ID, AgentID: agentTSS.ID, APMCID: apmcSirsi.ID, Taluk: "Sirsi", ArrivalQty: decimal.NewFromInt(40), TradeQty: decimal.NewFromInt(35), StockQty: decimal.NewFromInt(5)},
	}
	for _, q := range qtys {
		_ = initializers.DB.Create(&q).Error
	}

	fmt.Println("Seeded market reports (agents, APMCs, varieties, daily prices)")
}

// SeedMarketReportMenu adds Market Reports to the admin sidebar.
func SeedMarketReportMenu() {
	var existing models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", "Market Reports", "/market-reports").First(&existing).Error; err == nil {
		_ = initializers.DB.Model(&existing).Updates(map[string]interface{}{
			"icon": "BarChart3", "is_active": true, "sort_order": 3,
		}).Error
		return
	}
	m := models.Menu{
		MenuName:  "Market Reports",
		URL:       "/market-reports",
		Icon:      "BarChart3",
		SortOrder: 3,
		IsActive:  true,
		MenuType:  "main",
	}
	if err := initializers.DB.Create(&m).Error; err != nil {
		log.Printf("market menu seed: %v", err)
		return
	}
	fmt.Println("Seeded menu: Market Reports")
}
