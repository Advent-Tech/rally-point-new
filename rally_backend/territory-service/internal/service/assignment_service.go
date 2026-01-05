package service

import (
	"fmt"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// assignmentService implements TerritoryAssignmentService
type assignmentService struct {
	repo domain.TerritoryAssignmentRepository
}

// NewAssignmentService creates a new assignment service
func NewAssignmentService(repo domain.TerritoryAssignmentRepository) domain.TerritoryAssignmentService {
	return &assignmentService{repo: repo}
}

// AssignTerritory creates a new territory assignment
func (s *assignmentService) AssignTerritory(req *domain.CreateAssignmentRequest) (*domain.TerritoryAssignment, error) {
	if req.TerritoryID == uuid.Nil {
		return nil, fmt.Errorf("territory_id is required")
	}
	if req.TeamID == uuid.Nil {
		return nil, fmt.Errorf("team_id is required")
	}
	if req.AssignedBy == uuid.Nil {
		return nil, fmt.Errorf("assigned_by is required")
	}

	assignment := &domain.TerritoryAssignment{
		TerritoryID:      req.TerritoryID,
		TeamID:           req.TeamID,
		AssignedWorkerID: req.AssignedWorkerID,
		AssignedBy:       req.AssignedBy,
		ExpiresAt:        req.ExpiresAt,
		Priority:         req.Priority,
		Notes:            req.Notes,
		Status:           "active",
	}

	if assignment.Priority == "" {
		assignment.Priority = "medium"
	}

	err := s.repo.Create(assignment)
	if err != nil {
		return nil, fmt.Errorf("failed to create assignment: %w", err)
	}

	return assignment, nil
}

// GetAssignment retrieves an assignment by ID
func (s *assignmentService) GetAssignment(id uuid.UUID) (*domain.TerritoryAssignmentWithDetails, error) {
	return s.repo.GetByID(id)
}

// GetTeamAssignments retrieves all assignments for a team
func (s *assignmentService) GetTeamAssignments(teamID uuid.UUID, status string) ([]*domain.TerritoryAssignmentWithDetails, error) {
	return s.repo.GetByTeamID(teamID, status)
}

// GetWorkerAssignments retrieves all assignments for a worker
func (s *assignmentService) GetWorkerAssignments(workerID uuid.UUID, status string) ([]*domain.TerritoryAssignmentWithDetails, error) {
	return s.repo.GetByWorkerID(workerID, status)
}

// UpdateAssignment updates an assignment
func (s *assignmentService) UpdateAssignment(id uuid.UUID, req *domain.UpdateAssignmentRequest) error {
	return s.repo.Update(id, req)
}

// UnassignTerritory removes a territory assignment
func (s *assignmentService) UnassignTerritory(id uuid.UUID) error {
	return s.repo.Delete(id)
}

// GetWorkerTerritoriesGeoJSON returns worker's assigned territories as GeoJSON
func (s *assignmentService) GetWorkerTerritoriesGeoJSON(workerID uuid.UUID) (*domain.GeoJSONFeatureCollection, error) {
	return s.repo.GetWorkerAssignmentsGeoJSON(workerID)
}

// GetTeamTerritoriesGeoJSON returns team's assigned territories as GeoJSON
func (s *assignmentService) GetTeamTerritoriesGeoJSON(teamID uuid.UUID) (*domain.GeoJSONFeatureCollection, error) {
	return s.repo.GetTeamAssignmentsGeoJSON(teamID)
}

// RecordTerritoryVisit records a visit to a territory
func (s *assignmentService) RecordTerritoryVisit(assignmentID uuid.UUID) error {
	return s.repo.RecordVisit(assignmentID)
}

// RecordTerritoryVisitByWorker records a visit for a worker's territory assignment
// This is useful when you have the territory_id and worker_id but not the assignment_id
func (s *assignmentService) RecordTerritoryVisitByWorker(territoryID, workerID uuid.UUID) error {
	return s.repo.RecordVisitByTerritoryWorker(territoryID, workerID)
}
