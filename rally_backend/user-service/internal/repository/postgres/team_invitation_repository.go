package postgres

import (
	"database/sql"
	"fmt"
	"rally-point/user-service/internal/domain"
	"time"

	"github.com/google/uuid"
)

type TeamInvitationRepository struct {
	db *sql.DB
}

func NewTeamInvitationRepository(db *sql.DB) *TeamInvitationRepository {
	return &TeamInvitationRepository{db: db}
}

// Create creates a new invitation
func (r *TeamInvitationRepository) Create(invitation *domain.TeamInvitation) error {
	query := `
		INSERT INTO team_invitations (id, team_id, inviter_id, invitee_email, token_hash, status, expires_at, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	now := time.Now()
	invitation.CreatedAt = now
	invitation.UpdatedAt = now

	_, err := r.db.Exec(query,
		invitation.ID,
		invitation.TeamID,
		invitation.InviterID,
		invitation.InviteeEmail,
		invitation.TokenHash,
		invitation.Status,
		invitation.ExpiresAt,
		invitation.CreatedAt,
		invitation.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create team invitation: %w", err)
	}

	return nil
}

// GetByTokenHash finds an invitation by its token hash
func (r *TeamInvitationRepository) GetByTokenHash(tokenHash string) (*domain.TeamInvitation, error) {
	query := `
		SELECT
			ti.id, ti.team_id, ti.inviter_id, ti.invitee_email, ti.invitee_id,
			ti.token_hash, ti.status, ti.expires_at, ti.accepted_at, ti.created_at, ti.updated_at,
			t.name as team_name, u.display_name as inviter_name
		FROM team_invitations ti
		LEFT JOIN teams t ON ti.team_id = t.id
		LEFT JOIN users u ON ti.inviter_id = u.id
		WHERE ti.token_hash = $1
	`

	invitation := &domain.TeamInvitation{}
	var inviteeID sql.NullString
	var acceptedAt sql.NullTime
	var teamName sql.NullString
	var inviterName sql.NullString

	err := r.db.QueryRow(query, tokenHash).Scan(
		&invitation.ID,
		&invitation.TeamID,
		&invitation.InviterID,
		&invitation.InviteeEmail,
		&inviteeID,
		&invitation.TokenHash,
		&invitation.Status,
		&invitation.ExpiresAt,
		&acceptedAt,
		&invitation.CreatedAt,
		&invitation.UpdatedAt,
		&teamName,
		&inviterName,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("invitation not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get invitation: %w", err)
	}

	if inviteeID.Valid {
		id, _ := uuid.Parse(inviteeID.String)
		invitation.InviteeID = &id
	}
	if acceptedAt.Valid {
		invitation.AcceptedAt = &acceptedAt.Time
	}
	if teamName.Valid {
		invitation.TeamName = teamName.String
	}
	if inviterName.Valid {
		invitation.InviterName = inviterName.String
	}

	return invitation, nil
}

// GetByID finds an invitation by its ID
func (r *TeamInvitationRepository) GetByID(id uuid.UUID) (*domain.TeamInvitation, error) {
	query := `
		SELECT
			ti.id, ti.team_id, ti.inviter_id, ti.invitee_email, ti.invitee_id,
			ti.token_hash, ti.status, ti.expires_at, ti.accepted_at, ti.created_at, ti.updated_at,
			t.name as team_name, u.display_name as inviter_name
		FROM team_invitations ti
		LEFT JOIN teams t ON ti.team_id = t.id
		LEFT JOIN users u ON ti.inviter_id = u.id
		WHERE ti.id = $1
	`

	invitation := &domain.TeamInvitation{}
	var inviteeID sql.NullString
	var acceptedAt sql.NullTime
	var teamName sql.NullString
	var inviterName sql.NullString

	err := r.db.QueryRow(query, id).Scan(
		&invitation.ID,
		&invitation.TeamID,
		&invitation.InviterID,
		&invitation.InviteeEmail,
		&inviteeID,
		&invitation.TokenHash,
		&invitation.Status,
		&invitation.ExpiresAt,
		&acceptedAt,
		&invitation.CreatedAt,
		&invitation.UpdatedAt,
		&teamName,
		&inviterName,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("invitation not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get invitation: %w", err)
	}

	if inviteeID.Valid {
		id, _ := uuid.Parse(inviteeID.String)
		invitation.InviteeID = &id
	}
	if acceptedAt.Valid {
		invitation.AcceptedAt = &acceptedAt.Time
	}
	if teamName.Valid {
		invitation.TeamName = teamName.String
	}
	if inviterName.Valid {
		invitation.InviterName = inviterName.String
	}

	return invitation, nil
}

// GetByEmail finds all invitations for an email
func (r *TeamInvitationRepository) GetByEmail(email string) ([]*domain.TeamInvitation, error) {
	query := `
		SELECT
			ti.id, ti.team_id, ti.inviter_id, ti.invitee_email, ti.invitee_id,
			ti.token_hash, ti.status, ti.expires_at, ti.accepted_at, ti.created_at, ti.updated_at,
			t.name as team_name, u.display_name as inviter_name
		FROM team_invitations ti
		LEFT JOIN teams t ON ti.team_id = t.id
		LEFT JOIN users u ON ti.inviter_id = u.id
		WHERE LOWER(ti.invitee_email) = LOWER($1)
		ORDER BY ti.created_at DESC
	`

	rows, err := r.db.Query(query, email)
	if err != nil {
		return nil, fmt.Errorf("failed to get invitations by email: %w", err)
	}
	defer rows.Close()

	return r.scanInvitations(rows)
}

// GetPendingByEmailAndTeam finds a pending invitation for a specific email and team
func (r *TeamInvitationRepository) GetPendingByEmailAndTeam(email string, teamID uuid.UUID) (*domain.TeamInvitation, error) {
	query := `
		SELECT
			ti.id, ti.team_id, ti.inviter_id, ti.invitee_email, ti.invitee_id,
			ti.token_hash, ti.status, ti.expires_at, ti.accepted_at, ti.created_at, ti.updated_at,
			t.name as team_name, u.display_name as inviter_name
		FROM team_invitations ti
		LEFT JOIN teams t ON ti.team_id = t.id
		LEFT JOIN users u ON ti.inviter_id = u.id
		WHERE LOWER(ti.invitee_email) = LOWER($1)
			AND ti.team_id = $2
			AND ti.status = 'pending'
			AND ti.expires_at > NOW()
	`

	invitation := &domain.TeamInvitation{}
	var inviteeID sql.NullString
	var acceptedAt sql.NullTime
	var teamName sql.NullString
	var inviterName sql.NullString

	err := r.db.QueryRow(query, email, teamID).Scan(
		&invitation.ID,
		&invitation.TeamID,
		&invitation.InviterID,
		&invitation.InviteeEmail,
		&inviteeID,
		&invitation.TokenHash,
		&invitation.Status,
		&invitation.ExpiresAt,
		&acceptedAt,
		&invitation.CreatedAt,
		&invitation.UpdatedAt,
		&teamName,
		&inviterName,
	)

	if err == sql.ErrNoRows {
		return nil, nil // No pending invitation found
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get pending invitation: %w", err)
	}

	if inviteeID.Valid {
		id, _ := uuid.Parse(inviteeID.String)
		invitation.InviteeID = &id
	}
	if acceptedAt.Valid {
		invitation.AcceptedAt = &acceptedAt.Time
	}
	if teamName.Valid {
		invitation.TeamName = teamName.String
	}
	if inviterName.Valid {
		invitation.InviterName = inviterName.String
	}

	return invitation, nil
}

// GetByTeamID finds all invitations for a team
func (r *TeamInvitationRepository) GetByTeamID(teamID uuid.UUID) ([]*domain.TeamInvitation, error) {
	query := `
		SELECT
			ti.id, ti.team_id, ti.inviter_id, ti.invitee_email, ti.invitee_id,
			ti.token_hash, ti.status, ti.expires_at, ti.accepted_at, ti.created_at, ti.updated_at,
			t.name as team_name, u.display_name as inviter_name
		FROM team_invitations ti
		LEFT JOIN teams t ON ti.team_id = t.id
		LEFT JOIN users u ON ti.inviter_id = u.id
		WHERE ti.team_id = $1
		ORDER BY ti.created_at DESC
	`

	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get team invitations: %w", err)
	}
	defer rows.Close()

	return r.scanInvitations(rows)
}

// UpdateStatus updates the status of an invitation
func (r *TeamInvitationRepository) UpdateStatus(id uuid.UUID, status domain.InvitationStatus, inviteeID *uuid.UUID) error {
	var query string
	var args []interface{}

	if status == domain.InvitationStatusAccepted {
		query = `
			UPDATE team_invitations
			SET status = $1, invitee_id = $2, accepted_at = NOW(), updated_at = NOW()
			WHERE id = $3
		`
		args = []interface{}{status, inviteeID, id}
	} else {
		query = `
			UPDATE team_invitations
			SET status = $1, updated_at = NOW()
			WHERE id = $2
		`
		args = []interface{}{status, id}
	}

	result, err := r.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update invitation status: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("invitation not found")
	}

	return nil
}

// DeleteExpired removes expired invitations
func (r *TeamInvitationRepository) DeleteExpired() error {
	query := `
		UPDATE team_invitations
		SET status = 'expired', updated_at = NOW()
		WHERE status = 'pending' AND expires_at < NOW()
	`

	_, err := r.db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to mark expired invitations: %w", err)
	}

	return nil
}

// InvalidatePendingForEmailAndTeam invalidates existing pending invitations
func (r *TeamInvitationRepository) InvalidatePendingForEmailAndTeam(email string, teamID uuid.UUID) error {
	query := `
		UPDATE team_invitations
		SET status = 'expired', updated_at = NOW()
		WHERE LOWER(invitee_email) = LOWER($1)
			AND team_id = $2
			AND status = 'pending'
	`

	_, err := r.db.Exec(query, email, teamID)
	if err != nil {
		return fmt.Errorf("failed to invalidate pending invitations: %w", err)
	}

	return nil
}

// Helper function to scan multiple invitations
func (r *TeamInvitationRepository) scanInvitations(rows *sql.Rows) ([]*domain.TeamInvitation, error) {
	var invitations []*domain.TeamInvitation

	for rows.Next() {
		invitation := &domain.TeamInvitation{}
		var inviteeID sql.NullString
		var acceptedAt sql.NullTime
		var teamName sql.NullString
		var inviterName sql.NullString

		err := rows.Scan(
			&invitation.ID,
			&invitation.TeamID,
			&invitation.InviterID,
			&invitation.InviteeEmail,
			&inviteeID,
			&invitation.TokenHash,
			&invitation.Status,
			&invitation.ExpiresAt,
			&acceptedAt,
			&invitation.CreatedAt,
			&invitation.UpdatedAt,
			&teamName,
			&inviterName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan invitation: %w", err)
		}

		if inviteeID.Valid {
			id, _ := uuid.Parse(inviteeID.String)
			invitation.InviteeID = &id
		}
		if acceptedAt.Valid {
			invitation.AcceptedAt = &acceptedAt.Time
		}
		if teamName.Valid {
			invitation.TeamName = teamName.String
		}
		if inviterName.Valid {
			invitation.InviterName = inviterName.String
		}

		invitations = append(invitations, invitation)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating invitations: %w", err)
	}

	return invitations, nil
}
