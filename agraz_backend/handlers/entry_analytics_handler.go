package handler

import (
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

type entryAnalyticsRecent struct {
	Menu      string    `json:"menu"`
	ID        uint      `json:"id"`
	UserID    uint      `json:"user_id"`
	UserName  string    `json:"user_name"`
	Summary   string    `json:"summary"`
	Date      time.Time `json:"date"`
	CreatedAt time.Time `json:"created_at"`
}

type entryAnalyticsByUser struct {
	UserID        uint   `json:"user_id"`
	Name          string `json:"name"`
	Email         string `json:"email"`
	LaborCount    int64  `json:"labor_count"`
	IECount       int64  `json:"ie_count"`
	FeedbackCount int64  `json:"feedback_count"`
	Total         int64  `json:"total"`
}

func parseOptionalTime(s string) (time.Time, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, false
	}
	for _, layout := range []string{time.RFC3339, "2006-01-02", "2006-01-02T15:04:05"} {
		if t, err := time.Parse(layout, s); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

func userDisplayName(u models.User) string {
	name := strings.TrimSpace(u.Firstname + " " + u.Lastname)
	if name == "" {
		name = strings.TrimSpace(u.Username)
	}
	if name == "" {
		name = u.Email
	}
	return name
}

func applyEntryAnalyticsFilters(q *gorm.DB, dateCol string, filterUID uint, fromT time.Time, hasFrom bool, toT time.Time, hasTo bool) *gorm.DB {
	if filterUID > 0 {
		q = q.Where("user_id = ?", filterUID)
	}
	if hasFrom {
		q = q.Where(dateCol+" >= ?", fromT)
	}
	if hasTo {
		q = q.Where(dateCol+" <= ?", toT)
	}
	return q
}

// AdminEntryAnalytics handles GET /api/admin/entry-analytics
func AdminEntryAnalytics(c *fiber.Ctx) error {
	menuFilter := strings.TrimSpace(c.Query("menu"))
	userIDStr := strings.TrimSpace(c.Query("user_id"))
	var filterUID uint
	if userIDStr != "" {
		n, err := strconv.ParseUint(userIDStr, 10, 64)
		if err != nil || n == 0 {
			return c.Status(400).JSON(fiber.Map{"error": "invalid user_id"})
		}
		filterUID = uint(n)
	}
	fromT, hasFrom := parseOptionalTime(c.Query("from"))
	toT, hasTo := parseOptionalTime(c.Query("to"))

	laborQ := applyEntryAnalyticsFilters(laborDB.Model(&models.Labor{}), "date", filterUID, fromT, hasFrom, toT, hasTo)
	ieQ := applyEntryAnalyticsFilters(incomeExpenseDB.Model(&models.IncomeExpense{}), "date", filterUID, fromT, hasFrom, toT, hasTo)
	fbQ := applyEntryAnalyticsFilters(feedbackDB.Model(&models.AppFeedback{}), "created_at", filterUID, fromT, hasFrom, toT, hasTo)

	var laborCount, ieCount, fbCount int64
	if menuFilter == "" || menuFilter == "labor" {
		if err := laborQ.Count(&laborCount).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}
	if menuFilter == "" || menuFilter == "income_expense" {
		if err := ieQ.Count(&ieCount).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}
	if menuFilter == "" || menuFilter == "feedback" {
		if err := fbQ.Count(&fbCount).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
	}

	byMenu := fiber.Map{
		"labor":          laborCount,
		"income_expense": ieCount,
		"feedback":       fbCount,
	}

	type uidCount struct {
		UserID uint  `gorm:"column:user_id"`
		Cnt    int64 `gorm:"column:cnt"`
	}
	laborByUser := map[uint]int64{}
	ieByUser := map[uint]int64{}
	fbByUser := map[uint]int64{}
	uidSet := map[uint]struct{}{}

	if menuFilter == "" || menuFilter == "labor" {
		var rows []uidCount
		lq := applyEntryAnalyticsFilters(laborDB.Model(&models.Labor{}), "date", filterUID, fromT, hasFrom, toT, hasTo)
		if err := lq.Select("user_id, COUNT(*) as cnt").Group("user_id").Scan(&rows).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		for _, r := range rows {
			laborByUser[r.UserID] = r.Cnt
			uidSet[r.UserID] = struct{}{}
		}
	}
	if menuFilter == "" || menuFilter == "income_expense" {
		var rows []uidCount
		iq := applyEntryAnalyticsFilters(incomeExpenseDB.Model(&models.IncomeExpense{}), "date", filterUID, fromT, hasFrom, toT, hasTo)
		if err := iq.Select("user_id, COUNT(*) as cnt").Group("user_id").Scan(&rows).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		for _, r := range rows {
			ieByUser[r.UserID] = r.Cnt
			uidSet[r.UserID] = struct{}{}
		}
	}
	if menuFilter == "" || menuFilter == "feedback" {
		var rows []uidCount
		fq := applyEntryAnalyticsFilters(feedbackDB.Model(&models.AppFeedback{}), "created_at", filterUID, fromT, hasFrom, toT, hasTo)
		if err := fq.Select("user_id, COUNT(*) as cnt").Group("user_id").Scan(&rows).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		for _, r := range rows {
			fbByUser[r.UserID] = r.Cnt
			uidSet[r.UserID] = struct{}{}
		}
	}

	uids := make([]uint, 0, len(uidSet))
	for id := range uidSet {
		uids = append(uids, id)
	}
	usersByID := map[uint]models.User{}
	if len(uids) > 0 {
		var users []models.User
		if err := userDB.Where("id IN ?", uids).Find(&users).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		for _, u := range users {
			usersByID[u.ID] = u
		}
	}

	byUser := make([]entryAnalyticsByUser, 0, len(uids))
	for _, id := range uids {
		u := usersByID[id]
		row := entryAnalyticsByUser{
			UserID:        id,
			Name:          userDisplayName(u),
			Email:         u.Email,
			LaborCount:    laborByUser[id],
			IECount:       ieByUser[id],
			FeedbackCount: fbByUser[id],
		}
		row.Total = row.LaborCount + row.IECount + row.FeedbackCount
		byUser = append(byUser, row)
	}
	sort.Slice(byUser, func(i, j int) bool {
		if byUser[i].Total == byUser[j].Total {
			return byUser[i].UserID < byUser[j].UserID
		}
		return byUser[i].Total > byUser[j].Total
	})

	recent := make([]entryAnalyticsRecent, 0, 50)
	fetchLimit := 50
	if menuFilter == "" || menuFilter == "labor" {
		lq := applyEntryAnalyticsFilters(laborDB.Model(&models.Labor{}), "date", filterUID, fromT, hasFrom, toT, hasTo)
		var labors []models.Labor
		if err := lq.Order("created_at DESC").Limit(fetchLimit).Find(&labors).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		for _, l := range labors {
			name := userDisplayName(usersByID[l.UserID])
			if name == "" {
				name = l.Name
			}
			recent = append(recent, entryAnalyticsRecent{
				Menu:      "labor",
				ID:        l.ID,
				UserID:    l.UserID,
				UserName:  name,
				Summary:   fmt.Sprintf("%s · %s · %s", l.Name, l.Category, l.Shift),
				Date:      l.Date,
				CreatedAt: l.CreatedAt,
			})
		}
	}
	if menuFilter == "" || menuFilter == "income_expense" {
		iq := applyEntryAnalyticsFilters(incomeExpenseDB.Model(&models.IncomeExpense{}), "date", filterUID, fromT, hasFrom, toT, hasTo)
		var ies []models.IncomeExpense
		if err := iq.Order("created_at DESC").Limit(fetchLimit).Find(&ies).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		needUIDs := []uint{}
		for _, e := range ies {
			if _, ok := usersByID[e.UserID]; !ok {
				needUIDs = append(needUIDs, e.UserID)
			}
		}
		if len(needUIDs) > 0 {
			var users []models.User
			if err := userDB.Where("id IN ?", needUIDs).Find(&users).Error; err == nil {
				for _, u := range users {
					usersByID[u.ID] = u
				}
			}
		}
		for _, e := range ies {
			name := userDisplayName(usersByID[e.UserID])
			if name == "" {
				name = e.Name
			}
			recent = append(recent, entryAnalyticsRecent{
				Menu:      "income_expense",
				ID:        e.ID,
				UserID:    e.UserID,
				UserName:  name,
				Summary:   fmt.Sprintf("%s · %s / %s · %s", e.Type, e.Category, e.SubCategory, e.Amount.String()),
				Date:      e.Date,
				CreatedAt: e.CreatedAt,
			})
		}
	}
	// Also resolve labor user names missing from uidSet when filtered by menu
	if menuFilter == "" || menuFilter == "labor" {
		needUIDs := []uint{}
		for _, r := range recent {
			if r.Menu != "labor" {
				continue
			}
			if _, ok := usersByID[r.UserID]; !ok {
				needUIDs = append(needUIDs, r.UserID)
			}
		}
		if len(needUIDs) > 0 {
			var users []models.User
			if err := userDB.Where("id IN ?", needUIDs).Find(&users).Error; err == nil {
				for _, u := range users {
					usersByID[u.ID] = u
				}
				for i := range recent {
					if recent[i].Menu == "labor" {
						if n := userDisplayName(usersByID[recent[i].UserID]); n != "" {
							recent[i].UserName = n
						}
					}
				}
			}
		}
	}

	sort.Slice(recent, func(i, j int) bool {
		return recent[i].CreatedAt.After(recent[j].CreatedAt)
	})
	if len(recent) > 50 {
		recent = recent[:50]
	}

	return c.JSON(fiber.Map{
		"totals": fiber.Map{
			"labors":          laborCount,
			"income_expenses": ieCount,
			"feedbacks":       fbCount,
			"by_menu":         byMenu,
		},
		"by_user": byUser,
		"recent":  recent,
	})
}

// AdminEntryAnalyticsEntries handles GET /api/admin/entry-analytics/entries
func AdminEntryAnalyticsEntries(c *fiber.Ctx) error {
	menu := strings.TrimSpace(c.Query("menu"))
	if menu != "labor" && menu != "income_expense" {
		return c.Status(400).JSON(fiber.Map{"error": "menu must be labor or income_expense"})
	}
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	userIDStr := strings.TrimSpace(c.Query("user_id"))
	var filterUID uint
	if userIDStr != "" {
		n, err := strconv.ParseUint(userIDStr, 10, 64)
		if err != nil || n == 0 {
			return c.Status(400).JSON(fiber.Map{"error": "invalid user_id"})
		}
		filterUID = uint(n)
	}
	fromT, hasFrom := parseOptionalTime(c.Query("from"))
	toT, hasTo := parseOptionalTime(c.Query("to"))

	if menu == "labor" {
		q := applyEntryAnalyticsFilters(laborDB.Model(&models.Labor{}), "date", filterUID, fromT, hasFrom, toT, hasTo)
		var total int64
		if err := q.Count(&total).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		var rows []models.Labor
		if err := q.Order("date DESC, id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit, "menu": menu})
	}

	q := applyEntryAnalyticsFilters(incomeExpenseDB.Model(&models.IncomeExpense{}), "date", filterUID, fromT, hasFrom, toT, hasTo)
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var rows []models.IncomeExpense
	if err := q.Order("date DESC, id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit, "menu": menu})
}
