package domain

import (
	"time"

	"github.com/google/uuid"
)

// InvitationStatus represents the status of a team invitation
type InvitationStatus string

const (
	InvitationStatusPending  InvitationStatus = "pending"
	InvitationStatusAccepted InvitationStatus = "accepted"
	InvitationStatusDeclined InvitationStatus = "declined"
	InvitationStatusExpired  InvitationStatus = "expired"
)

// TeamInvitation represents an invitation to join a team
type TeamInvitation struct {
	ID           uuid.UUID        `json:"id"`
	TeamID       uuid.UUID        `json:"team_id"`
	TeamName     string           `json:"team_name,omitempty"`
	InviterID    uuid.UUID        `json:"inviter_id"`
	InviterName  string           `json:"inviter_name,omitempty"`
	InviteeEmail string           `json:"invitee_email"`
	InviteeID    *uuid.UUID       `json:"invitee_id,omitempty"` // Set when user registers/accepts
	TokenHash    string           `json:"-"`                    // SHA256 hash of the token
	Status       InvitationStatus `json:"status"`
	ExpiresAt    time.Time        `json:"expires_at"`
	AcceptedAt   *time.Time       `json:"accepted_at,omitempty"`
	CreatedAt    time.Time        `json:"created_at"`
	UpdatedAt    time.Time        `json:"updated_at"`
}

// IsExpired returns true if the invitation has expired
func (i *TeamInvitation) IsExpired() bool {
	return time.Now().After(i.ExpiresAt)
}

// IsPending returns true if the invitation is still pending
func (i *TeamInvitation) IsPending() bool {
	return i.Status == InvitationStatusPending && !i.IsExpired()
}

// SendInvitationRequest is the request to send a team invitation
type SendInvitationRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// SendInvitationResponse is the response after sending an invitation
type SendInvitationResponse struct {
	Message    string          `json:"message"`
	Invitation *TeamInvitation `json:"invitation,omitempty"`
}

// AcceptInvitationRequest is the request to accept a team invitation
type AcceptInvitationRequest struct {
	Token string `json:"token" binding:"required"`
}

// InvitationInfoResponse provides info about an invitation for registration
type InvitationInfoResponse struct {
	Valid     bool   `json:"valid"`
	TeamID    string `json:"team_id,omitempty"`
	TeamName  string `json:"team_name,omitempty"`
	Email     string `json:"email,omitempty"`
	InviterName string `json:"inviter_name,omitempty"`
	ExpiresAt string `json:"expires_at,omitempty"`
	Message   string `json:"message,omitempty"`
}

// TeamInvitationRepository defines the interface for team invitation storage
type TeamInvitationRepository interface {
	// Create creates a new invitation and invalidates any existing pending invitations for the same email/team
	Create(invitation *TeamInvitation) error

	// GetByTokenHash finds an invitation by its token hash
	GetByTokenHash(tokenHash string) (*TeamInvitation, error)

	// GetByID finds an invitation by its ID
	GetByID(id uuid.UUID) (*TeamInvitation, error)

	// GetByEmail finds all invitations for an email
	GetByEmail(email string) ([]*TeamInvitation, error)

	// GetPendingByEmailAndTeam finds a pending invitation for a specific email and team
	GetPendingByEmailAndTeam(email string, teamID uuid.UUID) (*TeamInvitation, error)

	// GetByTeamID finds all invitations for a team
	GetByTeamID(teamID uuid.UUID) ([]*TeamInvitation, error)

	// UpdateStatus updates the status of an invitation
	UpdateStatus(id uuid.UUID, status InvitationStatus, inviteeID *uuid.UUID) error

	// DeleteExpired removes expired invitations
	DeleteExpired() error

	// InvalidatePendingForEmailAndTeam invalidates existing pending invitations
	InvalidatePendingForEmailAndTeam(email string, teamID uuid.UUID) error
}

// TeamInvitationService defines the service interface for team invitations
type TeamInvitationService interface {
	// SendInvitation sends an invitation email to join a team
	SendInvitation(teamID, inviterID uuid.UUID, email string) (*TeamInvitation, error)

	// GetInvitationInfo gets information about an invitation by token (for registration page)
	GetInvitationInfo(token string) (*InvitationInfoResponse, error)

	// AcceptInvitation accepts an invitation and adds user to team
	AcceptInvitation(token string, userID uuid.UUID) error

	// DeclineInvitation declines an invitation
	DeclineInvitation(token string) error

	// GetTeamInvitations gets all invitations for a team
	GetTeamInvitations(teamID uuid.UUID) ([]*TeamInvitation, error)

	// ResendInvitation resends an existing invitation
	ResendInvitation(invitationID, inviterID uuid.UUID) error

	// CancelInvitation cancels a pending invitation
	CancelInvitation(invitationID, inviterID uuid.UUID) error
}
