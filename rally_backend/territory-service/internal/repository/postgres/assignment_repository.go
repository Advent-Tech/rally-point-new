package postgres

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// assignmentRepository implements TerritoryAssignmentRepository
type assignmentRepository struct {
	db *sql.DB
}

// NewAssignmentRepository creates a new assignment repository
func NewAssignmentRepository(db *sql.DB) domain.TerritoryAssignmentRepository {
	return &assignmentRepository{db: db}
}

// Create creates a new territory assignment
func (r *assignmentRepository) Create(assignment *domain.TerritoryAssignment) error {
	// Get the SOLID from the territory
	var solid string
	err := r.db.QueryRow("SELECT solid FROM territories WHERE id = $1", assignment.TerritoryID).Scan(&solid)
	if err != nil {
		return fmt.Errorf("territory not found: %w", err)
	}
	assignment.TerritorySOLID = solid

	query := `
		INSERT INTO territory_assignments (
			id, territory_id, territory_solid, team_id, assigned_worker_id,
			assigned_by, assigned_at, expires_at, status, priority, notes,
			created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
		)
	`

	now := time.Now()
	assignment.ID = uuid.New()
	assignment.AssignedAt = now
	assignment.CreatedAt = now
	assignment.UpdatedAt = now

	if assignment.Status == "" {
		assignment.Status = "active"
	}
	if assignment.Priority == "" {
		assignment.Priority = "medium"
	}

	_, err = r.db.Exec(query,
		assignment.ID,
		assignment.TerritoryID,
		assignment.TerritorySOLID,
		assignment.TeamID,
		assignment.AssignedWorkerID,
		assignment.AssignedBy,
		assignment.AssignedAt,
		assignment.ExpiresAt,
		assignment.Status,
		assignment.Priority,
		assignment.Notes,
		assignment.CreatedAt,
		assignment.UpdatedAt,
	)

	return err
}

// GetByID retrieves an assignment by ID with territory details
func (r *assignmentRepository) GetByID(id uuid.UUID) (*domain.TerritoryAssignmentWithDetails, error) {
	query := `
		SELECT
			ta.id, ta.territory_id, ta.territory_solid, ta.team_id, ta.assigned_worker_id,
			ta.assigned_by, ta.assigned_at, ta.expires_at, ta.status, ta.priority, ta.notes,
			ta.last_worked_at, ta.visits_count, ta.completeness_percentage,
			ta.created_at, ta.updated_at,
			t.entity_name, t.entity_id, t.city, t.state, t.union_name, t.conference,
			t.population, t.housing_units, ST_AsGeoJSON(t.geom) as geometry
		FROM territory_assignments ta
		JOIN territories t ON ta.territory_id = t.id
		WHERE ta.id = $1
	`

	var a domain.TerritoryAssignmentWithDetails
	err := r.db.QueryRow(query, id).Scan(
		&a.ID, &a.TerritoryID, &a.TerritorySOLID, &a.TeamID, &a.AssignedWorkerID,
		&a.AssignedBy, &a.AssignedAt, &a.ExpiresAt, &a.Status, &a.Priority, &a.Notes,
		&a.LastWorkedAt, &a.VisitsCount, &a.CompletenessPercentage,
		&a.CreatedAt, &a.UpdatedAt,
		&a.EntityName, &a.EntityID, &a.City, &a.State, &a.UnionName, &a.Conference,
		&a.Population, &a.HousingUnits, &a.Geometry,
	)

	if err != nil {
		return nil, err
	}

	return &a, nil
}

// GetByTerritoryID retrieves all assignments for a territory
func (r *assignmentRepository) GetByTerritoryID(territoryID uuid.UUID) ([]*domain.TerritoryAssignmentWithDetails, error) {
	query := `
		SELECT
			ta.id, ta.territory_id, ta.territory_solid, ta.team_id, ta.assigned_worker_id,
			ta.assigned_by, ta.assigned_at, ta.expires_at, ta.status, ta.priority, ta.notes,
			ta.last_worked_at, ta.visits_count, ta.completeness_percentage,
			ta.created_at, ta.updated_at,
			t.entity_name, t.entity_id, t.city, t.state, t.union_name, t.conference,
			t.population, t.housing_units, ST_AsGeoJSON(t.geom) as geometry
		FROM territory_assignments ta
		JOIN territories t ON ta.territory_id = t.id
		WHERE ta.territory_id = $1
		ORDER BY ta.assigned_at DESC
	`

	return r.queryAssignments(query, territoryID)
}

// GetByTeamID retrieves all assignments for a team
func (r *assignmentRepository) GetByTeamID(teamID uuid.UUID, status string) ([]*domain.TerritoryAssignmentWithDetails, error) {
	query := `
		SELECT
			ta.id, ta.territory_id, ta.territory_solid, ta.team_id, ta.assigned_worker_id,
			ta.assigned_by, ta.assigned_at, ta.expires_at, ta.status, ta.priority, ta.notes,
			ta.last_worked_at, ta.visits_count, ta.completeness_percentage,
			ta.created_at, ta.updated_at,
			t.entity_name, t.entity_id, t.city, t.state, t.union_name, t.conference,
			t.population, t.housing_units, ST_AsGeoJSON(t.geom) as geometry
		FROM territory_assignments ta
		JOIN territories t ON ta.territory_id = t.id
		WHERE ta.team_id = $1
	`

	if status != "" {
		query += " AND ta.status = $2 ORDER BY ta.priority DESC, ta.assigned_at DESC"
		return r.queryAssignments(query, teamID, status)
	}

	query += " ORDER BY ta.priority DESC, ta.assigned_at DESC"
	return r.queryAssignments(query, teamID)
}

// GetByWorkerID retrieves all assignments for a worker
func (r *assignmentRepository) GetByWorkerID(workerID uuid.UUID, status string) ([]*domain.TerritoryAssignmentWithDetails, error) {
	query := `
		SELECT
			ta.id, ta.territory_id, ta.territory_solid, ta.team_id, ta.assigned_worker_id,
			ta.assigned_by, ta.assigned_at, ta.expires_at, ta.status, ta.priority, ta.notes,
			ta.last_worked_at, ta.visits_count, ta.completeness_percentage,
			ta.created_at, ta.updated_at,
			t.entity_name, t.entity_id, t.city, t.state, t.union_name, t.conference,
			t.population, t.housing_units, ST_AsGeoJSON(t.geom) as geometry
		FROM territory_assignments ta
		JOIN territories t ON ta.territory_id = t.id
		WHERE ta.assigned_worker_id = $1
	`

	if status != "" {
		query += " AND ta.status = $2 ORDER BY ta.priority DESC, ta.assigned_at DESC"
		return r.queryAssignments(query, workerID, status)
	}

	query += " ORDER BY ta.priority DESC, ta.assigned_at DESC"
	return r.queryAssignments(query, workerID)
}

// queryAssignments is a helper to query and scan assignments
func (r *assignmentRepository) queryAssignments(query string, args ...interface{}) ([]*domain.TerritoryAssignmentWithDetails, error) {
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assignments []*domain.TerritoryAssignmentWithDetails
	for rows.Next() {
		var a domain.TerritoryAssignmentWithDetails
		err := rows.Scan(
			&a.ID, &a.TerritoryID, &a.TerritorySOLID, &a.TeamID, &a.AssignedWorkerID,
			&a.AssignedBy, &a.AssignedAt, &a.ExpiresAt, &a.Status, &a.Priority, &a.Notes,
			&a.LastWorkedAt, &a.VisitsCount, &a.CompletenessPercentage,
			&a.CreatedAt, &a.UpdatedAt,
			&a.EntityName, &a.EntityID, &a.City, &a.State, &a.UnionName, &a.Conference,
			&a.Population, &a.HousingUnits, &a.Geometry,
		)
		if err != nil {
			return nil, err
		}
		assignments = append(assignments, &a)
	}

	return assignments, rows.Err()
}

// Update updates an assignment
func (r *assignmentRepository) Update(id uuid.UUID, req *domain.UpdateAssignmentRequest) error {
	query := "UPDATE territory_assignments SET updated_at = NOW()"
	args := []interface{}{}
	argNum := 1

	if req.AssignedWorkerID != nil {
		query += fmt.Sprintf(", assigned_worker_id = $%d", argNum)
		args = append(args, req.AssignedWorkerID)
		argNum++
	}
	if req.Status != nil {
		query += fmt.Sprintf(", status = $%d", argNum)
		args = append(args, *req.Status)
		argNum++
	}
	if req.Priority != nil {
		query += fmt.Sprintf(", priority = $%d", argNum)
		args = append(args, *req.Priority)
		argNum++
	}
	if req.Notes != nil {
		query += fmt.Sprintf(", notes = $%d", argNum)
		args = append(args, *req.Notes)
		argNum++
	}
	if req.ExpiresAt != nil {
		query += fmt.Sprintf(", expires_at = $%d", argNum)
		args = append(args, req.ExpiresAt)
		argNum++
	}
	if req.VisitsCount != nil {
		query += fmt.Sprintf(", visits_count = $%d", argNum)
		args = append(args, *req.VisitsCount)
		argNum++
	}
	if req.CompletenessPercentage != nil {
		query += fmt.Sprintf(", completeness_percentage = $%d", argNum)
		args = append(args, *req.CompletenessPercentage)
		argNum++
	}

	query += fmt.Sprintf(" WHERE id = $%d", argNum)
	args = append(args, id)

	result, err := r.db.Exec(query, args...)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		return fmt.Errorf("assignment not found")
	}

	return nil
}

// Delete deletes an assignment
func (r *assignmentRepository) Delete(id uuid.UUID) error {
	result, err := r.db.Exec("DELETE FROM territory_assignments WHERE id = $1", id)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		return fmt.Errorf("assignment not found")
	}

	return nil
}

// GetWorkerAssignmentsGeoJSON returns worker's assigned territories as GeoJSON
func (r *assignmentRepository) GetWorkerAssignmentsGeoJSON(workerID uuid.UUID) (*domain.GeoJSONFeatureCollection, error) {
	query := `
		SELECT
			t.id::text as id,
			ST_AsGeoJSON(t.geom)::json as geometry,
			json_build_object(
				'solid', t.solid,
				'entity_name', t.entity_name,
				'entity_id', t.entity_id,
				'city', t.city,
				'state', t.state,
				'union_name', t.union_name,
				'conference', t.conference,
				'population', t.population,
				'housing_units', t.housing_units,
				'assignment_id', ta.id,
				'assignment_status', ta.status,
				'assignment_priority', ta.priority,
				'visits_count', ta.visits_count,
				'completeness_percentage', ta.completeness_percentage,
				'assigned_at', ta.assigned_at
			) as properties
		FROM territory_assignments ta
		JOIN territories t ON ta.territory_id = t.id
		WHERE ta.assigned_worker_id = $1 AND ta.status = 'active'
	`

	return r.queryGeoJSON(query, workerID)
}

// GetTeamAssignmentsGeoJSON returns team's assigned territories as GeoJSON
func (r *assignmentRepository) GetTeamAssignmentsGeoJSON(teamID uuid.UUID) (*domain.GeoJSONFeatureCollection, error) {
	query := `
		SELECT
			t.id::text as id,
			ST_AsGeoJSON(t.geom)::json as geometry,
			json_build_object(
				'solid', t.solid,
				'entity_name', t.entity_name,
				'entity_id', t.entity_id,
				'city', t.city,
				'state', t.state,
				'union_name', t.union_name,
				'conference', t.conference,
				'population', t.population,
				'housing_units', t.housing_units,
				'assignment_id', ta.id,
				'assigned_worker_id', ta.assigned_worker_id,
				'assignment_status', ta.status,
				'assignment_priority', ta.priority,
				'visits_count', ta.visits_count,
				'completeness_percentage', ta.completeness_percentage,
				'assigned_at', ta.assigned_at
			) as properties
		FROM territory_assignments ta
		JOIN territories t ON ta.territory_id = t.id
		WHERE ta.team_id = $1 AND ta.status IN ('active', 'paused')
	`

	return r.queryGeoJSON(query, teamID)
}

// queryGeoJSON is a helper to build GeoJSON feature collection
func (r *assignmentRepository) queryGeoJSON(query string, args ...interface{}) (*domain.GeoJSONFeatureCollection, error) {
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	features := []domain.GeoJSONFeature{}
	for rows.Next() {
		var id string
		var geometryJSON []byte
		var propertiesJSON []byte

		err := rows.Scan(&id, &geometryJSON, &propertiesJSON)
		if err != nil {
			return nil, err
		}

		var geometry interface{}
		var properties map[string]interface{}

		json.Unmarshal(geometryJSON, &geometry)
		json.Unmarshal(propertiesJSON, &properties)

		features = append(features, domain.GeoJSONFeature{
			Type:       "Feature",
			ID:         id,
			Geometry:   geometry,
			Properties: properties,
		})
	}

	return &domain.GeoJSONFeatureCollection{
		Type:     "FeatureCollection",
		Features: features,
	}, rows.Err()
}

// RecordVisit increments the visit count, updates last_worked_at, and recalculates completeness_percentage
func (r *assignmentRepository) RecordVisit(assignmentID uuid.UUID) error {
	query := `
		UPDATE territory_assignments ta
		SET visits_count = ta.visits_count + 1,
			last_worked_at = NOW(),
			updated_at = NOW(),
			completeness_percentage = LEAST(100.0,
				CASE
					WHEN t.housing_units > 0 THEN ((ta.visits_count + 1)::DECIMAL / t.housing_units) * 100
					ELSE 0
				END
			)
		FROM territories t
		WHERE ta.id = $1 AND ta.territory_id = t.id
	`

	result, err := r.db.Exec(query, assignmentID)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		return fmt.Errorf("assignment not found")
	}

	return nil
}

// RecordVisitByTerritoryWorker records a visit for a worker's territory assignment
// This looks up the assignment by territory_id and worker_id, then records the visit
func (r *assignmentRepository) RecordVisitByTerritoryWorker(territoryID, workerID uuid.UUID) error {
	query := `
		UPDATE territory_assignments ta
		SET visits_count = ta.visits_count + 1,
			last_worked_at = NOW(),
			updated_at = NOW(),
			completeness_percentage = LEAST(100.0,
				CASE
					WHEN t.housing_units > 0 THEN ((ta.visits_count + 1)::DECIMAL / t.housing_units) * 100
					ELSE 0
				END
			)
		FROM territories t
		WHERE ta.territory_id = $1
		  AND ta.assigned_worker_id = $2
		  AND ta.status = 'active'
		  AND ta.territory_id = t.id
	`

	result, err := r.db.Exec(query, territoryID, workerID)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		return fmt.Errorf("no active assignment found for worker in this territory")
	}

	return nil
}
