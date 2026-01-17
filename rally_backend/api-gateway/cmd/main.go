package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"rally-point/api-gateway/internal/config"
	"rally-point/api-gateway/internal/middleware"
	"rally-point/api-gateway/internal/proxy"
	"rally-point/api-gateway/internal/websocket"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/nats-io/nats.go"
	"github.com/rally-point/shared/auth"
	"github.com/redis/go-redis/v9"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Load configuration
	cfg := config.Load()

	// Initialize JWT manager
	jwtManager := auth.NewJWTManager(
		cfg.JWT.Secret,
		cfg.JWT.AccessTokenDuration,
		cfg.JWT.RefreshTokenDuration,
	)

	// Initialize Redis client
	redisClient := redis.NewClient(&redis.Options{
		Addr:     cfg.Redis.Host + ":" + cfg.Redis.Port,
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	})

	// Test Redis connection
	ctx := context.Background()
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Printf("Warning: Redis connection failed: %v", err)
		redisClient = nil // Use in-memory rate limiting
	}

	// Initialize rate limiter
	var rateLimiter middleware.RateLimiter
	if redisClient != nil {
		rateLimiter = middleware.NewRedisRateLimiter(redisClient, cfg.RateLimit.RequestsPerMinute)
	} else {
		rateLimiter = middleware.NewInMemoryRateLimiter(cfg.RateLimit.RequestsPerMinute, cfg.RateLimit.BurstSize)
	}

	// Initialize service proxy
	serviceProxy := proxy.NewServiceProxy(map[string]string{
		"user":      cfg.Services.UserService,
		"location":  cfg.Services.LocationService,
		"walkie":    cfg.Services.WalkieService,
		"territory": cfg.Services.TerritoryService,
		"survey":    cfg.Services.SurveyService,
		"delivery":  cfg.Services.DeliveryService,
		"ministry":  cfg.Services.MinistryService,
	})

	// Initialize WebSocket hub
	wsHub := websocket.NewHub()
	go wsHub.Run()

	// Initialize NATS subscription for ministry contact events (optional)
	natsURL := os.Getenv("NATS_URL")
	if natsURL == "" {
		natsURL = "nats://localhost:4222"
	}
	nc, err := nats.Connect(natsURL)
	if err != nil {
		log.Printf("Warning: failed to connect to NATS at %s: %v", natsURL, err)
	} else {
		// Subscribe to ministry contacts events
		_, subErr := nc.Subscribe("ministry.contacts.worker.*", func(msg *nats.Msg) {
			var event map[string]interface{}
			if err := json.Unmarshal(msg.Data, &event); err != nil {
				log.Printf("Error parsing ministry contact NATS event: %v", err)
				return
			}

			wsMessage := websocket.Message{
				Type:      "ministry-contact-event",
				Data:      event,
				Timestamp: time.Now().UnixMilli(),
				Channel:   msg.Subject,
			}

			wsHub.BroadcastToAll(wsMessage)
		})
		if subErr != nil {
			log.Printf("Warning: failed to subscribe to ministry contacts NATS subject: %v", subErr)
		}
		defer nc.Drain()
	}

	// Setup router
	router := setupRouter(cfg, jwtManager, rateLimiter, serviceProxy, wsHub)

	// Server configuration
	server := &http.Server{
		Addr:         ":" + cfg.Server.Port,
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
		IdleTimeout:  cfg.Server.IdleTimeout,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🚀 API Gateway starting on port %s", cfg.Server.Port)
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

	// Close Redis connection
	if redisClient != nil {
		redisClient.Close()
	}

	log.Println("✅ Server exited")
}

func setupRouter(cfg *config.Config, jwtManager *auth.JWTManager, rateLimiter middleware.RateLimiter, serviceProxy *proxy.ServiceProxy, wsHub *websocket.Hub) *gin.Engine {
	// Set Gin mode
	if gin.Mode() != gin.DebugMode {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Disable trailing slash redirect (causes CORS issues with 307 redirects)
	router.RedirectTrailingSlash = false

	// Global middleware
	router.Use(middleware.CORSMiddleware())
	router.Use(middleware.RequestResponseLogger())
	router.Use(gin.Recovery())

	// Health check endpoints
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"service":   "api-gateway",
			"timestamp": time.Now().Format(time.RFC3339),
		})
	})

	router.GET("/health/services", serviceProxy.HealthCheckProxy())

	// WebSocket endpoint (generic hub)
	router.GET("/ws", middleware.OptionalAuthMiddleware(jwtManager), wsHub.HandleWebSocket())

	// WebSocket proxy to walkie-talkie service
	router.GET("/ws/walkie", middleware.OptionalAuthMiddleware(jwtManager), serviceProxy.ProxyWebSocket("walkie", "/ws/walkie"))

	// API routes
	api := router.Group("/api")
	api.Use(middleware.RateLimitMiddleware(rateLimiter))

	// Public routes (no authentication required)
	public := api.Group("/")
	{
		// User service - auth endpoints
		public.POST("/auth/register", serviceProxy.ProxyRequest("user"))
		public.POST("/auth/login", serviceProxy.ProxyRequest("user"))
		public.POST("/auth/refresh", serviceProxy.ProxyRequest("user"))
		public.POST("/auth/forgot-password", serviceProxy.ProxyRequest("user"))
		public.POST("/auth/reset-password", serviceProxy.ProxyRequest("user"))
		public.POST("/auth/verify-email", serviceProxy.ProxyRequest("user"))
		public.POST("/auth/resend-verification", serviceProxy.ProxyRequest("user"))

		// Public team routes (for workers to find teams during signup)
		public.GET("/teams/search", serviceProxy.ProxyRequest("user"))
		public.GET("/teams/:id", serviceProxy.ProxyRequest("user"))

		// Public blog routes (read-only)
		public.GET("/blogs", serviceProxy.ProxyRequest("user"))
		public.GET("/blogs/:id", serviceProxy.ProxyRequest("user"))
	}

	// Protected routes (authentication required)
	protected := api.Group("/")
	protected.Use(middleware.AuthMiddleware(jwtManager))
	protected.Use(middleware.ServiceAuthMiddleware())
	{
		// User service routes
		users := protected.Group("/users")
		{
			users.GET("/me", serviceProxy.ProxyRequest("user"))
			users.GET("/profile", serviceProxy.ProxyRequest("user"))
			users.PUT("/profile", serviceProxy.ProxyRequest("user"))
			users.POST("/upload-avatar", serviceProxy.ProxyRequest("user"))
			users.DELETE("/avatar", serviceProxy.ProxyRequest("user"))
			users.POST("/change-password", serviceProxy.ProxyRequest("user"))
			users.DELETE("/account", serviceProxy.ProxyRequest("user"))
			// Survey-related user endpoints (routed to survey-service)
			users.GET("/surveys", serviceProxy.ProxyRequest("survey"))
			users.GET("/responses", serviceProxy.ProxyRequest("survey"))
			users.GET("/assignments", serviceProxy.ProxyRequest("survey"))
		}

		// Team management routes (protected)
		teams := protected.Group("/teams")
		{
			teams.GET("/", serviceProxy.ProxyRequest("user"))        // List teams (supports leader_id query param)
			teams.POST("/", serviceProxy.ProxyRequest("user"))
			teams.PUT("/:id", serviceProxy.ProxyRequest("user"))
			teams.DELETE("/:id", serviceProxy.ProxyRequest("user"))
			teams.POST("/join", serviceProxy.ProxyRequest("user"))  // Add missing join route
			teams.POST("/leave", serviceProxy.ProxyRequest("user")) // Add missing leave route
			teams.POST("/:id/invite", serviceProxy.ProxyRequest("user"))
			teams.POST("/:id/join", serviceProxy.ProxyRequest("user"))
			teams.DELETE("/:id/leave", serviceProxy.ProxyRequest("user"))
			teams.GET("/:id/members", serviceProxy.ProxyRequest("user"))
			teams.GET("/:id/workers", serviceProxy.ProxyRequest("user"))
			teams.PUT("/:id/members/:userId/role", serviceProxy.ProxyRequest("user"))
			teams.DELETE("/:id/members/:userId", serviceProxy.ProxyRequest("user"))
			// Team survey routes (routed to survey-service)
			teams.GET("/:id/surveys", serviceProxy.ProxyRequest("survey"))
			teams.GET("/:id/survey-stats", serviceProxy.ProxyRequest("survey"))
		}

		// Location service routes
		locations := protected.Group("/locations")
		{
			locations.POST("/", serviceProxy.ProxyRequest("location"))
			locations.GET("/user/:userId", serviceProxy.ProxyRequest("location"))
			locations.GET("/team/:teamId", serviceProxy.ProxyRequest("location"))
			locations.GET("/team/:teamId/history", serviceProxy.ProxyRequest("location"))
			locations.DELETE("/:id", serviceProxy.ProxyRequest("location"))
			locations.GET("/workers/active", serviceProxy.ProxyRequest("location"))
			locations.PUT("/workers/offline", serviceProxy.ProxyRequest("location"))
		}

		// Singular location routes to match location-service API
		location := protected.Group("/location")
		{
			location.POST("/update", serviceProxy.ProxyRequest("location"))
			location.GET("/history", serviceProxy.ProxyRequest("location"))
			location.GET("/stats", serviceProxy.ProxyRequest("location"))
		}

		// Walkie-talkie service routes
		walkie := protected.Group("/walkie")
		{
			// Transmission management
			walkie.POST("/start", serviceProxy.ProxyRequest("walkie"))
			walkie.POST("/end", serviceProxy.ProxyRequest("walkie"))
			walkie.GET("/teams/:teamId/session", serviceProxy.ProxyRequest("walkie"))
			walkie.GET("/teams/:teamId/state", serviceProxy.ProxyRequest("walkie"))
			// Messages - proxied to /api/messages on walkie-service
			walkie.POST("/messages", serviceProxy.ProxyRequestWithPath("walkie", "/api/messages/"))
			walkie.GET("/messages/team/:teamId", serviceProxy.ProxyRequestWithPath("walkie", "/api/messages/teams/:teamId"))
		}

		// Chat service routes (member-to-member, member-to-team messaging)
		chat := protected.Group("/chat")
		{
			// Conversations
			chat.POST("/conversations", serviceProxy.ProxyRequest("walkie"))
			chat.GET("/conversations", serviceProxy.ProxyRequest("walkie"))
			chat.POST("/conversations/direct", serviceProxy.ProxyRequest("walkie"))
			chat.GET("/conversations/team/:teamId", serviceProxy.ProxyRequest("walkie"))
			chat.GET("/conversations/:conversationId", serviceProxy.ProxyRequest("walkie"))
			chat.GET("/conversations/:conversationId/participants", serviceProxy.ProxyRequest("walkie"))
			chat.GET("/conversations/:conversationId/messages", serviceProxy.ProxyRequest("walkie"))
			chat.POST("/conversations/:conversationId/typing", serviceProxy.ProxyRequest("walkie"))

			// Messages
			chat.POST("/messages", serviceProxy.ProxyRequest("walkie"))
			chat.PUT("/messages/:messageId", serviceProxy.ProxyRequest("walkie"))
			chat.DELETE("/messages/:messageId", serviceProxy.ProxyRequest("walkie"))
			chat.POST("/messages/read", serviceProxy.ProxyRequest("walkie"))
		}

		// Territory service routes
		territories := protected.Group("/territories")
		{
			territories.POST("/", serviceProxy.ProxyRequest("territory"))
			territories.GET("/:id", serviceProxy.ProxyRequest("territory"))
			territories.PUT("/:id", serviceProxy.ProxyRequest("territory"))
			territories.DELETE("/:id", serviceProxy.ProxyRequest("territory"))
			territories.GET("/team/:teamId", serviceProxy.ProxyRequest("territory"))
			territories.GET("/worker/:workerId", serviceProxy.ProxyRequest("territory"))
			territories.PUT("/:id/assign", serviceProxy.ProxyRequest("territory"))
			territories.PUT("/:id/status", serviceProxy.ProxyRequest("territory"))
			territories.GET("/:id/visits", serviceProxy.ProxyRequest("territory"))
			territories.POST("/:id/visits", serviceProxy.ProxyRequest("territory"))
		}

		workers := protected.Group("/workers")
		{
			workers.GET("/:workerId/territories", serviceProxy.ProxyRequest("territory"))
			workers.GET("/active", serviceProxy.ProxyRequest("location"))
			workers.PUT("/offline", serviceProxy.ProxyRequest("location"))
			// Worker location and path endpoints (for team leaders/admins)
			workers.GET("/:workerId/path-history", serviceProxy.ProxyRequest("location"))
			workers.GET("/:workerId/location-stats", serviceProxy.ProxyRequest("location"))
			workers.GET("/:workerId/sessions", serviceProxy.ProxyRequest("location"))
			// Worker survey stats (for team leaders/admins)
			workers.GET("/:workerId/survey-stats", serviceProxy.ProxyRequest("survey"))
		}

		// Geo territory routes (imported GeoPackage territories)
		geo := protected.Group("/geo")
		{
			// Territory queries
			geo.GET("/territories", serviceProxy.ProxyRequest("territory"))
			geo.GET("/territories/search", serviceProxy.ProxyRequest("territory"))
			geo.GET("/territories/list", serviceProxy.ProxyRequest("territory"))
			geo.GET("/territories/at", serviceProxy.ProxyRequest("territory"))
			geo.GET("/territories/:id", serviceProxy.ProxyRequest("territory"))
			geo.GET("/territories/solid/:solid", serviceProxy.ProxyRequest("territory"))
			geo.GET("/territories/entity/:entityId", serviceProxy.ProxyRequest("territory"))

			// Church locations
			geo.GET("/churches", serviceProxy.ProxyRequest("territory"))
			geo.GET("/churches/:entityId", serviceProxy.ProxyRequest("territory"))

			// Statistics
			geo.GET("/stats/unions", serviceProxy.ProxyRequest("territory"))
			geo.GET("/stats/conferences", serviceProxy.ProxyRequest("territory"))

			// Vector tiles
			geo.GET("/tiles/:z/:x/:y", serviceProxy.ProxyRequest("territory"))

			// Territory assignments
			geo.POST("/assignments", serviceProxy.ProxyRequest("territory"))
			geo.GET("/assignments", serviceProxy.ProxyRequest("territory"))
			geo.GET("/assignments/:id", serviceProxy.ProxyRequest("territory"))
			geo.PUT("/assignments/:id", serviceProxy.ProxyRequest("territory"))
			geo.DELETE("/assignments/:id", serviceProxy.ProxyRequest("territory"))
			geo.POST("/assignments/:id/visit", serviceProxy.ProxyRequest("territory"))
			geo.GET("/assignments/worker/:id/geojson", serviceProxy.ProxyRequest("territory"))
			geo.GET("/assignments/team/:id/geojson", serviceProxy.ProxyRequest("territory"))
		}

		// Geofence routes (territory work session tracking)
		geofence := protected.Group("/geofence")
		{
			geofence.POST("/check", serviceProxy.ProxyRequest("territory"))
			geofence.POST("/checkin", serviceProxy.ProxyRequest("territory"))
			geofence.POST("/checkout", serviceProxy.ProxyRequest("territory"))
			geofence.POST("/location-update", serviceProxy.ProxyRequest("territory"))
			geofence.GET("/worker/:workerId/current", serviceProxy.ProxyRequest("territory"))
			geofence.GET("/worker/:workerId/sessions", serviceProxy.ProxyRequest("territory"))
			geofence.GET("/worker/:workerId/session", serviceProxy.ProxyRequest("territory"))
			geofence.GET("/teams/:teamId/workers/active", serviceProxy.ProxyRequest("territory"))
			geofence.GET("/workers/active", serviceProxy.ProxyRequest("territory"))
			geofence.GET("/sessions/:sessionId/visits", serviceProxy.ProxyRequest("territory"))
			geofence.POST("/sessions/:sessionId/visits", serviceProxy.ProxyRequest("territory"))
		}

		// Work sessions routes (for worker activity tracking)
		workSessions := protected.Group("/work-sessions")
		{
			workSessions.GET("/worker/:workerId", serviceProxy.ProxyRequest("territory"))
		}

		// Visits routes (for worker activity tracking)
		visitsRoutes := protected.Group("/visits")
		{
			visitsRoutes.GET("/worker/:workerId", serviceProxy.ProxyRequest("territory"))
		}

		// Survey service routes - explicit routes for both with and without trailing slash
		protected.GET("/surveys", serviceProxy.ProxyRequest("survey"))
		protected.POST("/surveys", serviceProxy.ProxyRequest("survey"))
		protected.GET("/surveys/", serviceProxy.ProxyRequest("survey"))
		protected.POST("/surveys/", serviceProxy.ProxyRequest("survey"))
		surveys := protected.Group("/surveys")
		{
			surveys.GET("/:id", serviceProxy.ProxyRequest("survey"))
			surveys.PUT("/:id", serviceProxy.ProxyRequest("survey"))
			surveys.DELETE("/:id", serviceProxy.ProxyRequest("survey"))
			surveys.GET("/team/:teamId", serviceProxy.ProxyRequest("survey"))
			surveys.GET("/worker/:workerId", serviceProxy.ProxyRequest("survey"))
			surveys.PUT("/:id/assign", serviceProxy.ProxyRequest("survey"))
			surveys.POST("/:id/assignments", serviceProxy.ProxyRequest("survey"))
			surveys.POST("/:id/responses", serviceProxy.ProxyRequest("survey"))
			surveys.GET("/:id/responses", serviceProxy.ProxyRequest("survey"))
			surveys.GET("/:id/analytics", serviceProxy.ProxyRequest("survey"))
		}

		// Schedule routes for workers (accessible by all authenticated users)
		workerSchedules := protected.Group("/schedules")
		{
			workerSchedules.GET("/worker/me", serviceProxy.ProxyRequest("territory"))
			workerSchedules.GET("/worker/:workerId", serviceProxy.ProxyRequest("territory"))
			workerSchedules.POST("/:id/start", serviceProxy.ProxyRequest("territory"))
			workerSchedules.POST("/:id/complete", serviceProxy.ProxyRequest("territory"))
		}

		// Schedule management routes (territory-service) - team leaders only
		schedules := protected.Group("/schedules")
		schedules.Use(middleware.RoleMiddleware("team_leader"))
		{
			schedules.GET("/team/:teamId", serviceProxy.ProxyRequest("territory"))
			schedules.POST("/", serviceProxy.ProxyRequest("territory"))
			schedules.PUT("/:id", serviceProxy.ProxyRequest("territory"))
			schedules.DELETE("/:id", serviceProxy.ProxyRequest("territory"))
			schedules.POST("/:id/cancel", serviceProxy.ProxyRequest("territory"))
		}

		// Ministry contacts service routes
		ministryContacts := protected.Group("/ministry-contacts")
		{
			ministryContacts.GET("/", serviceProxy.ProxyRequest("ministry"))
			ministryContacts.POST("/", serviceProxy.ProxyRequest("ministry"))
			ministryContacts.GET("/:id", serviceProxy.ProxyRequest("ministry"))
			ministryContacts.PUT("/:id", serviceProxy.ProxyRequest("ministry"))
			ministryContacts.DELETE("/:id", serviceProxy.ProxyRequest("ministry"))
			ministryContacts.GET("/stats", serviceProxy.ProxyRequest("ministry"))
			ministryContacts.GET("/export", serviceProxy.ProxyRequest("ministry"))
		}

		// Delivery service routes
		deliveries := protected.Group("/deliveries")
		{
			deliveries.POST("/", serviceProxy.ProxyRequest("delivery"))
			deliveries.GET("/:id", serviceProxy.ProxyRequest("delivery"))
			deliveries.PUT("/:id", serviceProxy.ProxyRequest("delivery"))
			deliveries.DELETE("/:id", serviceProxy.ProxyRequest("delivery"))
			deliveries.PUT("/:id/status", serviceProxy.ProxyRequest("delivery"))
			deliveries.PUT("/:id/assign", serviceProxy.ProxyRequest("delivery"))
			deliveries.PUT("/:id/start", serviceProxy.ProxyRequest("delivery"))
			deliveries.PUT("/:id/complete", serviceProxy.ProxyRequest("delivery"))
		}

		// Team-specific routes with team middleware
		teamRoutes := protected.Group("/")
		teamRoutes.Use(middleware.TeamMiddleware())
		{
			// Team deliveries and routes
			teamRoutes.GET("/teams/:id/deliveries", serviceProxy.ProxyRequest("delivery"))
			teamRoutes.GET("/teams/:id/routes", serviceProxy.ProxyRequest("delivery"))
			teamRoutes.GET("/teams/:id/stats", serviceProxy.ProxyRequest("delivery"))
			teamRoutes.GET("/teams/:id/worker-stats", serviceProxy.ProxyRequest("delivery"))

			// Worker-specific routes
			teamRoutes.GET("/workers/:workerId/deliveries", serviceProxy.ProxyRequest("delivery"))
			teamRoutes.GET("/workers/:workerId/routes", serviceProxy.ProxyRequest("delivery"))
			teamRoutes.GET("/workers/:workerId/stats", serviceProxy.ProxyRequest("delivery"))
		}

		// Route management
		routes := protected.Group("/routes")
		{
			routes.POST("/", serviceProxy.ProxyRequest("delivery"))
			routes.GET("/:id", serviceProxy.ProxyRequest("delivery"))
			routes.PUT("/:id/start", serviceProxy.ProxyRequest("delivery"))
			routes.PUT("/:id/complete", serviceProxy.ProxyRequest("delivery"))
			routes.PUT("/:id/optimize", serviceProxy.ProxyRequest("delivery"))
		}

		// Receipts routes
		receipts := protected.Group("/receipts")
		{
			receipts.POST("/", serviceProxy.ProxyRequest("delivery"))
			receipts.GET("/:id", serviceProxy.ProxyRequest("delivery"))
			receipts.GET("/number/:receiptNumber", serviceProxy.ProxyRequest("delivery"))
			receipts.PUT("/:id/cancel", serviceProxy.ProxyRequest("delivery"))
			receipts.PUT("/:id/refund", serviceProxy.ProxyRequest("delivery"))
			receipts.GET("/worker/:workerId", serviceProxy.ProxyRequest("delivery"))
			receipts.GET("/team/:teamId", serviceProxy.ProxyRequest("delivery"))
			receipts.GET("/session/:sessionId", serviceProxy.ProxyRequest("delivery"))
			receipts.GET("/stats/team/:teamId", serviceProxy.ProxyRequest("delivery"))
			receipts.GET("/stats/worker/:workerId", serviceProxy.ProxyRequest("delivery"))
		}

		// Donations routes
		donations := protected.Group("/donations")
		{
			donations.POST("/", serviceProxy.ProxyRequest("delivery"))
			donations.GET("/:id", serviceProxy.ProxyRequest("delivery"))
			donations.PUT("/:id/deposit", serviceProxy.ProxyRequest("delivery"))
			donations.PUT("/:id/cancel", serviceProxy.ProxyRequest("delivery"))
			donations.GET("/worker/:workerId", serviceProxy.ProxyRequest("delivery"))
			donations.GET("/team/:teamId", serviceProxy.ProxyRequest("delivery"))
			donations.GET("/session/:sessionId", serviceProxy.ProxyRequest("delivery"))
			donations.GET("/stats/team/:teamId", serviceProxy.ProxyRequest("delivery"))
			donations.GET("/stats/worker/:workerId", serviceProxy.ProxyRequest("delivery"))
		}

		// Prayer request routes
		prayerRequests := protected.Group("/prayer-requests")
		{
			prayerRequests.POST("/", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.GET("/", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.GET("/me", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.GET("/map", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.GET("/stats", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.GET("/:id", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.PUT("/:id", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.DELETE("/:id", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.PUT("/:id/status", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.PUT("/:id/assign-preacher", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.PUT("/:id/complete", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.GET("/worker/:workerId", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.GET("/team/:teamId", serviceProxy.ProxyRequest("delivery"))
			prayerRequests.GET("/territory/:territoryId", serviceProxy.ProxyRequest("delivery"))
		}

		// Payment routes (Stripe integration)
		payments := protected.Group("/payments")
		{
			payments.POST("/create-intent", serviceProxy.ProxyRequest("delivery"))
			payments.GET("/verify/:id", serviceProxy.ProxyRequest("delivery"))
			payments.POST("/send-link", serviceProxy.ProxyRequest("delivery"))
			payments.GET("/status/:sessionId", serviceProxy.ProxyRequest("delivery"))
		}

		// Blog routes (create/update/delete requires admin - enforced in user-service)
		blogs := protected.Group("/blogs")
		{
			blogs.POST("/", serviceProxy.ProxyRequest("user"))
			blogs.PUT("/:id", serviceProxy.ProxyRequest("user"))
			blogs.DELETE("/:id", serviceProxy.ProxyRequest("user"))
			blogs.POST("/:id/image", serviceProxy.ProxyRequest("user"))
			blogs.POST("/upload-image", serviceProxy.ProxyRequest("user"))
		}
	}

	// =====================================================
	// SUPERADMIN ROUTES (superadmin only)
	// =====================================================
	superadmin := api.Group("/superadmin")
	superadmin.Use(middleware.AuthMiddleware(jwtManager))
	superadmin.Use(middleware.SuperAdminMiddleware())
	superadmin.Use(middleware.ServiceAuthMiddleware())
	{
		// Admin account management
		superadmin.POST("/admins", serviceProxy.ProxyRequest("user"))
		superadmin.GET("/admins", serviceProxy.ProxyRequest("user"))
		superadmin.GET("/admins/:id", serviceProxy.ProxyRequest("user"))
		superadmin.DELETE("/admins/:id", serviceProxy.ProxyRequest("user"))
		superadmin.PUT("/admins/:id/reset-password", serviceProxy.ProxyRequest("user"))
	}

	// =====================================================
	// ADMIN ROUTES (admin and superadmin)
	// =====================================================
	admin := api.Group("/admin")
	admin.Use(middleware.AuthMiddleware(jwtManager))
	admin.Use(middleware.AdminMiddleware())
	admin.Use(middleware.ServiceAuthMiddleware())
	{
		admin.GET("/stats", func(c *gin.Context) {
			stats := wsHub.GetStats()
			c.JSON(http.StatusOK, gin.H{
				"websocket": stats,
				"timestamp": time.Now().Format(time.RFC3339),
			})
		})

		// Team leader verification and management
		admin.GET("/team-leaders", serviceProxy.ProxyRequest("user"))
		admin.GET("/team-leaders/:id", serviceProxy.ProxyRequest("user"))
		admin.PUT("/team-leaders/:id/verify", serviceProxy.ProxyRequest("user"))
		admin.PUT("/team-leaders/:id/reject", serviceProxy.ProxyRequest("user"))

		// Admin team management
		admin.POST("/teams", serviceProxy.ProxyRequest("user"))
		admin.PUT("/teams/:id/assign-leader", serviceProxy.ProxyRequest("user"))
		admin.DELETE("/teams/:id/leader", serviceProxy.ProxyRequest("user"))

		// Worker verification
		admin.GET("/workers/pending", serviceProxy.ProxyRequest("user"))
		admin.GET("/workers/verified", serviceProxy.ProxyRequest("user"))
		admin.PUT("/workers/:id/verify", serviceProxy.ProxyRequest("user"))
		admin.PUT("/workers/:id/reject", serviceProxy.ProxyRequest("user"))

		// Territory allocations (admin → team leader)
		admin.POST("/territories/allocate", serviceProxy.ProxyRequest("territory"))
		admin.POST("/territories/allocate-bulk", serviceProxy.ProxyRequest("territory"))
		admin.GET("/territories/allocations", serviceProxy.ProxyRequest("territory"))
		admin.GET("/territories/allocations/:id", serviceProxy.ProxyRequest("territory"))
		admin.DELETE("/territories/allocations/:id", serviceProxy.ProxyRequest("territory"))
		admin.GET("/territories/allocations/leader/:leaderId", serviceProxy.ProxyRequest("territory"))

		// Proxy admin routes to all services
		// Note: territories routes handled explicitly above to avoid catch-all conflict
		admin.Any("/users/*path", serviceProxy.ProxyRequest("user"))
		admin.Any("/locations/*path", serviceProxy.ProxyRequest("location"))
		admin.Any("/walkie/*path", serviceProxy.ProxyRequest("walkie"))
		admin.Any("/surveys/*path", serviceProxy.ProxyRequest("survey"))
		admin.Any("/deliveries/*path", serviceProxy.ProxyRequest("delivery"))
		admin.Any("/ministry-contacts/*path", serviceProxy.ProxyRequest("ministry"))
	}

	// =====================================================
	// TEAM LEADER ROUTES (for managing join requests)
	// =====================================================
	// Note: These are added to the teams routes under protected
	// Team leader can view and approve/reject join requests for their team
	teamLeaderRoutes := api.Group("/teams")
	teamLeaderRoutes.Use(middleware.AuthMiddleware(jwtManager))
	teamLeaderRoutes.Use(middleware.TeamLeaderMiddleware())
	teamLeaderRoutes.Use(middleware.ServiceAuthMiddleware())
	{
		// Join request management
		teamLeaderRoutes.GET("/:id/join-requests", serviceProxy.ProxyRequest("user"))
		teamLeaderRoutes.PUT("/join-requests/:id/approve", serviceProxy.ProxyRequest("user"))
		teamLeaderRoutes.PUT("/join-requests/:id/reject", serviceProxy.ProxyRequest("user"))
	}

	// =====================================================
	// WORKER ROUTES (for join requests)
	// =====================================================
	// Workers can request to join teams and view their request status
	workerTeamRoutes := api.Group("/teams")
	workerTeamRoutes.Use(middleware.AuthMiddleware(jwtManager))
	workerTeamRoutes.Use(middleware.ServiceAuthMiddleware())
	{
		// Join request endpoints for workers
		workerTeamRoutes.POST("/:id/request-join", serviceProxy.ProxyRequest("user"))
		workerTeamRoutes.GET("/my-request", serviceProxy.ProxyRequest("user"))
		workerTeamRoutes.GET("/my-requests", serviceProxy.ProxyRequest("user"))
		workerTeamRoutes.DELETE("/my-request", serviceProxy.ProxyRequest("user"))
	}

	// =====================================================
	// TERRITORY ALLOCATION ROUTES (for team leaders)
	// =====================================================
	// Leaders can view their allocated territories
	leaderTerritoryRoutes := api.Group("/territories")
	leaderTerritoryRoutes.Use(middleware.AuthMiddleware(jwtManager))
	leaderTerritoryRoutes.Use(middleware.TeamLeaderMiddleware())
	leaderTerritoryRoutes.Use(middleware.ServiceAuthMiddleware())
	{
		leaderTerritoryRoutes.GET("/my-allocations", serviceProxy.ProxyRequest("territory"))
		leaderTerritoryRoutes.GET("/my-allocations/geojson", serviceProxy.ProxyRequest("territory"))
		leaderTerritoryRoutes.GET("/my-allocations/stats", serviceProxy.ProxyRequest("territory"))
		leaderTerritoryRoutes.GET("/can-assign/:territoryId", serviceProxy.ProxyRequest("territory"))
	}

	return router
}
