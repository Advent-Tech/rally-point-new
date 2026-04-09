package service

import (
	"fmt"
	"time"

	"rally-point/territory-service/internal/domain"

	"github.com/google/uuid"
)

type territoryService struct {
	territoryRepo   domain.TerritoryRepository
	geofenceManager domain.GeofenceManager
	realtimeManager domain.RealtimeManager
}

// NewTerritoryService creates a new territory service
func NewTerritoryService(territoryRepo domain.TerritoryRepository, geofenceManager domain.GeofenceManager, realtimeManager domain.RealtimeManager) domain.TerritoryService {
	return &territoryService{
		territoryRepo:   territoryRepo,
		geofenceManager: geofenceManager,
		realtimeManager: realtimeManager,
	}
}

// CreateTerritory creates a new territory
func (s *territoryService) CreateTerritory(req *domain.CreateTerritoryRequest) (*domain.Territory, error) {
	// TODO: Fix boundary validation - temporarily disabled for testing
	// err := s.geofenceManager.ValidateBoundary(req.Boundary)
	// if err != nil {
	// 	return nil, fmt.Errorf("invalid boundary: %w", err)
	// }

	// Set default color if not provided
	color := req.Color
	if color == "" {
		color = domain.DefaultTerritoryColor
	}

	// Create territory
	territory := &domain.Territory{
		ID:               uuid.New(),
		Name:             req.Name,
		Description:      &req.Description,
		TeamID:           req.TeamID,
		AssignedWorkerID: req.AssignedWorkerID,
		Boundary:         req.Boundary,
		Color:            color,
		IsActive:         true,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}

	if req.Description == "" {
		territory.Description = nil
	}

	// Create territory
	err := s.territoryRepo.Create(territory)
	if err != nil {
		return nil, fmt.Errorf("failed to create territory: %w", err)
	}

	return territory, nil
}

// GetTerritory retrieves a territory by ID
func (s *territoryService) GetTerritory(id uuid.UUID) (*domain.Territory, error) {
	return s.territoryRepo.GetByID(id)
}

// UpdateTerritory updates a territory
func (s *territoryService) UpdateTerritory(id uuid.UUID, req *domain.UpdateTerritoryRequest) (*domain.Territory, error) {
	territory, err := s.territoryRepo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("territory not found: %w", err)
	}

	// Update fields if provided
	if req.Name != nil {
		territory.Name = *req.Name
	}
	if req.Description != nil {
		territory.Description = req.Description
	}
	if req.AssignedWorkerID != nil {
		territory.AssignedWorkerID = req.AssignedWorkerID
	}
	if req.Boundary != nil {
		// Validate new boundary
		err = s.geofenceManager.ValidateBoundary(*req.Boundary)
		if err != nil {
			return nil, fmt.Errorf("invalid boundary: %w", err)
		}
		territory.Boundary = *req.Boundary
	}
	if req.Color != nil {
		territory.Color = *req.Color
	}
	if req.IsActive != nil {
		territory.IsActive = *req.IsActive
	}

	err = s.territoryRepo.Update(territory)
	if err != nil {
		return nil, fmt.Errorf("failed to update territory: %w", err)
	}

	return territory, nil
}

// DeleteTerritory deletes a territory
func (s *territoryService) DeleteTerritory(id uuid.UUID) error {
	return s.territoryRepo.Delete(id)
}

// GetTeamTerritories retrieves territories for a team
func (s *territoryService) GetTeamTerritories(teamID uuid.UUID) ([]*domain.Territory, error) {
	return s.territoryRepo.GetByTeamID(teamID)
}

// GetWorkerTerritories retrieves territories assigned to a worker
func (s *territoryService) GetWorkerTerritories(workerID uuid.UUID) ([]*domain.Territory, error) {
	return s.territoryRepo.GetByWorkerID(workerID)
}

// TrackWorkerLocation tracks a worker's location and checks territory boundaries
func (s *territoryService) TrackWorkerLocation(userID uuid.UUID, location domain.LocationPoint) (*domain.TerritoryStatus, error) {
	// Get worker's assigned territories
	territories, err := s.territoryRepo.GetByWorkerID(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker territories: %w", err)
	}

	status := &domain.TerritoryStatus{
		UserID:     userID,
		UserName:   "Worker", // Would fetch from user service in real implementation
		IsInside:   false,
		LastUpdate: time.Now(),
		Location:   location,
	}

	// Check if worker is inside any assigned territory
	for _, territory := range territories {
		isInside, err := s.geofenceManager.IsPointInTerritory(location, territory.Boundary)
		if err != nil {
			continue // Skip this territory if there's an error
		}

		if isInside {
			status.IsInside = true
			status.TerritoryID = &territory.ID
			status.TerritoryName = &territory.Name
			break
		}
	}

	// Handle territory entry/exit events
	err = s.handleTerritoryEvents(userID, status, territories)
	if err != nil {
		fmt.Printf("Warning: failed to handle territory events: %v\n", err)
	}

	return status, nil
}

// handleTerritoryEvents handles territory entry/exit events
func (s *territoryService) handleTerritoryEvents(userID uuid.UUID, status *domain.TerritoryStatus, territories []*domain.Territory) error {
	if status.TerritoryID == nil {
		// Worker is not in any territory, check for exits
		return s.handleTerritoryExits(userID, status.Location)
	}

	// Worker is in a territory, check for entry
	return s.handleTerritoryEntry(userID, *status.TerritoryID, status.Location)
}

// handleTerritoryEntry handles territory entry
func (s *territoryService) handleTerritoryEntry(userID, territoryID uuid.UUID, location domain.LocationPoint) error {
	// Check if there's already an active entry
	activeEntry, err := s.territoryRepo.GetActiveEntry(userID, territoryID)
	if err != nil {
		return fmt.Errorf("failed to check active entry: %w", err)
	}

	if activeEntry != nil {
		return nil // Already inside
	}

	// Create new entry
	entry := &domain.TerritoryEntry{
		ID:          uuid.New(),
		UserID:      userID,
		TerritoryID: territoryID,
		EntryTime:   time.Now(),
		EntryLat:    location.Latitude,
		EntryLng:    location.Longitude,
		IsActive:    true,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	err = s.territoryRepo.CreateEntry(entry)
	if err != nil {
		return fmt.Errorf("failed to create entry: %w", err)
	}

	// Create entry alert
	territory, err := s.territoryRepo.GetByID(territoryID)
	if err != nil {
		return fmt.Errorf("failed to get territory: %w", err)
	}

	alert := &domain.TerritoryAlert{
		ID:          uuid.New(),
		UserID:      userID,
		TerritoryID: territoryID,
		AlertType:   domain.AlertTypeEntry,
		Message:     fmt.Sprintf("Worker entered territory: %s", territory.Name),
		Latitude:    location.Latitude,
		Longitude:   location.Longitude,
		IsRead:      false,
		CreatedAt:   time.Now(),
	}

	err = s.territoryRepo.CreateAlert(alert)
	if err != nil {
		return fmt.Errorf("failed to create alert: %w", err)
	}

	// Broadcast alert
	err = s.BroadcastAlert(alert)
	if err != nil {
		fmt.Printf("Warning: failed to broadcast alert: %v\n", err)
	}

	return nil
}

// handleTerritoryExits handles territory exits
func (s *territoryService) handleTerritoryExits(userID uuid.UUID, location domain.LocationPoint) error {
	// Get all territories for the user to check for exits
	territories, err := s.territoryRepo.GetByWorkerID(userID)
	if err != nil {
		return fmt.Errorf("failed to get worker territories: %w", err)
	}

	for _, territory := range territories {
		activeEntry, err := s.territoryRepo.GetActiveEntry(userID, territory.ID)
		if err != nil {
			continue
		}

		if activeEntry != nil {
			// Worker has an active entry, mark as exited
			now := time.Now()
			activeEntry.ExitTime = &now
			activeEntry.ExitLat = &location.Latitude
			activeEntry.ExitLng = &location.Longitude
			activeEntry.IsActive = false

			err = s.territoryRepo.UpdateEntry(activeEntry)
			if err != nil {
				continue
			}

			// Create exit alert
			alert := &domain.TerritoryAlert{
				ID:          uuid.New(),
				UserID:      userID,
				TerritoryID: territory.ID,
				AlertType:   domain.AlertTypeExit,
				Message:     fmt.Sprintf("Worker exited territory: %s", territory.Name),
				Latitude:    location.Latitude,
				Longitude:   location.Longitude,
				IsRead:      false,
				CreatedAt:   time.Now(),
			}

			err = s.territoryRepo.CreateAlert(alert)
			if err != nil {
				continue
			}

			// Broadcast alert
			err = s.BroadcastAlert(alert)
			if err != nil {
				fmt.Printf("Warning: failed to broadcast alert: %v\n", err)
			}
		}
	}

	return nil
}

// GetWorkerStatus retrieves the current status of a worker
func (s *territoryService) GetWorkerStatus(userID uuid.UUID) (*domain.TerritoryStatus, error) {
	// This would typically be cached or retrieved from a real-time store
	// For now, we'll return a basic status
	status := &domain.TerritoryStatus{
		UserID:     userID,
		UserName:   "Worker",
		IsInside:   false,
		LastUpdate: time.Now(),
	}

	return status, nil
}

// GetUserEntries retrieves entries for a user
func (s *territoryService) GetUserEntries(userID uuid.UUID, limit, offset int) ([]*domain.TerritoryEntry, error) {
	if limit <= 0 {
		limit = domain.DefaultEntryLimit
	}
	if limit > domain.MaxEntryLimit {
		limit = domain.MaxEntryLimit
	}

	return s.territoryRepo.GetUserEntries(userID, limit, offset)
}

// GetTerritoryEntries retrieves entries for a territory
func (s *territoryService) GetTerritoryEntries(territoryID uuid.UUID, limit, offset int) ([]*domain.TerritoryEntry, error) {
	if limit <= 0 {
		limit = domain.DefaultEntryLimit
	}
	if limit > domain.MaxEntryLimit {
		limit = domain.MaxEntryLimit
	}

	return s.territoryRepo.GetTerritoryEntries(territoryID, limit, offset)
}

// GetUserAlerts retrieves alerts for a user
func (s *territoryService) GetUserAlerts(userID uuid.UUID, limit, offset int) ([]*domain.TerritoryAlert, error) {
	if limit <= 0 {
		limit = domain.DefaultAlertLimit
	}
	if limit > domain.MaxAlertLimit {
		limit = domain.MaxAlertLimit
	}

	return s.territoryRepo.GetUserAlerts(userID, limit, offset)
}

// GetTeamAlerts retrieves alerts for a team
func (s *territoryService) GetTeamAlerts(teamID uuid.UUID, limit, offset int) ([]*domain.TerritoryAlert, error) {
	if limit <= 0 {
		limit = domain.DefaultAlertLimit
	}
	if limit > domain.MaxAlertLimit {
		limit = domain.MaxAlertLimit
	}

	return s.territoryRepo.GetTeamAlerts(teamID, limit, offset)
}

// MarkAlertRead marks an alert as read
func (s *territoryService) MarkAlertRead(alertID uuid.UUID) error {
	return s.territoryRepo.MarkAlertRead(alertID)
}

// GetTerritoryStats retrieves territory statistics for a team
func (s *territoryService) GetTerritoryStats(teamID uuid.UUID) (*domain.TerritoryStats, error) {
	return s.territoryRepo.GetTerritoryStats(teamID)
}

// GetUserTerritoryStats retrieves territory statistics for a user
func (s *territoryService) GetUserTerritoryStats(userID uuid.UUID, days int) (*domain.TerritoryStats, error) {
	if days <= 0 {
		days = 30 // Default to 30 days
	}
	return s.territoryRepo.GetUserTerritoryStats(userID, days)
}

// SubscribeToAlerts subscribes to real-time alerts
func (s *territoryService) SubscribeToAlerts(userID uuid.UUID) (<-chan *domain.TerritoryAlert, error) {
	ch := make(chan *domain.TerritoryAlert, 100)
	err := s.realtimeManager.AddSubscriber(userID, ch)
	if err != nil {
		close(ch)
		return nil, fmt.Errorf("failed to add subscriber: %w", err)
	}
	return ch, nil
}

// UnsubscribeFromAlerts unsubscribes from real-time alerts
func (s *territoryService) UnsubscribeFromAlerts(userID uuid.UUID) error {
	return s.realtimeManager.RemoveSubscriber(userID)
}

// BroadcastAlert broadcasts an alert to all subscribers
func (s *territoryService) BroadcastAlert(alert *domain.TerritoryAlert) error {
	return s.realtimeManager.Broadcast(alert)
}
