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

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/nats-io/nats.go"
	"github.com/rally-point/shared/auth"
	"github.com/rally-point/shared/database"
	"rally-point/survey-service/internal/handler"
	"rally-point/survey-service/internal/repository/postgres"
	"rally-point/survey-service/internal/service"
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

	// Connect to NATS for notification publishing
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
			log.Printf("Warning: failed to connect to NATS (%s): %v", natsURL, natsErr)
			nc = nil
		} else {
			log.Printf("Connected to NATS at %s", natsURL)
			defer nc.Drain()
		}
	}

	// Initialize components
	surveyRepo := postgres.NewSurveyRepository(db.DB)
	surveyService := service.NewSurveyService(surveyRepo, nc)

	// Initialize handlers
	surveyHandler := handler.NewSurveyHandler(surveyService, jwtManager)

	// Setup router
	router := setupRouter(surveyHandler)

	// Server configuration
	port := getEnv("PORT", "8084")
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🚀 Survey service starting on port %s", port)
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

func setupRouter(surveyHandler *handler.SurveyHandler) *gin.Engine {
	// Set Gin mode
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// Disable automatic trailing slash redirect (causes 307 issues with POST)
	router.RedirectTrailingSlash = false

	// NOTE: CORS is handled by API Gateway - do NOT add CORS middleware here
	// Adding CORS headers here causes duplicate headers when proxied through gateway

	// Health check
	router.GET("/health", surveyHandler.HealthCheck)

	// API routes
	api := router.Group("/api")
	
	// Protected routes
	protected := api.Group("/")
	protected.Use(surveyHandler.AuthMiddleware())
	{
		// Survey management - handle both with and without trailing slash
		surveys := protected.Group("/surveys")
		{
			// Without trailing slash (primary)
			surveys.GET("", surveyHandler.ListSurveys)
			surveys.POST("", surveyHandler.CreateSurvey)
			// With trailing slash (fallback)
			surveys.GET("/", surveyHandler.ListSurveys)
			surveys.POST("/", surveyHandler.CreateSurvey)
			surveys.GET("/:id", surveyHandler.GetSurvey)
			surveys.PUT("/:id", surveyHandler.UpdateSurvey)
			surveys.DELETE("/:id", surveyHandler.DeleteSurvey)
			surveys.GET("/:id/responses", surveyHandler.GetSurveyResponses)
			surveys.POST("/:id/responses", surveyHandler.SubmitSurveyResponse)
			surveys.GET("/:id/analytics", surveyHandler.GetSurveyAnalytics)
			surveys.POST("/:id/assignments", surveyHandler.AssignSurveyToWorkers)

			// Question management
			surveys.POST("/:id/questions", surveyHandler.AddQuestion)
			surveys.PUT("/:id/questions/:questionId", surveyHandler.UpdateQuestion)
			surveys.DELETE("/:id/questions/:questionId", surveyHandler.DeleteQuestion)
			surveys.PUT("/:id/questions/reorder", surveyHandler.ReorderQuestions)
		}

		// Team surveys
		teams := protected.Group("/teams")
		{
			teams.GET("/:teamId/surveys", surveyHandler.GetTeamSurveys)
			teams.GET("/:teamId/stats", surveyHandler.GetTeamSurveyStats)
		}

		// User surveys and responses
		users := protected.Group("/users")
		{
			users.GET("/surveys", surveyHandler.GetUserSurveys)
			users.GET("/responses", surveyHandler.GetUserResponses)
			users.GET("/assignments", surveyHandler.GetUserAssignments)
		}

		// Response submission
		responses := protected.Group("/responses")
		{
			responses.POST("/", surveyHandler.SubmitResponse)
		}

		// Survey assignments
		assignments := protected.Group("/assignments")
		{
			assignments.POST("/", surveyHandler.AssignSurvey)
		}

		// Worker-specific endpoints (for team leaders/admins)
		workers := protected.Group("/workers")
		{
			workers.GET("/:workerId/survey-stats", surveyHandler.GetWorkerSurveyStats)
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
