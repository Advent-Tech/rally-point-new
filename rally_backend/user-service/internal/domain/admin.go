package domain

import (
	"time"

	"github.com/google/uuid"
)

// CreateAdminRequest represents the request to create an admin account
type CreateAdminRequest struct {
	Email       string `json:"email" binding:"required,email"`
	Password    string `json:"password" binding:"required,min=6"`
	DisplayName string `json:"display_name" binding:"required"`
	Phone       string `json:"phone,omitempty"`
}

// VerifyTeamLeaderRequest represents the request to verify a team leader
type VerifyTeamLeaderRequest struct {
	Verified bool   `json:"verified"`
	Reason   string `json:"reason,omitempty"` // Required if rejecting
}

// AssignTeamLeaderRequest represents the request to assign a team to a leader
type AssignTeamLeaderRequest struct {
	LeaderID uuid.UUID `json:"leader_id" binding:"required"`
}

// AdminCreateTeamRequest represents admin's request to create a team
type AdminCreateTeamRequest struct {
	Name        string     `json:"name" binding:"required"`
	Description string     `json:"description,omitempty"`
	PhotoURL    string     `json:"photo_url,omitempty"`
	LeaderID    *uuid.UUID `json:"leader_id,omitempty"` // Optional - can assign later
}

// ResetPasswordRequest represents the request to reset a user's password
type ResetPasswordRequest struct {
	NewPassword string `json:"new_password" binding:"required,min=6"`
}

// TeamLeaderListResponse represents a list of team leaders with their status
type TeamLeaderListResponse struct {
	Leaders    []*TeamLeaderInfo `json:"leaders"`
	Total      int               `json:"total"`
	Pending    int               `json:"pending"`
	Verified   int               `json:"verified"`
	Rejected   int               `json:"rejected"`
}

// TeamLeaderInfo represents team leader information with verification status
type TeamLeaderInfo struct {
	ID                 uuid.UUID  `json:"id"`
	Email              string     `json:"email"`
	DisplayName        string     `json:"display_name"`
	Role               string     `json:"role"`
	Phone              *string    `json:"phone,omitempty"`
	ProfilePhotoURL    *string    `json:"profile_photo_url,omitempty"`
	TeamID             *uuid.UUID `json:"team_id,omitempty"`
	TeamName           *string    `json:"team_name,omitempty"`
	VerificationStatus string     `json:"verification_status"`
	VerifiedBy         *uuid.UUID `json:"verified_by,omitempty"`
	VerifiedAt         *time.Time `json:"verified_at,omitempty"`
	RejectionReason    *string    `json:"rejection_reason,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
}

// AdminListResponse represents a list of admins
type AdminListResponse struct {
	Admins []*AdminInfo `json:"admins"`
	Total  int          `json:"total"`
}

// AdminInfo represents admin information
type AdminInfo struct {
	ID              uuid.UUID `json:"id"`
	Email           string    `json:"email"`
	DisplayName     string    `json:"display_name"`
	Phone           *string   `json:"phone,omitempty"`
	ProfilePhotoURL *string   `json:"profile_photo_url,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
	LastActiveAt    time.Time `json:"last_active_at"`
	IsOnline        bool      `json:"is_online"`
}

// AdminService defines the interface for admin operations
type AdminService interface {
	// Team Leader Management
	GetTeamLeaders(status string) (*TeamLeaderListResponse, error)
	GetTeamLeaderByID(id uuid.UUID) (*TeamLeaderInfo, error)
	VerifyTeamLeader(leaderID, adminID uuid.UUID) error
	RejectTeamLeader(leaderID, adminID uuid.UUID, reason string) error

	// Team Management
	CreateTeam(req *AdminCreateTeamRequest) (*Team, error)
	AssignTeamToLeader(teamID, leaderID uuid.UUID) error
	UnassignTeamFromLeader(teamID uuid.UUID) error

	// Worker Verification (for direct admin approval)
	GetPendingWorkers() ([]*User, error)
	GetVerifiedWorkers() ([]*User, error)
	VerifyWorker(workerID, adminID uuid.UUID) error
	RejectWorker(workerID, adminID uuid.UUID, reason string) error
}

// SuperAdminService defines the interface for superadmin operations
type SuperAdminService interface {
	// Admin Management
	CreateAdmin(req *CreateAdminRequest) (*User, error)
	GetAllAdmins() (*AdminListResponse, error)
	GetAdminByID(id uuid.UUID) (*AdminInfo, error)
	DeleteAdmin(adminID uuid.UUID) error
	ResetAdminPassword(adminID uuid.UUID, newPassword string) error
}

// AdminRepository defines extended methods for admin operations
type AdminRepository interface {
	GetByRole(role string) ([]*User, error)
	GetByRoleAndStatus(role, status string) ([]*User, error)
	UpdateVerificationStatus(userID uuid.UUID, status string, verifiedBy *uuid.UUID, reason *string) error
}
