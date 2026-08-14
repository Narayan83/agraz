package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

var weatherDB *gorm.DB
var weatherMu sync.Mutex

const weatherRefreshEvery = 8 * time.Hour

func SetWeatherDB(db *gorm.DB) {
	weatherDB = db
}

type weatherLocation struct {
	Key      string
	Name     string
	NameKn   string
	District string
	Lat      float64
	Lng      float64
}

var weatherLocations = []weatherLocation{
	{Key: "sirsi", Name: "Sirsi", NameKn: "ಸಿರ್ಸಿ", District: "Uttara Kannada", Lat: 14.6196, Lng: 74.8354},
	{Key: "siddapur", Name: "Siddapur", NameKn: "ಸಿದ್ದಾಪುರ", District: "Uttara Kannada", Lat: 14.3431, Lng: 74.8942},
	{Key: "yellapur", Name: "Yellapur", NameKn: "ಯಲ್ಲಾಪುರ", District: "Uttara Kannada", Lat: 14.9640, Lng: 74.7092},
}

type weatherDay struct {
	Date        string  `json:"date"`
	Weekday     string  `json:"weekday"`
	WeekdayKn   string  `json:"weekday_kn"`
	TempMax     float64 `json:"temp_max"`
	TempMin     float64 `json:"temp_min"`
	RainMM      float64 `json:"rain_mm"`
	RainProb    int     `json:"rain_prob"`
	Humidity    float64 `json:"humidity"`
	WindKmh     float64 `json:"wind_kmh"`
	WindDir     string  `json:"wind_direction"`
	CloudPct    float64 `json:"cloud_cover_pct"`
	UVIndex     float64 `json:"uv_index"`
	FeelsLikeC  float64 `json:"feels_like_c"`
	WeatherCode int     `json:"weather_code"`
	ConditionEn string  `json:"condition_en"`
	ConditionKn string  `json:"condition_kn"`
}

type weatherSuggestion struct {
	Priority string `json:"priority"` // high | medium | info
	Icon     string `json:"icon"`
	TitleEn  string `json:"title_en"`
	TitleKn  string `json:"title_kn"`
	BodyEn   string `json:"body_en"`
	BodyKn   string `json:"body_kn"`
}

type weatherInsight struct {
	Key      string `json:"key"`
	Priority string `json:"priority"`
	Icon     string `json:"icon"`
	TitleEn  string `json:"title_en"`
	TitleKn  string `json:"title_kn"`
	BodyEn   string `json:"body_en"`
	BodyKn   string `json:"body_kn"`
}

type openMeteoResponse struct {
	Timezone string `json:"timezone"`
	Current  struct {
		Temperature2m      float64 `json:"temperature_2m"`
		RelativeHumidity2m float64 `json:"relative_humidity_2m"`
		ApparentTemperature float64 `json:"apparent_temperature"`
		Precipitation      float64 `json:"precipitation"`
		WeatherCode        int     `json:"weather_code"`
		WindSpeed10m       float64 `json:"wind_speed_10m"`
		WindDirection10m   float64 `json:"wind_direction_10m"`
		CloudCover         float64 `json:"cloud_cover"`
	} `json:"current"`
	Daily struct {
		Time                        []string  `json:"time"`
		WeatherCode                 []int     `json:"weather_code"`
		Temperature2mMax            []float64 `json:"temperature_2m_max"`
		Temperature2mMin            []float64 `json:"temperature_2m_min"`
		Temperature2mMean           []float64 `json:"temperature_2m_mean"`
		PrecipitationSum            []float64 `json:"precipitation_sum"`
		PrecipitationProbabilityMax []int     `json:"precipitation_probability_max"`
		RelativeHumidity2mMean      []float64 `json:"relative_humidity_2m_mean"`
		RelativeHumidity2mMin       []float64 `json:"relative_humidity_2m_min"`
		RelativeHumidity2mMax       []float64 `json:"relative_humidity_2m_max"`
		WindSpeed10mMax             []float64 `json:"wind_speed_10m_max"`
		WindDirection10mDominant    []float64 `json:"wind_direction_10m_dominant"`
		CloudCoverMean              []float64 `json:"cloud_cover_mean"`
		UVIndexMax                  []float64 `json:"uv_index_max"`
	} `json:"daily"`
}

func findWeatherLocation(key string) weatherLocation {
	key = strings.ToLower(strings.TrimSpace(key))
	for _, loc := range weatherLocations {
		if loc.Key == key {
			return loc
		}
	}
	return weatherLocations[0]
}

func weatherCondition(code int) (string, string) {
	switch {
	case code == 0:
		return "Clear sky", "ಸ್ಪಷ್ಟ ಆಕಾಶ"
	case code == 1:
		return "Mainly clear", "ಹೆಚ್ಚು ಸ್ಪಷ್ಟ"
	case code == 2:
		return "Partly cloudy", "ಭಾಗಶಃ ಮೋಡ"
	case code == 3:
		return "Overcast", "ಮೋಡ ಕವಿದ"
	case code == 45, code == 48:
		return "Fog", "ಮಂಜು"
	case code >= 51 && code <= 55:
		return "Drizzle", "ತುಂತುರು ಮಳೆ"
	case code >= 56 && code <= 57:
		return "Freezing drizzle", "ಹಿಮ ತುಂತುರು"
	case code == 61:
		return "Light rain", "ಹಗುರ ಮಳೆ"
	case code == 63:
		return "Moderate rain", "ಮಧ್ಯಮ ಮಳೆ"
	case code == 65:
		return "Heavy rain", "ಭಾರೀ ಮಳೆ"
	case code >= 66 && code <= 67:
		return "Freezing rain", "ಹಿಮ ಮಳೆ"
	case code >= 71 && code <= 77:
		return "Snow", "ಹಿಮ"
	case code == 80:
		return "Light rain showers", "ಹಗುರ ಮಳೆ ಸಿಂಪಡಣೆ"
	case code == 81:
		return "Rain showers", "ಮಳೆ ಸಿಂಪಡಣೆ"
	case code == 82:
		return "Heavy rain showers", "ಭಾರೀ ಮಳೆ ಸಿಂಪಡಣೆ"
	case code >= 95 && code <= 99:
		return "Thunderstorm", "ಗುಡುಗು ಸಿಡಿಲು"
	default:
		return "Cloudy", "ಮೋಡ"
	}
}

var weekdayEn = []string{"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
var weekdayKn = []string{"ಭಾನುವಾರ", "ಸೋಮವಾರ", "ಮಂಗಳವಾರ", "ಬುಧವಾರ", "ಗುರುವಾರ", "ಶುಕ್ರವಾರ", "ಶನಿವಾರ"}

func buildFarmSuggestions(days []weatherDay, loc weatherLocation) []weatherSuggestion {
	if len(days) == 0 {
		return nil
	}

	totalRain := 0.0
	rainyDays := 0
	heavyDays := 0
	dryDays := 0
	maxWind := 0.0
	maxHum := 0.0
	maxTemp := -100.0
	minTemp := 100.0
	storm := false
	maxRainDay := days[0]
	longestDry := 0
	curDry := 0

	for _, d := range days {
		totalRain += d.RainMM
		if d.RainMM >= 2 {
			rainyDays++
			curDry = 0
		} else {
			dryDays++
			curDry++
			if curDry > longestDry {
				longestDry = curDry
			}
		}
		if d.RainMM >= 25 {
			heavyDays++
		}
		if d.RainMM > maxRainDay.RainMM {
			maxRainDay = d
		}
		if d.WindKmh > maxWind {
			maxWind = d.WindKmh
		}
		if d.Humidity > maxHum {
			maxHum = d.Humidity
		}
		if d.TempMax > maxTemp {
			maxTemp = d.TempMax
		}
		if d.TempMin < minTemp {
			minTemp = d.TempMin
		}
		if d.WeatherCode >= 95 {
			storm = true
		}
	}

	out := make([]weatherSuggestion, 0, 8)

	out = append(out, weatherSuggestion{
		Priority: "info",
		Icon:     "week",
		TitleEn:  fmt.Sprintf("This week in %s", loc.Name),
		TitleKn:  fmt.Sprintf("%s ಈ ವಾರ", loc.NameKn),
		BodyEn: fmt.Sprintf(
			"%d rainy day(s), about %.0f mm total rain. Temperatures %.0f–%.0f°C. Plan irrigation, drying, spraying and plucking around this outlook.",
			rainyDays, totalRain, minTemp, maxTemp,
		),
		BodyKn: fmt.Sprintf(
			"%d ಮಳೆ ದಿನ, ಒಟ್ಟು ಸುಮಾರು %.0f ಮಿಮೀ ಮಳೆ. ತಾಪಮಾನ %.0f–%.0f°C. ನೀರಾವರಿ, ಒಣಗಿಸುವಿಕೆ, ಸಿಂಪಡಣೆ ಮತ್ತು ಕೊಯ್ಲನ್ನು ಈ ಮುನ್ಸೂಚನೆಗೆ ಅನುಗುಣವಾಗಿ ಯೋಜಿಸಿ.",
			rainyDays, totalRain, minTemp, maxTemp,
		),
	})

	if storm {
		out = append(out, weatherSuggestion{
			Priority: "high",
			Icon:     "storm",
			TitleEn:  "Thunderstorm risk — stay off palms",
			TitleKn:  "ಗುಡುಗು ಸಿಡಿಲು — ಮರ ಹತ್ತಬೇಡಿ",
			BodyEn:   "Do not climb areca or coconut palms. Keep labour under shelter and postpone plucking until the storm has passed.",
			BodyKn:   "ಅಡಿಕೆ ಅಥವಾ ತೆಂಗಿನ ಮರ ಹತ್ತಬೇಡಿ. ಕೂಲಿ ಕೆಲಸಗಾರರನ್ನು ಆಶ್ರಯದಲ್ಲಿರಿಸಿ, ಬಿರುಗಾಳಿ ತೀರುವವರೆಗೆ ಕೊಯ್ಲು ಮುಂದೂಡಿ.",
		})
	}

	if heavyDays > 0 {
		out = append(out, weatherSuggestion{
			Priority: "high",
			Icon:     "rain",
			TitleEn:  fmt.Sprintf("Heavy rain around %s", maxRainDay.Weekday),
			TitleKn:  fmt.Sprintf("%s ಸುಮಾರು ಭಾರೀ ಮಳೆ", maxRainDay.WeekdayKn),
			BodyEn: fmt.Sprintf(
				"Up to %.0f mm expected. Keep garden drains open, avoid waterlogging at the palm base, do not sun-dry nuts in the open yard, and delay spraying / fertilizer until soil drains.",
				maxRainDay.RainMM,
			),
			BodyKn: fmt.Sprintf(
				"%.0f ಮಿಮೀವರೆಗೆ ಮಳೆ ನಿರೀಕ್ಷೆ. ತೋಟದ ಚರಂಡಿ ತೆರೆದಿರಲಿ, ಗಿಡದ ಬುಡದಲ್ಲಿ ನೀರು ನಿಲ್ಲದಂತೆ ನೋಡಿ, ತೆರೆದ ಅಂಗಳದಲ್ಲಿ ಅಡಿಕೆ ಒಣಗಿಸಬೇಡಿ, ಮಣ್ಣು ಇಳಿಯುವವರೆಗೆ ಸಿಂಪಡಣೆ/ಗೊಬ್ಬರ ಮುಂದೂಡಿ.",
				maxRainDay.RainMM,
			),
		})
	} else if rainyDays >= 4 {
		out = append(out, weatherSuggestion{
			Priority: "medium",
			Icon:     "rain",
			TitleEn:  "Wet week — watch fruit rot",
			TitleKn:  "ತೇವ ವಾರ — ಹಣ್ಣು ಕೊಳೆತ ಎಚ್ಚರ",
			BodyEn:   "Frequent rain favours kolerga / fruit rot on arecanut. Improve air flow, remove fallen nuts, and avoid spraying just before rain. Cover drying yards.",
			BodyKn:   "ನಿರಂತರ ಮಳೆಯಿಂದ ಅಡಿಕೆಯಲ್ಲಿ ಕೊಳೆರೋಗ/ಹಣ್ಣು ಕೊಳೆತಕ್ಕೆ ಅವಕಾಶ. ಗಾಳಿ ಸಂಚಾರ ಹೆಚ್ಚಿಸಿ, ಬಿದ್ದ ಕಾಯಿ ತೆಗೆಯಿರಿ, ಮಳೆಗೆ ಮುನ್ನ ಸಿಂಪಡಿಸಬೇಡಿ. ಒಣಗಿಸುವ ಅಂಗಳ ಮುಚ್ಚಿ.",
		})
	}

	if maxHum >= 85 && rainyDays >= 2 {
		out = append(out, weatherSuggestion{
			Priority: "medium",
			Icon:     "humidity",
			TitleEn:  "High humidity — fungal pressure",
			TitleKn:  "ಹೆಚ್ಚು ತೇವಾಂಶ — ಶಿಲೀಂಧ್ರ ಅಪಾಯ",
			BodyEn:   "Warm humid air helps bud rot and leaf spots. Inspect inner crowns, avoid excess nitrogen, and keep basins free of decaying husk.",
			BodyKn:   "ಬೆಚ್ಚಗಿನ ತೇವ ಗಾಳಿಯಿಂದ ಮೊಗ್ಗು ಕೊಳೆತ ಮತ್ತು ಎಲೆ ಚುಕ್ಕೆ. ಒಳಗಿನ ಕಿರೀಟ ಪರೀಕ್ಷಿಸಿ, ಅಧಿಕ ಸಾರಜನಕ ತಪ್ಪಿಸಿ, ಕೊಳೆಯುವ ಸಿಪ್ಪೆ ಬುಡದಿಂದ ತೆಗೆಯಿರಿ.",
		})
	}

	if longestDry >= 3 || (dryDays >= 5 && totalRain < 8) {
		out = append(out, weatherSuggestion{
			Priority: "medium",
			Icon:     "sun",
			TitleEn:  "Dry spell — irrigate young palms",
			TitleKn:  "ಬರಗಾಲ — ಎಳೆ ಗಿಡಗಳಿಗೆ ನೀರು",
			BodyEn:   "Give drip or basin irrigation to young areca, banana and pepper. Mulch basins with dry leaves. Check drip lines before the next dry stretch.",
			BodyKn:   "ಎಳೆ ಅಡಿಕೆ, ಬಾಳೆ ಮತ್ತು ಮೆಣಸಿಗೆ ಡ್ರಿಪ್ ಅಥವಾ ಬುಡ ನೀರಾವರಿ ಕೊಡಿ. ಒಣ ಎಲೆಯಿಂದ ಬುಡ ಮುಚ್ಚಿ. ಮುಂದಿನ ಒಣ ಅವಧಿಗೆ ಮುನ್ನ ಡ್ರಿಪ್ ಲೈನ್ ಪರೀಕ್ಷಿಸಿ.",
		})
	}

	goodDry := 0
	for _, d := range days {
		if d.RainMM < 1 && d.Humidity < 78 && d.WeatherCode <= 3 {
			goodDry++
		}
	}
	if goodDry >= 2 {
		out = append(out, weatherSuggestion{
			Priority: "info",
			Icon:     "dry",
			TitleEn:  "Good days to sun-dry nuts",
			TitleKn:  "ಅಡಿಕೆ ಒಣಗಿಸಲು ಒಳ್ಳೆಯ ದಿನ",
			BodyEn:   "Spread chali / rashi in a thin layer on clear, low-humidity days. Keep tarpaulin ready — evening showers are still possible in the ghats.",
			BodyKn:   "ಸ್ಪಷ್ಟ, ಕಡಿಮೆ ತೇವದ ದಿನಗಳಲ್ಲಿ ಚಾಲಿ/ರಾಶಿ ತೆಳುವಾಗಿ ಹರಡಿ. ಸಂಜೆ ಮಳೆಗೆ ಟಾರ್ಪಾಲಿನ್ ಸಿದ್ಧವಿರಲಿ.",
		})
	}

	if maxWind >= 28 {
		out = append(out, weatherSuggestion{
			Priority: "medium",
			Icon:     "wind",
			TitleEn:  "Strong wind — delay climbing",
			TitleKn:  "ಬಿರುಗಾಳಿ — ಮರ ಹತ್ತುವುದನ್ನು ಮುಂದೂಡಿ",
			BodyEn:   "Skip plucking and crown cleaning on windy days. Tie young palms if needed and keep harvested bunches from rolling off drying yards.",
			BodyKn:   "ಗಾಳಿಯ ದಿನ ಕೊಯ್ಲು ಮತ್ತು ಕಿರೀಟ ಸ್ವಚ್ಛತೆ ಬೇಡ. ಅಗತ್ಯವಿದ್ದರೆ ಎಳೆ ಗಿಡ ಕಟ್ಟಿ, ಒಣಗಿಸುವ ಅಂಗಳದಿಂದ ಗೊನೆ ಉರುಳದಂತೆ ನೋಡಿ.",
		})
	}

	month := time.Now().In(istLoc()).Month()
	if month >= time.May && month <= time.July && totalRain >= 20 && heavyDays == 0 {
		out = append(out, weatherSuggestion{
			Priority: "info",
			Icon:     "plant",
			TitleEn:  "Monsoon planting window",
			TitleKn:  "ಮುಂಗಾರು ನೆಡುವ ಅವಕಾಶ",
			BodyEn:   "Soil moisture is useful for new areca seedlings if the pit is not waterlogged. Plant on a break in the rain and firm the soil around the collar.",
			BodyKn:   "ಗುಂಡಿ ನೀರಿನಿಂದ ತುಂಬಿಲ್ಲದಿದ್ದರೆ ಹೊಸ ಅಡಿಕೆ ಸಸಿಗೆ ಮಣ್ಣಿನ ತೇವ ಒಳ್ಳೆಯದು. ಮಳೆ ನಿಂತಾಗ ನೆಟ್ಟು ಕಾಂಡದ ಸುತ್ತ ಮಣ್ಣು ಗಟ್ಟಿಗೊಳಿಸಿ.",
		})
	}

	if maxTemp >= 34 {
		out = append(out, weatherSuggestion{
			Priority: "medium",
			Icon:     "hot",
			TitleEn:  "Hot spell — shade and water",
			TitleKn:  "ಬಿಸಿಲು — ನೆರಳು ಮತ್ತು ನೀರು",
			BodyEn:   "Irrigate in the morning or evening. Shade young seedlings. Avoid spraying in peak heat.",
			BodyKn:   "ಬೆಳಿಗ್ಗೆ ಅಥವಾ ಸಂಜೆ ನೀರಾವರಿ. ಎಳೆ ಸಸಿಗೆ ನೆರಳು. ತೀವ್ರ ಬಿಸಿಲಿನಲ್ಲಿ ಸಿಂಪಡಿಸಬೇಡಿ.",
		})
	}

	return out
}

func istLoc() *time.Location {
	loc, err := time.LoadLocation("Asia/Kolkata")
	if err != nil {
		return time.FixedZone("IST", 5*3600+30*60)
	}
	return loc
}

func fetchOpenMeteo(loc weatherLocation) (*models.WeatherReport, error) {
	url := fmt.Sprintf(
		"https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,cloud_cover&daily=weather_code,temperature_2m_max,temperature_2m_min,temperature_2m_mean,precipitation_sum,precipitation_probability_max,relative_humidity_2m_mean,relative_humidity_2m_min,relative_humidity_2m_max,wind_speed_10m_max,wind_direction_10m_dominant,uv_index_max,cloud_cover_mean&timezone=Asia%%2FKolkata&forecast_days=7",
		loc.Lat, loc.Lng,
	)
	client := &http.Client{Timeout: 25 * time.Second}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "AgRazWeather/1.0 (https://agrazllp.com)")
	req.Header.Set("Accept", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("open-meteo HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	var om openMeteoResponse
	if err := json.Unmarshal(body, &om); err != nil {
		return nil, err
	}

	n := len(om.Daily.Time)
	days := make([]weatherDay, 0, n)
	for i := 0; i < n; i++ {
		code := 0
		if i < len(om.Daily.WeatherCode) {
			code = om.Daily.WeatherCode[i]
		}
		en, kn := weatherCondition(code)
		dateStr := ""
		if i < len(om.Daily.Time) {
			dateStr = om.Daily.Time[i]
		}
		wdEn, wdKn := "", ""
		if t, err := time.Parse("2006-01-02", dateStr); err == nil {
			wdEn = weekdayEn[t.Weekday()]
			wdKn = weekdayKn[t.Weekday()]
		}
		d := weatherDay{
			Date:        dateStr,
			Weekday:     wdEn,
			WeekdayKn:   wdKn,
			WeatherCode: code,
			ConditionEn: en,
			ConditionKn: kn,
			TempMax:     f64At(om.Daily.Temperature2mMax, i),
			TempMin:     f64At(om.Daily.Temperature2mMin, i),
			RainMM:      f64At(om.Daily.PrecipitationSum, i),
			RainProb:    intAt(om.Daily.PrecipitationProbabilityMax, i),
			Humidity:    f64At(om.Daily.RelativeHumidity2mMean, i),
			WindKmh:     f64At(om.Daily.WindSpeed10mMax, i),
			WindDir:     compassDir(f64At(om.Daily.WindDirection10mDominant, i)),
			CloudPct:    f64At(om.Daily.CloudCoverMean, i),
			UVIndex:     f64At(om.Daily.UVIndexMax, i),
			FeelsLikeC:  f64At(om.Daily.Temperature2mMean, i),
		}
		days = append(days, d)
	}

	suggestions := buildFarmSuggestions(days, loc)
	daysRaw, _ := json.Marshal(days)
	sugRaw, _ := json.Marshal(suggestions)
	curEn, curKn := weatherCondition(om.Current.WeatherCode)
	todayMax, todayMin, todayUV, todayRainProb := 0.0, 0.0, 0.0, 0
	if len(days) > 0 {
		todayMax = days[0].TempMax
		todayMin = days[0].TempMin
		todayUV = days[0].UVIndex
		todayRainProb = days[0].RainProb
	}

	return &models.WeatherReport{
		LocationKey:     loc.Key,
		LocationName:    loc.Name,
		District:        loc.District,
		Latitude:        loc.Lat,
		Longitude:       loc.Lng,
		FetchedAt:       time.Now().UTC(),
		Timezone:        firstNonEmpty(om.Timezone, "Asia/Kolkata"),
		TempC:           om.Current.Temperature2m,
		Humidity:        om.Current.RelativeHumidity2m,
		RainMM:          om.Current.Precipitation,
		WindKmh:         om.Current.WindSpeed10m,
		WeatherCode:     om.Current.WeatherCode,
		ConditionEn:     curEn,
		ConditionKn:     curKn,
		FeelsLikeC:      om.Current.ApparentTemperature,
		MinC:            todayMin,
		MaxC:            todayMax,
		WindDir:         compassDir(om.Current.WindDirection10m),
		CloudPct:        om.Current.CloudCover,
		UVIndex:         todayUV,
		RainProb:        todayRainProb,
		DaysJSON:        datatypes.JSON(daysRaw),
		SuggestionsJSON: datatypes.JSON(sugRaw),
		Source:          "open-meteo",
	}, nil
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func RefreshAllWeather() error {
	if weatherDB == nil {
		return fmt.Errorf("weather db not set")
	}
	weatherMu.Lock()
	defer weatherMu.Unlock()

	var firstErr error
	for _, loc := range weatherLocations {
		row, err := fetchOpenMeteo(loc)
		if err != nil {
			log.Printf("weather fetch %s: %v", loc.Key, err)
			if firstErr == nil {
				firstErr = err
			}
			continue
		}
		if err := weatherDB.Create(row).Error; err != nil {
			log.Printf("weather save %s: %v", loc.Key, err)
			if firstErr == nil {
				firstErr = err
			}
			continue
		}
		upsertForecastDailies(loc, row)
		if err := backfillWeatherHistory(loc); err != nil {
			log.Printf("weather history %s: %v", loc.Key, err)
		}
		insights := buildWeatherInsights(loc, row)
		if raw, err := json.Marshal(insights); err == nil {
			_ = weatherDB.Model(row).Update("insights_json", datatypes.JSON(raw)).Error
			row.InsightsJSON = datatypes.JSON(raw)
		}
		log.Printf("weather saved %s id=%d temp=%.1f", loc.Key, row.ID, row.TempC)
		pruneOldWeather(loc.Key)
	}
	return firstErr
}

func pruneOldWeather(locationKey string) {
	var keep []uint
	if err := weatherDB.Model(&models.WeatherReport{}).
		Where("location_key = ?", locationKey).
		Order("fetched_at DESC").
		Limit(60).
		Pluck("id", &keep).Error; err != nil || len(keep) == 0 {
		return
	}
	_ = weatherDB.Where("location_key = ? AND id NOT IN ?", locationKey, keep).
		Delete(&models.WeatherReport{}).Error
}

func StartWeatherScheduler() {
	go func() {
		if err := RefreshAllWeather(); err != nil {
			log.Printf("weather initial scrape: %v", err)
		}
		ticker := time.NewTicker(weatherRefreshEvery)
		defer ticker.Stop()
		for range ticker.C {
			if err := RefreshAllWeather(); err != nil {
				log.Printf("weather scheduled scrape: %v", err)
			}
		}
	}()
	log.Printf("weather scheduler started (every %s)", weatherRefreshEvery)
}

func publicWeatherPayload(row models.WeatherReport) fiber.Map {
	days := []weatherDay{}
	suggestions := []weatherSuggestion{}
	if len(row.DaysJSON) > 0 {
		_ = json.Unmarshal(row.DaysJSON, &days)
	}
	if len(row.SuggestionsJSON) > 0 {
		_ = json.Unmarshal(row.SuggestionsJSON, &suggestions)
	}
	insights := []weatherInsight{}
	if len(row.InsightsJSON) > 0 {
		_ = json.Unmarshal(row.InsightsJSON, &insights)
	}
	loc := findWeatherLocation(row.LocationKey)
	return fiber.Map{
		"id":            row.ID,
		"location_key":  row.LocationKey,
		"location_name": row.LocationName,
		"location_kn":   loc.NameKn,
		"district":      row.District,
		"latitude":      row.Latitude,
		"longitude":     row.Longitude,
		"fetched_at":    row.FetchedAt,
		"timezone":      row.Timezone,
		"source":        row.Source,
		"refresh_hours": 8,
		"current": fiber.Map{
			"temp_c":                row.TempC,
			"feels_like_c":          row.FeelsLikeC,
			"min_c":                 row.MinC,
			"max_c":                 row.MaxC,
			"humidity":              row.Humidity,
			"rain_mm":               row.RainMM,
			"rain_probability_pct":  row.RainProb,
			"wind_kmh":              row.WindKmh,
			"wind_direction":        row.WindDir,
			"cloud_cover_pct":       row.CloudPct,
			"uv_index":              row.UVIndex,
			"weather_code":          row.WeatherCode,
			"condition_en":          row.ConditionEn,
			"condition_kn":          row.ConditionKn,
		},
		"days":        days,
		"suggestions": suggestions,
		"insights":    insights,
	}
}

func GetWeatherLocationsPublic(c *fiber.Ctx) error {
	type locOut struct {
		Key        string     `json:"key"`
		Name       string     `json:"name"`
		NameKn     string     `json:"name_kn"`
		District   string     `json:"district"`
		FetchedAt  *time.Time `json:"fetched_at,omitempty"`
	}
	out := make([]locOut, 0, len(weatherLocations))
	for _, loc := range weatherLocations {
		item := locOut{Key: loc.Key, Name: loc.Name, NameKn: loc.NameKn, District: loc.District}
		var row models.WeatherReport
		if weatherDB != nil {
			err := weatherDB.Where("location_key = ?", loc.Key).
				Order("fetched_at DESC").
				First(&row).Error
			if err == nil {
				t := row.FetchedAt
				item.FetchedAt = &t
			}
		}
		out = append(out, item)
	}
	return c.JSON(fiber.Map{"data": out})
}

func GetWeatherReportPublic(c *fiber.Ctx) error {
	key := strings.ToLower(strings.TrimSpace(c.Query("location")))
	if key == "" {
		key = "sirsi"
	}
	loc := findWeatherLocation(key)
	if weatherDB == nil {
		return c.Status(503).JSON(fiber.Map{"error": "weather not ready"})
	}
	var row models.WeatherReport
	err := weatherDB.Where("location_key = ?", loc.Key).
		Order("fetched_at DESC").
		First(&row).Error
	if err != nil {
		_ = RefreshAllWeather()
		err = weatherDB.Where("location_key = ?", loc.Key).
			Order("fetched_at DESC").
			First(&row).Error
	}
	if err != nil {
		return c.Status(503).JSON(fiber.Map{
			"error":   "weather report not ready yet",
			"message": "Report is being fetched. Please retry in a minute.",
		})
	}
	return c.JSON(fiber.Map{"data": publicWeatherPayload(row)})
}

func weatherCronAuthorized(c *fiber.Ctx) bool {
	secret := strings.TrimSpace(os.Getenv("WEATHER_CRON_SECRET"))
	got := strings.TrimSpace(c.Get("X-Weather-Cron-Token"))
	if got == "" {
		got = strings.TrimSpace(c.Query("token"))
	}
	if secret != "" {
		return got == secret
	}
	ip := c.IP()
	return ip == "127.0.0.1" || ip == "::1" || strings.HasPrefix(ip, "127.")
}

func WeatherCronRefresh(c *fiber.Ctx) error {
	if !weatherCronAuthorized(c) {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	if err := RefreshAllWeather(); err != nil {
		return c.Status(502).JSON(fiber.Map{"error": err.Error(), "ok": false})
	}
	return c.JSON(fiber.Map{"ok": true, "refreshed_at": time.Now().UTC()})
}

func AdminRefreshWeather(c *fiber.Ctx) error {
	if err := RefreshAllWeather(); err != nil {
		return c.Status(502).JSON(fiber.Map{"error": err.Error(), "ok": false})
	}
	return c.JSON(fiber.Map{"ok": true, "refreshed_at": time.Now().UTC()})
}
