package handler

import (
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var govDB *gorm.DB

func SetGovDB(db *gorm.DB) {
	govDB = db
}

var validGovCategories = map[string]bool{
	"loans":     true,
	"insurance": true,
	"grants":    true,
}

func normalizeGovCategory(s string) string {
	c := strings.ToLower(strings.TrimSpace(s))
	switch c {
	case "loan":
		return "loans"
	case "insurances", "insure":
		return "insurance"
	case "grant":
		return "grants"
	default:
		return c
	}
}

func parseOptionalDate(s string) (*time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	layouts := []string{
		time.RFC3339,
		"2006-01-02",
		"2006-01-02T15:04:05Z07:00",
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			tt := t.UTC()
			return &tt, nil
		}
	}
	return nil, fiber.NewError(400, "invalid date format (use YYYY-MM-DD)")
}

// ---------- Public (Flutter) ----------

func GetGovDepartments(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	q := govDB.Model(&models.GovDepartment{}).Where("tenant_id = ? AND status = ?", tid, "active")
	var rows []models.GovDepartment
	if err := q.Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func GetGovCrops(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	q := govDB.Model(&models.GovCrop{}).Where("tenant_id = ? AND status = ?", tid, "active")
	var rows []models.GovCrop
	if err := q.Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func GetGovCategories(c *fiber.Ctx) error {
	cats := []fiber.Map{
		{"slug": "loans", "name": "Loans"},
		{"slug": "insurance", "name": "Insurance"},
		{"slug": "grants", "name": "Grants"},
	}
	return c.JSON(fiber.Map{"data": cats})
}

func GetGovFacilities(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	q := govDB.Model(&models.GovFacility{}).Where("tenant_id = ? AND status = ?", tid, "active")

	if v := c.Query("department_id"); v != "" {
		q = q.Where("department_id = ?", v)
	}
	if v := c.Query("crop_id"); v != "" {
		q = q.Where("crop_id = ?", v)
	}
	if v := c.Query("category"); v != "" {
		cat := normalizeGovCategory(v)
		if !validGovCategories[cat] {
			return c.Status(400).JSON(fiber.Map{"error": "category must be loans, insurance, or grants"})
		}
		q = q.Where("category = ?", cat)
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("title ILIKE ? OR description ILIKE ? OR place ILIKE ?", like, like, like)
	}

	var rows []models.GovFacility
	if err := q.Preload("Department").Preload("Crop").
		Order("sort_order ASC, title ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func GetGovFacility(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var row models.GovFacility
	if err := govDB.Preload("Department").Preload("Crop").
		Where("id = ? AND tenant_id = ? AND status = ?", id, tid, "active").
		First(&row).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "facility not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

// ---------- Admin: departments ----------

type govDepartmentPayload struct {
	Name      string `json:"name"`
	Slug      string `json:"slug"`
	Status    string `json:"status"`
	SortOrder int    `json:"sort_order"`
}

func slugifySimple(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	var b strings.Builder
	prevDash := false
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			prevDash = false
		} else if !prevDash {
			b.WriteByte('-')
			prevDash = true
		}
	}
	out := strings.Trim(b.String(), "-")
	if out == "" {
		return "item"
	}
	return out
}

func AdminGetGovDepartments(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var rows []models.GovDepartment
	if err := govDB.Where("tenant_id = ?", tid).Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func AdminCreateGovDepartment(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var body govDepartmentPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	slug := strings.TrimSpace(body.Slug)
	if slug == "" {
		slug = slugifySimple(name)
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "active"
	}
	row := models.GovDepartment{
		TenantID:  tid,
		Name:      name,
		Slug:      slug,
		Status:    status,
		SortOrder: body.SortOrder,
	}
	if err := govDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateGovDepartment(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var row models.GovDepartment
	if err := govDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var body govDepartmentPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	if name := strings.TrimSpace(body.Name); name != "" {
		row.Name = name
	}
	if slug := strings.TrimSpace(body.Slug); slug != "" {
		row.Slug = slug
	}
	if status := strings.TrimSpace(body.Status); status != "" {
		row.Status = status
	}
	row.SortOrder = body.SortOrder
	if err := govDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteGovDepartment(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var count int64
	govDB.Model(&models.GovFacility{}).Where("department_id = ? AND tenant_id = ?", id, tid).Count(&count)
	if count > 0 {
		return c.Status(400).JSON(fiber.Map{"error": "cannot delete: facilities still linked to this department"})
	}
	res := govDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.GovDepartment{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Admin: crops ----------

type govCropPayload struct {
	Name      string `json:"name"`
	Slug      string `json:"slug"`
	Status    string `json:"status"`
	SortOrder int    `json:"sort_order"`
}

func AdminGetGovCrops(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var rows []models.GovCrop
	if err := govDB.Where("tenant_id = ?", tid).Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows})
}

func AdminCreateGovCrop(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var body govCropPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	slug := strings.TrimSpace(body.Slug)
	if slug == "" {
		slug = slugifySimple(name)
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "active"
	}
	row := models.GovCrop{
		TenantID:  tid,
		Name:      name,
		Slug:      slug,
		Status:    status,
		SortOrder: body.SortOrder,
	}
	if err := govDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateGovCrop(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var row models.GovCrop
	if err := govDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var body govCropPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	if name := strings.TrimSpace(body.Name); name != "" {
		row.Name = name
	}
	if slug := strings.TrimSpace(body.Slug); slug != "" {
		row.Slug = slug
	}
	if status := strings.TrimSpace(body.Status); status != "" {
		row.Status = status
	}
	row.SortOrder = body.SortOrder
	if err := govDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteGovCrop(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var count int64
	govDB.Model(&models.GovFacility{}).Where("crop_id = ? AND tenant_id = ?", id, tid).Count(&count)
	if count > 0 {
		return c.Status(400).JSON(fiber.Map{"error": "cannot delete: facilities still linked to this crop"})
	}
	res := govDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.GovCrop{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}

// ---------- Admin: facilities ----------

type govFacilityPayload struct {
	DepartmentID   uint   `json:"department_id"`
	CropID         uint   `json:"crop_id"`
	Category       string `json:"category"`
	Title          string `json:"title"`
	Description    string `json:"description"`
	Place          string `json:"place"`
	ContactPerson  string `json:"contact_person"`
	Email          string `json:"email"`
	Website        string `json:"website"`
	Phone          string `json:"phone"`
	ApplicationURL string `json:"application_url"`
	ValidFrom      string `json:"valid_from"`
	ValidTo        string `json:"valid_to"`
	Notes          string `json:"notes"`
	Status         string `json:"status"`
	SortOrder      int    `json:"sort_order"`
}

func applyGovFacilityPayload(row *models.GovFacility, body *govFacilityPayload) error {
	if body.DepartmentID == 0 {
		return fiber.NewError(400, "department_id is required")
	}
	if body.CropID == 0 {
		return fiber.NewError(400, "crop_id is required")
	}
	cat := normalizeGovCategory(body.Category)
	if !validGovCategories[cat] {
		return fiber.NewError(400, "category must be loans, insurance, or grants")
	}
	title := strings.TrimSpace(body.Title)
	if title == "" {
		return fiber.NewError(400, "title is required")
	}
	from, err := parseOptionalDate(body.ValidFrom)
	if err != nil {
		return err
	}
	to, err := parseOptionalDate(body.ValidTo)
	if err != nil {
		return err
	}
	status := strings.TrimSpace(body.Status)
	if status == "" {
		status = "active"
	}

	row.DepartmentID = body.DepartmentID
	row.CropID = body.CropID
	row.Category = cat
	row.Title = title
	row.Description = strings.TrimSpace(body.Description)
	row.Place = strings.TrimSpace(body.Place)
	row.ContactPerson = strings.TrimSpace(body.ContactPerson)
	row.Email = strings.TrimSpace(body.Email)
	row.Website = strings.TrimSpace(body.Website)
	row.Phone = strings.TrimSpace(body.Phone)
	row.ApplicationURL = strings.TrimSpace(body.ApplicationURL)
	row.ValidFrom = from
	row.ValidTo = to
	row.Notes = strings.TrimSpace(body.Notes)
	row.Status = status
	row.SortOrder = body.SortOrder
	return nil
}

func AdminGetGovFacilities(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	q := govDB.Model(&models.GovFacility{}).Where("tenant_id = ?", tid)
	if v := c.Query("department_id"); v != "" {
		q = q.Where("department_id = ?", v)
	}
	if v := c.Query("crop_id"); v != "" {
		q = q.Where("crop_id = ?", v)
	}
	if v := c.Query("category"); v != "" {
		q = q.Where("category = ?", normalizeGovCategory(v))
	}
	if v := c.Query("status"); v != "" {
		q = q.Where("status = ?", v)
	}
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		like := "%" + search + "%"
		q = q.Where("title ILIKE ? OR description ILIKE ? OR place ILIKE ?", like, like, like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var rows []models.GovFacility
	if err := q.Preload("Department").Preload("Crop").
		Order("sort_order ASC, id DESC").
		Offset((page - 1) * limit).Limit(limit).
		Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func AdminGetGovFacility(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var row models.GovFacility
	if err := govDB.Preload("Department").Preload("Crop").
		Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminCreateGovFacility(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var body govFacilityPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body", "details": err.Error()})
	}
	row := models.GovFacility{TenantID: tid}
	if err := applyGovFacilityPayload(&row, &body); err != nil {
		if fe, ok := err.(*fiber.Error); ok {
			return c.Status(fe.Code).JSON(fiber.Map{"error": fe.Message})
		}
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := govDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = govDB.Preload("Department").Preload("Crop").First(&row, row.ID)
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateGovFacility(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	var row models.GovFacility
	if err := govDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var body govFacilityPayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body"})
	}
	if err := applyGovFacilityPayload(&row, &body); err != nil {
		if fe, ok := err.(*fiber.Error); ok {
			return c.Status(fe.Code).JSON(fiber.Map{"error": fe.Message})
		}
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := govDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	_ = govDB.Preload("Department").Preload("Crop").First(&row, row.ID)
	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteGovFacility(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id := c.Params("id")
	res := govDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.GovFacility{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"message": "deleted"})
}
