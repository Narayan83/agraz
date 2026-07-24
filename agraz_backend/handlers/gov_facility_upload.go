package handler

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

const (
	maxGovAppFileBytes   = 15 << 20 // 15 MiB
	govFacilityUploadDir = "gov-facilities"
)

func sniffGovAppExt(fh *multipart.FileHeader) (string, bool) {
	name := strings.ToLower(fh.Filename)
	ct := strings.ToLower(fh.Header.Get("Content-Type"))

	switch {
	case strings.HasSuffix(name, ".pdf") || strings.Contains(ct, "pdf"):
		return ".pdf", true
	case strings.HasSuffix(name, ".doc"):
		return ".doc", true
	case strings.HasSuffix(name, ".docx") || strings.Contains(ct, "wordprocessingml"):
		return ".docx", true
	case strings.HasSuffix(name, ".jpg") || strings.HasSuffix(name, ".jpeg"):
		return ".jpg", true
	case strings.HasSuffix(name, ".png"):
		return ".png", true
	default:
		return "", false
	}
}

func saveGovApplicationFile(file *multipart.FileHeader) (string, error) {
	ext, ok := sniffGovAppExt(file)
	if !ok {
		return "", fmt.Errorf("unsupported file type (pdf, doc, docx, jpg, png)")
	}
	if file.Size > maxGovAppFileBytes {
		return "", fmt.Errorf("file exceeds %d bytes", maxGovAppFileBytes)
	}

	base := filepath.Join("uploads", govFacilityUploadDir)
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

	webPath := "/" + filepath.ToSlash(filepath.Join("uploads", govFacilityUploadDir, name))
	return webPath, nil
}

// UploadGovFacilityApplication stores an application form file.
// Multipart field name: "file"
func UploadGovFacilityApplication(c *fiber.Ctx) error {
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

	urlPath, err := saveGovApplicationFile(files[0])
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"url": urlPath})
}
