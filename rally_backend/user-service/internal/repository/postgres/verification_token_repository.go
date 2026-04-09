package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/user-service/internal/domain"
)

type verificationTokenRepository struct {
	db *sql.DB
}

// NewVerificationTokenRepository creates a new verification token repository
func NewVerificationTokenRepository(db *sql.DB) domain.VerificationTokenRepository {
	return &verificationTokenRepository{db: db}
}

// Create creates a new verification token (invalidates existing tokens of same type)
func (r *verificationTokenRepository) Create(token *domain.VerificationToken) error {
	// First, invalidate any existing active tokens of the same type for this user
	invalidateQuery := `
		UPDATE verification_tokens
		SET used_at = NOW()
		WHERE user_id = $1 AND token_type = $2 AND used_at IS NULL
	`
	_, err := r.db.Exec(invalidateQuery, token.UserID, token.TokenType)
	if err != nil {
		return fmt.Errorf("failed to invalidate existing tokens: %w", err)
	}

	// Create the new token
	query := `
		INSERT INTO verification_tokens (id, user_id, token_hash, token_type, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err = r.db.Exec(
		query,
		token.ID,
		token.UserID,
		token.TokenHash,
		token.TokenType,
		token.ExpiresAt,
		token.CreatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create verification token: %w", err)
	}

	return nil
}

// GetByTokenHash retrieves a valid (not used, not expired) token by its hash
func (r *verificationTokenRepository) GetByTokenHash(tokenHash string) (*domain.VerificationToken, error) {
	query := `
		SELECT id, user_id, token_hash, token_type, expires_at, used_at, created_at
		FROM verification_tokens
		WHERE token_hash = $1 AND used_at IS NULL AND expires_at > NOW()
	`

	token := &domain.VerificationToken{}
	err := r.db.QueryRow(query, tokenHash).Scan(
		&token.ID,
		&token.UserID,
		&token.TokenHash,
		&token.TokenType,
		&token.ExpiresAt,
		&token.UsedAt,
		&token.CreatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("token not found or expired")
		}
		return nil, fmt.Errorf("failed to get token: %w", err)
	}

	return token, nil
}

// GetActiveByUserAndType retrieves the active token for a user and type
func (r *verificationTokenRepository) GetActiveByUserAndType(userID uuid.UUID, tokenType string) (*domain.VerificationToken, error) {
	query := `
		SELECT id, user_id, token_hash, token_type, expires_at, used_at, created_at
		FROM verification_tokens
		WHERE user_id = $1 AND token_type = $2 AND used_at IS NULL AND expires_at > NOW()
		ORDER BY created_at DESC
		LIMIT 1
	`

	token := &domain.VerificationToken{}
	err := r.db.QueryRow(query, userID, tokenType).Scan(
		&token.ID,
		&token.UserID,
		&token.TokenHash,
		&token.TokenType,
		&token.ExpiresAt,
		&token.UsedAt,
		&token.CreatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("no active token found")
		}
		return nil, fmt.Errorf("failed to get token: %w", err)
	}

	return token, nil
}

// MarkAsUsed marks a token as used
func (r *verificationTokenRepository) MarkAsUsed(id uuid.UUID) error {
	query := `UPDATE verification_tokens SET used_at = $2 WHERE id = $1`

	result, err := r.db.Exec(query, id, time.Now())
	if err != nil {
		return fmt.Errorf("failed to mark token as used: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("token not found")
	}

	return nil
}

// DeleteByUserAndType deletes all tokens of a specific type for a user
func (r *verificationTokenRepository) DeleteByUserAndType(userID uuid.UUID, tokenType string) error {
	query := `DELETE FROM verification_tokens WHERE user_id = $1 AND token_type = $2`

	_, err := r.db.Exec(query, userID, tokenType)
	if err != nil {
		return fmt.Errorf("failed to delete tokens: %w", err)
	}

	return nil
}

// DeleteExpired deletes all expired and used tokens
func (r *verificationTokenRepository) DeleteExpired() (int64, error) {
	query := `DELETE FROM verification_tokens WHERE expires_at < NOW() OR used_at IS NOT NULL`

	result, err := r.db.Exec(query)
	if err != nil {
		return 0, fmt.Errorf("failed to delete expired tokens: %w", err)
	}

	return result.RowsAffected()
}
