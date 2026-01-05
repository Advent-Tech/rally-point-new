package service

import (
	"database/sql"
	"fmt"
	"rally-point/user-service/internal/domain"
	"strings"

	"github.com/google/uuid"
)

type TeamService struct {
	teamRepo domain.TeamRepository
	db       *sql.DB
}

func NewTeamService(teamRepo domain.TeamRepository, db *sql.DB) *TeamService {
	return &TeamService{
		teamRepo: teamRepo,
		db:       db,
	}
}

func (t *TeamService) CreateTeam(leaderID uuid.UUID, req *domain.CreateTeamRequest) (*domain.Team, error) {
	team := &domain.Team{
		ID:          uuid.New(),
		Name:        req.Name,
		Description: &req.Description,
		LeaderID:    leaderID,
		WorkerCount: 1, // Leader counts as first worker
	}

	err := t.teamRepo.Create(team)
	if err != nil {
		return nil, fmt.Errorf("failed to create team: %w", err)
	}

	// Also set the leader's team_id to this team
	// This ensures the leader is associated with their team for queries
	err = t.teamRepo.AddWorker(team.ID, leaderID)
	if err != nil {
		// Log but don't fail - the team was created successfully
		fmt.Printf("Warning: failed to set leader's team_id: %v\n", err)
	}

	return team, nil
}

func (t *TeamService) GetTeam(teamID uuid.UUID) (*domain.Team, error) {
	team, err := t.teamRepo.GetByID(teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get team: %w", err)
	}

	return team, nil
}

func (t *TeamService) UpdateTeam(teamID, userID uuid.UUID, req *domain.UpdateTeamRequest) (*domain.Team, error) {
	team, err := t.teamRepo.GetByID(teamID)
	if err != nil {
		return nil, fmt.Errorf("team not found: %w", err)
	}

	// Check if user is team leader
	if team.LeaderID != userID {
		return nil, fmt.Errorf("only team leader can update team")
	}

	// Update fields if provided
	if req.Name != nil {
		team.Name = *req.Name
	}
	if req.Description != nil {
		team.Description = req.Description
	}
	if req.PhotoURL != nil {
		team.PhotoURL = req.PhotoURL
	}

	err = t.teamRepo.Update(team)
	if err != nil {
		return nil, fmt.Errorf("failed to update team: %w", err)
	}

	return team, nil
}

func (t *TeamService) DeleteTeam(teamID, userID uuid.UUID) error {
	team, err := t.teamRepo.GetByID(teamID)
	if err != nil {
		return fmt.Errorf("team not found: %w", err)
	}

	// Check if user is team leader
	if team.LeaderID != userID {
		return fmt.Errorf("only team leader can delete team")
	}

	err = t.teamRepo.Delete(teamID)
	if err != nil {
		return fmt.Errorf("failed to delete team: %w", err)
	}

	return nil
}

func (t *TeamService) JoinTeam(userID uuid.UUID, req *domain.JoinTeamRequest) error {
	// Add worker to team
	err := t.teamRepo.AddWorker(req.TeamID, userID)
	if err != nil {
		return fmt.Errorf("failed to join team: %w", err)
	}

	// Update worker count
	team, err := t.teamRepo.GetByID(req.TeamID)
	if err == nil {
		team.WorkerCount++
		t.teamRepo.Update(team)
	}

	return nil
}

func (t *TeamService) LeaveTeam(userID uuid.UUID) error {
	// This is a simplified implementation
	// In a real implementation, you'd need to find the user's team first
	return fmt.Errorf("not implemented - need to find user's team first")
}

func (t *TeamService) GetTeamWorkers(teamID uuid.UUID) ([]*domain.User, error) {
	workers, err := t.teamRepo.GetTeamWorkers(teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get team workers: %w", err)
	}

	return workers, nil
}

func (t *TeamService) GetUserTeams(userID uuid.UUID) ([]*domain.Team, error) {
	// This is a simplified implementation
	// In a real implementation, you'd query teams where user is a member
	return nil, fmt.Errorf("not implemented")
}

func (t *TeamService) GetTeamsByLeader(leaderID uuid.UUID) ([]*domain.Team, error) {
	return t.teamRepo.GetByLeaderID(leaderID)
}

func (t *TeamService) SearchTeams(query string) ([]*domain.Team, error) {
	if query == "" {
		return nil, fmt.Errorf("search query is required")
	}

	// Use SQL query to search teams by name (case-insensitive)
	sqlQuery := `
		SELECT id, name, description, leader_id, photo_url, worker_count, created_at, updated_at
		FROM teams
		WHERE LOWER(name) LIKE LOWER($1)
		ORDER BY name
		LIMIT 50
	`

	searchPattern := "%" + strings.ToLower(query) + "%"
	rows, err := t.db.Query(sqlQuery, searchPattern)
	if err != nil {
		return nil, fmt.Errorf("failed to search teams: %w", err)
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

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating team rows: %w", err)
	}

	return teams, nil
}
