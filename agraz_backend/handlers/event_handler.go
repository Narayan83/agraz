package handler

import (
	"strconv"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

var eventDB *gorm.DB

func SetEventDB(db *gorm.DB) {
	eventDB = db
}

const (
	eventRecurYearly  = "yearly"
	eventRecurMonthly = "monthly"
	eventRecurWeekly  = "weekly"
	eventRecurDaily   = "daily"
)

type eventBody struct {
	Name        string `json:"name"`
	EventDate   string `json:"event_date"`
	Recurrence  string `json:"recurrence"`
	NotifyTime  string `json:"notify_time"`
	UserID      uint   `json:"user_id"`
	OwnerUserID uint   `json:"owner_user_id"`
}

func normalizeEventRecurrence(s string) string {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case eventRecurYearly, "year", "annual", "annually":
		return eventRecurYearly
	case eventRecurMonthly, "month":
		return eventRecurMonthly
	case eventRecurWeekly, "week":
		return eventRecurWeekly
	case eventRecurDaily, "day":
		return eventRecurDaily
	default:
		return ""
	}
}

func normalizeNotifyTime(s string) (string, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "09:00", true
	}
	layouts := []string{"15:04", "15:04:05", "3:04", "3:04PM", "3:04 PM", "03:04 PM"}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			return t.Format("15:04"), true
		}
	}
	return "", false
}

func parseEventDate(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, fiber.NewError(fiber.StatusBadRequest, "event_date is required")
	}
	for _, layout := range []string{
		"2006-01-02",
		time.RFC3339,
		"2006-01-02T15:04:05",
		"2006-01-02T15:04:05Z07:00",
	} {
		if t, err := time.Parse(layout, s); err == nil {
			return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC), nil
		}
	}
	return time.Time{}, fiber.NewError(fiber.StatusBadRequest, "invalid event_date")
}

func ownerIDFromEventBody(userID, ownerUserID uint) uint {
	if ownerUserID > 0 {
		return ownerUserID
	}
	return userID
}

func adminEventOwnerID(c *fiber.Ctx) (uint, error) {
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

func requireAdminEventOwnerID(c *fiber.Ctx, fromBody uint) (uint, error) {
	if _, err := requireUserID(c); err != nil {
		return 0, err
	}
	if fromBody > 0 {
		return fromBody, nil
	}
	return adminEventOwnerID(c)
}

func eventFromBody(body eventBody) (models.ManagedEvent, error) {
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return models.ManagedEvent{}, fiber.NewError(fiber.StatusBadRequest, "name is required")
	}
	when, err := parseEventDate(body.EventDate)
	if err != nil {
		return models.ManagedEvent{}, err
	}
	recurrence := normalizeEventRecurrence(body.Recurrence)
	if recurrence == "" {
		recurrence = eventRecurYearly
	}
	notify, ok := normalizeNotifyTime(body.NotifyTime)
	if !ok {
		return models.ManagedEvent{}, fiber.NewError(fiber.StatusBadRequest, "invalid notify_time")
	}
	return models.ManagedEvent{
		Name:       name,
		EventDate:  when,
		Recurrence: recurrence,
		NotifyTime: notify,
	}, nil
}

func listEventsForOwner(c *fiber.Ctx, ownerUID uint) error {
	q := scopeByUserID(eventDB.Model(&models.ManagedEvent{}), ownerUID)
	if search := strings.TrimSpace(c.Query("q")); search != "" {
		q = q.Where("LOWER(name) LIKE ?", "%"+strings.ToLower(search)+"%")
	}
	if rec := normalizeEventRecurrence(c.Query("recurrence")); rec != "" {
		q = q.Where("recurrence = ?", rec)
	}
	var rows []models.ManagedEvent
	if err := q.Order("event_date ASC, notify_time ASC, id ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to load events"})
	}
	if rows == nil {
		rows = []models.ManagedEvent{}
	}
	return c.JSON(fiber.Map{"data": rows, "total": len(rows)})
}

func createEventForOwner(c *fiber.Ctx, ownerUID uint, body eventBody) error {
	row, err := eventFromBody(body)
	if err != nil {
		return err
	}
	row.UserID = ownerUID
	if err := eventDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create event"})
	}
	return c.Status(201).JSON(fiber.Map{"message": "Event created", "data": row})
}

func updateEventForOwner(c *fiber.Ctx, ownerUID uint, body eventBody) error {
	id, err := strconv.ParseUint(c.Params("id"), 10, 64)
	if err != nil || id == 0 {
		return fiber.NewError(fiber.StatusBadRequest, "invalid id")
	}
	patch, err := eventFromBody(body)
	if err != nil {
		return err
	}
	var row models.ManagedEvent
	if err := scopeByUserID(eventDB.Model(&models.ManagedEvent{}), ownerUID).
		First(&row, id).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Event not found"})
	}
	row.Name = patch.Name
	row.EventDate = patch.EventDate
	row.Recurrence = patch.Recurrence
	row.NotifyTime = patch.NotifyTime
	if err := eventDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update event"})
	}
	return c.JSON(fiber.Map{"message": "Event updated", "data": row})
}

func deleteEventForOwner(c *fiber.Ctx, ownerUID uint) error {
	id, err := strconv.ParseUint(c.Params("id"), 10, 64)
	if err != nil || id == 0 {
		return fiber.NewError(fiber.StatusBadRequest, "invalid id")
	}
	res := scopeByUserID(eventDB.Model(&models.ManagedEvent{}), ownerUID).
		Delete(&models.ManagedEvent{}, id)
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to delete event"})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "Event not found"})
	}
	return c.JSON(fiber.Map{"message": "Event deleted"})
}

func ListEvents(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return listEventsForOwner(c, uid)
}

func CreateEvent(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body eventBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return createEventForOwner(c, uid, body)
}

func UpdateEvent(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var body eventBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	return updateEventForOwner(c, uid, body)
}

func DeleteEvent(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	return deleteEventForOwner(c, uid)
}

func AdminListEvents(c *fiber.Ctx) error {
	ownerUID, err := adminEventOwnerID(c)
	if err != nil {
		return err
	}
	return listEventsForOwner(c, ownerUID)
}

func AdminCreateEvent(c *fiber.Ctx) error {
	var body eventBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	ownerUID, err := requireAdminEventOwnerID(c, ownerIDFromEventBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return createEventForOwner(c, ownerUID, body)
}

func AdminUpdateEvent(c *fiber.Ctx) error {
	var body eventBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	ownerUID, err := requireAdminEventOwnerID(c, ownerIDFromEventBody(body.UserID, body.OwnerUserID))
	if err != nil {
		return err
	}
	return updateEventForOwner(c, ownerUID, body)
}

func AdminDeleteEvent(c *fiber.Ctx) error {
	ownerUID, err := adminEventOwnerID(c)
	if err != nil {
		return err
	}
	return deleteEventForOwner(c, ownerUID)
}
