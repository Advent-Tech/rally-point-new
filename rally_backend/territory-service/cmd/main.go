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

	"rally-point/territory-service/internal/handler"
	"rally-point/territory-service/internal/importer"
	"rally-point/territory-service/internal/realtime"
	"rally-point/territory-service/internal/repository/postgres"
	"rally-point/territory-service/internal/service"

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
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     getEnvAsInt("DB_PORT", 5432),
		User:     getEnv("DB_USER", "rally_user"),
		Password: getEnv("DB_PASSWORD", "rally_password"),
		DBName:   getEnv("DB_NAME", "rally_point"),
		SSLMode:  getEnv("DB_SSL_MODE", "disable"),
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
	territoryRepo := postgres.NewTerritoryRepository(db.DB)
	geofenceManager := service.NewGeofenceManager()
	realtimeManager := realtime.NewRealtimeManager()
	territoryService := service.NewTerritoryService(territoryRepo, geofenceManager, realtimeManager)

	// Initialize geo territory components
	geoTerritoryRepo := postgres.NewGeoTerritoryRepository(db.DB)
	geoImporter := importer.NewGeoPackageImporter(db.DB)
	geoTerritoryService := service.NewGeoTerritoryService(geoTerritoryRepo, geoImporter)

	// Initialize assignment components
	assignmentRepo := postgres.NewAssignmentRepository(db.DB)
	assignmentService := service.NewAssignmentService(assignmentRepo)

	// Initialize geofence components
	geofenceRepo := postgres.NewGeofenceRepository(db.DB)
	geofenceService := service.NewGeofenceService(geofenceRepo, geofenceManager)

	// Initialize schedule components
	scheduleRepo := postgres.NewScheduleRepository(db.DB)
	scheduleService := service.NewScheduleService(scheduleRepo)

	// Initialize handlers
	territoryHandler := handler.NewTerritoryHandler(territoryService, jwtManager)
	geoTerritoryHandler := handler.NewGeoTerritoryHandler(geoTerritoryService)
	assignmentHandler := handler.NewAssignmentHandler(assignmentService)
	geofenceHandler := handler.NewGeofenceHandler(geofenceService)
	scheduleHandler := handler.NewScheduleHandler(scheduleService)

	// Setup router
	router := setupRouter(territoryHandler, geoTerritoryHandler, assignmentHandler, geofenceHandler, scheduleHandler)

	// Server configuration
	port := getEnv("PORT", "8083")
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🚀 Territory service starting on port %s", port)
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

func setupRouter(territoryHandler *handler.TerritoryHandler, geoHandler *handler.GeoTerritoryHandler, assignmentHandler *handler.AssignmentHandler, geofenceHandler *handler.GeofenceHandler, scheduleHandler *handler.ScheduleHandler) *gin.Engine {
	// Set Gin mode
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// Health check
	router.GET("/health", territoryHandler.HealthCheck)

	// WebSocket endpoint for real-time alerts
	router.GET("/ws/territory", territoryHandler.WebSocketHandler)

	// API routes
	api := router.Group("/api")

	// Protected routes
	protected := api.Group("/")
	protected.Use(territoryHandler.AuthMiddleware())
	{
		// Territory management
		territories := protected.Group("/territories")
		{
			territories.POST("/", territoryHandler.CreateTerritory)
			territories.GET("/:id", territoryHandler.GetTerritory)
			territories.PUT("/:id", territoryHandler.UpdateTerritory)
			territories.DELETE("/:id", territoryHandler.DeleteTerritory)
			territories.GET("/:id/entries", territoryHandler.GetTerritoryEntries)
			territories.GET("/team/:teamId", territoryHandler.GetTeamTerritories)
			territories.GET("/worker/:workerId", territoryHandler.GetWorkerTerritories)
		}

		// Team territories
		teams := protected.Group("/teams")
		{
			teams.GET("/:teamId/territories", territoryHandler.GetTeamTerritories)
			teams.GET("/:teamId/alerts", territoryHandler.GetTeamAlerts)
			teams.GET("/:teamId/stats", territoryHandler.GetTerritoryStats)
		}

		// Worker territories
		workers := protected.Group("/workers")
		{
			workers.GET("/:workerId/territories", territoryHandler.GetWorkerTerritories)
		}

		// Location tracking
		tracking := protected.Group("/tracking")
		{
			tracking.POST("/location", territoryHandler.TrackWorkerLocation)
			tracking.GET("/status", territoryHandler.GetWorkerStatus)
		}

		// User data
		users := protected.Group("/users")
		{
			users.GET("/entries", territoryHandler.GetUserEntries)
			users.GET("/alerts", territoryHandler.GetUserAlerts)
			users.GET("/stats", territoryHandler.GetUserTerritoryStats)
		}

		// Alerts
		alerts := protected.Group("/alerts")
		{
			alerts.PUT("/:alertId/read", territoryHandler.MarkAlertRead)
		}
	}

	// Register geo territory routes (public for now, add auth as needed)
	geoHandler.RegisterRoutes(api)

	// Register assignment routes
	assignmentHandler.RegisterRoutes(api)

	// Register geofence routes
	geofenceHandler.RegisterRoutes(api)

	// Register schedule routes
	scheduleHandler.RegisterRoutes(api)

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
