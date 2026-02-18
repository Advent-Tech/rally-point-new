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
	"rally-point/walkie-service/internal/handler"
	"rally-point/walkie-service/internal/realtime"
	"rally-point/walkie-service/internal/repository/postgres"
	"rally-point/walkie-service/internal/service"
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
	walkieRepo := postgres.NewWalkieRepository(db.DB)
	realtimeManager := realtime.NewRealtimeManager()
	audioStoragePath := getEnv("AUDIO_STORAGE_PATH", "/app/audio")
	audioManager := service.NewAudioManager(audioStoragePath)
	walkieService := service.NewWalkieService(walkieRepo, realtimeManager, audioManager, nc)

	// Initialize chat components
	chatRepo := postgres.NewChatRepository(db.DB)
	chatService := service.NewChatService(chatRepo, nc)

	// Initialize handlers
	walkieHandler := handler.NewWalkieHandler(walkieService, jwtManager)
	chatHandler := handler.NewChatHandler(chatService)

	// Setup router
	router := setupRouter(walkieHandler, chatHandler)

	// Server configuration
	port := getEnv("PORT", "8086")
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🚀 Walkie-talkie service starting on port %s", port)
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

func setupRouter(walkieHandler *handler.WalkieHandler, chatHandler *handler.ChatHandler) *gin.Engine {
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
	router.GET("/health", walkieHandler.HealthCheck)

	// WebSocket endpoints for real-time communication
	router.GET("/ws/walkie", walkieHandler.WebSocketHandler)
	router.GET("/ws/chat", chatHandler.ChatWebSocketHandler)

	// Static file serving for audio files
	router.Static("/audio", getEnv("AUDIO_STORAGE_PATH", "/app/audio"))

	// API routes
	api := router.Group("/api")

	// Protected routes
	protected := api.Group("/")
	protected.Use(walkieHandler.AuthMiddleware())
	{
		// Transmission management
		walkie := protected.Group("/walkie")
		{
			walkie.POST("/start", walkieHandler.StartTransmission)
			walkie.POST("/end", walkieHandler.EndTransmission)
			walkie.GET("/teams/:teamId/session", walkieHandler.GetActiveSession)
			walkie.GET("/teams/:teamId/state", walkieHandler.GetTeamState)
		}

		// Message management (walkie)
		messages := protected.Group("/messages")
		{
			messages.POST("/", walkieHandler.SendMessage)
			messages.GET("/teams/:teamId", walkieHandler.GetTeamMessages)
		}

		// Team management
		teams := protected.Group("/teams")
		{
			teams.GET("/:teamId/members", walkieHandler.GetTeamMembers)
		}

		// Audio management
		audio := protected.Group("/audio")
		{
			audio.POST("/upload", walkieHandler.UploadAudio)
			audio.GET("/sessions/:sessionId", walkieHandler.GetAudioURL)
		}

		// Chat routes
		chat := protected.Group("/chat")
		{
			// Conversations
			chat.POST("/conversations", chatHandler.CreateConversation)
			chat.GET("/conversations", chatHandler.GetUserConversations)
			chat.POST("/conversations/direct", chatHandler.GetOrCreateDirect)
			chat.GET("/conversations/team/:teamId", chatHandler.GetTeamConversation)
			chat.GET("/conversations/:conversationId", chatHandler.GetConversation)
			chat.GET("/conversations/:conversationId/participants", chatHandler.GetParticipants)
			chat.GET("/conversations/:conversationId/messages", chatHandler.GetMessages)
			chat.POST("/conversations/:conversationId/typing", chatHandler.SendTypingIndicator)

			// Messages
			chat.POST("/messages", chatHandler.SendMessage)
			chat.PUT("/messages/:messageId", chatHandler.EditMessage)
			chat.DELETE("/messages/:messageId", chatHandler.DeleteMessage)
			chat.POST("/messages/read", chatHandler.MarkAsRead)
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
