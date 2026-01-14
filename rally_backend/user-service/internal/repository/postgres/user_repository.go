package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/user-service/internal/domain"
)

type userRepository struct {
	db *sql.DB
}

// NewUserRepository creates a new user repository
func NewUserRepository(db *sql.DB) domain.UserRepository {
	return &userRepository{db: db}
}

// Create creates a new user
func (r *userRepository) Create(user *domain.User) error {
	query := `
		INSERT INTO users (id, email, password_hash, display_name, role, phone, profile_photo_url, team_id, is_online, last_active_at, verification_status, verified_by, verified_at, rejection_reason, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
	`

	_, err := r.db.Exec(
		query,
		user.ID,
		user.Email,
		user.PasswordHash,
		user.DisplayName,
		user.Role,
		user.Phone,
		user.ProfilePhotoURL,
		user.TeamID,
		user.IsOnline,
		user.LastActiveAt,
		user.VerificationStatus,
		user.VerifiedBy,
		user.VerifiedAt,
		user.RejectionReason,
		user.CreatedAt,
		user.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}

	return nil
}

// GetByID retrieves a user by ID
func (r *userRepository) GetByID(id uuid.UUID) (*domain.User, error) {
	query := `
		SELECT id, email, password_hash, display_name, role, phone, profile_photo_url, team_id,
		       is_online, last_active_at, verification_status, verified_by, verified_at,
		       rejection_reason, created_at, updated_at
		FROM users
		WHERE id = $1
	`

	user := &domain.User{}
	err := r.db.QueryRow(query, id).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.DisplayName,
		&user.Role,
		&user.Phone,
		&user.ProfilePhotoURL,
		&user.TeamID,
		&user.IsOnline,
		&user.LastActiveAt,
		&user.VerificationStatus,
		&user.VerifiedBy,
		&user.VerifiedAt,
		&user.RejectionReason,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return user, nil
}

// GetByEmail retrieves a user by email
func (r *userRepository) GetByEmail(email string) (*domain.User, error) {
	query := `
		SELECT id, email, password_hash, display_name, role, phone, profile_photo_url, team_id,
		       is_online, last_active_at, verification_status, verified_by, verified_at,
		       rejection_reason, created_at, updated_at
		FROM users
		WHERE email = $1
	`

	user := &domain.User{}
	err := r.db.QueryRow(query, email).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.DisplayName,
		&user.Role,
		&user.Phone,
		&user.ProfilePhotoURL,
		&user.TeamID,
		&user.IsOnline,
		&user.LastActiveAt,
		&user.VerificationStatus,
		&user.VerifiedBy,
		&user.VerifiedAt,
		&user.RejectionReason,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return user, nil
}

// Update updates a user
func (r *userRepository) Update(user *domain.User) error {
	query := `
		UPDATE users 
		SET display_name = $2, phone = $3, profile_photo_url = $4, team_id = $5, is_online = $6, last_active_at = $7, updated_at = $8
		WHERE id = $1
	`
	
	user.UpdatedAt = time.Now()
	
	_, err := r.db.Exec(
		query,
		user.ID,
		user.DisplayName,
		user.Phone,
		user.ProfilePhotoURL,
		user.TeamID,
		user.IsOnline,
		user.LastActiveAt,
		user.UpdatedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}
	
	return nil
}

// Delete deletes a user
func (r *userRepository) Delete(id uuid.UUID) error {
	query := `DELETE FROM users WHERE id = $1`
	
	result, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}
	
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	
	if rowsAffected == 0 {
		return fmt.Errorf("user not found")
	}
	
	return nil
}

// GetByTeamID retrieves users by team ID
func (r *userRepository) GetByTeamID(teamID uuid.UUID) ([]*domain.User, error) {
	query := `
		SELECT id, email, password_hash, display_name, role, phone, profile_photo_url, team_id,
		       is_online, last_active_at, verification_status, verified_by, verified_at,
		       rejection_reason, created_at, updated_at
		FROM users
		WHERE team_id = $1
		ORDER BY display_name
	`

	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get users by team: %w", err)
	}
	defer rows.Close()

	var users []*domain.User
	for rows.Next() {
		user := &domain.User{}
		err := rows.Scan(
			&user.ID,
			&user.Email,
			&user.PasswordHash,
			&user.DisplayName,
			&user.Role,
			&user.Phone,
			&user.ProfilePhotoURL,
			&user.TeamID,
			&user.IsOnline,
			&user.LastActiveAt,
			&user.VerificationStatus,
			&user.VerifiedBy,
			&user.VerifiedAt,
			&user.RejectionReason,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user: %w", err)
		}
		users = append(users, user)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate users: %w", err)
	}

	return users, nil
}

// UpdateLastActive updates the last active timestamp
func (r *userRepository) UpdateLastActive(id uuid.UUID) error {
	query := `UPDATE users SET last_active_at = $2, updated_at = $2 WHERE id = $1`
	
	now := time.Now()
	_, err := r.db.Exec(query, id, now)
	if err != nil {
		return fmt.Errorf("failed to update last active: %w", err)
	}
	
	return nil
}

// SetOnlineStatus sets the online status of a user
func (r *userRepository) SetOnlineStatus(id uuid.UUID, isOnline bool) error {
	query := `UPDATE users SET is_online = $2, last_active_at = $3, updated_at = $3 WHERE id = $1`

	now := time.Now()
	_, err := r.db.Exec(query, id, isOnline, now)
	if err != nil {
		return fmt.Errorf("failed to set online status: %w", err)
	}

	return nil
}

// GetByRole retrieves users by role
func (r *userRepository) GetByRole(role string) ([]*domain.User, error) {
	query := `
		SELECT id, email, password_hash, display_name, role, phone, profile_photo_url, team_id,
		       is_online, last_active_at, verification_status, verified_by, verified_at,
		       rejection_reason, created_at, updated_at
		FROM users
		WHERE role = $1
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(query, role)
	if err != nil {
		return nil, fmt.Errorf("failed to get users by role: %w", err)
	}
	defer rows.Close()

	var users []*domain.User
	for rows.Next() {
		user := &domain.User{}
		err := rows.Scan(
			&user.ID,
			&user.Email,
			&user.PasswordHash,
			&user.DisplayName,
			&user.Role,
			&user.Phone,
			&user.ProfilePhotoURL,
			&user.TeamID,
			&user.IsOnline,
			&user.LastActiveAt,
			&user.VerificationStatus,
			&user.VerifiedBy,
			&user.VerifiedAt,
			&user.RejectionReason,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user: %w", err)
		}
		users = append(users, user)
	}

	return users, nil
}

// GetByRoleAndStatus retrieves users by role and verification status
func (r *userRepository) GetByRoleAndStatus(role, status string) ([]*domain.User, error) {
	query := `
		SELECT id, email, password_hash, display_name, role, phone, profile_photo_url, team_id,
		       is_online, last_active_at, verification_status, verified_by, verified_at,
		       rejection_reason, created_at, updated_at
		FROM users
		WHERE role = $1 AND verification_status = $2
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(query, role, status)
	if err != nil {
		return nil, fmt.Errorf("failed to get users by role and status: %w", err)
	}
	defer rows.Close()

	var users []*domain.User
	for rows.Next() {
		user := &domain.User{}
		err := rows.Scan(
			&user.ID,
			&user.Email,
			&user.PasswordHash,
			&user.DisplayName,
			&user.Role,
			&user.Phone,
			&user.ProfilePhotoURL,
			&user.TeamID,
			&user.IsOnline,
			&user.LastActiveAt,
			&user.VerificationStatus,
			&user.VerifiedBy,
			&user.VerifiedAt,
			&user.RejectionReason,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user: %w", err)
		}
		users = append(users, user)
	}

	return users, nil
}

// UpdateVerificationStatus updates a user's verification status
func (r *userRepository) UpdateVerificationStatus(userID uuid.UUID, status string, verifiedBy *uuid.UUID, reason *string) error {
	now := time.Now()
	query := `
		UPDATE users
		SET verification_status = $2, verified_by = $3, verified_at = $4, rejection_reason = $5, updated_at = $6
		WHERE id = $1
	`

	var verifiedAt *time.Time
	if status == domain.VerificationVerified || status == domain.VerificationRejected {
		verifiedAt = &now
	}

	result, err := r.db.Exec(query, userID, status, verifiedBy, verifiedAt, reason, now)
	if err != nil {
		return fmt.Errorf("failed to update verification status: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("user not found")
	}

	return nil
}

// UpdatePassword updates a user's password
func (r *userRepository) UpdatePassword(userID uuid.UUID, passwordHash string) error {
	query := `UPDATE users SET password_hash = $2, updated_at = $3 WHERE id = $1`

	result, err := r.db.Exec(query, userID, passwordHash, time.Now())
	if err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("user not found")
	}

	return nil
}
