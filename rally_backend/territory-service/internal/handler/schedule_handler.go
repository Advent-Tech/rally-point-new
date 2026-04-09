package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// ScheduleHandler handles schedule-related HTTP requests
type ScheduleHandler struct {
	service domain.ScheduleService
}

// NewScheduleHandler creates a new schedule handler
func NewScheduleHandler(service domain.ScheduleService) *ScheduleHandler {
	return &ScheduleHandler{service: service}
}

// RegisterRoutes registers schedule routes
func (h *ScheduleHandler) RegisterRoutes(router *gin.RouterGroup) {
	schedules := router.Group("/schedules")
	{
		// Team leader endpoints
		schedules.GET("/team/:teamId", h.GetTeamSchedules)
		schedules.POST("", h.CreateSchedule)
		schedules.PUT("/:id", h.UpdateSchedule)
		schedules.DELETE("/:id", h.DeleteSchedule)

		// Worker endpoints (for viewing own schedules)
		schedules.GET("/worker/:workerId", h.GetWorkerSchedules)
		schedules.GET("/worker/me", h.GetMySchedules)

		// Session integration
		schedules.POST("/:id/start", h.StartScheduledSession)
		schedules.POST("/:id/complete", h.CompleteScheduledSession)
		schedules.POST("/:id/cancel", h.CancelSchedule)
	}
}

// GetTeamSchedules returns schedules for a team on a specific date
// GET /api/schedules/team/:teamId?date=YYYY-MM-DD
func (h *ScheduleHandler) GetTeamSchedules(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team_id"})
		return
	}

	// Get date from query param, default to today
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

	response, err := h.service.GetTeamSchedules(teamID, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// GetWorkerSchedules returns schedules for a specific worker
// GET /api/schedules/worker/:workerId?date=YYYY-MM-DD
func (h *ScheduleHandler) GetWorkerSchedules(c *gin.Context) {
	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	// Get date from query param, default to today
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

	// Check for date range
	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	if startDateStr != "" && endDateStr != "" {
		startDate, err := time.Parse("2006-01-02", startDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid start_date format"})
			return
		}
		endDate, err := time.Parse("2006-01-02", endDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid end_date format"})
			return
		}

		response, err := h.service.GetWorkerScheduleRange(workerID, startDate, endDate)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, response)
		return
	}

	response, err := h.service.GetWorkerSchedules(workerID, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// GetMySchedules returns schedules for the authenticated worker
// GET /api/schedules/worker/me?date=YYYY-MM-DD
func (h *ScheduleHandler) GetMySchedules(c *gin.Context) {
	// Get user ID from context (set by auth middleware via X-User-ID header)
	userIDStr := c.GetHeader("X-User-ID")
	if userIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
		return
	}

	workerID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user_id"})
		return
	}

	// Get date from query param, default to today
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

	// Check for date range
	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	if startDateStr != "" && endDateStr != "" {
		startDate, err := time.Parse("2006-01-02", startDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid start_date format"})
			return
		}
		endDate, err := time.Parse("2006-01-02", endDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid end_date format"})
			return
		}

		response, err := h.service.GetWorkerScheduleRange(workerID, startDate, endDate)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, response)
		return
	}

	response, err := h.service.GetWorkerSchedules(workerID, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// CreateSchedule creates a new schedule entry
// POST /api/schedules
func (h *ScheduleHandler) CreateSchedule(c *gin.Context) {
	// Get creator ID from context
	creatorIDStr := c.GetHeader("X-User-ID")
	if creatorIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
		return
	}

	creatorID, err := uuid.Parse(creatorIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user_id"})
		return
	}

	var req domain.CreateScheduleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	schedule, err := h.service.CreateSchedule(creatorID, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, schedule)
}

// UpdateSchedule updates an existing schedule entry
// PUT /api/schedules/:id
func (h *ScheduleHandler) UpdateSchedule(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid schedule id"})
		return
	}

	var req domain.UpdateScheduleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	schedule, err := h.service.UpdateSchedule(id, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, schedule)
}

// DeleteSchedule deletes a schedule entry
// DELETE /api/schedules/:id
func (h *ScheduleHandler) DeleteSchedule(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid schedule id"})
		return
	}

	err = h.service.DeleteSchedule(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "schedule deleted"})
}

// StartScheduledSession marks a schedule as in progress
// POST /api/schedules/:id/start
func (h *ScheduleHandler) StartScheduledSession(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid schedule id"})
		return
	}

	err = h.service.StartScheduledSession(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Return updated schedule
	schedule, err := h.service.GetSchedule(id)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"message": "session started"})
		return
	}

	c.JSON(http.StatusOK, schedule)
}

// CompleteScheduledSession marks a schedule as completed
// POST /api/schedules/:id/complete
func (h *ScheduleHandler) CompleteScheduledSession(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid schedule id"})
		return
	}

	err = h.service.CompleteScheduledSession(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Return updated schedule
	schedule, err := h.service.GetSchedule(id)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"message": "session completed"})
		return
	}

	c.JSON(http.StatusOK, schedule)
}

// CancelSchedule cancels a scheduled shift
// POST /api/schedules/:id/cancel
func (h *ScheduleHandler) CancelSchedule(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid schedule id"})
		return
	}

	err = h.service.CancelSchedule(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "schedule cancelled"})
}
