package handler

import (
	"net/http"
	"rally-point/user-service/internal/domain"
	"rally-point/user-service/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type TeamInvitationHandler struct {
	invitationService *service.TeamInvitationService
}

func NewTeamInvitationHandler(invitationService *service.TeamInvitationService) *TeamInvitationHandler {
	return &TeamInvitationHandler{
		invitationService: invitationService,
	}
}

// SendInvitation handles sending a team invitation
// POST /api/teams/:id/invitations
func (h *TeamInvitationHandler) SendInvitation(c *gin.Context) {
	// Get team ID from path
	teamIDStr := c.Param("id")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid team ID"})
		return
	}

	// Get inviter ID from auth context
	userIDStr, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	inviterID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user ID"})
		return
	}

	// Parse request body
	var req domain.SendInvitationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: email is required"})
		return
	}

	// Send invitation
	invitation, err := h.invitationService.SendInvitation(teamID, inviterID, req.Email)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, domain.SendInvitationResponse{
		Message:    "Invitation sent successfully",
		Invitation: invitation,
	})
}

// GetTeamInvitations returns all invitations for a team
// GET /api/teams/:id/invitations
func (h *TeamInvitationHandler) GetTeamInvitations(c *gin.Context) {
	// Get team ID from path
	teamIDStr := c.Param("id")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid team ID"})
		return
	}

	invitations, err := h.invitationService.GetTeamInvitations(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get invitations"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"invitations": invitations,
	})
}

// GetInvitationInfo returns information about an invitation
// GET /api/invitations/info?token=xxx
func (h *TeamInvitationHandler) GetInvitationInfo(c *gin.Context) {
	token := c.Query("token")
	if token == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"valid":   false,
			"message": "Invitation token is required",
		})
		return
	}

	info, err := h.invitationService.GetInvitationInfo(token)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"valid":   false,
			"message": "Invalid invitation",
		})
		return
	}

	c.JSON(http.StatusOK, info)
}

// AcceptInvitation accepts a team invitation for an authenticated user
// POST /api/invitations/accept
func (h *TeamInvitationHandler) AcceptInvitation(c *gin.Context) {
	// Get user from auth context
	userIDStr, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user ID"})
		return
	}

	// Parse request body
	var req domain.AcceptInvitationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Token is required"})
		return
	}

	// Accept invitation
	if err := h.invitationService.AcceptInvitation(req.Token, userID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Invitation accepted successfully. You are now a member of the team.",
	})
}

// DeclineInvitation declines a team invitation
// POST /api/invitations/decline
func (h *TeamInvitationHandler) DeclineInvitation(c *gin.Context) {
	var req domain.AcceptInvitationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Token is required"})
		return
	}

	if err := h.invitationService.DeclineInvitation(req.Token); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Invitation declined",
	})
}

// CancelInvitation cancels a pending invitation
// DELETE /api/teams/:id/invitations/:invitationId
func (h *TeamInvitationHandler) CancelInvitation(c *gin.Context) {
	// Get invitation ID from path
	invitationIDStr := c.Param("invitationId")
	invitationID, err := uuid.Parse(invitationIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid invitation ID"})
		return
	}

	// Get user from auth context
	userIDStr, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user ID"})
		return
	}

	if err := h.invitationService.CancelInvitation(invitationID, userID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Invitation cancelled",
	})
}

// ResendInvitation resends an invitation email
// POST /api/teams/:id/invitations/:invitationId/resend
func (h *TeamInvitationHandler) ResendInvitation(c *gin.Context) {
	// Get invitation ID from path
	invitationIDStr := c.Param("invitationId")
	invitationID, err := uuid.Parse(invitationIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid invitation ID"})
		return
	}

	// Get user from auth context
	userIDStr, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user ID"})
		return
	}

	if err := h.invitationService.ResendInvitation(invitationID, userID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Invitation resent successfully",
	})
}
