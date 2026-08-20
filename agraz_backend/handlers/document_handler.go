package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

var documentDB *gorm.DB

func SetDocumentDB(db *gorm.DB) {
	documentDB = db
}

const (
	maxDocumentFileBytes   = 8 << 20 // 8 MiB
	maxDocumentImagesReq   = 12
	maxDocumentImagesTotal = 20
	documentUploadDir      = "documents"
)

type folderBody struct {
	Name        string `json:"name"`
	UserID      uint   `json:"user_id"`
	OwnerUserID uint   `json:"owner_user_id"`
}

type documentBody struct {
	Name        string    `json:"name"`
	FolderID    *int64    `json:"folder_id"`
	Images      *[]string `json:"images"`
	UserID      uint      `json:"user_id"`
	OwnerUserID uint      `json:"owner_user_id"`
}

func parseImageURLList(j datatypes.JSON) []string {
	if len(j) == 0 {
		return []string{}
	}
	var asStrings []string
	if err := json.Unmarshal(j, &asStrings); err == nil {
		return sanitizeImageURLs(asStrings)
	}
	return []string{}
}

func sanitizeImageURLs(in []string) []string {
	out := make([]string, 0, len(in))
	seen := map[string]bool{}
	for _, raw := range in {
		s := strings.TrimSpace(raw)
		if s == "" || seen[s] {
			continue
		}
		seen[s] = true
		out = append(out, s)
	}
	return out
}

func imageURLsToJSON(paths []string) datatypes.JSON {
	clean := sanitizeImageURLs(paths)
	if clean == nil {
		clean = []string{}
	}
	b, err := json.Marshal(clean)
	if err != nil {
		return datatypes.JSON([]byte("[]"))
	}
	return datatypes.JSON(b)
}

func folderNameValid(name string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", fmt.Errorf("folder name is required")
	}
	if len([]rune(name)) > 120 {
		return "", fmt.Errorf("folder name is too long")
	}
	return name, nil
}

func documentNameValid(name string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", fmt.Errorf("document name is required")
	}
	if len([]rune(name)) > 120 {
		return "", fmt.Errorf("document name is too long")
	}
	return name, nil
}

func resolveFolderID(uid uint, raw *int64) (*uint, error) {
	if raw == nil || *raw == 0 {
		return nil, nil
	}
	if *raw < 0 {
		return nil, fmt.Errorf("invalid folder_id")
	}
	id := uint(*raw)
	var folder models.DocumentFolder
	if err := scopeByUserID(documentDB.Model(&models.DocumentFolder{}), uid).First(&folder, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, fmt.Errorf("folder not found")
		}
		return nil, err
	}
	return &id, nil
}

func attachFolderCounts(uid uint, folders []models.DocumentFolder) {
	if len(folders) == 0 {
		return
	}
	type countRow struct {
		FolderID uint
		Cnt      int64
	}
	var rows []countRow
	_ = documentDB.Model(&models.UserDocument{}).
		Select("folder_id as folder_id, count(*) as cnt").
		Where("user_id = ? AND folder_id IS NOT NULL", uid).
		Group("folder_id").
		Scan(&rows)
	byID := make(map[uint]int, len(rows))
	for _, r := range rows {
		byID[r.FolderID] = int(r.Cnt)
	}
	for i := range folders {
		folders[i].DocumentCount = byID[folders[i].ID]
	}
}

func documentToMap(row models.UserDocument) fiber.Map {
	images := parseImageURLList(row.Images)
	m := fiber.Map{
		"id":         row.ID,
		"user_id":    row.UserID,
		"name":       row.Name,
		"images":     images,
		"created_at": row.CreatedAt,
		"updated_at": row.UpdatedAt,
	}
	if row.FolderID != nil {
		m["folder_id"] = *row.FolderID
	} else {
		m["folder_id"] = nil
	}
	return m
}

func removeDocumentFiles(paths []string) {
	for _, p := range paths {
		p = strings.TrimSpace(p)
		if !strings.HasPrefix(p, "/uploads/documents/") {
			continue
		}
		rel := strings.TrimPrefix(p, "/")
		_ = os.Remove(filepath.FromSlash(rel))
	}
}

func saveDocumentImage(file *multipart.FileHeader) (string, error) {
	if file.Size > maxDocumentFileBytes {
		return "", fmt.Errorf("file exceeds %d bytes", maxDocumentFileBytes)
	}
	src, err := file.Open()
	if err != nil {
		return "", err
	}
	defer src.Close()

	ext, ok := sniffImageExt(src)
	if !ok {
		return "", fmt.Errorf("unsupported image type (jpg, png, webp)")
	}

	base := filepath.Join("uploads", documentUploadDir)
	if err := os.MkdirAll(base, 0755); err != nil {
		return "", err
	}
	name := uuid.NewString() + ext
	dstPath := filepath.Join(base, name)

	dst, err := os.Create(dstPath)
	if err != nil {
		return "", err
	}
	defer dst.Close()

	if _, err := io.Copy(dst, src); err != nil {
		return "", err
	}
	return "/" + filepath.ToSlash(filepath.Join("uploads", documentUploadDir, name)), nil
}

func collectUploadFiles(form *multipart.Form) []*multipart.FileHeader {
	var files []*multipart.FileHeader
	files = append(files, form.File["file"]...)
	files = append(files, form.File["files"]...)
	files = append(files, form.File["images"]...)
	return files
}

func uploadDocumentImagesFor(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
		return err
	}
	form, err := c.MultipartForm()
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "multipart form required", "details": err.Error()})
	}
	files := collectUploadFiles(form)
	if len(files) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no file: use multipart field \"file\" or \"files\""})
	}
	if len(files) > maxDocumentImagesReq {
		return c.Status(400).JSON(fiber.Map{"error": fmt.Sprintf("too many files (max %d)", maxDocumentImagesReq)})
	}
	urls := make([]string, 0, len(files))
	for _, f := range files {
		urlPath, err := saveDocumentImage(f)
		if err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		}
		urls = append(urls, urlPath)
	}
	out := fiber.Map{"urls": urls}
	if len(urls) == 1 {
		out["url"] = urls[0]
	}
	return c.JSON(out)
}

func browseDocumentsFor(c *fiber.Ctx, uid uint) error {
	q := strings.TrimSpace(c.Query("q"))
	folderRaw := strings.TrimSpace(c.Query("folder_id"))

	var folderID *uint
	var current *models.DocumentFolder
	if folderRaw != "" && folderRaw != "0" {
		n, err := strconv.ParseUint(folderRaw, 10, 64)
		if err != nil || n == 0 {
			return c.Status(400).JSON(fiber.Map{"error": "invalid folder_id"})
		}
		id := uint(n)
		var folder models.DocumentFolder
		if err := scopeByUserID(documentDB.Model(&models.DocumentFolder{}), uid).First(&folder, id).Error; err != nil {
			if err == gorm.ErrRecordNotFound {
				return c.Status(404).JSON(fiber.Map{"error": "folder not found"})
			}
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		folderID = &id
		current = &folder
	}

	folders := []models.DocumentFolder{}
	if folderID == nil {
		fq := scopeByUserID(documentDB.Model(&models.DocumentFolder{}), uid)
		if q != "" {
			like := "%" + q + "%"
			fq = fq.Where("name ILIKE ?", like)
		}
		if err := fq.Order("lower(name) ASC, id ASC").Find(&folders).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		attachFolderCounts(uid, folders)
	}

	var docs []models.UserDocument
	dq := scopeByUserID(documentDB.Model(&models.UserDocument{}), uid)
	if folderID == nil {
		dq = dq.Where("folder_id IS NULL")
	} else {
		dq = dq.Where("folder_id = ?", *folderID)
	}
	if q != "" {
		like := "%" + q + "%"
		dq = dq.Where("name ILIKE ?", like)
	}
	if err := dq.Order("lower(name) ASC, id ASC").Find(&docs).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	docMaps := make([]fiber.Map, 0, len(docs))
	for _, d := range docs {
		docMaps = append(docMaps, documentToMap(d))
	}

	payload := fiber.Map{
		"folders":   folders,
		"documents": docMaps,
		"folder":    current,
	}
	return c.JSON(payload)
}

func createFolderFor(c *fiber.Ctx, uid uint, body folderBody) error {
	name, err := folderNameValid(body.Name)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	row := models.DocumentFolder{UserID: uid, Name: name}
	if err := documentDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create folder", "details": err.Error()})
	}
	row.DocumentCount = 0
	return c.Status(201).JSON(row)
}

func updateFolderFor(c *fiber.Ctx, uid uint, body folderBody) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	name, err := folderNameValid(body.Name)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	var row models.DocumentFolder
	if err := scopeByUserID(documentDB.Model(&models.DocumentFolder{}), uid).First(&row, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "folder not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	row.Name = name
	if err := documentDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update folder"})
	}
	counted := []models.DocumentFolder{row}
	attachFolderCounts(uid, counted)
	return c.JSON(counted[0])
}

func deleteFolderFor(c *fiber.Ctx, uid uint) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var folder models.DocumentFolder
	if err := scopeByUserID(documentDB.Model(&models.DocumentFolder{}), uid).First(&folder, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "folder not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var docs []models.UserDocument
	_ = documentDB.Where("user_id = ? AND folder_id = ?", uid, folder.ID).Find(&docs)
	for _, d := range docs {
		removeDocumentFiles(parseImageURLList(d.Images))
	}
	if err := documentDB.Where("user_id = ? AND folder_id = ?", uid, folder.ID).Delete(&models.UserDocument{}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := documentDB.Delete(&folder).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func getDocumentFor(c *fiber.Ctx, uid uint) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.UserDocument
	if err := scopeByUserID(documentDB.Model(&models.UserDocument{}), uid).First(&row, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(documentToMap(row))
}

func createDocumentFor(c *fiber.Ctx, uid uint, body documentBody) error {
	name, err := documentNameValid(body.Name)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	folderID, err := resolveFolderID(uid, body.FolderID)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	images := []string{}
	if body.Images != nil {
		images = sanitizeImageURLs(*body.Images)
	}
	if len(images) > maxDocumentImagesTotal {
		return c.Status(400).JSON(fiber.Map{"error": fmt.Sprintf("too many images (max %d)", maxDocumentImagesTotal)})
	}
	row := models.UserDocument{
		UserID:   uid,
		FolderID: folderID,
		Name:     name,
		Images:   imageURLsToJSON(images),
	}
	if err := documentDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to save document", "details": err.Error()})
	}
	return c.Status(201).JSON(documentToMap(row))
}

func updateDocumentFor(c *fiber.Ctx, uid uint, body documentBody) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.UserDocument
	if err := scopeByUserID(documentDB.Model(&models.UserDocument{}), uid).First(&row, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if strings.TrimSpace(body.Name) != "" {
		name, err := documentNameValid(body.Name)
		if err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		}
		row.Name = name
	}
	if body.FolderID != nil {
		folderID, err := resolveFolderID(uid, body.FolderID)
		if err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		}
		row.FolderID = folderID
	}
	if body.Images != nil {
		images := sanitizeImageURLs(*body.Images)
		if len(images) > maxDocumentImagesTotal {
			return c.Status(400).JSON(fiber.Map{"error": fmt.Sprintf("too many images (max %d)", maxDocumentImagesTotal)})
		}
		old := parseImageURLList(row.Images)
		removed := make([]string, 0)
		keep := map[string]bool{}
		for _, p := range images {
			keep[p] = true
		}
		for _, p := range old {
			if !keep[p] {
				removed = append(removed, p)
			}
		}
		row.Images = imageURLsToJSON(images)
		if err := documentDB.Save(&row).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "Failed to update document"})
		}
		removeDocumentFiles(removed)
		return c.JSON(documentToMap(row))
	}
	if err := documentDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update document"})
	}
	return c.JSON(documentToMap(row))
}

func deleteDocumentFor(c *fiber.Ctx, uid uint) error {
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.UserDocument
	if err := scopeByUserID(documentDB.Model(&models.UserDocument{}), uid).First(&row, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	images := parseImageURLList(row.Images)
	if err := documentDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	removeDocumentFiles(images)
	return c.JSON(fiber.Map{"ok": true})
}

func ownerIDFromDocBody(userID, ownerUserID uint) uint {
	if userID > 0 {
		return userID
	}
	return ownerUserID
}

func adminDocumentOwnerID(c *fiber.Ctx) (uint, error) {
	if _, err := requireUserID(c); err != nil {
		return 0, err
	}
	raw := strings.TrimSpace(c.Query("user_id"))
	if raw == "" {
		raw = strings.TrimSpace(c.Query("owner_user_id"))
	}
	if raw == "" {
		return 0, fiber.NewError(fiber.StatusBadRequest, "user_id is required")
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, fiber.NewError(fiber.StatusBadRequest, "invalid user_id")
	}
	return uint(n), nil
}

func requireAdminDocumentOwnerID(c *fiber.Ctx, fromBody uint) (uint, error) {
	if _, err := requireUserID(c); err != nil {
		return 0, err
	}
	if fromBody > 0 {
		return fromBody, nil
	}
	return adminDocumentOwnerID(c)
}

// --- Mobile (owner-scoped, including family sub-users) ---

func BrowseDocuments(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return browseDocumentsFor(c, uid)
}

func CreateDocumentFolder(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body folderBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return createFolderFor(c, uid, body)
}

func UpdateDocumentFolder(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body folderBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return updateFolderFor(c, uid, body)
}

func DeleteDocumentFolder(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return deleteFolderFor(c, uid)
}

func GetUserDocument(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return getDocumentFor(c, uid)
}

func CreateUserDocument(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body documentBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return createDocumentFor(c, uid, body)
}

func UpdateUserDocument(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body documentBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return updateDocumentFor(c, uid, body)
}

func DeleteUserDocument(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return deleteDocumentFor(c, uid)
}

func UploadDocumentImages(c *fiber.Ctx) error {
	return uploadDocumentImagesFor(c)
}

// --- Admin ---

func AdminBrowseDocuments(c *fiber.Ctx) error {
	uid, err := adminDocumentOwnerID(c)
	if err != nil {
		return err
	}
	return browseDocumentsFor(c, uid)
}

func AdminCreateDocumentFolder(c *fiber.Ctx) error {
	var body folderBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	uid, err := requireAdminDocumentOwnerID(c, ownerIDFromDocBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return createFolderFor(c, uid, body)
}

func AdminUpdateDocumentFolder(c *fiber.Ctx) error {
	var body folderBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	uid, err := requireAdminDocumentOwnerID(c, ownerIDFromDocBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return updateFolderFor(c, uid, body)
}

func AdminDeleteDocumentFolder(c *fiber.Ctx) error {
	uid, err := adminDocumentOwnerID(c)
	if err != nil {
		return err
	}
	return deleteFolderFor(c, uid)
}

func AdminGetUserDocument(c *fiber.Ctx) error {
	uid, err := adminDocumentOwnerID(c)
	if err != nil {
		return err
	}
	return getDocumentFor(c, uid)
}

func AdminCreateUserDocument(c *fiber.Ctx) error {
	var body documentBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	uid, err := requireAdminDocumentOwnerID(c, ownerIDFromDocBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return createDocumentFor(c, uid, body)
}

func AdminUpdateUserDocument(c *fiber.Ctx) error {
	var body documentBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	uid, err := requireAdminDocumentOwnerID(c, ownerIDFromDocBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return updateDocumentFor(c, uid, body)
}

func AdminDeleteUserDocument(c *fiber.Ctx) error {
	uid, err := adminDocumentOwnerID(c)
	if err != nil {
		return err
	}
	return deleteDocumentFor(c, uid)
}

func AdminUploadDocumentImages(c *fiber.Ctx) error {
	if _, err := requireUserID(c); err != nil {
		return err
	}
	return uploadDocumentImagesFor(c)
}
