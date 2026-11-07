package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"github.com/glebarez/sqlite"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupAdApp(t *testing.T) *fiber.App {
	t.Helper()
	dsn := fmt.Sprintf("file:%s?mode=memory&cache=shared",
		strings.ReplaceAll(t.Name(), "/", "_"))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.Advertisement{}); err != nil {
		t.Fatal(err)
	}
	SetAdvertisementDB(db)

	app := fiber.New(fiber.Config{BodyLimit: 8 << 20})
	app.Use(func(c *fiber.Ctx) error {
		c.Locals(middleware.CtxTenantID, uint(1))
		return c.Next()
	})
	api := app.Group("/api")
	api.Get("/advertisements/active", GetActiveAdvertisementsPublic)
	api.Post("/advertisements/:id/impression", RecordAdvertisementImpressionPublic)
	api.Post("/advertisements/:id/click", RecordAdvertisementClickPublic)

	admin := api.Group("/admin", func(c *fiber.Ctx) error {
		auth := c.Get("Authorization")
		if auth == "" {
			return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
		}
		return c.Next()
	})
	admin.Get("/advertisements", AdminListAdvertisements)
	admin.Post("/advertisements", AdminCreateAdvertisement)
	admin.Put("/advertisements/reorder", AdminReorderAdvertisements)
	admin.Put("/advertisements/:id", AdminUpdateAdvertisement)
	admin.Patch("/advertisements/:id/status", AdminPatchAdvertisementStatus)
	admin.Delete("/advertisements/:id", AdminDeleteAdvertisement)
	return app
}

func adJSON(t *testing.T, app *fiber.App, method, path string, body any, auth bool) (int, map[string]any) {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		rdr = bytes.NewReader(raw)
	}
	req := httptest.NewRequest(method, path, rdr)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if auth {
		req.Header.Set("Authorization", "Bearer test-token")
	}
	resp, err := app.Test(req, 8000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	out := map[string]any{}
	_ = json.Unmarshal(raw, &out)
	return resp.StatusCode, out
}

func makeTestJPEG(t *testing.T) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 100, 40))
	for y := 0; y < 40; y++ {
		for x := 0; x < 100; x++ {
			img.Set(x, y, color.RGBA{20, 96, 63, 255})
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 80}); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func adMultipartCreate(t *testing.T, app *fiber.App, fields map[string]string, filename string, fileBytes []byte, auth bool) (int, map[string]any) {
	t.Helper()
	var body bytes.Buffer
	w := multipart.NewWriter(&body)
	for k, v := range fields {
		_ = w.WriteField(k, v)
	}
	if fileBytes != nil {
		part, err := w.CreateFormFile("image", filename)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := part.Write(fileBytes); err != nil {
			t.Fatal(err)
		}
	}
	_ = w.Close()
	req := httptest.NewRequest(http.MethodPost, "/api/admin/advertisements", &body)
	req.Header.Set("Content-Type", w.FormDataContentType())
	if auth {
		req.Header.Set("Authorization", "Bearer test-token")
	}
	resp, err := app.Test(req, 15000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	out := map[string]any{}
	_ = json.Unmarshal(raw, &out)
	return resp.StatusCode, out
}

func TestAdvertisementCreateAndListActive(t *testing.T) {
	cwd, _ := os.Getwd()
	tmp := t.TempDir()
	if err := os.Chdir(tmp); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(cwd) })

	app := setupAdApp(t)
	code, created := adMultipartCreate(t, app, map[string]string{
		"title":     "Smart Farming, Simplified",
		"subtitle":  "Test subtitle",
		"tag":       "AD",
		"link_type": "none",
		"is_active": "true",
	}, "hero.jpg", makeTestJPEG(t), true)
	if code != 201 {
		t.Fatalf("create status %d: %v", code, created)
	}
	data, _ := created["data"].(map[string]any)
	if data["title"] != "Smart Farming, Simplified" {
		t.Fatalf("unexpected title: %v", data)
	}
	imgURL, _ := data["image_url"].(string)
	if !strings.HasPrefix(imgURL, "/uploads/advertisements/") {
		t.Fatalf("unexpected image_url: %s", imgURL)
	}
	if _, err := os.Stat(filepath.FromSlash(strings.TrimPrefix(imgURL, "/"))); err != nil {
		t.Fatalf("uploaded file missing: %v", err)
	}

	code, active := adJSON(t, app, http.MethodGet, "/api/advertisements/active", nil, false)
	if code != 200 {
		t.Fatalf("active status %d", code)
	}
	list, _ := active["data"].([]any)
	if len(list) != 1 {
		t.Fatalf("expected 1 active ad, got %d: %v", len(list), active)
	}
}

func TestAdvertisementActiveFiltersByDateAndStatus(t *testing.T) {
	app := setupAdApp(t)
	now := time.Now().UTC()
	past := now.Add(-48 * time.Hour)
	futureStart := now.Add(24 * time.Hour)
	futureEnd := now.Add(72 * time.Hour)
	expiredEnd := now.Add(-1 * time.Hour)

	// Use maps so GORM does not skip bool false (zero value) when column has default:true.
	seeds := []map[string]interface{}{
		{"tenant_id": 1, "title": "Live", "image_url": "/uploads/advertisements/a.jpg", "link_type": "none", "sort_order": 10, "is_active": true},
		{"tenant_id": 1, "title": "Inactive", "image_url": "/uploads/advertisements/b.jpg", "link_type": "none", "sort_order": 20, "is_active": false},
		{"tenant_id": 1, "title": "Scheduled", "image_url": "/uploads/advertisements/c.jpg", "link_type": "none", "sort_order": 30, "is_active": true, "start_date": futureStart, "end_date": futureEnd},
		{"tenant_id": 1, "title": "Expired", "image_url": "/uploads/advertisements/d.jpg", "link_type": "none", "sort_order": 40, "is_active": true, "start_date": past, "end_date": expiredEnd},
	}
	for _, row := range seeds {
		if err := advertisementDB.Model(&models.Advertisement{}).Create(row).Error; err != nil {
			t.Fatal(err)
		}
	}

	code, active := adJSON(t, app, http.MethodGet, "/api/advertisements/active", nil, false)
	if code != 200 {
		t.Fatalf("status %d", code)
	}
	list, _ := active["data"].([]any)
	if len(list) != 1 {
		t.Fatalf("expected only live ad, got %d: %v", len(list), active)
	}
	item := list[0].(map[string]any)
	if item["title"] != "Live" {
		t.Fatalf("expected Live, got %v", item["title"])
	}

	code, adminList := adJSON(t, app, http.MethodGet, "/api/admin/advertisements?status=scheduled", nil, true)
	if code != 200 {
		t.Fatalf("admin list %d", code)
	}
	alist, _ := adminList["data"].([]any)
	if len(alist) != 1 || alist[0].(map[string]any)["title"] != "Scheduled" {
		t.Fatalf("scheduled filter failed: %v", adminList)
	}
}

func TestAdvertisementReorder(t *testing.T) {
	app := setupAdApp(t)
	a := models.Advertisement{TenantID: 1, Title: "A", ImageURL: "/x.jpg", LinkType: "none", SortOrder: 10, IsActive: true}
	b := models.Advertisement{TenantID: 1, Title: "B", ImageURL: "/y.jpg", LinkType: "none", SortOrder: 20, IsActive: true}
	if err := advertisementDB.Create(&a).Error; err != nil {
		t.Fatal(err)
	}
	if err := advertisementDB.Create(&b).Error; err != nil {
		t.Fatal(err)
	}
	code, out := adJSON(t, app, http.MethodPut, "/api/admin/advertisements/reorder", map[string]any{
		"ids": []uint{b.ID, a.ID},
	}, true)
	if code != 200 || out["ok"] != true {
		t.Fatalf("reorder failed: %d %v", code, out)
	}
	code, active := adJSON(t, app, http.MethodGet, "/api/advertisements/active", nil, false)
	if code != 200 {
		t.Fatal(code)
	}
	list := active["data"].([]any)
	if list[0].(map[string]any)["title"] != "B" {
		t.Fatalf("order not updated: %v", list)
	}
}

func TestAdvertisementAdminAuthRequired(t *testing.T) {
	app := setupAdApp(t)
	code, _ := adJSON(t, app, http.MethodGet, "/api/admin/advertisements", nil, false)
	if code != 401 {
		t.Fatalf("expected 401, got %d", code)
	}
	code, _ = adJSON(t, app, http.MethodPost, "/api/admin/advertisements", map[string]any{
		"title": "x", "image_url": "/uploads/advertisements/x.jpg", "link_type": "none",
	}, false)
	if code != 401 {
		t.Fatalf("expected 401 on create, got %d", code)
	}
}

func TestAdvertisementInvalidFileRejected(t *testing.T) {
	cwd, _ := os.Getwd()
	tmp := t.TempDir()
	if err := os.Chdir(tmp); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(cwd) })

	app := setupAdApp(t)
	code, out := adMultipartCreate(t, app, map[string]string{
		"title":     "Bad file",
		"link_type": "none",
	}, "note.txt", []byte("not an image"), true)
	if code != 400 {
		t.Fatalf("expected 400, got %d: %v", code, out)
	}
	errMsg, _ := out["error"].(string)
	if !strings.Contains(strings.ToLower(errMsg), "jpg") && !strings.Contains(strings.ToLower(errMsg), "image") {
		t.Fatalf("unexpected error: %v", out)
	}
}
