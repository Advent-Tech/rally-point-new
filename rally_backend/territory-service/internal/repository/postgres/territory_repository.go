package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

type territoryRepository struct {
	db *sql.DB
}

// NewTerritoryRepository creates a new territory repository
func NewTerritoryRepository(db *sql.DB) domain.TerritoryRepository {
	return &territoryRepository{db: db}
}

// Create creates a new territory
func (r *territoryRepository) Create(territory *domain.Territory) error {
	query := `
		INSERT INTO custom_territories (id, name, description, team_id, assigned_worker_id, boundary, color, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, ST_GeomFromGeoJSON($6), $7, $8, $9, $10)
	`
	
	_, err := r.db.Exec(
		query,
		territory.ID,
		territory.Name,
		territory.Description,
		territory.TeamID,
		territory.AssignedWorkerID,
		territory.Boundary,
		territory.Color,
		territory.IsActive,
		territory.CreatedAt,
		territory.UpdatedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to create territory: %w", err)
	}
	
	return nil
}

// GetByID retrieves a territory by ID
func (r *territoryRepository) GetByID(id uuid.UUID) (*domain.Territory, error) {
	query := `
		SELECT id, name, description, team_id, assigned_worker_id, ST_AsGeoJSON(boundary) as boundary, color, is_active, created_at, updated_at
		FROM custom_territories
		WHERE id = $1
	`
	
	territory := &domain.Territory{}
	err := r.db.QueryRow(query, id).Scan(
		&territory.ID,
		&territory.Name,
		&territory.Description,
		&territory.TeamID,
		&territory.AssignedWorkerID,
		&territory.Boundary,
		&territory.Color,
		&territory.IsActive,
		&territory.CreatedAt,
		&territory.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("territory not found")
		}
		return nil, fmt.Errorf("failed to get territory: %w", err)
	}
	
	return territory, nil
}

// GetByTeamID retrieves territories by team ID
func (r *territoryRepository) GetByTeamID(teamID uuid.UUID) ([]*domain.Territory, error) {
	query := `
		SELECT id, name, description, team_id, assigned_worker_id, ST_AsGeoJSON(boundary) as boundary, color, is_active, created_at, updated_at
		FROM custom_territories
		WHERE team_id = $1
		ORDER BY name
	`
	
	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get territories by team: %w", err)
	}
	defer rows.Close()
	
	var territories []*domain.Territory
	for rows.Next() {
		territory := &domain.Territory{}
		err := rows.Scan(
			&territory.ID,
			&territory.Name,
			&territory.Description,
			&territory.TeamID,
			&territory.AssignedWorkerID,
			&territory.Boundary,
			&territory.Color,
			&territory.IsActive,
			&territory.CreatedAt,
			&territory.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan territory: %w", err)
		}
		territories = append(territories, territory)
	}
	
	return territories, nil
}

// GetByWorkerID retrieves territories assigned to a worker
func (r *territoryRepository) GetByWorkerID(workerID uuid.UUID) ([]*domain.Territory, error) {
	query := `
		SELECT id, name, description, team_id, assigned_worker_id, ST_AsGeoJSON(boundary) as boundary, color, is_active, created_at, updated_at
		FROM custom_territories
		WHERE assigned_worker_id = $1 AND is_active = true
		ORDER BY name
	`
	
	rows, err := r.db.Query(query, workerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get territories by worker: %w", err)
	}
	defer rows.Close()
	
	var territories []*domain.Territory
	for rows.Next() {
		territory := &domain.Territory{}
		err := rows.Scan(
			&territory.ID,
			&territory.Name,
			&territory.Description,
			&territory.TeamID,
			&territory.AssignedWorkerID,
			&territory.Boundary,
			&territory.Color,
			&territory.IsActive,
			&territory.CreatedAt,
			&territory.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan territory: %w", err)
		}
		territories = append(territories, territory)
	}
	
	return territories, nil
}

// Update updates a territory
func (r *territoryRepository) Update(territory *domain.Territory) error {
	query := `
		UPDATE custom_territories
		SET name = $2, description = $3, assigned_worker_id = $4, boundary = ST_GeomFromGeoJSON($5), color = $6, is_active = $7, updated_at = $8
		WHERE id = $1
	`
	
	territory.UpdatedAt = time.Now()
	
	_, err := r.db.Exec(
		query,
		territory.ID,
		territory.Name,
		territory.Description,
		territory.AssignedWorkerID,
		territory.Boundary,
		territory.Color,
		territory.IsActive,
		territory.UpdatedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to update territory: %w", err)
	}
	
	return nil
}

// Delete deletes a territory
func (r *territoryRepository) Delete(id uuid.UUID) error {
	query := `DELETE FROM custom_territories WHERE id = $1`
	
	result, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete territory: %w", err)
	}
	
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	
	if rowsAffected == 0 {
		return fmt.Errorf("territory not found")
	}
	
	return nil
}

// GetAll retrieves all territories
func (r *territoryRepository) GetAll() ([]*domain.Territory, error) {
	query := `
		SELECT id, name, description, team_id, assigned_worker_id, ST_AsGeoJSON(boundary) as boundary, color, is_active, created_at, updated_at
		FROM custom_territories
		ORDER BY name
	`
	
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get all territories: %w", err)
	}
	defer rows.Close()
	
	var territories []*domain.Territory
	for rows.Next() {
		territory := &domain.Territory{}
		err := rows.Scan(
			&territory.ID,
			&territory.Name,
			&territory.Description,
			&territory.TeamID,
			&territory.AssignedWorkerID,
			&territory.Boundary,
			&territory.Color,
			&territory.IsActive,
			&territory.CreatedAt,
			&territory.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan territory: %w", err)
		}
		territories = append(territories, territory)
	}
	
	return territories, nil
}

// CreateEntry creates a new territory entry
func (r *territoryRepository) CreateEntry(entry *domain.TerritoryEntry) error {
	query := `
		INSERT INTO territory_entries (id, user_id, territory_id, entry_time, exit_time, entry_location, exit_location, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, ST_GeomFromText('POINT(' || $6 || ' ' || $7 || ')', 4326), $8, $9, $10, $11)
	`
	
	var exitLocation interface{}
	if entry.ExitLat != nil && entry.ExitLng != nil {
		exitLocation = fmt.Sprintf("POINT(%f %f)", *entry.ExitLng, *entry.ExitLat)
	}
	
	_, err := r.db.Exec(
		query,
		entry.ID,
		entry.UserID,
		entry.TerritoryID,
		entry.EntryTime,
		entry.ExitTime,
		entry.EntryLng,
		entry.EntryLat,
		exitLocation,
		entry.IsActive,
		entry.CreatedAt,
		entry.UpdatedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to create territory entry: %w", err)
	}
	
	return nil
}

// GetActiveEntry retrieves the active entry for a user in a territory
func (r *territoryRepository) GetActiveEntry(userID, territoryID uuid.UUID) (*domain.TerritoryEntry, error) {
	query := `
		SELECT id, user_id, territory_id, entry_time, exit_time, 
			   ST_X(entry_location) as entry_lng, ST_Y(entry_location) as entry_lat,
			   ST_X(exit_location) as exit_lng, ST_Y(exit_location) as exit_lat,
			   is_active, created_at, updated_at
		FROM territory_entries
		WHERE user_id = $1 AND territory_id = $2 AND is_active = true
		ORDER BY entry_time DESC
		LIMIT 1
	`
	
	entry := &domain.TerritoryEntry{}
	err := r.db.QueryRow(query, userID, territoryID).Scan(
		&entry.ID,
		&entry.UserID,
		&entry.TerritoryID,
		&entry.EntryTime,
		&entry.ExitTime,
		&entry.EntryLng,
		&entry.EntryLat,
		&entry.ExitLng,
		&entry.ExitLat,
		&entry.IsActive,
		&entry.CreatedAt,
		&entry.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // No active entry
		}
		return nil, fmt.Errorf("failed to get active entry: %w", err)
	}
	
	return entry, nil
}

// UpdateEntry updates a territory entry
func (r *territoryRepository) UpdateEntry(entry *domain.TerritoryEntry) error {
	query := `
		UPDATE territory_entries 
		SET exit_time = $2, exit_location = ST_GeomFromText('POINT(' || $3 || ' ' || $4 || ')', 4326), is_active = $5, updated_at = $6
		WHERE id = $1
	`
	
	entry.UpdatedAt = time.Now()
	
	_, err := r.db.Exec(
		query,
		entry.ID,
		entry.ExitTime,
		entry.ExitLng,
		entry.ExitLat,
		entry.IsActive,
		entry.UpdatedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to update territory entry: %w", err)
	}
	
	return nil
}

// GetUserEntries retrieves entries for a user
func (r *territoryRepository) GetUserEntries(userID uuid.UUID, limit, offset int) ([]*domain.TerritoryEntry, error) {
	query := `
		SELECT id, user_id, territory_id, entry_time, exit_time,
			   ST_X(entry_location) as entry_lng, ST_Y(entry_location) as entry_lat,
			   ST_X(exit_location) as exit_lng, ST_Y(exit_location) as exit_lat,
			   is_active, created_at, updated_at
		FROM territory_entries
		WHERE user_id = $1
		ORDER BY entry_time DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.db.Query(query, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get user entries: %w", err)
	}
	defer rows.Close()
	
	var entries []*domain.TerritoryEntry
	for rows.Next() {
		entry := &domain.TerritoryEntry{}
		err := rows.Scan(
			&entry.ID,
			&entry.UserID,
			&entry.TerritoryID,
			&entry.EntryTime,
			&entry.ExitTime,
			&entry.EntryLng,
			&entry.EntryLat,
			&entry.ExitLng,
			&entry.ExitLat,
			&entry.IsActive,
			&entry.CreatedAt,
			&entry.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan entry: %w", err)
		}
		entries = append(entries, entry)
	}
	
	return entries, nil
}

// GetTerritoryEntries retrieves entries for a territory
func (r *territoryRepository) GetTerritoryEntries(territoryID uuid.UUID, limit, offset int) ([]*domain.TerritoryEntry, error) {
	query := `
		SELECT id, user_id, territory_id, entry_time, exit_time,
			   ST_X(entry_location) as entry_lng, ST_Y(entry_location) as entry_lat,
			   ST_X(exit_location) as exit_lng, ST_Y(exit_location) as exit_lat,
			   is_active, created_at, updated_at
		FROM territory_entries
		WHERE territory_id = $1
		ORDER BY entry_time DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.db.Query(query, territoryID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get territory entries: %w", err)
	}
	defer rows.Close()
	
	var entries []*domain.TerritoryEntry
	for rows.Next() {
		entry := &domain.TerritoryEntry{}
		err := rows.Scan(
			&entry.ID,
			&entry.UserID,
			&entry.TerritoryID,
			&entry.EntryTime,
			&entry.ExitTime,
			&entry.EntryLng,
			&entry.EntryLat,
			&entry.ExitLng,
			&entry.ExitLat,
			&entry.IsActive,
			&entry.CreatedAt,
			&entry.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan entry: %w", err)
		}
		entries = append(entries, entry)
	}
	
	return entries, nil
}

// CreateAlert creates a new territory alert
func (r *territoryRepository) CreateAlert(alert *domain.TerritoryAlert) error {
	query := `
		INSERT INTO territory_alerts (id, user_id, territory_id, alert_type, message, location, is_read, created_at)
		VALUES ($1, $2, $3, $4, $5, ST_GeomFromText('POINT(' || $6 || ' ' || $7 || ')', 4326), $8, $9)
	`
	
	_, err := r.db.Exec(
		query,
		alert.ID,
		alert.UserID,
		alert.TerritoryID,
		alert.AlertType,
		alert.Message,
		alert.Longitude,
		alert.Latitude,
		alert.IsRead,
		alert.CreatedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to create territory alert: %w", err)
	}
	
	return nil
}

// GetUserAlerts retrieves alerts for a user
func (r *territoryRepository) GetUserAlerts(userID uuid.UUID, limit, offset int) ([]*domain.TerritoryAlert, error) {
	query := `
		SELECT id, user_id, territory_id, alert_type, message,
			   ST_X(location) as longitude, ST_Y(location) as latitude,
			   is_read, created_at
		FROM territory_alerts
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.db.Query(query, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get user alerts: %w", err)
	}
	defer rows.Close()
	
	var alerts []*domain.TerritoryAlert
	for rows.Next() {
		alert := &domain.TerritoryAlert{}
		err := rows.Scan(
			&alert.ID,
			&alert.UserID,
			&alert.TerritoryID,
			&alert.AlertType,
			&alert.Message,
			&alert.Longitude,
			&alert.Latitude,
			&alert.IsRead,
			&alert.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan alert: %w", err)
		}
		alerts = append(alerts, alert)
	}
	
	return alerts, nil
}

// GetTeamAlerts retrieves alerts for a team
func (r *territoryRepository) GetTeamAlerts(teamID uuid.UUID, limit, offset int) ([]*domain.TerritoryAlert, error) {
	query := `
		SELECT ta.id, ta.user_id, ta.territory_id, ta.alert_type, ta.message,
			   ST_X(ta.location) as longitude, ST_Y(ta.location) as latitude,
			   ta.is_read, ta.created_at
		FROM territory_alerts ta
		JOIN custom_territories t ON ta.territory_id = t.id
		WHERE t.team_id = $1
		ORDER BY ta.created_at DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.db.Query(query, teamID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get team alerts: %w", err)
	}
	defer rows.Close()
	
	var alerts []*domain.TerritoryAlert
	for rows.Next() {
		alert := &domain.TerritoryAlert{}
		err := rows.Scan(
			&alert.ID,
			&alert.UserID,
			&alert.TerritoryID,
			&alert.AlertType,
			&alert.Message,
			&alert.Longitude,
			&alert.Latitude,
			&alert.IsRead,
			&alert.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan alert: %w", err)
		}
		alerts = append(alerts, alert)
	}
	
	return alerts, nil
}

// MarkAlertRead marks an alert as read
func (r *territoryRepository) MarkAlertRead(alertID uuid.UUID) error {
	query := `UPDATE territory_alerts SET is_read = true WHERE id = $1`
	
	_, err := r.db.Exec(query, alertID)
	if err != nil {
		return fmt.Errorf("failed to mark alert as read: %w", err)
	}
	
	return nil
}

// GetTerritoryStats retrieves territory statistics for a team
func (r *territoryRepository) GetTerritoryStats(teamID uuid.UUID) (*domain.TerritoryStats, error) {
	query := `
		SELECT
			COUNT(*) as total_territories,
			COUNT(CASE WHEN is_active = true THEN 1 END) as active_territories,
			COUNT(CASE WHEN assigned_worker_id IS NOT NULL THEN 1 END) as assigned_territories
		FROM custom_territories
		WHERE team_id = $1
	`

	stats := &domain.TerritoryStats{}
	err := r.db.QueryRow(query, teamID).Scan(
		&stats.TotalTerritories,
		&stats.ActiveTerritories,
		&stats.AssignedTerritories,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get territory stats: %w", err)
	}

	// Get entry and alert counts
	entryQuery := `
		SELECT COUNT(*)
		FROM territory_entries te
		JOIN custom_territories t ON te.territory_id = t.id
		WHERE t.team_id = $1
	`

	err = r.db.QueryRow(entryQuery, teamID).Scan(&stats.TotalEntries)
	if err != nil {
		return nil, fmt.Errorf("failed to get entry count: %w", err)
	}

	alertQuery := `
		SELECT COUNT(*)
		FROM territory_alerts ta
		JOIN custom_territories t ON ta.territory_id = t.id
		WHERE t.team_id = $1
	`

	err = r.db.QueryRow(alertQuery, teamID).Scan(&stats.TotalAlerts)
	if err != nil {
		return nil, fmt.Errorf("failed to get alert count: %w", err)
	}

	return stats, nil
}

// GetUserTerritoryStats retrieves territory statistics for a user
func (r *territoryRepository) GetUserTerritoryStats(userID uuid.UUID, days int) (*domain.TerritoryStats, error) {
	query := `
		SELECT 
			COUNT(DISTINCT te.territory_id) as total_territories,
			COUNT(*) as total_entries,
			COALESCE(AVG(EXTRACT(EPOCH FROM (COALESCE(te.exit_time, NOW()) - te.entry_time)) / 60), 0) as average_time_inside
		FROM territory_entries te
		WHERE te.user_id = $1 AND te.entry_time >= NOW() - INTERVAL '%d days'
	`
	
	stats := &domain.TerritoryStats{}
	err := r.db.QueryRow(fmt.Sprintf(query, days), userID).Scan(
		&stats.TotalTerritories,
		&stats.TotalEntries,
		&stats.AverageTimeInside,
	)
	
	if err != nil {
		return nil, fmt.Errorf("failed to get user territory stats: %w", err)
	}
	
	// Get alert count
	alertQuery := `
		SELECT COUNT(*) 
		FROM territory_alerts
		WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '%d days'
	`
	
	err = r.db.QueryRow(fmt.Sprintf(alertQuery, days), userID).Scan(&stats.TotalAlerts)
	if err != nil {
		return nil, fmt.Errorf("failed to get user alert count: %w", err)
	}
	
	return stats, nil
}
