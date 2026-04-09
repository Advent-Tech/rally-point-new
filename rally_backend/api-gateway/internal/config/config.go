package config

import (
	"os"
	"strconv"
	"time"
)

// Config holds all configuration for the API Gateway
type Config struct {
	Server    ServerConfig
	Services  ServicesConfig
	Redis     RedisConfig
	JWT       JWTConfig
	RateLimit RateLimitConfig
	Database  DatabaseConfig
	Firebase  FirebaseConfig
}

// DatabaseConfig holds PostgreSQL configuration
type DatabaseConfig struct {
	Host     string
	Port     string
	Name     string
	User     string
	Password string
}

// FirebaseConfig holds Firebase Cloud Messaging configuration
type FirebaseConfig struct {
	ProjectID   string
	PrivateKey  string
	ClientEmail string
}

// ServerConfig holds server configuration
type ServerConfig struct {
	Port         string
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	IdleTimeout  time.Duration
}

// ServicesConfig holds microservices endpoints
type ServicesConfig struct {
	UserService      string
	LocationService  string
	WalkieService    string
	TerritoryService string
	SurveyService    string
	DeliveryService  string
	MinistryService  string
}

// RedisConfig holds Redis configuration
type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

// JWTConfig holds JWT configuration
type JWTConfig struct {
	Secret               string
	AccessTokenDuration  time.Duration
	RefreshTokenDuration time.Duration
}

// RateLimitConfig holds rate limiting configuration
type RateLimitConfig struct {
	RequestsPerMinute int
	BurstSize         int
}

// Load loads configuration from environment variables
func Load() *Config {
	return &Config{
		Server: ServerConfig{
			Port:         getEnv("PORT", "8080"),
			ReadTimeout:  getDurationEnv("SERVER_READ_TIMEOUT", 30*time.Second),
			WriteTimeout: getDurationEnv("SERVER_WRITE_TIMEOUT", 30*time.Second),
			IdleTimeout:  getDurationEnv("SERVER_IDLE_TIMEOUT", 120*time.Second),
		},
		Services: ServicesConfig{
			UserService:      getEnv("USER_SERVICE_URL", "http://user-service:8081"),
			LocationService:  getEnv("LOCATION_SERVICE_URL", "http://location-service:8082"),
			WalkieService:    getEnv("WALKIE_SERVICE_URL", "http://walkie-service:8086"),
			TerritoryService: getEnv("TERRITORY_SERVICE_URL", "http://territory-service:8084"),
			SurveyService:    getEnv("SURVEY_SERVICE_URL", "http://survey-service:8085"),
			DeliveryService:  getEnv("DELIVERY_SERVICE_URL", "http://delivery-service:8087"),
			MinistryService:  getEnv("MINISTRY_SERVICE_URL", "http://ministry-service:8088"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getIntEnv("REDIS_DB", 0),
		},
		JWT: JWTConfig{
			Secret:               getEnv("JWT_SECRET", "your-super-secret-jwt-key-change-in-production"),
			AccessTokenDuration:  getDurationEnv("JWT_ACCESS_DURATION", 15*time.Minute),
			RefreshTokenDuration: getDurationEnv("JWT_REFRESH_DURATION", 7*24*time.Hour),
		},
		RateLimit: RateLimitConfig{
			RequestsPerMinute: getIntEnv("RATE_LIMIT_RPM", 100),
			BurstSize:         getIntEnv("RATE_LIMIT_BURST", 10),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			Name:     getEnv("DB_NAME", "rally_point"),
			User:     getEnv("DB_USER", "rally_user"),
			Password: getEnv("DB_PASSWORD", "rally_password"),
		},
		Firebase: FirebaseConfig{
			ProjectID:   getEnv("FIREBASE_PROJECT_ID", ""),
			PrivateKey:  getEnv("FIREBASE_PRIVATE_KEY", ""),
			ClientEmail: getEnv("FIREBASE_CLIENT_EMAIL", ""),
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getIntEnv(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getDurationEnv(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	return defaultValue
}
