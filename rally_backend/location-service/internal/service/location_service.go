package service

import (
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"rally-point/location-service/internal/domain"
)

type locationService struct {
	locationRepo    domain.LocationRepository
	realtimeManager domain.RealtimeManager
	distanceCalc    domain.DistanceCalculator
	geofenceClient  domain.GeofenceClient
	natsPublisher   domain.LocationEventPublisher
	workerCache     domain.WorkerLocationCache
	gpsSmoother     *GPSSmoother
	kalmanFilter    *KalmanFilter
}

// NewLocationService creates a new location service
func NewLocationService(locationRepo domain.LocationRepository, realtimeManager domain.RealtimeManager, distanceCalc domain.DistanceCalculator) domain.LocationService {
	return &locationService{
		locationRepo:    locationRepo,
		realtimeManager: realtimeManager,
		distanceCalc:    distanceCalc,
		geofenceClient:  nil,                 // Optional geofence client
		gpsSmoother:     NewGPSSmoother(0.2), // Alpha 0.2 for moderate smoothing
		kalmanFilter:    NewKalmanFilter(3.0, 100.0),
	}
}

// NewLocationServiceWithGeofence creates a new location service with geofence integration
func NewLocationServiceWithGeofence(locationRepo domain.LocationRepository, realtimeManager domain.RealtimeManager, distanceCalc domain.DistanceCalculator, geofenceClient domain.GeofenceClient) domain.LocationService {
	return &locationService{
		locationRepo:    locationRepo,
		realtimeManager: realtimeManager,
		distanceCalc:    distanceCalc,
		geofenceClient:  geofenceClient,
		gpsSmoother:     NewGPSSmoother(0.2),
		kalmanFilter:    NewKalmanFilter(3.0, 100.0),
	}
}

// NewLocationServiceWithNATS creates a location service that publishes geofence events via NATS (async)
func NewLocationServiceWithNATS(locationRepo domain.LocationRepository, realtimeManager domain.RealtimeManager, distanceCalc domain.DistanceCalculator, publisher domain.LocationEventPublisher, workerCache domain.WorkerLocationCache) domain.LocationService {
	return &locationService{
		locationRepo:    locationRepo,
		realtimeManager: realtimeManager,
		distanceCalc:    distanceCalc,
		natsPublisher:   publisher,
		workerCache:     workerCache,
		gpsSmoother:     NewGPSSmoother(0.2),
		kalmanFilter:    NewKalmanFilter(3.0, 100.0),
	}
}

// UpdateLocation updates a user's location
func (s *locationService) UpdateLocation(userID uuid.UUID, update *domain.LocationUpdate) (*domain.LocationTrack, error) {
	// Apply GPS smoothing using Kalman filter (better for varying accuracy)
	smoothedLat, smoothedLng := s.kalmanFilter.Smooth(userID, update.Latitude, update.Longitude, update.Accuracy)

	// Create location track with both raw and smoothed coordinates
	track := &domain.LocationTrack{
		ID:                uuid.New(),
		UserID:            userID,
		Latitude:          update.Latitude,
		Longitude:         update.Longitude,
		SmoothedLatitude:  &smoothedLat,
		SmoothedLongitude: &smoothedLng,
		Accuracy:          update.Accuracy,
		Speed:             update.Speed,
		Heading:           update.Heading,
		SessionID:         update.SessionID,
		TrackedAt:         time.Now(),
		CreatedAt:         time.Now(),
	}

	// Save to database
	err := s.locationRepo.CreateTrack(track)
	if err != nil {
		return nil, fmt.Errorf("failed to save location track: %w", err)
	}

	// Update session if provided
	if update.SessionID != nil {
		err = s.updateSessionWithNewLocation(*update.SessionID, track)
		if err != nil {
			// Log error but don't fail the location update
			fmt.Printf("Warning: failed to update session: %v\n", err)
		}
	}

	// Create worker location for real-time updates
	workerLocation := &domain.WorkerLocation{
		UserID:    userID,
		UserName:  "", // Would be fetched from user service in real implementation
		Latitude:  update.Latitude,
		Longitude: update.Longitude,
		Accuracy:  update.Accuracy,
		Speed:     update.Speed,
		Heading:   update.Heading,
		IsActive:  true,
		LastSeen:  time.Now(),
		UpdatedAt: time.Now(),
	}
	if update.TeamID != nil {
		workerLocation.TeamID = update.TeamID.String()
	}

	// Update real-time location in Redis cache
	if s.workerCache != nil {
		if cacheErr := s.workerCache.SetWorkerLocation(workerLocation); cacheErr != nil {
			fmt.Printf("Warning: failed to update Redis worker cache: %v\n", cacheErr)
		}
	}
	// Also update via repo (currently a no-op, kept for interface compatibility)
	err = s.locationRepo.UpdateWorkerLocation(workerLocation)
	if err != nil {
		fmt.Printf("Warning: failed to update real-time location: %v\n", err)
	}

	// Broadcast to subscribers filtered by worker's team
	teamID := ""
	if update.TeamID != nil {
		teamID = update.TeamID.String()
	}
	err = s.BroadcastLocationUpdate(workerLocation, teamID)
	if err != nil {
		fmt.Printf("Warning: failed to broadcast location update: %v\n", err)
	}

	// Publish location event for async geofence processing via NATS
	if s.natsPublisher != nil {
		go func() {
			evt := &domain.LocationEventMessage{
				WorkerID:  userID,
				Latitude:  update.Latitude,
				Longitude: update.Longitude,
				SessionID: update.SessionID,
				Timestamp: time.Now(),
			}
			if err := s.natsPublisher.PublishLocationUpdate(evt); err != nil {
				fmt.Printf("Warning: failed to publish location event to NATS: %v\n", err)
			}
		}()
	} else if s.geofenceClient != nil {
		// Fallback: synchronous geofence check (if NATS not configured)
		geofenceEvent, err := s.geofenceClient.ProcessLocationUpdate(userID, nil, update.Latitude, update.Longitude)
		if err != nil {
			fmt.Printf("Warning: failed to check geofence: %v\n", err)
		} else if geofenceEvent != nil {
			s.broadcastGeofenceEvent(geofenceEvent)
		}
	}

	return track, nil
}

// broadcastGeofenceEvent broadcasts a geofence event to WebSocket subscribers
func (s *locationService) broadcastGeofenceEvent(event *domain.GeofenceEvent) {
	// Create a geofence alert for WebSocket broadcast
	alert := &domain.GeofenceAlert{
		ID:        uuid.New(),
		UserID:    event.WorkerID,
		UserName:  "", // Would be populated from user service
		AlertType: event.EventType,
		Location: domain.LocationTrack{
			UserID:    event.WorkerID,
			Latitude:  event.Latitude,
			Longitude: event.Longitude,
			TrackedAt: event.Timestamp,
		},
		Message:   fmt.Sprintf("Worker %s territory: %s", event.EventType, event.TerritoryName),
		Timestamp: event.Timestamp,
	}

	// Broadcast the geofence alert
	// This would send to WebSocket subscribers monitoring this worker/team
	fmt.Printf("Geofence event: %s - Territory: %s, Worker: %s\n",
		event.EventType, event.TerritoryName, event.WorkerID.String())

	// In a full implementation, we'd broadcast this to relevant subscribers
	_ = alert // Used for logging/broadcast
}

// updateSessionWithNewLocation incrementally updates session distance with the new track
func (s *locationService) updateSessionWithNewLocation(sessionID uuid.UUID, newTrack *domain.LocationTrack) error {
	// Get only the previous track (1 row) instead of ALL tracks
	prevTrack, err := s.locationRepo.GetLastTrackForSession(sessionID, newTrack.ID)
	if err != nil {
		return fmt.Errorf("failed to get previous track: %w", err)
	}

	var segmentDistance float64
	if prevTrack != nil {
		segmentDistance = s.distanceCalc.CalculateDistance(
			prevTrack.Latitude, prevTrack.Longitude,
			newTrack.Latitude, newTrack.Longitude,
		)
		// Ignore jumps > 1km between updates (GPS glitch)
		if segmentDistance > 1000 {
			segmentDistance = 0
		}
	}

	// Atomic increment — no race conditions, no full re-read
	return s.locationRepo.IncrementSessionDistance(sessionID, segmentDistance)
}

// GetUserLocations retrieves user locations based on query
func (s *locationService) GetUserLocations(userID uuid.UUID, query *domain.LocationQuery) ([]*domain.LocationTrack, error) {
	// Set default limit if not provided
	if query.Limit <= 0 {
		query.Limit = domain.DefaultLocationLimit
	}
	if query.Limit > domain.MaxLocationLimit {
		query.Limit = domain.MaxLocationLimit
	}

	// Query based on parameters
	if query.SessionID != nil {
		return s.locationRepo.GetTracksBySessionID(*query.SessionID)
	}

	if query.StartTime != nil && query.EndTime != nil {
		return s.locationRepo.GetTracksInTimeRange(userID, *query.StartTime, *query.EndTime)
	}

	return s.locationRepo.GetTracksByUserID(userID, query.Limit, query.Offset)
}

// StartSession starts a new location tracking session
func (s *locationService) StartSession(userID uuid.UUID) (*domain.LocationSession, error) {
	// Reset Kalman filter state for new session (start fresh smoothing)
	if s.kalmanFilter != nil {
		s.kalmanFilter.Reset(userID)
	}

	// Check if there's already an active session
	activeSession, err := s.locationRepo.GetActiveSession(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to check active session: %w", err)
	}

	if activeSession != nil {
		return activeSession, nil // Return existing active session
	}

	// Create new session
	session := &domain.LocationSession{
		ID:            uuid.New(),
		UserID:        userID,
		StartTime:     time.Now(),
		TotalDistance: 0,
		LocationCount: 0,
		IsActive:      true,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}

	err = s.locationRepo.CreateSession(session)
	if err != nil {
		return nil, fmt.Errorf("failed to create session: %w", err)
	}

	return session, nil
}

// EndSession ends a location tracking session
func (s *locationService) EndSession(userID, sessionID uuid.UUID) (*domain.LocationSession, error) {
	session, err := s.locationRepo.GetSessionByID(sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get session: %w", err)
	}

	if session.UserID != userID {
		return nil, fmt.Errorf("session does not belong to user")
	}

	if !session.IsActive {
		return session, nil // Already ended
	}

	// Calculate final statistics
	tracks, err := s.locationRepo.GetTracksBySessionID(sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get session tracks: %w", err)
	}

	session.TotalDistance = s.distanceCalc.CalculateSessionDistance(tracks)
	session.LocationCount = len(tracks)
	session.IsActive = false
	now := time.Now()
	session.EndTime = &now

	err = s.locationRepo.UpdateSession(session)
	if err != nil {
		return nil, fmt.Errorf("failed to update session: %w", err)
	}

	return session, nil
}

// GetActiveSession retrieves the active session for a user
func (s *locationService) GetActiveSession(userID uuid.UUID) (*domain.LocationSession, error) {
	return s.locationRepo.GetActiveSession(userID)
}

// GetUserSessions retrieves sessions for a user
func (s *locationService) GetUserSessions(userID uuid.UUID, limit, offset int) ([]*domain.LocationSession, error) {
	if limit <= 0 {
		limit = domain.DefaultSessionLimit
	}
	return s.locationRepo.GetUserSessions(userID, limit, offset)
}

// GetLocationStats retrieves location statistics for a user
func (s *locationService) GetLocationStats(userID uuid.UUID, days int) (*domain.LocationStats, error) {
	if days <= 0 {
		days = 30 // Default to 30 days
	}
	return s.locationRepo.GetLocationStats(userID, days)
}

// GetActiveWorkers retrieves all active workers (Redis first, PostgreSQL fallback)
func (s *locationService) GetActiveWorkers() ([]*domain.WorkerLocation, error) {
	if s.workerCache != nil {
		workers, err := s.workerCache.GetActiveWorkers()
		if err == nil && len(workers) > 0 {
			return workers, nil
		}
		if err != nil {
			fmt.Printf("Warning: Redis cache miss for active workers: %v\n", err)
		}
	}
	return s.locationRepo.GetActiveWorkers()
}

// GetActiveWorkersByTeam retrieves active workers for a specific team from Redis cache
func (s *locationService) GetActiveWorkersByTeam(teamID string) ([]*domain.WorkerLocation, error) {
	if s.workerCache != nil {
		workers, err := s.workerCache.GetActiveWorkersByTeam(teamID)
		if err == nil && len(workers) > 0 {
			return workers, nil
		}
		if err != nil {
			fmt.Printf("Warning: Redis cache error for team workers: %v\n", err)
		}
	}
	// Fallback to database
	return s.locationRepo.GetActiveWorkersByTeam(teamID)
}

// SetWorkerOffline sets a worker as offline
func (s *locationService) SetWorkerOffline(userID uuid.UUID) error {
	if s.workerCache != nil {
		if err := s.workerCache.RemoveWorker(userID); err != nil {
			fmt.Printf("Warning: failed to remove worker from Redis cache: %v\n", err)
		}
	}
	return s.locationRepo.SetWorkerOffline(userID)
}

// SubscribeToLocationUpdates subscribes to real-time location updates
func (s *locationService) SubscribeToLocationUpdates(userID uuid.UUID, teamID string) (<-chan *domain.WorkerLocation, error) {
	// Small buffered channel to keep only near-latest updates per subscriber
	// and avoid unbounded backlog during burst traffic.
	ch := make(chan *domain.WorkerLocation, 1)
	err := s.realtimeManager.AddSubscriber(userID, ch, teamID)
	if err != nil {
		close(ch)
		return nil, fmt.Errorf("failed to add subscriber: %w", err)
	}
	return ch, nil
}

// UnsubscribeFromLocationUpdates unsubscribes from real-time location updates
func (s *locationService) UnsubscribeFromLocationUpdates(userID uuid.UUID) error {
	return s.realtimeManager.RemoveSubscriber(userID)
}

// BroadcastLocationUpdate broadcasts a location update to subscribers in the same team
func (s *locationService) BroadcastLocationUpdate(location *domain.WorkerLocation, teamID string) error {
	return s.realtimeManager.Broadcast(location, teamID)
}

// DistanceCalculator implementation
type distanceCalculator struct{}

// NewDistanceCalculator creates a new distance calculator
func NewDistanceCalculator() domain.DistanceCalculator {
	return &distanceCalculator{}
}

// CalculateDistance calculates distance between two points using Haversine formula
func (dc *distanceCalculator) CalculateDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadius = 6371000 // Earth radius in meters

	// Convert degrees to radians
	lat1Rad := lat1 * math.Pi / 180
	lat2Rad := lat2 * math.Pi / 180
	deltaLatRad := (lat2 - lat1) * math.Pi / 180
	deltaLonRad := (lon2 - lon1) * math.Pi / 180

	a := math.Sin(deltaLatRad/2)*math.Sin(deltaLatRad/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
			math.Sin(deltaLonRad/2)*math.Sin(deltaLonRad/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadius * c
}

// CalculateSessionDistance calculates total distance for a session
func (dc *distanceCalculator) CalculateSessionDistance(tracks []*domain.LocationTrack) float64 {
	if len(tracks) < 2 {
		return 0
	}

	var totalDistance float64
	for i := 1; i < len(tracks); i++ {
		prev := tracks[i-1]
		curr := tracks[i]

		distance := dc.CalculateDistance(
			prev.Latitude, prev.Longitude,
			curr.Latitude, curr.Longitude,
		)

		// Only add distance if it's reasonable (less than 1km between points)
		if distance < 1000 {
			totalDistance += distance
		}
	}

	return totalDistance
}
