package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"rally-point/ministry-service/internal/handler"
	"rally-point/ministry-service/internal/repository/postgres"
	"rally-point/ministry-service/internal/service"

	"github.com/gin-gonic/gin"
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

	// Initialize NATS connection (optional)
	natsURL := getEnv("NATS_URL", "nats://localhost:4222")
	if !strings.HasPrefix(natsURL, "nats://") && !strings.HasPrefix(natsURL, "tls://") && !strings.HasPrefix(natsURL, "ws://") {
		natsURL = "nats://" + natsURL
	}

	var natsConn *nats.Conn
	natsConn, err = nats.Connect(natsURL)
	if err != nil {
		log.Printf("Warning: failed to connect to NATS at %s: %v", natsURL, err)
	} else {
		defer natsConn.Drain()
	}

	// Initialize components
	repo := postgres.NewMinistryContactRepository(db.DB)
	service := service.NewMinistryContactService(repo, natsConn)

	// Initialize handlers
	handler := handler.NewMinistryContactHandler(service, jwtManager)

	// Setup router
	router := setupRouter(handler)

	// Server configuration
	port := getEnv("PORT", "8087")
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🚀 Ministry service starting on port %s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 Shutting down ministry service...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("✅ Ministry service exited")
}

func setupRouter(handler *handler.MinistryContactHandler) *gin.Engine {
	// Set Gin mode
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// CORS middleware
	router.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Health check
	router.GET("/health", handler.HealthCheck)

	// API routes
	api := router.Group("/api")

	// Protected routes
	protected := api.Group("/")
	protected.Use(handler.AuthMiddleware())
	{
		contacts := protected.Group("/ministry-contacts")
		{
			contacts.GET("/", handler.ListContacts)
			contacts.GET("", handler.ListContacts)
			contacts.POST("/", handler.CreateContact)
			contacts.GET("/:id", handler.GetContact)
			contacts.PUT("/:id", handler.UpdateContact)
			contacts.DELETE("/:id", handler.DeleteContact)
			contacts.GET("/stats", handler.GetStats)
			contacts.GET("/export", handler.ExportContacts)
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
