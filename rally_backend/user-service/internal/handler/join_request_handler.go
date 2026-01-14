package handler

import (
	"net/http"

	"rally-point/user-service/internal/domain"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type JoinRequestHandler struct {
	joinRequestService domain.JoinRequestService
	teamService        domain.TeamService
}

// NewJoinRequestHandler creates a new join request handler
func NewJoinRequestHandler(joinRequestService domain.JoinRequestService, teamService domain.TeamService) *JoinRequestHandler {
	return &JoinRequestHandler{
		joinRequestService: joinRequestService,
		teamService:        teamService,
	}
}

// RequestJoinTeam handles worker's request to join a team
// POST /api/teams/:id/request-join
func (h *JoinRequestHandler) RequestJoinTeam(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	teamIDStr := c.Param("id")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	var req struct {
		Message string `json:"message,omitempty"`
	}
	c.ShouldBindJSON(&req)

	createReq := &domain.CreateJoinRequestRequest{
		TeamID:  teamID,
		Message: req.Message,
	}

	request, err := h.joinRequestService.CreateRequest(userID, createReq)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Join request submitted successfully",
		"request": request,
	})
}

// GetMyJoinRequest retrieves the current user's pending join request
// GET /api/teams/my-request
func (h *JoinRequestHandler) GetMyJoinRequest(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	request, err := h.joinRequestService.GetUserPendingRequest(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if request == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "no pending join request"})
		return
	}

	c.JSON(http.StatusOK, request)
}

// GetMyJoinRequests retrieves all join requests for the current user
// GET /api/teams/my-requests
func (h *JoinRequestHandler) GetMyJoinRequests(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	requests, err := h.joinRequestService.GetUserRequests(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"requests": requests,
		"count":    len(requests),
	})
}

// CancelMyJoinRequest cancels the current user's pending join request
// DELETE /api/teams/my-request
func (h *JoinRequestHandler) CancelMyJoinRequest(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	// Get the pending request first
	request, err := h.joinRequestService.GetUserPendingRequest(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if request == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "no pending join request to cancel"})
		return
	}

	err = h.joinRequestService.CancelRequest(request.ID, userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Join request cancelled"})
}

// GetTeamJoinRequests retrieves all join requests for a team (team leader only)
// GET /api/teams/:id/join-requests
func (h *JoinRequestHandler) GetTeamJoinRequests(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	teamIDStr := c.Param("id")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	// Verify user is the team leader or admin
	team, err := h.teamService.GetTeam(teamID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "team not found"})
		return
	}

	userRole := c.GetString("user_role")
	if team.LeaderID != userID && userRole != domain.RoleAdmin && userRole != domain.RoleSuperAdmin {
		c.JSON(http.StatusForbidden, gin.H{"error": "only team leader can view join requests"})
		return
	}

	// Get pending only by default
	status := c.DefaultQuery("status", "pending")
	var requests []*domain.TeamJoinRequest

	if status == "pending" {
		requests, err = h.joinRequestService.GetPendingTeamRequests(teamID)
	} else {
		requests, err = h.joinRequestService.GetTeamRequests(teamID)
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"requests": requests,
		"count":    len(requests),
	})
}

// ApproveJoinRequest approves a join request (team leader only)
// PUT /api/teams/join-requests/:id/approve
func (h *JoinRequestHandler) ApproveJoinRequest(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	requestIDStr := c.Param("id")
	requestID, err := uuid.Parse(requestIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request ID"})
		return
	}

	err = h.joinRequestService.ApproveRequest(requestID, userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Join request approved"})
}

// RejectJoinRequest rejects a join request (team leader only)
// PUT /api/teams/join-requests/:id/reject
func (h *JoinRequestHandler) RejectJoinRequest(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	requestIDStr := c.Param("id")
	requestID, err := uuid.Parse(requestIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request ID"})
		return
	}

	var req struct {
		Reason string `json:"reason,omitempty"`
	}
	c.ShouldBindJSON(&req)

	err = h.joinRequestService.RejectRequest(requestID, userID, req.Reason)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Join request rejected"})
}

// TeamLeaderMiddleware ensures only team leaders can access certain routes
func TeamLeaderMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("user_role")
		if role != domain.RoleTeamLeader && role != domain.RoleAdmin && role != domain.RoleSuperAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "team leader access required"})
			c.Abort()
			return
		}
		c.Next()
	}
}
