package domain

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// LeaderTerritoryAllocation represents an admin's allocation of territory to a team leader
type LeaderTerritoryAllocation struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	LeaderID    uuid.UUID  `json:"leader_id" db:"leader_id"`
	TerritoryID uuid.UUID  `json:"territory_id" db:"territory_id"`
	AllocatedBy uuid.UUID  `json:"allocated_by" db:"allocated_by"`
	AllocatedAt time.Time  `json:"allocated_at" db:"allocated_at"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty" db:"expires_at"`
	Status      string     `json:"status" db:"status"` // active, revoked, expired
	Notes       *string    `json:"notes,omitempty" db:"notes"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

// LeaderTerritoryAllocationWithDetails includes territory info
type LeaderTerritoryAllocationWithDetails struct {
	LeaderTerritoryAllocation
	TerritorySOLID string          `json:"territory_solid"`
	EntityName     string          `json:"entity_name"`
	EntityID       string          `json:"entity_id"`
	City           *string         `json:"city,omitempty"`
	State          *string         `json:"state,omitempty"`
	UnionName      *string         `json:"union_name,omitempty"`
	Conference     *string         `json:"conference,omitempty"`
	Population     *int            `json:"population,omitempty"`
	HousingUnits   *int            `json:"housing_units,omitempty"`
	Geometry       json.RawMessage `json:"geometry,omitempty"` // GeoJSON geometry
}

// CreateAllocationRequest for allocating territory to a leader
type CreateAllocationRequest struct {
	LeaderID    uuid.UUID  `json:"leader_id" binding:"required"`
	TerritoryID uuid.UUID  `json:"territory_id" binding:"required"`
	AllocatedBy uuid.UUID  `json:"allocated_by"` // Set by handler from JWT context
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
	Notes       *string    `json:"notes,omitempty"`
}

// BulkAllocationRequest for allocating multiple territories to a leader
type BulkAllocationRequest struct {
	LeaderID     uuid.UUID   `json:"leader_id" binding:"required"`
	TerritoryIDs []uuid.UUID `json:"territory_ids" binding:"required"`
	AllocatedBy  uuid.UUID   `json:"allocated_by"` // Set by handler from JWT context
	ExpiresAt    *time.Time  `json:"expires_at,omitempty"`
	Notes        *string     `json:"notes,omitempty"`
}

// UpdateAllocationRequest for updating an allocation
type UpdateAllocationRequest struct {
	Status    *string    `json:"status,omitempty"`
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
	Notes     *string    `json:"notes,omitempty"`
}

// AllocationFilters for querying allocations
type AllocationFilters struct {
	LeaderID    *uuid.UUID `json:"leader_id" form:"leader_id"`
	TerritoryID *uuid.UUID `json:"territory_id" form:"territory_id"`
	Status      string     `json:"status" form:"status"`
	Limit       int        `json:"limit" form:"limit"`
	Offset      int        `json:"offset" form:"offset"`
}

// AllocationStats for a leader
type AllocationStats struct {
	LeaderID          uuid.UUID `json:"leader_id"`
	TotalAllocations  int       `json:"total_allocations"`
	ActiveAllocations int       `json:"active_allocations"`
	TotalPopulation   int       `json:"total_population"`
	TotalHousingUnits int       `json:"total_housing_units"`
}

// LeaderTerritoryAllocationRepository defines the interface for allocation data access
type LeaderTerritoryAllocationRepository interface {
	Create(allocation *LeaderTerritoryAllocation) error
	GetByID(id uuid.UUID) (*LeaderTerritoryAllocationWithDetails, error)
	GetByLeaderID(leaderID uuid.UUID, status string) ([]*LeaderTerritoryAllocationWithDetails, error)
	GetByTerritoryID(territoryID uuid.UUID) ([]*LeaderTerritoryAllocation, error)
	GetByLeaderAndTerritory(leaderID, territoryID uuid.UUID) (*LeaderTerritoryAllocation, error)
	Update(id uuid.UUID, req *UpdateAllocationRequest) error
	Delete(id uuid.UUID) error
	Revoke(id uuid.UUID) error
	GetLeaderAllocationsGeoJSON(leaderID uuid.UUID) (*GeoJSONFeatureCollection, error)
	GetAllocationStats(leaderID uuid.UUID) (*AllocationStats, error)
	IsLeaderAllocated(leaderID, territoryID uuid.UUID) (bool, error)
	GetAllAllocations(status string, limit, offset int) ([]*LeaderTerritoryAllocationWithDetails, int, error)
}

// LeaderTerritoryAllocationService defines the interface for allocation business logic
type LeaderTerritoryAllocationService interface {
	// Admin operations
	AllocateTerritory(req *CreateAllocationRequest) (*LeaderTerritoryAllocation, error)
	AllocateTerritories(req *BulkAllocationRequest) ([]*LeaderTerritoryAllocation, error)
	RevokeAllocation(id uuid.UUID) error
	GetAllocation(id uuid.UUID) (*LeaderTerritoryAllocationWithDetails, error)
	GetAllAllocations(status string, limit, offset int) ([]*LeaderTerritoryAllocationWithDetails, int, error)

	// Leader operations
	GetLeaderAllocations(leaderID uuid.UUID, status string) ([]*LeaderTerritoryAllocationWithDetails, error)
	GetLeaderAllocationsGeoJSON(leaderID uuid.UUID) (*GeoJSONFeatureCollection, error)
	GetLeaderAllocationStats(leaderID uuid.UUID) (*AllocationStats, error)

	// Validation
	CanLeaderAssignTerritory(leaderID, territoryID uuid.UUID) (bool, error)
}

// Allocation status constants
const (
	AllocationStatusActive  = "active"
	AllocationStatusRevoked = "revoked"
	AllocationStatusExpired = "expired"
)
