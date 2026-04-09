package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// GeofenceHandler handles geofence-related HTTP requests
type GeofenceHandler struct {
	service domain.GeofenceService
}

// NewGeofenceHandler creates a new geofence handler
func NewGeofenceHandler(service domain.GeofenceService) *GeofenceHandler {
	return &GeofenceHandler{service: service}
}

// RegisterRoutes registers geofence routes
func (h *GeofenceHandler) RegisterRoutes(router *gin.RouterGroup) {
	geofence := router.Group("/geofence")
	{
		// Check if a location is inside assigned territories
		geofence.POST("/check", h.CheckLocation)

		// Process location update (entry/exit detection)
		geofence.POST("/location-update", h.ProcessLocationUpdate)

		// Get worker's current territory status
		geofence.GET("/worker/:workerId/current", h.GetWorkerCurrentTerritory)

		// Get worker's work session history
		geofence.GET("/worker/:workerId/sessions", h.GetWorkerWorkSessions)

		// Get territory work sessions
		geofence.GET("/territory/:territoryId/sessions", h.GetTerritoryWorkSessions)

		// Manual check-in/check-out endpoints
		geofence.POST("/checkin", h.CheckIn)
		geofence.POST("/checkout", h.CheckOut)

		// Get worker's current active session with details
		geofence.GET("/worker/:workerId/session", h.GetWorkerCurrentSession)

		// Visit logging endpoints
		geofence.POST("/sessions/:sessionId/visits", h.LogVisit)
		geofence.GET("/sessions/:sessionId/visits", h.GetSessionVisits)

		// Active workers endpoints
		geofence.GET("/workers/active", h.GetActiveWorkers)
		geofence.GET("/teams/:teamId/workers/active", h.GetTeamActiveWorkers)
	}

	// Worker-centric endpoints for activity tracking (used by WorkerActivityScreen)
	workSessions := router.Group("/work-sessions")
	{
		workSessions.GET("/worker/:workerId", h.GetWorkerWorkSessionsByDate)
	}

	visits := router.Group("/visits")
	{
		visits.GET("/worker/:workerId", h.GetWorkerVisitsByDate)
	}
}

// CheckLocation checks if a location is inside a worker's assigned territories
// POST /api/geofence/check
func (h *GeofenceHandler) CheckLocation(c *gin.Context) {
	var req domain.GeofenceCheckRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := h.service.CheckWorkerLocation(&req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// ProcessLocationUpdate processes a location update and detects territory entry/exit
// POST /api/geofence/location-update
func (h *GeofenceHandler) ProcessLocationUpdate(c *gin.Context) {
	var req struct {
		WorkerID  string  `json:"worker_id" binding:"required"`
		TeamID    *string `json:"team_id,omitempty"`
		Latitude  float64 `json:"latitude" binding:"required"`
		Longitude float64 `json:"longitude" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	workerID, err := uuid.Parse(req.WorkerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	var teamID *uuid.UUID
	if req.TeamID != nil {
		parsed, err := uuid.Parse(*req.TeamID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team_id"})
			return
		}
		teamID = &parsed
	}

	update := &domain.WorkerLocationUpdate{
		WorkerID:  workerID,
		TeamID:    teamID,
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		Timestamp: time.Now(),
	}

	event, err := h.service.ProcessLocationUpdate(update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Return event if any, otherwise return status
	if event != nil {
		c.JSON(http.StatusOK, gin.H{
			"event":   event,
			"message": "Territory " + event.EventType + " detected",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"event":   nil,
		"message": "No territory change detected",
	})
}

// GetWorkerCurrentTerritory gets the worker's current territory status
// GET /api/geofence/worker/:workerId/current
func (h *GeofenceHandler) GetWorkerCurrentTerritory(c *gin.Context) {
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
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	result, err := h.service.GetWorkerCurrentTerritory(workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetWorkerWorkSessions gets the work session history for a worker
// GET /api/geofence/worker/:workerId/sessions
func (h *GeofenceHandler) GetWorkerWorkSessions(c *gin.Context) {
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
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

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

	sessions, err := h.service.GetWorkerWorkSessions(workerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"sessions": sessions,
		"count":    len(sessions),
	})
}

// GetTerritoryWorkSessions gets work sessions for a territory
// GET /api/geofence/territory/:territoryId/sessions
func (h *GeofenceHandler) GetTerritoryWorkSessions(c *gin.Context) {
	territoryIDStr := c.Param("territoryId")
	_, err := uuid.Parse(territoryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory_id"})
		return
	}

	// For now, return a placeholder - we'd need to add this to the service interface
	c.JSON(http.StatusOK, gin.H{
		"sessions": []interface{}{},
		"message":  "Territory work sessions endpoint - implement as needed",
	})
}

// CheckIn performs a manual check-in for a worker
// POST /api/geofence/checkin
func (h *GeofenceHandler) CheckIn(c *gin.Context) {
	var req struct {
		WorkerID      string   `json:"worker_id" binding:"required"`
		TerritoryID   string   `json:"territory_id" binding:"required"`
		TerritoryName string   `json:"territory_name" binding:"required"`
		Latitude      *float64 `json:"latitude,omitempty"`
		Longitude     *float64 `json:"longitude,omitempty"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	workerID, err := uuid.Parse(req.WorkerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	territoryID, err := uuid.Parse(req.TerritoryID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory_id"})
		return
	}

	checkInReq := &domain.CheckInRequest{
		WorkerID:      workerID,
		TerritoryID:   territoryID,
		TerritoryName: req.TerritoryName,
		Latitude:      req.Latitude,
		Longitude:     req.Longitude,
	}

	session, err := h.service.CheckIn(checkInReq)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"session": session,
		"message": "Check-in successful",
	})
}

// CheckOut performs a manual check-out for a worker
// POST /api/geofence/checkout
func (h *GeofenceHandler) CheckOut(c *gin.Context) {
	var req struct {
		WorkerID  string  `json:"worker_id" binding:"required"`
		SessionID string  `json:"session_id" binding:"required"`
		Notes     *string `json:"notes,omitempty"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	workerID, err := uuid.Parse(req.WorkerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	sessionID, err := uuid.Parse(req.SessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session_id"})
		return
	}

	checkOutReq := &domain.CheckOutRequest{
		WorkerID:  workerID,
		SessionID: sessionID,
		Notes:     req.Notes,
	}

	session, err := h.service.CheckOut(checkOutReq)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"session": session,
		"message": "Check-out successful",
	})
}

// GetWorkerCurrentSession gets the worker's current active session with details
// GET /api/geofence/worker/:workerId/session
func (h *GeofenceHandler) GetWorkerCurrentSession(c *gin.Context) {
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
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	session, err := h.service.GetWorkerCurrentSession(workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if session == nil {
		c.JSON(http.StatusOK, gin.H{
			"session":   nil,
			"has_active": false,
			"message":   "No active work session",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"session":    session,
		"has_active": true,
	})
}

// LogVisit logs a visit during an active work session
// POST /api/geofence/sessions/:sessionId/visits
func (h *GeofenceHandler) LogVisit(c *gin.Context) {
	sessionIDStr := c.Param("sessionId")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session_id"})
		return
	}

	var req struct {
		Address   string   `json:"address" binding:"required"`
		Outcome   string   `json:"outcome" binding:"required"`
		Notes     *string  `json:"notes,omitempty"`
		Latitude  *float64 `json:"latitude,omitempty"`
		Longitude *float64 `json:"longitude,omitempty"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate outcome
	validOutcomes := map[string]bool{
		"contacted":   true,
		"not_home":    true,
		"interested":  true,
		"do_not_call": true,
		"completed":   true,
		"other":       true,
	}

	if !validOutcomes[req.Outcome] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid outcome value"})
		return
	}

	visitReq := &domain.LogVisitRequest{
		SessionID: sessionID,
		Address:   req.Address,
		Outcome:   req.Outcome,
		Notes:     req.Notes,
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
	}

	visit, err := h.service.LogVisit(visitReq)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"visit":   visit,
		"message": "Visit logged successfully",
	})
}

// GetSessionVisits gets all visits for a work session
// GET /api/geofence/sessions/:sessionId/visits
func (h *GeofenceHandler) GetSessionVisits(c *gin.Context) {
	sessionIDStr := c.Param("sessionId")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session_id"})
		return
	}

	visits, err := h.service.GetSessionVisits(sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"visits": visits,
		"count":  len(visits),
	})
}

// GetActiveWorkers gets all currently active workers
// GET /api/geofence/workers/active
func (h *GeofenceHandler) GetActiveWorkers(c *gin.Context) {
	sessions, err := h.service.GetActiveWorkers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"active_sessions": sessions,
		"count":           len(sessions),
	})
}

// GetTeamActiveWorkers gets active workers for a specific team
// GET /api/geofence/teams/:teamId/workers/active
func (h *GeofenceHandler) GetTeamActiveWorkers(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team_id"})
		return
	}

	sessions, err := h.service.GetTeamActiveWorkers(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"active_sessions": sessions,
		"count":           len(sessions),
	})
}

// GetWorkerWorkSessionsByDate gets work sessions for a worker on a specific date
// GET /api/work-sessions/worker/:workerId?date=YYYY-MM-DD
func (h *GeofenceHandler) GetWorkerWorkSessionsByDate(c *gin.Context) {
	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	// Parse date from query param, default to today
	dateStr := c.Query("date")
	var date time.Time
	if dateStr == "" {
		date = time.Now()
	} else {
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid date format, expected YYYY-MM-DD"})
			return
		}
	}

	sessions, err := h.service.GetWorkerWorkSessionsByDate(workerID, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"sessions": sessions,
		"count":    len(sessions),
		"date":     date.Format("2006-01-02"),
	})
}

// GetWorkerVisitsByDate gets all visits for a worker on a specific date
// GET /api/visits/worker/:workerId?date=YYYY-MM-DD
func (h *GeofenceHandler) GetWorkerVisitsByDate(c *gin.Context) {
	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	// Parse date from query param, default to today
	dateStr := c.Query("date")
	var date time.Time
	if dateStr == "" {
		date = time.Now()
	} else {
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid date format, expected YYYY-MM-DD"})
			return
		}
	}

	visits, err := h.service.GetWorkerVisits(workerID, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"visits": visits,
		"count":  len(visits),
		"date":   date.Format("2006-01-02"),
	})
}
