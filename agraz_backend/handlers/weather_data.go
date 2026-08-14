package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"strings"
	"time"

	"erp.local/backend/models"
	"gorm.io/gorm/clause"
)

func f64At(a []float64, i int) float64 {
	if i >= 0 && i < len(a) {
		return a[i]
	}
	return 0
}

func intAt(a []int, i int) int {
	if i >= 0 && i < len(a) {
		return a[i]
	}
	return 0
}

func compassDir(deg float64) string {
	dirs := []string{"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
	i := int(math.Round(deg/45.0)) % 8
	if i < 0 {
		i += 8
	}
	return dirs[i]
}

func weatherDate(t time.Time) time.Time {
	y, m, d := t.In(istLoc()).Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

func weatherTypeFor(date time.Time, today time.Time) string {
	d := weatherDate(date)
	t := weatherDate(today)
	switch {
	case d.Equal(t):
		return "CURRENT"
	case d.After(t):
		return "FORECAST"
	default:
		return "HISTORY"
	}
}

func upsertWeatherDaily(row models.WeatherDaily) {
	if weatherDB == nil {
		return
	}
	row.LastUpdated = time.Now().UTC()
	_ = weatherDB.Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "location_id"}, {Name: "date"}},
		DoUpdates: clause.AssignmentColumns([]string{
			"location_name", "district", "latitude", "longitude", "year", "month",
			"obs_time", "weather_type", "weather_condition", "weather_condition_kn",
			"temperature_c", "min_temperature_c", "max_temperature_c", "feels_like_c",
			"humidity_pct", "min_humidity_pct", "max_humidity_pct", "rainfall_mm",
			"rain_probability_pct", "wind_speed_kmph", "wind_direction", "cloud_cover_pct",
			"uv_index", "forecast_day", "data_source", "last_updated", "weather_code",
		}),
	}).Create(&row).Error
}

func dailyFromForecast(loc weatherLocation, report *models.WeatherReport, day weatherDay, idx int, now time.Time) models.WeatherDaily {
	dt, err := time.Parse("2006-01-02", day.Date)
	if err != nil {
		dt = now
	}
	dt = weatherDate(dt)
	temp := (day.TempMax + day.TempMin) / 2
	wtype := weatherTypeFor(dt, now)
	obsTime := ""
	if idx == 0 {
		temp = report.TempC
		obsTime = now.In(istLoc()).Format("15:04")
	}
	return models.WeatherDaily{
		LocationID:         loc.Key,
		LocationName:       loc.Name,
		District:           loc.District,
		Latitude:           loc.Lat,
		Longitude:          loc.Lng,
		Year:               dt.Year(),
		Month:              int(dt.Month()),
		Date:               dt,
		ObsTime:            obsTime,
		WeatherType:        wtype,
		WeatherCondition:   day.ConditionEn,
		WeatherConditionKn: day.ConditionKn,
		TemperatureC:       temp,
		MinTemperatureC:    day.TempMin,
		MaxTemperatureC:    day.TempMax,
		FeelsLikeC:         report.FeelsLikeC,
		HumidityPct:        day.Humidity,
		RainfallMM:         day.RainMM,
		RainProbabilityPct: day.RainProb,
		WindSpeedKmph:      day.WindKmh,
		WindDirection:      day.WindDir,
		CloudCoverPct:      day.CloudPct,
		UVIndex:            day.UVIndex,
		ForecastDay:        idx,
		DataSource:         "open-meteo",
		WeatherCode:        day.WeatherCode,
	}
}

func upsertForecastDailies(loc weatherLocation, report *models.WeatherReport) {
	days := []weatherDay{}
	if len(report.DaysJSON) > 0 {
		_ = json.Unmarshal(report.DaysJSON, &days)
	}
	now := time.Now().In(istLoc())
	for i, day := range days {
		row := dailyFromForecast(loc, report, day, i, now)
		if i == 0 {
			row.HumidityPct = report.Humidity
			row.FeelsLikeC = report.FeelsLikeC
			row.WindSpeedKmph = report.WindKmh
			row.WindDirection = report.WindDir
			row.CloudCoverPct = report.CloudPct
			row.WeatherCondition = report.ConditionEn
			row.WeatherConditionKn = report.ConditionKn
			row.WeatherCode = report.WeatherCode
		}
		upsertWeatherDaily(row)
	}
}

func backfillWeatherHistory(loc weatherLocation) error {
	var n int64
	_ = weatherDB.Model(&models.WeatherDaily{}).
		Where("location_id = ? AND weather_type = ?", loc.Key, "HISTORY").
		Count(&n).Error
	if n >= 400 {
		return nil
	}
	today := weatherDate(time.Now().In(istLoc()))
	end := today.AddDate(0, 0, -2)
	start := today.AddDate(-2, 0, 0)
	url := fmt.Sprintf(
		"https://archive-api.open-meteo.com/v1/archive?latitude=%.4f&longitude=%.4f&start_date=%s&end_date=%s&daily=weather_code,temperature_2m_max,temperature_2m_min,temperature_2m_mean,precipitation_sum,relative_humidity_2m_mean,relative_humidity_2m_min,relative_humidity_2m_max,wind_speed_10m_max,wind_direction_10m_dominant,cloud_cover_mean&timezone=Asia%%2FKolkata",
		loc.Lat, loc.Lng, start.Format("2006-01-02"), end.Format("2006-01-02"),
	)
	client := &http.Client{Timeout: 60 * time.Second}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "AgRazWeather/1.0 (https://agrazllp.com)")
	req.Header.Set("Accept", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("archive HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	var om openMeteoResponse
	if err := json.Unmarshal(body, &om); err != nil {
		return err
	}
	now := time.Now().UTC()
	batch := make([]models.WeatherDaily, 0, 64)
	for i, dateStr := range om.Daily.Time {
		dt, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			continue
		}
		dt = weatherDate(dt)
		code := intAt(om.Daily.WeatherCode, i)
		en, kn := weatherCondition(code)
		mean := f64At(om.Daily.Temperature2mMean, i)
		if mean == 0 {
			mean = (f64At(om.Daily.Temperature2mMax, i) + f64At(om.Daily.Temperature2mMin, i)) / 2
		}
		batch = append(batch, models.WeatherDaily{
			LocationID:         loc.Key,
			LocationName:       loc.Name,
			District:           loc.District,
			Latitude:           loc.Lat,
			Longitude:          loc.Lng,
			Year:               dt.Year(),
			Month:              int(dt.Month()),
			Date:               dt,
			WeatherType:        "HISTORY",
			WeatherCondition:   en,
			WeatherConditionKn: kn,
			TemperatureC:       mean,
			MinTemperatureC:    f64At(om.Daily.Temperature2mMin, i),
			MaxTemperatureC:    f64At(om.Daily.Temperature2mMax, i),
			HumidityPct:        f64At(om.Daily.RelativeHumidity2mMean, i),
			MinHumidityPct:     f64At(om.Daily.RelativeHumidity2mMin, i),
			MaxHumidityPct:     f64At(om.Daily.RelativeHumidity2mMax, i),
			RainfallMM:         f64At(om.Daily.PrecipitationSum, i),
			WindSpeedKmph:      f64At(om.Daily.WindSpeed10mMax, i),
			WindDirection:      compassDir(f64At(om.Daily.WindDirection10mDominant, i)),
			CloudCoverPct:      f64At(om.Daily.CloudCoverMean, i),
			ForecastDay:        -1,
			DataSource:         "open-meteo-archive",
			LastUpdated:        now,
			WeatherCode:        code,
		})
		if len(batch) >= 80 {
			flushDailyBatch(batch)
			batch = batch[:0]
		}
	}
	flushDailyBatch(batch)
	log.Printf("weather history backfilled %s rows~%d", loc.Key, len(om.Daily.Time))
	return nil
}

func flushDailyBatch(rows []models.WeatherDaily) {
	if len(rows) == 0 || weatherDB == nil {
		return
	}
	_ = weatherDB.Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "location_id"}, {Name: "date"}},
		DoUpdates: clause.AssignmentColumns([]string{
			"location_name", "district", "latitude", "longitude", "year", "month",
			"weather_type", "weather_condition", "weather_condition_kn",
			"temperature_c", "min_temperature_c", "max_temperature_c",
			"humidity_pct", "min_humidity_pct", "max_humidity_pct", "rainfall_mm",
			"wind_speed_kmph", "wind_direction", "cloud_cover_pct",
			"forecast_day", "data_source", "last_updated", "weather_code",
		}),
	}).Create(&rows).Error
}

func sumRainfall(locationID string, from, to time.Time) float64 {
	var sum float64
	_ = weatherDB.Model(&models.WeatherDaily{}).
		Select("COALESCE(SUM(rainfall_mm),0)").
		Where("location_id = ? AND date >= ? AND date <= ?", locationID, weatherDate(from), weatherDate(to)).
		Scan(&sum).Error
	return sum
}

func weatherPctChange(cur, prev float64) float64 {
	if prev == 0 {
		return 0
	}
	return ((cur - prev) / prev) * 100
}

func buildWeatherInsights(loc weatherLocation, report *models.WeatherReport) []weatherInsight {
	if weatherDB == nil {
		return nil
	}
	now := time.Now().In(istLoc())
	today := weatherDate(now)
	monthStart := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
	yearStart := time.Date(today.Year(), 1, 1, 0, 0, 0, 0, time.UTC)
	lastYearSame := today.AddDate(-1, 0, 0)
	lastYearMonthStart := monthStart.AddDate(-1, 0, 0)
	lastYearMonthEnd := lastYearSame
	if lastYearSame.Month() != today.Month() {
		lastYearMonthEnd = lastYearMonthStart.AddDate(0, 1, -1)
	}

	mtd := sumRainfall(loc.Key, monthStart, today)
	mtdLast := sumRainfall(loc.Key, lastYearMonthStart, lastYearMonthEnd)
	ytd := sumRainfall(loc.Key, yearStart, today)
	ytdLast := sumRainfall(loc.Key, yearStart.AddDate(-1, 0, 0), lastYearSame)

	days := []weatherDay{}
	if len(report.DaysJSON) > 0 {
		_ = json.Unmarshal(report.DaysJSON, &days)
	}
	weekRain := 0.0
	rainy := 0
	for _, d := range days {
		weekRain += d.RainMM
		if d.RainMM >= 2 {
			rainy++
		}
	}

	out := make([]weatherInsight, 0, 6)
	monthName := today.Month().String()

	if mtdLast > 0 {
		chg := weatherPctChange(mtd, mtdLast)
		wordEn, wordKn := "above", "ಹೆಚ್ಚು"
		if chg < 0 {
			wordEn, wordKn = "below", "ಕಡಿಮೆ"
			chg = -chg
		}
		out = append(out, weatherInsight{
			Key:      "month_rain_yoy",
			Priority: "info",
			Icon:     "rain",
			TitleEn:  fmt.Sprintf("%s rainfall vs last year", monthName),
			TitleKn:  fmt.Sprintf("%s ಮಳೆ — ಹಿಂದಿನ ವರ್ಷದ ಹೋಲಿಕೆ", monthName),
			BodyEn: fmt.Sprintf(
				"%s has received %.0f mm so far this %s, %.0f%% %s last year to the same date (%.0f mm).",
				loc.Name, mtd, monthName, chg, wordEn, mtdLast,
			),
			BodyKn: fmt.Sprintf(
				"%s ಈ %s %.0f ಮಿಮೀ ಮಳೆ ಪಡೆದಿದೆ. ಹಿಂದಿನ ವರ್ಷದ ಇದೇ ದಿನಾಂಕದವರೆಗೆ (%.0f ಮಿಮೀ) ಗಿಂತ %.0f%% %s.",
				loc.NameKn, monthName, mtd, mtdLast, chg, wordKn,
			),
		})
	}

	prevAvg := 0.0
	_ = weatherDB.Model(&models.WeatherDaily{}).
		Select("COALESCE(AVG(temperature_c),0)").
		Where("location_id = ? AND month = ? AND date < ?", loc.Key, int(today.Month()), monthStart).
		Scan(&prevAvg).Error
	if prevAvg > 0 {
		diff := report.TempC - prevAvg
		cmpEn, cmpKn := "higher", "ಹೆಚ್ಚು"
		if diff < 0 {
			cmpEn, cmpKn = "lower", "ಕಡಿಮೆ"
			diff = -diff
		}
		out = append(out, weatherInsight{
			Key:      "temp_vs_month_avg",
			Priority: "info",
			Icon:     "hot",
			TitleEn:  "Today vs previous years this month",
			TitleKn:  "ಇಂದು vs ಹಿಂದಿನ ವರ್ಷಗಳ ಈ ತಿಂಗಳು",
			BodyEn: fmt.Sprintf(
				"Today is %.1f°C, %.1f°C %s than the previous-years %s average (%.1f°C) at %s.",
				report.TempC, diff, cmpEn, monthName, prevAvg, loc.Name,
			),
			BodyKn: fmt.Sprintf(
				"ಇಂದು %.1f°C. %s ಹಿಂದಿನ ವರ್ಷಗಳ %s ಸರಾಸರಿ (%.1f°C) ಗಿಂತ %.1f°C %s.",
				report.TempC, loc.NameKn, monthName, prevAvg, diff, cmpKn,
			),
		})
	}

	out = append(out, weatherInsight{
		Key:      "week_rain_trend",
		Priority: "info",
		Icon:     "week",
		TitleEn:  fmt.Sprintf("7-day rainfall trend — %s", loc.Name),
		TitleKn:  fmt.Sprintf("7 ದಿನದ ಮಳೆ ಪ್ರವೃತ್ತಿ — %s", loc.NameKn),
		BodyEn: fmt.Sprintf(
			"%d rainy day(s) ahead, about %.0f mm total. Plan drying, spraying and drainage around this trend.",
			rainy, weekRain,
		),
		BodyKn: fmt.Sprintf(
			"ಮುಂದೆ %d ಮಳೆ ದಿನ, ಒಟ್ಟು ಸುಮಾರು %.0f ಮಿಮೀ. ಒಣಗಿಸುವಿಕೆ, ಸಿಂಪಡಣೆ ಮತ್ತು ಚರಂಡಿಯನ್ನು ಈ ಪ್ರವೃತ್ತಿಗೆ ಅನುಗುಣವಾಗಿ ಯೋಜಿಸಿ.",
			rainy, weekRain,
		),
	})

	if ytdLast > 0 {
		chg := weatherPctChange(ytd, ytdLast)
		wordEn, wordKn := "above", "ಹೆಚ್ಚು"
		if chg < 0 {
			wordEn, wordKn = "below", "ಕಡಿಮೆ"
			chg = -chg
		}
		out = append(out, weatherInsight{
			Key:      "ytd_rain",
			Priority: "info",
			Icon:     "rain",
			TitleEn:  "Rainfall vs last year to this date",
			TitleKn:  "ಈ ದಿನಾಂಕದವರೆಗೆ ಹಿಂದಿನ ವರ್ಷದ ಮಳೆ ಹೋಲಿಕೆ",
			BodyEn: fmt.Sprintf(
				"Current year rainfall at %s is %.0f mm, %.0f%% %s last year to the same date (%.0f mm).",
				loc.Name, ytd, chg, wordEn, ytdLast,
			),
			BodyKn: fmt.Sprintf(
				"%s ನಲ್ಲಿ ಈ ವರ್ಷ %.0f ಮಿಮೀ ಮಳೆ. ಹಿಂದಿನ ವರ್ಷದ ಇದೇ ದಿನಾಂಕದವರೆಗೆ (%.0f ಮಿಮೀ) ಗಿಂತ %.0f%% %s.",
				loc.NameKn, ytd, ytdLast, chg, wordKn,
			),
		})
	}

	riskEn := "Watch fruit rot, keep drains open, and delay spraying before rain. Cover drying yards."
	riskKn := "ಹಣ್ಣು ಕೊಳೆತ ಎಚ್ಚರ. ಚರಂಡಿ ತೆರೆದಿರಲಿ, ಮಳೆಗೆ ಮುನ್ನ ಸಿಂಪಡಿಸಬೇಡಿ, ಒಣಗಿಸುವ ಅಂಗಳ ಮುಚ್ಚಿ."
	if ytdLast > 0 && weatherPctChange(ytd, ytdLast) < -15 && weekRain < 15 {
		riskEn = "Drier than last year with a lighter week ahead — irrigate young palms and check drip lines."
		riskKn = "ಹಿಂದಿನ ವರ್ಷಕ್ಕಿಂತ ಒಣ ಮತ್ತು ಮುಂದಿನ ವಾರ ಹಗುರ — ಎಳೆ ಗಿಡಗಳಿಗೆ ನೀರು, ಡ್ರಿಪ್ ಲೈನ್ ಪರೀಕ್ಷಿಸಿ."
	}
	out = append(out, weatherInsight{
		Key:      "agri_risk",
		Priority: "medium",
		Icon:     "humidity",
		TitleEn:  "Farm risks from history + 7-day forecast",
		TitleKn:  "ಇತಿಹಾಸ ಮತ್ತು 7 ದಿನದ ಮುನ್ಸೂಚನೆಯಿಂದ ಕೃಷಿ ಅಪಾಯ",
		BodyEn:   riskEn,
		BodyKn:   riskKn,
	})

	return out
}
