package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"rally-point/territory-service/internal/domain"
	"rally-point/territory-service/internal/handler"
	"rally-point/territory-service/internal/importer"
	"rally-point/territory-service/internal/realtime"
	"rally-point/territory-service/internal/repository/postgres"
	"rally-point/territory-service/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"github.com/nats-io/nats.go"
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

	// Connect to NATS for location events and notification publishing
	var nc *nats.Conn
	natsURL := getEnv("NATS_URL", "")
	if natsURL != "" {
		var natsErr error
		nc, natsErr = nats.Connect(natsURL,
			nats.RetryOnFailedConnect(true),
			nats.MaxReconnects(10),
			nats.ReconnectWait(2*time.Second),
		)
		if natsErr != nil {
			log.Printf("Warning: failed to connect to NATS (%s): %v - geofence will only work via HTTP", natsURL, natsErr)
			nc = nil
		} else {
			log.Printf("Connected to NATS at %s", natsURL)
			defer nc.Drain()
		}
	}

	// Initialize geofence components
	geofenceRepo := postgres.NewGeofenceRepository(db.DB)
	geofenceService := service.NewGeofenceService(geofenceRepo, geofenceManager, nc)

	// Initialize schedule components
	scheduleRepo := postgres.NewScheduleRepository(db.DB)
	scheduleService := service.NewScheduleService(scheduleRepo)

	// Initialize allocation components (admin → team leader territory allocations)
	allocationRepo := postgres.NewAllocationRepository(db.DB)
	allocationService := service.NewAllocationService(allocationRepo)

	// Initialize assignment service (after NATS so it can publish notifications)
	assignmentService := service.NewAssignmentService(assignmentRepo, nc)

	// Subscribe to NATS location events for async geofence processing
	if nc != nil {
		_, err := nc.Subscribe("location.update", func(msg *nats.Msg) {
				var event struct {
					WorkerID  uuid.UUID  `json:"worker_id"`
					TeamID    *uuid.UUID `json:"team_id,omitempty"`
					Latitude  float64    `json:"latitude"`
					Longitude float64    `json:"longitude"`
					SessionID *uuid.UUID `json:"session_id,omitempty"`
					Timestamp time.Time  `json:"timestamp"`
				}
				if err := json.Unmarshal(msg.Data, &event); err != nil {
					log.Printf("Warning: failed to unmarshal NATS location event: %v", err)
					return
				}
				update := &domain.WorkerLocationUpdate{
					WorkerID:  event.WorkerID,
					TeamID:    event.TeamID,
					Latitude:  event.Latitude,
					Longitude: event.Longitude,
					Timestamp: event.Timestamp,
				}
				if update.Timestamp.IsZero() {
					update.Timestamp = time.Now()
				}
				geofenceResult, err := geofenceService.ProcessLocationUpdate(update)
				if err != nil {
					log.Printf("Warning: NATS geofence processing failed for worker %s: %v", event.WorkerID, err)
					return
				}
				if geofenceResult != nil {
					log.Printf("Geofence event via NATS: %s - Territory: %s, Worker: %s",
						geofenceResult.EventType, geofenceResult.TerritoryName, event.WorkerID)

					// Publish geofence notification — notify team leader about worker movement
					titleVerb := "entered"
					bodyText := "Work session started"
					if geofenceResult.EventType == "exit" {
						titleVerb = "left"
						bodyText = "Work session ended"
					}

					// Use team_leader if team_id available, else team_leader_of_user
					targetType := "team_leader_of_user"
					targetID := event.WorkerID.String()
					if event.TeamID != nil {
						targetType = "team_leader"
						targetID = event.TeamID.String()
					}

					notifyEvent := map[string]interface{}{
						"event_type":        "territory.geofence." + geofenceResult.EventType,
						"target_type":       targetType,
						"target_id":         targetID,
						"actor_id":          event.WorkerID.String(),
						"title":             fmt.Sprintf("Worker %s %s", titleVerb, geofenceResult.TerritoryName),
						"body":              bodyText,
						"data":              map[string]interface{}{"territory_id": geofenceResult.TerritoryID.String(), "worker_id": event.WorkerID.String()},
						"priority":          "normal",
						"notification_type": "geofence",
						"group_key":         "geofence:" + geofenceResult.TerritoryID.String(),
						"created_at":        time.Now().Format(time.RFC3339),
					}
					if geofenceResult.SessionID != nil {
						notifyEvent["data"].(map[string]interface{})["session_id"] = geofenceResult.SessionID.String()
					}
					notifyData, _ := json.Marshal(notifyEvent)
					if pubErr := nc.Publish("notify.territory.geofence", notifyData); pubErr != nil {
						log.Printf("Failed to publish geofence notification: %v", pubErr)
					}
				}
			})
			if err != nil {
				log.Printf("Warning: failed to subscribe to location.update: %v", err)
			} else {
				log.Println("Subscribed to location.update NATS topic for geofence processing")
			}
	}

	// Initialize handlers
	territoryHandler := handler.NewTerritoryHandler(territoryService, jwtManager)
	geoTerritoryHandler := handler.NewGeoTerritoryHandler(geoTerritoryService)
	assignmentHandler := handler.NewAssignmentHandler(assignmentService)
	geofenceHandler := handler.NewGeofenceHandler(geofenceService)
	scheduleHandler := handler.NewScheduleHandler(scheduleService)
	allocationHandler := handler.NewAllocationHandler(allocationService)

	// Setup router
	router := setupRouter(territoryHandler, geoTerritoryHandler, assignmentHandler, geofenceHandler, scheduleHandler, allocationHandler)

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

func setupRouter(
	territoryHandler *handler.TerritoryHandler,
	geoHandler *handler.GeoTerritoryHandler,
	assignmentHandler *handler.AssignmentHandler,
	geofenceHandler *handler.GeofenceHandler,
	scheduleHandler *handler.ScheduleHandler,
	allocationHandler *handler.AllocationHandler,
) *gin.Engine {
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

			// Leader allocation routes (team leaders view their allocated territories)
			territories.GET("/my-allocations", allocationHandler.GetMyAllocations)
			territories.GET("/my-allocations/geojson", allocationHandler.GetMyAllocationsGeoJSON)
			territories.GET("/my-allocations/stats", allocationHandler.GetMyAllocationStats)
			territories.GET("/can-assign/:territoryId", allocationHandler.CheckCanAssign)
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

		// Admin allocation routes (admin allocates territories to team leaders)
		admin := protected.Group("/admin")
		{
			admin.POST("/territories/allocate", allocationHandler.AllocateTerritory)
			admin.POST("/territories/allocate-bulk", allocationHandler.AllocateTerritories)
			admin.GET("/territories/allocations", allocationHandler.ListAllAllocations)
			admin.GET("/territories/allocations/:id", allocationHandler.GetAllocation)
			admin.DELETE("/territories/allocations/:id", allocationHandler.RevokeAllocation)
			admin.GET("/territories/allocations/leader/:leaderId", allocationHandler.GetLeaderAllocations)
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
