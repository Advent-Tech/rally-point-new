package domain

import (
	"time"

	"github.com/google/uuid"
)

// Token type constants
const (
	TokenTypeEmailVerification = "email_verification"
	TokenTypePasswordReset     = "password_reset"
)

// Token expiry durations
const (
	EmailVerificationExpiry = 24 * time.Hour
	PasswordResetExpiry     = 1 * time.Hour
)

// VerificationToken represents an email verification or password reset token
type VerificationToken struct {
	ID        uuid.UUID  `json:"id" db:"id"`
	UserID    uuid.UUID  `json:"user_id" db:"user_id"`
	TokenHash string     `json:"-" db:"token_hash"`
	TokenType string     `json:"token_type" db:"token_type"`
	ExpiresAt time.Time  `json:"expires_at" db:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty" db:"used_at"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
}

// IsExpired checks if the token has expired
func (t *VerificationToken) IsExpired() bool {
	return time.Now().After(t.ExpiresAt)
}

// IsUsed checks if the token has been used
func (t *VerificationToken) IsUsed() bool {
	return t.UsedAt != nil
}

// IsValid checks if the token is still valid (not expired and not used)
func (t *VerificationToken) IsValid() bool {
	return !t.IsExpired() && !t.IsUsed()
}

// Request DTOs

// RequestEmailVerificationRequest represents the request to resend verification email
type RequestEmailVerificationRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// VerifyEmailRequest represents the request to verify email
type VerifyEmailRequest struct {
	Token string `json:"token" binding:"required"`
}

// ForgotPasswordRequest represents the forgot password request
type ForgotPasswordRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// TokenResetPasswordRequest represents the public password reset request (with token)
type TokenResetPasswordRequest struct {
	Token       string `json:"token" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

// Response DTOs

// VerificationResponse represents the response for verification operations
type VerificationResponse struct {
	Message string `json:"message"`
	Success bool   `json:"success"`
}

// VerificationTokenRepository defines the interface for token data access
type VerificationTokenRepository interface {
	// Create creates a new verification token (invalidates existing tokens of same type)
	Create(token *VerificationToken) error

	// GetByTokenHash retrieves a valid (not used, not expired) token by its hash
	GetByTokenHash(tokenHash string) (*VerificationToken, error)

	// GetActiveByUserAndType retrieves the active token for a user and type
	GetActiveByUserAndType(userID uuid.UUID, tokenType string) (*VerificationToken, error)

	// MarkAsUsed marks a token as used
	MarkAsUsed(id uuid.UUID) error

	// DeleteByUserAndType deletes all tokens of a specific type for a user
	DeleteByUserAndType(userID uuid.UUID, tokenType string) error

	// DeleteExpired deletes all expired and used tokens
	DeleteExpired() (int64, error)
}

// VerificationService defines the interface for verification business logic
type VerificationService interface {
	// Email Verification
	SendVerificationEmail(userID uuid.UUID) error
	ResendVerificationEmail(email string) error
	VerifyEmail(token string) error

	// Password Reset
	RequestPasswordReset(email string) error
	ResetPassword(token, newPassword string) error

	// Token Management
	InvalidateUserTokens(userID uuid.UUID, tokenType string) error
}
