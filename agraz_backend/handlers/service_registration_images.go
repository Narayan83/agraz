package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"gorm.io/datatypes"
)

const (
	maxServiceRegImageBytes   = 8 << 20 // 8 MiB per file
	maxServiceRegImagesPerReq = 24
	serviceRegUploadSubdir    = "service-registrations"
	stagingDirName            = "_staging"
)

func imagePathsToStrings(j datatypes.JSON) ([]string, error) {
	if len(j) == 0 {
		return []string{}, nil
	}
	var asStrings []string
	if err := json.Unmarshal(j, &asStrings); err == nil {
		return asStrings, nil
	}
	var asAny []interface{}
	if err := json.Unmarshal(j, &asAny); err != nil {
		return nil, err
	}
	out := make([]string, 0, len(asAny))
	for _, v := range asAny {
		if s, ok := v.(string); ok {
			out = append(out, s)
		}
	}
	return out, nil
}

func stringsToImagePathsJSON(paths []string) (datatypes.JSON, error) {
	b, err := json.Marshal(paths)
	if err != nil {
		return nil, err
	}
	return datatypes.JSON(b), nil
}

func syncCoverImageForRow(id uint, j datatypes.JSON) error {
	paths, err := imagePathsToStrings(j)
	if err != nil {
		return err
	}
	if len(paths) == 0 {
		return serviceRegistrationDB.Model(&models.ServiceRegistration{}).Where("id = ?", id).Update("cover_image", nil).Error
	}
	return serviceRegistrationDB.Model(&models.ServiceRegistration{}).Where("id = ?", id).Update("cover_image", paths[0]).Error
}

func sniffImageExt(f multipart.File) (ext string, ok bool) {
	buf := make([]byte, 512)
	n, err := f.Read(buf)
	if err != nil && err != io.EOF {
		return "", false
	}
	if _, seekErr := f.Seek(0, io.SeekStart); seekErr != nil {
		return "", false
	}
	ct := http.DetectContentType(buf[:n])
	if ct == "image/jpeg" {
		return ".jpg", true
	}
	if ct == "image/png" {
		return ".png", true
	}
	if ct == "image/webp" {
		return ".webp", true
	}
	if ct == "image/gif" {
		return ".gif", true
	}
	return "", false
}

func saveServiceRegImageFiles(regFolder string, files []*multipart.FileHeader) ([]string, error) {
	if len(files) > maxServiceRegImagesPerReq {
		return nil, fmt.Errorf("too many files (max %d)", maxServiceRegImagesPerReq)
	}

	base := filepath.Join("uploads", serviceRegUploadSubdir, regFolder)
	if err := os.MkdirAll(base, 0755); err != nil {
		return nil, err
	}

	var paths []string
	for _, fh := range files {
		if fh.Size > maxServiceRegImageBytes {
			return nil, fmt.Errorf("file %s exceeds %d bytes", fh.Filename, maxServiceRegImageBytes)
		}
		src, err := fh.Open()
		if err != nil {
			return nil, err
		}
		ext, ok := sniffImageExt(src)
		src.Close()
		if !ok {
			return nil, fmt.Errorf("unsupported or invalid image: %s", fh.Filename)
		}

		name := uuid.NewString() + ext
		dstPath := filepath.Join(base, name)
		src, err = fh.Open()
		if err != nil {
			return nil, err
		}
		defer src.Close()
		dst, err := os.Create(dstPath)
		if err != nil {
			return nil, err
		}
		if _, err := io.Copy(dst, src); err != nil {
			dst.Close()
			return nil, err
		}
		if err := dst.Close(); err != nil {
			return nil, err
		}

		webPath := "/" + filepath.ToSlash(filepath.Join("uploads", serviceRegUploadSubdir, regFolder, name))
		paths = append(paths, webPath)
	}
	return paths, nil
}

// saveSingleServiceRegImage saves one image under uploads/service-registrations/{regFolder}/ with optional filename prefix.
func saveSingleServiceRegImage(regFolder string, fh *multipart.FileHeader, namePrefix string) (string, error) {
	if fh == nil {
		return "", fmt.Errorf("no file")
	}
	if fh.Size > maxServiceRegImageBytes {
		return "", fmt.Errorf("file %s exceeds %d bytes", fh.Filename, maxServiceRegImageBytes)
	}
	base := filepath.Join("uploads", serviceRegUploadSubdir, regFolder)
	if err := os.MkdirAll(base, 0755); err != nil {
		return "", err
	}
	src, err := fh.Open()
	if err != nil {
		return "", err
	}
	ext, ok := sniffImageExt(src)
	src.Close()
	if !ok {
		return "", fmt.Errorf("unsupported or invalid image: %s", fh.Filename)
	}
	prefix := namePrefix
	if prefix != "" {
		prefix = prefix + "-"
	}
	name := prefix + uuid.NewString() + ext
	dstPath := filepath.Join(base, name)
	src, err = fh.Open()
	if err != nil {
		return "", err
	}
	defer src.Close()
	dst, err := os.Create(dstPath)
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(dst, src); err != nil {
		dst.Close()
		return "", err
	}
	if err := dst.Close(); err != nil {
		return "", err
	}
	webPath := "/" + filepath.ToSlash(filepath.Join("uploads", serviceRegUploadSubdir, regFolder, name))
	return webPath, nil
}

// UploadServiceRegistrationImages accepts multipart field "images" (repeatable).
// Optional form field "registration_id": if set, appends paths to that row's image_paths and returns updated record.
// If empty, files go to _staging and only paths are returned (for new records / manual JSON).
func UploadServiceRegistrationImages(c *fiber.Ctx) error {
	form, err := c.MultipartForm()
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "multipart form required", "details": err.Error()})
	}
	files := form.File["images"]
	if len(files) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no files: use form field \"images\""})
	}

	registrationIDStr := c.FormValue("registration_id")
	var regFolder string
	if registrationIDStr != "" {
		regFolder = registrationIDStr
	} else {
		regFolder = filepath.Join(stagingDirName, uuid.NewString())
	}

	paths, err := saveServiceRegImageFiles(regFolder, files)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}

	if registrationIDStr == "" {
		return c.Status(201).JSON(fiber.Map{
			"paths": paths,
		})
	}

	var row models.ServiceRegistration
	if err := serviceRegistrationDB.First(&row, registrationIDStr).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "registration not found"})
	}

	existing, err := imagePathsToStrings(row.ImagePaths)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "invalid stored image_paths", "details": err.Error()})
	}
	merged := append(existing, paths...)
	newJSON, err := stringsToImagePathsJSON(merged)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := serviceRegistrationDB.Model(&row).Update("image_paths", newJSON).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to save paths", "details": err.Error()})
	}
	serviceRegistrationDB.First(&row, row.ID)
	_ = syncCoverImageForRow(row.ID, row.ImagePaths)
	serviceRegistrationDB.First(&row, row.ID)
	return c.Status(201).JSON(fiber.Map{
		"paths":  paths,
		"record": row,
	})
}

type removeServiceRegImageBody struct {
	Path string `json:"path"`
}

// RemoveServiceRegistrationImage removes one path from image_paths and deletes the file if it is under uploads/service-registrations/{id}/.
func RemoveServiceRegistrationImage(c *fiber.Ctx) error {
	id := c.Params("id")
	var body removeServiceRegImageBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "JSON body with path required"})
	}
	body.Path = strings.TrimSpace(body.Path)
	if body.Path == "" {
		return c.Status(400).JSON(fiber.Map{"error": "path is required"})
	}

	var row models.ServiceRegistration
	if err := serviceRegistrationDB.First(&row, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "registration not found"})
	}

	prefix := fmt.Sprintf("/uploads/%s/%s/", serviceRegUploadSubdir, id)
	stagingPrefix := fmt.Sprintf("/uploads/%s/%s/", serviceRegUploadSubdir, stagingDirName)
	if !strings.HasPrefix(body.Path, prefix) && !strings.HasPrefix(body.Path, stagingPrefix) {
		return c.Status(400).JSON(fiber.Map{"error": "path must belong to this registration or staging"})
	}

	paths, err := imagePathsToStrings(row.ImagePaths)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "invalid stored image_paths"})
	}
	found := false
	next := make([]string, 0, len(paths))
	for _, p := range paths {
		if p == body.Path {
			found = true
			continue
		}
		next = append(next, p)
	}
	if !found {
		return c.Status(404).JSON(fiber.Map{"error": "path not in image_paths"})
	}

	rel := strings.TrimPrefix(body.Path, "/")
	if strings.Contains(rel, "..") {
		return c.Status(400).JSON(fiber.Map{"error": "invalid path"})
	}

	newJSON, err := stringsToImagePathsJSON(next)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := serviceRegistrationDB.Model(&row).Update("image_paths", newJSON).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to update record"})
	}
	serviceRegistrationDB.First(&row, row.ID)
	_ = syncCoverImageForRow(row.ID, row.ImagePaths)
	serviceRegistrationDB.First(&row, row.ID)

	_ = os.Remove(rel)

	return c.JSON(fiber.Map{"message": "removed", "record": row})
}
