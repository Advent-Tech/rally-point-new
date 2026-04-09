package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rally-point/shared/auth"
	"rally-point/delivery-service/internal/domain"
)

type DeliveryHandler struct {
	deliveryService domain.DeliveryService
	jwtManager      *auth.JWTManager
}

// NewDeliveryHandler creates a new delivery handler
func NewDeliveryHandler(deliveryService domain.DeliveryService, jwtManager *auth.JWTManager) *DeliveryHandler {
	return &DeliveryHandler{
		deliveryService: deliveryService,
		jwtManager:      jwtManager,
	}
}

// CreateDelivery handles delivery creation
func (h *DeliveryHandler) CreateDelivery(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	// Get user display name from header (set by API gateway)
	displayName := c.GetHeader("X-User-DisplayName")

	var req domain.CreateDeliveryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set worker name from header if not provided in request
	if req.WorkerName == "" && displayName != "" {
		req.WorkerName = displayName
	}

	delivery, err := h.deliveryService.CreateDelivery(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, delivery)
}

// GetDelivery handles getting a delivery by ID
func (h *DeliveryHandler) GetDelivery(c *gin.Context) {
	deliveryIDStr := c.Param("id")
	deliveryID, err := uuid.Parse(deliveryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid delivery ID"})
		return
	}

	delivery, err := h.deliveryService.GetDelivery(deliveryID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, delivery)
}

// UpdateDelivery handles delivery updates
func (h *DeliveryHandler) UpdateDelivery(c *gin.Context) {
	deliveryIDStr := c.Param("id")
	deliveryID, err := uuid.Parse(deliveryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid delivery ID"})
		return
	}

	var req domain.UpdateDeliveryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	delivery, err := h.deliveryService.UpdateDelivery(deliveryID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, delivery)
}

// DeleteDelivery handles delivery deletion
func (h *DeliveryHandler) DeleteDelivery(c *gin.Context) {
	deliveryIDStr := c.Param("id")
	deliveryID, err := uuid.Parse(deliveryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid delivery ID"})
		return
	}

	err = h.deliveryService.DeleteDelivery(deliveryID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "delivery deleted successfully"})
}

// GetTeamDeliveries handles getting deliveries for a team
func (h *DeliveryHandler) GetTeamDeliveries(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	// Parse query parameters
	status := c.Query("status")
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit parameter"})
		return
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid offset parameter"})
		return
	}

	deliveries, err := h.deliveryService.GetTeamDeliveries(teamID, status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"deliveries": deliveries,
		"count":      len(deliveries),
	})
}

// GetWorkerDeliveries handles getting deliveries for a worker
func (h *DeliveryHandler) GetWorkerDeliveries(c *gin.Context) {
	workerIDStr := c.Param("workerId")

	// Support "me" as a shorthand for the authenticated user
	if workerIDStr == "me" {
		workerIDStr = c.GetHeader("X-User-ID")
		if workerIDStr == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
			return
		}
	}

	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	// Parse pagination parameters
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit parameter"})
		return
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid offset parameter"})
		return
	}

	deliveries, err := h.deliveryService.GetWorkerDeliveries(workerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"deliveries": deliveries,
		"count":      len(deliveries),
	})
}

// UpdateDeliveryStatus handles delivery status updates
func (h *DeliveryHandler) UpdateDeliveryStatus(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	deliveryIDStr := c.Param("id")
	deliveryID, err := uuid.Parse(deliveryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid delivery ID"})
		return
	}

	var req domain.UpdateDeliveryStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.deliveryService.UpdateDeliveryStatus(deliveryID, uid, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "delivery status updated successfully"})
}

// AssignDelivery handles delivery assignment
func (h *DeliveryHandler) AssignDelivery(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	assignerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	deliveryIDStr := c.Param("id")
	deliveryID, err := uuid.Parse(deliveryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid delivery ID"})
		return
	}

	var req struct {
		WorkerID uuid.UUID `json:"worker_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.deliveryService.AssignDelivery(deliveryID, req.WorkerID, assignerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "delivery assigned successfully"})
}

// StartDelivery handles starting a delivery
func (h *DeliveryHandler) StartDelivery(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	deliveryIDStr := c.Param("id")
	deliveryID, err := uuid.Parse(deliveryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid delivery ID"})
		return
	}

	err = h.deliveryService.StartDelivery(deliveryID, workerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "delivery started successfully"})
}

// CompleteDelivery handles completing a delivery
func (h *DeliveryHandler) CompleteDelivery(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	deliveryIDStr := c.Param("id")
	deliveryID, err := uuid.Parse(deliveryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid delivery ID"})
		return
	}

	var req domain.UpdateDeliveryStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.deliveryService.CompleteDelivery(deliveryID, workerID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "delivery completed successfully"})
}

// CreateRoute handles route creation
func (h *DeliveryHandler) CreateRoute(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	creatorID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.CreateRouteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	route, err := h.deliveryService.CreateRoute(creatorID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, route)
}

// GetRoute handles getting a route by ID
func (h *DeliveryHandler) GetRoute(c *gin.Context) {
	routeIDStr := c.Param("id")
	routeID, err := uuid.Parse(routeIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid route ID"})
		return
	}

	route, err := h.deliveryService.GetRoute(routeID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, route)
}

// GetTeamRoutes handles getting routes for a team
func (h *DeliveryHandler) GetTeamRoutes(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	// Parse pagination parameters
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit parameter"})
		return
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid offset parameter"})
		return
	}

	routes, err := h.deliveryService.GetTeamRoutes(teamID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"routes": routes,
		"count":  len(routes),
	})
}

// GetWorkerRoutes handles getting routes for a worker
func (h *DeliveryHandler) GetWorkerRoutes(c *gin.Context) {
	workerIDStr := c.Param("workerId")

	// Support "me" as a shorthand for the authenticated user
	if workerIDStr == "me" {
		workerIDStr = c.GetHeader("X-User-ID")
		if workerIDStr == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
			return
		}
	}

	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	// Parse pagination parameters
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit parameter"})
		return
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid offset parameter"})
		return
	}

	routes, err := h.deliveryService.GetWorkerRoutes(workerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"routes": routes,
		"count":  len(routes),
	})
}

// StartRoute handles starting a route
func (h *DeliveryHandler) StartRoute(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	routeIDStr := c.Param("id")
	routeID, err := uuid.Parse(routeIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid route ID"})
		return
	}

	err = h.deliveryService.StartRoute(routeID, workerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "route started successfully"})
}

// CompleteRoute handles completing a route
func (h *DeliveryHandler) CompleteRoute(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	routeIDStr := c.Param("id")
	routeID, err := uuid.Parse(routeIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid route ID"})
		return
	}

	err = h.deliveryService.CompleteRoute(routeID, workerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "route completed successfully"})
}

// OptimizeRoute handles route optimization
func (h *DeliveryHandler) OptimizeRoute(c *gin.Context) {
	routeIDStr := c.Param("id")
	routeID, err := uuid.Parse(routeIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid route ID"})
		return
	}

	route, err := h.deliveryService.OptimizeRoute(routeID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, route)
}

// GetDeliveryStats handles getting delivery statistics
func (h *DeliveryHandler) GetDeliveryStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid days parameter"})
		return
	}

	stats, err := h.deliveryService.GetDeliveryStats(teamID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetWorkerStats handles getting worker statistics
func (h *DeliveryHandler) GetWorkerStats(c *gin.Context) {
	workerIDStr := c.Param("workerId")

	// Support "me" as a shorthand for the authenticated user
	if workerIDStr == "me" {
		workerIDStr = c.GetHeader("X-User-ID")
		if workerIDStr == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
			return
		}
	}

	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid days parameter"})
		return
	}

	stats, err := h.deliveryService.GetWorkerStats(workerID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetTeamWorkerStats handles getting team worker statistics
func (h *DeliveryHandler) GetTeamWorkerStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid days parameter"})
		return
	}

	stats, err := h.deliveryService.GetTeamWorkerStats(teamID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"worker_stats": stats,
		"count":        len(stats),
	})
}

// GetAllDonationDeliveries returns all donation-type deliveries
// GET /api/donations/all
func (h *DeliveryHandler) GetAllDonationDeliveries(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	donations, err := h.deliveryService.GetAllDonationDeliveries(limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// GetTeamDonationDeliveries returns team-specific donation-type deliveries
// GET /api/donations/team/:teamId
func (h *DeliveryHandler) GetTeamDonationDeliveries(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	donations, err := h.deliveryService.GetTeamDonationDeliveries(teamID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// GetTeamDonationDeliveryStats returns team-specific donation stats from deliveries table
// GET /api/donations/stats/team/:teamId
func (h *DeliveryHandler) GetTeamDonationDeliveryStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	// Default to 0 = all-time
	daysStr := c.DefaultQuery("days", "0")
	days, _ := strconv.Atoi(daysStr)

	stats, err := h.deliveryService.GetTeamDonationDeliveryStats(teamID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetGlobalDonationDeliveryStats returns global donation stats from deliveries table
// GET /api/donations/stats
func (h *DeliveryHandler) GetGlobalDonationDeliveryStats(c *gin.Context) {
	// Default to 0 = all-time
	daysStr := c.DefaultQuery("days", "0")
	days, _ := strconv.Atoi(daysStr)

	stats, err := h.deliveryService.GetGlobalDonationDeliveryStats(days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetAllBookSales returns all book_sale-type deliveries
// GET /api/book-sales/all
func (h *DeliveryHandler) GetAllBookSales(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	bookSales, err := h.deliveryService.GetAllBookSales(limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"book_sales": bookSales,
		"count":      len(bookSales),
	})
}

// GetTeamBookSales returns team-specific book_sale-type deliveries
// GET /api/book-sales/team/:teamId
func (h *DeliveryHandler) GetTeamBookSales(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	bookSales, err := h.deliveryService.GetTeamBookSales(teamID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"book_sales": bookSales,
		"count":      len(bookSales),
	})
}

// GetGlobalBookSaleStats returns global book sale stats
// GET /api/book-sales/stats
func (h *DeliveryHandler) GetGlobalBookSaleStats(c *gin.Context) {
	daysStr := c.DefaultQuery("days", "0")
	days, _ := strconv.Atoi(daysStr)

	stats, err := h.deliveryService.GetGlobalBookSaleStats(days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, stats)
}

// GetTeamBookSaleStats returns team-specific book sale stats
// GET /api/book-sales/stats/team/:teamId
func (h *DeliveryHandler) GetTeamBookSaleStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	daysStr := c.DefaultQuery("days", "0")
	days, _ := strconv.Atoi(daysStr)

	stats, err := h.deliveryService.GetTeamBookSaleStats(teamID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// AuthMiddleware validates JWT tokens
func (h *DeliveryHandler) AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization header required"})
			c.Abort()
			return
		}

		token := auth.ExtractTokenFromHeader(authHeader)
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header format"})
			c.Abort()
			return
		}

		claims, err := h.jwtManager.VerifyToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			c.Abort()
			return
		}

		if claims.TokenType != "access" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token type"})
			c.Abort()
			return
		}

		c.Set("user_id", claims.UserID.String())
		c.Set("user_email", claims.Email)
		c.Set("user_role", claims.Role)
		if claims.TeamID != nil {
			c.Set("team_id", claims.TeamID.String())
		}

		c.Next()
	}
}

// HealthCheck handles health check
func (h *DeliveryHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "delivery-service",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
