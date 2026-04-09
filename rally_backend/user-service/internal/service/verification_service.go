package service

import (
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

type verificationService struct {
	userRepo    domain.UserRepository
	tokenRepo   domain.VerificationTokenRepository
	sessionRepo domain.SessionRepository
	emailClient *email.EmailClient
	templates   *email.EmailTemplates
}

// NewVerificationService creates a new verification service
func NewVerificationService(
	userRepo domain.UserRepository,
	tokenRepo domain.VerificationTokenRepository,
	sessionRepo domain.SessionRepository,
) domain.VerificationService {
	return &verificationService{
		userRepo:    userRepo,
		tokenRepo:   tokenRepo,
		sessionRepo: sessionRepo,
		emailClient: email.NewEmailClient(),
		templates:   email.NewEmailTemplates(),
	}
}

// SendVerificationEmail sends a verification email to a user
func (s *verificationService) SendVerificationEmail(userID uuid.UUID) error {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	if user.EmailVerified {
		return fmt.Errorf("email already verified")
	}

	// Generate secure token
	plainToken, err := utils.GenerateSecureToken(32) // 64 character hex string
	if err != nil {
		return fmt.Errorf("failed to generate token: %w", err)
	}

	// Hash token for storage
	tokenHash := utils.HashSHA256(plainToken)

	// Create token record
	token := &domain.VerificationToken{
		ID:        uuid.New(),
		UserID:    userID,
		TokenHash: tokenHash,
		TokenType: domain.TokenTypeEmailVerification,
		ExpiresAt: time.Now().Add(domain.EmailVerificationExpiry),
		CreatedAt: time.Now(),
	}

	if err = s.tokenRepo.Create(token); err != nil {
		return fmt.Errorf("failed to create token: %w", err)
	}

	// Generate email content
	verificationURL := s.templates.GetVerificationURL(plainToken)
	htmlContent, textContent, err := s.templates.GenerateVerificationEmail(email.VerificationEmailData{
		UserName:        user.DisplayName,
		VerificationURL: verificationURL,
		ExpiryHours:     24,
	})
	if err != nil {
		return fmt.Errorf("failed to generate email: %w", err)
	}

	// Send email
	if !s.emailClient.IsConfigured() {
		// In development, log the verification URL
		if os.Getenv("GO_ENV") == "development" || os.Getenv("GO_ENV") == "" {
			log.Printf("📧 [DEV] Verification email for %s:\n   URL: %s\n", user.Email, verificationURL)
			return nil
		}
		return fmt.Errorf("email service not configured")
	}

	if err = s.emailClient.SendEmail(user.Email, "Verify Your Email - Rally Point", htmlContent, textContent); err != nil {
		// Check if auto-verify bypass is enabled
		if os.Getenv("AUTO_VERIFY_EMAIL") == "true" {
			log.Printf("⚠️ Email failed, AUTO_VERIFY_EMAIL enabled - auto-verifying user %s\n", utils.MaskEmail(user.Email))
			if verifyErr := s.userRepo.UpdateEmailVerified(userID, true); verifyErr != nil {
				log.Printf("❌ Failed to auto-verify: %v\n", verifyErr)
			} else {
				log.Printf("✅ User %s auto-verified (email bypass)\n", utils.MaskEmail(user.Email))
				return nil
			}
		}
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("📧 Verification email sent to %s\n", utils.MaskEmail(user.Email))
	return nil
}

// ResendVerificationEmail resends verification email to a user by email
func (s *verificationService) ResendVerificationEmail(emailAddr string) error {
	user, err := s.userRepo.GetByEmail(emailAddr)
	if err != nil {
		// Don't reveal if email exists - silently succeed
		log.Printf("📧 Resend verification requested for non-existent email: %s\n", utils.MaskEmail(emailAddr))
		return nil
	}

	if user.EmailVerified {
		// Don't reveal if already verified - silently succeed
		log.Printf("📧 Resend verification requested for already verified email: %s\n", utils.MaskEmail(emailAddr))
		return nil
	}

	return s.SendVerificationEmail(user.ID)
}

// VerifyEmail verifies a user's email using the token
func (s *verificationService) VerifyEmail(plainToken string) error {
	// Hash the provided token
	tokenHash := utils.HashSHA256(plainToken)

	// Get token from database
	token, err := s.tokenRepo.GetByTokenHash(tokenHash)
	if err != nil {
		return fmt.Errorf("invalid or expired verification link")
	}

	if token.TokenType != domain.TokenTypeEmailVerification {
		return fmt.Errorf("invalid token type")
	}

	// Get user
	user, err := s.userRepo.GetByID(token.UserID)
	if err != nil {
		return fmt.Errorf("user not found")
	}

	if user.EmailVerified {
		return fmt.Errorf("email already verified")
	}

	// Mark email as verified
	if err = s.userRepo.UpdateEmailVerified(token.UserID, true); err != nil {
		return fmt.Errorf("failed to verify email: %w", err)
	}

	// Mark token as used
	if err = s.tokenRepo.MarkAsUsed(token.ID); err != nil {
		log.Printf("Warning: failed to mark token as used: %v\n", err)
	}

	log.Printf("✅ Email verified for user %s\n", utils.MaskEmail(user.Email))
	return nil
}

// RequestPasswordReset initiates a password reset for a user
func (s *verificationService) RequestPasswordReset(emailAddr string) error {
	user, err := s.userRepo.GetByEmail(emailAddr)
	if err != nil {
		// Don't reveal if email exists - always return success
		log.Printf("Password reset requested for non-existent email: %s\n", utils.MaskEmail(emailAddr))
		return nil
	}

	// Generate secure token
	plainToken, err := utils.GenerateSecureToken(32) // 64 character hex string
	if err != nil {
		return fmt.Errorf("failed to generate token: %w", err)
	}

	// Hash token for storage
	tokenHash := utils.HashSHA256(plainToken)

	// Create token record
	token := &domain.VerificationToken{
		ID:        uuid.New(),
		UserID:    user.ID,
		TokenHash: tokenHash,
		TokenType: domain.TokenTypePasswordReset,
		ExpiresAt: time.Now().Add(domain.PasswordResetExpiry),
		CreatedAt: time.Now(),
	}

	if err = s.tokenRepo.Create(token); err != nil {
		return fmt.Errorf("failed to create token: %w", err)
	}

	// Generate email content
	resetURL := s.templates.GetPasswordResetURL(plainToken)
	htmlContent, textContent, err := s.templates.GeneratePasswordResetEmail(email.PasswordResetEmailData{
		UserName:      user.DisplayName,
		ResetURL:      resetURL,
		ExpiryMinutes: 60,
	})
	if err != nil {
		return fmt.Errorf("failed to generate email: %w", err)
	}

	// Send email
	if !s.emailClient.IsConfigured() {
		// In development, log the reset URL
		if os.Getenv("GO_ENV") == "development" || os.Getenv("GO_ENV") == "" {
			log.Printf("📧 [DEV] Password reset email for %s:\n   URL: %s\n", user.Email, resetURL)
			return nil
		}
		return fmt.Errorf("email service not configured")
	}

	if err = s.emailClient.SendEmail(user.Email, "Reset Your Password - Rally Point", htmlContent, textContent); err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("📧 Password reset email sent to %s\n", utils.MaskEmail(user.Email))
	return nil
}

// ResetPassword resets a user's password using the token
func (s *verificationService) ResetPassword(plainToken, newPassword string) error {
	// Validate password strength
	if len(newPassword) < 8 {
		return fmt.Errorf("password must be at least 8 characters")
	}

	// Hash the provided token
	tokenHash := utils.HashSHA256(plainToken)

	// Get token from database
	token, err := s.tokenRepo.GetByTokenHash(tokenHash)
	if err != nil {
		return fmt.Errorf("invalid or expired reset link")
	}

	if token.TokenType != domain.TokenTypePasswordReset {
		return fmt.Errorf("invalid token type")
	}

	// Hash new password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update password
	if err = s.userRepo.UpdatePassword(token.UserID, string(hashedPassword)); err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	// Mark token as used
	if err = s.tokenRepo.MarkAsUsed(token.ID); err != nil {
		log.Printf("Warning: failed to mark token as used: %v\n", err)
	}

	// Invalidate all user sessions (force re-login)
	if s.sessionRepo != nil {
		if err = s.sessionRepo.DeleteByUserID(token.UserID); err != nil {
			log.Printf("Warning: failed to invalidate user sessions: %v\n", err)
		}
	}

	log.Printf("✅ Password reset completed for user %s\n", token.UserID)
	return nil
}

// InvalidateUserTokens invalidates all tokens of a specific type for a user
func (s *verificationService) InvalidateUserTokens(userID uuid.UUID, tokenType string) error {
	return s.tokenRepo.DeleteByUserAndType(userID, tokenType)
}
