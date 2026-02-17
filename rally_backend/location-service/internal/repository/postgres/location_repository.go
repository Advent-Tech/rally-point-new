package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/location-service/internal/domain"
)

type locationRepository struct {
	db *sql.DB
}

// NewLocationRepository creates a new location repository
func NewLocationRepository(db *sql.DB) domain.LocationRepository {
	return &locationRepository{db: db}
}

// CreateTrack creates a new location track
func (r *locationRepository) CreateTrack(track *domain.LocationTrack) error {
	// Insert with PostGIS location column - use separate parameters for ST_MakePoint
	query := `
		INSERT INTO location_tracks (id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at, location)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, ST_SetSRID(ST_MakePoint($11, $12), 4326))
	`

	_, err := r.db.Exec(
		query,
		track.ID,
		track.UserID,
		track.Latitude,
		track.Longitude,
		track.Accuracy,
		track.Speed,
		track.Heading,
		track.SessionID,
		track.TrackedAt,
		track.CreatedAt,
		track.Longitude, // $11 for ST_MakePoint (longitude first)
		track.Latitude,  // $12 for ST_MakePoint (latitude second)
	)

	if err != nil {
		return fmt.Errorf("failed to create location track: %w", err)
	}

	return nil
}

// GetTracksByUserID retrieves location tracks by user ID
func (r *locationRepository) GetTracksByUserID(userID uuid.UUID, limit, offset int) ([]*domain.LocationTrack, error) {
	query := `
		SELECT id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at
		FROM location_tracks
		WHERE user_id = $1
		ORDER BY tracked_at DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.db.Query(query, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get tracks by user: %w", err)
	}
	defer rows.Close()
	
	var tracks []*domain.LocationTrack
	for rows.Next() {
		track := &domain.LocationTrack{}
		err := rows.Scan(
			&track.ID,
			&track.UserID,
			&track.Latitude,
			&track.Longitude,
			&track.Accuracy,
			&track.Speed,
			&track.Heading,
			&track.SessionID,
			&track.TrackedAt,
			&track.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan track: %w", err)
		}
		tracks = append(tracks, track)
	}
	
	return tracks, nil
}

// GetTracksBySessionID retrieves location tracks by session ID
func (r *locationRepository) GetTracksBySessionID(sessionID uuid.UUID) ([]*domain.LocationTrack, error) {
	query := `
		SELECT id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at
		FROM location_tracks
		WHERE session_id = $1
		ORDER BY tracked_at ASC
	`
	
	rows, err := r.db.Query(query, sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get tracks by session: %w", err)
	}
	defer rows.Close()
	
	var tracks []*domain.LocationTrack
	for rows.Next() {
		track := &domain.LocationTrack{}
		err := rows.Scan(
			&track.ID,
			&track.UserID,
			&track.Latitude,
			&track.Longitude,
			&track.Accuracy,
			&track.Speed,
			&track.Heading,
			&track.SessionID,
			&track.TrackedAt,
			&track.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan track: %w", err)
		}
		tracks = append(tracks, track)
	}
	
	return tracks, nil
}

// GetTracksInTimeRange retrieves location tracks in a time range
func (r *locationRepository) GetTracksInTimeRange(userID uuid.UUID, startTime, endTime time.Time) ([]*domain.LocationTrack, error) {
	query := `
		SELECT id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at
		FROM location_tracks
		WHERE user_id = $1 AND tracked_at BETWEEN $2 AND $3
		ORDER BY tracked_at ASC
	`
	
	rows, err := r.db.Query(query, userID, startTime, endTime)
	if err != nil {
		return nil, fmt.Errorf("failed to get tracks in time range: %w", err)
	}
	defer rows.Close()
	
	var tracks []*domain.LocationTrack
	for rows.Next() {
		track := &domain.LocationTrack{}
		err := rows.Scan(
			&track.ID,
			&track.UserID,
			&track.Latitude,
			&track.Longitude,
			&track.Accuracy,
			&track.Speed,
			&track.Heading,
			&track.SessionID,
			&track.TrackedAt,
			&track.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan track: %w", err)
		}
		tracks = append(tracks, track)
	}
	
	return tracks, nil
}

// GetLastTrackForSession gets the most recent track for a session (before the given track)
func (r *locationRepository) GetLastTrackForSession(sessionID uuid.UUID, beforeTrackID uuid.UUID) (*domain.LocationTrack, error) {
	query := `
		SELECT id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at
		FROM location_tracks
		WHERE session_id = $1 AND id != $2
		ORDER BY tracked_at DESC
		LIMIT 1
	`

	track := &domain.LocationTrack{}
	err := r.db.QueryRow(query, sessionID, beforeTrackID).Scan(
		&track.ID,
		&track.UserID,
		&track.Latitude,
		&track.Longitude,
		&track.Accuracy,
		&track.Speed,
		&track.Heading,
		&track.SessionID,
		&track.TrackedAt,
		&track.CreatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // First track in session
		}
		return nil, fmt.Errorf("failed to get last track for session: %w", err)
	}

	return track, nil
}

// IncrementSessionDistance atomically adds distance and increments location count
func (r *locationRepository) IncrementSessionDistance(sessionID uuid.UUID, addDistance float64) error {
	query := `
		UPDATE location_sessions
		SET total_distance = total_distance + $2,
			location_count = location_count + 1,
			updated_at = NOW()
		WHERE id = $1 AND is_active = true
	`

	_, err := r.db.Exec(query, sessionID, addDistance)
	if err != nil {
		return fmt.Errorf("failed to increment session distance: %w", err)
	}

	return nil
}

// CreateSession creates a new location session
func (r *locationRepository) CreateSession(session *domain.LocationSession) error {
	query := `
		INSERT INTO location_sessions (id, user_id, start_time, end_time, total_distance, location_count, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	
	_, err := r.db.Exec(
		query,
		session.ID,
		session.UserID,
		session.StartTime,
		session.EndTime,
		session.TotalDistance,
		session.LocationCount,
		session.IsActive,
		session.CreatedAt,
		session.UpdatedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to create session: %w", err)
	}
	
	return nil
}

// GetSessionByID retrieves a session by ID
func (r *locationRepository) GetSessionByID(id uuid.UUID) (*domain.LocationSession, error) {
	query := `
		SELECT id, user_id, start_time, end_time, total_distance, location_count, is_active, created_at, updated_at
		FROM location_sessions
		WHERE id = $1
	`
	
	session := &domain.LocationSession{}
	err := r.db.QueryRow(query, id).Scan(
		&session.ID,
		&session.UserID,
		&session.StartTime,
		&session.EndTime,
		&session.TotalDistance,
		&session.LocationCount,
		&session.IsActive,
		&session.CreatedAt,
		&session.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("session not found")
		}
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	
	return session, nil
}

// GetActiveSession retrieves the active session for a user
func (r *locationRepository) GetActiveSession(userID uuid.UUID) (*domain.LocationSession, error) {
	query := `
		SELECT id, user_id, start_time, end_time, total_distance, location_count, is_active, created_at, updated_at
		FROM location_sessions
		WHERE user_id = $1 AND is_active = true
		ORDER BY start_time DESC
		LIMIT 1
	`
	
	session := &domain.LocationSession{}
	err := r.db.QueryRow(query, userID).Scan(
		&session.ID,
		&session.UserID,
		&session.StartTime,
		&session.EndTime,
		&session.TotalDistance,
		&session.LocationCount,
		&session.IsActive,
		&session.CreatedAt,
		&session.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // No active session
		}
		return nil, fmt.Errorf("failed to get active session: %w", err)
	}
	
	return session, nil
}

// UpdateSession updates a location session
func (r *locationRepository) UpdateSession(session *domain.LocationSession) error {
	query := `
		UPDATE location_sessions 
		SET end_time = $2, total_distance = $3, location_count = $4, is_active = $5, updated_at = $6
		WHERE id = $1
	`
	
	session.UpdatedAt = time.Now()
	
	_, err := r.db.Exec(
		query,
		session.ID,
		session.EndTime,
		session.TotalDistance,
		session.LocationCount,
		session.IsActive,
		session.UpdatedAt,
	)
	
	if err != nil {
		return fmt.Errorf("failed to update session: %w", err)
	}
	
	return nil
}

// EndSession ends a location session
func (r *locationRepository) EndSession(sessionID uuid.UUID) error {
	query := `
		UPDATE location_sessions 
		SET end_time = $2, is_active = false, updated_at = $2
		WHERE id = $1
	`
	
	now := time.Now()
	_, err := r.db.Exec(query, sessionID, now)
	if err != nil {
		return fmt.Errorf("failed to end session: %w", err)
	}
	
	return nil
}

// GetUserSessions retrieves sessions for a user
func (r *locationRepository) GetUserSessions(userID uuid.UUID, limit, offset int) ([]*domain.LocationSession, error) {
	query := `
		SELECT id, user_id, start_time, end_time, total_distance, location_count, is_active, created_at, updated_at
		FROM location_sessions
		WHERE user_id = $1
		ORDER BY start_time DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.db.Query(query, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get user sessions: %w", err)
	}
	defer rows.Close()
	
	var sessions []*domain.LocationSession
	for rows.Next() {
		session := &domain.LocationSession{}
		err := rows.Scan(
			&session.ID,
			&session.UserID,
			&session.StartTime,
			&session.EndTime,
			&session.TotalDistance,
			&session.LocationCount,
			&session.IsActive,
			&session.CreatedAt,
			&session.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan session: %w", err)
		}
		sessions = append(sessions, session)
	}
	
	return sessions, nil
}

// GetLocationStats retrieves location statistics for a user
func (r *locationRepository) GetLocationStats(userID uuid.UUID, days int) (*domain.LocationStats, error) {
	query := `
		SELECT 
			COALESCE(SUM(total_distance), 0) as total_distance,
			COALESCE(EXTRACT(EPOCH FROM SUM(COALESCE(end_time, NOW()) - start_time)), 0) as total_time,
			COALESCE(AVG(CASE WHEN total_distance > 0 AND end_time IS NOT NULL 
				THEN total_distance / EXTRACT(EPOCH FROM (end_time - start_time)) * 3600 
				ELSE 0 END), 0) as average_speed,
			COALESCE(MAX(CASE WHEN total_distance > 0 AND end_time IS NOT NULL 
				THEN total_distance / EXTRACT(EPOCH FROM (end_time - start_time)) * 3600 
				ELSE 0 END), 0) as max_speed,
			COUNT(*) as session_count
		FROM location_sessions
		WHERE user_id = $1 AND start_time >= NOW() - INTERVAL '%d days'
	`
	
	stats := &domain.LocationStats{}
	err := r.db.QueryRow(fmt.Sprintf(query, days), userID).Scan(
		&stats.TotalDistance,
		&stats.TotalTime,
		&stats.AverageSpeed,
		&stats.MaxSpeed,
		&stats.SessionCount,
	)
	
	if err != nil {
		return nil, fmt.Errorf("failed to get location stats: %w", err)
	}
	
	// Get location count
	countQuery := `
		SELECT COUNT(*) 
		FROM location_tracks 
		WHERE user_id = $1 AND tracked_at >= NOW() - INTERVAL '%d days'
	`
	
	err = r.db.QueryRow(fmt.Sprintf(countQuery, days), userID).Scan(&stats.LocationCount)
	if err != nil {
		return nil, fmt.Errorf("failed to get location count: %w", err)
	}
	
	// Get last location time
	lastTimeQuery := `
		SELECT tracked_at 
		FROM location_tracks 
		WHERE user_id = $1 
		ORDER BY tracked_at DESC 
		LIMIT 1
	`
	
	var lastTime time.Time
	err = r.db.QueryRow(lastTimeQuery, userID).Scan(&lastTime)
	if err == nil {
		stats.LastLocationTime = &lastTime
	}
	
	return stats, nil
}

// GetActiveWorkers retrieves all active workers with their latest locations
func (r *locationRepository) GetActiveWorkers() ([]*domain.WorkerLocation, error) {
	query := `
		SELECT DISTINCT ON (u.id) 
			u.id, u.display_name, lt.latitude, lt.longitude, lt.accuracy, lt.speed, lt.heading, 
			u.is_online, u.last_active_at, lt.tracked_at
		FROM users u
		JOIN location_tracks lt ON u.id = lt.user_id
		WHERE u.is_online = true 
		AND lt.tracked_at >= NOW() - INTERVAL '5 minutes'
		ORDER BY u.id, lt.tracked_at DESC
	`
	
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get active workers: %w", err)
	}
	defer rows.Close()
	
	var workers []*domain.WorkerLocation
	for rows.Next() {
		worker := &domain.WorkerLocation{}
		err := rows.Scan(
			&worker.UserID,
			&worker.UserName,
			&worker.Latitude,
			&worker.Longitude,
			&worker.Accuracy,
			&worker.Speed,
			&worker.Heading,
			&worker.IsActive,
			&worker.LastSeen,
			&worker.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan worker: %w", err)
		}
		workers = append(workers, worker)
	}
	
	return workers, nil
}

// UpdateWorkerLocation updates a worker's real-time location in Redis (would be implemented with Redis)
func (r *locationRepository) UpdateWorkerLocation(location *domain.WorkerLocation) error {
	// This would typically update Redis for real-time data
	// For now, we'll just ensure the latest location is in the database
	return nil
}

// SetWorkerOffline sets a worker as offline
func (r *locationRepository) SetWorkerOffline(userID uuid.UUID) error {
	// This would typically update Redis and the users table
	query := `UPDATE users SET is_online = false, last_active_at = NOW() WHERE id = $1`
	
	_, err := r.db.Exec(query, userID)
	if err != nil {
		return fmt.Errorf("failed to set worker offline: %w", err)
	}
	
	return nil
}
