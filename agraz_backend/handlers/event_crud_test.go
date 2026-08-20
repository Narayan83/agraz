package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"github.com/glebarez/sqlite"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupEventCRUDApp(t *testing.T, ownerID uint) *fiber.App {
	t.Helper()
	db, err := gorm.Open(sqlite.Open("file::memory:?cache=shared"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.ManagedEvent{}); err != nil {
		t.Fatal(err)
	}
	SetEventDB(db)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", ownerID)
		c.Locals(middleware.CtxOwnerUserID, ownerID)
		return c.Next()
	})
	api := app.Group("/api")
	api.Get("/events", ListEvents)
	api.Post("/events", CreateEvent)
	api.Put("/events/:id", UpdateEvent)
	api.Delete("/events/:id", DeleteEvent)
	api.Get("/admin/events", AdminListEvents)
	api.Post("/admin/events", AdminCreateEvent)
	api.Put("/admin/events/:id", AdminUpdateEvent)
	api.Delete("/admin/events/:id", AdminDeleteEvent)
	return app
}

func eventReq(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any, string) {
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
	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	out := map[string]any{}
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &out)
	}
	return resp.StatusCode, out, string(raw)
}

func eventJSON(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any) {
	t.Helper()
	code, out, _ := eventReq(t, app, method, path, body)
	return code, out
}

func TestEventCRUD(t *testing.T) {
	app := setupEventCRUDApp(t, 7)

	code, created := eventJSON(t, app, http.MethodPost, "/api/events", map[string]any{
		"name":        " Ravi birthday ",
		"event_date":  "1998-05-20",
		"recurrence":  "yearly",
		"notify_time": "08:30",
	})
	if code != 201 {
		t.Fatalf("create status %d body=%v", code, created)
	}
	data, _ := created["data"].(map[string]any)
	id := fmt.Sprint(data["id"])
	if id == "" || id == "<nil>" {
		t.Fatalf("missing id: %v", created)
	}
	if data["name"] != "Ravi birthday" {
		t.Fatalf("name not trimmed: %v", data["name"])
	}
	if data["recurrence"] != "yearly" || data["notify_time"] != "08:30" {
		t.Fatalf("fields: %v", data)
	}

	code, listed := eventJSON(t, app, http.MethodGet, "/api/events", nil)
	if code != 200 {
		t.Fatalf("list status %d", code)
	}
	rows, _ := listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 row, got %v", listed)
	}

	code, listed = eventJSON(t, app, http.MethodGet, "/api/events?q=ravi", nil)
	if code != 200 {
		t.Fatalf("search status %d", code)
	}
	rows, _ = listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("search missed row: %v", listed)
	}

	code, updated := eventJSON(t, app, http.MethodPut, "/api/events/"+id, map[string]any{
		"name":        "LIC renewal",
		"event_date":  "2026-09-01",
		"recurrence":  "monthly",
		"notify_time": "18:05",
	})
	if code != 200 {
		t.Fatalf("update status %d body=%v", code, updated)
	}
	data, _ = updated["data"].(map[string]any)
	if data["name"] != "LIC renewal" || data["recurrence"] != "monthly" || data["notify_time"] != "18:05" {
		t.Fatalf("update fields: %v", data)
	}

	code, listed = eventJSON(t, app, http.MethodGet, "/api/events", nil)
	if code != 200 {
		t.Fatalf("list after update %d", code)
	}
	rows, _ = listed["data"].([]any)
	first, _ := rows[0].(map[string]any)
	if first["name"] != "LIC renewal" {
		t.Fatalf("list not updated: %v", first)
	}

	code, deleted := eventJSON(t, app, http.MethodDelete, "/api/events/"+id, nil)
	if code != 200 {
		t.Fatalf("delete status %d body=%v", code, deleted)
	}
	code, listed = eventJSON(t, app, http.MethodGet, "/api/events", nil)
	rows, _ = listed["data"].([]any)
	if code != 200 || len(rows) != 0 {
		t.Fatalf("want empty list after delete, got %v", listed)
	}

	code, missing := eventJSON(t, app, http.MethodDelete, "/api/events/"+id, nil)
	if code != 404 {
		t.Fatalf("second delete want 404, got %d %v", code, missing)
	}
}

func TestEventCreateValidation(t *testing.T) {
	app := setupEventCRUDApp(t, 3)

	code, body, raw := eventReq(t, app, http.MethodPost, "/api/events", map[string]any{
		"name":       "",
		"event_date": "2026-08-20",
	})
	if code != 400 || !strings.Contains(raw+fmt.Sprint(body["error"]), "name") {
		t.Fatalf("blank name: %d %v %q", code, body, raw)
	}

	code, body, _ = eventReq(t, app, http.MethodPost, "/api/events", map[string]any{
		"name":       "X",
		"event_date": "20-08-2026",
	})
	if code != 400 {
		t.Fatalf("bad date want 400, got %d %v", code, body)
	}

	code, body = eventJSON(t, app, http.MethodPost, "/api/events", map[string]any{
		"name":        "Daily pill",
		"event_date":  "2026-08-20",
		"recurrence":  "daily",
		"notify_time": "7:30",
	})
	if code != 201 {
		t.Fatalf("daily create %d %v", code, body)
	}
	data, _ := body["data"].(map[string]any)
	if data["notify_time"] != "07:30" || data["recurrence"] != "daily" {
		t.Fatalf("normalized fields: %v", data)
	}
}

func TestAdminEventCRUDScopedToUser(t *testing.T) {
	app := setupEventCRUDApp(t, 1)

	code, created := eventJSON(t, app, http.MethodPost, "/api/admin/events", map[string]any{
		"user_id":     42,
		"name":        "Admin birthday",
		"event_date":  "2001-01-15",
		"recurrence":  "yearly",
		"notify_time": "09:00",
	})
	if code != 201 {
		t.Fatalf("admin create %d %v", code, created)
	}
	data, _ := created["data"].(map[string]any)
	id := fmt.Sprint(data["id"])

	code, listed := eventJSON(t, app, http.MethodGet, "/api/admin/events?user_id=42", nil)
	if code != 200 {
		t.Fatalf("admin list %d", code)
	}
	rows, _ := listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("admin list for 42: %v", listed)
	}

	code, other := eventJSON(t, app, http.MethodGet, "/api/admin/events?user_id=99", nil)
	if code != 200 {
		t.Fatalf("admin list other %d", code)
	}
	rows, _ = other["data"].([]any)
	if len(rows) != 0 {
		t.Fatalf("user 99 should have no events: %v", other)
	}

	code, listed = eventJSON(t, app, http.MethodGet, "/api/events", nil)
	rows, _ = listed["data"].([]any)
	if code != 200 || len(rows) != 0 {
		t.Fatalf("owner 1 must not see user 42 events: %v", listed)
	}

	code, _ = eventJSON(t, app, http.MethodPut, "/api/admin/events/"+id, map[string]any{
		"user_id":     42,
		"name":        "Admin birthday updated",
		"event_date":  "2001-01-15",
		"recurrence":  "yearly",
		"notify_time": "10:15",
	})
	if code != 200 {
		t.Fatalf("admin update %d", code)
	}

	code, _ = eventJSON(t, app, http.MethodDelete, "/api/admin/events/"+id+"?user_id=42", nil)
	if code != 200 {
		t.Fatalf("admin delete %d", code)
	}

	code, listed = eventJSON(t, app, http.MethodGet, "/api/admin/events?user_id=42", nil)
	rows, _ = listed["data"].([]any)
	if code != 200 || len(rows) != 0 {
		t.Fatalf("admin list after delete: %v", listed)
	}

	code, missing, raw := eventReq(t, app, http.MethodGet, "/api/admin/events", nil)
	if code != 400 || !strings.Contains(raw+fmt.Sprint(missing["error"]), "user_id") {
		t.Fatalf("admin list without user_id: %d %v %q", code, missing, raw)
	}
}
