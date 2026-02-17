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
	"github.com/rally-point/shared/auth"
	"github.com/rally-point/shared/database"
	"rally-point/delivery-service/internal/client"
	"rally-point/delivery-service/internal/handler"
	"rally-point/delivery-service/internal/repository/postgres"
	"rally-point/delivery-service/internal/service"
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

	// Initialize territory client for cross-service communication
	territoryServiceURL := getEnv("TERRITORY_SERVICE_URL", "http://localhost:8082")
	var territoryClient = client.NewTerritoryClient(territoryServiceURL)

	// Initialize components
	deliveryRepo := postgres.NewDeliveryRepository(db.DB)
	routeOptimizer := service.NewRouteOptimizer()
	deliveryService := service.NewDeliveryService(deliveryRepo, routeOptimizer, territoryClient)

	// Initialize receipt components
	receiptRepo := postgres.NewReceiptRepository(db.DB)
	receiptService := service.NewReceiptService(receiptRepo)

	// Initialize prayer request components
	prayerRepo := postgres.NewPrayerRequestRepository(db.DB)
	prayerService := service.NewPrayerRequestService(prayerRepo)

	// Initialize handlers
	deliveryHandler := handler.NewDeliveryHandler(deliveryService, jwtManager)
	receiptHandler := handler.NewReceiptHandler(receiptService)
	paymentHandler := handler.NewPaymentHandler()
	prayerHandler := handler.NewPrayerRequestHandler(prayerService)

	// Setup router
	router := setupRouter(deliveryHandler, receiptHandler, paymentHandler, prayerHandler)

	// Server configuration
	port := getEnv("PORT", "8085")
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🚀 Delivery service starting on port %s", port)
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

func setupRouter(deliveryHandler *handler.DeliveryHandler, receiptHandler *handler.ReceiptHandler, paymentHandler *handler.PaymentHandler, prayerHandler *handler.PrayerRequestHandler) *gin.Engine {
	// Set Gin mode
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// Note: CORS is handled by the API gateway - do not set CORS headers here
	// to avoid duplicate header values when proxied through the gateway

	// Health check
	router.GET("/health", deliveryHandler.HealthCheck)

	// API routes
	api := router.Group("/api")
	
	// Protected routes
	protected := api.Group("/")
	protected.Use(deliveryHandler.AuthMiddleware())
	{
		// Delivery management
		deliveries := protected.Group("/deliveries")
		{
			deliveries.POST("/", deliveryHandler.CreateDelivery)
			deliveries.GET("/:id", deliveryHandler.GetDelivery)
			deliveries.PUT("/:id", deliveryHandler.UpdateDelivery)
			deliveries.DELETE("/:id", deliveryHandler.DeleteDelivery)
			deliveries.PUT("/:id/status", deliveryHandler.UpdateDeliveryStatus)
			deliveries.PUT("/:id/assign", deliveryHandler.AssignDelivery)
			deliveries.PUT("/:id/start", deliveryHandler.StartDelivery)
			deliveries.PUT("/:id/complete", deliveryHandler.CompleteDelivery)
		}

		// Team deliveries
		teams := protected.Group("/teams")
		{
			teams.GET("/:teamId/deliveries", deliveryHandler.GetTeamDeliveries)
			teams.GET("/:teamId/routes", deliveryHandler.GetTeamRoutes)
			teams.GET("/:teamId/stats", deliveryHandler.GetDeliveryStats)
			teams.GET("/:teamId/worker-stats", deliveryHandler.GetTeamWorkerStats)
		}

		// Worker deliveries and routes
		workers := protected.Group("/workers")
		{
			workers.GET("/:workerId/deliveries", deliveryHandler.GetWorkerDeliveries)
			workers.GET("/:workerId/routes", deliveryHandler.GetWorkerRoutes)
			workers.GET("/:workerId/stats", deliveryHandler.GetWorkerStats)
		}

		// Route management
		routes := protected.Group("/routes")
		{
			routes.POST("/", deliveryHandler.CreateRoute)
			routes.GET("/:id", deliveryHandler.GetRoute)
			routes.PUT("/:id/start", deliveryHandler.StartRoute)
			routes.PUT("/:id/complete", deliveryHandler.CompleteRoute)
			routes.PUT("/:id/optimize", deliveryHandler.OptimizeRoute)
		}

		// Receipt management
		receipts := protected.Group("/receipts")
		{
			receipts.POST("/", receiptHandler.CreateReceipt)
			receipts.GET("/:id", receiptHandler.GetReceipt)
			receipts.GET("/number/:receiptNumber", receiptHandler.GetReceiptByNumber)
			receipts.PUT("/:id/cancel", receiptHandler.CancelReceipt)
			receipts.PUT("/:id/refund", receiptHandler.RefundReceipt)
			receipts.GET("/worker/:workerId", receiptHandler.GetWorkerReceipts)
			receipts.GET("/team/:teamId", receiptHandler.GetTeamReceipts)
			receipts.GET("/session/:sessionId", receiptHandler.GetSessionReceipts)
			receipts.GET("/stats/team/:teamId", receiptHandler.GetReceiptStats)
			receipts.GET("/stats/worker/:workerId", receiptHandler.GetWorkerReceiptStats)
		}

		// Donation management
		donations := protected.Group("/donations")
		{
			// Global donation endpoints query deliveries table (where donations actually live)
			donations.GET("/all", deliveryHandler.GetAllDonationDeliveries)
			donations.GET("/stats", deliveryHandler.GetGlobalDonationDeliveryStats)
			donations.POST("/", receiptHandler.CreateDonation)
			donations.GET("/:id", receiptHandler.GetDonation)
			donations.PUT("/:id/deposit", receiptHandler.MarkDonationDeposited)
			donations.PUT("/:id/cancel", receiptHandler.CancelDonation)
			donations.GET("/worker/:workerId", receiptHandler.GetWorkerDonations)
			// Team donation endpoints query deliveries table
			donations.GET("/team/:teamId", deliveryHandler.GetTeamDonationDeliveries)
			donations.GET("/session/:sessionId", receiptHandler.GetSessionDonations)
			donations.GET("/stats/team/:teamId", deliveryHandler.GetTeamDonationDeliveryStats)
			donations.GET("/stats/worker/:workerId", receiptHandler.GetWorkerDonationStats)
		}

		// Payment management (Stripe)
		payments := protected.Group("/payments")
		{
			payments.POST("/create-intent", paymentHandler.CreatePaymentIntent)
			payments.GET("/verify/:id", paymentHandler.VerifyPayment)
			payments.POST("/send-link", paymentHandler.SendPaymentLink)
			payments.GET("/status/:sessionId", paymentHandler.GetPaymentStatus)
		}

		// Prayer request management
		prayerRequests := protected.Group("/prayer-requests")
		{
			prayerRequests.POST("/", prayerHandler.CreatePrayerRequest)
			prayerRequests.GET("/", prayerHandler.ListPrayerRequests)
			prayerRequests.GET("/me", prayerHandler.GetMyPrayerRequests)
			prayerRequests.GET("/map", prayerHandler.GetMapMarkers)
			prayerRequests.GET("/stats", prayerHandler.GetStats)
			prayerRequests.GET("/:id", prayerHandler.GetPrayerRequest)
			prayerRequests.PUT("/:id", prayerHandler.UpdatePrayerRequest)
			prayerRequests.DELETE("/:id", prayerHandler.DeletePrayerRequest)
			prayerRequests.PUT("/:id/status", prayerHandler.UpdateStatus)
			prayerRequests.PUT("/:id/assign-preacher", prayerHandler.AssignPreacher)
			prayerRequests.PUT("/:id/complete", prayerHandler.CompletePrayerRequest)
			prayerRequests.GET("/worker/:workerId", prayerHandler.GetWorkerPrayerRequests)
			prayerRequests.GET("/team/:teamId", prayerHandler.GetTeamPrayerRequests)
			prayerRequests.GET("/territory/:territoryId", prayerHandler.GetTerritoryPrayerRequests)
		}
	}

	// Stripe webhook (unprotected - uses Stripe signature verification)
	api.POST("/webhooks/stripe", paymentHandler.HandleWebhook)

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
