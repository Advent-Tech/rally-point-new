package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// geofenceRepository implements GeofenceRepository
type geofenceRepository struct {
	db *sql.DB
}

// NewGeofenceRepository creates a new geofence repository
func NewGeofenceRepository(db *sql.DB) domain.GeofenceRepository {
	return &geofenceRepository{db: db}
}

// CheckWorkerInTerritory checks if a point is inside worker's assigned territories
func (r *geofenceRepository) CheckWorkerInTerritory(workerID uuid.UUID, lat, lng float64) (*domain.GeofenceCheckResult, error) {
	query := `
		SELECT
			t.id as territory_id,
			ta.id as assignment_id,
			t.solid as territory_solid,
			t.entity_name,
			t.entity_id
		FROM territory_assignments ta
		JOIN territories t ON ta.territory_id = t.id
		WHERE ta.assigned_worker_id = $1
		AND ta.status = 'active'
		AND ST_Contains(t.geom, ST_SetSRID(ST_MakePoint($3, $2), 4326))
		LIMIT 1
	`

	var result domain.GeofenceCheckResult
	var territoryID, assignmentID uuid.UUID
	var solid, entityName, entityID string

	err := r.db.QueryRow(query, workerID, lat, lng).Scan(
		&territoryID,
		&assignmentID,
		&solid,
		&entityName,
		&entityID,
	)

	if err == sql.ErrNoRows {
		// Not inside any assigned territory
		result.IsInside = false
		return &result, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to check worker territory: %w", err)
	}

	result.IsInside = true
	result.TerritoryID = &territoryID
	result.AssignmentID = &assignmentID
	result.TerritorySOLID = &solid
	result.EntityName = &entityName
	result.EntityID = &entityID

	return &result, nil
}

// CheckTeamTerritory checks if a point is inside team's assigned territories
func (r *geofenceRepository) CheckTeamTerritory(teamID uuid.UUID, lat, lng float64) (*domain.GeofenceCheckResult, error) {
	query := `
		SELECT
			t.id as territory_id,
			ta.id as assignment_id,
			t.solid as territory_solid,
			t.entity_name,
			t.entity_id
		FROM territory_assignments ta
		JOIN territories t ON ta.territory_id = t.id
		WHERE ta.team_id = $1
		AND ta.status = 'active'
		AND ST_Contains(t.geom, ST_SetSRID(ST_MakePoint($3, $2), 4326))
		LIMIT 1
	`

	var result domain.GeofenceCheckResult
	var territoryID, assignmentID uuid.UUID
	var solid, entityName, entityID string

	err := r.db.QueryRow(query, teamID, lat, lng).Scan(
		&territoryID,
		&assignmentID,
		&solid,
		&entityName,
		&entityID,
	)

	if err == sql.ErrNoRows {
		result.IsInside = false
		return &result, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to check team territory: %w", err)
	}

	result.IsInside = true
	result.TerritoryID = &territoryID
	result.AssignmentID = &assignmentID
	result.TerritorySOLID = &solid
	result.EntityName = &entityName
	result.EntityID = &entityID

	return &result, nil
}

// CreateWorkSession creates a new territory work session
func (r *geofenceRepository) CreateWorkSession(session *domain.TerritoryWorkSession) error {
	query := `
		INSERT INTO territory_work_sessions (
			id, worker_id, territory_id, assignment_id,
			entry_time, entry_lat, entry_lng, is_active,
			created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	now := time.Now()
	session.ID = uuid.New()
	session.EntryTime = now
	session.IsActive = true
	session.CreatedAt = now
	session.UpdatedAt = now

	_, err := r.db.Exec(query,
		session.ID,
		session.WorkerID,
		session.TerritoryID,
		session.AssignmentID,
		session.EntryTime,
		session.EntryLat,
		session.EntryLng,
		session.IsActive,
		session.CreatedAt,
		session.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create work session: %w", err)
	}

	return nil
}

// GetActiveWorkSession retrieves the active work session for a worker
func (r *geofenceRepository) GetActiveWorkSession(workerID uuid.UUID) (*domain.TerritoryWorkSession, error) {
	query := `
		SELECT
			id, worker_id, territory_id, assignment_id,
			entry_time, exit_time, entry_lat, entry_lng, exit_lat, exit_lng,
			time_spent_seconds, distance_covered_meters, is_active,
			created_at, updated_at
		FROM territory_work_sessions
		WHERE worker_id = $1 AND is_active = true
		ORDER BY entry_time DESC
		LIMIT 1
	`

	var session domain.TerritoryWorkSession
	err := r.db.QueryRow(query, workerID).Scan(
		&session.ID,
		&session.WorkerID,
		&session.TerritoryID,
		&session.AssignmentID,
		&session.EntryTime,
		&session.ExitTime,
		&session.EntryLat,
		&session.EntryLng,
		&session.ExitLat,
		&session.ExitLng,
		&session.TimeSpentSeconds,
		&session.DistanceCoveredMeters,
		&session.IsActive,
		&session.CreatedAt,
		&session.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil // No active session
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get active work session: %w", err)
	}

	return &session, nil
}

// EndWorkSession ends an active work session
func (r *geofenceRepository) EndWorkSession(sessionID uuid.UUID, exitLat, exitLng float64, timeSpent int, distance float64) error {
	query := `
		UPDATE territory_work_sessions
		SET exit_time = NOW(),
			exit_lat = $2,
			exit_lng = $3,
			time_spent_seconds = $4,
			distance_covered_meters = $5,
			is_active = false,
			updated_at = NOW()
		WHERE id = $1
	`

	result, err := r.db.Exec(query, sessionID, exitLat, exitLng, timeSpent, distance)
	if err != nil {
		return fmt.Errorf("failed to end work session: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("work session not found")
	}

	return nil
}

// GetWorkerWorkSessions retrieves work sessions for a worker
func (r *geofenceRepository) GetWorkerWorkSessions(workerID uuid.UUID, limit, offset int) ([]*domain.TerritoryWorkSessionWithDetails, error) {
	if limit <= 0 {
		limit = 50
	}

	query := `
		SELECT
			tws.id, tws.worker_id, tws.territory_id, tws.assignment_id,
			tws.entry_time, tws.exit_time, tws.entry_lat, tws.entry_lng,
			tws.exit_lat, tws.exit_lng, tws.time_spent_seconds,
			tws.distance_covered_meters, tws.is_active,
			tws.created_at, tws.updated_at,
			t.solid, t.entity_name, t.entity_id, t.city, t.state
		FROM territory_work_sessions tws
		JOIN territories t ON tws.territory_id = t.id
		WHERE tws.worker_id = $1
		ORDER BY tws.entry_time DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(query, workerID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker work sessions: %w", err)
	}
	defer rows.Close()

	var sessions []*domain.TerritoryWorkSessionWithDetails
	for rows.Next() {
		var s domain.TerritoryWorkSessionWithDetails
		err := rows.Scan(
			&s.ID, &s.WorkerID, &s.TerritoryID, &s.AssignmentID,
			&s.EntryTime, &s.ExitTime, &s.EntryLat, &s.EntryLng,
			&s.ExitLat, &s.ExitLng, &s.TimeSpentSeconds,
			&s.DistanceCoveredMeters, &s.IsActive,
			&s.CreatedAt, &s.UpdatedAt,
			&s.TerritorySOLID, &s.EntityName, &s.EntityID, &s.City, &s.State,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan work session: %w", err)
		}
		sessions = append(sessions, &s)
	}

	return sessions, rows.Err()
}

// GetTerritoryWorkSessions retrieves work sessions for a territory
func (r *geofenceRepository) GetTerritoryWorkSessions(territoryID uuid.UUID, limit, offset int) ([]*domain.TerritoryWorkSessionWithDetails, error) {
	if limit <= 0 {
		limit = 50
	}

	query := `
		SELECT
			tws.id, tws.worker_id, tws.territory_id, tws.assignment_id,
			tws.entry_time, tws.exit_time, tws.entry_lat, tws.entry_lng,
			tws.exit_lat, tws.exit_lng, tws.time_spent_seconds,
			tws.distance_covered_meters, tws.is_active,
			tws.created_at, tws.updated_at,
			t.solid, t.entity_name, t.entity_id, t.city, t.state
		FROM territory_work_sessions tws
		JOIN territories t ON tws.territory_id = t.id
		WHERE tws.territory_id = $1
		ORDER BY tws.entry_time DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(query, territoryID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get territory work sessions: %w", err)
	}
	defer rows.Close()

	var sessions []*domain.TerritoryWorkSessionWithDetails
	for rows.Next() {
		var s domain.TerritoryWorkSessionWithDetails
		err := rows.Scan(
			&s.ID, &s.WorkerID, &s.TerritoryID, &s.AssignmentID,
			&s.EntryTime, &s.ExitTime, &s.EntryLat, &s.EntryLng,
			&s.ExitLat, &s.ExitLng, &s.TimeSpentSeconds,
			&s.DistanceCoveredMeters, &s.IsActive,
			&s.CreatedAt, &s.UpdatedAt,
			&s.TerritorySOLID, &s.EntityName, &s.EntityID, &s.City, &s.State,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan work session: %w", err)
		}
		sessions = append(sessions, &s)
	}

	return sessions, rows.Err()
}

// CreateWorkSessionWithDetails creates a work session and returns it with territory details
func (r *geofenceRepository) CreateWorkSessionWithDetails(session *domain.TerritoryWorkSession, territoryName string) (*domain.TerritoryWorkSessionWithDetails, error) {
	query := `
		INSERT INTO territory_work_sessions (
			id, worker_id, territory_id, assignment_id, territory_name,
			entry_time, entry_lat, entry_lng, is_active,
			created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id, entry_time, created_at, updated_at
	`

	now := time.Now()
	session.ID = uuid.New()
	session.IsActive = true

	var lat, lng float64
	if session.EntryLat != 0 {
		lat = session.EntryLat
	}
	if session.EntryLng != 0 {
		lng = session.EntryLng
	}

	err := r.db.QueryRow(query,
		session.ID,
		session.WorkerID,
		session.TerritoryID,
		session.AssignmentID,
		territoryName,
		now,
		lat,
		lng,
		true,
		now,
		now,
	).Scan(&session.ID, &session.EntryTime, &session.CreatedAt, &session.UpdatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create work session: %w", err)
	}

	return &domain.TerritoryWorkSessionWithDetails{
		TerritoryWorkSession: *session,
		EntityName:           territoryName,
	}, nil
}

// GetWorkSession retrieves a specific work session by ID
func (r *geofenceRepository) GetWorkSession(sessionID uuid.UUID) (*domain.TerritoryWorkSessionWithDetails, error) {
	query := `
		SELECT
			tws.id, tws.worker_id, tws.territory_id, tws.assignment_id,
			tws.entry_time, tws.exit_time, tws.entry_lat, tws.entry_lng,
			tws.exit_lat, tws.exit_lng, tws.time_spent_seconds,
			tws.distance_covered_meters, tws.is_active,
			tws.created_at, tws.updated_at,
			COALESCE(t.solid, '') as solid,
			COALESCE(tws.territory_name, t.entity_name, '') as entity_name,
			COALESCE(t.entity_id, '') as entity_id,
			t.city, t.state
		FROM territory_work_sessions tws
		LEFT JOIN territories t ON tws.territory_id = t.id
		WHERE tws.id = $1
	`

	var s domain.TerritoryWorkSessionWithDetails
	err := r.db.QueryRow(query, sessionID).Scan(
		&s.ID, &s.WorkerID, &s.TerritoryID, &s.AssignmentID,
		&s.EntryTime, &s.ExitTime, &s.EntryLat, &s.EntryLng,
		&s.ExitLat, &s.ExitLng, &s.TimeSpentSeconds,
		&s.DistanceCoveredMeters, &s.IsActive,
		&s.CreatedAt, &s.UpdatedAt,
		&s.TerritorySOLID, &s.EntityName, &s.EntityID, &s.City, &s.State,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get work session: %w", err)
	}

	return &s, nil
}

// EndWorkSessionWithNotes ends a work session with optional notes
func (r *geofenceRepository) EndWorkSessionWithNotes(sessionID uuid.UUID, notes *string) (*domain.TerritoryWorkSessionWithDetails, error) {
	session, err := r.GetWorkSession(sessionID)
	if err != nil {
		return nil, err
	}
	if session == nil {
		return nil, fmt.Errorf("work session not found")
	}

	timeSpent := int(time.Since(session.EntryTime).Seconds())

	query := `
		UPDATE territory_work_sessions
		SET exit_time = NOW(),
			time_spent_seconds = $2,
			is_active = false,
			updated_at = NOW()
		WHERE id = $1
	`

	_, err = r.db.Exec(query, sessionID, timeSpent)
	if err != nil {
		return nil, fmt.Errorf("failed to end work session: %w", err)
	}

	return r.GetWorkSession(sessionID)
}

// CreateVisitRecord creates a new visit record
func (r *geofenceRepository) CreateVisitRecord(visit *domain.VisitRecord) error {
	query := `
		INSERT INTO visit_records (
			id, session_id, worker_id, territory_id,
			address, outcome, notes, latitude, longitude,
			visited_at, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`

	now := time.Now()
	visit.ID = uuid.New()
	visit.VisitedAt = now
	visit.CreatedAt = now
	visit.UpdatedAt = now

	_, err := r.db.Exec(query,
		visit.ID,
		visit.SessionID,
		visit.WorkerID,
		visit.TerritoryID,
		visit.Address,
		visit.Outcome,
		visit.Notes,
		visit.Latitude,
		visit.Longitude,
		visit.VisitedAt,
		visit.CreatedAt,
		visit.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create visit record: %w", err)
	}

	return nil
}

// GetSessionVisits retrieves all visits for a session
func (r *geofenceRepository) GetSessionVisits(sessionID uuid.UUID) ([]*domain.VisitRecord, error) {
	query := `
		SELECT
			id, session_id, worker_id, territory_id,
			address, outcome, notes, latitude, longitude,
			visited_at, created_at, updated_at
		FROM visit_records
		WHERE session_id = $1
		ORDER BY visited_at DESC
	`

	rows, err := r.db.Query(query, sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get session visits: %w", err)
	}
	defer rows.Close()

	var visits []*domain.VisitRecord
	for rows.Next() {
		var v domain.VisitRecord
		err := rows.Scan(
			&v.ID, &v.SessionID, &v.WorkerID, &v.TerritoryID,
			&v.Address, &v.Outcome, &v.Notes, &v.Latitude, &v.Longitude,
			&v.VisitedAt, &v.CreatedAt, &v.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan visit record: %w", err)
		}
		visits = append(visits, &v)
	}

	return visits, rows.Err()
}

// GetWorkerVisits retrieves all visits for a worker on a specific date
func (r *geofenceRepository) GetWorkerVisits(workerID uuid.UUID, date time.Time) ([]*domain.VisitRecord, error) {
	// Get start and end of the day
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)

	query := `
		SELECT
			id, session_id, worker_id, territory_id,
			address, outcome, notes, latitude, longitude,
			visited_at, created_at, updated_at
		FROM visit_records
		WHERE worker_id = $1
		AND visited_at >= $2 AND visited_at < $3
		ORDER BY visited_at DESC
	`

	rows, err := r.db.Query(query, workerID, startOfDay, endOfDay)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker visits: %w", err)
	}
	defer rows.Close()

	var visits []*domain.VisitRecord
	for rows.Next() {
		var v domain.VisitRecord
		err := rows.Scan(
			&v.ID, &v.SessionID, &v.WorkerID, &v.TerritoryID,
			&v.Address, &v.Outcome, &v.Notes, &v.Latitude, &v.Longitude,
			&v.VisitedAt, &v.CreatedAt, &v.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan visit record: %w", err)
		}
		visits = append(visits, &v)
	}

	return visits, rows.Err()
}

// GetWorkerWorkSessionsByDate retrieves work sessions for a worker on a specific date
func (r *geofenceRepository) GetWorkerWorkSessionsByDate(workerID uuid.UUID, date time.Time) ([]*domain.TerritoryWorkSessionWithDetails, error) {
	// Get start and end of the day
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)

	query := `
		SELECT
			tws.id, tws.worker_id, tws.territory_id, tws.assignment_id,
			tws.entry_time, tws.exit_time, tws.entry_lat, tws.entry_lng,
			tws.exit_lat, tws.exit_lng, tws.time_spent_seconds,
			tws.distance_covered_meters, tws.is_active,
			tws.created_at, tws.updated_at,
			COALESCE(t.solid, '') as solid,
			COALESCE(tws.territory_name, t.entity_name, '') as entity_name,
			COALESCE(t.entity_id, '') as entity_id,
			t.city, t.state
		FROM territory_work_sessions tws
		LEFT JOIN territories t ON tws.territory_id = t.id
		WHERE tws.worker_id = $1
		AND tws.entry_time >= $2 AND tws.entry_time < $3
		ORDER BY tws.entry_time DESC
	`

	rows, err := r.db.Query(query, workerID, startOfDay, endOfDay)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker work sessions by date: %w", err)
	}
	defer rows.Close()

	var sessions []*domain.TerritoryWorkSessionWithDetails
	for rows.Next() {
		var s domain.TerritoryWorkSessionWithDetails
		err := rows.Scan(
			&s.ID, &s.WorkerID, &s.TerritoryID, &s.AssignmentID,
			&s.EntryTime, &s.ExitTime, &s.EntryLat, &s.EntryLng,
			&s.ExitLat, &s.ExitLng, &s.TimeSpentSeconds,
			&s.DistanceCoveredMeters, &s.IsActive,
			&s.CreatedAt, &s.UpdatedAt,
			&s.TerritorySOLID, &s.EntityName, &s.EntityID, &s.City, &s.State,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan work session: %w", err)
		}
		sessions = append(sessions, &s)
	}

	return sessions, rows.Err()
}

// GetVisitStats retrieves aggregated visit statistics for a session
func (r *geofenceRepository) GetVisitStats(sessionID uuid.UUID) (*domain.VisitStats, error) {
	query := `
		SELECT
			COUNT(*) as total_visits,
			COUNT(*) FILTER (WHERE outcome = 'contacted') as contacted,
			COUNT(*) FILTER (WHERE outcome = 'not_home') as not_home,
			COUNT(*) FILTER (WHERE outcome = 'interested') as interested,
			COUNT(*) FILTER (WHERE outcome = 'do_not_call') as do_not_call,
			COUNT(*) FILTER (WHERE outcome = 'completed') as completed,
			COUNT(*) FILTER (WHERE outcome = 'other') as other
		FROM visit_records
		WHERE session_id = $1
	`

	var stats domain.VisitStats
	err := r.db.QueryRow(query, sessionID).Scan(
		&stats.TotalVisits,
		&stats.Contacted,
		&stats.NotHome,
		&stats.Interested,
		&stats.DoNotCall,
		&stats.Completed,
		&stats.Other,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get visit stats: %w", err)
	}

	return &stats, nil
}

// GetAllActiveSessions retrieves all currently active work sessions
func (r *geofenceRepository) GetAllActiveSessions() ([]*domain.TerritoryWorkSessionWithDetails, error) {
	query := `
		SELECT
			tws.id, tws.worker_id, tws.territory_id, tws.assignment_id,
			tws.entry_time, tws.exit_time, tws.entry_lat, tws.entry_lng,
			tws.exit_lat, tws.exit_lng, tws.time_spent_seconds,
			tws.distance_covered_meters, tws.is_active,
			tws.created_at, tws.updated_at,
			COALESCE(t.solid, '') as solid,
			COALESCE(tws.territory_name, t.entity_name, '') as entity_name,
			COALESCE(t.entity_id, '') as entity_id,
			t.city, t.state,
			COALESCE(u.display_name, '') as worker_name
		FROM territory_work_sessions tws
		LEFT JOIN territories t ON tws.territory_id = t.id
		LEFT JOIN users u ON tws.worker_id = u.id
		WHERE tws.is_active = true
		ORDER BY tws.entry_time DESC
	`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get active sessions: %w", err)
	}
	defer rows.Close()

	var sessions []*domain.TerritoryWorkSessionWithDetails
	for rows.Next() {
		var s domain.TerritoryWorkSessionWithDetails
		err := rows.Scan(
			&s.ID, &s.WorkerID, &s.TerritoryID, &s.AssignmentID,
			&s.EntryTime, &s.ExitTime, &s.EntryLat, &s.EntryLng,
			&s.ExitLat, &s.ExitLng, &s.TimeSpentSeconds,
			&s.DistanceCoveredMeters, &s.IsActive,
			&s.CreatedAt, &s.UpdatedAt,
			&s.TerritorySOLID, &s.EntityName, &s.EntityID, &s.City, &s.State,
			&s.WorkerName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan active session: %w", err)
		}
		sessions = append(sessions, &s)
	}

	return sessions, rows.Err()
}

// GetTeamActiveSessions retrieves active work sessions for a specific team
func (r *geofenceRepository) GetTeamActiveSessions(teamID uuid.UUID) ([]*domain.TerritoryWorkSessionWithDetails, error) {
	query := `
		SELECT
			tws.id, tws.worker_id, tws.territory_id, tws.assignment_id,
			tws.entry_time, tws.exit_time, tws.entry_lat, tws.entry_lng,
			tws.exit_lat, tws.exit_lng, tws.time_spent_seconds,
			tws.distance_covered_meters, tws.is_active,
			tws.created_at, tws.updated_at,
			COALESCE(t.solid, '') as solid,
			COALESCE(tws.territory_name, t.entity_name, '') as entity_name,
			COALESCE(t.entity_id, '') as entity_id,
			t.city, t.state,
			COALESCE(u.display_name, '') as worker_name
		FROM territory_work_sessions tws
		LEFT JOIN territories t ON tws.territory_id = t.id
		LEFT JOIN users u ON tws.worker_id = u.id
		LEFT JOIN territory_assignments ta ON tws.assignment_id = ta.id
		WHERE tws.is_active = true
		AND (ta.team_id = $1 OR u.team_id = $1)
		ORDER BY tws.entry_time DESC
	`

	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get team active sessions: %w", err)
	}
	defer rows.Close()

	var sessions []*domain.TerritoryWorkSessionWithDetails
	for rows.Next() {
		var s domain.TerritoryWorkSessionWithDetails
		err := rows.Scan(
			&s.ID, &s.WorkerID, &s.TerritoryID, &s.AssignmentID,
			&s.EntryTime, &s.ExitTime, &s.EntryLat, &s.EntryLng,
			&s.ExitLat, &s.ExitLng, &s.TimeSpentSeconds,
			&s.DistanceCoveredMeters, &s.IsActive,
			&s.CreatedAt, &s.UpdatedAt,
			&s.TerritorySOLID, &s.EntityName, &s.EntityID, &s.City, &s.State,
			&s.WorkerName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan team active session: %w", err)
		}
		sessions = append(sessions, &s)
	}

	return sessions, rows.Err()
}
