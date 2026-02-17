package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"rally-point/location-service/internal/client"
	"rally-point/location-service/internal/domain"
	"rally-point/location-service/internal/events"
	"rally-point/location-service/internal/handler"
	"rally-point/location-service/internal/realtime"
	"rally-point/location-service/internal/repository/postgres"
	"rally-point/location-service/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/rally-point/shared/auth"
	"github.com/rally-point/shared/database"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Database configuration
	dbConfig := database.Config{
		Host:                   getEnv("DB_HOST", "localhost"),
		Port:                   getEnvAsInt("DB_PORT", 5432),
		User:                   getEnv("DB_USER", "rally_user"),
		Password:               getEnv("DB_PASSWORD", "rally_password"),
		DBName:                 getEnv("DB_NAME", "rally_point"),
		SSLMode:                getEnv("DB_SSL_MODE", "disable"),
		MaxOpenConns:           getEnvAsInt("DB_MAX_OPEN_CONNS", 0),
		MaxIdleConns:           getEnvAsInt("DB_MAX_IDLE_CONNS", 0),
		ConnMaxLifetimeSeconds: getEnvAsInt("DB_CONN_MAX_LIFETIME", 0),
	}

	// Connect to database
	db, err := database.NewConnection(dbConfig)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Initialize JWT manager
	jwtSecret := getEnv("JWT_SECRET", "your-super-secret-jwt-key-change-in-production")
	jwtManager := auth.NewJWTManager(
		jwtSecret,
		15*time.Minute, // Access token duration
		7*24*time.Hour, // Refresh token duration
	)

	// Initialize components
	locationRepo := postgres.NewLocationRepository(db.DB)
	realtimeManager := realtime.NewRealtimeManager()
	distanceCalc := service.NewDistanceCalculator()

	// Try NATS first for async geofence processing, fall back to sync HTTP
	var locationService = func() domain.LocationService {
		natsURL := getEnv("NATS_URL", "")
		if natsURL != "" {
			publisher, err := events.NewNATSPublisher(natsURL)
			if err != nil {
				log.Printf("Warning: failed to connect to NATS (%s), falling back to sync geofence: %v", natsURL, err)
			} else {
				log.Printf("Connected to NATS at %s - geofence checks will be async", natsURL)
				return service.NewLocationServiceWithNATS(locationRepo, realtimeManager, distanceCalc, publisher)
			}
		}
		// Fallback: synchronous HTTP geofence client
		territoryServiceURL := getEnv("TERRITORY_SERVICE_URL", "http://localhost:8083")
		geofenceClient := client.NewGeofenceClient(territoryServiceURL)
		return service.NewLocationServiceWithGeofence(locationRepo, realtimeManager, distanceCalc, geofenceClient)
	}()

	// Initialize handlers
	locationHandler := handler.NewLocationHandler(locationService, jwtManager)

	// Setup router
	router := setupRouter(locationHandler)

	// Server configuration
	port := getEnv("PORT", "8082")
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🚀 Location service starting on port %s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("✅ Server exited")
}

func setupRouter(locationHandler *handler.LocationHandler) *gin.Engine {
	// Set Gin mode
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// CORS middleware
	router.Use(func(c *gin.Context) {
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Health check
	router.GET("/health", locationHandler.HealthCheck)

	// WebSocket endpoint for real-time location updates
	router.GET("/ws/location", locationHandler.WebSocketHandler)

	// API routes
	api := router.Group("/api")

	// Protected routes
	protected := api.Group("/")
	protected.Use(locationHandler.AuthMiddleware())
	{
		// Location tracking
		locations := protected.Group("/location")
		{
			locations.POST("/update", locationHandler.UpdateLocation)
			locations.GET("/history", locationHandler.GetUserLocations)
			locations.GET("/stats", locationHandler.GetLocationStats)
		}

		// Session management
		sessions := protected.Group("/sessions")
		{
			sessions.POST("/start", locationHandler.StartSession)
			sessions.PUT("/:id/end", locationHandler.EndSession)
			sessions.GET("/active", locationHandler.GetActiveSession)
			sessions.GET("/", locationHandler.GetUserSessions)
		}

		// Worker management
		workers := protected.Group("/workers")
		{
			workers.GET("/active", locationHandler.GetActiveWorkers)
			workers.PUT("/offline", locationHandler.SetWorkerOffline)
			// Worker-specific endpoints (for team leaders/admins)
			workers.GET("/:workerId/path-history", locationHandler.GetWorkerPathHistory)
			workers.GET("/:workerId/location-stats", locationHandler.GetWorkerLocationStats)
			workers.GET("/:workerId/sessions", locationHandler.GetWorkerSessions)
		}
	}

	return router
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}
