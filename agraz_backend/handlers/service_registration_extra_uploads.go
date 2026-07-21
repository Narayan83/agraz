package handler

import (
	"encoding/json"
	"os"
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/datatypes"
)

// UploadServiceProviderPhoto stores one image as the service provider profile photo (multipart field "photo").
func UploadServiceProviderPhoto(c *fiber.Ctx) error {
	id := c.Params("id")
	form, err := c.MultipartForm()
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "multipart form required", "details": err.Error()})
	}
	files := form.File["photo"]
	if len(files) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "use multipart field \"photo\""})
	}
	if len(files) > 1 {
		return c.Status(400).JSON(fiber.Map{"error": "send only one file"})
	}

	var row models.ServiceRegistration
	if err := serviceRegistrationDB.First(&row, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "registration not found"})
	}

	path, err := saveSingleServiceRegImage(id, files[0], "provider")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	if row.ServiceProviderPhoto != nil && strings.TrimSpace(*row.ServiceProviderPhoto) != "" {
		rel := strings.TrimPrefix(*row.ServiceProviderPhoto, "/")
		if !strings.Contains(rel, "..") {
			_ = os.Remove(rel)
		}
	}

	if err := serviceRegistrationDB.Model(&row).Update("service_provider_photo", path).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	serviceRegistrationDB.First(&row, row.ID)
	return c.Status(201).JSON(fiber.Map{"url": path, "record": row})
}

// UploadCustomServiceImage stores one image for custom services list; returns URL path only (client merges into custom_services JSON on save).
func UploadCustomServiceImage(c *fiber.Ctx) error {
	id := c.Params("id")
	form, err := c.MultipartForm()
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "multipart form required", "details": err.Error()})
	}
	files := form.File["image"]
	if len(files) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "use multipart field \"image\""})
	}
	if len(files) > 1 {
		return c.Status(400).JSON(fiber.Map{"error": "send only one file"})
	}

	var row models.ServiceRegistration
	if err := serviceRegistrationDB.First(&row, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "registration not found"})
	}

	path, err := saveSingleServiceRegImage(id, files[0], "cs")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"url": path})
}

func customServiceImagePathsFromJSON(j datatypes.JSON) []string {
	if len(j) == 0 {
		return nil
	}
	var arr []map[string]interface{}
	if err := json.Unmarshal(j, &arr); err != nil {
		return nil
	}
	var out []string
	for _, m := range arr {
		if u, ok := m["image_url"].(string); ok && strings.TrimSpace(u) != "" {
			out = append(out, u)
		}
	}
	return out
}

func removeServiceRegistrationFiles(row *models.ServiceRegistration) {
	if row == nil {
		return
	}
	paths, _ := imagePathsToStrings(row.ImagePaths)
	for _, p := range paths {
		rel := strings.TrimPrefix(p, "/")
		if strings.Contains(rel, "..") {
			continue
		}
		_ = os.Remove(rel)
	}
	if row.ServiceProviderPhoto != nil && strings.TrimSpace(*row.ServiceProviderPhoto) != "" {
		rel := strings.TrimPrefix(*row.ServiceProviderPhoto, "/")
		if !strings.Contains(rel, "..") {
			_ = os.Remove(rel)
		}
	}
	for _, p := range customServiceImagePathsFromJSON(row.CustomServices) {
		rel := strings.TrimPrefix(p, "/")
		if strings.Contains(rel, "..") {
			continue
		}
		_ = os.Remove(rel)
	}
}
