package handler

import (
	"net/http"

	"rally-point/user-service/internal/domain"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type AdminHandler struct {
	adminService domain.AdminService
}

// NewAdminHandler creates a new admin handler
func NewAdminHandler(adminService domain.AdminService) *AdminHandler {
	return &AdminHandler{
		adminService: adminService,
	}
}

// ListTeamLeaders handles listing team leaders with optional status filter
// GET /api/admin/team-leaders?status=pending|verified|rejected
func (h *AdminHandler) ListTeamLeaders(c *gin.Context) {
	status := c.Query("status")

	response, err := h.adminService.GetTeamLeaders(status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// GetTeamLeader handles getting a specific team leader
// GET /api/admin/team-leaders/:id
func (h *AdminHandler) GetTeamLeader(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team leader ID"})
		return
	}

	leader, err := h.adminService.GetTeamLeaderByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, leader)
}

// VerifyTeamLeader handles team leader verification
// PUT /api/admin/team-leaders/:id/verify
func (h *AdminHandler) VerifyTeamLeader(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team leader ID"})
		return
	}

	// Get admin ID from context
	adminIDStr := c.GetString("user_id")
	adminID, err := uuid.Parse(adminIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid admin ID"})
		return
	}

	err = h.adminService.VerifyTeamLeader(id, adminID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Team leader verified successfully"})
}

// RejectTeamLeader handles team leader rejection
// PUT /api/admin/team-leaders/:id/reject
func (h *AdminHandler) RejectTeamLeader(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team leader ID"})
		return
	}

	// Get admin ID from context
	adminIDStr := c.GetString("user_id")
	adminID, err := uuid.Parse(adminIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid admin ID"})
		return
	}

	var req struct {
		Reason string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.adminService.RejectTeamLeader(id, adminID, req.Reason)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Team leader rejected"})
}

// CreateTeam handles admin team creation
// POST /api/admin/teams
func (h *AdminHandler) CreateTeam(c *gin.Context) {
	var req domain.AdminCreateTeamRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	team, err := h.adminService.CreateTeam(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Team created successfully",
		"team":    team,
	})
}

// AssignTeamToLeader handles assigning a team to a leader
// PUT /api/admin/teams/:id/assign-leader
func (h *AdminHandler) AssignTeamToLeader(c *gin.Context) {
	teamIDStr := c.Param("id")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	var req domain.AssignTeamLeaderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.adminService.AssignTeamToLeader(teamID, req.LeaderID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Team assigned to leader successfully"})
}

// UnassignTeamFromLeader handles removing a leader from a team
// DELETE /api/admin/teams/:id/leader
func (h *AdminHandler) UnassignTeamFromLeader(c *gin.Context) {
	teamIDStr := c.Param("id")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	err = h.adminService.UnassignTeamFromLeader(teamID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Team unassigned from leader successfully"})
}

// ListPendingWorkers handles listing pending workers
// GET /api/admin/workers/pending
func (h *AdminHandler) ListPendingWorkers(c *gin.Context) {
	workers, err := h.adminService.GetPendingWorkers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"workers": workers,
		"count":   len(workers),
	})
}

// ListVerifiedWorkers handles listing verified workers
// GET /api/admin/workers/verified
func (h *AdminHandler) ListVerifiedWorkers(c *gin.Context) {
	workers, err := h.adminService.GetVerifiedWorkers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"workers": workers,
		"count":   len(workers),
	})
}

// VerifyWorker handles worker verification by admin
// PUT /api/admin/workers/:id/verify
func (h *AdminHandler) VerifyWorker(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	adminIDStr := c.GetString("user_id")
	adminID, err := uuid.Parse(adminIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid admin ID"})
		return
	}

	err = h.adminService.VerifyWorker(id, adminID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Worker verified successfully"})
}

// RejectWorker handles worker rejection by admin
// PUT /api/admin/workers/:id/reject
func (h *AdminHandler) RejectWorker(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	adminIDStr := c.GetString("user_id")
	adminID, err := uuid.Parse(adminIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid admin ID"})
		return
	}

	var req struct {
		Reason string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.adminService.RejectWorker(id, adminID, req.Reason)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Worker rejected"})
}

// AdminMiddleware ensures only admin or superadmin can access certain routes
func AdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("user_role")
		if role != domain.RoleAdmin && role != domain.RoleSuperAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "admin access required"})
			c.Abort()
			return
		}
		c.Next()
	}
}
