package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/donation-service/internal/domain"
	"github.com/rally-point/shared/auth"
)

type DonationHandler struct {
	donationService domain.DonationService
	jwtManager      *auth.JWTManager
}

// NewDonationHandler creates a new donation handler
func NewDonationHandler(donationService domain.DonationService, jwtManager *auth.JWTManager) *DonationHandler {
	return &DonationHandler{
		donationService: donationService,
		jwtManager:      jwtManager,
	}
}

// CreateDonation handles creating a new donation
func (h *DonationHandler) CreateDonation(c *gin.Context) {
	userID := c.GetString("user_id")
	userName := c.GetString("user_name")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.CreateDonationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	donation, err := h.donationService.CreateDonation(workerID, userName, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, donation)
}

// GetDonation handles getting a donation by ID
func (h *DonationHandler) GetDonation(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid donation ID"})
		return
	}

	donation, err := h.donationService.GetDonation(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "donation not found"})
		return
	}

	c.JSON(http.StatusOK, donation)
}

// UpdateDonation handles updating a donation
func (h *DonationHandler) UpdateDonation(c *gin.Context) {
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

	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid donation ID"})
		return
	}

	var req domain.UpdateDonationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	donation, err := h.donationService.UpdateDonation(id, workerID, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, donation)
}

// DeleteDonation handles deleting a donation
func (h *DonationHandler) DeleteDonation(c *gin.Context) {
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

	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid donation ID"})
		return
	}

	err = h.donationService.DeleteDonation(id, workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "donation deleted"})
}

// ListDonations handles listing donations with filters
func (h *DonationHandler) ListDonations(c *gin.Context) {
	var query domain.DonationQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set defaults
	if query.Limit == 0 {
		query.Limit = 50
	}

	donations, err := h.donationService.ListDonations(&query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// GetWorkerDonations handles getting donations for a specific worker
func (h *DonationHandler) GetWorkerDonations(c *gin.Context) {
	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	donations, err := h.donationService.GetWorkerDonations(workerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// GetTeamDonations handles getting donations for a team
func (h *DonationHandler) GetTeamDonations(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	donations, err := h.donationService.GetTeamDonations(teamID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"count":     len(donations),
	})
}

// GetWorkerStats handles getting donation statistics for a worker
func (h *DonationHandler) GetWorkerStats(c *gin.Context) {
	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		// If no worker ID in path, use authenticated user
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "worker ID required"})
			return
		}
		workerID, err = uuid.Parse(userID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
			return
		}
	}

	days, _ := strconv.Atoi(c.DefaultQuery("days", "30"))

	stats, err := h.donationService.GetWorkerStats(workerID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetMyStats handles getting donation statistics for the authenticated user
func (h *DonationHandler) GetMyStats(c *gin.Context) {
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

	days, _ := strconv.Atoi(c.DefaultQuery("days", "30"))

	stats, err := h.donationService.GetWorkerStats(workerID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetTeamStats handles getting donation statistics for a team
func (h *DonationHandler) GetTeamStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	days, _ := strconv.Atoi(c.DefaultQuery("days", "30"))

	stats, err := h.donationService.GetTeamStats(teamID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetTeamWorkerStats handles getting donation statistics per worker for a team
func (h *DonationHandler) GetTeamWorkerStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	stats, err := h.donationService.GetTeamWorkerStats(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"worker_stats": stats,
		"count":        len(stats),
	})
}

// AuthMiddleware validates JWT tokens
func (h *DonationHandler) AuthMiddleware() gin.HandlerFunc {
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
		c.Set("user_name", claims.DisplayName)
		c.Set("user_role", claims.Role)
		if claims.TeamID != nil {
			c.Set("team_id", claims.TeamID.String())
		}

		c.Next()
	}
}

// HealthCheck handles health check requests
func (h *DonationHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "donation-service",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
