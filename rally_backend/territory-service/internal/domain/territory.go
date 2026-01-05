package domain

import (
	"time"

	"github.com/google/uuid"
)

// Territory represents a territory in the system
type Territory struct {
	ID               uuid.UUID `json:"id" db:"id"`
	Name             string    `json:"name" db:"name"`
	Description      *string   `json:"description,omitempty" db:"description"`
	TeamID           uuid.UUID `json:"team_id" db:"team_id"`
	AssignedWorkerID *uuid.UUID `json:"assigned_worker_id,omitempty" db:"assigned_worker_id"`
	Boundary         string    `json:"boundary" db:"boundary"` // GeoJSON polygon as string
	Color            string    `json:"color" db:"color"`
	IsActive         bool      `json:"is_active" db:"is_active"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
}

// TerritoryEntry represents a territory entry/exit record
type TerritoryEntry struct {
	ID           uuid.UUID  `json:"id" db:"id"`
	UserID       uuid.UUID  `json:"user_id" db:"user_id"`
	TerritoryID  uuid.UUID  `json:"territory_id" db:"territory_id"`
	EntryTime    time.Time  `json:"entry_time" db:"entry_time"`
	ExitTime     *time.Time `json:"exit_time,omitempty" db:"exit_time"`
	EntryLat     float64    `json:"entry_lat" db:"entry_lat"`
	EntryLng     float64    `json:"entry_lng" db:"entry_lng"`
	ExitLat      *float64   `json:"exit_lat,omitempty" db:"exit_lat"`
	ExitLng      *float64   `json:"exit_lng,omitempty" db:"exit_lng"`
	IsActive     bool       `json:"is_active" db:"is_active"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}

// TerritoryAlert represents a territory alert
type TerritoryAlert struct {
	ID          uuid.UUID `json:"id" db:"id"`
	UserID      uuid.UUID `json:"user_id" db:"user_id"`
	TerritoryID uuid.UUID `json:"territory_id" db:"territory_id"`
	AlertType   string    `json:"alert_type" db:"alert_type"` // "entry", "exit", "boundary_violation"
	Message     string    `json:"message" db:"message"`
	Latitude    float64   `json:"latitude" db:"latitude"`
	Longitude   float64   `json:"longitude" db:"longitude"`
	IsRead      bool      `json:"is_read" db:"is_read"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// CreateTerritoryRequest represents the request to create a territory
type CreateTerritoryRequest struct {
	Name             string     `json:"name" binding:"required"`
	Description      string     `json:"description,omitempty"`
	TeamID           uuid.UUID  `json:"team_id" binding:"required"`
	AssignedWorkerID *uuid.UUID `json:"assigned_worker_id,omitempty"`
	Boundary         string     `json:"boundary" binding:"required"` // GeoJSON polygon
	Color            string     `json:"color,omitempty"`
}

// UpdateTerritoryRequest represents the request to update a territory
type UpdateTerritoryRequest struct {
	Name             *string    `json:"name,omitempty"`
	Description      *string    `json:"description,omitempty"`
	AssignedWorkerID *uuid.UUID `json:"assigned_worker_id,omitempty"`
	Boundary         *string    `json:"boundary,omitempty"`
	Color            *string    `json:"color,omitempty"`
	IsActive         *bool      `json:"is_active,omitempty"`
}

// LocationPoint represents a geographic point
type LocationPoint struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// TerritoryStatus represents the current status of a worker in territories
type TerritoryStatus struct {
	UserID        uuid.UUID  `json:"user_id"`
	UserName      string     `json:"user_name"`
	TerritoryID   *uuid.UUID `json:"territory_id,omitempty"`
	TerritoryName *string    `json:"territory_name,omitempty"`
	IsInside      bool       `json:"is_inside"`
	LastUpdate    time.Time  `json:"last_update"`
	Location      LocationPoint `json:"location"`
}

// TerritoryStats represents territory statistics
type TerritoryStats struct {
	TotalTerritories    int     `json:"total_territories"`
	ActiveTerritories   int     `json:"active_territories"`
	AssignedTerritories int     `json:"assigned_territories"`
	TotalEntries        int     `json:"total_entries"`
	TotalAlerts         int     `json:"total_alerts"`
	AverageTimeInside   float64 `json:"average_time_inside_minutes"`
}

// WebSocketMessage represents a WebSocket message for real-time updates
type WebSocketMessage struct {
	Type      string      `json:"type"`
	UserID    uuid.UUID   `json:"user_id,omitempty"`
	Data      interface{} `json:"data"`
	Timestamp time.Time   `json:"timestamp"`
}

// TerritoryRepository defines the interface for territory data access
type TerritoryRepository interface {
	// Territory management
	Create(territory *Territory) error
	GetByID(id uuid.UUID) (*Territory, error)
	GetByTeamID(teamID uuid.UUID) ([]*Territory, error)
	GetByWorkerID(workerID uuid.UUID) ([]*Territory, error)
	Update(territory *Territory) error
	Delete(id uuid.UUID) error
	GetAll() ([]*Territory, error)
	
	// Entry/Exit tracking
	CreateEntry(entry *TerritoryEntry) error
	GetActiveEntry(userID, territoryID uuid.UUID) (*TerritoryEntry, error)
	UpdateEntry(entry *TerritoryEntry) error
	GetUserEntries(userID uuid.UUID, limit, offset int) ([]*TerritoryEntry, error)
	GetTerritoryEntries(territoryID uuid.UUID, limit, offset int) ([]*TerritoryEntry, error)
	
	// Alerts
	CreateAlert(alert *TerritoryAlert) error
	GetUserAlerts(userID uuid.UUID, limit, offset int) ([]*TerritoryAlert, error)
	GetTeamAlerts(teamID uuid.UUID, limit, offset int) ([]*TerritoryAlert, error)
	MarkAlertRead(alertID uuid.UUID) error
	
	// Statistics
	GetTerritoryStats(teamID uuid.UUID) (*TerritoryStats, error)
	GetUserTerritoryStats(userID uuid.UUID, days int) (*TerritoryStats, error)
}

// TerritoryService defines the interface for territory business logic
type TerritoryService interface {
	// Territory management
	CreateTerritory(req *CreateTerritoryRequest) (*Territory, error)
	GetTerritory(id uuid.UUID) (*Territory, error)
	UpdateTerritory(id uuid.UUID, req *UpdateTerritoryRequest) (*Territory, error)
	DeleteTerritory(id uuid.UUID) error
	GetTeamTerritories(teamID uuid.UUID) ([]*Territory, error)
	GetWorkerTerritories(workerID uuid.UUID) ([]*Territory, error)
	
	// Location tracking
	TrackWorkerLocation(userID uuid.UUID, location LocationPoint) (*TerritoryStatus, error)
	GetWorkerStatus(userID uuid.UUID) (*TerritoryStatus, error)
	
	// Entry/Exit management
	GetUserEntries(userID uuid.UUID, limit, offset int) ([]*TerritoryEntry, error)
	GetTerritoryEntries(territoryID uuid.UUID, limit, offset int) ([]*TerritoryEntry, error)
	
	// Alerts
	GetUserAlerts(userID uuid.UUID, limit, offset int) ([]*TerritoryAlert, error)
	GetTeamAlerts(teamID uuid.UUID, limit, offset int) ([]*TerritoryAlert, error)
	MarkAlertRead(alertID uuid.UUID) error
	
	// Statistics
	GetTerritoryStats(teamID uuid.UUID) (*TerritoryStats, error)
	GetUserTerritoryStats(userID uuid.UUID, days int) (*TerritoryStats, error)
	
	// Real-time features
	SubscribeToAlerts(userID uuid.UUID) (<-chan *TerritoryAlert, error)
	UnsubscribeFromAlerts(userID uuid.UUID) error
	BroadcastAlert(alert *TerritoryAlert) error
}

// GeofenceManager defines the interface for geofencing operations
type GeofenceManager interface {
	IsPointInTerritory(point LocationPoint, boundary string) (bool, error)
	CalculateDistance(point1, point2 LocationPoint) float64
	ValidateBoundary(boundary string) error
}

// RealtimeManager defines the interface for real-time territory management
type RealtimeManager interface {
	AddSubscriber(userID uuid.UUID, ch chan<- *TerritoryAlert) error
	RemoveSubscriber(userID uuid.UUID) error
	Broadcast(alert *TerritoryAlert) error
	GetActiveSubscribers() []uuid.UUID
}

// Constants
const (
	// Alert types
	AlertTypeEntry            = "entry"
	AlertTypeExit             = "exit"
	AlertTypeBoundaryViolation = "boundary_violation"
	
	// WebSocket message types
	WSMessageTypeTerritoryAlert = "territory_alert"
	WSMessageTypeStatusUpdate   = "status_update"
	WSMessageTypeEntryExit      = "entry_exit"
	
	// Default values
	DefaultTerritoryColor = "#007AFF"
	DefaultAlertLimit     = 50
	DefaultEntryLimit     = 100
	MaxAlertLimit         = 200
	MaxEntryLimit         = 500
	
	// Geofence settings
	DefaultGeofenceRadius = 50.0 // meters
	MinGeofenceRadius     = 10.0 // meters
	MaxGeofenceRadius     = 1000.0 // meters
)
