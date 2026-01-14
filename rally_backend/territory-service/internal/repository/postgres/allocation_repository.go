package postgres

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

type allocationRepository struct {
	db *sql.DB
}

// NewAllocationRepository creates a new allocation repository
func NewAllocationRepository(db *sql.DB) domain.LeaderTerritoryAllocationRepository {
	return &allocationRepository{db: db}
}

// Create creates a new territory allocation
func (r *allocationRepository) Create(allocation *domain.LeaderTerritoryAllocation) error {
	query := `
		INSERT INTO leader_territory_allocations
		(id, leader_id, territory_id, allocated_by, allocated_at, expires_at, status, notes, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	allocation.ID = uuid.New()
	allocation.AllocatedAt = time.Now()
	allocation.Status = domain.AllocationStatusActive
	allocation.CreatedAt = time.Now()
	allocation.UpdatedAt = time.Now()

	_, err := r.db.Exec(query,
		allocation.ID,
		allocation.LeaderID,
		allocation.TerritoryID,
		allocation.AllocatedBy,
		allocation.AllocatedAt,
		allocation.ExpiresAt,
		allocation.Status,
		allocation.Notes,
		allocation.CreatedAt,
		allocation.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create allocation: %w", err)
	}

	return nil
}

// GetByID retrieves an allocation by ID with territory details
func (r *allocationRepository) GetByID(id uuid.UUID) (*domain.LeaderTerritoryAllocationWithDetails, error) {
	query := `
		SELECT
			a.id, a.leader_id, a.territory_id, a.allocated_by, a.allocated_at,
			a.expires_at, a.status, a.notes, a.created_at, a.updated_at,
			t.solid as territory_solid, t.entity_name, t.entity_id,
			t.city, t.state, t.union_name, t.conference,
			t.population, t.housing_units,
			ST_AsGeoJSON(t.geom) as geometry
		FROM leader_territory_allocations a
		JOIN territories t ON t.id = a.territory_id
		WHERE a.id = $1
	`

	var alloc domain.LeaderTerritoryAllocationWithDetails
	var geometryJSON sql.NullString
	err := r.db.QueryRow(query, id).Scan(
		&alloc.ID, &alloc.LeaderID, &alloc.TerritoryID, &alloc.AllocatedBy, &alloc.AllocatedAt,
		&alloc.ExpiresAt, &alloc.Status, &alloc.Notes, &alloc.CreatedAt, &alloc.UpdatedAt,
		&alloc.TerritorySOLID, &alloc.EntityName, &alloc.EntityID,
		&alloc.City, &alloc.State, &alloc.UnionName, &alloc.Conference,
		&alloc.Population, &alloc.HousingUnits,
		&geometryJSON,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("allocation not found")
		}
		return nil, fmt.Errorf("failed to get allocation: %w", err)
	}

	if geometryJSON.Valid && geometryJSON.String != "" {
		alloc.Geometry = json.RawMessage(geometryJSON.String)
	}

	return &alloc, nil
}

// GetByLeaderID retrieves all allocations for a leader
func (r *allocationRepository) GetByLeaderID(leaderID uuid.UUID, status string) ([]*domain.LeaderTerritoryAllocationWithDetails, error) {
	query := `
		SELECT
			a.id, a.leader_id, a.territory_id, a.allocated_by, a.allocated_at,
			a.expires_at, a.status, a.notes, a.created_at, a.updated_at,
			t.solid as territory_solid, t.entity_name, t.entity_id,
			t.city, t.state, t.union_name, t.conference,
			t.population, t.housing_units,
			ST_AsGeoJSON(t.geom) as geometry
		FROM leader_territory_allocations a
		JOIN territories t ON t.id = a.territory_id
		WHERE a.leader_id = $1
	`

	args := []interface{}{leaderID}
	if status != "" {
		query += " AND a.status = $2"
		args = append(args, status)
	}

	// Filter out expired allocations
	query += " AND (a.expires_at IS NULL OR a.expires_at > NOW())"
	query += " ORDER BY a.allocated_at DESC"

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get leader allocations: %w", err)
	}
	defer rows.Close()

	var allocations []*domain.LeaderTerritoryAllocationWithDetails
	for rows.Next() {
		var alloc domain.LeaderTerritoryAllocationWithDetails
		var geometryJSON sql.NullString
		err := rows.Scan(
			&alloc.ID, &alloc.LeaderID, &alloc.TerritoryID, &alloc.AllocatedBy, &alloc.AllocatedAt,
			&alloc.ExpiresAt, &alloc.Status, &alloc.Notes, &alloc.CreatedAt, &alloc.UpdatedAt,
			&alloc.TerritorySOLID, &alloc.EntityName, &alloc.EntityID,
			&alloc.City, &alloc.State, &alloc.UnionName, &alloc.Conference,
			&alloc.Population, &alloc.HousingUnits,
			&geometryJSON,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan allocation: %w", err)
		}
		if geometryJSON.Valid && geometryJSON.String != "" {
			alloc.Geometry = json.RawMessage(geometryJSON.String)
		}
		allocations = append(allocations, &alloc)
	}

	return allocations, nil
}

// GetByTerritoryID retrieves all allocations for a territory
func (r *allocationRepository) GetByTerritoryID(territoryID uuid.UUID) ([]*domain.LeaderTerritoryAllocation, error) {
	query := `
		SELECT id, leader_id, territory_id, allocated_by, allocated_at,
		       expires_at, status, notes, created_at, updated_at
		FROM leader_territory_allocations
		WHERE territory_id = $1
		ORDER BY allocated_at DESC
	`

	rows, err := r.db.Query(query, territoryID)
	if err != nil {
		return nil, fmt.Errorf("failed to get territory allocations: %w", err)
	}
	defer rows.Close()

	var allocations []*domain.LeaderTerritoryAllocation
	for rows.Next() {
		var alloc domain.LeaderTerritoryAllocation
		err := rows.Scan(
			&alloc.ID, &alloc.LeaderID, &alloc.TerritoryID, &alloc.AllocatedBy, &alloc.AllocatedAt,
			&alloc.ExpiresAt, &alloc.Status, &alloc.Notes, &alloc.CreatedAt, &alloc.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan allocation: %w", err)
		}
		allocations = append(allocations, &alloc)
	}

	return allocations, nil
}

// GetByLeaderAndTerritory retrieves an allocation by leader and territory
func (r *allocationRepository) GetByLeaderAndTerritory(leaderID, territoryID uuid.UUID) (*domain.LeaderTerritoryAllocation, error) {
	query := `
		SELECT id, leader_id, territory_id, allocated_by, allocated_at,
		       expires_at, status, notes, created_at, updated_at
		FROM leader_territory_allocations
		WHERE leader_id = $1 AND territory_id = $2
	`

	var alloc domain.LeaderTerritoryAllocation
	err := r.db.QueryRow(query, leaderID, territoryID).Scan(
		&alloc.ID, &alloc.LeaderID, &alloc.TerritoryID, &alloc.AllocatedBy, &alloc.AllocatedAt,
		&alloc.ExpiresAt, &alloc.Status, &alloc.Notes, &alloc.CreatedAt, &alloc.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("allocation not found")
		}
		return nil, fmt.Errorf("failed to get allocation: %w", err)
	}

	return &alloc, nil
}

// Update updates an allocation
func (r *allocationRepository) Update(id uuid.UUID, req *domain.UpdateAllocationRequest) error {
	query := `
		UPDATE leader_territory_allocations
		SET updated_at = $2
	`
	args := []interface{}{id, time.Now()}
	argNum := 3

	if req.Status != nil {
		query += fmt.Sprintf(", status = $%d", argNum)
		args = append(args, *req.Status)
		argNum++
	}

	if req.ExpiresAt != nil {
		query += fmt.Sprintf(", expires_at = $%d", argNum)
		args = append(args, *req.ExpiresAt)
		argNum++
	}

	if req.Notes != nil {
		query += fmt.Sprintf(", notes = $%d", argNum)
		args = append(args, *req.Notes)
	}

	query += " WHERE id = $1"

	result, err := r.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update allocation: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("allocation not found")
	}

	return nil
}

// Delete deletes an allocation
func (r *allocationRepository) Delete(id uuid.UUID) error {
	query := `DELETE FROM leader_territory_allocations WHERE id = $1`

	result, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete allocation: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("allocation not found")
	}

	return nil
}

// Revoke revokes an allocation
func (r *allocationRepository) Revoke(id uuid.UUID) error {
	query := `
		UPDATE leader_territory_allocations
		SET status = $2, updated_at = $3
		WHERE id = $1
	`

	result, err := r.db.Exec(query, id, domain.AllocationStatusRevoked, time.Now())
	if err != nil {
		return fmt.Errorf("failed to revoke allocation: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("allocation not found")
	}

	return nil
}

// GetLeaderAllocationsGeoJSON returns leader's allocated territories as GeoJSON
func (r *allocationRepository) GetLeaderAllocationsGeoJSON(leaderID uuid.UUID) (*domain.GeoJSONFeatureCollection, error) {
	query := `
		SELECT
			a.id, t.solid, t.entity_name, t.entity_id, t.city, t.state,
			t.union_name, t.conference, t.population, t.housing_units,
			a.status, a.allocated_at, a.expires_at,
			ST_AsGeoJSON(t.geom) as geometry
		FROM leader_territory_allocations a
		JOIN territories t ON t.id = a.territory_id
		WHERE a.leader_id = $1 AND a.status = 'active'
		AND (a.expires_at IS NULL OR a.expires_at > NOW())
	`

	rows, err := r.db.Query(query, leaderID)
	if err != nil {
		return nil, fmt.Errorf("failed to get leader allocations: %w", err)
	}
	defer rows.Close()

	features := make([]domain.GeoJSONFeature, 0)

	for rows.Next() {
		var allocID uuid.UUID
		var solid, entityName, entityID string
		var city, state, unionName, conference sql.NullString
		var population, housingUnits sql.NullInt64
		var status string
		var allocatedAt time.Time
		var expiresAt sql.NullTime
		var geometryJSON string

		err := rows.Scan(
			&allocID, &solid, &entityName, &entityID, &city, &state,
			&unionName, &conference, &population, &housingUnits,
			&status, &allocatedAt, &expiresAt,
			&geometryJSON,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan allocation: %w", err)
		}

		var geometry interface{}
		json.Unmarshal([]byte(geometryJSON), &geometry)

		properties := map[string]interface{}{
			"allocation_id": allocID.String(),
			"solid":         solid,
			"entity_name":   entityName,
			"entity_id":     entityID,
			"status":        status,
			"allocated_at":  allocatedAt,
		}

		if city.Valid {
			properties["city"] = city.String
		}
		if state.Valid {
			properties["state"] = state.String
		}
		if unionName.Valid {
			properties["union_name"] = unionName.String
		}
		if conference.Valid {
			properties["conference"] = conference.String
		}
		if population.Valid {
			properties["population"] = population.Int64
		}
		if housingUnits.Valid {
			properties["housing_units"] = housingUnits.Int64
		}
		if expiresAt.Valid {
			properties["expires_at"] = expiresAt.Time
		}

		features = append(features, domain.GeoJSONFeature{
			Type:       "Feature",
			ID:         allocID.String(),
			Geometry:   geometry,
			Properties: properties,
		})
	}

	return &domain.GeoJSONFeatureCollection{
		Type:     "FeatureCollection",
		Features: features,
	}, nil
}

// GetAllocationStats returns allocation statistics for a leader
func (r *allocationRepository) GetAllocationStats(leaderID uuid.UUID) (*domain.AllocationStats, error) {
	query := `
		SELECT
			COUNT(*) as total_allocations,
			COUNT(*) FILTER (WHERE a.status = 'active' AND (a.expires_at IS NULL OR a.expires_at > NOW())) as active_allocations,
			COALESCE(SUM(t.population), 0) as total_population,
			COALESCE(SUM(t.housing_units), 0) as total_housing_units
		FROM leader_territory_allocations a
		JOIN territories t ON t.id = a.territory_id
		WHERE a.leader_id = $1
	`

	stats := &domain.AllocationStats{LeaderID: leaderID}
	err := r.db.QueryRow(query, leaderID).Scan(
		&stats.TotalAllocations,
		&stats.ActiveAllocations,
		&stats.TotalPopulation,
		&stats.TotalHousingUnits,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get allocation stats: %w", err)
	}

	return stats, nil
}

// IsLeaderAllocated checks if a territory is allocated to a leader
func (r *allocationRepository) IsLeaderAllocated(leaderID, territoryID uuid.UUID) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM leader_territory_allocations
			WHERE leader_id = $1 AND territory_id = $2
			AND status = 'active'
			AND (expires_at IS NULL OR expires_at > NOW())
		)
	`

	var exists bool
	err := r.db.QueryRow(query, leaderID, territoryID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check allocation: %w", err)
	}

	return exists, nil
}

// GetAllAllocations returns all allocations with pagination
func (r *allocationRepository) GetAllAllocations(status string, limit, offset int) ([]*domain.LeaderTerritoryAllocationWithDetails, int, error) {
	countQuery := `SELECT COUNT(*) FROM leader_territory_allocations`
	if status != "" {
		countQuery += " WHERE status = $1"
	}

	var total int
	var countArgs []interface{}
	if status != "" {
		countArgs = append(countArgs, status)
	}

	err := r.db.QueryRow(countQuery, countArgs...).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count allocations: %w", err)
	}

	query := `
		SELECT
			a.id, a.leader_id, a.territory_id, a.allocated_by, a.allocated_at,
			a.expires_at, a.status, a.notes, a.created_at, a.updated_at,
			t.solid as territory_solid, t.entity_name, t.entity_id,
			t.city, t.state, t.union_name, t.conference,
			t.population, t.housing_units,
			'' as geometry
		FROM leader_territory_allocations a
		JOIN territories t ON t.id = a.territory_id
	`

	args := []interface{}{}
	argNum := 1

	if status != "" {
		query += fmt.Sprintf(" WHERE a.status = $%d", argNum)
		args = append(args, status)
		argNum++
	}

	query += " ORDER BY a.allocated_at DESC"

	if limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", argNum)
		args = append(args, limit)
		argNum++
	}

	if offset > 0 {
		query += fmt.Sprintf(" OFFSET $%d", argNum)
		args = append(args, offset)
	}

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get allocations: %w", err)
	}
	defer rows.Close()

	var allocations []*domain.LeaderTerritoryAllocationWithDetails
	for rows.Next() {
		var alloc domain.LeaderTerritoryAllocationWithDetails
		var geometryJSON sql.NullString
		err := rows.Scan(
			&alloc.ID, &alloc.LeaderID, &alloc.TerritoryID, &alloc.AllocatedBy, &alloc.AllocatedAt,
			&alloc.ExpiresAt, &alloc.Status, &alloc.Notes, &alloc.CreatedAt, &alloc.UpdatedAt,
			&alloc.TerritorySOLID, &alloc.EntityName, &alloc.EntityID,
			&alloc.City, &alloc.State, &alloc.UnionName, &alloc.Conference,
			&alloc.Population, &alloc.HousingUnits,
			&geometryJSON,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("failed to scan allocation: %w", err)
		}
		if geometryJSON.Valid && geometryJSON.String != "" {
			alloc.Geometry = json.RawMessage(geometryJSON.String)
		}
		allocations = append(allocations, &alloc)
	}

	return allocations, total, nil
}
