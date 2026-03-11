package domain

import (
	"time"

	"github.com/google/uuid"
)

// LocationTrack represents a location tracking record
type LocationTrack struct {
	ID                uuid.UUID  `json:"id" db:"id"`
	UserID            uuid.UUID  `json:"user_id" db:"user_id"`
	Latitude          float64    `json:"latitude" db:"latitude"`
	Longitude         float64    `json:"longitude" db:"longitude"`
	SmoothedLatitude  *float64   `json:"smoothed_latitude,omitempty" db:"smoothed_latitude"`
	SmoothedLongitude *float64   `json:"smoothed_longitude,omitempty" db:"smoothed_longitude"`
	Accuracy          *float64   `json:"accuracy,omitempty" db:"accuracy"`
	Speed             *float64   `json:"speed,omitempty" db:"speed"`
	Heading           *float64   `json:"heading,omitempty" db:"heading"`
	SessionID         *uuid.UUID `json:"session_id,omitempty" db:"session_id"`
	TrackedAt         time.Time  `json:"tracked_at" db:"tracked_at"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
}

// LocationSession represents a location tracking session
type LocationSession struct {
	ID            uuid.UUID  `json:"id" db:"id"`
	UserID        uuid.UUID  `json:"user_id" db:"user_id"`
	StartTime     time.Time  `json:"start_time" db:"start_time"`
	EndTime       *time.Time `json:"end_time,omitempty" db:"end_time"`
	TotalDistance float64    `json:"total_distance" db:"total_distance"`
	LocationCount int        `json:"location_count" db:"location_count"`
	IsActive      bool       `json:"is_active" db:"is_active"`
	CreatedAt     time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at" db:"updated_at"`
}

// WorkerLocation represents real-time worker location data
type WorkerLocation struct {
	UserID    uuid.UUID `json:"user_id"`
	UserName  string    `json:"user_name"`
	TeamID    string    `json:"team_id,omitempty"`
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	Accuracy  *float64  `json:"accuracy,omitempty"`
	Speed     *float64  `json:"speed,omitempty"`
	Heading   *float64  `json:"heading,omitempty"`
	IsActive  bool      `json:"is_active"`
	LastSeen  time.Time `json:"last_seen"`
	UpdatedAt time.Time `json:"updated_at"`
}

// LocationUpdate represents a location update request
type LocationUpdate struct {
	Latitude  float64    `json:"latitude" binding:"required"`
	Longitude float64    `json:"longitude" binding:"required"`
	Accuracy  *float64   `json:"accuracy,omitempty"`
	Speed     *float64   `json:"speed,omitempty"`
	Heading   *float64   `json:"heading,omitempty"`
	SessionID *uuid.UUID `json:"session_id,omitempty"`
	TeamID    *uuid.UUID `json:"team_id,omitempty"`
}

// StartSessionRequest represents a request to start a tracking session
type StartSessionRequest struct {
	UserID uuid.UUID `json:"user_id" binding:"required"`
}

// LocationQuery represents location query parameters
type LocationQuery struct {
	UserID    *uuid.UUID `form:"user_id"`
	SessionID *uuid.UUID `form:"session_id"`
	StartTime *time.Time `form:"start_time"`
	EndTime   *time.Time `form:"end_time"`
	Limit     int        `form:"limit"`
	Offset    int        `form:"offset"`
}

// LocationStats represents location statistics
type LocationStats struct {
	TotalDistance    float64    `json:"total_distance"`
	TotalTime        int64      `json:"total_time_seconds"`
	AverageSpeed     float64    `json:"average_speed"`
	MaxSpeed         float64    `json:"max_speed"`
	LocationCount    int        `json:"location_count"`
	SessionCount     int        `json:"session_count"`
	LastLocationTime *time.Time `json:"last_location_time,omitempty"`
}

// GeofenceAlert represents a geofence alert
type GeofenceAlert struct {
	ID        uuid.UUID     `json:"id"`
	UserID    uuid.UUID     `json:"user_id"`
	UserName  string        `json:"user_name"`
	AlertType string        `json:"alert_type"` // "entry", "exit", "boundary_violation"
	Location  LocationTrack `json:"location"`
	Message   string        `json:"message"`
	Timestamp time.Time     `json:"timestamp"`
}

// WebSocketMessage represents a WebSocket message for real-time updates
type WebSocketMessage struct {
	Type      string      `json:"type"`
	UserID    uuid.UUID   `json:"user_id,omitempty"`
	Data      interface{} `json:"data"`
	Timestamp time.Time   `json:"timestamp"`
}

// LocationRepository defines the interface for location data access
type LocationRepository interface {
	CreateTrack(track *LocationTrack) error
	GetTracksByUserID(userID uuid.UUID, limit, offset int) ([]*LocationTrack, error)
	GetTracksBySessionID(sessionID uuid.UUID) ([]*LocationTrack, error)
	GetTracksInTimeRange(userID uuid.UUID, startTime, endTime time.Time) ([]*LocationTrack, error)
	GetLastTrackForSession(sessionID uuid.UUID, beforeTrackID uuid.UUID) (*LocationTrack, error)

	CreateSession(session *LocationSession) error
	GetSessionByID(id uuid.UUID) (*LocationSession, error)
	GetActiveSession(userID uuid.UUID) (*LocationSession, error)
	UpdateSession(session *LocationSession) error
	EndSession(sessionID uuid.UUID) error
	GetUserSessions(userID uuid.UUID, limit, offset int) ([]*LocationSession, error)
	IncrementSessionDistance(sessionID uuid.UUID, addDistance float64) error

	GetLocationStats(userID uuid.UUID, days int) (*LocationStats, error)
	GetActiveWorkers() ([]*WorkerLocation, error)
	GetActiveWorkersByTeam(teamID string) ([]*WorkerLocation, error)
	UpdateWorkerLocation(location *WorkerLocation) error
	SetWorkerOffline(userID uuid.UUID) error
}

// LocationService defines the interface for location business logic
type LocationService interface {
	UpdateLocation(userID uuid.UUID, update *LocationUpdate) (*LocationTrack, error)
	GetUserLocations(userID uuid.UUID, query *LocationQuery) ([]*LocationTrack, error)

	StartSession(userID uuid.UUID) (*LocationSession, error)
	EndSession(userID, sessionID uuid.UUID) (*LocationSession, error)
	GetActiveSession(userID uuid.UUID) (*LocationSession, error)
	GetUserSessions(userID uuid.UUID, limit, offset int) ([]*LocationSession, error)

	GetLocationStats(userID uuid.UUID, days int) (*LocationStats, error)
	GetActiveWorkers() ([]*WorkerLocation, error)
	GetActiveWorkersByTeam(teamID string) ([]*WorkerLocation, error)
	SetWorkerOffline(userID uuid.UUID) error

	// Real-time features
	SubscribeToLocationUpdates(userID uuid.UUID, teamID string) (<-chan *WorkerLocation, error)
	UnsubscribeFromLocationUpdates(userID uuid.UUID) error
	BroadcastLocationUpdate(location *WorkerLocation, teamID string) error
}

// RealtimeManager defines the interface for real-time location management
type RealtimeManager interface {
	AddSubscriber(userID uuid.UUID, ch chan<- *WorkerLocation, teamID string) error
	RemoveSubscriber(userID uuid.UUID) error
	Broadcast(location *WorkerLocation, teamID string) error
	GetActiveSubscribers() []uuid.UUID
}

// DistanceCalculator defines the interface for distance calculations
type DistanceCalculator interface {
	CalculateDistance(lat1, lon1, lat2, lon2 float64) float64
	CalculateSessionDistance(tracks []*LocationTrack) float64
}

// GeofenceEvent represents an entry/exit event from the territory service
type GeofenceEvent struct {
	EventType     string     `json:"event_type"` // "entry" or "exit"
	WorkerID      uuid.UUID  `json:"worker_id"`
	TerritoryID   uuid.UUID  `json:"territory_id"`
	AssignmentID  *uuid.UUID `json:"assignment_id,omitempty"`
	TerritoryName string     `json:"territory_name"`
	Latitude      float64    `json:"latitude"`
	Longitude     float64    `json:"longitude"`
	Timestamp     time.Time  `json:"timestamp"`
	SessionID     *uuid.UUID `json:"session_id,omitempty"`
}

// GeofenceClient defines the interface for geofence operations with territory service
type GeofenceClient interface {
	ProcessLocationUpdate(workerID uuid.UUID, teamID *uuid.UUID, lat, lng float64) (*GeofenceEvent, error)
}

// LocationEventMessage is the message sent via NATS for async geofence processing
type LocationEventMessage struct {
	WorkerID  uuid.UUID  `json:"worker_id"`
	TeamID    *uuid.UUID `json:"team_id,omitempty"`
	Latitude  float64    `json:"latitude"`
	Longitude float64    `json:"longitude"`
	SessionID *uuid.UUID `json:"session_id,omitempty"`
	Timestamp time.Time  `json:"timestamp"`
}

// LocationEventPublisher defines the interface for publishing location events
type LocationEventPublisher interface {
	PublishLocationUpdate(event *LocationEventMessage) error
	Close()
}

// WorkerLocationCache defines the interface for caching real-time worker locations
type WorkerLocationCache interface {
	SetWorkerLocation(location *WorkerLocation) error
	GetActiveWorkers() ([]*WorkerLocation, error)
	GetActiveWorkersByTeam(teamID string) ([]*WorkerLocation, error)
	RemoveWorker(userID uuid.UUID) error
}

// Constants
const (
	// Alert types
	AlertTypeEntry             = "entry"
	AlertTypeExit              = "exit"
	AlertTypeBoundaryViolation = "boundary_violation"

	// WebSocket message types
	WSMessageTypeLocationUpdate          = "location_update"
	WSMessageTypeWorkerOnline            = "worker_online"
	WSMessageTypeWorkerOffline           = "worker_offline"
	WSMessageTypeGeofenceAlert           = "geofence_alert"
	WSMessageTypeWorkerLocationBroadcast = "worker_location_broadcast"

	// Default values
	DefaultLocationLimit = 100
	DefaultSessionLimit  = 50
	MaxLocationLimit     = 1000
)
