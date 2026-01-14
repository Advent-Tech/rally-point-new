package service

import (
	"database/sql"
	"fmt"
	"time"

	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type superAdminService struct {
	userRepo domain.UserRepository
	db       *sql.DB
}

// NewSuperAdminService creates a new superadmin service
func NewSuperAdminService(userRepo domain.UserRepository, db *sql.DB) domain.SuperAdminService {
	return &superAdminService{
		userRepo: userRepo,
		db:       db,
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

// GetAllAdmins returns all admin users
func (s *superAdminService) GetAllAdmins() (*domain.AdminListResponse, error) {
	admins, err := s.userRepo.GetByRole(domain.RoleAdmin)
	if err != nil {
		return nil, fmt.Errorf("failed to get admins: %w", err)
	}

	adminInfos := make([]*domain.AdminInfo, 0, len(admins))
	for _, admin := range admins {
		adminInfos = append(adminInfos, &domain.AdminInfo{
			ID:              admin.ID,
			Email:           admin.Email,
			DisplayName:     admin.DisplayName,
			Phone:           admin.Phone,
			ProfilePhotoURL: admin.ProfilePhotoURL,
			CreatedAt:       admin.CreatedAt,
			LastActiveAt:    admin.LastActiveAt,
			IsOnline:        admin.IsOnline,
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
	// Verify the user is an admin
	user, err := s.userRepo.GetByID(adminID)
	if err != nil {
		return fmt.Errorf("admin not found: %w", err)
	}

	if user.Role != domain.RoleAdmin {
		return fmt.Errorf("user is not an admin")
	}

	// Delete the admin
	err = s.userRepo.Delete(adminID)
	if err != nil {
		return fmt.Errorf("failed to delete admin: %w", err)
	}

	fmt.Printf("🗑️ Admin account deleted: %s (%s)\n", user.DisplayName, user.Email)

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
