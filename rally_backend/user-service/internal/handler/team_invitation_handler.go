package handler

import (
	"fmt"
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
	userIDStr := c.GetString("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	inviterID, err := uuid.Parse(userIDStr)
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

// JoinInvitationLanding renders a browser page for worker invitation links
// GET /api/invitations/join/:token
func (h *TeamInvitationHandler) JoinInvitationLanding(c *gin.Context) {
	token := c.Param("token")
	if token == "" {
		c.Data(http.StatusBadRequest, "text/html; charset=utf-8", []byte(renderInvitationLanding(false, "", "", "", token, "Invitation token is required")))
		return
	}

	info, err := h.invitationService.GetInvitationInfo(token)
	if err != nil || info == nil || !info.Valid {
		msg := "Invalid or expired invitation link"
		if info != nil && info.Message != "" {
			msg = info.Message
		}
		c.Data(http.StatusBadRequest, "text/html; charset=utf-8", []byte(renderInvitationLanding(false, "", "", "", token, msg)))
		return
	}

	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(renderInvitationLanding(true, info.TeamName, info.InviterName, info.Email, token, "")))
}

// AcceptInvitation accepts a team invitation for an authenticated user
// POST /api/invitations/accept
func (h *TeamInvitationHandler) AcceptInvitation(c *gin.Context) {
	// Get user from auth context
	userIDStr := c.GetString("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, err := uuid.Parse(userIDStr)
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
	userIDStr := c.GetString("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, err := uuid.Parse(userIDStr)
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
	userIDStr := c.GetString("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, err := uuid.Parse(userIDStr)
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

func renderInvitationLanding(valid bool, teamName, inviterName, email, token, errorMessage string) string {
	if !valid {
		return fmt.Sprintf(`<!doctype html>
<html><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>light point - Team Invitation</title>
<style>
body{margin:0;background:#F8FAFC;color:#0F172A;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif}
.wrap{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
.card{width:100%%;max-width:520px;background:#fff;border:1px solid #E2E8F0;border-radius:16px;padding:26px;box-shadow:0 8px 30px rgba(15,23,42,.08)}
h1{margin:0 0 12px;font-size:28px}.title{font-size:22px;font-weight:700;color:#DC2626;margin:0 0 10px}
.msg{font-size:16px;line-height:1.45}
</style></head><body><div class="wrap"><div class="card">
<h1>light point</h1><div class="title">Invitation Invalid</div><div class="msg">%s</div>
</div></div></body></html>`, errorMessage)
	}

	deepLink := fmt.Sprintf("rallypoint://join-team?token=%s", token)
	return fmt.Sprintf(`<!doctype html>
<html><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>light point - Team Invitation</title>
<style>
body{margin:0;background:#F8FAFC;color:#0F172A;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif}
.wrap{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
.card{width:100%%;max-width:560px;background:#fff;border:1px solid #E2E8F0;border-radius:16px;padding:26px;box-shadow:0 8px 30px rgba(15,23,42,.08)}
h1{margin:0 0 10px;font-size:28px}.title{font-size:22px;font-weight:700;margin:0 0 10px}
.meta{font-size:15px;color:#334155;line-height:1.5;margin-bottom:14px}
.btn{display:inline-block;background:#7C3AED;color:#fff !important;text-decoration:none;padding:13px 24px;border-radius:10px;font-weight:700}
.note{margin-top:14px;padding:12px;border:1px solid #E2E8F0;background:#F8FAFC;border-radius:10px;font-size:14px;color:#475569}
.token{font-family:ui-monospace,Menlo,monospace;word-break:break-all;font-size:12px;color:#334155}
</style></head><body><div class="wrap"><div class="card">
<h1>light point</h1><div class="title">You are invited to join a team</div>
<div class="meta"><strong>Team:</strong> %s<br/><strong>Invited by:</strong> %s<br/><strong>Email:</strong> %s</div>
<a class="btn" href="%s">Open in light point app</a>
<div class="note">
If the app does not open, install/open the worker app and use the same invited email.<br/>
Invitation token:<div class="token">%s</div>
</div>
</div></div></body></html>`, teamName, inviterName, email, deepLink, token)
}
