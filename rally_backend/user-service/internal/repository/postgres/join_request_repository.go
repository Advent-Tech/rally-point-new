package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/user-service/internal/domain"
)

type joinRequestRepository struct {
	db *sql.DB
}

// NewJoinRequestRepository creates a new join request repository
func NewJoinRequestRepository(db *sql.DB) domain.JoinRequestRepository {
	return &joinRequestRepository{db: db}
}

// Create creates a new join request
func (r *joinRequestRepository) Create(request *domain.TeamJoinRequest) error {
	query := `
		INSERT INTO team_join_requests (id, user_id, team_id, status, message, requested_at, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := r.db.Exec(
		query,
		request.ID,
		request.UserID,
		request.TeamID,
		request.Status,
		request.Message,
		request.RequestedAt,
		request.CreatedAt,
		request.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create join request: %w", err)
	}

	return nil
}

// GetByID retrieves a join request by ID
func (r *joinRequestRepository) GetByID(id uuid.UUID) (*domain.TeamJoinRequest, error) {
	query := `
		SELECT id, user_id, team_id, status, message, requested_at, reviewed_by, reviewed_at,
		       rejection_reason, created_at, updated_at
		FROM team_join_requests
		WHERE id = $1
	`

	request := &domain.TeamJoinRequest{}
	err := r.db.QueryRow(query, id).Scan(
		&request.ID,
		&request.UserID,
		&request.TeamID,
		&request.Status,
		&request.Message,
		&request.RequestedAt,
		&request.ReviewedBy,
		&request.ReviewedAt,
		&request.RejectionReason,
		&request.CreatedAt,
		&request.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("join request not found")
		}
		return nil, fmt.Errorf("failed to get join request: %w", err)
	}

	return request, nil
}

// GetByUserID retrieves all join requests for a user
func (r *joinRequestRepository) GetByUserID(userID uuid.UUID) ([]*domain.TeamJoinRequest, error) {
	query := `
		SELECT jr.id, jr.user_id, jr.team_id, jr.status, jr.message, jr.requested_at,
		       jr.reviewed_by, jr.reviewed_at, jr.rejection_reason, jr.created_at, jr.updated_at,
		       t.name as team_name
		FROM team_join_requests jr
		LEFT JOIN teams t ON t.id = jr.team_id
		WHERE jr.user_id = $1
		ORDER BY jr.requested_at DESC
	`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get join requests: %w", err)
	}
	defer rows.Close()

	var requests []*domain.TeamJoinRequest
	for rows.Next() {
		request := &domain.TeamJoinRequest{}
		var teamName sql.NullString
		err := rows.Scan(
			&request.ID,
			&request.UserID,
			&request.TeamID,
			&request.Status,
			&request.Message,
			&request.RequestedAt,
			&request.ReviewedBy,
			&request.ReviewedAt,
			&request.RejectionReason,
			&request.CreatedAt,
			&request.UpdatedAt,
			&teamName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan join request: %w", err)
		}
		if teamName.Valid {
			request.Team = &domain.Team{ID: request.TeamID, Name: teamName.String}
		}
		requests = append(requests, request)
	}

	return requests, nil
}

// GetByTeamID retrieves all join requests for a team
func (r *joinRequestRepository) GetByTeamID(teamID uuid.UUID) ([]*domain.TeamJoinRequest, error) {
	query := `
		SELECT jr.id, jr.user_id, jr.team_id, jr.status, jr.message, jr.requested_at,
		       jr.reviewed_by, jr.reviewed_at, jr.rejection_reason, jr.created_at, jr.updated_at,
		       u.display_name, u.email, u.phone, u.profile_photo_url
		FROM team_join_requests jr
		LEFT JOIN users u ON u.id = jr.user_id
		WHERE jr.team_id = $1
		ORDER BY jr.requested_at DESC
	`

	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get join requests: %w", err)
	}
	defer rows.Close()

	var requests []*domain.TeamJoinRequest
	for rows.Next() {
		request := &domain.TeamJoinRequest{}
		var displayName, email sql.NullString
		var phone, profilePhoto sql.NullString
		err := rows.Scan(
			&request.ID,
			&request.UserID,
			&request.TeamID,
			&request.Status,
			&request.Message,
			&request.RequestedAt,
			&request.ReviewedBy,
			&request.ReviewedAt,
			&request.RejectionReason,
			&request.CreatedAt,
			&request.UpdatedAt,
			&displayName,
			&email,
			&phone,
			&profilePhoto,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan join request: %w", err)
		}
		if displayName.Valid {
			user := &domain.User{
				ID:          request.UserID,
				DisplayName: displayName.String,
				Email:       email.String,
			}
			if phone.Valid {
				user.Phone = &phone.String
			}
			if profilePhoto.Valid {
				user.ProfilePhotoURL = &profilePhoto.String
			}
			request.User = user
		}
		requests = append(requests, request)
	}

	return requests, nil
}

// GetPendingByTeamID retrieves pending join requests for a team
func (r *joinRequestRepository) GetPendingByTeamID(teamID uuid.UUID) ([]*domain.TeamJoinRequest, error) {
	query := `
		SELECT jr.id, jr.user_id, jr.team_id, jr.status, jr.message, jr.requested_at,
		       jr.reviewed_by, jr.reviewed_at, jr.rejection_reason, jr.created_at, jr.updated_at,
		       u.display_name, u.email, u.phone, u.profile_photo_url
		FROM team_join_requests jr
		LEFT JOIN users u ON u.id = jr.user_id
		WHERE jr.team_id = $1 AND jr.status = 'pending'
		ORDER BY jr.requested_at ASC
	`

	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending join requests: %w", err)
	}
	defer rows.Close()

	var requests []*domain.TeamJoinRequest
	for rows.Next() {
		request := &domain.TeamJoinRequest{}
		var displayName, email sql.NullString
		var phone, profilePhoto sql.NullString
		err := rows.Scan(
			&request.ID,
			&request.UserID,
			&request.TeamID,
			&request.Status,
			&request.Message,
			&request.RequestedAt,
			&request.ReviewedBy,
			&request.ReviewedAt,
			&request.RejectionReason,
			&request.CreatedAt,
			&request.UpdatedAt,
			&displayName,
			&email,
			&phone,
			&profilePhoto,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan join request: %w", err)
		}
		if displayName.Valid {
			user := &domain.User{
				ID:          request.UserID,
				DisplayName: displayName.String,
				Email:       email.String,
			}
			if phone.Valid {
				user.Phone = &phone.String
			}
			if profilePhoto.Valid {
				user.ProfilePhotoURL = &profilePhoto.String
			}
			request.User = user
		}
		requests = append(requests, request)
	}

	return requests, nil
}

// GetByUserAndTeam retrieves a join request by user and team
func (r *joinRequestRepository) GetByUserAndTeam(userID, teamID uuid.UUID) (*domain.TeamJoinRequest, error) {
	query := `
		SELECT id, user_id, team_id, status, message, requested_at, reviewed_by, reviewed_at,
		       rejection_reason, created_at, updated_at
		FROM team_join_requests
		WHERE user_id = $1 AND team_id = $2
	`

	request := &domain.TeamJoinRequest{}
	err := r.db.QueryRow(query, userID, teamID).Scan(
		&request.ID,
		&request.UserID,
		&request.TeamID,
		&request.Status,
		&request.Message,
		&request.RequestedAt,
		&request.ReviewedBy,
		&request.ReviewedAt,
		&request.RejectionReason,
		&request.CreatedAt,
		&request.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("join request not found")
		}
		return nil, fmt.Errorf("failed to get join request: %w", err)
	}

	return request, nil
}

// Update updates a join request
func (r *joinRequestRepository) Update(request *domain.TeamJoinRequest) error {
	query := `
		UPDATE team_join_requests
		SET status = $2, reviewed_by = $3, reviewed_at = $4, rejection_reason = $5, updated_at = $6
		WHERE id = $1
	`

	request.UpdatedAt = time.Now()

	result, err := r.db.Exec(
		query,
		request.ID,
		request.Status,
		request.ReviewedBy,
		request.ReviewedAt,
		request.RejectionReason,
		request.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to update join request: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("join request not found")
	}

	return nil
}

// Delete deletes a join request
func (r *joinRequestRepository) Delete(id uuid.UUID) error {
	query := `DELETE FROM team_join_requests WHERE id = $1`

	result, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete join request: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("join request not found")
	}

	return nil
}

// GetPendingByUserID retrieves the pending join request for a user (only one allowed)
func (r *joinRequestRepository) GetPendingByUserID(userID uuid.UUID) (*domain.TeamJoinRequest, error) {
	query := `
		SELECT jr.id, jr.user_id, jr.team_id, jr.status, jr.message, jr.requested_at,
		       jr.reviewed_by, jr.reviewed_at, jr.rejection_reason, jr.created_at, jr.updated_at,
		       t.name as team_name
		FROM team_join_requests jr
		LEFT JOIN teams t ON t.id = jr.team_id
		WHERE jr.user_id = $1 AND jr.status = 'pending'
		LIMIT 1
	`

	request := &domain.TeamJoinRequest{}
	var teamName sql.NullString
	err := r.db.QueryRow(query, userID).Scan(
		&request.ID,
		&request.UserID,
		&request.TeamID,
		&request.Status,
		&request.Message,
		&request.RequestedAt,
		&request.ReviewedBy,
		&request.ReviewedAt,
		&request.RejectionReason,
		&request.CreatedAt,
		&request.UpdatedAt,
		&teamName,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // No pending request found
		}
		return nil, fmt.Errorf("failed to get pending join request: %w", err)
	}

	if teamName.Valid {
		request.Team = &domain.Team{ID: request.TeamID, Name: teamName.String}
	}

	return request, nil
}
