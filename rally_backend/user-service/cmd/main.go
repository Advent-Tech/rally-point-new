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

	// Initialize repositories
	userRepo := postgres.NewUserRepository(db.DB)
	teamRepo := postgres.NewTeamRepository(db.DB)
	sessionRepo := postgres.NewSessionRepository(db.DB)
	joinRequestRepo := postgres.NewJoinRequestRepository(db.DB)
	blogRepo := postgres.NewBlogRepository(db.DB)
	verificationTokenRepo := postgres.NewVerificationTokenRepository(db.DB)
	teamInvitationRepo := postgres.NewTeamInvitationRepository(db.DB)

	// Storage path for blog images
	storagePath := getEnv("STORAGE_PATH", "./uploads")
	baseURL := getEnv("BASE_URL", "http://localhost:8081")

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

	// Initialize services
	teamService := service.NewTeamService(teamRepo, db.DB, nc)
	userService := service.NewUserService(userRepo, sessionRepo, joinRequestRepo, jwtManager, db.DB)
	adminService := service.NewAdminService(userRepo, teamRepo, db.DB)
	superAdminService := service.NewSuperAdminService(userRepo, db.DB)
	joinRequestService := service.NewJoinRequestService(joinRequestRepo, userRepo, teamRepo, nc)
	blogService := service.NewBlogService(blogRepo, storagePath, baseURL)
	verificationService := service.NewVerificationService(userRepo, verificationTokenRepo, sessionRepo)
	teamInvitationService := service.NewTeamInvitationService(teamInvitationRepo, teamRepo, userRepo)

	// Initialize handlers
	userHandler := handler.NewUserHandler(userService, teamService, verificationService, jwtManager)
	adminHandler := handler.NewAdminHandler(adminService)
	superAdminHandler := handler.NewSuperAdminHandler(superAdminService)
	joinRequestHandler := handler.NewJoinRequestHandler(joinRequestService, teamService)
	blogHandler := handler.NewBlogHandler(blogService)
	verificationHandler := handler.NewVerificationHandler(verificationService)
	teamInvitationHandler := handler.NewTeamInvitationHandler(teamInvitationService)

	// Setup router
	router := setupRouter(userHandler, adminHandler, superAdminHandler, joinRequestHandler, blogHandler, verificationHandler, teamInvitationHandler, storagePath)

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

func setupRouter(
	userHandler *handler.UserHandler,
	adminHandler *handler.AdminHandler,
	superAdminHandler *handler.SuperAdminHandler,
	joinRequestHandler *handler.JoinRequestHandler,
	blogHandler *handler.BlogHandler,
	verificationHandler *handler.VerificationHandler,
	teamInvitationHandler *handler.TeamInvitationHandler,
	storagePath string,
) *gin.Engine {
	// Set Gin mode
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// Serve static files for uploads with CORS headers
	uploadsGroup := router.Group("/uploads")
	uploadsGroup.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})
	uploadsGroup.Static("/", storagePath)

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
			// Email verification and password reset routes
			auth.POST("/resend-verification", verificationHandler.ResendVerificationEmail)
			auth.POST("/verify-email", verificationHandler.VerifyEmail)
			auth.POST("/forgot-password", verificationHandler.ForgotPassword)
			auth.POST("/reset-password", verificationHandler.ResetPassword)
		}

		// Public blog routes (read-only, no authentication required)
		blogs := api.Group("/blogs")
		{
			blogs.GET("/", blogHandler.ListBlogs)
			blogs.GET("/:id", blogHandler.GetBlog)
		}

		// Public invitation routes (get invitation info)
		invitations := api.Group("/invitations")
		{
			invitations.GET("/info", teamInvitationHandler.GetInvitationInfo)
			invitations.POST("/decline", teamInvitationHandler.DeclineInvitation)
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

			// Join request routes (workers)
			teams.POST("/:id/request-join", joinRequestHandler.RequestJoinTeam)
			teams.GET("/my-request", joinRequestHandler.GetMyJoinRequest)
			teams.GET("/my-requests", joinRequestHandler.GetMyJoinRequests)
			teams.DELETE("/my-request", joinRequestHandler.CancelMyJoinRequest)

			// Join request routes (team leaders)
			teams.GET("/:id/join-requests", joinRequestHandler.GetTeamJoinRequests)
			teams.PUT("/join-requests/:id/approve", joinRequestHandler.ApproveJoinRequest)
			teams.PUT("/join-requests/:id/reject", joinRequestHandler.RejectJoinRequest)

			// Team invitation routes (team leaders)
			teams.POST("/:id/invitations", teamInvitationHandler.SendInvitation)
			teams.GET("/:id/invitations", teamInvitationHandler.GetTeamInvitations)
			teams.DELETE("/:id/invitations/:invitationId", teamInvitationHandler.CancelInvitation)
			teams.POST("/:id/invitations/:invitationId/resend", teamInvitationHandler.ResendInvitation)
		}

		// Protected invitation routes (accepting invitations)
		invitations := protected.Group("/api/invitations")
		{
			invitations.POST("/accept", teamInvitationHandler.AcceptInvitation)
		}

		// Blog routes (protected - create/update/delete requires admin)
		blogs := protected.Group("/api/blogs")
		{
			blogs.POST("/", blogHandler.CreateBlog)
			blogs.PUT("/:id", blogHandler.UpdateBlog)
			blogs.DELETE("/:id", blogHandler.DeleteBlog)
			blogs.POST("/:id/image", blogHandler.UploadImage)
			blogs.POST("/upload-image", blogHandler.UploadImageDirect)
		}

		// Admin routes (admin and superadmin only)
		admin := protected.Group("/api/admin")
		admin.Use(handler.AdminMiddleware())
		{
			// Team leader management
			admin.GET("/team-leaders", adminHandler.ListTeamLeaders)
			admin.GET("/team-leaders/:id", adminHandler.GetTeamLeader)
			admin.PUT("/team-leaders/:id/verify", adminHandler.VerifyTeamLeader)
			admin.PUT("/team-leaders/:id/reject", adminHandler.RejectTeamLeader)

			// Team management by admin
			admin.POST("/teams", adminHandler.CreateTeam)
			admin.PUT("/teams/:id/assign-leader", adminHandler.AssignTeamToLeader)
			admin.DELETE("/teams/:id/leader", adminHandler.UnassignTeamFromLeader)

			// Worker management
			admin.GET("/workers/pending", adminHandler.ListPendingWorkers)
			admin.GET("/workers/verified", adminHandler.ListVerifiedWorkers)
			admin.PUT("/workers/:id/verify", adminHandler.VerifyWorker)
			admin.PUT("/workers/:id/reject", adminHandler.RejectWorker)
		}

		// Superadmin routes (superadmin only)
		superadmin := protected.Group("/api/superadmin")
		superadmin.Use(handler.SuperAdminMiddleware())
		{
			superadmin.POST("/admins", superAdminHandler.CreateAdmin)
			superadmin.GET("/admins", superAdminHandler.ListAdmins)
			superadmin.GET("/admins/:id", superAdminHandler.GetAdmin)
			superadmin.DELETE("/admins/:id", superAdminHandler.DeleteAdmin)
			superadmin.PUT("/admins/:id/reset-password", superAdminHandler.ResetAdminPassword)
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
