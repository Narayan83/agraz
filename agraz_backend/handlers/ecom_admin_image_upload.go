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
	maxEcomAdminImageBytes = 10 << 20 // 10 MiB
	ecomImageUploadSubdir  = "ecom"
	ecomImageKindProduct   = "product"
	ecomImageKindVariant   = "variant"
	ecomImageKindHero      = "hero"
)

func saveEcomAdminImageFiles(kind string, file *multipart.FileHeader) (string, error) {
	ext, ok := func(fh *multipart.FileHeader) (string, bool) {
		src, err := fh.Open()
		if err != nil {
			return "", false
		}
		// sniffImageExt reads + seeks within the file handle.
		ext, ok := sniffImageExt(src)
		src.Close()
		return ext, ok
	}(file)
	if !ok {
		return "", fmt.Errorf("unsupported or invalid image")
	}

	if file.Size > maxEcomAdminImageBytes {
		return "", fmt.Errorf("file exceeds %d bytes", maxEcomAdminImageBytes)
	}

	subdir := filepath.Join(ecomImageUploadSubdir, kind)
	if kind == ecomImageKindHero {
		subdir = "storefront"
	}
	base := filepath.Join("uploads", subdir)
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

	webPath := "/" + filepath.ToSlash(filepath.Join("uploads", subdir, name))
	return webPath, nil
}

// UploadAdminEcomImage stores an uploaded (already-cropped) image and returns a URL path.
// Form fields:
// - kind: "product" | "variant" | "hero" (hero files go under uploads/storefront/)
// - image: multipart file (field name "image")
func UploadAdminEcomImage(c *fiber.Ctx) error {
	kind := strings.ToLower(strings.TrimSpace(c.FormValue("kind")))
	if kind != ecomImageKindProduct && kind != ecomImageKindVariant && kind != ecomImageKindHero {
		return c.Status(400).JSON(fiber.Map{"error": "kind must be product, variant, or hero"})
	}

	form, err := c.MultipartForm()
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "multipart form required", "details": err.Error()})
	}

	files := form.File["image"]
	if len(files) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no file: use multipart field \"image\""})
	}
	if len(files) > 1 {
		return c.Status(400).JSON(fiber.Map{"error": "send only one file per request"})
	}

	urlPath, err := saveEcomAdminImageFiles(kind, files[0])
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(201).JSON(fiber.Map{"url": urlPath})
}

