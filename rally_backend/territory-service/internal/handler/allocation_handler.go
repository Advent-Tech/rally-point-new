package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

type AllocationHandler struct {
	allocationService domain.LeaderTerritoryAllocationService
}

// NewAllocationHandler creates a new allocation handler
func NewAllocationHandler(allocationService domain.LeaderTerritoryAllocationService) *AllocationHandler {
	return &AllocationHandler{
		allocationService: allocationService,
	}
}

// AllocateTerritory allocates a territory to a leader (admin only)
// POST /api/admin/territories/allocate
func (h *AllocationHandler) AllocateTerritory(c *gin.Context) {
	var req domain.CreateAllocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set allocated_by from context
	adminIDStr := c.GetString("user_id")
	adminID, err := uuid.Parse(adminIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid admin ID"})
		return
	}
	req.AllocatedBy = adminID

	allocation, err := h.allocationService.AllocateTerritory(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message":    "Territory allocated successfully",
		"allocation": allocation,
	})
}

// AllocateTerritories allocates multiple territories to a leader (admin only)
// POST /api/admin/territories/allocate-bulk
func (h *AllocationHandler) AllocateTerritories(c *gin.Context) {
	var req domain.BulkAllocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set allocated_by from context
	adminIDStr := c.GetString("user_id")
	adminID, err := uuid.Parse(adminIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid admin ID"})
		return
	}
	req.AllocatedBy = adminID

	allocations, err := h.allocationService.AllocateTerritories(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message":     "Territories allocated successfully",
		"allocations": allocations,
		"count":       len(allocations),
	})
}

// RevokeAllocation revokes a territory allocation (admin only)
// DELETE /api/admin/territories/allocations/:id
func (h *AllocationHandler) RevokeAllocation(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid allocation ID"})
		return
	}

	err = h.allocationService.RevokeAllocation(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Territory allocation revoked"})
}

// GetAllocation retrieves an allocation by ID
// GET /api/admin/territories/allocations/:id
func (h *AllocationHandler) GetAllocation(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid allocation ID"})
		return
	}

	allocation, err := h.allocationService.GetAllocation(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, allocation)
}

// ListAllAllocations lists all allocations (admin only)
// GET /api/admin/territories/allocations?status=active&limit=50&offset=0
func (h *AllocationHandler) ListAllAllocations(c *gin.Context) {
	status := c.Query("status")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	allocations, total, err := h.allocationService.GetAllAllocations(status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"allocations": allocations,
		"total":       total,
		"limit":       limit,
		"offset":      offset,
	})
}

// GetLeaderAllocations retrieves allocations for a specific leader
// GET /api/admin/territories/allocations/leader/:leaderId
func (h *AllocationHandler) GetLeaderAllocations(c *gin.Context) {
	leaderIDStr := c.Param("leaderId")
	leaderID, err := uuid.Parse(leaderIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid leader ID"})
		return
	}

	status := c.Query("status")

	allocations, err := h.allocationService.GetLeaderAllocations(leaderID, status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"allocations": allocations,
		"count":       len(allocations),
	})
}

// GetMyAllocations retrieves allocations for the current leader
// GET /api/territories/my-allocations
func (h *AllocationHandler) GetMyAllocations(c *gin.Context) {
	leaderIDStr := c.GetString("user_id")
	leaderID, err := uuid.Parse(leaderIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	status := c.DefaultQuery("status", "active")

	allocations, err := h.allocationService.GetLeaderAllocations(leaderID, status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"allocations": allocations,
		"count":       len(allocations),
	})
}

// GetMyAllocationsGeoJSON retrieves leader's allocations as GeoJSON
// GET /api/territories/my-allocations/geojson
func (h *AllocationHandler) GetMyAllocationsGeoJSON(c *gin.Context) {
	leaderIDStr := c.GetString("user_id")
	leaderID, err := uuid.Parse(leaderIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	geojson, err := h.allocationService.GetLeaderAllocationsGeoJSON(leaderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, geojson)
}

// GetMyAllocationStats retrieves allocation statistics for the current leader
// GET /api/territories/my-allocations/stats
func (h *AllocationHandler) GetMyAllocationStats(c *gin.Context) {
	leaderIDStr := c.GetString("user_id")
	leaderID, err := uuid.Parse(leaderIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	stats, err := h.allocationService.GetLeaderAllocationStats(leaderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// CheckCanAssign checks if the leader can assign a territory to a worker
// GET /api/territories/can-assign/:territoryId
func (h *AllocationHandler) CheckCanAssign(c *gin.Context) {
	leaderIDStr := c.GetString("user_id")
	leaderID, err := uuid.Parse(leaderIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	territoryIDStr := c.Param("territoryId")
	territoryID, err := uuid.Parse(territoryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	canAssign, err := h.allocationService.CanLeaderAssignTerritory(leaderID, territoryID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"can_assign":   canAssign,
		"leader_id":    leaderID,
		"territory_id": territoryID,
	})
}
