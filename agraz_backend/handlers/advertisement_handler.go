package handler

import (
	"bytes"
	"crypto/sha1"
	"encoding/hex"
	"errors"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/png"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

const (
	maxAdvertisementImageBytes = 2 << 20 // 2 MiB
	advertisementUploadSubdir  = "advertisements"
	// Recommended design size — must match Flutter slider (1170×658). Uploads keep aspect ratio.
	advertisementTargetW   = 1170
	advertisementTargetH   = 658
	advertisementMaxEdgePx = 2000
	maxActiveAdvertisements   = 10
	adImpressionClickCooldown = 2 * time.Second
)

var (
	advertisementDB *gorm.DB

	adRateMu    sync.Mutex
	adRateLast  = map[string]time.Time{}
	adInAppRoutes = map[string]bool{
		"/main":             true,
		"/services":         true,
		"/buy-sell":         true,
		"/market-report":    true,
		"/weather":          true,
		"/income-expense":   true,
		"/organizations":    true,
		"/labour":           true,
		"/work-entry":       true,
		"/daily-log":        true,
		"market_report":     true,
		"buy_sell":          true,
		"services":          true,
		"weather":           true,
	}
)

func SetAdvertisementDB(db *gorm.DB) {
	advertisementDB = db
}

func adUserIDFromCtx(c *fiber.Ctx) *uint {
	v := c.Locals("user_id")
	if v == nil {
		return nil
	}
	switch t := v.(type) {
	case uint:
		return &t
	case int:
		u := uint(t)
		return &u
	case float64:
		u := uint(t)
		return &u
	case string:
		n, err := strconv.ParseUint(t, 10, 32)
		if err != nil {
			return nil
		}
		u := uint(n)
		return &u
	default:
		return nil
	}
}

func adLinkTypeOK(t string) bool {
	switch t {
	case "none", "external_url", "in_app_screen":
		return true
	default:
		return false
	}
}

func validateAdLink(linkType string, linkValue *string) error {
	if !adLinkTypeOK(linkType) {
		return fmt.Errorf("link_type must be none, external_url, or in_app_screen")
	}
	val := ""
	if linkValue != nil {
		val = strings.TrimSpace(*linkValue)
	}
	switch linkType {
	case "none":
		if val != "" {
			return fmt.Errorf("link_value must be empty when link_type is none")
		}
	case "external_url":
		if val == "" {
			return fmt.Errorf("link_value (https URL) is required for external_url")
		}
		low := strings.ToLower(val)
		if !strings.HasPrefix(low, "https://") {
			return fmt.Errorf("external URL must start with https://")
		}
	case "in_app_screen":
		if val == "" {
			return fmt.Errorf("link_value (screen route) is required for in_app_screen")
		}
		key := strings.TrimSpace(val)
		if !adInAppRoutes[key] && !adInAppRoutes[strings.TrimPrefix(key, "/")] {
			return fmt.Errorf("in-app route is not in the allow-list")
		}
	}
	return nil
}

func parseOptionalAdDate(s string) (*time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	layouts := []string{
		time.RFC3339,
		"2006-01-02",
		"2006-01-02T15:04:05",
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			return &t, nil
		}
	}
	return nil, fmt.Errorf("invalid date: %s", s)
}

func adScheduleActive(row *models.Advertisement, now time.Time) bool {
	if row.StartDate != nil && now.Before(*row.StartDate) {
		return false
	}
	if row.EndDate != nil && now.After(*row.EndDate) {
		return false
	}
	return true
}

func adStatusLabel(row *models.Advertisement, now time.Time) string {
	if !row.IsActive {
		return "inactive"
	}
	if row.StartDate != nil && now.Before(*row.StartDate) {
		return "scheduled"
	}
	if row.EndDate != nil && now.After(*row.EndDate) {
		return "expired"
	}
	return "active"
}

func countActiveAdsNow(tid uint, now time.Time, excludeID uint) (int64, error) {
	var rows []models.Advertisement
	q := advertisementDB.Where("tenant_id = ? AND is_active = ?", tid, true)
	if excludeID > 0 {
		q = q.Where("id <> ?", excludeID)
	}
	if err := q.Find(&rows).Error; err != nil {
		return 0, err
	}
	var n int64
	for i := range rows {
		if adScheduleActive(&rows[i], now) {
			n++
		}
	}
	return n, nil
}

func publicAdMap(row models.Advertisement) fiber.Map {
	m := fiber.Map{
		"id":         row.ID,
		"title":      row.Title,
		"image_url":  row.ImageURL,
		"link_type":  row.LinkType,
		"sort_order": row.SortOrder,
	}
	if row.Subtitle != nil {
		m["subtitle"] = *row.Subtitle
	}
	if row.Tag != nil {
		m["tag"] = *row.Tag
	}
	if row.LinkValue != nil {
		m["link_value"] = *row.LinkValue
	}
	return m
}

func adminAdMap(row models.Advertisement, now time.Time) fiber.Map {
	m := fiber.Map{
		"id":          row.ID,
		"tenant_id":   row.TenantID,
		"title":       row.Title,
		"image_url":   row.ImageURL,
		"link_type":   row.LinkType,
		"sort_order":  row.SortOrder,
		"is_active":   row.IsActive,
		"impressions": row.Impressions,
		"clicks":      row.Clicks,
		"created_at":  row.CreatedAt,
		"updated_at":  row.UpdatedAt,
		"status":      adStatusLabel(&row, now),
	}
	if row.Subtitle != nil {
		m["subtitle"] = *row.Subtitle
	}
	if row.Tag != nil {
		m["tag"] = *row.Tag
	}
	if row.LinkValue != nil {
		m["link_value"] = *row.LinkValue
	}
	if row.StartDate != nil {
		m["start_date"] = row.StartDate
	}
	if row.EndDate != nil {
		m["end_date"] = row.EndDate
	}
	if row.CreatedBy != nil {
		m["created_by"] = *row.CreatedBy
	}
	return m
}

// GetActiveAdvertisementsPublic returns currently runnable ads for the mobile slider.
func GetActiveAdvertisementsPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	now := time.Now().UTC()
	var rows []models.Advertisement
	err := advertisementDB.
		Where("tenant_id = ? AND is_active = ?", tid, true).
		Order("sort_order ASC, id ASC").
		Find(&rows).Error
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	out := make([]fiber.Map, 0, len(rows))
	var etagParts []string
	var latest time.Time
	for _, row := range rows {
		if !adScheduleActive(&row, now) {
			continue
		}
		out = append(out, publicAdMap(row))
		etagParts = append(etagParts, fmt.Sprintf("%d:%d", row.ID, row.UpdatedAt.Unix()))
		if row.UpdatedAt.After(latest) {
			latest = row.UpdatedAt
		}
	}
	sum := sha1.Sum([]byte(strings.Join(etagParts, "|")))
	etag := `"` + hex.EncodeToString(sum[:]) + `"`
	if inm := strings.TrimSpace(c.Get("If-None-Match")); inm != "" && inm == etag {
		return c.SendStatus(304)
	}
	c.Set("ETag", etag)
	c.Set("Cache-Control", "public, max-age=300")
	if !latest.IsZero() {
		c.Set("Last-Modified", latest.UTC().Format(http.TimeFormat))
	}
	return c.JSON(fiber.Map{"data": out})
}

func adRateLimited(c *fiber.Ctx, action string, id uint) bool {
	ip := c.IP()
	key := fmt.Sprintf("%s:%s:%d", ip, action, id)
	adRateMu.Lock()
	defer adRateMu.Unlock()
	if t, ok := adRateLast[key]; ok && time.Since(t) < adImpressionClickCooldown {
		return true
	}
	adRateLast[key] = time.Now()
	return false
}

func RecordAdvertisementImpressionPublic(c *fiber.Ctx) error {
	id64, err := strconv.ParseUint(c.Params("id"), 10, 32)
	if err != nil || id64 == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	id := uint(id64)
	if adRateLimited(c, "imp", id) {
		return c.JSON(fiber.Map{"ok": true, "rate_limited": true})
	}
	tid := tenantIDFromCtx(c)
	res := advertisementDB.Model(&models.Advertisement{}).
		Where("id = ? AND tenant_id = ? AND is_active = ?", id, tid, true).
		UpdateColumn("impressions", gorm.Expr("impressions + 1"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func RecordAdvertisementClickPublic(c *fiber.Ctx) error {
	id64, err := strconv.ParseUint(c.Params("id"), 10, 32)
	if err != nil || id64 == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	id := uint(id64)
	if adRateLimited(c, "clk", id) {
		return c.JSON(fiber.Map{"ok": true, "rate_limited": true})
	}
	tid := tenantIDFromCtx(c)
	res := advertisementDB.Model(&models.Advertisement{}).
		Where("id = ? AND tenant_id = ? AND is_active = ?", id, tid, true).
		UpdateColumn("clicks", gorm.Expr("clicks + 1"))
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func AdminListAdvertisements(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	now := time.Now().UTC()
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	q := strings.TrimSpace(c.Query("q"))
	filter := strings.ToLower(strings.TrimSpace(c.Query("status")))

	var rows []models.Advertisement
	dbq := advertisementDB.Where("tenant_id = ?", tid)
	if q != "" {
		like := "%" + q + "%"
		dbq = dbq.Where("title ILIKE ? OR COALESCE(subtitle,'') ILIKE ? OR COALESCE(tag,'') ILIKE ?", like, like, like)
	}
	if err := dbq.Order("sort_order ASC, id ASC").Find(&rows).Error; err != nil {
		// SQLite tests don't support ILIKE — fall back to LIKE
		if strings.Contains(err.Error(), "ILIKE") || strings.Contains(strings.ToLower(err.Error()), "syntax") {
			dbq = advertisementDB.Where("tenant_id = ?", tid)
			if q != "" {
				like := "%" + q + "%"
				dbq = dbq.Where("title LIKE ? OR COALESCE(subtitle,'') LIKE ? OR COALESCE(tag,'') LIKE ?", like, like, like)
			}
			if err2 := dbq.Order("sort_order ASC, id ASC").Find(&rows).Error; err2 != nil {
				return c.Status(500).JSON(fiber.Map{"error": err2.Error()})
			}
		} else {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}

	filtered := make([]fiber.Map, 0, len(rows))
	for _, row := range rows {
		st := adStatusLabel(&row, now)
		if filter != "" && filter != "all" && st != filter {
			continue
		}
		filtered = append(filtered, adminAdMap(row, now))
	}
	total := len(filtered)
	start := (page - 1) * limit
	if start > total {
		start = total
	}
	end := start + limit
	if end > total {
		end = total
	}
	return c.JSON(fiber.Map{
		"data":  filtered[start:end],
		"total": total,
		"page":  page,
		"limit": limit,
	})
}

func sniffAdImageExt(f multipart.File) (ext string, ok bool) {
	buf := make([]byte, 512)
	n, err := f.Read(buf)
	if err != nil && err != io.EOF {
		return "", false
	}
	if _, seekErr := f.Seek(0, io.SeekStart); seekErr != nil {
		return "", false
	}
	ct := http.DetectContentType(buf[:n])
	switch ct {
	case "image/jpeg":
		return ".jpg", true
	case "image/png":
		return ".png", true
	case "image/webp":
		return ".webp", true
	default:
		// DetectContentType often returns application/octet-stream for WebP
		if n >= 12 && string(buf[0:4]) == "RIFF" && string(buf[8:12]) == "WEBP" {
			return ".webp", true
		}
		return "", false
	}
}

// resizeAdImageDownscale copies src, optionally shrinking so the longest edge
// is at most advertisementMaxEdgePx. Aspect ratio is always preserved (never stretched).
func resizeAdImageDownscale(src image.Image) *image.RGBA {
	sb := src.Bounds()
	sw, sh := sb.Dx(), sb.Dy()
	if sw < 1 || sh < 1 {
		return image.NewRGBA(image.Rect(0, 0, 1, 1))
	}

	dw, dh := sw, sh
	maxEdge := sw
	if sh > maxEdge {
		maxEdge = sh
	}
	if maxEdge > advertisementMaxEdgePx {
		scale := float64(advertisementMaxEdgePx) / float64(maxEdge)
		dw = int(float64(sw)*scale + 0.5)
		dh = int(float64(sh)*scale + 0.5)
		if dw < 1 {
			dw = 1
		}
		if dh < 1 {
			dh = 1
		}
	}

	dst := image.NewRGBA(image.Rect(0, 0, dw, dh))
	for y := 0; y < dh; y++ {
		sy := sb.Min.Y + y*sh/dh
		if sy >= sb.Max.Y {
			sy = sb.Max.Y - 1
		}
		for x := 0; x < dw; x++ {
			sx := sb.Min.X + x*sw/dw
			if sx >= sb.Max.X {
				sx = sb.Max.X - 1
			}
			dst.Set(x, y, src.At(sx, sy))
		}
	}
	return dst
}

func saveAdvertisementImage(file *multipart.FileHeader) (string, error) {
	if file.Size > maxAdvertisementImageBytes {
		return "", fmt.Errorf("image must be 2 MB or smaller")
	}
	src, err := file.Open()
	if err != nil {
		return "", err
	}
	defer src.Close()

	ext, ok := sniffAdImageExt(src)
	if !ok {
		return "", fmt.Errorf("only JPG, PNG and WebP images are allowed")
	}

	raw, err := io.ReadAll(io.LimitReader(src, maxAdvertisementImageBytes+1))
	if err != nil {
		return "", err
	}
	if len(raw) > maxAdvertisementImageBytes {
		return "", fmt.Errorf("image must be 2 MB or smaller")
	}

	base := filepath.Join("uploads", advertisementUploadSubdir)
	if err := os.MkdirAll(base, 0755); err != nil {
		return "", err
	}

	// WebP: validate signature and store as-is (stdlib has no encoder; still random filename).
	if ext == ".webp" {
		name := uuid.NewString() + ".webp"
		dstPath := filepath.Join(base, name)
		if err := os.WriteFile(dstPath, raw, 0644); err != nil {
			return "", err
		}
		return "/" + filepath.ToSlash(filepath.Join("uploads", advertisementUploadSubdir, name)), nil
	}

	img, _, err := image.Decode(bytes.NewReader(raw))
	if err != nil {
		return "", fmt.Errorf("could not decode image: %v", err)
	}
	resized := resizeAdImageDownscale(img)
	name := uuid.NewString() + ".jpg"
	dstPath := filepath.Join(base, name)
	out, err := os.Create(dstPath)
	if err != nil {
		return "", err
	}
	defer out.Close()
	if err := jpeg.Encode(out, resized, &jpeg.Options{Quality: 85}); err != nil {
		_ = os.Remove(dstPath)
		return "", err
	}
	return "/" + filepath.ToSlash(filepath.Join("uploads", advertisementUploadSubdir, name)), nil
}

func deleteLocalUploadIfOwned(urlPath string) {
	urlPath = strings.TrimSpace(urlPath)
	if !strings.HasPrefix(urlPath, "/uploads/"+advertisementUploadSubdir+"/") {
		return
	}
	rel := strings.TrimPrefix(urlPath, "/")
	_ = os.Remove(filepath.FromSlash(rel))
}

func parseAdFormOrJSON(c *fiber.Ctx) (title, subtitle, tag, linkType string, linkValue *string, sortOrder *int, isActive *bool, start, end *time.Time, imageURL string, hasImage bool, err error) {
	ct := strings.ToLower(c.Get("Content-Type"))
	if strings.Contains(ct, "multipart/form-data") {
		title = strings.TrimSpace(c.FormValue("title"))
		subtitle = strings.TrimSpace(c.FormValue("subtitle"))
		tag = strings.TrimSpace(c.FormValue("tag"))
		linkType = strings.TrimSpace(c.FormValue("link_type"))
		if linkType == "" {
			linkType = "none"
		}
		lv := strings.TrimSpace(c.FormValue("link_value"))
		if lv != "" {
			linkValue = &lv
		}
		if s := strings.TrimSpace(c.FormValue("sort_order")); s != "" {
			n, e := strconv.Atoi(s)
			if e != nil {
				err = fmt.Errorf("invalid sort_order")
				return
			}
			sortOrder = &n
		}
		if s := strings.TrimSpace(c.FormValue("is_active")); s != "" {
			b := s == "1" || strings.EqualFold(s, "true") || s == "on"
			isActive = &b
		}
		start, err = parseOptionalAdDate(c.FormValue("start_date"))
		if err != nil {
			return
		}
		end, err = parseOptionalAdDate(c.FormValue("end_date"))
		if err != nil {
			return
		}
		fh, ferr := c.FormFile("image")
		if ferr == nil && fh != nil {
			imageURL, err = saveAdvertisementImage(fh)
			if err != nil {
				return
			}
			hasImage = true
		} else if existing := strings.TrimSpace(c.FormValue("image_url")); existing != "" {
			imageURL = existing
		}
		return
	}

	var body struct {
		Title     string  `json:"title"`
		Subtitle  *string `json:"subtitle"`
		Tag       *string `json:"tag"`
		ImageURL  string  `json:"image_url"`
		LinkType  string  `json:"link_type"`
		LinkValue *string `json:"link_value"`
		SortOrder *int    `json:"sort_order"`
		IsActive  *bool   `json:"is_active"`
		StartDate *string `json:"start_date"`
		EndDate   *string `json:"end_date"`
	}
	if e := c.BodyParser(&body); e != nil {
		err = fmt.Errorf("invalid body")
		return
	}
	title = strings.TrimSpace(body.Title)
	if body.Subtitle != nil {
		subtitle = strings.TrimSpace(*body.Subtitle)
	}
	if body.Tag != nil {
		tag = strings.TrimSpace(*body.Tag)
	}
	imageURL = strings.TrimSpace(body.ImageURL)
	linkType = strings.TrimSpace(body.LinkType)
	if linkType == "" {
		linkType = "none"
	}
	linkValue = body.LinkValue
	sortOrder = body.SortOrder
	isActive = body.IsActive
	if body.StartDate != nil {
		start, err = parseOptionalAdDate(*body.StartDate)
		if err != nil {
			return
		}
	}
	if body.EndDate != nil {
		end, err = parseOptionalAdDate(*body.EndDate)
		if err != nil {
			return
		}
	}
	return
}

func AdminCreateAdvertisement(c *fiber.Ctx) error {
	title, subtitle, tag, linkType, linkValue, sortOrder, isActive, start, end, imageURL, hasImage, err := parseAdFormOrJSON(c)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	if title == "" {
		return c.Status(400).JSON(fiber.Map{"error": "title is required"})
	}
	if len(title) > 80 {
		return c.Status(400).JSON(fiber.Map{"error": "title max length is 80"})
	}
	if len(subtitle) > 120 {
		return c.Status(400).JSON(fiber.Map{"error": "subtitle max length is 120"})
	}
	if imageURL == "" {
		return c.Status(400).JSON(fiber.Map{"error": "image is required (multipart field \"image\" or image_url)"})
	}
	if err := validateAdLink(linkType, linkValue); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	tid := tenantIDFromCtx(c)
	now := time.Now().UTC()
	active := true
	if isActive != nil {
		active = *isActive
	}
	order := 0
	if sortOrder != nil {
		order = *sortOrder
	}
	if order == 0 {
		var last models.Advertisement
		err := advertisementDB.Where("tenant_id = ?", tid).Order("sort_order DESC").First(&last).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			order = 10
		} else if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		} else {
			order = last.SortOrder + 10
		}
	}

	willBeActive := active && adScheduleActive(&models.Advertisement{IsActive: active, StartDate: start, EndDate: end}, now)
	if willBeActive {
		n, err := countActiveAdsNow(tid, now, 0)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		if n >= maxActiveAdvertisements {
			if hasImage {
				deleteLocalUploadIfOwned(imageURL)
			}
			return c.Status(400).JSON(fiber.Map{"error": fmt.Sprintf("limit of %d active advertisements reached", maxActiveAdvertisements)})
		}
	}

	var subPtr, tagPtr *string
	if subtitle != "" {
		subPtr = &subtitle
	}
	if tag != "" {
		tagPtr = &tag
	}
	createdBy := adUserIDFromCtx(c)
	row := models.Advertisement{
		TenantID:  tid,
		Title:     title,
		Subtitle:  subPtr,
		Tag:       tagPtr,
		ImageURL:  imageURL,
		LinkType:  linkType,
		LinkValue: linkValue,
		SortOrder: order,
		IsActive:  active,
		StartDate: start,
		EndDate:   end,
		CreatedBy: createdBy,
	}
	// Create via map so is_active=false is persisted (GORM skips bool zero with default:true).
	createMap := map[string]interface{}{
		"tenant_id":  row.TenantID,
		"title":      row.Title,
		"subtitle":   row.Subtitle,
		"tag":        row.Tag,
		"image_url":  row.ImageURL,
		"link_type":  row.LinkType,
		"link_value": row.LinkValue,
		"sort_order": row.SortOrder,
		"is_active":  row.IsActive,
		"start_date": row.StartDate,
		"end_date":   row.EndDate,
		"created_by": row.CreatedBy,
	}
	if err := advertisementDB.Model(&models.Advertisement{}).Create(createMap).Error; err != nil {
		if hasImage {
			deleteLocalUploadIfOwned(imageURL)
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var created models.Advertisement
	advertisementDB.Where("tenant_id = ? AND title = ?", tid, title).Order("id DESC").First(&created)
	return c.Status(201).JSON(fiber.Map{"data": adminAdMap(created, now)})
}

func AdminUpdateAdvertisement(c *fiber.Ctx) error {
	id64, err := strconv.ParseUint(c.Params("id"), 10, 32)
	if err != nil || id64 == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	id := uint(id64)
	tid := tenantIDFromCtx(c)
	now := time.Now().UTC()

	var row models.Advertisement
	if err := advertisementDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	title, subtitle, tag, linkType, linkValue, sortOrder, isActive, start, end, imageURL, hasImage, err := parseAdFormOrJSON(c)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	oldImage := row.ImageURL
	updates := map[string]interface{}{}
	if title != "" {
		if len(title) > 80 {
			return c.Status(400).JSON(fiber.Map{"error": "title max length is 80"})
		}
		updates["title"] = title
		row.Title = title
	}
	if subtitle != "" || c.FormValue("subtitle") != "" || strings.Contains(strings.ToLower(c.Get("Content-Type")), "json") {
		if len(subtitle) > 120 {
			return c.Status(400).JSON(fiber.Map{"error": "subtitle max length is 120"})
		}
		if subtitle == "" {
			updates["subtitle"] = nil
			row.Subtitle = nil
		} else {
			updates["subtitle"] = subtitle
			row.Subtitle = &subtitle
		}
	}
	if tag != "" || c.FormValue("tag") != "" {
		if tag == "" {
			updates["tag"] = nil
			row.Tag = nil
		} else {
			updates["tag"] = tag
			row.Tag = &tag
		}
	}
	if linkType != "" && linkType != "none" || c.FormValue("link_type") != "" || strings.Contains(strings.ToLower(c.Get("Content-Type")), "application/json") {
		if linkType == "" {
			linkType = row.LinkType
		}
		lv := linkValue
		if lv == nil {
			lv = row.LinkValue
		}
		if err := validateAdLink(linkType, lv); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		}
		updates["link_type"] = linkType
		row.LinkType = linkType
		if lv == nil || (lv != nil && strings.TrimSpace(*lv) == "") {
			updates["link_value"] = nil
			row.LinkValue = nil
		} else {
			updates["link_value"] = *lv
			row.LinkValue = lv
		}
	}
	if sortOrder != nil {
		updates["sort_order"] = *sortOrder
		row.SortOrder = *sortOrder
	}
	if isActive != nil {
		updates["is_active"] = *isActive
		row.IsActive = *isActive
	}
	if start != nil || strings.TrimSpace(c.FormValue("start_date")) != "" {
		updates["start_date"] = start
		row.StartDate = start
	}
	if end != nil || strings.TrimSpace(c.FormValue("end_date")) != "" {
		updates["end_date"] = end
		row.EndDate = end
	}
	if hasImage || imageURL != "" {
		if imageURL != "" {
			updates["image_url"] = imageURL
			row.ImageURL = imageURL
		}
	}

	willBeActive := row.IsActive && adScheduleActive(&row, now)
	if willBeActive {
		n, err := countActiveAdsNow(tid, now, id)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		if n >= maxActiveAdvertisements {
			if hasImage {
				deleteLocalUploadIfOwned(imageURL)
			}
			return c.Status(400).JSON(fiber.Map{"error": fmt.Sprintf("limit of %d active advertisements reached", maxActiveAdvertisements)})
		}
	}

	if len(updates) == 0 {
		return c.JSON(fiber.Map{"data": adminAdMap(row, now)})
	}
	if err := advertisementDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if hasImage && oldImage != imageURL {
		deleteLocalUploadIfOwned(oldImage)
	}
	advertisementDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row)
	return c.JSON(fiber.Map{"data": adminAdMap(row, now)})
}

func AdminPatchAdvertisementStatus(c *fiber.Ctx) error {
	id64, err := strconv.ParseUint(c.Params("id"), 10, 32)
	if err != nil || id64 == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	id := uint(id64)
	tid := tenantIDFromCtx(c)
	now := time.Now().UTC()

	var body struct {
		IsActive *bool `json:"is_active"`
	}
	if err := c.BodyParser(&body); err != nil || body.IsActive == nil {
		return c.Status(400).JSON(fiber.Map{"error": "is_active is required"})
	}

	var row models.Advertisement
	if err := advertisementDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	if *body.IsActive {
		row.IsActive = true
		if adScheduleActive(&row, now) {
			n, err := countActiveAdsNow(tid, now, id)
			if err != nil {
				return c.Status(500).JSON(fiber.Map{"error": err.Error()})
			}
			if n >= maxActiveAdvertisements {
				return c.Status(400).JSON(fiber.Map{"error": fmt.Sprintf("limit of %d active advertisements reached", maxActiveAdvertisements)})
			}
		}
	}

	if err := advertisementDB.Model(&row).Update("is_active", *body.IsActive).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	row.IsActive = *body.IsActive
	return c.JSON(fiber.Map{"data": adminAdMap(row, now)})
}

func AdminReorderAdvertisements(c *fiber.Ctx) error {
	var body struct {
		IDs []uint `json:"ids"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid body", "details": err.Error()})
	}
	if len(body.IDs) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "ids is required"})
	}
	tid := tenantIDFromCtx(c)
	if err := advertisementDB.Transaction(func(tx *gorm.DB) error {
		for i, id := range body.IDs {
			if id == 0 {
				continue
			}
			order := (i + 1) * 10
			r := tx.Model(&models.Advertisement{}).
				Where("id = ? AND tenant_id = ?", id, tid).
				Update("sort_order", order)
			if r.Error != nil {
				return r.Error
			}
		}
		return nil
	}); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func AdminDeleteAdvertisement(c *fiber.Ctx) error {
	id64, err := strconv.ParseUint(c.Params("id"), 10, 32)
	if err != nil || id64 == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	id := uint(id64)
	tid := tenantIDFromCtx(c)

	var row models.Advertisement
	if err := advertisementDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	img := row.ImageURL
	res := advertisementDB.Delete(&row)
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	deleteLocalUploadIfOwned(img)
	return c.JSON(fiber.Map{"ok": true})
}
