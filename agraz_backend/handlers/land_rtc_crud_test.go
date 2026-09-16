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

func setupLandRtcCRUDApp(t *testing.T, ownerID uint) *fiber.App {
	t.Helper()
	dsn := fmt.Sprintf("file:%s?mode=memory&cache=shared",
		strings.ReplaceAll(t.Name(), "/", "_"))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.LandRtc{}, &models.User{}); err != nil {
		t.Fatal(err)
	}
	SetLandRtcDB(db)
	SetUserDB(db)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", ownerID)
		c.Locals(middleware.CtxOwnerUserID, ownerID)
		return c.Next()
	})
	api := app.Group("/api")
	api.Get("/land_rtcs", ListMyLandRtcs)
	api.Get("/land_rtcs/:id", GetMyLandRtc)
	api.Post("/land_rtcs", CreateLandRtc)
	api.Put("/land_rtcs/:id", UpdateLandRtc)
	api.Delete("/land_rtcs/:id", DeleteLandRtc)
	api.Get("/admin/land_rtcs", AdminListLandRtcs)
	api.Get("/admin/land_rtcs/:id", AdminGetLandRtc)
	api.Post("/admin/land_rtcs", AdminCreateLandRtc)
	api.Put("/admin/land_rtcs/:id", AdminUpdateLandRtc)
	api.Delete("/admin/land_rtcs/:id", AdminDeleteLandRtc)
	return app
}

func rtcReq(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any, string) {
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
	resp, err := app.Test(req, 8000)
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

func rtcJSON(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any) {
	t.Helper()
	code, out, _ := rtcReq(t, app, method, path, body)
	return code, out
}

func TestLandRtcCRUD(t *testing.T) {
	app := setupLandRtcCRUDApp(t, 11)

	code, created := rtcJSON(t, app, http.MethodPost, "/api/land_rtcs", map[string]any{
		"state":          "Karnataka",
		"district":       "Uttara Kannada",
		"taluk":          "Sirsi",
		"hobli":          "Sampakanda",
		"grama":          " Janmane ",
		"survey_number":  " 12/3 ",
		"hissa":          "1",
		"acre":           1,
		"gunta":          10,
		"ana":            2,
		"details":        "arecanut",
	})
	if code != 201 {
		t.Fatalf("create status %d body=%v", code, created)
	}
	id := fmt.Sprint(created["id"])
	if id == "" || id == "<nil>" || id == "0" {
		t.Fatalf("missing id: %v", created)
	}
	if created["hobli"] != "Sampakanda" {
		t.Fatalf("hobli: %v", created["hobli"])
	}
	if created["grama"] != "Janmane" {
		t.Fatalf("grama not trimmed: %v", created["grama"])
	}
	if created["survey_number"] != "12/3" {
		t.Fatalf("survey: %v", created["survey_number"])
	}

	code, listed := rtcJSON(t, app, http.MethodGet, "/api/land_rtcs", nil)
	if code != 200 {
		t.Fatalf("list status %d body=%v", code, listed)
	}
	rows, _ := listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 row, got %v", listed)
	}

	code, got := rtcJSON(t, app, http.MethodGet, "/api/land_rtcs/"+id, nil)
	if code != 200 || fmt.Sprint(got["grama"]) != "Janmane" {
		t.Fatalf("get: %d %v", code, got)
	}

	code, updated := rtcJSON(t, app, http.MethodPut, "/api/land_rtcs/"+id, map[string]any{
		"taluk":         "Siddapur",
		"hobli":         "Kansur",
		"grama":         "Siddapur",
		"survey_number": "12/3",
		"hissa":         "2",
		"acre":          2,
		"gunta":         0,
		"ana":           0,
		"details":       "updated",
	})
	if code != 200 {
		t.Fatalf("update status %d body=%v", code, updated)
	}
	if updated["taluk"] != "Siddapur" || updated["hobli"] != "Kansur" || updated["grama"] != "Siddapur" {
		t.Fatalf("update fields: %v", updated)
	}

	code, missing := rtcJSON(t, app, http.MethodPost, "/api/land_rtcs", map[string]any{
		"taluk": "Yellapur",
		"hobli": "Yellapur",
		"grama": "Yellapur",
	})
	if code != 400 {
		t.Fatalf("missing survey should 400, got %d %v", code, missing)
	}

	code, del := rtcJSON(t, app, http.MethodDelete, "/api/land_rtcs/"+id, nil)
	if code != 200 {
		t.Fatalf("delete status %d body=%v", code, del)
	}
	code, listed = rtcJSON(t, app, http.MethodGet, "/api/land_rtcs", nil)
	rows, _ = listed["data"].([]any)
	if code != 200 || len(rows) != 0 {
		t.Fatalf("list after delete: %v", listed)
	}
}

func TestAdminLandRtcCRUD(t *testing.T) {
	app := setupLandRtcCRUDApp(t, 1)

	code, created := rtcJSON(t, app, http.MethodPost, "/api/admin/land_rtcs", map[string]any{
		"user_id":       42,
		"taluk":         "Yellapur",
		"hobli":         "Kirwatti",
		"grama":         "Yellapur",
		"survey_number": "88",
		"acre":          0,
		"gunta":         20,
		"ana":           0,
	})
	if code != 201 {
		t.Fatalf("admin create %d body=%v", code, created)
	}
	id := fmt.Sprint(created["id"])
	if created["grama"] != "Yellapur" || created["hobli"] != "Kirwatti" {
		t.Fatalf("admin create fields: %v", created)
	}

	code, listed := rtcJSON(t, app, http.MethodGet, "/api/admin/land_rtcs", nil)
	if code != 200 {
		t.Fatalf("admin list %d body=%v", code, listed)
	}
	rows, _ := listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("admin search missed grama: %v", listed)
	}

	code, updated := rtcJSON(t, app, http.MethodPut, "/api/admin/land_rtcs/"+id, map[string]any{
		"user_id":       42,
		"taluk":         "Sirsi",
		"hobli":         "Sampakanda",
		"grama":         "Sampakanda",
		"survey_number": "88",
		"acre":          1,
	})
	if code != 200 {
		t.Fatalf("admin update %d body=%v", code, updated)
	}
	if updated["hobli"] != "Sampakanda" || updated["grama"] != "Sampakanda" {
		t.Fatalf("admin update fields: %v", updated)
	}

	code, _ = rtcJSON(t, app, http.MethodDelete, "/api/admin/land_rtcs/"+id, nil)
	if code != 200 {
		t.Fatalf("admin delete %d", code)
	}
	code, listed = rtcJSON(t, app, http.MethodGet, "/api/admin/land_rtcs", nil)
	rows, _ = listed["data"].([]any)
	if code != 200 || len(rows) != 0 {
		t.Fatalf("admin list after delete: %v", listed)
	}
}
