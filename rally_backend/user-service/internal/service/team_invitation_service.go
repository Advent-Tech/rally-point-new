package service

import (
	"fmt"
	"log"
	"os"
	"rally-point/user-service/internal/domain"
	"rally-point/user-service/internal/email"
	"time"

	"github.com/google/uuid"
	"github.com/rally-point/shared/utils"
)

const (
	// InvitationExpiryDays is the number of days an invitation is valid
	InvitationExpiryDays = 7
	// InvitationTokenLength is the length of the invitation token in bytes
	InvitationTokenLength = 32
)

type TeamInvitationService struct {
	invitationRepo domain.TeamInvitationRepository
	teamRepo       domain.TeamRepository
	userRepo       domain.UserRepository
	emailClient    *email.EmailClient
	emailTemplates *email.EmailTemplates
}

func NewTeamInvitationService(
	invitationRepo domain.TeamInvitationRepository,
	teamRepo domain.TeamRepository,
	userRepo domain.UserRepository,
) *TeamInvitationService {
	return &TeamInvitationService{
		invitationRepo: invitationRepo,
		teamRepo:       teamRepo,
		userRepo:       userRepo,
		emailClient:    email.NewEmailClient(),
		emailTemplates: email.NewEmailTemplates(),
	}
}

// SendInvitation sends an invitation email to join a team
func (s *TeamInvitationService) SendInvitation(teamID, inviterID uuid.UUID, inviteeEmail string) (*domain.TeamInvitation, error) {
	// Get team info
	team, err := s.teamRepo.GetByID(teamID)
	if err != nil {
		return nil, fmt.Errorf("team not found: %w", err)
	}

	// Verify inviter is the team leader
	if team.LeaderID != inviterID {
		return nil, fmt.Errorf("only team leader can send invitations")
	}

	// Get inviter info
	inviter, err := s.userRepo.GetByID(inviterID)
	if err != nil {
		return nil, fmt.Errorf("inviter not found: %w", err)
	}

	// Check if user already exists and is already in the team
	existingUser, err := s.userRepo.GetByEmail(inviteeEmail)
	if err == nil && existingUser != nil {
		if existingUser.TeamID != nil && *existingUser.TeamID == teamID {
			return nil, fmt.Errorf("user is already a member of this team")
		}
	}

	// Invalidate any existing pending invitations for this email/team combo
	if err := s.invitationRepo.InvalidatePendingForEmailAndTeam(inviteeEmail, teamID); err != nil {
		log.Printf("Warning: failed to invalidate pending invitations: %v", err)
	}

	// Generate invitation token
	token, err := utils.GenerateSecureToken(InvitationTokenLength)
	if err != nil {
		return nil, fmt.Errorf("failed to generate invitation token: %w", err)
	}

	// Hash the token for storage
	tokenHash := utils.HashSHA256(token)

	// Create invitation
	invitation := &domain.TeamInvitation{
		ID:           uuid.New(),
		TeamID:       teamID,
		TeamName:     team.Name,
		InviterID:    inviterID,
		InviterName:  inviter.DisplayName,
		InviteeEmail: inviteeEmail,
		TokenHash:    tokenHash,
		Status:       domain.InvitationStatusPending,
		ExpiresAt:    time.Now().Add(time.Duration(InvitationExpiryDays) * 24 * time.Hour),
	}

	// Save invitation
	if err := s.invitationRepo.Create(invitation); err != nil {
		return nil, fmt.Errorf("failed to create invitation: %w", err)
	}

	// Send invitation email
	inviterName := inviter.DisplayName
	if inviterName == "" {
		inviterName = inviter.Email
	}

	if err := s.sendInvitationEmail(inviteeEmail, inviterName, team.Name, token); err != nil {
		log.Printf("Warning: failed to send invitation email to %s: %v", inviteeEmail, err)
		// Don't fail the request, invitation is still created
	}

	return invitation, nil
}

// sendInvitationEmail sends the invitation email
func (s *TeamInvitationService) sendInvitationEmail(to, inviterName, teamName, token string) error {
	invitationURL := s.emailTemplates.GetTeamInvitationURL(token)

	data := email.TeamInvitationEmailData{
		InviterName:   inviterName,
		TeamName:      teamName,
		InviteeEmail:  to,
		InvitationURL: invitationURL,
		ExpiryDays:    InvitationExpiryDays,
	}

	htmlBody, textBody, err := s.emailTemplates.GenerateTeamInvitationEmail(data)
	if err != nil {
		return fmt.Errorf("failed to generate email: %w", err)
	}

	// Check if in development mode
	if os.Getenv("DEV_MODE") == "true" || !s.emailClient.IsConfigured() {
		log.Printf("[DEV] Team invitation email to %s:", to)
		log.Printf("[DEV] Invitation URL: %s", invitationURL)
		log.Printf("[DEV] Team: %s, Inviter: %s", teamName, inviterName)
		return nil
	}

	subject := fmt.Sprintf("You've been invited to join %s on Rally Point", teamName)
	return s.emailClient.SendEmail(to, subject, htmlBody, textBody)
}

// GetInvitationInfo gets information about an invitation by token (for registration page)
func (s *TeamInvitationService) GetInvitationInfo(token string) (*domain.InvitationInfoResponse, error) {
	tokenHash := utils.HashSHA256(token)

	invitation, err := s.invitationRepo.GetByTokenHash(tokenHash)
	if err != nil {
		return &domain.InvitationInfoResponse{
			Valid:   false,
			Message: "Invalid or expired invitation link",
		}, nil
	}

	// Check if expired
	if invitation.IsExpired() {
		return &domain.InvitationInfoResponse{
			Valid:   false,
			Message: "This invitation has expired",
		}, nil
	}

	// Check if already used
	if invitation.Status != domain.InvitationStatusPending {
		return &domain.InvitationInfoResponse{
			Valid:   false,
			Message: "This invitation has already been used",
		}, nil
	}

	return &domain.InvitationInfoResponse{
		Valid:       true,
		TeamID:      invitation.TeamID.String(),
		TeamName:    invitation.TeamName,
		Email:       invitation.InviteeEmail,
		InviterName: invitation.InviterName,
		ExpiresAt:   invitation.ExpiresAt.Format(time.RFC3339),
	}, nil
}

// AcceptInvitation accepts an invitation and adds user to team
func (s *TeamInvitationService) AcceptInvitation(token string, userID uuid.UUID) error {
	tokenHash := utils.HashSHA256(token)

	invitation, err := s.invitationRepo.GetByTokenHash(tokenHash)
	if err != nil {
		return fmt.Errorf("invalid invitation token")
	}

	// Validate invitation
	if invitation.IsExpired() {
		return fmt.Errorf("invitation has expired")
	}

	if invitation.Status != domain.InvitationStatusPending {
		return fmt.Errorf("invitation has already been used")
	}

	// Add user to team
	if err := s.teamRepo.AddWorker(invitation.TeamID, userID); err != nil {
		return fmt.Errorf("failed to add user to team: %w", err)
	}

	// Update invitation status
	if err := s.invitationRepo.UpdateStatus(invitation.ID, domain.InvitationStatusAccepted, &userID); err != nil {
		log.Printf("Warning: failed to update invitation status: %v", err)
	}

	return nil
}

// AcceptInvitationByToken accepts an invitation using just the token (for existing users)
func (s *TeamInvitationService) AcceptInvitationByToken(token string, email string) (*domain.TeamInvitation, error) {
	tokenHash := utils.HashSHA256(token)

	invitation, err := s.invitationRepo.GetByTokenHash(tokenHash)
	if err != nil {
		return nil, fmt.Errorf("invalid invitation token")
	}

	// Validate invitation
	if invitation.IsExpired() {
		return nil, fmt.Errorf("invitation has expired")
	}

	if invitation.Status != domain.InvitationStatusPending {
		return nil, fmt.Errorf("invitation has already been used")
	}

	// Get user by email
	user, err := s.userRepo.GetByEmail(email)
	if err != nil {
		return nil, fmt.Errorf("user not found with this email")
	}

	// Check if user is already in a team
	if user.TeamID != nil {
		return nil, fmt.Errorf("you are already a member of a team")
	}

	// Add user to team
	if err := s.teamRepo.AddWorker(invitation.TeamID, user.ID); err != nil {
		return nil, fmt.Errorf("failed to add user to team: %w", err)
	}

	// Update invitation status
	if err := s.invitationRepo.UpdateStatus(invitation.ID, domain.InvitationStatusAccepted, &user.ID); err != nil {
		log.Printf("Warning: failed to update invitation status: %v", err)
	}

	return invitation, nil
}

// DeclineInvitation declines an invitation
func (s *TeamInvitationService) DeclineInvitation(token string) error {
	tokenHash := utils.HashSHA256(token)

	invitation, err := s.invitationRepo.GetByTokenHash(tokenHash)
	if err != nil {
		return fmt.Errorf("invalid invitation token")
	}

	if invitation.Status != domain.InvitationStatusPending {
		return fmt.Errorf("invitation has already been processed")
	}

	return s.invitationRepo.UpdateStatus(invitation.ID, domain.InvitationStatusDeclined, nil)
}

// GetTeamInvitations gets all invitations for a team
func (s *TeamInvitationService) GetTeamInvitations(teamID uuid.UUID) ([]*domain.TeamInvitation, error) {
	return s.invitationRepo.GetByTeamID(teamID)
}

// ResendInvitation resends an existing invitation
func (s *TeamInvitationService) ResendInvitation(invitationID, inviterID uuid.UUID) error {
	invitation, err := s.invitationRepo.GetByID(invitationID)
	if err != nil {
		return fmt.Errorf("invitation not found")
	}

	// Verify inviter is still the team leader
	team, err := s.teamRepo.GetByID(invitation.TeamID)
	if err != nil {
		return fmt.Errorf("team not found")
	}

	if team.LeaderID != inviterID {
		return fmt.Errorf("only team leader can resend invitations")
	}

	if invitation.Status != domain.InvitationStatusPending {
		return fmt.Errorf("cannot resend a processed invitation")
	}

	// Generate new token
	token, err := utils.GenerateSecureToken(InvitationTokenLength)
	if err != nil {
		return fmt.Errorf("failed to generate new token: %w", err)
	}

	// Get inviter info
	inviter, err := s.userRepo.GetByID(inviterID)
	if err != nil {
		return fmt.Errorf("inviter not found")
	}

	inviterName := inviter.DisplayName
	if inviterName == "" {
		inviterName = inviter.Email
	}

	// Send email with new token
	return s.sendInvitationEmail(invitation.InviteeEmail, inviterName, team.Name, token)
}

// CancelInvitation cancels a pending invitation
func (s *TeamInvitationService) CancelInvitation(invitationID, inviterID uuid.UUID) error {
	invitation, err := s.invitationRepo.GetByID(invitationID)
	if err != nil {
		return fmt.Errorf("invitation not found")
	}

	// Verify inviter is the team leader
	team, err := s.teamRepo.GetByID(invitation.TeamID)
	if err != nil {
		return fmt.Errorf("team not found")
	}

	if team.LeaderID != inviterID {
		return fmt.Errorf("only team leader can cancel invitations")
	}

	if invitation.Status != domain.InvitationStatusPending {
		return fmt.Errorf("cannot cancel a processed invitation")
	}

	return s.invitationRepo.UpdateStatus(invitationID, domain.InvitationStatusExpired, nil)
}

// GetPendingInvitationsForEmail gets pending invitations for an email address
func (s *TeamInvitationService) GetPendingInvitationsForEmail(email string) ([]*domain.TeamInvitation, error) {
	invitations, err := s.invitationRepo.GetByEmail(email)
	if err != nil {
		return nil, err
	}

	// Filter to only pending and non-expired
	var pending []*domain.TeamInvitation
	for _, inv := range invitations {
		if inv.IsPending() {
			pending = append(pending, inv)
		}
	}

	return pending, nil
}
