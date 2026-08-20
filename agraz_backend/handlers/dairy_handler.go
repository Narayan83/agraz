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

var dairyDB *gorm.DB

func SetDairyDB(db *gorm.DB) {
	dairyDB = db
}

const (
	dairyKindGiven     = "milk_given"
	dairyKindBought    = "milk_bought"
	dairyKindPayRecv   = "payment_received"
	dairyKindPayMade   = "payment_made"
	dairyOriginFarmer  = "farmer"
	dairyOriginDairy   = "dairy"
	dairyShiftMorning  = "morning"
	dairyShiftEvening  = "evening"
)

type dairyEntryBody struct {
	UserID         uint            `json:"user_id"`
	OwnerUserID    uint            `json:"owner_user_id"`
	Kind           string          `json:"kind"`
	OwnerKind      string          `json:"owner_kind"`
	PartyName      string          `json:"party_name"`
	PartyMobile    string          `json:"party_mobile"`
	CustomerID     *uint           `json:"customer_id"`
	Date           string          `json:"date"`
	Shift          string          `json:"shift"`
	QuantityLiters decimal.Decimal `json:"quantity_liters"`
	RatePerLiter   decimal.Decimal `json:"rate_per_liter"`
	Amount         decimal.Decimal `json:"amount"`
	FatPercent     decimal.Decimal `json:"fat_percent"`
	Narration      string          `json:"narration"`
}

type dairyCustomerBody struct {
	UserID      uint            `json:"user_id"`
	OwnerUserID uint            `json:"owner_user_id"`
	Name        string          `json:"name"`
	Mobile      string          `json:"mobile"`
	Village     string          `json:"village"`
	DefaultRate decimal.Decimal `json:"default_rate"`
	Notes       string          `json:"notes"`
}

func normalizeDairyKind(kind, ownerKind string) string {
	k := strings.ToLower(strings.TrimSpace(kind))
	if k == "" {
		k = strings.ToLower(strings.TrimSpace(ownerKind))
	}
	switch k {
	case dairyKindGiven, "given", "supplied":
		return dairyKindGiven
	case dairyKindBought, "bought", "purchased":
		return dairyKindBought
	case dairyKindPayRecv, "received":
		return dairyKindPayRecv
	case dairyKindPayMade, "paid", "payment":
		return dairyKindPayMade
	case "collected", "collection":
		return dairyKindBought
	case "sold", "sale":
		return dairyKindGiven
	default:
		return ""
	}
}

func ownerKindFromLedger(kind string) string {
	switch kind {
	case dairyKindBought:
		return "collected"
	case dairyKindGiven:
		return "sold"
	case dairyKindPayMade:
		return "paid"
	case dairyKindPayRecv:
		return "received"
	default:
		return kind
	}
}

func reverseDairyKind(kind string) string {
	switch kind {
	case dairyKindGiven:
		return dairyKindBought
	case dairyKindBought:
		return dairyKindGiven
	case dairyKindPayRecv:
		return dairyKindPayMade
	case dairyKindPayMade:
		return dairyKindPayRecv
	default:
		return kind
	}
}

func normalizeDairyShift(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	switch s {
	case dairyShiftMorning, dairyShiftEvening:
		return s
	default:
		return ""
	}
}

func parseDairyDate(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Now(), nil
	}
	for _, layout := range []string{
		time.RFC3339,
		"2006-01-02",
		"2006-01-02T15:04:05",
		"2006-01-02T15:04:05Z07:00",
	} {
		if t, err := time.Parse(layout, s); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fiber.NewError(fiber.StatusBadRequest, "invalid date")
}

func dairyKindLabel(kind string) string {
	switch kind {
	case dairyKindGiven:
		return "Milk given"
	case dairyKindBought:
		return "Milk bought"
	case dairyKindPayRecv:
		return "Payment received"
	case dairyKindPayMade:
		return "Payment made"
	default:
		return kind
	}
}

func dairyUserMobileLast10(uid uint) string {
	var u models.User
	if userDB == nil || uid == 0 {
		return ""
	}
	if err := userDB.First(&u, uid).Error; err != nil {
		return ""
	}
	if u.MobileNumber == nil {
		return ""
	}
	return last10Phone(*u.MobileNumber)
}

func dairyUserName(uid uint) string {
	var u models.User
	if userDB == nil || uid == 0 {
		return ""
	}
	if err := userDB.First(&u, uid).Error; err != nil {
		return ""
	}
	return userDisplayName(u)
}

func dairyEntryToMap(row models.DairyEntry, viewerUID uint) fiber.Map {
	kind := row.Kind
	partyName := row.PartyName
	fromDairy := row.Origin == dairyOriginDairy && row.UserID != viewerUID
	editable := row.UserID == viewerUID
	if fromDairy {
		kind = reverseDairyKind(row.Kind)
		n := dairyUserName(row.UserID)
		if n != "" {
			partyName = n
		}
	}
	out := fiber.Map{
		"id":              row.ID,
		"user_id":         row.UserID,
		"origin":          row.Origin,
		"kind":            kind,
		"kind_label":      dairyKindLabel(kind),
		"owner_kind":      ownerKindFromLedger(row.Kind),
		"party_name":      partyName,
		"party_mobile":    row.PartyMobile,
		"customer_id":     row.CustomerID,
		"date":            row.Date.Format("2006-01-02"),
		"shift":           row.Shift,
		"quantity_liters": row.QuantityLiters,
		"rate_per_liter":  row.RatePerLiter,
		"amount":          row.Amount,
		"fat_percent":     row.FatPercent,
		"narration":       row.Narration,
		"from_dairy":      fromDairy,
		"editable":        editable,
		"created_at":      row.CreatedAt,
		"updated_at":      row.UpdatedAt,
	}
	return out
}

func dairyCustomerToMap(row models.DairyCustomer, tid uint) fiber.Map {
	linked := findUserByMobileLast10(row.Mobile, row.UserID, tid)
	out := fiber.Map{
		"id":             row.ID,
		"user_id":        row.UserID,
		"name":           row.Name,
		"mobile":         row.Mobile,
		"village":        row.Village,
		"default_rate":   row.DefaultRate,
		"notes":          row.Notes,
		"linked_account": linked != nil,
		"created_at":     row.CreatedAt,
		"updated_at":     row.UpdatedAt,
	}
	if linked != nil {
		out["linked_user_id"] = linked.ID
		out["linked_user_name"] = userDisplayName(*linked)
	}
	return out
}

func applyDairyEntryBody(row *models.DairyEntry, body dairyEntryBody, asOwner bool) error {
	kind := normalizeDairyKind(body.Kind, body.OwnerKind)
	if kind == "" {
		return fiber.NewError(fiber.StatusBadRequest, "kind is required")
	}
	if asOwner && strings.TrimSpace(body.Kind) == "" && strings.TrimSpace(body.OwnerKind) != "" {
		kind = normalizeDairyKind("", body.OwnerKind)
	}
	date, err := parseDairyDate(body.Date)
	if err != nil {
		return err
	}
	name := strings.TrimSpace(body.PartyName)
	mobile := last10Phone(body.PartyMobile)
	if name == "" {
		return fiber.NewError(fiber.StatusBadRequest, "party_name is required")
	}
	qty := body.QuantityLiters
	rate := body.RatePerLiter
	amt := body.Amount
	if kind == dairyKindGiven || kind == dairyKindBought {
		if qty.LessThanOrEqual(decimal.Zero) {
			return fiber.NewError(fiber.StatusBadRequest, "quantity_liters must be greater than zero")
		}
		if rate.LessThan(decimal.Zero) {
			return fiber.NewError(fiber.StatusBadRequest, "rate_per_liter cannot be negative")
		}
		if amt.LessThanOrEqual(decimal.Zero) {
			amt = qty.Mul(rate).Round(2)
		}
		if amt.LessThanOrEqual(decimal.Zero) {
			return fiber.NewError(fiber.StatusBadRequest, "amount must be greater than zero")
		}
	} else {
		qty = decimal.Zero
		rate = decimal.Zero
		if amt.LessThanOrEqual(decimal.Zero) {
			return fiber.NewError(fiber.StatusBadRequest, "amount must be greater than zero")
		}
	}
	row.Kind = kind
	row.PartyName = name
	row.PartyMobile = mobile
	row.CustomerID = body.CustomerID
	row.Date = date
	row.Shift = normalizeDairyShift(body.Shift)
	row.QuantityLiters = qty
	row.RatePerLiter = rate
	row.Amount = amt.Round(2)
	row.FatPercent = body.FatPercent
	row.Narration = strings.TrimSpace(body.Narration)
	return nil
}

func ensureDairyCustomer(ownerUID uint, name, mobile, village string, rate decimal.Decimal) (*models.DairyCustomer, error) {
	mobile = last10Phone(mobile)
	name = strings.TrimSpace(name)
	if ownerUID == 0 || name == "" {
		return nil, nil
	}
	var row models.DairyCustomer
	q := dairyDB.Where("user_id = ?", ownerUID)
	if mobile != "" {
		q = q.Where("mobile = ?", mobile)
	} else {
		q = q.Where("mobile = ? AND LOWER(name) = ?", "", strings.ToLower(name))
	}
	err := q.First(&row).Error
	if err == nil {
		updates := map[string]interface{}{}
		if name != "" && row.Name != name {
			updates["name"] = name
		}
		if village != "" && row.Village == "" {
			updates["village"] = village
		}
		if rate.GreaterThan(decimal.Zero) && row.DefaultRate.Equal(decimal.Zero) {
			updates["default_rate"] = rate
		}
		if len(updates) > 0 {
			_ = dairyDB.Model(&row).Updates(updates).Error
			_ = dairyDB.First(&row, row.ID).Error
		}
		return &row, nil
	}
	if err != gorm.ErrRecordNotFound {
		return nil, err
	}
	row = models.DairyCustomer{
		UserID:      ownerUID,
		Name:        name,
		Mobile:      mobile,
		Village:     strings.TrimSpace(village),
		DefaultRate: rate,
	}
	if err := dairyDB.Create(&row).Error; err != nil {
		return nil, err
	}
	return &row, nil
}

func dairySummaryFromRows(rows []models.DairyEntry, viewerUID uint) fiber.Map {
	givenQty, boughtQty := decimal.Zero, decimal.Zero
	givenAmt, boughtAmt := decimal.Zero, decimal.Zero
	recvAmt, paidAmt := decimal.Zero, decimal.Zero
	for _, row := range rows {
		kind := row.Kind
		if row.Origin == dairyOriginDairy && row.UserID != viewerUID {
			kind = reverseDairyKind(kind)
		}
		switch kind {
		case dairyKindGiven:
			givenQty = givenQty.Add(row.QuantityLiters)
			givenAmt = givenAmt.Add(row.Amount)
		case dairyKindBought:
			boughtQty = boughtQty.Add(row.QuantityLiters)
			boughtAmt = boughtAmt.Add(row.Amount)
		case dairyKindPayRecv:
			recvAmt = recvAmt.Add(row.Amount)
		case dairyKindPayMade:
			paidAmt = paidAmt.Add(row.Amount)
		}
	}
	receivable := givenAmt.Sub(recvAmt)
	payable := boughtAmt.Sub(paidAmt)
	net := receivable.Sub(payable)
	side := "settled"
	if net.GreaterThan(decimal.Zero) {
		side = "receivable"
	} else if net.LessThan(decimal.Zero) {
		side = "payable"
	}
	return fiber.Map{
		"milk_given_liters":  givenQty,
		"milk_bought_liters": boughtQty,
		"milk_given_amount":  givenAmt,
		"milk_bought_amount": boughtAmt,
		"payment_received":   recvAmt,
		"payment_made":       paidAmt,
		"receivable":         receivable,
		"payable":            payable,
		"net":                net,
		"net_side":           side,
		"entry_count":        len(rows),
	}
}

func loadFarmerDairyRows(uid uint, from, to time.Time, hasFrom, hasTo bool, kind, q, partyMobile string) ([]models.DairyEntry, error) {
	own := dairyDB.Model(&models.DairyEntry{}).Where("user_id = ? AND origin = ?", uid, dairyOriginFarmer)
	own = filterDairyEntries(own, from, to, hasFrom, hasTo, "", q, partyMobile)
	var ownRows []models.DairyEntry
	if err := own.Order("date DESC, id DESC").Find(&ownRows).Error; err != nil {
		return nil, err
	}

	mobile := dairyUserMobileLast10(uid)
	var dairyRows []models.DairyEntry
	if len(mobile) >= 10 {
		dq := dairyDB.Model(&models.DairyEntry{}).
			Where("origin = ? AND user_id <> ?", dairyOriginDairy, uid).
			Where("right(regexp_replace(coalesce(party_mobile,''), '[^0-9]', '', 'g'), 10) = ?", mobile)
		dq = filterDairyEntries(dq, from, to, hasFrom, hasTo, "", q, "")
		if err := dq.Order("date DESC, id DESC").Find(&dairyRows).Error; err != nil {
			return nil, err
		}
	}

	rows := append(ownRows, dairyRows...)
	if kind != "" {
		filtered := make([]models.DairyEntry, 0, len(rows))
		for _, r := range rows {
			viewKind := r.Kind
			if r.Origin == dairyOriginDairy && r.UserID != uid {
				viewKind = reverseDairyKind(viewKind)
			}
			if viewKind == kind {
				filtered = append(filtered, r)
			}
		}
		rows = filtered
	}
	return rows, nil
}

func filterDairyEntries(q *gorm.DB, from, to time.Time, hasFrom, hasTo bool, kind, search, mobile string) *gorm.DB {
	if hasFrom {
		q = q.Where("date >= ?", from)
	}
	if hasTo {
		end := time.Date(to.Year(), to.Month(), to.Day(), 23, 59, 59, 0, to.Location())
		q = q.Where("date <= ?", end)
	}
	if kind != "" {
		q = q.Where("kind = ?", kind)
	}
	if m := last10Phone(mobile); m != "" {
		q = q.Where("right(regexp_replace(coalesce(party_mobile,''), '[^0-9]', '', 'g'), 10) = ?", m)
	}
	if s := strings.TrimSpace(search); s != "" {
		like := "%" + s + "%"
		q = q.Where("party_name ILIKE ? OR party_mobile ILIKE ? OR narration ILIKE ?", like, like, like)
	}
	return q
}

func dairyDateRange(c *fiber.Ctx) (from, to time.Time, hasFrom, hasTo bool) {
	if t, ok := parseOptionalTime(c.Query("from")); ok {
		from, hasFrom = t, true
	}
	if t, ok := parseOptionalTime(c.Query("to")); ok {
		to, hasTo = t, true
	}
	return
}

func dairyListPayload(rows []models.DairyEntry, viewerUID uint) []fiber.Map {
	out := make([]fiber.Map, 0, len(rows))
	for _, r := range rows {
		out = append(out, dairyEntryToMap(r, viewerUID))
	}
	return out
}

// GET /api/dairy/summary
func GetDairySummary(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	from, to, hasFrom, hasTo := dairyDateRange(c)
	kind := normalizeDairyKind(c.Query("kind"), "")
	rows, err := loadFarmerDairyRows(uid, from, to, hasFrom, hasTo, kind, c.Query("q"), c.Query("mobile"))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(dairySummaryFromRows(rows, uid))
}

// GET /api/dairy/entries
func ListDairyEntries(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	from, to, hasFrom, hasTo := dairyDateRange(c)
	kind := normalizeDairyKind(c.Query("kind"), "")
	rows, err := loadFarmerDairyRows(uid, from, to, hasFrom, hasTo, kind, c.Query("q"), c.Query("mobile"))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": dairyListPayload(rows, uid), "total": len(rows)})
}

// POST /api/dairy/entries
func CreateDairyEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body dairyEntryBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	row := models.DairyEntry{UserID: uid, Origin: dairyOriginFarmer}
	if err := applyDairyEntryBody(&row, body, false); err != nil {
		return err
	}
	if err := dairyDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to save dairy entry"})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Dairy entry saved", "data": dairyEntryToMap(row, uid)})
}

func loadOwnFarmerEntry(uid, id uint) (*models.DairyEntry, error) {
	var row models.DairyEntry
	err := dairyDB.Where("id = ? AND user_id = ? AND origin = ?", id, uid, dairyOriginFarmer).First(&row).Error
	if err != nil {
		return nil, err
	}
	return &row, nil
}

// PUT /api/dairy/entries/:id
func UpdateDairyEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	row, err := loadOwnFarmerEntry(uid, uint(id))
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "Entry not found or cannot be edited (dairy-recorded entries are read-only)"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var body dairyEntryBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	if err := applyDairyEntryBody(row, body, false); err != nil {
		return err
	}
	if err := dairyDB.Save(row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update dairy entry"})
	}
	return c.JSON(fiber.Map{"message": "Dairy entry updated", "data": dairyEntryToMap(*row, uid)})
}

// DELETE /api/dairy/entries/:id
func DeleteDairyEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	res := dairyDB.Where("id = ? AND user_id = ? AND origin = ?", id, uid, dairyOriginFarmer).
		Delete(&models.DairyEntry{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Entry not found or cannot be deleted (dairy-recorded entries are read-only)"})
	}
	return c.JSON(fiber.Map{"message": "Dairy entry deleted"})
}

// GET /api/dairy/owner/customers
func ListDairyCustomers(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return listDairyCustomersForOwner(c, uid)
}

func listDairyCustomersForOwner(c *fiber.Ctx, ownerUID uint) error {
	q := dairyDB.Model(&models.DairyCustomer{}).Where("user_id = ?", ownerUID)
	if s := strings.TrimSpace(c.Query("q")); s != "" {
		like := "%" + s + "%"
		q = q.Where("name ILIKE ? OR mobile ILIKE ? OR village ILIKE ?", like, like, like)
	}
	var rows []models.DairyCustomer
	if err := q.Order("name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	tid := tenantIDFromCtx(c)
	out := make([]fiber.Map, 0, len(rows))
	for _, r := range rows {
		m := dairyCustomerToMap(r, tid)
		m["balance"] = dairyCustomerBalance(ownerUID, r)
		out = append(out, m)
	}
	return c.JSON(fiber.Map{"data": out, "total": len(out)})
}

func dairyCustomerBalance(ownerUID uint, cust models.DairyCustomer) fiber.Map {
	q := dairyDB.Model(&models.DairyEntry{}).Where("user_id = ? AND origin = ?", ownerUID, dairyOriginDairy)
	if cust.ID > 0 {
		mob := last10Phone(cust.Mobile)
		if mob != "" {
			q = q.Where("customer_id = ? OR right(regexp_replace(coalesce(party_mobile,''), '[^0-9]', '', 'g'), 10) = ?", cust.ID, mob)
		} else {
			q = q.Where("customer_id = ?", cust.ID)
		}
	}
	var rows []models.DairyEntry
	_ = q.Find(&rows).Error
	return dairySummaryFromRows(rows, ownerUID)
}

// POST /api/dairy/owner/customers
func CreateDairyCustomer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body dairyCustomerBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return saveDairyCustomer(c, uid, body)
}

func ownerIDFromDairyBody(userID, ownerUserID uint) uint {
	if ownerUserID > 0 {
		return ownerUserID
	}
	return userID
}

func saveDairyCustomer(c *fiber.Ctx, ownerUID uint, body dairyCustomerBody) error {
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row, err := ensureDairyCustomer(ownerUID, name, body.Mobile, body.Village, body.DefaultRate)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to save customer"})
	}
	if row == nil {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	if strings.TrimSpace(body.Notes) != "" {
		_ = dairyDB.Model(row).Update("notes", strings.TrimSpace(body.Notes)).Error
		_ = dairyDB.First(row, row.ID).Error
	}
	return c.Status(201).JSON(fiber.Map{
		"message": "Customer saved",
		"data":    dairyCustomerToMap(*row, tenantIDFromCtx(c)),
	})
}

// PUT /api/dairy/owner/customers/:id
func UpdateDairyCustomer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body dairyCustomerBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return saveUpdatedDairyCustomer(c, uid, body)
}

func saveUpdatedDairyCustomer(c *fiber.Ctx, ownerUID uint, body dairyCustomerBody) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.DairyCustomer
	if err := dairyDB.Where("id = ? AND user_id = ?", id, ownerUID).First(&row).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "Customer not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	row.Name = name
	row.Mobile = last10Phone(body.Mobile)
	row.Village = strings.TrimSpace(body.Village)
	row.DefaultRate = body.DefaultRate
	row.Notes = strings.TrimSpace(body.Notes)
	if err := dairyDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update customer"})
	}
	return c.JSON(fiber.Map{"message": "Customer updated", "data": dairyCustomerToMap(row, tenantIDFromCtx(c))})
}

// DELETE /api/dairy/owner/customers/:id
func DeleteDairyCustomer(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return deleteDairyCustomerForOwner(c, uid)
}

func deleteDairyCustomerForOwner(c *fiber.Ctx, ownerUID uint) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	res := dairyDB.Where("id = ? AND user_id = ?", id, ownerUID).Delete(&models.DairyCustomer{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Customer not found"})
	}
	_ = dairyDB.Model(&models.DairyEntry{}).
		Where("user_id = ? AND customer_id = ?", ownerUID, id).
		Update("customer_id", nil).Error
	return c.JSON(fiber.Map{"message": "Customer deleted"})
}

// GET /api/dairy/owner/entries
func ListOwnerDairyEntries(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return listOwnerDairyEntriesFor(c, uid)
}

func listOwnerDairyEntriesFor(c *fiber.Ctx, ownerUID uint) error {
	from, to, hasFrom, hasTo := dairyDateRange(c)
	kind := normalizeDairyKind(c.Query("kind"), c.Query("owner_kind"))
	q := dairyDB.Model(&models.DairyEntry{}).Where("user_id = ? AND origin = ?", ownerUID, dairyOriginDairy)
	q = filterDairyEntries(q, from, to, hasFrom, hasTo, kind, c.Query("q"), c.Query("mobile"))
	if cid := c.QueryInt("customer_id", 0); cid > 0 {
		q = q.Where("customer_id = ?", cid)
	}
	var rows []models.DairyEntry
	if err := q.Order("date DESC, id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": dairyListPayload(rows, ownerUID), "total": len(rows)})
}

// GET /api/dairy/owner/summary
func GetOwnerDairySummary(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return ownerDairySummaryFor(c, uid)
}

func ownerDairySummaryFor(c *fiber.Ctx, ownerUID uint) error {
	from, to, hasFrom, hasTo := dairyDateRange(c)
	q := dairyDB.Model(&models.DairyEntry{}).Where("user_id = ? AND origin = ?", ownerUID, dairyOriginDairy)
	q = filterDairyEntries(q, from, to, hasFrom, hasTo, "", c.Query("q"), c.Query("mobile"))
	if cid := c.QueryInt("customer_id", 0); cid > 0 {
		q = q.Where("customer_id = ?", cid)
	}
	var rows []models.DairyEntry
	if err := q.Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(dairySummaryFromRows(rows, ownerUID))
}

// POST /api/dairy/owner/entries
func CreateOwnerDairyEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body dairyEntryBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return saveOwnerDairyEntry(c, uid, body)
}

func saveOwnerDairyEntry(c *fiber.Ctx, ownerUID uint, body dairyEntryBody) error {
	if body.CustomerID != nil && *body.CustomerID > 0 {
		var cust models.DairyCustomer
		if err := dairyDB.Where("id = ? AND user_id = ?", *body.CustomerID, ownerUID).First(&cust).Error; err == nil {
			if strings.TrimSpace(body.PartyName) == "" {
				body.PartyName = cust.Name
			}
			if strings.TrimSpace(body.PartyMobile) == "" {
				body.PartyMobile = cust.Mobile
			}
			if body.RatePerLiter.LessThanOrEqual(decimal.Zero) && cust.DefaultRate.GreaterThan(decimal.Zero) {
				body.RatePerLiter = cust.DefaultRate
			}
		}
	}
	row := models.DairyEntry{UserID: ownerUID, Origin: dairyOriginDairy}
	if err := applyDairyEntryBody(&row, body, true); err != nil {
		return err
	}
	cust, err := ensureDairyCustomer(ownerUID, row.PartyName, row.PartyMobile, "", row.RatePerLiter)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to save customer"})
	}
	if cust != nil {
		id := cust.ID
		row.CustomerID = &id
		if row.PartyMobile == "" {
			row.PartyMobile = cust.Mobile
		}
	}
	if err := dairyDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to save dairy entry"})
	}
	return c.Status(201).JSON(fiber.Map{
		"message":        "Milk entry saved. It will show on the customer's Dairy page if they use the app with this mobile number.",
		"data":           dairyEntryToMap(row, ownerUID),
		"linked_account": findUserByMobileLast10(row.PartyMobile, ownerUID, tenantIDFromCtx(c)) != nil,
	})
}

// PUT /api/dairy/owner/entries/:id
func UpdateOwnerDairyEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body dairyEntryBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return saveUpdatedOwnerDairyEntry(c, uid, body)
}

func saveUpdatedOwnerDairyEntry(c *fiber.Ctx, ownerUID uint, body dairyEntryBody) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.DairyEntry
	if err := dairyDB.Where("id = ? AND user_id = ? AND origin = ?", id, ownerUID, dairyOriginDairy).First(&row).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "Entry not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := applyDairyEntryBody(&row, body, true); err != nil {
		return err
	}
	if err := dairyDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update dairy entry"})
	}
	return c.JSON(fiber.Map{"message": "Dairy entry updated", "data": dairyEntryToMap(row, ownerUID)})
}

// DELETE /api/dairy/owner/entries/:id
func DeleteOwnerDairyEntry(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return deleteOwnerDairyEntryFor(c, uid)
}

func deleteOwnerDairyEntryFor(c *fiber.Ctx, ownerUID uint) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	res := dairyDB.Where("id = ? AND user_id = ? AND origin = ?", id, ownerUID, dairyOriginDairy).
		Delete(&models.DairyEntry{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Entry not found"})
	}
	return c.JSON(fiber.Map{"message": "Dairy entry deleted"})
}

func adminDairyOwnerID(c *fiber.Ctx) (uint, error) {
	if _, err := requireUserID(c); err != nil {
		return 0, err
	}
	raw := strings.TrimSpace(c.Query("user_id"))
	if raw == "" {
		raw = strings.TrimSpace(c.Query("owner_user_id"))
	}
	if raw == "" {
		return 0, fiber.NewError(fiber.StatusBadRequest, "user_id is required")
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, fiber.NewError(fiber.StatusBadRequest, "invalid user_id")
	}
	return uint(n), nil
}

func requireAdminDairyOwnerID(c *fiber.Ctx, fromBody uint) (uint, error) {
	if _, err := requireUserID(c); err != nil {
		return 0, err
	}
	if fromBody > 0 {
		return fromBody, nil
	}
	return adminDairyOwnerID(c)
}

// GET /api/admin/dairy/customers
func AdminListDairyCustomers(c *fiber.Ctx) error {
	ownerUID, err := adminDairyOwnerID(c)
	if err != nil {
		return err
	}
	return listDairyCustomersForOwner(c, ownerUID)
}

// POST /api/admin/dairy/customers
func AdminCreateDairyCustomer(c *fiber.Ctx) error {
	var body dairyCustomerBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	ownerUID, err := requireAdminDairyOwnerID(c, ownerIDFromDairyBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return saveDairyCustomer(c, ownerUID, body)
}

// PUT /api/admin/dairy/customers/:id
func AdminUpdateDairyCustomer(c *fiber.Ctx) error {
	var body dairyCustomerBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	ownerUID, err := requireAdminDairyOwnerID(c, ownerIDFromDairyBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return saveUpdatedDairyCustomer(c, ownerUID, body)
}

// DELETE /api/admin/dairy/customers/:id
func AdminDeleteDairyCustomer(c *fiber.Ctx) error {
	ownerUID, err := adminDairyOwnerID(c)
	if err != nil {
		return err
	}
	return deleteDairyCustomerForOwner(c, ownerUID)
}

// GET /api/admin/dairy/entries
func AdminListDairyEntries(c *fiber.Ctx) error {
	ownerUID, err := adminDairyOwnerID(c)
	if err != nil {
		return err
	}
	return listOwnerDairyEntriesFor(c, ownerUID)
}

// POST /api/admin/dairy/entries
func AdminCreateDairyEntry(c *fiber.Ctx) error {
	var body dairyEntryBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	ownerUID, err := requireAdminDairyOwnerID(c, ownerIDFromDairyBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return saveOwnerDairyEntry(c, ownerUID, body)
}

// PUT /api/admin/dairy/entries/:id
func AdminUpdateDairyEntry(c *fiber.Ctx) error {
	var body dairyEntryBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	ownerUID, err := requireAdminDairyOwnerID(c, ownerIDFromDairyBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return saveUpdatedOwnerDairyEntry(c, ownerUID, body)
}

// DELETE /api/admin/dairy/entries/:id
func AdminDeleteDairyEntry(c *fiber.Ctx) error {
	ownerUID, err := adminDairyOwnerID(c)
	if err != nil {
		return err
	}
	return deleteOwnerDairyEntryFor(c, ownerUID)
}

// GET /api/admin/dairy/summary
func AdminGetDairySummary(c *fiber.Ctx) error {
	ownerUID, err := adminDairyOwnerID(c)
	if err != nil {
		return err
	}
	return ownerDairySummaryFor(c, ownerUID)
}
