package domain

import (
	"time"

	"github.com/google/uuid"
)

// JoinRequestStatus constants
const (
	JoinRequestPending  = "pending"
	JoinRequestApproved = "approved"
	JoinRequestRejected = "rejected"
)

// TeamJoinRequest represents a worker's request to join a team
type TeamJoinRequest struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	UserID          uuid.UUID  `json:"user_id" db:"user_id"`
	TeamID          uuid.UUID  `json:"team_id" db:"team_id"`
	Status          string     `json:"status" db:"status"`
	Message         *string    `json:"message,omitempty" db:"message"`
	RequestedAt     time.Time  `json:"requested_at" db:"requested_at"`
	ReviewedBy      *uuid.UUID `json:"reviewed_by,omitempty" db:"reviewed_by"`
	ReviewedAt      *time.Time `json:"reviewed_at,omitempty" db:"reviewed_at"`
	RejectionReason *string    `json:"rejection_reason,omitempty" db:"rejection_reason"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`

	// Joined fields (not stored in DB)
	User *User `json:"user,omitempty" db:"-"`
	Team *Team `json:"team,omitempty" db:"-"`
}

// CreateJoinRequestRequest represents the request to create a join request
type CreateJoinRequestRequest struct {
	TeamID  uuid.UUID `json:"team_id" binding:"required"`
	Message string    `json:"message,omitempty"`
}

// ReviewJoinRequestRequest represents the request to review a join request
type ReviewJoinRequestRequest struct {
	Approved        bool   `json:"approved"`
	RejectionReason string `json:"rejection_reason,omitempty"`
}

// JoinRequestRepository defines the interface for join request data access
type JoinRequestRepository interface {
	Create(request *TeamJoinRequest) error
	GetByID(id uuid.UUID) (*TeamJoinRequest, error)
	GetByUserID(userID uuid.UUID) ([]*TeamJoinRequest, error)
	GetByTeamID(teamID uuid.UUID) ([]*TeamJoinRequest, error)
	GetPendingByTeamID(teamID uuid.UUID) ([]*TeamJoinRequest, error)
	GetByUserAndTeam(userID, teamID uuid.UUID) (*TeamJoinRequest, error)
	Update(request *TeamJoinRequest) error
	Delete(id uuid.UUID) error
	GetPendingByUserID(userID uuid.UUID) (*TeamJoinRequest, error)
}

// JoinRequestService defines the interface for join request business logic
type JoinRequestService interface {
	CreateRequest(userID uuid.UUID, req *CreateJoinRequestRequest) (*TeamJoinRequest, error)
	GetRequest(requestID uuid.UUID) (*TeamJoinRequest, error)
	GetUserRequests(userID uuid.UUID) ([]*TeamJoinRequest, error)
	GetTeamRequests(teamID uuid.UUID) ([]*TeamJoinRequest, error)
	GetPendingTeamRequests(teamID uuid.UUID) ([]*TeamJoinRequest, error)
	ApproveRequest(requestID, reviewerID uuid.UUID) error
	RejectRequest(requestID, reviewerID uuid.UUID, reason string) error
	CancelRequest(requestID, userID uuid.UUID) error
	GetUserPendingRequest(userID uuid.UUID) (*TeamJoinRequest, error)
}
