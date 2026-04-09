package service

import (
	"errors"
	"fmt"
	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
)

type MockTeamService struct{}

func NewMockTeamService() *MockTeamService {
	return &MockTeamService{}
}

func (m *MockTeamService) CreateTeam(leaderID uuid.UUID, req *domain.CreateTeamRequest) (*domain.Team, error) {
	team := &domain.Team{
		ID:          uuid.New(),
		Name:        req.Name,
		Description: &req.Description,
		LeaderID:    leaderID,
		WorkerCount: 1,
	}
	return team, nil
}

func (m *MockTeamService) GetTeam(teamID uuid.UUID) (*domain.Team, error) {
	return nil, errors.New("not implemented")
}

func (m *MockTeamService) UpdateTeam(teamID, userID uuid.UUID, req *domain.UpdateTeamRequest) (*domain.Team, error) {
	return nil, errors.New("not implemented")
}

func (m *MockTeamService) DeleteTeam(teamID, userID uuid.UUID) error {
	return errors.New("not implemented")
}

func (m *MockTeamService) JoinTeam(userID uuid.UUID, req *domain.JoinTeamRequest) error {
	// Mock implementation - just return success
	fmt.Printf("Mock: User %s joining team %s\n", userID, req.TeamID)
	return nil
}

func (m *MockTeamService) LeaveTeam(userID uuid.UUID) error {
	return errors.New("not implemented")
}

func (m *MockTeamService) GetTeamWorkers(teamID uuid.UUID) ([]*domain.User, error) {
	return nil, errors.New("not implemented")
}

func (m *MockTeamService) GetUserTeams(userID uuid.UUID) ([]*domain.Team, error) {
	return nil, errors.New("not implemented")
}

func (m *MockTeamService) SearchTeams(query string) ([]*domain.Team, error) {
	// Mock implementation - return some sample teams for testing
	teams := []*domain.Team{
		{
			ID:          uuid.New(),
			Name:        "Test Team 1",
			Description: stringPtr("A test team for development"),
			LeaderID:    uuid.New(),
			WorkerCount: 5,
		},
		{
			ID:          uuid.New(),
			Name:        "Test Team 2",
			Description: stringPtr("Another test team"),
			LeaderID:    uuid.New(),
			WorkerCount: 3,
		},
	}

	// Filter teams based on query (case-insensitive)
	if query != "" {
		var filtered []*domain.Team
		for _, team := range teams {
			if containsIgnoreCase(team.Name, query) {
				filtered = append(filtered, team)
			}
		}
		return filtered, nil
	}

	return teams, nil
}

// Helper functions
func stringPtr(s string) *string {
	return &s
}

func containsIgnoreCase(str, substr string) bool {
	return len(str) >= len(substr) && (str == substr ||
		(len(str) > len(substr) &&
			(str[:len(substr)] == substr ||
				str[len(str)-len(substr):] == substr ||
				indexOfIgnoreCase(str, substr) >= 0)))
}

func indexOfIgnoreCase(str, substr string) int {
	for i := 0; i <= len(str)-len(substr); i++ {
		if str[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}
