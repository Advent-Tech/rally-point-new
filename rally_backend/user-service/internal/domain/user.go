package domain

import (
	"time"

	"github.com/google/uuid"
)

// User represents a user in the system
type User struct {
	ID                 uuid.UUID  `json:"id" db:"id"`
	Email              string     `json:"email" db:"email"`
	PasswordHash       string     `json:"-" db:"password_hash"`
	DisplayName        string     `json:"display_name" db:"display_name"`
	Role               string     `json:"role" db:"role"`
	Phone              *string    `json:"phone,omitempty" db:"phone"`
	ProfilePhotoURL    *string    `json:"profile_photo_url,omitempty" db:"profile_photo_url"`
	TeamID             *uuid.UUID `json:"team_id,omitempty" db:"team_id"`
	IsOnline           bool       `json:"is_online" db:"is_online"`
	LastActiveAt       time.Time  `json:"last_active_at" db:"last_active_at"`
	VerificationStatus string     `json:"verification_status" db:"verification_status"`
	VerifiedBy         *uuid.UUID `json:"verified_by,omitempty" db:"verified_by"`
	VerifiedAt         *time.Time `json:"verified_at,omitempty" db:"verified_at"`
	RejectionReason    *string    `json:"rejection_reason,omitempty" db:"rejection_reason"`
	EmailVerified      bool       `json:"email_verified" db:"email_verified"`
	EmailVerifiedAt    *time.Time `json:"email_verified_at,omitempty" db:"email_verified_at"`
	CreatedAt          time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at" db:"updated_at"`
}

// Team represents a team in the system
type Team struct {
	ID          uuid.UUID `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description,omitempty" db:"description"`
	LeaderID    uuid.UUID `json:"leader_id" db:"leader_id"`
	LeaderName  *string   `json:"leader_name,omitempty"` // Not in DB, populated by JOIN
	PhotoURL    *string   `json:"photo_url,omitempty" db:"photo_url"`
	WorkerCount int       `json:"worker_count" db:"worker_count"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// UserSession represents a user session for JWT management
type UserSession struct {
	ID           uuid.UUID `json:"id" db:"id"`
	UserID       uuid.UUID `json:"user_id" db:"user_id"`
	RefreshToken string    `json:"refresh_token" db:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at" db:"expires_at"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// CreateUserRequest represents the request to create a user
type CreateUserRequest struct {
	Email           string  `json:"email" binding:"required,email"`
	Password        string  `json:"password" binding:"required,min=6"`
	DisplayName     string  `json:"display_name" binding:"required"`
	Role            string  `json:"role,omitempty"`
	Phone           string  `json:"phone,omitempty"`
	TeamName        string  `json:"team_name,omitempty"`  // For team leaders creating a new team
	TeamID          *string `json:"team_id,omitempty"`    // For workers joining an existing team
	Skills          string  `json:"skills,omitempty"`
	SelfDescription string  `json:"self_description,omitempty"`
}

// LoginRequest represents the login request
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// UpdateUserRequest represents the request to update a user
type UpdateUserRequest struct {
	DisplayName     *string `json:"display_name,omitempty"`
	Phone           *string `json:"phone,omitempty"`
	ProfilePhotoURL *string `json:"profile_photo_url,omitempty"`
}

// CreateTeamRequest represents the request to create a team
type CreateTeamRequest struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description,omitempty"`
	PhotoURL    string `json:"photo_url,omitempty"`
}

// UpdateTeamRequest represents the request to update a team
type UpdateTeamRequest struct {
	Name        *string `json:"name,omitempty"`
	Description *string `json:"description,omitempty"`
	PhotoURL    *string `json:"photo_url,omitempty"`
}

// JoinTeamRequest represents the request to join a team
type JoinTeamRequest struct {
	TeamID uuid.UUID `json:"team_id" binding:"required"`
}

// AuthResponse represents the authentication response
type AuthResponse struct {
	User         *User  `json:"user"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

// RefreshTokenRequest represents the refresh token request
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// UserRole constants
const (
	RoleSuperAdmin = "superadmin"
	RoleAdmin      = "admin"
	RoleTeamLeader = "team_leader"
	RoleWorker     = "worker"
)

// Verification status constants
const (
	VerificationPending  = "pending"
	VerificationVerified = "verified"
	VerificationRejected = "rejected"
)

// ValidRoles returns a list of valid user roles
func ValidRoles() []string {
	return []string{RoleAdmin, RoleTeamLeader, RoleWorker}
}

// AllRoles returns all roles including superadmin (for internal use)
func AllRoles() []string {
	return []string{RoleSuperAdmin, RoleAdmin, RoleTeamLeader, RoleWorker}
}

// IsAdminRole checks if the role has admin privileges
func IsAdminRole(role string) bool {
	return role == RoleSuperAdmin || role == RoleAdmin
}

// RequiresVerification checks if a role requires verification
func RequiresVerification(role string) bool {
	return role == RoleTeamLeader || role == RoleWorker
}

// IsValidRole checks if a role is valid
func IsValidRole(role string) bool {
	for _, validRole := range ValidRoles() {
		if role == validRole {
			return true
		}
	}
	return false
}

// UserRepository defines the interface for user data access
type UserRepository interface {
	Create(user *User) error
	GetByID(id uuid.UUID) (*User, error)
	GetByEmail(email string) (*User, error)
	Update(user *User) error
	Delete(id uuid.UUID) error
	GetByTeamID(teamID uuid.UUID) ([]*User, error)
	UpdateLastActive(id uuid.UUID) error
	SetOnlineStatus(id uuid.UUID, isOnline bool) error
	// New methods for multi-role system
	GetByRole(role string) ([]*User, error)
	GetByRoleAndStatus(role, status string) ([]*User, error)
	UpdateVerificationStatus(userID uuid.UUID, status string, verifiedBy *uuid.UUID, reason *string) error
	UpdatePassword(userID uuid.UUID, passwordHash string) error
	// Email verification
	UpdateEmailVerified(userID uuid.UUID, verified bool) error
}

// TeamRepository defines the interface for team data access
type TeamRepository interface {
	Create(team *Team) error
	GetByID(id uuid.UUID) (*Team, error)
	GetByLeaderID(leaderID uuid.UUID) ([]*Team, error)
	Update(team *Team) error
	Delete(id uuid.UUID) error
	GetAll() ([]*Team, error)
	AddWorker(teamID, workerID uuid.UUID) error
	RemoveWorker(teamID, workerID uuid.UUID) error
	GetTeamWorkers(teamID uuid.UUID) ([]*User, error)
}

// SessionRepository defines the interface for session data access
type SessionRepository interface {
	Create(session *UserSession) error
	GetByRefreshToken(token string) (*UserSession, error)
	DeleteByUserID(userID uuid.UUID) error
	DeleteExpired() error
}

// UserService defines the interface for user business logic
type UserService interface {
	Register(req *CreateUserRequest) (*AuthResponse, error)
	Login(req *LoginRequest) (*AuthResponse, error)
	RefreshToken(req *RefreshTokenRequest) (*AuthResponse, error)
	GetProfile(userID uuid.UUID) (*User, error)
	UpdateProfile(userID uuid.UUID, req *UpdateUserRequest) (*User, error)
	Logout(userID uuid.UUID) error
	SetOnlineStatus(userID uuid.UUID, isOnline bool) error
}

// TeamService defines the interface for team business logic
type TeamService interface {
	CreateTeam(leaderID uuid.UUID, req *CreateTeamRequest) (*Team, error)
	GetTeam(teamID uuid.UUID) (*Team, error)
	UpdateTeam(teamID, userID uuid.UUID, req *UpdateTeamRequest) (*Team, error)
	DeleteTeam(teamID, userID uuid.UUID) error
	JoinTeam(userID uuid.UUID, req *JoinTeamRequest) error
	LeaveTeam(userID uuid.UUID) error
	GetTeamWorkers(teamID uuid.UUID) ([]*User, error)
	GetUserTeams(userID uuid.UUID) ([]*Team, error)
	GetTeamsByLeader(leaderID uuid.UUID) ([]*Team, error)
	SearchTeams(query string) ([]*Team, error)
	GetAllTeams() ([]*Team, error)
}
