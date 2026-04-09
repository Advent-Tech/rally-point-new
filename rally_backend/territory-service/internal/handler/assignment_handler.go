package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// AssignmentHandler handles territory assignment HTTP requests
type AssignmentHandler struct {
	service domain.TerritoryAssignmentService
}

// NewAssignmentHandler creates a new assignment handler
func NewAssignmentHandler(service domain.TerritoryAssignmentService) *AssignmentHandler {
	return &AssignmentHandler{service: service}
}

// CreateAssignment creates a new territory assignment
// POST /api/geo/assignments
func (h *AssignmentHandler) CreateAssignment(c *gin.Context) {
	var req domain.CreateAssignmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	assignment, err := h.service.AssignTerritory(&req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, assignment)
}

// GetAssignment retrieves an assignment by ID
// GET /api/geo/assignments/:id
func (h *AssignmentHandler) GetAssignment(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid assignment ID"})
		return
	}

	assignment, err := h.service.GetAssignment(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "assignment not found"})
		return
	}

	c.JSON(http.StatusOK, assignment)
}

// ListAssignments retrieves assignments with filters
// GET /api/geo/assignments?team_id=...&worker_id=...&status=...
func (h *AssignmentHandler) ListAssignments(c *gin.Context) {
	teamIDStr := c.Query("team_id")
	workerIDStr := c.Query("worker_id")
	status := c.Query("status")

	if teamIDStr != "" {
		teamID, err := uuid.Parse(teamIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team_id"})
			return
		}

		assignments, err := h.service.GetTeamAssignments(teamID, status)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"assignments": assignments,
			"count":       len(assignments),
		})
		return
	}

	if workerIDStr != "" {
		workerID, err := uuid.Parse(workerIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
			return
		}

		assignments, err := h.service.GetWorkerAssignments(workerID, status)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"assignments": assignments,
			"count":       len(assignments),
		})
		return
	}

	c.JSON(http.StatusBadRequest, gin.H{"error": "team_id or worker_id is required"})
}

// UpdateAssignment updates an assignment
// PUT /api/geo/assignments/:id
func (h *AssignmentHandler) UpdateAssignment(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid assignment ID"})
		return
	}

	var req domain.UpdateAssignmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.service.UpdateAssignment(id, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "assignment updated"})
}

// DeleteAssignment deletes an assignment
// DELETE /api/geo/assignments/:id
func (h *AssignmentHandler) DeleteAssignment(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid assignment ID"})
		return
	}

	err = h.service.UnassignTerritory(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "assignment deleted"})
}

// GetWorkerTerritoriesGeoJSON returns worker's assigned territories as GeoJSON
// GET /api/geo/assignments/worker/:id/geojson
func (h *AssignmentHandler) GetWorkerTerritoriesGeoJSON(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	geojson, err := h.service.GetWorkerTerritoriesGeoJSON(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, geojson)
}

// GetTeamTerritoriesGeoJSON returns team's assigned territories as GeoJSON
// GET /api/geo/assignments/team/:id/geojson
func (h *AssignmentHandler) GetTeamTerritoriesGeoJSON(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	geojson, err := h.service.GetTeamTerritoriesGeoJSON(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, geojson)
}

// RecordVisit records a visit to a territory
// POST /api/geo/assignments/:id/visit
func (h *AssignmentHandler) RecordVisit(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid assignment ID"})
		return
	}

	err = h.service.RecordTerritoryVisit(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "visit recorded"})
}

// RecordVisitByTerritoryWorker records a visit using territory_id and worker_id
// POST /api/geo/assignments/record-visit
// Body: { "territory_id": "uuid", "worker_id": "uuid" }
func (h *AssignmentHandler) RecordVisitByTerritoryWorker(c *gin.Context) {
	var req struct {
		TerritoryID uuid.UUID `json:"territory_id" binding:"required"`
		WorkerID    uuid.UUID `json:"worker_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.service.RecordTerritoryVisitByWorker(req.TerritoryID, req.WorkerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "visit recorded"})
}

// RegisterRoutes registers the assignment routes
func (h *AssignmentHandler) RegisterRoutes(router *gin.RouterGroup) {
	assignments := router.Group("/geo/assignments")
	{
		assignments.POST("", h.CreateAssignment)
		assignments.GET("", h.ListAssignments)
		assignments.GET("/:id", h.GetAssignment)
		assignments.PUT("/:id", h.UpdateAssignment)
		assignments.DELETE("/:id", h.DeleteAssignment)
		assignments.POST("/:id/visit", h.RecordVisit)
		assignments.POST("/record-visit", h.RecordVisitByTerritoryWorker)

		// GeoJSON endpoints
		assignments.GET("/worker/:id/geojson", h.GetWorkerTerritoriesGeoJSON)
		assignments.GET("/team/:id/geojson", h.GetTeamTerritoriesGeoJSON)
	}
}
