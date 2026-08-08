package service

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	"rally-point/user-service/internal/domain"
	"rally-point/user-service/internal/email"

	"github.com/google/uuid"
	"github.com/rally-point/shared/utils"
	"golang.org/x/crypto/bcrypt"
)

type superAdminService struct {
	userRepo  domain.UserRepository
	tokenRepo domain.VerificationTokenRepository
	db        *sql.DB
	emailClient *email.EmailClient
	templates   *email.EmailTemplates
}

// NewSuperAdminService creates a new superadmin service
func NewSuperAdminService(userRepo domain.UserRepository, tokenRepo domain.VerificationTokenRepository, db *sql.DB) domain.SuperAdminService {
	return &superAdminService{
		userRepo:    userRepo,
		tokenRepo:   tokenRepo,
		db:          db,
		emailClient: email.NewEmailClient(),
		templates:   email.NewEmailTemplates(),
	}
}

// CreateAdmin creates a new admin account
func (s *superAdminService) CreateAdmin(req *domain.CreateAdminRequest) (*domain.User, error) {
	// Check if email already exists
	existingUser, _ := s.userRepo.GetByEmail(req.Email)
	if existingUser != nil {
		return nil, fmt.Errorf("user with email %s already exists", req.Email)
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Create admin user
	user := &domain.User{
		ID:                 uuid.New(),
		Email:              req.Email,
		PasswordHash:       string(hashedPassword),
		DisplayName:        req.DisplayName,
		Role:               domain.RoleAdmin,
		VerificationStatus: domain.VerificationVerified, // Admins are always verified
		IsOnline:           false,
		LastActiveAt:       time.Now(),
		CreatedAt:          time.Now(),
		UpdatedAt:          time.Now(),
	}

	if req.Phone != "" {
		user.Phone = &req.Phone
	}

	err = s.userRepo.Create(user)
	if err != nil {
		return nil, fmt.Errorf("failed to create admin: %w", err)
	}

	fmt.Printf("👤 Admin account created: %s (%s)\n", req.DisplayName, req.Email)

	// Remove password hash from response
	user.PasswordHash = ""

	return user, nil
}

// InviteAdmin invites an admin/superadmin by email, creating their account and sending an invitation email
func (s *superAdminService) InviteAdmin(req *domain.InviteAdminRequest) error {
	// Check if email already exists
	existingUser, _ := s.userRepo.GetByEmail(req.Email)
	if existingUser != nil {
		return fmt.Errorf("a user with email %s already exists", req.Email)
	}

	// Determine role (default to admin)
	role := domain.RoleAdmin
	if req.Role == "superadmin" {
		role = domain.RoleSuperAdmin
	}

	// Generate a random placeholder password (user will set their own via invitation link)
	placeholderPassword, err := utils.GenerateSecureToken(32)
	if err != nil {
		return fmt.Errorf("failed to generate placeholder password: %w", err)
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(placeholderPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash placeholder password: %w", err)
	}

	// Create user with placeholder password
	user := &domain.User{
		ID:                 uuid.New(),
		Email:              req.Email,
		PasswordHash:       string(hashedPassword),
		DisplayName:        req.DisplayName,
		Role:               role,
		VerificationStatus: domain.VerificationVerified,
		IsOnline:           false,
		LastActiveAt:       time.Now(),
		CreatedAt:          time.Now(),
		UpdatedAt:          time.Now(),
	}

	if req.Phone != "" {
		user.Phone = &req.Phone
	}

	err = s.userRepo.Create(user)
	if err != nil {
		return fmt.Errorf("failed to create admin: %w", err)
	}

	// Generate password reset token for the invitation
	plainToken, err := utils.GenerateSecureToken(32)
	if err != nil {
		return fmt.Errorf("failed to generate token: %w", err)
	}

	tokenHash := utils.HashSHA256(plainToken)

	token := &domain.VerificationToken{
		ID:        uuid.New(),
		UserID:    user.ID,
		TokenHash: tokenHash,
		TokenType: domain.TokenTypePasswordReset,
		ExpiresAt: time.Now().Add(7 * 24 * time.Hour), // 7 days for invitation
		CreatedAt: time.Now(),
	}

	if err = s.tokenRepo.Create(token); err != nil {
		return fmt.Errorf("failed to create invitation token: %w", err)
	}

	// Generate invitation email
	invitationURL := s.templates.GetAdminInvitationURL(plainToken)
	roleLabel := "Admin"
	if role == domain.RoleSuperAdmin {
		roleLabel = "Superadmin"
	}

	htmlContent, textContent, err := s.templates.GenerateAdminInvitationEmail(email.AdminInvitationEmailData{
		InviterName:   "Light Point Admin",
		InviteeEmail:  req.Email,
		Role:          roleLabel,
		InvitationURL: invitationURL,
		ExpiryDays:    7,
	})
	if err != nil {
		return fmt.Errorf("failed to generate invitation email: %w", err)
	}

	// Send email
	if !s.emailClient.IsConfigured() {
		if os.Getenv("GO_ENV") == "development" || os.Getenv("GO_ENV") == "" {
			log.Printf("📧 [DEV] Admin invitation email for %s:\n   URL: %s\n", req.Email, invitationURL)
			return nil
		}
		return fmt.Errorf("email service not configured")
	}

	if err = s.emailClient.SendEmail(req.Email, "You're Invited to Join Light Point Admin", htmlContent, textContent); err != nil {
		return fmt.Errorf("failed to send invitation email: %w", err)
	}

	fmt.Printf("📧 Admin invitation sent to %s (role: %s)\n", req.Email, roleLabel)
	return nil
}

// GetAllAdmins returns all admin and superadmin users
func (s *superAdminService) GetAllAdmins() (*domain.AdminListResponse, error) {
	admins, err := s.userRepo.GetByRole(domain.RoleAdmin)
	if err != nil {
		return nil, fmt.Errorf("failed to get admins: %w", err)
	}

	superadmins, err := s.userRepo.GetByRole(domain.RoleSuperAdmin)
	if err != nil {
		return nil, fmt.Errorf("failed to get superadmins: %w", err)
	}

	allUsers := append(admins, superadmins...)

	adminInfos := make([]*domain.AdminInfo, 0, len(allUsers))
	for _, user := range allUsers {
		adminInfos = append(adminInfos, &domain.AdminInfo{
			ID:              user.ID,
			Email:           user.Email,
			DisplayName:     user.DisplayName,
			Role:            user.Role,
			Phone:           user.Phone,
			ProfilePhotoURL: user.ProfilePhotoURL,
			CreatedAt:       user.CreatedAt,
			LastActiveAt:    user.LastActiveAt,
			IsOnline:        user.IsOnline,
		})
	}

	return &domain.AdminListResponse{
		Admins: adminInfos,
		Total:  len(adminInfos),
	}, nil
}

// GetAdminByID returns an admin by ID
func (s *superAdminService) GetAdminByID(id uuid.UUID) (*domain.AdminInfo, error) {
	user, err := s.userRepo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("admin not found: %w", err)
	}

	if user.Role != domain.RoleAdmin {
		return nil, fmt.Errorf("user is not an admin")
	}

	return &domain.AdminInfo{
		ID:              user.ID,
		Email:           user.Email,
		DisplayName:     user.DisplayName,
		Phone:           user.Phone,
		ProfilePhotoURL: user.ProfilePhotoURL,
		CreatedAt:       user.CreatedAt,
		LastActiveAt:    user.LastActiveAt,
		IsOnline:        user.IsOnline,
	}, nil
}

// DeleteAdmin deletes an admin account
func (s *superAdminService) DeleteAdmin(adminID uuid.UUID) error {
	// Verify the user exists and is admin or superadmin
	user, err := s.userRepo.GetByID(adminID)
	if err != nil {
		return fmt.Errorf("admin not found: %w", err)
	}

	if !domain.IsAdminRole(user.Role) {
		return fmt.Errorf("user is not an admin")
	}

	// Delete the admin
	err = s.userRepo.Delete(adminID)
	if err != nil {
		return fmt.Errorf("failed to delete admin: %w", err)
	}

	fmt.Printf("🗑️ Admin account deleted: %s (%s) [%s]\n", user.DisplayName, user.Email, user.Role)

	return nil
}

// ResetAdminPassword resets an admin's password
func (s *superAdminService) ResetAdminPassword(adminID uuid.UUID, newPassword string) error {
	// Verify the user is an admin
	user, err := s.userRepo.GetByID(adminID)
	if err != nil {
		return fmt.Errorf("admin not found: %w", err)
	}

	if user.Role != domain.RoleAdmin {
		return fmt.Errorf("user is not an admin")
	}

	// Hash new password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update password
	err = s.userRepo.UpdatePassword(adminID, string(hashedPassword))
	if err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	fmt.Printf("🔑 Admin password reset: %s\n", user.Email)

	return nil
}
