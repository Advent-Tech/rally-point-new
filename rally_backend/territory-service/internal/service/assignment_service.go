package service

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
	"rally-point/territory-service/internal/domain"
)

// assignmentService implements TerritoryAssignmentService
type assignmentService struct {
	repo           domain.TerritoryAssignmentRepository
	allocationRepo domain.LeaderTerritoryAllocationRepository
	nc             *nats.Conn
}

// NewAssignmentService creates a new assignment service
func NewAssignmentService(repo domain.TerritoryAssignmentRepository, nc *nats.Conn) domain.TerritoryAssignmentService {
	return &assignmentService{repo: repo, nc: nc}
}

// NewAssignmentServiceWithAllocation creates a new assignment service with allocation validation
func NewAssignmentServiceWithAllocation(repo domain.TerritoryAssignmentRepository, allocationRepo domain.LeaderTerritoryAllocationRepository, nc *nats.Conn) domain.TerritoryAssignmentService {
	return &assignmentService{
		repo:           repo,
		allocationRepo: allocationRepo,
		nc:             nc,
	}
}

// publishNotify publishes a notification event to NATS
func (s *assignmentService) publishNotify(subject string, event map[string]interface{}) {
	if s.nc == nil {
		return
	}
	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("Failed to marshal notification event: %v", err)
		return
	}
	if err := s.nc.Publish(subject, data); err != nil {
		log.Printf("Failed to publish %s: %v", subject, err)
	}
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

	// If allocation repository is available, validate that the leader has this territory allocated
	if s.allocationRepo != nil {
		isAllocated, err := s.allocationRepo.IsLeaderAllocated(req.AssignedBy, req.TerritoryID)
		if err != nil {
			return nil, fmt.Errorf("failed to check territory allocation: %w", err)
		}
		if !isAllocated {
			return nil, fmt.Errorf("you can only assign territories that have been allocated to you by admin")
		}
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

	// Publish notification for territory assignment
	if req.AssignedWorkerID != nil && *req.AssignedWorkerID != uuid.Nil {
		s.publishNotify("notify.territory.assigned", map[string]interface{}{
			"event_type":        "territory.assigned",
			"target_type":       "user",
			"target_id":         req.AssignedWorkerID.String(),
			"actor_id":          req.AssignedBy.String(),
			"title":             "New territory assigned",
			"body":              fmt.Sprintf("You've been assigned a new territory"),
			"data":              map[string]interface{}{"territory_id": req.TerritoryID.String(), "assignment_id": assignment.ID.String()},
			"priority":          "high",
			"notification_type": "territory",
			"group_key":         "territory:" + req.TerritoryID.String(),
			"created_at":        time.Now().Format(time.RFC3339),
		})
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
