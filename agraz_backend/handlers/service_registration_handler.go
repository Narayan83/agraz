package handler

import (
	"encoding/json"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

var serviceRegistrationDB *gorm.DB

func SetServiceRegistrationDB(db *gorm.DB) {
	serviceRegistrationDB = db
}

type serviceRegistrationCreatePayload struct {
	Mobile       string          `json:"mobile"`
	Name         string          `json:"name"`
	MainCategory string          `json:"main_category"`
	SubCategory  *string         `json:"sub_category"`
	BusinessName string          `json:"business_name"`
	ImagePaths   datatypes.JSON  `json:"image_paths"`
	Approved     *bool           `json:"approved"`
	BusinessAddress      *string  `json:"business_address"`
	CustomerAddress      *string  `json:"customer_address"`
	ServiceProviderPhoto *string  `json:"service_provider_photo"`
	Aadhar               *string  `json:"aadhar"`
	CustomServices       *json.RawMessage `json:"custom_services"`
	Latitude             *float64 `json:"latitude"`
	Longitude            *float64 `json:"longitude"`
	SecondaryContact     *string  `json:"secondary_contact"`
	Whatsapp             *string  `json:"whatsapp"`
	Email                *string  `json:"email"`
	Remarks              *string  `json:"remarks"`
	SocialFacebook       *string  `json:"social_facebook"`
	SocialWebsite        *string  `json:"social_website"`
	SocialInstagram      *string  `json:"social_instagram"`
	SocialYoutube        *string  `json:"social_youtube"`
}

type serviceRegistrationUpdatePayload struct {
	Mobile       *string          `json:"mobile"`
	Name         *string          `json:"name"`
	MainCategory *string          `json:"main_category"`
	SubCategory  *string          `json:"sub_category"`
	BusinessName *string          `json:"business_name"`
	ImagePaths   *json.RawMessage `json:"image_paths"`
	Approved     *bool            `json:"approved"`
	BusinessAddress      *string  `json:"business_address"`
	CustomerAddress      *string  `json:"customer_address"`
	ServiceProviderPhoto *string  `json:"service_provider_photo"`
	Aadhar               *string  `json:"aadhar"`
	CustomServices       *json.RawMessage `json:"custom_services"`
	Latitude             *float64 `json:"latitude"`
	Longitude            *float64 `json:"longitude"`
	SecondaryContact     *string  `json:"secondary_contact"`
	Whatsapp             *string  `json:"whatsapp"`
	Email                *string  `json:"email"`
	Remarks              *string  `json:"remarks"`
	SocialFacebook       *string  `json:"social_facebook"`
	SocialWebsite        *string  `json:"social_website"`
	SocialInstagram      *string  `json:"social_instagram"`
	SocialYoutube        *string  `json:"social_youtube"`
}

func CreateServiceRegistration(c *fiber.Ctx) error {
	var body serviceRegistrationCreatePayload
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	if body.Mobile == "" || body.Name == "" || body.MainCategory == "" || body.BusinessName == "" {
		return c.Status(400).JSON(fiber.Map{"error": "mobile, name, main_category, and business_name are required"})
	}

	approved := false
	if body.Approved != nil {
		approved = *body.Approved
	}

	row := models.ServiceRegistration{
		Mobile:               body.Mobile,
		Name:                 body.Name,
		MainCategory:         body.MainCategory,
		SubCategory:          body.SubCategory,
		BusinessName:         body.BusinessName,
		ImagePaths:           body.ImagePaths,
		Approved:             approved,
		BusinessAddress:      body.BusinessAddress,
		CustomerAddress:      body.CustomerAddress,
		ServiceProviderPhoto: body.ServiceProviderPhoto,
		Aadhar:               body.Aadhar,
		Latitude:             body.Latitude,
		Longitude:            body.Longitude,
		SecondaryContact:     body.SecondaryContact,
		Whatsapp:             body.Whatsapp,
		Email:                body.Email,
		Remarks:              body.Remarks,
		SocialFacebook:       body.SocialFacebook,
		SocialWebsite:        body.SocialWebsite,
		SocialInstagram:      body.SocialInstagram,
		SocialYoutube:        body.SocialYoutube,
	}
	if body.CustomServices != nil && len(*body.CustomServices) > 0 && string(*body.CustomServices) != "null" {
		row.CustomServices = datatypes.JSON(*body.CustomServices)
	}
	if err := serviceRegistrationDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create record", "details": err.Error()})
	}
	_ = syncCoverImageForRow(row.ID, row.ImagePaths)
	serviceRegistrationDB.First(&row, row.ID)
	return c.Status(201).JSON(row)
}

// approval filter: all | pending | approved
func GetServiceRegistrations(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 10)
	if page < 1 {
		page = 1
	}
	offset := (page - 1) * limit

	var rows []models.ServiceRegistration
	var total int64
	q := serviceRegistrationDB.Model(&models.ServiceRegistration{})

	switch c.Query("approval", "all") {
	case "pending":
		q = q.Where("approved = ?", false)
	case "approved":
		q = q.Where("approved = ?", true)
	}

	if m := c.Query("mobile"); m != "" {
		q = q.Where("mobile = ?", m)
	}
	if mc := c.Query("main_category"); mc != "" {
		q = q.Where("main_category ILIKE ?", "%"+mc+"%")
	}
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := q.Order("id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func GetServiceRegistration(c *fiber.Ctx) error {
	var row models.ServiceRegistration
	if err := serviceRegistrationDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}
	return c.JSON(row)
}

func UpdateServiceRegistration(c *fiber.Ctx) error {
	rawBytes := append([]byte(nil), c.Body()...)
	var body serviceRegistrationUpdatePayload
	if err := json.Unmarshal(rawBytes, &body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	var rawJSON map[string]interface{}
	_ = json.Unmarshal(rawBytes, &rawJSON)

	var row models.ServiceRegistration
	if err := serviceRegistrationDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}

	updates := map[string]interface{}{}
	if body.Mobile != nil {
		updates["mobile"] = *body.Mobile
	}
	if body.Name != nil {
		updates["name"] = *body.Name
	}
	if body.MainCategory != nil {
		updates["main_category"] = *body.MainCategory
	}
	if body.SubCategory != nil {
		updates["sub_category"] = body.SubCategory
	}
	if body.BusinessName != nil {
		updates["business_name"] = *body.BusinessName
	}
	if body.ImagePaths != nil {
		raw := *body.ImagePaths
		if len(raw) == 0 || string(raw) == "null" {
			updates["image_paths"] = nil
		} else {
			updates["image_paths"] = datatypes.JSON(raw)
		}
	}
	if body.Approved != nil {
		updates["approved"] = *body.Approved
	}
	if body.BusinessAddress != nil {
		updates["business_address"] = *body.BusinessAddress
	}
	if body.CustomerAddress != nil {
		updates["customer_address"] = *body.CustomerAddress
	}
	if body.ServiceProviderPhoto != nil {
		updates["service_provider_photo"] = *body.ServiceProviderPhoto
	}
	if body.Aadhar != nil {
		updates["aadhar"] = *body.Aadhar
	}
	if body.CustomServices != nil {
		raw := *body.CustomServices
		if len(raw) == 0 || string(raw) == "null" {
			updates["custom_services"] = datatypes.JSON([]byte("[]"))
		} else {
			updates["custom_services"] = datatypes.JSON(raw)
		}
	}
	// JSON null must clear columns; plain *float64 cannot distinguish null from omitted.
	if _, ok := rawJSON["latitude"]; ok {
		if rawJSON["latitude"] == nil {
			updates["latitude"] = nil
		} else if body.Latitude != nil {
			updates["latitude"] = *body.Latitude
		}
	}
	if _, ok := rawJSON["longitude"]; ok {
		if rawJSON["longitude"] == nil {
			updates["longitude"] = nil
		} else if body.Longitude != nil {
			updates["longitude"] = *body.Longitude
		}
	}
	if body.SecondaryContact != nil {
		updates["secondary_contact"] = *body.SecondaryContact
	}
	if body.Whatsapp != nil {
		updates["whatsapp"] = *body.Whatsapp
	}
	if body.Email != nil {
		updates["email"] = *body.Email
	}
	if body.Remarks != nil {
		updates["remarks"] = *body.Remarks
	}
	if body.SocialFacebook != nil {
		updates["social_facebook"] = *body.SocialFacebook
	}
	if body.SocialWebsite != nil {
		updates["social_website"] = *body.SocialWebsite
	}
	if body.SocialInstagram != nil {
		updates["social_instagram"] = *body.SocialInstagram
	}
	if body.SocialYoutube != nil {
		updates["social_youtube"] = *body.SocialYoutube
	}

	if len(updates) == 0 {
		return c.JSON(row)
	}
	if err := serviceRegistrationDB.Model(&row).Updates(updates).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update", "details": err.Error()})
	}
	serviceRegistrationDB.First(&row, row.ID)
	if body.ImagePaths != nil {
		_ = syncCoverImageForRow(row.ID, row.ImagePaths)
		serviceRegistrationDB.First(&row, row.ID)
	}
	return c.JSON(row)
}

func DeleteServiceRegistration(c *fiber.Ctx) error {
	var row models.ServiceRegistration
	if err := serviceRegistrationDB.First(&row, c.Params("id")).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Record not found"})
	}
	removeServiceRegistrationFiles(&row)
	if err := serviceRegistrationDB.Delete(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Deleted"})
}
