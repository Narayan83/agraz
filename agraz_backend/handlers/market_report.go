package handler

import (
	"strconv"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var marketDB *gorm.DB

func SetMarketDB(db *gorm.DB) {
	marketDB = db
}

func parseMarketDate(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, fiber.NewError(400, "date is required")
	}
	layouts := []string{
		"2006-01-02",
		time.RFC3339,
		"02-01-2006",
		"2006-01-02T15:04:05Z07:00",
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			y, m, d := t.Date()
			return time.Date(y, m, d, 0, 0, 0, 0, time.UTC), nil
		}
	}
	return time.Time{}, fiber.NewError(400, "invalid date (use YYYY-MM-DD or DD-MM-YYYY)")
}

func parseDecimalField(v interface{}, field string) (decimal.Decimal, error) {
	switch x := v.(type) {
	case nil:
		return decimal.Zero, fiber.NewError(400, field+" is required")
	case float64:
		return decimal.NewFromFloat(x), nil
	case float32:
		return decimal.NewFromFloat32(x), nil
	case int:
		return decimal.NewFromInt(int64(x)), nil
	case int64:
		return decimal.NewFromInt(x), nil
	case string:
		s := strings.TrimSpace(x)
		if s == "" {
			return decimal.Zero, fiber.NewError(400, field+" is required")
		}
		d, err := decimal.NewFromString(s)
		if err != nil {
			return decimal.Zero, fiber.NewError(400, "invalid "+field)
		}
		return d, nil
	default:
		return decimal.Zero, fiber.NewError(400, "invalid "+field)
	}
}

func parseUintFromMap(m map[string]interface{}, key string) (uint, error) {
	v, ok := m[key]
	if !ok || v == nil {
		return 0, fiber.NewError(400, key+" is required")
	}
	switch x := v.(type) {
	case float64:
		if x <= 0 {
			return 0, fiber.NewError(400, key+" is required")
		}
		return uint(x), nil
	case int:
		if x <= 0 {
			return 0, fiber.NewError(400, key+" is required")
		}
		return uint(x), nil
	case string:
		n, err := strconv.ParseUint(strings.TrimSpace(x), 10, 64)
		if err != nil || n == 0 {
			return 0, fiber.NewError(400, "invalid "+key)
		}
		return uint(n), nil
	default:
		return 0, fiber.NewError(400, "invalid "+key)
	}
}

func safeString(m map[string]interface{}, key string) string {
	v, ok := m[key]
	if !ok || v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return strings.TrimSpace(s)
	}
	return ""
}

func applyMarketFilters(q *gorm.DB, c *fiber.Ctx) *gorm.DB {
	if v := c.Query("agent_id"); v != "" {
		q = q.Where("agent_id = ?", v)
	}
	if v := c.Query("apmc_id"); v != "" {
		q = q.Where("apmc_id = ?", v)
	}
	if v := c.Query("variety_id"); v != "" {
		q = q.Where("variety_id = ?", v)
	}
	if v := strings.TrimSpace(c.Query("taluk")); v != "" {
		q = q.Where("taluk ILIKE ?", v)
	}
	if v := strings.TrimSpace(c.Query("date")); v != "" {
		if d, err := parseMarketDate(v); err == nil {
			q = q.Where("date = ?", d)
		}
	}
	if v := strings.TrimSpace(c.Query("from")); v != "" {
		if d, err := parseMarketDate(v); err == nil {
			q = q.Where("date >= ?", d)
		}
	}
	if v := strings.TrimSpace(c.Query("to")); v != "" {
		if d, err := parseMarketDate(v); err == nil {
			q = q.Where("date <= ?", d)
		}
	}
	return q
}

func paginate(c *fiber.Ctx) (page, limit, offset int) {
	page = 1
	limit = 50
	if v, err := strconv.Atoi(c.Query("page", "1")); err == nil && v > 0 {
		page = v
	}
	if v, err := strconv.Atoi(c.Query("limit", "50")); err == nil && v > 0 {
		limit = v
		if limit > 500 {
			limit = 500
		}
	}
	offset = (page - 1) * limit
	return
}

func preloadMarketRefs(q *gorm.DB) *gorm.DB {
	return q.Preload("Variety").Preload("Agent").Preload("APMC")
}

// ---------- Public lookups ----------

func GetMarketAgentsPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var rows []models.MarketAgent
	if err := marketDB.Where("tenant_id = ? AND status = ?", tid, "active").
		Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.MarketAgent{}})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func GetMarketAPMCsPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	q := marketDB.Where("tenant_id = ? AND status = ?", tid, "active")
	if v := strings.TrimSpace(c.Query("taluk")); v != "" {
		q = q.Where("taluk ILIKE ?", v)
	}
	var rows []models.MarketAPMC
	if err := q.Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.MarketAPMC{}})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func GetMarketVarietiesPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var rows []models.MarketVariety
	if err := marketDB.Where("tenant_id = ? AND status = ?", tid, "active").
		Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.MarketVariety{}})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func GetMarketTaluksPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	type row struct {
		Taluk string `json:"taluk"`
	}
	var rows []row
	_ = marketDB.Model(&models.MarketAPMC{}).
		Select("DISTINCT taluk").
		Where("tenant_id = ? AND status = ? AND taluk <> ''", tid, "active").
		Order("taluk ASC").
		Scan(&rows).Error
	out := make([]string, 0, len(rows))
	for _, r := range rows {
		if strings.TrimSpace(r.Taluk) != "" {
			out = append(out, r.Taluk)
		}
	}
	return c.JSON(fiber.Map{"data": out})
}

func GetMarketDailyPricesPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	page, limit, offset := paginate(c)
	q := marketDB.Model(&models.MarketDailyPrice{}).Where("tenant_id = ?", tid)
	q = applyMarketFilters(q, c)
	var total int64
	_ = q.Count(&total).Error
	var rows []models.MarketDailyPrice
	if err := preloadMarketRefs(q).Order("date DESC, id DESC").Offset(offset).Limit(limit).Find(&rows).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.MarketDailyPrice{}, "total": 0, "page": page, "limit": limit})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetMarketLotsPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	page, limit, offset := paginate(c)
	q := marketDB.Model(&models.MarketLot{}).Where("tenant_id = ?", tid)
	q = applyMarketFilters(q, c)
	if v := strings.TrimSpace(c.Query("lot_no")); v != "" {
		q = q.Where("lot_no ILIKE ?", "%"+v+"%")
	}
	if v := strings.TrimSpace(c.Query("purchaser")); v != "" {
		q = q.Where("purchaser ILIKE ?", "%"+v+"%")
	}
	var total int64
	_ = q.Count(&total).Error
	var rows []models.MarketLot
	if err := preloadMarketRefs(q).Order("date DESC, id DESC").Offset(offset).Limit(limit).Find(&rows).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.MarketLot{}, "total": 0, "page": page, "limit": limit})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetMarketQuantitiesPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	page, limit, offset := paginate(c)
	q := marketDB.Model(&models.MarketQuantity{}).Where("tenant_id = ?", tid)
	q = applyMarketFilters(q, c)
	var total int64
	_ = q.Count(&total).Error
	var rows []models.MarketQuantity
	if err := preloadMarketRefs(q).Order("date DESC, id DESC").Offset(offset).Limit(limit).Find(&rows).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.MarketQuantity{}, "total": 0, "page": page, "limit": limit})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetMarketAnalyticsPublic(c *fiber.Ctx) error {
	return marketAnalytics(c, true)
}

func GetMarketAnalyticsAdmin(c *fiber.Ctx) error {
	return marketAnalytics(c, false)
}

func marketAnalytics(c *fiber.Ctx, _ bool) error {
	tid := tenantIDFromCtx(c)
	q := marketDB.Model(&models.MarketDailyPrice{}).Where("tenant_id = ?", tid)
	q = applyMarketFilters(q, c)

	var prices []models.MarketDailyPrice
	if err := preloadMarketRefs(q).Order("date ASC").Find(&prices).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	qq := marketDB.Model(&models.MarketQuantity{}).Where("tenant_id = ?", tid)
	qq = applyMarketFilters(qq, c)
	var qtys []models.MarketQuantity
	_ = preloadMarketRefs(qq).Order("date ASC").Find(&qtys).Error

	type pricePoint struct {
		Date      string  `json:"date"`
		Variety   string  `json:"variety"`
		Agent     string  `json:"agent"`
		APMC      string  `json:"apmc"`
		Taluk     string  `json:"taluk"`
		Min       float64 `json:"min"`
		Max       float64 `json:"max"`
		Avg       float64 `json:"avg"`
		VarietyID uint    `json:"variety_id"`
		AgentID   uint    `json:"agent_id"`
		APMCID    uint    `json:"apmc_id"`
	}
	series := make([]pricePoint, 0, len(prices))
	for _, p := range prices {
		vName, aName, apName := "", "", ""
		if p.Variety != nil {
			vName = p.Variety.Name
		}
		if p.Agent != nil {
			aName = p.Agent.Name
		}
		if p.APMC != nil {
			apName = p.APMC.Name
		}
		minF, _ := p.MinPrice.Float64()
		maxF, _ := p.MaxPrice.Float64()
		avgF, _ := p.AvgPrice.Float64()
		series = append(series, pricePoint{
			Date: p.Date.Format("2006-01-02"), Variety: vName, Agent: aName, APMC: apName, Taluk: p.Taluk,
			Min: minF, Max: maxF, Avg: avgF, VarietyID: p.VarietyID, AgentID: p.AgentID, APMCID: p.APMCID,
		})
	}

	type qtyPoint struct {
		Date     string  `json:"date"`
		Variety  string  `json:"variety"`
		Agent    string  `json:"agent"`
		APMC     string  `json:"apmc"`
		Taluk    string  `json:"taluk"`
		Arrival  float64 `json:"arrival"`
		Trade    float64 `json:"trade"`
		Stock    float64 `json:"stock"`
	}
	qtySeries := make([]qtyPoint, 0, len(qtys))
	for _, row := range qtys {
		vName, aName, apName := "", "", ""
		if row.Variety != nil {
			vName = row.Variety.Name
		}
		if row.Agent != nil {
			aName = row.Agent.Name
		}
		if row.APMC != nil {
			apName = row.APMC.Name
		}
		a, _ := row.ArrivalQty.Float64()
		t, _ := row.TradeQty.Float64()
		s, _ := row.StockQty.Float64()
		qtySeries = append(qtySeries, qtyPoint{
			Date: row.Date.Format("2006-01-02"), Variety: vName, Agent: aName, APMC: apName, Taluk: row.Taluk,
			Arrival: a, Trade: t, Stock: s,
		})
	}

	return c.JSON(fiber.Map{
		"price_series": series,
		"qty_series":   qtySeries,
	})
}

// ---------- Admin masters ----------

type marketNamedPayload struct {
	Name      string `json:"name"`
	Code      string `json:"code"`
	Taluk     string `json:"taluk"`
	District  string `json:"district"`
	Status    string `json:"status"`
	SortOrder int    `json:"sort_order"`
}

func AdminListMarketAgents(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var rows []models.MarketAgent
	if err := marketDB.Where("tenant_id = ?", tid).Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func AdminCreateMarketAgent(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var body marketNamedPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	code := strings.TrimSpace(body.Code)
	if code == "" {
		code = strings.ToUpper(name)
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "active"
	}
	row := models.MarketAgent{TenantID: tid, Name: name, Code: code, Status: status, SortOrder: body.SortOrder}
	if err := marketDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateMarketAgent(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var row models.MarketAgent
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body marketNamedPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	if n := strings.TrimSpace(body.Code); n != "" {
		row.Code = n
	}
	if n := strings.TrimSpace(body.Status); n != "" {
		row.Status = n
	}
	row.SortOrder = body.SortOrder
	if err := marketDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteMarketAgent(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.MarketAgent{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func AdminListMarketAPMCs(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var rows []models.MarketAPMC
	if err := marketDB.Where("tenant_id = ?", tid).Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func AdminCreateMarketAPMC(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var body marketNamedPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "active"
	}
	taluk := strings.TrimSpace(body.Taluk)
	if taluk == "" {
		taluk = name
	}
	row := models.MarketAPMC{
		TenantID: tid, Name: name, Taluk: taluk, District: strings.TrimSpace(body.District),
		Status: status, SortOrder: body.SortOrder,
	}
	if err := marketDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateMarketAPMC(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var row models.MarketAPMC
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body marketNamedPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	if n := strings.TrimSpace(body.Taluk); n != "" {
		row.Taluk = n
	}
	row.District = strings.TrimSpace(body.District)
	if n := strings.TrimSpace(body.Status); n != "" {
		row.Status = n
	}
	row.SortOrder = body.SortOrder
	if err := marketDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteMarketAPMC(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.MarketAPMC{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func AdminListMarketVarieties(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var rows []models.MarketVariety
	if err := marketDB.Where("tenant_id = ?", tid).Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func AdminCreateMarketVariety(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var body marketNamedPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "active"
	}
	row := models.MarketVariety{TenantID: tid, Name: name, Status: status, SortOrder: body.SortOrder}
	if err := marketDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateMarketVariety(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var row models.MarketVariety
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body marketNamedPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	if n := strings.TrimSpace(body.Status); n != "" {
		row.Status = n
	}
	row.SortOrder = body.SortOrder
	if err := marketDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteMarketVariety(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.MarketVariety{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

// ---------- Admin daily prices ----------

func AdminListMarketDailyPrices(c *fiber.Ctx) error {
	return GetMarketDailyPricesPublic(c)
}

func AdminCreateMarketDailyPrice(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var raw map[string]interface{}
	if err := c.BodyParser(&raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	row, err := parseDailyPricePayload(tid, raw)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := marketDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = preloadMarketRefs(marketDB).First(&row, row.ID)
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateMarketDailyPrice(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var existing models.MarketDailyPrice
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).First(&existing).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var raw map[string]interface{}
	if err := c.BodyParser(&raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	row, err := parseDailyPricePayload(tid, raw)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	existing.Date = row.Date
	existing.VarietyID = row.VarietyID
	existing.AgentID = row.AgentID
	existing.APMCID = row.APMCID
	existing.Taluk = row.Taluk
	existing.MinPrice = row.MinPrice
	existing.MaxPrice = row.MaxPrice
	existing.AvgPrice = row.AvgPrice
	existing.Notes = row.Notes
	if err := marketDB.Save(&existing).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = preloadMarketRefs(marketDB).First(&existing, existing.ID)
	return c.JSON(fiber.Map{"data": existing})
}

func AdminDeleteMarketDailyPrice(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.MarketDailyPrice{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func parseDailyPricePayload(tid uint, raw map[string]interface{}) (models.MarketDailyPrice, error) {
	var row models.MarketDailyPrice
	row.TenantID = tid
	dateStr := safeString(raw, "date")
	d, err := parseMarketDate(dateStr)
	if err != nil {
		return row, err
	}
	row.Date = d
	vid, err := parseUintFromMap(raw, "variety_id")
	if err != nil {
		return row, err
	}
	aid, err := parseUintFromMap(raw, "agent_id")
	if err != nil {
		return row, err
	}
	apid, err := parseUintFromMap(raw, "apmc_id")
	if err != nil {
		return row, err
	}
	row.VarietyID, row.AgentID, row.APMCID = vid, aid, apid
	row.Taluk = safeString(raw, "taluk")
	if row.Taluk == "" {
		var apmc models.MarketAPMC
		if marketDB.First(&apmc, apid).Error == nil {
			row.Taluk = apmc.Taluk
		}
	}
	minP, err := parseDecimalField(raw["min_price"], "min_price")
	if err != nil {
		return row, err
	}
	maxP, err := parseDecimalField(raw["max_price"], "max_price")
	if err != nil {
		return row, err
	}
	avgP, err := parseDecimalField(raw["avg_price"], "avg_price")
	if err != nil {
		// auto average if missing
		avgP = minP.Add(maxP).Div(decimal.NewFromInt(2))
	}
	row.MinPrice, row.MaxPrice, row.AvgPrice = minP, maxP, avgP
	row.Notes = safeString(raw, "notes")
	return row, nil
}

// ---------- Admin lots ----------

func AdminListMarketLots(c *fiber.Ctx) error {
	return GetMarketLotsPublic(c)
}

func AdminCreateMarketLot(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var raw map[string]interface{}
	if err := c.BodyParser(&raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	row, err := parseLotPayload(tid, raw)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := marketDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = preloadMarketRefs(marketDB).First(&row, row.ID)
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateMarketLot(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var existing models.MarketLot
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).First(&existing).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var raw map[string]interface{}
	if err := c.BodyParser(&raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	row, err := parseLotPayload(tid, raw)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	existing.Date = row.Date
	existing.LotNo = row.LotNo
	existing.Price = row.Price
	existing.Quantity = row.Quantity
	existing.Purchaser = row.Purchaser
	existing.VarietyID = row.VarietyID
	existing.AgentID = row.AgentID
	existing.APMCID = row.APMCID
	existing.Taluk = row.Taluk
	existing.Notes = row.Notes
	if err := marketDB.Save(&existing).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = preloadMarketRefs(marketDB).First(&existing, existing.ID)
	return c.JSON(fiber.Map{"data": existing})
}

func AdminDeleteMarketLot(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.MarketLot{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func parseLotPayload(tid uint, raw map[string]interface{}) (models.MarketLot, error) {
	var row models.MarketLot
	row.TenantID = tid
	d, err := parseMarketDate(safeString(raw, "date"))
	if err != nil {
		return row, err
	}
	row.Date = d
	row.LotNo = safeString(raw, "lot_no")
	if row.LotNo == "" {
		return row, fiber.NewError(400, "lot_no is required")
	}
	price, err := parseDecimalField(raw["price"], "price")
	if err != nil {
		return row, err
	}
	qty, err := parseDecimalField(raw["quantity"], "quantity")
	if err != nil {
		return row, err
	}
	row.Price, row.Quantity = price, qty
	row.Purchaser = safeString(raw, "purchaser")
	vid, err := parseUintFromMap(raw, "variety_id")
	if err != nil {
		return row, err
	}
	aid, err := parseUintFromMap(raw, "agent_id")
	if err != nil {
		return row, err
	}
	apid, err := parseUintFromMap(raw, "apmc_id")
	if err != nil {
		return row, err
	}
	row.VarietyID, row.AgentID, row.APMCID = vid, aid, apid
	row.Taluk = safeString(raw, "taluk")
	if row.Taluk == "" {
		var apmc models.MarketAPMC
		if marketDB.First(&apmc, apid).Error == nil {
			row.Taluk = apmc.Taluk
		}
	}
	row.Notes = safeString(raw, "notes")
	return row, nil
}

// ---------- Admin quantities ----------

func AdminListMarketQuantities(c *fiber.Ctx) error {
	return GetMarketQuantitiesPublic(c)
}

func AdminCreateMarketQuantity(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var raw map[string]interface{}
	if err := c.BodyParser(&raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	row, err := parseQtyPayload(tid, raw)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := marketDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = preloadMarketRefs(marketDB).First(&row, row.ID)
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateMarketQuantity(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var existing models.MarketQuantity
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).First(&existing).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var raw map[string]interface{}
	if err := c.BodyParser(&raw); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	row, err := parseQtyPayload(tid, raw)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	existing.Date = row.Date
	existing.VarietyID = row.VarietyID
	existing.AgentID = row.AgentID
	existing.APMCID = row.APMCID
	existing.Taluk = row.Taluk
	existing.ArrivalQty = row.ArrivalQty
	existing.TradeQty = row.TradeQty
	existing.StockQty = row.StockQty
	existing.Notes = row.Notes
	if err := marketDB.Save(&existing).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = preloadMarketRefs(marketDB).First(&existing, existing.ID)
	return c.JSON(fiber.Map{"data": existing})
}

func AdminDeleteMarketQuantity(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	if err := marketDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.MarketQuantity{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func parseQtyPayload(tid uint, raw map[string]interface{}) (models.MarketQuantity, error) {
	var row models.MarketQuantity
	row.TenantID = tid
	d, err := parseMarketDate(safeString(raw, "date"))
	if err != nil {
		return row, err
	}
	row.Date = d
	vid, err := parseUintFromMap(raw, "variety_id")
	if err != nil {
		return row, err
	}
	aid, err := parseUintFromMap(raw, "agent_id")
	if err != nil {
		return row, err
	}
	apid, err := parseUintFromMap(raw, "apmc_id")
	if err != nil {
		return row, err
	}
	row.VarietyID, row.AgentID, row.APMCID = vid, aid, apid
	row.Taluk = safeString(raw, "taluk")
	if row.Taluk == "" {
		var apmc models.MarketAPMC
		if marketDB.First(&apmc, apid).Error == nil {
			row.Taluk = apmc.Taluk
		}
	}
	arrival := decimal.Zero
	trade := decimal.Zero
	stock := decimal.Zero
	if raw["arrival_qty"] != nil {
		if a, e := parseDecimalField(raw["arrival_qty"], "arrival_qty"); e == nil {
			arrival = a
		}
	}
	if raw["trade_qty"] != nil {
		if a, e := parseDecimalField(raw["trade_qty"], "trade_qty"); e == nil {
			trade = a
		}
	}
	if raw["stock_qty"] != nil {
		if a, e := parseDecimalField(raw["stock_qty"], "stock_qty"); e == nil {
			stock = a
		}
	}
	row.ArrivalQty, row.TradeQty, row.StockQty = arrival, trade, stock
	row.Notes = safeString(raw, "notes")
	return row, nil
}
