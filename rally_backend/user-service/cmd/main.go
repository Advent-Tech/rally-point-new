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

	"rally-point/user-service/internal/handler"
	"rally-point/user-service/internal/repository/postgres"
	"rally-point/user-service/internal/service"

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

	// Initialize repositories
	userRepo := postgres.NewUserRepository(db.DB)
	teamRepo := postgres.NewTeamRepository(db.DB)
	sessionRepo := postgres.NewSessionRepository(db.DB)

	// Initialize services
	teamService := service.NewTeamService(teamRepo, db.DB)
	userService := service.NewUserService(userRepo, sessionRepo, jwtManager, db.DB)

	// Initialize handlers
	userHandler := handler.NewUserHandler(userService, teamService, jwtManager)

	// Setup router
	router := setupRouter(userHandler)

	// Server configuration
	port := getEnv("PORT", "8081")
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🚀 User service starting on port %s", port)
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

func setupRouter(userHandler *handler.UserHandler) *gin.Engine {
	// Set Gin mode
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// Health check
	router.GET("/health", userHandler.HealthCheck)

	// Public routes
	api := router.Group("/api")
	{
		// Public team routes (no authentication required)
		teams := api.Group("/teams")
		{
			teams.GET("/search", userHandler.SearchTeams)
			teams.GET("/:id", userHandler.GetTeam)
		}

		// Public auth routes (no authentication required)
		auth := api.Group("/auth")
		{
			auth.POST("/register", userHandler.Register)
			auth.POST("/login", userHandler.Login)
			auth.POST("/refresh", userHandler.RefreshToken)
		}
	}

	// Protected routes (authentication required)
	protected := router.Group("/")
	protected.Use(userHandler.AuthMiddleware())
	{
		// User management routes
		users := protected.Group("/api/users")
		{
			users.GET("/me", userHandler.GetProfile)
			users.GET("/profile", userHandler.GetProfile)
			users.PUT("/profile", userHandler.UpdateProfile)
			users.POST("/logout", userHandler.Logout)
			users.PUT("/online-status", userHandler.SetOnlineStatus)
		}

		// Team routes (protected)
		teams := protected.Group("/api/teams")
		{
			teams.GET("/", userHandler.ListTeams)
			teams.POST("/", userHandler.CreateTeam)
			teams.POST("/join", userHandler.JoinTeam)
			teams.POST("/leave", userHandler.LeaveTeam)
			teams.GET("/:id/workers", userHandler.GetTeamWorkers)
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
