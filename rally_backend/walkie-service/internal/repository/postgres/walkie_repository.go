package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/walkie-service/internal/domain"
)

type walkieRepository struct {
	db *sql.DB
}

// NewWalkieRepository creates a new walkie repository
func NewWalkieRepository(db *sql.DB) domain.WalkieRepository {
	return &walkieRepository{db: db}
}

// CreateSession creates a new walkie-talkie session
func (r *walkieRepository) CreateSession(session *domain.WalkieSession) error {
	query := `
		INSERT INTO walkie_sessions (id, team_id, speaker_id, speaker_name, audio_url, duration, is_active, started_at, ended_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	
	_, err := r.db.Exec(
		query,
		session.ID,
		session.TeamID,
		session.SpeakerID,
		session.SpeakerName,
		session.AudioURL,
		session.Duration,
		session.IsActive,
		session.StartedAt,
		session.EndedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to create session: %w", err)
	}
	
	return nil
}

// GetSessionByID retrieves a session by ID
func (r *walkieRepository) GetSessionByID(id uuid.UUID) (*domain.WalkieSession, error) {
	query := `
		SELECT id, team_id, speaker_id, speaker_name, audio_url, duration, is_active, started_at, ended_at
		FROM walkie_sessions
		WHERE id = $1
	`
	
	session := &domain.WalkieSession{}
	err := r.db.QueryRow(query, id).Scan(
		&session.ID,
		&session.TeamID,
		&session.SpeakerID,
		&session.SpeakerName,
		&session.AudioURL,
		&session.Duration,
		&session.IsActive,
		&session.StartedAt,
		&session.EndedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("session not found")
		}
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	
	return session, nil
}

// GetActiveSession retrieves the active session for a team
func (r *walkieRepository) GetActiveSession(teamID uuid.UUID) (*domain.WalkieSession, error) {
	query := `
		SELECT id, team_id, speaker_id, speaker_name, audio_url, duration, is_active, started_at, ended_at
		FROM walkie_sessions
		WHERE team_id = $1 AND is_active = true
		ORDER BY started_at DESC
		LIMIT 1
	`
	
	session := &domain.WalkieSession{}
	err := r.db.QueryRow(query, teamID).Scan(
		&session.ID,
		&session.TeamID,
		&session.SpeakerID,
		&session.SpeakerName,
		&session.AudioURL,
		&session.Duration,
		&session.IsActive,
		&session.StartedAt,
		&session.EndedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // No active session
		}
		return nil, fmt.Errorf("failed to get active session: %w", err)
	}
	
	return session, nil
}

// UpdateSession updates a walkie-talkie session
func (r *walkieRepository) UpdateSession(session *domain.WalkieSession) error {
	query := `
		UPDATE walkie_sessions 
		SET audio_url = $2, duration = $3, is_active = $4, ended_at = $5
		WHERE id = $1
	`
	
	_, err := r.db.Exec(
		query,
		session.ID,
		session.AudioURL,
		session.Duration,
		session.IsActive,
		session.EndedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to update session: %w", err)
	}
	
	return nil
}

// EndSession ends a walkie-talkie session
func (r *walkieRepository) EndSession(sessionID uuid.UUID, audioURL *string, duration *int) error {
	query := `
		UPDATE walkie_sessions 
		SET audio_url = $2, duration = $3, is_active = false, ended_at = $4
		WHERE id = $1
	`
	
	now := time.Now()
	_, err := r.db.Exec(query, sessionID, audioURL, duration, now)
	if err != nil {
		return fmt.Errorf("failed to end session: %w", err)
	}
	
	return nil
}

// GetTeamSessions retrieves sessions for a team
func (r *walkieRepository) GetTeamSessions(teamID uuid.UUID, limit, offset int) ([]*domain.WalkieSession, error) {
	query := `
		SELECT id, team_id, speaker_id, speaker_name, audio_url, duration, is_active, started_at, ended_at
		FROM walkie_sessions
		WHERE team_id = $1
		ORDER BY started_at DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.db.Query(query, teamID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get team sessions: %w", err)
	}
	defer rows.Close()
	
	var sessions []*domain.WalkieSession
	for rows.Next() {
		session := &domain.WalkieSession{}
		err := rows.Scan(
			&session.ID,
			&session.TeamID,
			&session.SpeakerID,
			&session.SpeakerName,
			&session.AudioURL,
			&session.Duration,
			&session.IsActive,
			&session.StartedAt,
			&session.EndedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan session: %w", err)
		}
		sessions = append(sessions, session)
	}
	
	return sessions, nil
}

// CreateMessage creates a new walkie-talkie message
func (r *walkieRepository) CreateMessage(message *domain.WalkieMessage) error {
	query := `
		INSERT INTO walkie_messages (id, team_id, sender_id, sender_name, message, message_type, sent_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	
	_, err := r.db.Exec(
		query,
		message.ID,
		message.TeamID,
		message.SenderID,
		message.SenderName,
		message.Message,
		message.MessageType,
		message.SentAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to create message: %w", err)
	}
	
	return nil
}

// GetTeamMessages retrieves messages for a team
func (r *walkieRepository) GetTeamMessages(teamID uuid.UUID, limit, offset int) ([]*domain.WalkieMessage, error) {
	query := `
		SELECT id, team_id, sender_id, sender_name, message, message_type, sent_at
		FROM walkie_messages
		WHERE team_id = $1
		ORDER BY sent_at DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.db.Query(query, teamID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get team messages: %w", err)
	}
	defer rows.Close()
	
	var messages []*domain.WalkieMessage
	for rows.Next() {
		message := &domain.WalkieMessage{}
		err := rows.Scan(
			&message.ID,
			&message.TeamID,
			&message.SenderID,
			&message.SenderName,
			&message.Message,
			&message.MessageType,
			&message.SentAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan message: %w", err)
		}
		messages = append(messages, message)
	}
	
	return messages, nil
}

// DeleteMessage deletes a message
func (r *walkieRepository) DeleteMessage(id uuid.UUID) error {
	query := `DELETE FROM walkie_messages WHERE id = $1`
	
	result, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete message: %w", err)
	}
	
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	
	if rowsAffected == 0 {
		return fmt.Errorf("message not found")
	}
	
	return nil
}

// GetTeamMembers retrieves team members for walkie-talkie
func (r *walkieRepository) GetTeamMembers(teamID uuid.UUID) ([]*domain.TeamMember, error) {
	query := `
		SELECT u.id, u.display_name, u.email, u.is_online
		FROM users u
		WHERE u.team_id = $1
		ORDER BY u.display_name
	`
	
	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get team members: %w", err)
	}
	defer rows.Close()
	
	var members []*domain.TeamMember
	for rows.Next() {
		member := &domain.TeamMember{}
		err := rows.Scan(
			&member.UserID,
			&member.Name,
			&member.Email,
			&member.IsOnline,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan team member: %w", err)
		}
		members = append(members, member)
	}
	
	return members, nil
}

// IsUserInTeam checks if a user is in a team
func (r *walkieRepository) IsUserInTeam(userID, teamID uuid.UUID) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM users 
			WHERE id = $1 AND team_id = $2
		)
	`
	
	var exists bool
	err := r.db.QueryRow(query, userID, teamID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check user in team: %w", err)
	}
	
	return exists, nil
}
