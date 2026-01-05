package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
)

type sessionRepository struct {
	db *sql.DB
}

// NewSessionRepository creates a new session repository
func NewSessionRepository(db *sql.DB) domain.SessionRepository {
	return &sessionRepository{db: db}
}

// Create creates a new session or updates existing one
func (r *sessionRepository) Create(session *domain.UserSession) error {
	// Use upsert to handle both create and update
	query := `
		INSERT INTO user_sessions (id, user_id, refresh_token, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (id) DO UPDATE SET
			refresh_token = EXCLUDED.refresh_token,
			expires_at = EXCLUDED.expires_at
	`

	_, err := r.db.Exec(
		query,
		session.ID,
		session.UserID,
		session.RefreshToken,
		session.ExpiresAt,
		session.CreatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create session: %w", err)
	}

	return nil
}

// GetByRefreshToken retrieves a session by refresh token
func (r *sessionRepository) GetByRefreshToken(token string) (*domain.UserSession, error) {
	query := `
		SELECT id, user_id, refresh_token, expires_at, created_at
		FROM user_sessions
		WHERE refresh_token = $1
	`

	session := &domain.UserSession{}
	err := r.db.QueryRow(query, token).Scan(
		&session.ID,
		&session.UserID,
		&session.RefreshToken,
		&session.ExpiresAt,
		&session.CreatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("session not found")
		}
		return nil, fmt.Errorf("failed to get session: %w", err)
	}

	return session, nil
}

// DeleteByUserID deletes all sessions for a user
func (r *sessionRepository) DeleteByUserID(userID uuid.UUID) error {
	query := `DELETE FROM user_sessions WHERE user_id = $1`

	_, err := r.db.Exec(query, userID)
	if err != nil {
		return fmt.Errorf("failed to delete sessions: %w", err)
	}

	return nil
}

// DeleteExpired deletes all expired sessions
func (r *sessionRepository) DeleteExpired() error {
	query := `DELETE FROM user_sessions WHERE expires_at < $1`

	_, err := r.db.Exec(query, time.Now())
	if err != nil {
		return fmt.Errorf("failed to delete expired sessions: %w", err)
	}

	return nil
}
