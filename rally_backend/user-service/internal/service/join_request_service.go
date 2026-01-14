package service

import (
	"fmt"
	"time"

	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
)

type joinRequestService struct {
	joinRequestRepo domain.JoinRequestRepository
	userRepo        domain.UserRepository
	teamRepo        domain.TeamRepository
}

// NewJoinRequestService creates a new join request service
func NewJoinRequestService(
	joinRequestRepo domain.JoinRequestRepository,
	userRepo domain.UserRepository,
	teamRepo domain.TeamRepository,
) domain.JoinRequestService {
	return &joinRequestService{
		joinRequestRepo: joinRequestRepo,
		userRepo:        userRepo,
		teamRepo:        teamRepo,
	}
}

// CreateRequest creates a new join request
func (s *joinRequestService) CreateRequest(userID uuid.UUID, req *domain.CreateJoinRequestRequest) (*domain.TeamJoinRequest, error) {
	// Verify the user exists and is a worker
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	if user.Role != domain.RoleWorker {
		return nil, fmt.Errorf("only workers can request to join teams")
	}

	// Check if user already has a team
	if user.TeamID != nil {
		return nil, fmt.Errorf("you are already a member of a team")
	}

	// Check if user already has a pending request
	existingRequest, _ := s.joinRequestRepo.GetPendingByUserID(userID)
	if existingRequest != nil {
		return nil, fmt.Errorf("you already have a pending request to join a team")
	}

	// Verify the team exists
	team, err := s.teamRepo.GetByID(req.TeamID)
	if err != nil {
		return nil, fmt.Errorf("team not found: %w", err)
	}

	// Create the request
	now := time.Now()
	joinRequest := &domain.TeamJoinRequest{
		ID:          uuid.New(),
		UserID:      userID,
		TeamID:      req.TeamID,
		Status:      domain.JoinRequestPending,
		RequestedAt: now,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	if req.Message != "" {
		joinRequest.Message = &req.Message
	}

	err = s.joinRequestRepo.Create(joinRequest)
	if err != nil {
		return nil, fmt.Errorf("failed to create join request: %w", err)
	}

	joinRequest.Team = team

	fmt.Printf("📨 Worker %s requested to join team %s\n", user.DisplayName, team.Name)

	return joinRequest, nil
}

// GetRequest retrieves a join request by ID
func (s *joinRequestService) GetRequest(requestID uuid.UUID) (*domain.TeamJoinRequest, error) {
	return s.joinRequestRepo.GetByID(requestID)
}

// GetUserRequests retrieves all join requests for a user
func (s *joinRequestService) GetUserRequests(userID uuid.UUID) ([]*domain.TeamJoinRequest, error) {
	return s.joinRequestRepo.GetByUserID(userID)
}

// GetTeamRequests retrieves all join requests for a team
func (s *joinRequestService) GetTeamRequests(teamID uuid.UUID) ([]*domain.TeamJoinRequest, error) {
	return s.joinRequestRepo.GetByTeamID(teamID)
}

// GetPendingTeamRequests retrieves pending join requests for a team
func (s *joinRequestService) GetPendingTeamRequests(teamID uuid.UUID) ([]*domain.TeamJoinRequest, error) {
	return s.joinRequestRepo.GetPendingByTeamID(teamID)
}

// ApproveRequest approves a join request
func (s *joinRequestService) ApproveRequest(requestID, reviewerID uuid.UUID) error {
	// Get the request
	request, err := s.joinRequestRepo.GetByID(requestID)
	if err != nil {
		return fmt.Errorf("join request not found: %w", err)
	}

	if request.Status != domain.JoinRequestPending {
		return fmt.Errorf("request has already been processed")
	}

	// Verify reviewer is the team leader
	team, err := s.teamRepo.GetByID(request.TeamID)
	if err != nil {
		return fmt.Errorf("team not found: %w", err)
	}

	if team.LeaderID != reviewerID {
		// Check if reviewer is an admin (admins can also approve)
		reviewer, err := s.userRepo.GetByID(reviewerID)
		if err != nil || !domain.IsAdminRole(reviewer.Role) {
			return fmt.Errorf("only the team leader or admin can approve requests")
		}
	}

	// Update the request
	now := time.Now()
	request.Status = domain.JoinRequestApproved
	request.ReviewedBy = &reviewerID
	request.ReviewedAt = &now

	err = s.joinRequestRepo.Update(request)
	if err != nil {
		return fmt.Errorf("failed to update request: %w", err)
	}

	// Update the user's team_id and verification_status
	user, err := s.userRepo.GetByID(request.UserID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	user.TeamID = &request.TeamID
	err = s.userRepo.Update(user)
	if err != nil {
		return fmt.Errorf("failed to update user team: %w", err)
	}

	// Update verification status
	err = s.userRepo.UpdateVerificationStatus(request.UserID, domain.VerificationVerified, &reviewerID, nil)
	if err != nil {
		return fmt.Errorf("failed to update verification status: %w", err)
	}

	// Update team worker count
	err = s.teamRepo.AddWorker(request.TeamID, request.UserID)
	if err != nil {
		fmt.Printf("Warning: failed to update team worker count: %v\n", err)
	}

	fmt.Printf("✅ Join request approved: %s joined team %s\n", user.DisplayName, team.Name)

	return nil
}

// RejectRequest rejects a join request
func (s *joinRequestService) RejectRequest(requestID, reviewerID uuid.UUID, reason string) error {
	// Get the request
	request, err := s.joinRequestRepo.GetByID(requestID)
	if err != nil {
		return fmt.Errorf("join request not found: %w", err)
	}

	if request.Status != domain.JoinRequestPending {
		return fmt.Errorf("request has already been processed")
	}

	// Verify reviewer is the team leader or admin
	team, err := s.teamRepo.GetByID(request.TeamID)
	if err != nil {
		return fmt.Errorf("team not found: %w", err)
	}

	if team.LeaderID != reviewerID {
		reviewer, err := s.userRepo.GetByID(reviewerID)
		if err != nil || !domain.IsAdminRole(reviewer.Role) {
			return fmt.Errorf("only the team leader or admin can reject requests")
		}
	}

	// Update the request
	now := time.Now()
	request.Status = domain.JoinRequestRejected
	request.ReviewedBy = &reviewerID
	request.ReviewedAt = &now
	if reason != "" {
		request.RejectionReason = &reason
	}

	err = s.joinRequestRepo.Update(request)
	if err != nil {
		return fmt.Errorf("failed to update request: %w", err)
	}

	fmt.Printf("❌ Join request rejected for team %s\n", team.Name)

	return nil
}

// CancelRequest cancels a join request (by the worker)
func (s *joinRequestService) CancelRequest(requestID, userID uuid.UUID) error {
	// Get the request
	request, err := s.joinRequestRepo.GetByID(requestID)
	if err != nil {
		return fmt.Errorf("join request not found: %w", err)
	}

	// Verify the request belongs to this user
	if request.UserID != userID {
		return fmt.Errorf("you can only cancel your own requests")
	}

	if request.Status != domain.JoinRequestPending {
		return fmt.Errorf("request has already been processed")
	}

	// Delete the request
	err = s.joinRequestRepo.Delete(requestID)
	if err != nil {
		return fmt.Errorf("failed to cancel request: %w", err)
	}

	fmt.Printf("🗑️ Join request cancelled\n")

	return nil
}

// GetUserPendingRequest retrieves the pending join request for a user
func (s *joinRequestService) GetUserPendingRequest(userID uuid.UUID) (*domain.TeamJoinRequest, error) {
	return s.joinRequestRepo.GetPendingByUserID(userID)
}
