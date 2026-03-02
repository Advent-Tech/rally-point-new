package handler

import (
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/delivery-service/internal/domain"
	"rally-point/delivery-service/internal/service"
)

type TargetHandler struct {
	targetService *service.TargetService
}

func NewTargetHandler(targetService *service.TargetService) *TargetHandler {
	return &TargetHandler{
		targetService: targetService,
	}
}

type CreateTargetRequest struct {
	Name        string  `json:"name" binding:"required"`
	Description string  `json:"description"`
	TargetType  string  `json:"target_type" binding:"required"`
	TargetUnit  string  `json:"target_unit" binding:"required"`
	TargetValue float64 `json:"target_value" binding:"required"`
	PeriodType  string  `json:"period_type" binding:"required"`
}

type AssignTargetRequest struct {
	WorkerID    *string    `json:"worker_id"`
	TeamID      *string    `json:"team_id"`
	PeriodStart *time.Time `json:"period_start"`
	PeriodEnd   *time.Time `json:"period_end"`
}

func (h *TargetHandler) CreateTarget(c *gin.Context) {
	userID := c.GetString("user_id")
	role := c.GetString("user_role")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	creatorID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req CreateTargetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	target := &domain.Target{
		Name:          req.Name,
		Description:   req.Description,
		TargetType:    domain.TargetType(req.TargetType),
		TargetUnit:    domain.TargetUnit(req.TargetUnit),
		TargetValue:   req.TargetValue,
		PeriodType:    domain.PeriodType(req.PeriodType),
		CreatedBy:     creatorID,
		CreatedByRole: role,
	}

	err = h.targetService.CreateTarget(c, target)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, target)
}

func (h *TargetHandler) GetTargets(c *gin.Context) {
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

	targets, err := h.targetService.GetTargetsByCreator(c, creatorID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, targets)
}

func (h *TargetHandler) GetTargetByID(c *gin.Context) {
	id := c.Param("id")
	targetID, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid target ID"})
		return
	}

	target, err := h.targetService.GetTargetByID(c, targetID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if target == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "target not found"})
		return
	}

	c.JSON(http.StatusOK, target)
}

func (h *TargetHandler) UpdateTarget(c *gin.Context) {
	id := c.Param("id")
	targetID, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid target ID"})
		return
	}

	var req CreateTargetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	target := &domain.Target{
		ID:          targetID,
		Name:        req.Name,
		Description: req.Description,
		TargetType:  domain.TargetType(req.TargetType),
		TargetUnit:  domain.TargetUnit(req.TargetUnit),
		TargetValue: req.TargetValue,
		PeriodType:  domain.PeriodType(req.PeriodType),
	}

	err = h.targetService.UpdateTarget(c, target)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "target updated"})
}

func (h *TargetHandler) DeleteTarget(c *gin.Context) {
	id := c.Param("id")
	targetID, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid target ID"})
		return
	}

	err = h.targetService.DeleteTarget(c, targetID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "target deleted"})
}

func (h *TargetHandler) AssignTargetToWorker(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid target ID"})
		return
	}

	userID := c.GetString("user_id")
	assignedBy, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req AssignTargetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.WorkerID == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "worker_id is required"})
		return
	}

	workerID, err := uuid.Parse(*req.WorkerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	err = h.targetService.AssignTargetToWorker(c, targetID, workerID, assignedBy, req.PeriodStart, req.PeriodEnd)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "target assigned to worker"})
}

func (h *TargetHandler) AssignTargetToTeam(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid target ID"})
		return
	}

	userID := c.GetString("user_id")
	assignedBy, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req AssignTargetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.TeamID == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "team_id is required"})
		return
	}

	teamID, err := uuid.Parse(*req.TeamID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team_id"})
		return
	}

	err = h.targetService.AssignTargetToTeam(c, targetID, teamID, assignedBy, req.PeriodStart, req.PeriodEnd)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "target assigned to team"})
}

func (h *TargetHandler) GetWorkerTargets(c *gin.Context) {
	userID := c.GetString("user_id")
	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	// Debug: log team_id
	log.Printf("DEBUG: user_id=%s, team_id from claims=%s, team_id from query=%s",
		userID, c.GetString("team_id"), c.Query("team_id"))

	// Get worker's targets (directly assigned)
	targets, err := h.targetService.GetWorkerTargets(c, workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Also get team targets if worker has a team
	// Try to get team_id from JWT claims first, then from query params
	teamIDStr := c.GetString("team_id")
	if teamIDStr == "" {
		teamIDStr = c.Query("team_id")
	}

	// Hardcoded for testing - REMOVE THIS AFTER TESTING
	if teamIDStr == "" {
		teamIDStr = "8b17e5c6-2d2d-4dee-ab05-4c39dcf9e5fc"
	}

	log.Printf("DEBUG: teamIDStr=%s", teamIDStr)

	if teamIDStr != "" {
		teamID, err := uuid.Parse(teamIDStr)
		if err == nil {
			teamTargets, err := h.targetService.GetTeamTargets(c, teamID)
			if err == nil {
				// Combine worker targets and team targets
				targets = append(targets, teamTargets...)
			}
		}
	}

	c.JSON(http.StatusOK, targets)
}

func (h *TargetHandler) GetTeamTargets(c *gin.Context) {
	teamIDStr := c.Query("team_id")
	if teamIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "team_id is required"})
		return
	}

	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team_id"})
		return
	}

	targets, err := h.targetService.GetTeamTargets(c, teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, targets)
}

func (h *TargetHandler) DeleteAssignment(c *gin.Context) {
	id := c.Param("id")
	assignmentID, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid assignment ID"})
		return
	}

	err = h.targetService.DeleteAssignment(c, assignmentID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "assignment deleted"})
}
