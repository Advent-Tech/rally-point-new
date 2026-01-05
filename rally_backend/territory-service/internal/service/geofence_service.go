package service

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// geofenceService implements the GeofenceService interface
type geofenceService struct {
	repo            domain.GeofenceRepository
	geofenceManager domain.GeofenceManager
}

// NewGeofenceService creates a new geofence service
func NewGeofenceService(repo domain.GeofenceRepository, manager domain.GeofenceManager) domain.GeofenceService {
	return &geofenceService{
		repo:            repo,
		geofenceManager: manager,
	}
}

// ProcessLocationUpdate processes a location update and detects territory entry/exit
func (s *geofenceService) ProcessLocationUpdate(update *domain.WorkerLocationUpdate) (*domain.GeofenceEvent, error) {
	// First, check if worker has an active work session
	activeSession, err := s.repo.GetActiveWorkSession(update.WorkerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get active work session: %w", err)
	}

	// Check if worker is currently inside any assigned territory
	checkResult, err := s.repo.CheckWorkerInTerritory(update.WorkerID, update.Latitude, update.Longitude)
	if err != nil {
		return nil, fmt.Errorf("failed to check worker territory: %w", err)
	}

	// If worker check returns no result and team ID is provided, check team territories
	if !checkResult.IsInside && update.TeamID != nil {
		teamResult, err := s.repo.CheckTeamTerritory(*update.TeamID, update.Latitude, update.Longitude)
		if err != nil {
			return nil, fmt.Errorf("failed to check team territory: %w", err)
		}
		checkResult = teamResult
	}

	// Case 1: Worker is inside a territory
	if checkResult.IsInside {
		// If no active session, worker just entered - create a new session
		if activeSession == nil {
			session := &domain.TerritoryWorkSession{
				WorkerID:    update.WorkerID,
				TerritoryID: *checkResult.TerritoryID,
				AssignmentID: checkResult.AssignmentID,
				EntryLat:    update.Latitude,
				EntryLng:    update.Longitude,
			}

			if err := s.repo.CreateWorkSession(session); err != nil {
				return nil, fmt.Errorf("failed to create work session: %w", err)
			}

			// Return entry event
			territoryName := ""
			if checkResult.EntityName != nil {
				territoryName = *checkResult.EntityName
			}

			return &domain.GeofenceEvent{
				EventType:     "entry",
				WorkerID:      update.WorkerID,
				TerritoryID:   *checkResult.TerritoryID,
				AssignmentID:  checkResult.AssignmentID,
				TerritoryName: territoryName,
				Latitude:      update.Latitude,
				Longitude:     update.Longitude,
				Timestamp:     update.Timestamp,
				SessionID:     &session.ID,
			}, nil
		}

		// If active session exists but for a different territory, end old and start new
		if activeSession.TerritoryID != *checkResult.TerritoryID {
			// Calculate time spent in previous territory
			timeSpent := int(time.Since(activeSession.EntryTime).Seconds())
			distance := s.geofenceManager.CalculateDistance(
				domain.LocationPoint{Latitude: activeSession.EntryLat, Longitude: activeSession.EntryLng},
				domain.LocationPoint{Latitude: update.Latitude, Longitude: update.Longitude},
			)

			// End the old session
			if err := s.repo.EndWorkSession(activeSession.ID, update.Latitude, update.Longitude, timeSpent, distance); err != nil {
				return nil, fmt.Errorf("failed to end previous work session: %w", err)
			}

			// Create new session for the new territory
			newSession := &domain.TerritoryWorkSession{
				WorkerID:    update.WorkerID,
				TerritoryID: *checkResult.TerritoryID,
				AssignmentID: checkResult.AssignmentID,
				EntryLat:    update.Latitude,
				EntryLng:    update.Longitude,
			}

			if err := s.repo.CreateWorkSession(newSession); err != nil {
				return nil, fmt.Errorf("failed to create new work session: %w", err)
			}

			territoryName := ""
			if checkResult.EntityName != nil {
				territoryName = *checkResult.EntityName
			}

			return &domain.GeofenceEvent{
				EventType:     "entry",
				WorkerID:      update.WorkerID,
				TerritoryID:   *checkResult.TerritoryID,
				AssignmentID:  checkResult.AssignmentID,
				TerritoryName: territoryName,
				Latitude:      update.Latitude,
				Longitude:     update.Longitude,
				Timestamp:     update.Timestamp,
				SessionID:     &newSession.ID,
			}, nil
		}

		// Worker is still in the same territory - no event
		return nil, nil
	}

	// Case 2: Worker is NOT inside any territory
	// If there's an active session, worker just exited - end the session
	if activeSession != nil {
		timeSpent := int(time.Since(activeSession.EntryTime).Seconds())
		distance := s.geofenceManager.CalculateDistance(
			domain.LocationPoint{Latitude: activeSession.EntryLat, Longitude: activeSession.EntryLng},
			domain.LocationPoint{Latitude: update.Latitude, Longitude: update.Longitude},
		)

		if err := s.repo.EndWorkSession(activeSession.ID, update.Latitude, update.Longitude, timeSpent, distance); err != nil {
			return nil, fmt.Errorf("failed to end work session: %w", err)
		}

		return &domain.GeofenceEvent{
			EventType:     "exit",
			WorkerID:      update.WorkerID,
			TerritoryID:   activeSession.TerritoryID,
			AssignmentID:  activeSession.AssignmentID,
			TerritoryName: "", // Could look up from territory
			Latitude:      update.Latitude,
			Longitude:     update.Longitude,
			Timestamp:     update.Timestamp,
			SessionID:     &activeSession.ID,
		}, nil
	}

	// Worker is outside and had no active session - no event
	return nil, nil
}

// CheckWorkerLocation checks if a worker is inside any assigned territory
func (s *geofenceService) CheckWorkerLocation(req *domain.GeofenceCheckRequest) (*domain.GeofenceCheckResult, error) {
	// First check worker-specific assignments
	result, err := s.repo.CheckWorkerInTerritory(req.WorkerID, req.Latitude, req.Longitude)
	if err != nil {
		return nil, fmt.Errorf("failed to check worker territory: %w", err)
	}

	// If not inside and team ID provided, check team assignments
	if !result.IsInside && req.TeamID != nil {
		teamResult, err := s.repo.CheckTeamTerritory(*req.TeamID, req.Latitude, req.Longitude)
		if err != nil {
			return nil, fmt.Errorf("failed to check team territory: %w", err)
		}
		return teamResult, nil
	}

	return result, nil
}

// GetWorkerCurrentTerritory gets the worker's current territory from active session
func (s *geofenceService) GetWorkerCurrentTerritory(workerID uuid.UUID) (*domain.GeofenceCheckResult, error) {
	session, err := s.repo.GetActiveWorkSession(workerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get active work session: %w", err)
	}

	if session == nil {
		return &domain.GeofenceCheckResult{IsInside: false}, nil
	}

	return &domain.GeofenceCheckResult{
		IsInside:     true,
		TerritoryID:  &session.TerritoryID,
		AssignmentID: session.AssignmentID,
	}, nil
}

// GetWorkerWorkSessions gets the work session history for a worker
func (s *geofenceService) GetWorkerWorkSessions(workerID uuid.UUID, limit, offset int) ([]*domain.TerritoryWorkSessionWithDetails, error) {
	return s.repo.GetWorkerWorkSessions(workerID, limit, offset)
}

// CheckIn performs a manual check-in for a worker
func (s *geofenceService) CheckIn(req *domain.CheckInRequest) (*domain.TerritoryWorkSessionWithDetails, error) {
	// Check if worker already has an active session
	existingSession, err := s.repo.GetActiveWorkSession(req.WorkerID)
	if err != nil {
		return nil, fmt.Errorf("failed to check existing session: %w", err)
	}

	if existingSession != nil {
		return nil, fmt.Errorf("worker already has an active work session")
	}

	// Create a new work session
	session := &domain.TerritoryWorkSession{
		WorkerID:    req.WorkerID,
		TerritoryID: req.TerritoryID,
	}

	// Set location if provided
	if req.Latitude != nil && req.Longitude != nil {
		session.EntryLat = *req.Latitude
		session.EntryLng = *req.Longitude
	}

	// Create the session with territory name
	createdSession, err := s.repo.CreateWorkSessionWithDetails(session, req.TerritoryName)
	if err != nil {
		return nil, fmt.Errorf("failed to create work session: %w", err)
	}

	return createdSession, nil
}

// CheckOut performs a manual check-out for a worker
func (s *geofenceService) CheckOut(req *domain.CheckOutRequest) (*domain.TerritoryWorkSessionWithDetails, error) {
	// Get the active session
	activeSession, err := s.repo.GetActiveWorkSession(req.WorkerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get active session: %w", err)
	}

	if activeSession == nil {
		return nil, fmt.Errorf("no active work session found")
	}

	// End the session with notes
	endedSession, err := s.repo.EndWorkSessionWithNotes(activeSession.ID, req.Notes)
	if err != nil {
		return nil, fmt.Errorf("failed to end work session: %w", err)
	}

	return endedSession, nil
}

// LogVisit logs a visit during an active work session
func (s *geofenceService) LogVisit(req *domain.LogVisitRequest) (*domain.VisitRecord, error) {
	// Get the work session to verify it exists and is active
	session, err := s.repo.GetWorkSession(req.SessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get work session: %w", err)
	}

	if session == nil {
		return nil, fmt.Errorf("work session not found")
	}

	if session.ExitTime != nil {
		return nil, fmt.Errorf("cannot log visit to an ended session")
	}

	// Create the visit record
	visit := &domain.VisitRecord{
		ID:          uuid.New(),
		SessionID:   req.SessionID,
		WorkerID:    session.WorkerID,
		TerritoryID: session.TerritoryID,
		Address:     req.Address,
		Outcome:     req.Outcome,
		Notes:       req.Notes,
		Latitude:    req.Latitude,
		Longitude:   req.Longitude,
		VisitedAt:   time.Now(),
	}

	if err := s.repo.CreateVisitRecord(visit); err != nil {
		return nil, fmt.Errorf("failed to create visit record: %w", err)
	}

	return visit, nil
}

// GetSessionVisits gets all visits for a session
func (s *geofenceService) GetSessionVisits(sessionID uuid.UUID) ([]*domain.VisitRecord, error) {
	return s.repo.GetSessionVisits(sessionID)
}

// GetWorkerCurrentSession gets the worker's current active session with details
func (s *geofenceService) GetWorkerCurrentSession(workerID uuid.UUID) (*domain.TerritoryWorkSessionWithDetails, error) {
	session, err := s.repo.GetActiveWorkSession(workerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get active work session: %w", err)
	}

	if session == nil {
		return nil, nil
	}

	// Get the full session details
	return s.repo.GetWorkSession(session.ID)
}

// GetActiveWorkers gets all currently active workers (with active work sessions)
func (s *geofenceService) GetActiveWorkers() ([]*domain.TerritoryWorkSessionWithDetails, error) {
	return s.repo.GetAllActiveSessions()
}

// GetTeamActiveWorkers gets active workers for a specific team
func (s *geofenceService) GetTeamActiveWorkers(teamID uuid.UUID) ([]*domain.TerritoryWorkSessionWithDetails, error) {
	return s.repo.GetTeamActiveSessions(teamID)
}

// GetWorkerVisits gets all visits for a worker on a specific date
func (s *geofenceService) GetWorkerVisits(workerID uuid.UUID, date time.Time) ([]*domain.VisitRecord, error) {
	return s.repo.GetWorkerVisits(workerID, date)
}

// GetWorkerWorkSessionsByDate gets work sessions for a worker on a specific date
func (s *geofenceService) GetWorkerWorkSessionsByDate(workerID uuid.UUID, date time.Time) ([]*domain.TerritoryWorkSessionWithDetails, error) {
	return s.repo.GetWorkerWorkSessionsByDate(workerID, date)
}
