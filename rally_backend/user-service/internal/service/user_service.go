package service

import (
	"database/sql"
	"fmt"
	"time"

	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
	"github.com/rally-point/shared/auth"
	"golang.org/x/crypto/bcrypt"
)

type userService struct {
	userRepo        domain.UserRepository
	sessionRepo     domain.SessionRepository
	joinRequestRepo domain.JoinRequestRepository
	jwtManager      *auth.JWTManager
	db              *sql.DB
}

// NewUserService creates a new user service
func NewUserService(userRepo domain.UserRepository, sessionRepo domain.SessionRepository, joinRequestRepo domain.JoinRequestRepository, jwtManager *auth.JWTManager, db *sql.DB) domain.UserService {
	return &userService{
		userRepo:        userRepo,
		sessionRepo:     sessionRepo,
		joinRequestRepo: joinRequestRepo,
		jwtManager:      jwtManager,
		db:              db,
	}
}

// createTeamForLeader creates a new team for a team leader
func (s *userService) createTeamForLeader(leaderID uuid.UUID, teamName string) (*uuid.UUID, error) {
	teamID := uuid.New()

	// Create team record directly in database
	query := `
		INSERT INTO teams (id, name, leader_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
	`

	_, err := s.db.Exec(query, teamID, teamName, leaderID, time.Now(), time.Now())
	if err != nil {
		return nil, fmt.Errorf("failed to create team: %w", err)
	}

	return &teamID, nil
}

// Register creates a new user account
func (s *userService) Register(req *domain.CreateUserRequest) (*domain.AuthResponse, error) {
	// Check if user already exists
	existingUser, _ := s.userRepo.GetByEmail(req.Email)
	if existingUser != nil {
		return nil, fmt.Errorf("user with email %s already exists", req.Email)
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Set default role if not provided
	role := req.Role
	if role == "" {
		role = domain.RoleWorker
	}

	// Validate role - only allow team_leader and worker for public registration
	if !domain.IsValidRole(role) {
		return nil, fmt.Errorf("invalid role: %s", role)
	}

	// Determine verification status based on role
	// Team leaders and workers require verification before they can login
	verificationStatus := domain.VerificationPending
	if role == domain.RoleAdmin {
		// Admins cannot self-register - must be created by superadmin
		return nil, fmt.Errorf("admin accounts cannot be created through registration")
	}

	// Create user
	user := &domain.User{
		ID:                 uuid.New(),
		Email:              req.Email,
		PasswordHash:       string(hashedPassword),
		DisplayName:        req.DisplayName,
		Role:               role,
		IsOnline:           false, // Not online until verified and logged in
		LastActiveAt:       time.Now(),
		VerificationStatus: verificationStatus,
		CreatedAt:          time.Now(),
		UpdatedAt:          time.Now(),
	}

	if req.Phone != "" {
		user.Phone = &req.Phone
	}

	// Create user (teams are now created by admin and assigned to leaders)
	err = s.userRepo.Create(user)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	fmt.Printf("📝 User %s registered as %s (pending verification)\n", req.DisplayName, role)

	// For workers, automatically create a join request if team_id was provided
	if role == domain.RoleWorker && req.TeamID != nil && *req.TeamID != "" {
		teamID, err := uuid.Parse(*req.TeamID)
		if err != nil {
			// Don't fail registration, just log and skip join request
			fmt.Printf("⚠️ Invalid team_id provided for worker %s: %v\n", req.DisplayName, err)
		} else if s.joinRequestRepo != nil {
			// Create the join request
			joinRequest := &domain.TeamJoinRequest{
				ID:          uuid.New(),
				UserID:      user.ID,
				TeamID:      teamID,
				Status:      domain.JoinRequestPending,
				RequestedAt: time.Now(),
				CreatedAt:   time.Now(),
				UpdatedAt:   time.Now(),
			}

			err = s.joinRequestRepo.Create(joinRequest)
			if err != nil {
				// Don't fail registration, just log the error
				fmt.Printf("⚠️ Failed to create join request for worker %s: %v\n", req.DisplayName, err)
			} else {
				fmt.Printf("📨 Join request created for worker %s to team %s\n", req.DisplayName, teamID)
			}
		}
	}

	// For pending users, return a response without tokens (they can't login yet)
	// Remove password hash from response
	user.PasswordHash = ""

	return &domain.AuthResponse{
		User:         user,
		AccessToken:  "", // No token for unverified users
		RefreshToken: "",
		ExpiresIn:    0,
	}, nil
}

// Login authenticates a user
func (s *userService) Login(req *domain.LoginRequest) (*domain.AuthResponse, error) {
	// Get user by email
	user, err := s.userRepo.GetByEmail(req.Email)
	if err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	// Check password
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password))
	if err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	// Check email verification - team leaders and workers must verify email first
	if domain.RequiresVerification(user.Role) && !user.EmailVerified {
		return nil, fmt.Errorf("please verify your email address before logging in. Check your inbox for the verification link")
	}

	// Check verification status - only verified users can login
	// Superadmin and admin are always verified (created through proper channels)
	if domain.RequiresVerification(user.Role) {
		if user.VerificationStatus == domain.VerificationPending {
			return nil, fmt.Errorf("your account is pending verification. Please wait for admin approval")
		}
		if user.VerificationStatus == domain.VerificationRejected {
			reason := "Your account has been rejected"
			if user.RejectionReason != nil && *user.RejectionReason != "" {
				reason = fmt.Sprintf("Your account has been rejected: %s", *user.RejectionReason)
			}
			return nil, fmt.Errorf(reason)
		}
	}

	// For workers, also check if they have a team (required after verification)
	if user.Role == domain.RoleWorker && user.TeamID == nil {
		return nil, fmt.Errorf("you need to be approved to join a team before you can login")
	}

	// Update last active and online status
	err = s.userRepo.SetOnlineStatus(user.ID, true)
	if err != nil {
		return nil, fmt.Errorf("failed to update online status: %w", err)
	}

	// Delete existing sessions (if session repository is available)
	if s.sessionRepo != nil {
		s.sessionRepo.DeleteByUserID(user.ID)
	}

	// Generate tokens
	tokenPair, err := s.jwtManager.GenerateTokenPair(user.ID, user.Email, user.Role, user.TeamID, user.DisplayName)
	if err != nil {
		return nil, fmt.Errorf("failed to generate tokens: %w", err)
	}

	// Create session (if session repository is available)
	if s.sessionRepo != nil {
		session := &domain.UserSession{
			ID:           uuid.New(),
			UserID:       user.ID,
			RefreshToken: tokenPair.RefreshToken,
			ExpiresAt:    time.Now().Add(7 * 24 * time.Hour), // 7 days
			CreatedAt:    time.Now(),
		}

		err = s.sessionRepo.Create(session)
		if err != nil {
			return nil, fmt.Errorf("failed to create session: %w", err)
		}
	}

	// Remove password hash from response
	user.PasswordHash = ""
	user.IsOnline = true
	user.LastActiveAt = time.Now()

	return &domain.AuthResponse{
		User:         user,
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		ExpiresIn:    tokenPair.ExpiresIn,
	}, nil
}

// RefreshToken generates new tokens using refresh token
func (s *userService) RefreshToken(req *domain.RefreshTokenRequest) (*domain.AuthResponse, error) {
	if s.sessionRepo == nil {
		return nil, fmt.Errorf("session management not available")
	}

	// Verify refresh token
	claims, err := s.jwtManager.VerifyToken(req.RefreshToken)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token: %w", err)
	}

	if claims.TokenType != "refresh" {
		return nil, fmt.Errorf("invalid token type")
	}

	// Get session
	session, err := s.sessionRepo.GetByRefreshToken(req.RefreshToken)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token")
	}

	if session.ExpiresAt.Before(time.Now()) {
		return nil, fmt.Errorf("refresh token expired")
	}

	// Get user
	user, err := s.userRepo.GetByID(session.UserID)
	if err != nil {
		return nil, fmt.Errorf("user not found")
	}

	// Update last active
	err = s.userRepo.UpdateLastActive(user.ID)
	if err != nil {
		return nil, fmt.Errorf("failed to update last active: %w", err)
	}

	// Generate new tokens
	tokenPair, err := s.jwtManager.GenerateTokenPair(user.ID, user.Email, user.Role, user.TeamID, user.DisplayName)
	if err != nil {
		return nil, fmt.Errorf("failed to generate tokens: %w", err)
	}

	// Update session with new refresh token
	session.RefreshToken = tokenPair.RefreshToken
	session.ExpiresAt = time.Now().Add(7 * 24 * time.Hour)

	err = s.sessionRepo.Create(session) // This will update the existing session
	if err != nil {
		return nil, fmt.Errorf("failed to update session: %w", err)
	}

	// Remove password hash from response
	user.PasswordHash = ""

	return &domain.AuthResponse{
		User:         user,
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		ExpiresIn:    tokenPair.ExpiresIn,
	}, nil
}

// GetProfile retrieves user profile
func (s *userService) GetProfile(userID uuid.UUID) (*domain.User, error) {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user profile: %w", err)
	}

	// Remove password hash from response
	user.PasswordHash = ""

	return user, nil
}

// UpdateProfile updates user profile
func (s *userService) UpdateProfile(userID uuid.UUID, req *domain.UpdateUserRequest) (*domain.User, error) {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	// Update fields if provided
	if req.DisplayName != nil {
		user.DisplayName = *req.DisplayName
	}
	if req.Phone != nil {
		user.Phone = req.Phone
	}
	if req.ProfilePhotoURL != nil {
		user.ProfilePhotoURL = req.ProfilePhotoURL
	}

	err = s.userRepo.Update(user)
	if err != nil {
		return nil, fmt.Errorf("failed to update user: %w", err)
	}

	// Remove password hash from response
	user.PasswordHash = ""

	return user, nil
}

// Logout logs out a user
func (s *userService) Logout(userID uuid.UUID) error {
	// Set user offline
	err := s.userRepo.SetOnlineStatus(userID, false)
	if err != nil {
		return fmt.Errorf("failed to set offline status: %w", err)
	}

	// Delete user sessions (if session repository is available)
	if s.sessionRepo != nil {
		err = s.sessionRepo.DeleteByUserID(userID)
		if err != nil {
			return fmt.Errorf("failed to delete sessions: %w", err)
		}
	}

	return nil
}

// SetOnlineStatus sets user online status
func (s *userService) SetOnlineStatus(userID uuid.UUID, isOnline bool) error {
	err := s.userRepo.SetOnlineStatus(userID, isOnline)
	if err != nil {
		return fmt.Errorf("failed to set online status: %w", err)
	}

	return nil
}
