package handler

import (
	"net/http"
	"strconv"
	"time"

	"rally-point/delivery-service/internal/domain"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type PrayerRequestHandler struct {
	service *domain.PrayerRequestService
}

func NewPrayerRequestHandler(service domain.PrayerRequestService) *PrayerRequestHandler {
	return &PrayerRequestHandler{service: &service}
}

// CreatePrayerRequest handles POST /api/prayer-requests
func (h *PrayerRequestHandler) CreatePrayerRequest(c *gin.Context) {
	// Get user info from context (set by auth middleware)
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	teamIDStr := c.GetString("team_id")
	teamID, _ := uuid.Parse(teamIDStr)

	var req domain.CreatePrayerRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := (*h.service).CreatePrayerRequest(userID, teamID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, result)
}

// GetPrayerRequest handles GET /api/prayer-requests/:id
func (h *PrayerRequestHandler) GetPrayerRequest(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid prayer request ID"})
		return
	}

	result, err := (*h.service).GetPrayerRequest(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "prayer request not found"})
		return
	}

	c.JSON(http.StatusOK, result)
}

// UpdatePrayerRequest handles PUT /api/prayer-requests/:id
func (h *PrayerRequestHandler) UpdatePrayerRequest(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid prayer request ID"})
		return
	}

	var req domain.UpdatePrayerRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := (*h.service).UpdatePrayerRequest(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// DeletePrayerRequest handles DELETE /api/prayer-requests/:id
func (h *PrayerRequestHandler) DeletePrayerRequest(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid prayer request ID"})
		return
	}

	err = (*h.service).DeletePrayerRequest(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "prayer request deleted"})
}

// ListPrayerRequests handles GET /api/prayer-requests
func (h *PrayerRequestHandler) ListPrayerRequests(c *gin.Context) {
	// Parse pagination
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	// Parse filters
	filter := &domain.PrayerRequestFilter{}

	if teamID := c.Query("team_id"); teamID != "" {
		if id, err := uuid.Parse(teamID); err == nil {
			filter.TeamID = &id
		}
	}

	if territoryID := c.Query("territory_id"); territoryID != "" {
		if id, err := uuid.Parse(territoryID); err == nil {
			filter.TerritoryID = &id
		}
	}

	if status := c.Query("status"); status != "" {
		filter.Status = &status
	}

	if requestType := c.Query("request_type"); requestType != "" {
		filter.RequestType = &requestType
	}

	if category := c.Query("category"); category != "" {
		filter.Category = &category
	}

	if urgency := c.Query("urgency"); urgency != "" {
		filter.Urgency = &urgency
	}

	result, err := (*h.service).ListPrayerRequests(filter, page, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetMapMarkers handles GET /api/prayer-requests/map
func (h *PrayerRequestHandler) GetMapMarkers(c *gin.Context) {
	filter := &domain.PrayerRequestFilter{}

	if teamID := c.Query("team_id"); teamID != "" {
		if id, err := uuid.Parse(teamID); err == nil {
			filter.TeamID = &id
		}
	}

	if territoryID := c.Query("territory_id"); territoryID != "" {
		if id, err := uuid.Parse(territoryID); err == nil {
			filter.TerritoryID = &id
		}
	}

	if status := c.Query("status"); status != "" {
		filter.Status = &status
	}

	if requestType := c.Query("request_type"); requestType != "" {
		filter.RequestType = &requestType
	}

	markers, err := (*h.service).GetMapMarkers(filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"markers": markers})
}

// GetWorkerPrayerRequests handles GET /api/prayer-requests/worker/:workerId
func (h *PrayerRequestHandler) GetWorkerPrayerRequests(c *gin.Context) {
	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	result, err := (*h.service).GetWorkerPrayerRequests(workerID, page, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetMyPrayerRequests handles GET /api/prayer-requests/me
func (h *PrayerRequestHandler) GetMyPrayerRequests(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	result, err := (*h.service).GetWorkerPrayerRequests(userID, page, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetTeamPrayerRequests handles GET /api/prayer-requests/team/:teamId
func (h *PrayerRequestHandler) GetTeamPrayerRequests(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	result, err := (*h.service).GetTeamPrayerRequests(teamID, page, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetTerritoryPrayerRequests handles GET /api/prayer-requests/territory/:territoryId
func (h *PrayerRequestHandler) GetTerritoryPrayerRequests(c *gin.Context) {
	territoryIDStr := c.Param("territoryId")
	territoryID, err := uuid.Parse(territoryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	result, err := (*h.service).GetTerritoryPrayerRequests(territoryID, page, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetStats handles GET /api/prayer-requests/stats
func (h *PrayerRequestHandler) GetStats(c *gin.Context) {
	filter := &domain.PrayerRequestFilter{}

	if teamID := c.Query("team_id"); teamID != "" {
		if id, err := uuid.Parse(teamID); err == nil {
			filter.TeamID = &id
		}
	}

	if territoryID := c.Query("territory_id"); territoryID != "" {
		if id, err := uuid.Parse(territoryID); err == nil {
			filter.TerritoryID = &id
		}
	}

	stats, err := (*h.service).GetStats(filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// UpdateStatus handles PUT /api/prayer-requests/:id/status
func (h *PrayerRequestHandler) UpdateStatus(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid prayer request ID"})
		return
	}

	var req domain.UpdatePrayerStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user ID for completion tracking
	var completedBy *uuid.UUID
	if req.Status == domain.PrayerStatusCompleted {
		userIDStr := c.GetString("user_id")
		if userID, err := uuid.Parse(userIDStr); err == nil {
			completedBy = &userID
		}
	}

	err = (*h.service).UpdateStatus(id, req.Status, completedBy, req.CompletionNotes)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "status updated"})
}

// AssignPreacher handles PUT /api/prayer-requests/:id/assign-preacher
func (h *PrayerRequestHandler) AssignPreacher(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid prayer request ID"})
		return
	}

	var req domain.AssignPreacherRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	preacherID, err := uuid.Parse(req.PreacherID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid preacher ID"})
		return
	}

	var scheduledAt *time.Time
	if req.ScheduledAt != nil {
		parsed, err := time.Parse(time.RFC3339, *req.ScheduledAt)
		if err == nil {
			scheduledAt = &parsed
		}
	}

	err = (*h.service).AssignPreacher(id, preacherID, scheduledAt, req.Notes)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "preacher assigned"})
}

// CompletePrayerRequest handles PUT /api/prayer-requests/:id/complete
func (h *PrayerRequestHandler) CompletePrayerRequest(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid prayer request ID"})
		return
	}

	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	var req struct {
		Notes *string `json:"notes"`
	}
	c.ShouldBindJSON(&req)

	err = (*h.service).CompletePrayerRequest(id, userID, req.Notes)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "prayer request completed"})
}
