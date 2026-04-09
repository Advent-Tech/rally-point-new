package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/delivery-service/internal/domain"
)

// ReceiptHandler handles receipt and donation HTTP requests
type ReceiptHandler struct {
	service domain.ReceiptService
}

// NewReceiptHandler creates a new receipt handler
func NewReceiptHandler(service domain.ReceiptService) *ReceiptHandler {
	return &ReceiptHandler{service: service}
}

// RegisterRoutes registers receipt and donation routes
func (h *ReceiptHandler) RegisterRoutes(router *gin.RouterGroup) {
	// Receipt routes
	receipts := router.Group("/receipts")
	{
		receipts.POST("", h.CreateReceipt)
		receipts.GET("/:id", h.GetReceipt)
		receipts.GET("/number/:number", h.GetReceiptByNumber)
		receipts.GET("/worker/:workerId", h.GetWorkerReceipts)
		receipts.GET("/team/:teamId", h.GetTeamReceipts)
		receipts.GET("/session/:sessionId", h.GetSessionReceipts)
		receipts.POST("/:id/cancel", h.CancelReceipt)
		receipts.POST("/:id/refund", h.RefundReceipt)
		receipts.GET("/stats/team/:teamId", h.GetReceiptStats)
		receipts.GET("/stats/worker/:workerId", h.GetWorkerReceiptStats)
	}

	// Donation routes
	donations := router.Group("/donations")
	{
		donations.POST("", h.CreateDonation)
		donations.GET("/:id", h.GetDonation)
		donations.GET("/worker/:workerId", h.GetWorkerDonations)
		donations.GET("/team/:teamId", h.GetTeamDonations)
		donations.GET("/session/:sessionId", h.GetSessionDonations)
		donations.POST("/:id/deposit", h.MarkDonationDeposited)
		donations.POST("/:id/cancel", h.CancelDonation)
		donations.GET("/stats/team/:teamId", h.GetDonationStats)
		donations.GET("/stats/worker/:workerId", h.GetWorkerDonationStats)
	}
}

// CreateReceipt creates a new receipt
// POST /api/receipts
func (h *ReceiptHandler) CreateReceipt(c *gin.Context) {
	var req domain.CreateReceiptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get worker info from context (set by auth middleware)
	workerID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	workerName, _ := c.Get("user_name")
	workerNameStr := ""
	if workerName != nil {
		workerNameStr = workerName.(string)
	}

	receipt, err := h.service.CreateReceipt(workerID.(uuid.UUID), workerNameStr, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"receipt": receipt,
		"message": "Receipt created successfully",
	})
}

// GetReceipt gets a receipt by ID
// GET /api/receipts/:id
func (h *ReceiptHandler) GetReceipt(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid receipt ID"})
		return
	}

	receipt, err := h.service.GetReceipt(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if receipt == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "receipt not found"})
		return
	}

	c.JSON(http.StatusOK, receipt)
}

// GetReceiptByNumber gets a receipt by receipt number
// GET /api/receipts/number/:number
func (h *ReceiptHandler) GetReceiptByNumber(c *gin.Context) {
	number := c.Param("number")
	if number == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "receipt number required"})
		return
	}

	receipt, err := h.service.GetReceiptByNumber(number)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if receipt == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "receipt not found"})
		return
	}

	c.JSON(http.StatusOK, receipt)
}

// GetWorkerReceipts gets receipts for a worker
// GET /api/receipts/worker/:workerId
func (h *ReceiptHandler) GetWorkerReceipts(c *gin.Context) {
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

	limit, offset := getPaginationParams(c)

	receipts, err := h.service.GetWorkerReceipts(workerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"receipts": receipts,
		"count":    len(receipts),
	})
}

// GetTeamReceipts gets receipts for a team
// GET /api/receipts/team/:teamId
func (h *ReceiptHandler) GetTeamReceipts(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	limit, offset := getPaginationParams(c)

	receipts, err := h.service.GetTeamReceipts(teamID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"receipts": receipts,
		"count":    len(receipts),
	})
}

// GetSessionReceipts gets receipts for a work session
// GET /api/receipts/session/:sessionId
func (h *ReceiptHandler) GetSessionReceipts(c *gin.Context) {
	sessionIDStr := c.Param("sessionId")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session ID"})
		return
	}

	receipts, err := h.service.GetSessionReceipts(sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"receipts": receipts,
		"count":    len(receipts),
	})
}

// CancelReceipt cancels a receipt
// POST /api/receipts/:id/cancel
func (h *ReceiptHandler) CancelReceipt(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid receipt ID"})
		return
	}

	err = h.service.CancelReceipt(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Receipt cancelled successfully"})
}

// RefundReceipt refunds a receipt
// POST /api/receipts/:id/refund
func (h *ReceiptHandler) RefundReceipt(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid receipt ID"})
		return
	}

	err = h.service.RefundReceipt(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Receipt refunded successfully"})
}

// GetReceiptStats gets receipt statistics for a team
// GET /api/receipts/stats/team/:teamId
func (h *ReceiptHandler) GetReceiptStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	days := getDaysParam(c)

	stats, err := h.service.GetReceiptStats(teamID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetWorkerReceiptStats gets receipt statistics for a worker
// GET /api/receipts/stats/worker/:workerId
func (h *ReceiptHandler) GetWorkerReceiptStats(c *gin.Context) {
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

	days := getDaysParam(c)

	stats, err := h.service.GetWorkerReceiptStats(workerID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// CreateDonation creates a new donation
// POST /api/donations
func (h *ReceiptHandler) CreateDonation(c *gin.Context) {
	var req domain.CreateDonationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get worker info from context (set by auth middleware)
	workerID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	workerName, _ := c.Get("user_name")
	workerNameStr := ""
	if workerName != nil {
		workerNameStr = workerName.(string)
	}

	donation, err := h.service.CreateDonation(workerID.(uuid.UUID), workerNameStr, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"donation": donation,
		"message":  "Donation recorded successfully",
	})
}

// GetAllDonations gets all donations across all teams
// GET /api/donations/all
func (h *ReceiptHandler) GetAllDonations(c *gin.Context) {
	limit, offset := getPaginationParams(c)

	donations, err := h.service.GetAllDonations(limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// GetGlobalDonationStats gets donation statistics across all teams
// GET /api/donations/stats
func (h *ReceiptHandler) GetGlobalDonationStats(c *gin.Context) {
	days := getDaysParam(c)

	stats, err := h.service.GetGlobalDonationStats(days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetDonation gets a donation by ID
// GET /api/donations/:id
func (h *ReceiptHandler) GetDonation(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid donation ID"})
		return
	}

	donation, err := h.service.GetDonation(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if donation == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "donation not found"})
		return
	}

	c.JSON(http.StatusOK, donation)
}

// GetWorkerDonations gets donations for a worker
// GET /api/donations/worker/:workerId
func (h *ReceiptHandler) GetWorkerDonations(c *gin.Context) {
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

	limit, offset := getPaginationParams(c)

	donations, err := h.service.GetWorkerDonations(workerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// GetTeamDonations gets donations for a team
// GET /api/donations/team/:teamId
func (h *ReceiptHandler) GetTeamDonations(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	limit, offset := getPaginationParams(c)

	donations, err := h.service.GetTeamDonations(teamID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// GetSessionDonations gets donations for a work session
// GET /api/donations/session/:sessionId
func (h *ReceiptHandler) GetSessionDonations(c *gin.Context) {
	sessionIDStr := c.Param("sessionId")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session ID"})
		return
	}

	donations, err := h.service.GetSessionDonations(sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// MarkDonationDeposited marks a donation as deposited
// POST /api/donations/:id/deposit
func (h *ReceiptHandler) MarkDonationDeposited(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid donation ID"})
		return
	}

	err = h.service.MarkDonationDeposited(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Donation marked as deposited"})
}

// CancelDonation cancels a donation
// POST /api/donations/:id/cancel
func (h *ReceiptHandler) CancelDonation(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid donation ID"})
		return
	}

	err = h.service.CancelDonation(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Donation cancelled successfully"})
}

// GetDonationStats gets donation statistics for a team
// GET /api/donations/stats/team/:teamId
func (h *ReceiptHandler) GetDonationStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	days := getDaysParam(c)

	stats, err := h.service.GetDonationStats(teamID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetWorkerDonationStats gets donation statistics for a worker
// GET /api/donations/stats/worker/:workerId
func (h *ReceiptHandler) GetWorkerDonationStats(c *gin.Context) {
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

	days := getDaysParam(c)

	stats, err := h.service.GetWorkerDonationStats(workerID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// Helper functions
func getPaginationParams(c *gin.Context) (int, int) {
	limit := 50
	offset := 0

	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	return limit, offset
}

func getDaysParam(c *gin.Context) int {
	days := 30 // default

	if d := c.Query("days"); d != "" {
		if parsed, err := strconv.Atoi(d); err == nil && parsed > 0 {
			days = parsed
		}
	}

	return days
}
