package handler

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

var landRtcDB *gorm.DB

func SetLandRtcDB(db *gorm.DB) {
	landRtcDB = db
}

type landRtcBody struct {
	State        string `json:"state"`
	District     string `json:"district"`
	Taluk        string `json:"taluk"`
	Hobli        string `json:"hobli"`
	SurveyNumber string `json:"survey_number"`
	Hissa        string `json:"hissa"`
	Acre         int    `json:"acre"`
	Gunta        int    `json:"gunta"`
	Ana          int    `json:"ana"`
	Details      string `json:"details"`
	DocumentURL  string `json:"document_url"`
}

func applyLandRtcBody(row *models.LandRtc, body landRtcBody) error {
	state := strings.TrimSpace(body.State)
	if state == "" {
		state = "Karnataka"
	}
	district := strings.TrimSpace(body.District)
	if district == "" {
		district = "Uttara Kannada"
	}
	taluk := strings.TrimSpace(body.Taluk)
	survey := strings.TrimSpace(body.SurveyNumber)
	if survey == "" {
		return fmt.Errorf("survey_number is required")
	}
	if body.Acre < 0 || body.Gunta < 0 || body.Ana < 0 {
		return fmt.Errorf("acre, gunta and ana must be >= 0")
	}
	// Normalize carry: 4 ana = 1 gunta, 40 gunta = 1 acre
	acre, gunta, ana := body.Acre, body.Gunta, body.Ana
	gunta += ana / 4
	ana = ana % 4
	acre += gunta / 40
	gunta = gunta % 40

	row.State = state
	row.District = district
	row.Taluk = taluk
	row.Hobli = strings.TrimSpace(body.Hobli)
	row.SurveyNumber = survey
	row.Hissa = strings.TrimSpace(body.Hissa)
	row.Acre = acre
	row.Gunta = gunta
	row.Ana = ana
	row.TotalAcres = models.ComputeTotalAcres(acre, gunta, ana)
	row.Details = strings.TrimSpace(body.Details)
	row.DocumentURL = strings.TrimSpace(body.DocumentURL)
	return nil
}

// ListMyLandRtcs GET /api/land_rtcs
func ListMyLandRtcs(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 50)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	offset := (page - 1) * limit

	var rows []models.LandRtc
	var total int64
	q := scopeByUserID(landRtcDB.Model(&models.LandRtc{}), uid)
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

// GetMyLandRtc GET /api/land_rtcs/:id
func GetMyLandRtc(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.LandRtc
	if err := scopeByUserID(landRtcDB.Model(&models.LandRtc{}), uid).First(&row, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(row)
}

// CreateLandRtc POST /api/land_rtcs
func CreateLandRtc(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body landRtcBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	row := models.LandRtc{UserID: uid}
	if err := applyLandRtcBody(&row, body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := landRtcDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create RTC", "details": err.Error()})
	}
	return c.Status(201).JSON(row)
}

// UpdateLandRtc PUT /api/land_rtcs/:id
func UpdateLandRtc(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.LandRtc
	if err := scopeByUserID(landRtcDB.Model(&models.LandRtc{}), uid).First(&row, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var body landRtcBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if err := applyLandRtcBody(&row, body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := landRtcDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update RTC", "details": err.Error()})
	}
	return c.JSON(row)
}

// DeleteLandRtc DELETE /api/land_rtcs/:id
func DeleteLandRtc(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	res := scopeByUserID(landRtcDB.Model(&models.LandRtc{}), uid).Delete(&models.LandRtc{}, id)
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"ok": true})
}

const (
	maxRtcFileBytes = 15 << 20 // 15 MiB
	rtcUploadDir    = "land-rtcs"
)

func sniffRtcExt(fh *multipart.FileHeader) (string, bool) {
	name := strings.ToLower(fh.Filename)
	ct := strings.ToLower(fh.Header.Get("Content-Type"))
	switch {
	case strings.HasSuffix(name, ".pdf") || strings.Contains(ct, "pdf"):
		return ".pdf", true
	case strings.HasSuffix(name, ".jpg") || strings.HasSuffix(name, ".jpeg") || strings.Contains(ct, "jpeg"):
		return ".jpg", true
	case strings.HasSuffix(name, ".png") || strings.Contains(ct, "png"):
		return ".png", true
	case strings.HasSuffix(name, ".webp") || strings.Contains(ct, "webp"):
		return ".webp", true
	default:
		return "", false
	}
}

func saveRtcFile(file *multipart.FileHeader) (string, error) {
	ext, ok := sniffRtcExt(file)
	if !ok {
		return "", fmt.Errorf("unsupported file type (pdf, jpg, png)")
	}
	if file.Size > maxRtcFileBytes {
		return "", fmt.Errorf("file exceeds %d bytes", maxRtcFileBytes)
	}
	base := filepath.Join("uploads", rtcUploadDir)
	if err := os.MkdirAll(base, 0755); err != nil {
		return "", err
	}
	name := uuid.NewString() + ext
	dstPath := filepath.Join(base, name)

	src, err := file.Open()
	if err != nil {
		return "", err
	}
	defer src.Close()

	dst, err := os.Create(dstPath)
	if err != nil {
		return "", err
	}
	defer dst.Close()

	if _, err := io.Copy(dst, src); err != nil {
		return "", err
	}
	return "/" + filepath.ToSlash(filepath.Join("uploads", rtcUploadDir, name)), nil
}

// UploadLandRtcDocument POST /api/land_rtcs/upload — multipart field "file"
func UploadLandRtcDocument(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
		return err
	}
	form, err := c.MultipartForm()
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "multipart form required", "details": err.Error()})
	}
	files := form.File["file"]
	if len(files) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no file: use multipart field \"file\""})
	}
	if len(files) > 1 {
		return c.Status(400).JSON(fiber.Map{"error": "send only one file per request"})
	}
	urlPath, err := saveRtcFile(files[0])
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"url": urlPath})
}

// --- Admin ---

func attachLandRtcUserMeta(rows []models.LandRtc) {
	if len(rows) == 0 || userDB == nil {
		return
	}
	ids := make([]uint, 0, len(rows))
	seen := map[uint]struct{}{}
	for _, r := range rows {
		if _, ok := seen[r.UserID]; ok {
			continue
		}
		seen[r.UserID] = struct{}{}
		ids = append(ids, r.UserID)
	}
	var users []models.User
	if err := userDB.Where("id IN ?", ids).Find(&users).Error; err != nil {
		return
	}
	byID := map[uint]models.User{}
	for _, u := range users {
		byID[u.ID] = u
	}
	for i := range rows {
		u, ok := byID[rows[i].UserID]
		if !ok {
			continue
		}
		name := strings.TrimSpace(u.Firstname + " " + u.Lastname)
		if name == "" {
			name = strings.TrimSpace(u.Username)
		}
		rows[i].UserName = name
		if u.MobileNumber != nil {
			rows[i].UserPhone = strings.TrimSpace(*u.MobileNumber)
		}
	}
}

// AdminListLandRtcs GET /api/admin/land_rtcs
func AdminListLandRtcs(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
		return err
	}
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}
	offset := (page - 1) * limit

	q := landRtcDB.Model(&models.LandRtc{})
	if uid := c.QueryInt("user_id", 0); uid > 0 {
		q = q.Where("user_id = ?", uid)
	}
	if s := strings.TrimSpace(c.Query("q")); s != "" {
		like := "%" + s + "%"
		q = q.Where(
			"survey_number ILIKE ? OR taluk ILIKE ? OR hobli ILIKE ? OR district ILIKE ? OR hissa ILIKE ?",
			like, like, like, like, like,
		)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var rows []models.LandRtc
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	attachLandRtcUserMeta(rows)
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

// AdminGetLandRtc GET /api/admin/land_rtcs/:id
func AdminGetLandRtc(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
		return err
	}
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.LandRtc
	if err := landRtcDB.First(&row, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	list := []models.LandRtc{row}
	attachLandRtcUserMeta(list)
	return c.JSON(list[0])
}

type adminLandRtcBody struct {
	landRtcBody
	UserID uint `json:"user_id"`
}

// AdminCreateLandRtc POST /api/admin/land_rtcs
func AdminCreateLandRtc(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
		return err
	}
	var body adminLandRtcBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if body.UserID == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "user_id is required"})
	}
	row := models.LandRtc{UserID: body.UserID}
	if err := applyLandRtcBody(&row, body.landRtcBody); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := landRtcDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create RTC", "details": err.Error()})
	}
	list := []models.LandRtc{row}
	attachLandRtcUserMeta(list)
	return c.Status(201).JSON(list[0])
}

// AdminUpdateLandRtc PUT /api/admin/land_rtcs/:id
func AdminUpdateLandRtc(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
		return err
	}
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.LandRtc
	if err := landRtcDB.First(&row, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var body adminLandRtcBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if body.UserID > 0 {
		row.UserID = body.UserID
	}
	if err := applyLandRtcBody(&row, body.landRtcBody); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if err := landRtcDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update RTC", "details": err.Error()})
	}
	list := []models.LandRtc{row}
	attachLandRtcUserMeta(list)
	return c.JSON(list[0])
}

// AdminDeleteLandRtc DELETE /api/admin/land_rtcs/:id
func AdminDeleteLandRtc(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
		return err
	}
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	res := landRtcDB.Delete(&models.LandRtc{}, id)
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"ok": true})
}

// AdminUploadLandRtcDocument POST /api/admin/land_rtcs/upload
func AdminUploadLandRtcDocument(c *fiber.Ctx) error {
	return UploadLandRtcDocument(c)
}
