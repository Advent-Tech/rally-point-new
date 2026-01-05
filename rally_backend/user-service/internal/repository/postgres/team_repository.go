package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
)

type teamRepository struct {
	db *sql.DB
}

// NewTeamRepository creates a new team repository
func NewTeamRepository(db *sql.DB) domain.TeamRepository {
	return &teamRepository{db: db}
}

// Create creates a new team
func (r *teamRepository) Create(team *domain.Team) error {
	query := `
		INSERT INTO teams (id, name, description, leader_id, photo_url, worker_count, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := r.db.Exec(
		query,
		team.ID,
		team.Name,
		team.Description,
		team.LeaderID,
		team.PhotoURL,
		team.WorkerCount,
		team.CreatedAt,
		team.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create team: %w", err)
	}

	return nil
}

// GetByID retrieves a team by ID
func (r *teamRepository) GetByID(id uuid.UUID) (*domain.Team, error) {
	query := `
		SELECT id, name, description, leader_id, photo_url, worker_count, created_at, updated_at
		FROM teams
		WHERE id = $1
	`

	team := &domain.Team{}
	var description sql.NullString
	var photoURL sql.NullString

	err := r.db.QueryRow(query, id).Scan(
		&team.ID,
		&team.Name,
		&description,
		&team.LeaderID,
		&photoURL,
		&team.WorkerCount,
		&team.CreatedAt,
		&team.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("team not found")
		}
		return nil, fmt.Errorf("failed to get team: %w", err)
	}

	// Handle nullable fields
	if description.Valid {
		team.Description = &description.String
	}
	if photoURL.Valid {
		team.PhotoURL = &photoURL.String
	}

	return team, nil
}

// GetByLeaderID retrieves teams by leader ID
func (r *teamRepository) GetByLeaderID(leaderID uuid.UUID) ([]*domain.Team, error) {
	query := `
		SELECT id, name, description, leader_id, photo_url, worker_count, created_at, updated_at
		FROM teams
		WHERE leader_id = $1
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(query, leaderID)
	if err != nil {
		return nil, fmt.Errorf("failed to get teams by leader: %w", err)
	}
	defer rows.Close()

	var teams []*domain.Team
	for rows.Next() {
		team := &domain.Team{}
		var description sql.NullString
		var photoURL sql.NullString

		err := rows.Scan(
			&team.ID,
			&team.Name,
			&description,
			&team.LeaderID,
			&photoURL,
			&team.WorkerCount,
			&team.CreatedAt,
			&team.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan team row: %w", err)
		}

		// Handle nullable fields
		if description.Valid {
			team.Description = &description.String
		}
		if photoURL.Valid {
			team.PhotoURL = &photoURL.String
		}

		teams = append(teams, team)
	}

	return teams, nil
}

// Update updates a team
func (r *teamRepository) Update(team *domain.Team) error {
	query := `
		UPDATE teams
		SET name = $2, description = $3, leader_id = $4, photo_url = $5, worker_count = $6, updated_at = $7
		WHERE id = $1
	`

	_, err := r.db.Exec(
		query,
		team.ID,
		team.Name,
		team.Description,
		team.LeaderID,
		team.PhotoURL,
		team.WorkerCount,
		time.Now(), // Update timestamp
	)

	if err != nil {
		return fmt.Errorf("failed to update team: %w", err)
	}

	return nil
}

// Delete deletes a team
func (r *teamRepository) Delete(id uuid.UUID) error {
	query := `DELETE FROM teams WHERE id = $1`

	_, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete team: %w", err)
	}

	return nil
}

// GetAll retrieves all teams
func (r *teamRepository) GetAll() ([]*domain.Team, error) {
	query := `
		SELECT id, name, description, leader_id, photo_url, worker_count, created_at, updated_at
		FROM teams
		ORDER BY name
	`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get all teams: %w", err)
	}
	defer rows.Close()

	var teams []*domain.Team
	for rows.Next() {
		team := &domain.Team{}
		var description sql.NullString
		var photoURL sql.NullString

		err := rows.Scan(
			&team.ID,
			&team.Name,
			&description,
			&team.LeaderID,
			&photoURL,
			&team.WorkerCount,
			&team.CreatedAt,
			&team.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan team row: %w", err)
		}

		// Handle nullable fields
		if description.Valid {
			team.Description = &description.String
		}
		if photoURL.Valid {
			team.PhotoURL = &photoURL.String
		}

		teams = append(teams, team)
	}

	return teams, nil
}

// AddWorker adds a worker to a team (simplified implementation)
func (r *teamRepository) AddWorker(teamID, workerID uuid.UUID) error {
	// This is a simplified implementation
	// In a real implementation, you'd have a team_members table
	// For now, we'll just update the user's team_id
	query := `UPDATE users SET team_id = $1 WHERE id = $2`

	_, err := r.db.Exec(query, teamID, workerID)
	if err != nil {
		return fmt.Errorf("failed to add worker to team: %w", err)
	}

	return nil
}

// RemoveWorker removes a worker from a team (simplified implementation)
func (r *teamRepository) RemoveWorker(teamID, workerID uuid.UUID) error {
	// This is a simplified implementation
	// In a real implementation, you'd remove from team_members table
	// For now, we'll just set the user's team_id to NULL
	query := `UPDATE users SET team_id = NULL WHERE id = $1 AND team_id = $2`

	_, err := r.db.Exec(query, workerID, teamID)
	if err != nil {
		return fmt.Errorf("failed to remove worker from team: %w", err)
	}

	return nil
}

// GetTeamWorkers retrieves all workers in a team
func (r *teamRepository) GetTeamWorkers(teamID uuid.UUID) ([]*domain.User, error) {
	query := `
		SELECT id, email, password_hash, display_name, role, phone, profile_photo_url, team_id, is_online, last_active_at, created_at, updated_at
		FROM users
		WHERE team_id = $1
		ORDER BY display_name
	`

	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get team workers: %w", err)
	}
	defer rows.Close()

	var workers []*domain.User
	for rows.Next() {
		user := &domain.User{}
		var phone sql.NullString
		var profilePhotoURL sql.NullString
		var teamID sql.NullString

		err := rows.Scan(
			&user.ID,
			&user.Email,
			&user.PasswordHash,
			&user.DisplayName,
			&user.Role,
			&phone,
			&profilePhotoURL,
			&teamID,
			&user.IsOnline,
			&user.LastActiveAt,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user row: %w", err)
		}

		// Handle nullable fields
		if phone.Valid {
			user.Phone = &phone.String
		}
		if profilePhotoURL.Valid {
			user.ProfilePhotoURL = &profilePhotoURL.String
		}
		if teamID.Valid {
			// Parse the UUID string from the database
			parsedUUID, err := uuid.Parse(teamID.String)
			if err == nil {
				user.TeamID = &parsedUUID
			}
		}

		workers = append(workers, user)
	}

	return workers, nil
}
