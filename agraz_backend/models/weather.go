package models

import (
	"time"

	"gorm.io/datatypes"
)

// WeatherReport is a cached 7-day forecast snapshot for one location.
// The scheduler writes a new row about every 8 hours.
type WeatherReport struct {
	ID              uint           `gorm:"primaryKey;autoIncrement" json:"id"`
	LocationKey     string         `gorm:"type:varchar(50);not null;index" json:"location_key"`
	LocationName    string         `gorm:"type:varchar(100);not null;default:''" json:"location_name"`
	District        string         `gorm:"type:varchar(100);not null;default:''" json:"district"`
	Latitude        float64        `gorm:"not null;default:0" json:"latitude"`
	Longitude       float64        `gorm:"not null;default:0" json:"longitude"`
	FetchedAt       time.Time      `gorm:"not null;index" json:"fetched_at"`
	Timezone        string         `gorm:"type:varchar(64);not null;default:'Asia/Kolkata'" json:"timezone"`
	TempC           float64        `gorm:"not null;default:0" json:"temp_c"`
	Humidity        float64        `gorm:"not null;default:0" json:"humidity"`
	RainMM          float64        `gorm:"not null;default:0" json:"rain_mm"`
	WindKmh         float64        `gorm:"not null;default:0" json:"wind_kmh"`
	WeatherCode     int            `gorm:"not null;default:0" json:"weather_code"`
	ConditionEn     string         `gorm:"type:varchar(120);not null;default:''" json:"condition_en"`
	ConditionKn     string         `gorm:"type:varchar(120);not null;default:''" json:"condition_kn"`
	FeelsLikeC      float64        `gorm:"not null;default:0" json:"feels_like_c"`
	MinC            float64        `gorm:"not null;default:0" json:"min_c"`
	MaxC            float64        `gorm:"not null;default:0" json:"max_c"`
	WindDir         string         `gorm:"type:varchar(8);not null;default:''" json:"wind_direction"`
	CloudPct        float64        `gorm:"not null;default:0" json:"cloud_cover_pct"`
	UVIndex         float64        `gorm:"not null;default:0" json:"uv_index"`
	RainProb        int            `gorm:"not null;default:0" json:"rain_probability_pct"`
	DaysJSON        datatypes.JSON `gorm:"type:jsonb;not null;default:'[]'" json:"days"`
	SuggestionsJSON datatypes.JSON `gorm:"type:jsonb;not null;default:'[]'" json:"suggestions"`
	InsightsJSON    datatypes.JSON `gorm:"type:jsonb;not null;default:'[]'" json:"insights"`
	Source          string         `gorm:"type:varchar(40);not null;default:'open-meteo'" json:"source"`
	CreatedAt       time.Time      `json:"created_at"`
}

func (WeatherReport) TableName() string { return "weather_reports" }

// WeatherDaily is one calendar-day row per location (history, today, forecast).
// Column names follow the AgRaz weather data design sheet.
type WeatherDaily struct {
	ID                   uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	LocationID           string    `gorm:"column:location_id;type:varchar(50);not null;uniqueIndex:idx_wd_loc_date" json:"location_id"`
	LocationName         string    `gorm:"column:location_name;type:varchar(100);not null;default:''" json:"location_name"`
	District             string    `gorm:"type:varchar(100);not null;default:''" json:"district"`
	Latitude             float64   `gorm:"not null;default:0" json:"latitude"`
	Longitude            float64   `gorm:"not null;default:0" json:"longitude"`
	Year                 int       `gorm:"not null;index" json:"year"`
	Month                int       `gorm:"not null;index" json:"month"`
	Date                 time.Time `gorm:"type:date;not null;uniqueIndex:idx_wd_loc_date" json:"date"`
	ObsTime              string    `gorm:"column:obs_time;type:varchar(8);not null;default:''" json:"time"`
	WeatherType          string    `gorm:"column:weather_type;type:varchar(20);not null;default:'HISTORY';index" json:"weather_type"`
	WeatherCondition     string    `gorm:"column:weather_condition;type:varchar(120);not null;default:''" json:"weather_condition"`
	WeatherConditionKn   string    `gorm:"column:weather_condition_kn;type:varchar(120);not null;default:''" json:"weather_condition_kn"`
	TemperatureC         float64   `gorm:"column:temperature_c;not null;default:0" json:"temperature_c"`
	MinTemperatureC      float64   `gorm:"column:min_temperature_c;not null;default:0" json:"min_temperature_c"`
	MaxTemperatureC      float64   `gorm:"column:max_temperature_c;not null;default:0" json:"max_temperature_c"`
	FeelsLikeC           float64   `gorm:"column:feels_like_c;not null;default:0" json:"feels_like_c"`
	HumidityPct          float64   `gorm:"column:humidity_pct;not null;default:0" json:"humidity_pct"`
	MinHumidityPct       float64   `gorm:"column:min_humidity_pct;not null;default:0" json:"min_humidity_pct"`
	MaxHumidityPct       float64   `gorm:"column:max_humidity_pct;not null;default:0" json:"max_humidity_pct"`
	RainfallMM           float64   `gorm:"column:rainfall_mm;not null;default:0" json:"rainfall_mm"`
	RainProbabilityPct   int       `gorm:"column:rain_probability_pct;not null;default:0" json:"rain_probability_pct"`
	WindSpeedKmph        float64   `gorm:"column:wind_speed_kmph;not null;default:0" json:"wind_speed_kmph"`
	WindDirection        string    `gorm:"column:wind_direction;type:varchar(8);not null;default:''" json:"wind_direction"`
	CloudCoverPct        float64   `gorm:"column:cloud_cover_pct;not null;default:0" json:"cloud_cover_pct"`
	UVIndex              float64   `gorm:"column:uv_index;not null;default:0" json:"uv_index"`
	ForecastDay          int       `gorm:"column:forecast_day;not null;default:0" json:"forecast_day"`
	DataSource           string    `gorm:"column:data_source;type:varchar(40);not null;default:'open-meteo'" json:"data_source"`
	LastUpdated          time.Time `gorm:"column:last_updated" json:"last_updated"`
	WeatherCode          int       `gorm:"not null;default:0" json:"weather_code"`
}

func (WeatherDaily) TableName() string { return "weather_data" }
