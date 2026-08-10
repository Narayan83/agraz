package handler

import (
	"fmt"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// GetIncomeExpenseReportsPublic handles GET /api/income_expense/reports
// Query: year, month, months (trend window, default 6), type, mobile, category
func GetIncomeExpenseReportsPublic(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	now := time.Now()
	year := c.QueryInt("year", now.Year())
	month := c.QueryInt("month", int(now.Month()))
	trendMonths := c.QueryInt("months", 6)
	if trendMonths < 1 {
		trendMonths = 6
	}
	if trendMonths > 24 {
		trendMonths = 24
	}
	if month < 1 || month > 12 {
		return c.Status(400).JSON(fiber.Map{"error": "month must be 1-12"})
	}

	txType := strings.TrimSpace(c.Query("type"))
	mobile := strings.TrimSpace(c.Query("mobile"))
	category := strings.TrimSpace(c.Query("category"))

	base := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid)
	if txType == "Income" || txType == "Expense" {
		base = base.Where("type = ?", txType)
	}
	if mobile != "" {
		base = base.Where("mobile = ?", mobile)
	}
	if category != "" {
		base = base.Where("category ILIKE ?", "%"+category+"%")
	}

	monthStart := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.Local)
	monthEnd := monthStart.AddDate(0, 1, 0)
	trendStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.Local).
		AddDate(0, -(trendMonths - 1), 0)

	summary, err := ieReportSummary(base.Session(&gorm.Session{}))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	monthSummary, err := ieReportSummary(
		base.Session(&gorm.Session{}).Where("date >= ? AND date < ?", monthStart, monthEnd),
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	monthly, err := ieMonthlySchedule(base.Session(&gorm.Session{}), trendStart, now)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	weekly, err := ieWeeklySchedule(base.Session(&gorm.Session{}), monthStart, monthEnd)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	byCategory, err := ieCategoryBreakdown(
		base.Session(&gorm.Session{}).Where("date >= ? AND date < ?", monthStart, monthEnd),
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	byCategoryAll, err := ieCategoryBreakdown(base.Session(&gorm.Session{}))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	trends := ieBuildTrends(monthly, byCategoryAll)

	return c.JSON(fiber.Map{
		"year":             year,
		"month":            month,
		"month_label":      monthStart.Format("January 2006"),
		"summary":          summary,
		"month_summary":    monthSummary,
		"monthly":          monthly,
		"weekly":           weekly,
		"by_category":      byCategory,
		"by_category_all":  byCategoryAll,
		"trends":           trends,
	})
}

type ieSumAgg struct {
	Income       float64 `json:"income"`
	Expense      float64 `json:"expense"`
	Net          float64 `json:"net"`
	IncomeCount  int64   `json:"income_count"`
	ExpenseCount int64   `json:"expense_count"`
	TotalCount   int64   `json:"total_count"`
}

func ieReportSummary(q *gorm.DB) (ieSumAgg, error) {
	type row struct {
		Type        string  `gorm:"column:type"`
		TotalAmount float64 `gorm:"column:total_amount"`
		Count       int64   `gorm:"column:count"`
	}
	var rows []row
	err := q.Select("type, COALESCE(SUM(amount),0)::float8 as total_amount, COUNT(*) as count").
		Group("type").
		Scan(&rows).Error
	out := ieSumAgg{}
	if err != nil {
		return out, err
	}
	for _, r := range rows {
		switch strings.TrimSpace(r.Type) {
		case "Income":
			out.Income = r.TotalAmount
			out.IncomeCount = r.Count
		case "Expense":
			out.Expense = r.TotalAmount
			out.ExpenseCount = r.Count
		}
	}
	out.Net = out.Income - out.Expense
	out.TotalCount = out.IncomeCount + out.ExpenseCount
	return out, nil
}

type iePeriodRow struct {
	Year    int     `json:"year"`
	Month   int     `json:"month"`
	Label   string  `json:"label"`
	Income  float64 `json:"income"`
	Expense float64 `json:"expense"`
	Net     float64 `json:"net"`
	Count   int64   `json:"count"`
}

func ieMonthlySchedule(q *gorm.DB, from, to time.Time) ([]iePeriodRow, error) {
	type row struct {
		Y       int     `gorm:"column:y"`
		M       int     `gorm:"column:m"`
		Income  float64 `gorm:"column:income"`
		Expense float64 `gorm:"column:expense"`
		Count   int64   `gorm:"column:count"`
	}
	var rows []row
	err := q.Select(`
		EXTRACT(YEAR FROM date)::int as y,
		EXTRACT(MONTH FROM date)::int as m,
		COALESCE(SUM(CASE WHEN type = 'Income' THEN amount ELSE 0 END),0)::float8 as income,
		COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount ELSE 0 END),0)::float8 as expense,
		COUNT(*) as count
	`).
		Where("date >= ? AND date <= ?", from, to).
		Group("y, m").
		Order("y ASC, m ASC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	byKey := map[string]row{}
	for _, r := range rows {
		byKey[fmt.Sprintf("%d-%02d", r.Y, r.M)] = r
	}

	out := make([]iePeriodRow, 0)
	cur := time.Date(from.Year(), from.Month(), 1, 0, 0, 0, 0, time.Local)
	end := time.Date(to.Year(), to.Month(), 1, 0, 0, 0, 0, time.Local)
	for !cur.After(end) {
		key := fmt.Sprintf("%d-%02d", cur.Year(), int(cur.Month()))
		r := byKey[key]
		income, expense := r.Income, r.Expense
		out = append(out, iePeriodRow{
			Year:    cur.Year(),
			Month:   int(cur.Month()),
			Label:   cur.Format("Jan 2006"),
			Income:  income,
			Expense: expense,
			Net:     income - expense,
			Count:   r.Count,
		})
		cur = cur.AddDate(0, 1, 0)
	}
	return out, nil
}

type ieWeekRow struct {
	Week      int     `json:"week"`
	WeekStart string  `json:"week_start"`
	WeekEnd   string  `json:"week_end"`
	Label     string  `json:"label"`
	Income    float64 `json:"income"`
	Expense   float64 `json:"expense"`
	Net       float64 `json:"net"`
	Count     int64   `json:"count"`
}

func ieWeeklySchedule(q *gorm.DB, monthStart, monthEnd time.Time) ([]ieWeekRow, error) {
	type row struct {
		WeekNum int     `gorm:"column:week_num"`
		Income  float64 `gorm:"column:income"`
		Expense float64 `gorm:"column:expense"`
		Count   int64   `gorm:"column:count"`
	}
	var rows []row
	// Week-of-month: days 1-7 = week 1, 8-14 = week 2, etc.
	err := q.Select(`
		((EXTRACT(DAY FROM date)::int - 1) / 7) + 1 as week_num,
		COALESCE(SUM(CASE WHEN type = 'Income' THEN amount ELSE 0 END),0)::float8 as income,
		COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount ELSE 0 END),0)::float8 as expense,
		COUNT(*) as count
	`).
		Where("date >= ? AND date < ?", monthStart, monthEnd).
		Group("week_num").
		Order("week_num ASC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	byWeek := map[int]row{}
	for _, r := range rows {
		byWeek[r.WeekNum] = r
	}

	lastDay := monthEnd.AddDate(0, 0, -1).Day()
	maxWeek := ((lastDay - 1) / 7) + 1
	out := make([]ieWeekRow, 0, maxWeek)
	for w := 1; w <= maxWeek; w++ {
		startDay := (w-1)*7 + 1
		endDay := w * 7
		if endDay > lastDay {
			endDay = lastDay
		}
		ws := time.Date(monthStart.Year(), monthStart.Month(), startDay, 0, 0, 0, 0, time.Local)
		we := time.Date(monthStart.Year(), monthStart.Month(), endDay, 0, 0, 0, 0, time.Local)
		r := byWeek[w]
		out = append(out, ieWeekRow{
			Week:      w,
			WeekStart: ws.Format("2006-01-02"),
			WeekEnd:   we.Format("2006-01-02"),
			Label:     fmt.Sprintf("Week %d (%s–%s)", w, ws.Format("2 Jan"), we.Format("2 Jan")),
			Income:    r.Income,
			Expense:   r.Expense,
			Net:       r.Income - r.Expense,
			Count:     r.Count,
		})
	}
	return out, nil
}

type ieCatRow struct {
	Type        string  `json:"type"`
	Category    string  `json:"category"`
	SubCategory string  `json:"sub_category"`
	Total       float64 `json:"total"`
	Count       int64   `json:"count"`
	Pct         float64 `json:"pct"`
}

func ieCategoryBreakdown(q *gorm.DB) ([]ieCatRow, error) {
	type row struct {
		Type        string  `gorm:"column:type"`
		Category    string  `gorm:"column:category"`
		SubCategory string  `gorm:"column:sub_category"`
		Total       float64 `gorm:"column:total"`
		Count       int64   `gorm:"column:count"`
	}
	var rows []row
	err := q.Select(`
		type, category, sub_category,
		COALESCE(SUM(amount),0)::float8 as total,
		COUNT(*) as count
	`).
		Group("type, category, sub_category").
		Order("type ASC, total DESC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	var incomeTotal, expenseTotal float64
	for _, r := range rows {
		if r.Type == "Income" {
			incomeTotal += r.Total
		} else if r.Type == "Expense" {
			expenseTotal += r.Total
		}
	}

	out := make([]ieCatRow, 0, len(rows))
	for _, r := range rows {
		denom := incomeTotal
		if r.Type == "Expense" {
			denom = expenseTotal
		}
		pct := 0.0
		if denom > 0 {
			pct = (r.Total / denom) * 100
		}
		out = append(out, ieCatRow{
			Type:        r.Type,
			Category:    r.Category,
			SubCategory: r.SubCategory,
			Total:       r.Total,
			Count:       r.Count,
			Pct:         pct,
		})
	}
	return out, nil
}

func ieBuildTrends(monthly []iePeriodRow, categories []ieCatRow) fiber.Map {
	var incomeSum, expenseSum float64
	var incomeChange, expenseChange, netChange float64
	n := len(monthly)
	if n >= 2 {
		prev, cur := monthly[n-2], monthly[n-1]
		incomeChange = pctChange(prev.Income, cur.Income)
		expenseChange = pctChange(prev.Expense, cur.Expense)
		netChange = pctChange(prev.Net, cur.Net)
	}
	for _, m := range monthly {
		incomeSum += m.Income
		expenseSum += m.Expense
	}
	avgIncome, avgExpense := 0.0, 0.0
	if n > 0 {
		avgIncome = incomeSum / float64(n)
		avgExpense = expenseSum / float64(n)
	}

	topIncome := topCategories(categories, "Income", 5)
	topExpense := topCategories(categories, "Expense", 5)

	return fiber.Map{
		"income_change_pct":     incomeChange,
		"expense_change_pct":    expenseChange,
		"net_change_pct":        netChange,
		"avg_monthly_income":    avgIncome,
		"avg_monthly_expense":   avgExpense,
		"avg_monthly_net":       avgIncome - avgExpense,
		"top_income_categories": topIncome,
		"top_expense_categories": topExpense,
		"months_analyzed":       n,
	}
}

func pctChange(prev, cur float64) float64 {
	if prev == 0 {
		if cur == 0 {
			return 0
		}
		return 100
	}
	return ((cur - prev) / prev) * 100
}

func topCategories(rows []ieCatRow, typ string, limit int) []ieCatRow {
	out := make([]ieCatRow, 0, limit)
	for _, r := range rows {
		if r.Type != typ {
			continue
		}
		out = append(out, r)
		if len(out) >= limit {
			break
		}
	}
	return out
}
