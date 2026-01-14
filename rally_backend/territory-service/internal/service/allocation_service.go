package service

import (
	"fmt"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// allocationService implements LeaderTerritoryAllocationService
type allocationService struct {
	repo domain.LeaderTerritoryAllocationRepository
}

// NewAllocationService creates a new allocation service
func NewAllocationService(repo domain.LeaderTerritoryAllocationRepository) domain.LeaderTerritoryAllocationService {
	return &allocationService{repo: repo}
}

// AllocateTerritory allocates a territory to a leader
func (s *allocationService) AllocateTerritory(req *domain.CreateAllocationRequest) (*domain.LeaderTerritoryAllocation, error) {
	if req.LeaderID == uuid.Nil {
		return nil, fmt.Errorf("leader_id is required")
	}
	if req.TerritoryID == uuid.Nil {
		return nil, fmt.Errorf("territory_id is required")
	}
	if req.AllocatedBy == uuid.Nil {
		return nil, fmt.Errorf("allocated_by is required")
	}

	// Check if territory is already allocated to this leader
	existing, _ := s.repo.GetByLeaderAndTerritory(req.LeaderID, req.TerritoryID)
	if existing != nil && existing.Status == domain.AllocationStatusActive {
		return nil, fmt.Errorf("territory is already allocated to this leader")
	}

	allocation := &domain.LeaderTerritoryAllocation{
		LeaderID:    req.LeaderID,
		TerritoryID: req.TerritoryID,
		AllocatedBy: req.AllocatedBy,
		ExpiresAt:   req.ExpiresAt,
		Notes:       req.Notes,
	}

	err := s.repo.Create(allocation)
	if err != nil {
		return nil, fmt.Errorf("failed to create allocation: %w", err)
	}

	fmt.Printf("🗺️ Territory allocated to leader %s\n", req.LeaderID)

	return allocation, nil
}

// AllocateTerritories allocates multiple territories to a leader
func (s *allocationService) AllocateTerritories(req *domain.BulkAllocationRequest) ([]*domain.LeaderTerritoryAllocation, error) {
	if req.LeaderID == uuid.Nil {
		return nil, fmt.Errorf("leader_id is required")
	}
	if len(req.TerritoryIDs) == 0 {
		return nil, fmt.Errorf("at least one territory_id is required")
	}
	if req.AllocatedBy == uuid.Nil {
		return nil, fmt.Errorf("allocated_by is required")
	}

	var allocations []*domain.LeaderTerritoryAllocation
	var errors []string

	for _, territoryID := range req.TerritoryIDs {
		createReq := &domain.CreateAllocationRequest{
			LeaderID:    req.LeaderID,
			TerritoryID: territoryID,
			AllocatedBy: req.AllocatedBy,
			ExpiresAt:   req.ExpiresAt,
			Notes:       req.Notes,
		}

		allocation, err := s.AllocateTerritory(createReq)
		if err != nil {
			errors = append(errors, fmt.Sprintf("territory %s: %s", territoryID, err.Error()))
			continue
		}

		allocations = append(allocations, allocation)
	}

	if len(errors) > 0 && len(allocations) == 0 {
		return nil, fmt.Errorf("failed to allocate any territories: %v", errors)
	}

	return allocations, nil
}

// RevokeAllocation revokes an allocation
func (s *allocationService) RevokeAllocation(id uuid.UUID) error {
	err := s.repo.Revoke(id)
	if err != nil {
		return fmt.Errorf("failed to revoke allocation: %w", err)
	}

	fmt.Printf("🚫 Territory allocation revoked: %s\n", id)

	return nil
}

// GetAllocation retrieves an allocation by ID
func (s *allocationService) GetAllocation(id uuid.UUID) (*domain.LeaderTerritoryAllocationWithDetails, error) {
	return s.repo.GetByID(id)
}

// GetAllAllocations retrieves all allocations with optional status filter
func (s *allocationService) GetAllAllocations(status string, limit, offset int) ([]*domain.LeaderTerritoryAllocationWithDetails, int, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	return s.repo.GetAllAllocations(status, limit, offset)
}

// GetLeaderAllocations retrieves all allocations for a leader
func (s *allocationService) GetLeaderAllocations(leaderID uuid.UUID, status string) ([]*domain.LeaderTerritoryAllocationWithDetails, error) {
	return s.repo.GetByLeaderID(leaderID, status)
}

// GetLeaderAllocationsGeoJSON returns leader's allocated territories as GeoJSON
func (s *allocationService) GetLeaderAllocationsGeoJSON(leaderID uuid.UUID) (*domain.GeoJSONFeatureCollection, error) {
	return s.repo.GetLeaderAllocationsGeoJSON(leaderID)
}

// GetLeaderAllocationStats returns allocation statistics for a leader
func (s *allocationService) GetLeaderAllocationStats(leaderID uuid.UUID) (*domain.AllocationStats, error) {
	return s.repo.GetAllocationStats(leaderID)
}

// CanLeaderAssignTerritory checks if a leader can assign a territory to a worker
// (i.e., the territory must be allocated to the leader)
func (s *allocationService) CanLeaderAssignTerritory(leaderID, territoryID uuid.UUID) (bool, error) {
	return s.repo.IsLeaderAllocated(leaderID, territoryID)
}
