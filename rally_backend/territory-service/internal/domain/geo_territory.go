package domain

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// GeoTerritory represents an imported territory from GeoPackage data
type GeoTerritory struct {
	ID             uuid.UUID `json:"id" db:"id"`
	FID            int       `json:"fid" db:"fid"`
	SOLID          string    `json:"solid" db:"solid"`

	// Church/Entity info
	EntityName     string    `json:"entity_name" db:"entity_name"`
	EntityID       string    `json:"entity_id" db:"entity_id"`
	GroupID        *string   `json:"group_id,omitempty" db:"group_id"`

	// Location
	Address        *string   `json:"address,omitempty" db:"address"`
	StreetAddress  *string   `json:"street_address,omitempty" db:"street_address"`
	City           *string   `json:"city,omitempty" db:"city"`
	County         *string   `json:"county,omitempty" db:"county"`
	State          *string   `json:"state,omitempty" db:"state"`
	Zipcode        *string   `json:"zipcode,omitempty" db:"zipcode"`

	// Demographics
	Population     *int      `json:"population,omitempty" db:"population"`
	HousingUnits   *int      `json:"housing_units,omitempty" db:"housing_units"`

	// Organizational
	UnionName      *string   `json:"union_name,omitempty" db:"union_name"`
	Conference     *string   `json:"conference,omitempty" db:"conference"`

	// Census
	GEOID          *string   `json:"geoid,omitempty" db:"geoid"`
	ZID            *string   `json:"zid,omitempty" db:"zid"`

	// Display
	Label          *string   `json:"label,omitempty" db:"label"`
	Order          *float64  `json:"order,omitempty" db:"territory_order"`

	// Geometry - returned as parsed GeoJSON object
	Geometry       json.RawMessage `json:"geometry,omitempty" db:"geom"`

	// Metadata
	SourceFile     *string   `json:"source_file,omitempty" db:"source_file"`
	ImportedAt     time.Time `json:"imported_at" db:"imported_at"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

// GeoTerritorySimple is a lightweight version for list views
type GeoTerritorySimple struct {
	ID         uuid.UUID `json:"id"`
	SOLID      string    `json:"solid"`
	EntityName string    `json:"entity_name"`
	EntityID   string    `json:"entity_id"`
	City       *string   `json:"city,omitempty"`
	State      *string   `json:"state,omitempty"`
	UnionName  *string   `json:"union_name,omitempty"`
	Conference *string   `json:"conference,omitempty"`
	Population *int      `json:"population,omitempty"`
}

// ChurchLocation represents a church point location (centroid of territories)
type ChurchLocation struct {
	EntityID        string    `json:"entity_id" db:"entity_id"`
	EntityName      string    `json:"entity_name" db:"entity_name"`
	UnionName       *string   `json:"union_name,omitempty" db:"union_name"`
	Conference      *string   `json:"conference,omitempty" db:"conference"`
	Address         *string   `json:"address,omitempty" db:"address"`
	City            *string   `json:"city,omitempty" db:"city"`
	State           *string   `json:"state,omitempty" db:"state"`
	Latitude        float64   `json:"latitude"`
	Longitude       float64   `json:"longitude"`
	TerritoryCount  int       `json:"territory_count" db:"territory_count"`
	TotalPopulation int       `json:"total_population" db:"total_population"`
	TotalHousing    int       `json:"total_housing" db:"total_housing"`
}

// GeoJSONFeature represents a GeoJSON feature
type GeoJSONFeature struct {
	Type       string                 `json:"type"`
	ID         string                 `json:"id,omitempty"`
	Geometry   interface{}            `json:"geometry"`
	Properties map[string]interface{} `json:"properties"`
}

// GeoJSONFeatureCollection represents a GeoJSON feature collection
type GeoJSONFeatureCollection struct {
	Type     string           `json:"type"`
	Features []GeoJSONFeature `json:"features"`
}

// BoundsQuery represents a spatial bounds query
type BoundsQuery struct {
	MinLng float64 `json:"min_lng" form:"min_lng"`
	MinLat float64 `json:"min_lat" form:"min_lat"`
	MaxLng float64 `json:"max_lng" form:"max_lng"`
	MaxLat float64 `json:"max_lat" form:"max_lat"`
	Limit  int     `json:"limit" form:"limit"`
	Zoom   int     `json:"zoom" form:"zoom"`
}

// TerritorySearchQuery represents a territory search query
type TerritorySearchQuery struct {
	Query           string `json:"q" form:"q"`
	Union           string `json:"union" form:"union"`
	Conference      string `json:"conference" form:"conference"`
	State           string `json:"state" form:"state"`
	City            string `json:"city" form:"city"`
	Limit           int    `json:"limit" form:"limit"`
	Offset          int    `json:"offset" form:"offset"`
	IncludeGeometry bool   `json:"include_geometry" form:"include_geometry"`
}

// TerritoryFilters for listing/searching
type TerritoryFilters struct {
	UnionName       string `json:"union_name" form:"union"`
	Conference      string `json:"conference" form:"conference"`
	State           string `json:"state" form:"state"`
	City            string `json:"city" form:"city"`
	EntityID        string `json:"entity_id" form:"entity_id"`
	Limit           int    `json:"limit" form:"limit"`
	Offset          int    `json:"offset" form:"offset"`
	IncludeGeometry bool   `json:"include_geometry" form:"include_geometry"`
}

// UnionStats represents statistics for a union
type UnionStats struct {
	UnionName        string `json:"union_name"`
	TerritoryCount   int    `json:"territory_count"`
	ChurchCount      int    `json:"church_count"`
	ConferenceCount  int    `json:"conference_count"`
	TotalPopulation  int    `json:"total_population"`
	TotalHousing     int    `json:"total_housing"`
}

// ConferenceStats represents statistics for a conference
type ConferenceStats struct {
	Conference       string `json:"conference"`
	UnionName        string `json:"union_name"`
	TerritoryCount   int    `json:"territory_count"`
	ChurchCount      int    `json:"church_count"`
	TotalPopulation  int    `json:"total_population"`
	TotalHousing     int    `json:"total_housing"`
}

// ImportProgress represents the progress of a GeoPackage import
type ImportProgress struct {
	FileName       string    `json:"file_name"`
	TotalRecords   int       `json:"total_records"`
	ImportedCount  int       `json:"imported_count"`
	FailedCount    int       `json:"failed_count"`
	StartedAt      time.Time `json:"started_at"`
	CompletedAt    *time.Time `json:"completed_at,omitempty"`
	Status         string    `json:"status"` // "in_progress", "completed", "failed"
	ErrorMessage   *string   `json:"error_message,omitempty"`
}

// GeoTerritoryRepository defines the interface for geo territory data access
type GeoTerritoryRepository interface {
	// Territory retrieval
	GetByID(id uuid.UUID) (*GeoTerritory, error)
	GetByFID(fid int) (*GeoTerritory, error)
	GetBySOLID(solid string) (*GeoTerritory, error)
	GetByEntityID(entityID string) ([]*GeoTerritory, error)

	// Spatial queries
	GetInBounds(bounds BoundsQuery) ([]*GeoTerritory, error)
	GetInBoundsGeoJSON(bounds BoundsQuery) (*GeoJSONFeatureCollection, error)
	GetByPoint(lat, lng float64) ([]*GeoTerritory, error)

	// Search
	Search(query TerritorySearchQuery) ([]*GeoTerritorySimple, error)
	SearchWithGeometry(query TerritorySearchQuery) ([]*GeoTerritory, error)

	// Listing with filters
	List(filters TerritoryFilters) ([]*GeoTerritorySimple, int, error)
	ListWithGeometry(filters TerritoryFilters) ([]*GeoTerritory, int, error)

	// Church locations
	GetChurchLocations(bounds *BoundsQuery) ([]*ChurchLocation, error)
	GetChurchByEntityID(entityID string) (*ChurchLocation, error)

	// Statistics
	GetUnionStats() ([]*UnionStats, error)
	GetConferenceStats(unionName string) ([]*ConferenceStats, error)
	GetTotalCount() (int, error)

	// Vector tiles
	GetVectorTile(z, x, y int) ([]byte, error)

	// Import
	CreateBatch(territories []*GeoTerritory) error
	UpdateSimplifiedGeometry(tolerance float64) error
	RefreshChurchLocations() error
}

// GeoTerritoryService defines the interface for geo territory business logic
type GeoTerritoryService interface {
	// Territory retrieval
	GetTerritory(id uuid.UUID) (*GeoTerritory, error)
	GetTerritoryBySOLID(solid string) (*GeoTerritory, error)
	GetTerritoriesByEntity(entityID string) ([]*GeoTerritory, error)

	// Spatial queries
	GetTerritoriesInBounds(bounds BoundsQuery) (*GeoJSONFeatureCollection, error)
	GetTerritoriesAtPoint(lat, lng float64) ([]*GeoTerritory, error)

	// Search
	SearchTerritories(query TerritorySearchQuery) ([]*GeoTerritorySimple, error)
	SearchTerritoriesWithGeometry(query TerritorySearchQuery) ([]*GeoTerritory, error)

	// Listing
	ListTerritories(filters TerritoryFilters) ([]*GeoTerritorySimple, int, error)
	ListTerritoriesWithGeometry(filters TerritoryFilters) ([]*GeoTerritory, int, error)

	// Church locations
	GetChurchLocations(bounds *BoundsQuery) ([]*ChurchLocation, error)
	GetChurch(entityID string) (*ChurchLocation, error)

	// Statistics
	GetUnionStats() ([]*UnionStats, error)
	GetConferenceStats(unionName string) ([]*ConferenceStats, error)

	// Vector tiles
	GetVectorTile(z, x, y int) ([]byte, error)

	// Import
	ImportGeoPackage(filePath string) (*ImportProgress, error)
	GetImportProgress(fileName string) (*ImportProgress, error)
}

// TerritoryAssignment represents an assignment of a geo territory to a team/worker
type TerritoryAssignment struct {
	ID                     uuid.UUID  `json:"id" db:"id"`
	TerritoryID            uuid.UUID  `json:"territory_id" db:"territory_id"`
	TerritorySOLID         string     `json:"territory_solid" db:"territory_solid"`
	TeamID                 uuid.UUID  `json:"team_id" db:"team_id"`
	AssignedWorkerID       *uuid.UUID `json:"assigned_worker_id,omitempty" db:"assigned_worker_id"`
	AssignedBy             uuid.UUID  `json:"assigned_by" db:"assigned_by"`
	AssignedAt             time.Time  `json:"assigned_at" db:"assigned_at"`
	ExpiresAt              *time.Time `json:"expires_at,omitempty" db:"expires_at"`
	Status                 string     `json:"status" db:"status"` // active, completed, paused, cancelled
	Priority               string     `json:"priority" db:"priority"` // high, medium, low
	Notes                  *string    `json:"notes,omitempty" db:"notes"`
	LastWorkedAt           *time.Time `json:"last_worked_at,omitempty" db:"last_worked_at"`
	VisitsCount            int        `json:"visits_count" db:"visits_count"`
	CompletenessPercentage float64    `json:"completeness_percentage" db:"completeness_percentage"`
	CreatedAt              time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt              time.Time  `json:"updated_at" db:"updated_at"`
}

// TerritoryAssignmentWithDetails includes territory info
type TerritoryAssignmentWithDetails struct {
	TerritoryAssignment
	EntityName   string          `json:"entity_name"`
	EntityID     string          `json:"entity_id"`
	City         *string         `json:"city,omitempty"`
	State        *string         `json:"state,omitempty"`
	UnionName    *string         `json:"union_name,omitempty"`
	Conference   *string         `json:"conference,omitempty"`
	Population   *int            `json:"population,omitempty"`
	HousingUnits *int            `json:"housing_units,omitempty"`
	Geometry     json.RawMessage `json:"geometry,omitempty"` // GeoJSON geometry
}

// CreateAssignmentRequest for creating a new territory assignment
type CreateAssignmentRequest struct {
	TerritoryID      uuid.UUID  `json:"territory_id" binding:"required"`
	TeamID           uuid.UUID  `json:"team_id" binding:"required"`
	AssignedWorkerID *uuid.UUID `json:"assigned_worker_id,omitempty"`
	AssignedBy       uuid.UUID  `json:"assigned_by" binding:"required"`
	Priority         string     `json:"priority"` // defaults to "medium"
	Notes            *string    `json:"notes,omitempty"`
	ExpiresAt        *time.Time `json:"expires_at,omitempty"`
}

// UpdateAssignmentRequest for updating an assignment
type UpdateAssignmentRequest struct {
	AssignedWorkerID       *uuid.UUID `json:"assigned_worker_id,omitempty"`
	Status                 *string    `json:"status,omitempty"`
	Priority               *string    `json:"priority,omitempty"`
	Notes                  *string    `json:"notes,omitempty"`
	ExpiresAt              *time.Time `json:"expires_at,omitempty"`
	VisitsCount            *int       `json:"visits_count,omitempty"`
	CompletenessPercentage *float64   `json:"completeness_percentage,omitempty"`
}

// AssignmentFilters for querying assignments
type AssignmentFilters struct {
	TeamID     *uuid.UUID `json:"team_id" form:"team_id"`
	WorkerID   *uuid.UUID `json:"worker_id" form:"worker_id"`
	Status     string     `json:"status" form:"status"`
	Priority   string     `json:"priority" form:"priority"`
	Limit      int        `json:"limit" form:"limit"`
	Offset     int        `json:"offset" form:"offset"`
}

// TerritoryAssignmentRepository defines the interface for assignment data access
type TerritoryAssignmentRepository interface {
	Create(assignment *TerritoryAssignment) error
	GetByID(id uuid.UUID) (*TerritoryAssignmentWithDetails, error)
	GetByTerritoryID(territoryID uuid.UUID) ([]*TerritoryAssignmentWithDetails, error)
	GetByTeamID(teamID uuid.UUID, status string) ([]*TerritoryAssignmentWithDetails, error)
	GetByWorkerID(workerID uuid.UUID, status string) ([]*TerritoryAssignmentWithDetails, error)
	Update(id uuid.UUID, req *UpdateAssignmentRequest) error
	Delete(id uuid.UUID) error
	GetWorkerAssignmentsGeoJSON(workerID uuid.UUID) (*GeoJSONFeatureCollection, error)
	GetTeamAssignmentsGeoJSON(teamID uuid.UUID) (*GeoJSONFeatureCollection, error)
	RecordVisit(assignmentID uuid.UUID) error
	RecordVisitByTerritoryWorker(territoryID, workerID uuid.UUID) error
}

// TerritoryAssignmentService defines the interface for assignment business logic
type TerritoryAssignmentService interface {
	AssignTerritory(req *CreateAssignmentRequest) (*TerritoryAssignment, error)
	GetAssignment(id uuid.UUID) (*TerritoryAssignmentWithDetails, error)
	GetTeamAssignments(teamID uuid.UUID, status string) ([]*TerritoryAssignmentWithDetails, error)
	GetWorkerAssignments(workerID uuid.UUID, status string) ([]*TerritoryAssignmentWithDetails, error)
	UpdateAssignment(id uuid.UUID, req *UpdateAssignmentRequest) error
	UnassignTerritory(id uuid.UUID) error
	GetWorkerTerritoriesGeoJSON(workerID uuid.UUID) (*GeoJSONFeatureCollection, error)
	GetTeamTerritoriesGeoJSON(teamID uuid.UUID) (*GeoJSONFeatureCollection, error)
	RecordTerritoryVisit(assignmentID uuid.UUID) error
	RecordTerritoryVisitByWorker(territoryID, workerID uuid.UUID) error
}

// Constants for geo territories
const (
	// Default values
	DefaultGeoLimit     = 1000
	MaxGeoLimit         = 5000
	DefaultSearchLimit  = 50
	MaxSearchLimit      = 200

	// Zoom levels for simplified geometry
	ZoomThresholdSimplified = 10

	// Geometry simplification tolerance (degrees)
	SimplificationTolerance = 0.001

	// Tile settings
	TileExtent  = 4096
	TileBuffer  = 64
	MaxTileZoom = 18
	MinTileZoom = 5
)

// ========== Geofence / Territory Work Session Types ==========

// GeofenceCheckRequest for checking if a location is inside assigned territories
type GeofenceCheckRequest struct {
	WorkerID  uuid.UUID `json:"worker_id" binding:"required"`
	TeamID    *uuid.UUID `json:"team_id,omitempty"`
	Latitude  float64   `json:"latitude" binding:"required"`
	Longitude float64   `json:"longitude" binding:"required"`
}

// GeofenceCheckResult result of checking if location is inside a territory
type GeofenceCheckResult struct {
	IsInside       bool       `json:"is_inside"`
	TerritoryID    *uuid.UUID `json:"territory_id,omitempty"`
	AssignmentID   *uuid.UUID `json:"assignment_id,omitempty"`
	TerritorySOLID *string    `json:"territory_solid,omitempty"`
	EntityName     *string    `json:"entity_name,omitempty"`
	EntityID       *string    `json:"entity_id,omitempty"`
}

// TerritoryWorkSession tracks when a worker is inside a territory
type TerritoryWorkSession struct {
	ID                    uuid.UUID  `json:"id" db:"id"`
	WorkerID              uuid.UUID  `json:"worker_id" db:"worker_id"`
	TerritoryID           uuid.UUID  `json:"territory_id" db:"territory_id"`
	AssignmentID          *uuid.UUID `json:"assignment_id,omitempty" db:"assignment_id"`
	EntryTime             time.Time  `json:"entry_time" db:"entry_time"`
	ExitTime              *time.Time `json:"exit_time,omitempty" db:"exit_time"`
	EntryLat              float64    `json:"entry_lat" db:"entry_lat"`
	EntryLng              float64    `json:"entry_lng" db:"entry_lng"`
	ExitLat               *float64   `json:"exit_lat,omitempty" db:"exit_lat"`
	ExitLng               *float64   `json:"exit_lng,omitempty" db:"exit_lng"`
	TimeSpentSeconds      int        `json:"time_spent_seconds" db:"time_spent_seconds"`
	DistanceCoveredMeters float64    `json:"distance_covered_meters" db:"distance_covered_meters"`
	IsActive              bool       `json:"is_active" db:"is_active"`
	CreatedAt             time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt             time.Time  `json:"updated_at" db:"updated_at"`
}

// TerritoryWorkSessionWithDetails includes territory info
type TerritoryWorkSessionWithDetails struct {
	TerritoryWorkSession
	TerritorySOLID string  `json:"territory_solid"`
	EntityName     string  `json:"entity_name"`
	EntityID       string  `json:"entity_id"`
	City           *string `json:"city,omitempty"`
	State          *string `json:"state,omitempty"`
	WorkerName     string  `json:"worker_name,omitempty"`
}

// WorkerLocationUpdate represents a location update from the location service
type WorkerLocationUpdate struct {
	WorkerID  uuid.UUID  `json:"worker_id"`
	TeamID    *uuid.UUID `json:"team_id,omitempty"`
	Latitude  float64    `json:"latitude"`
	Longitude float64    `json:"longitude"`
	Timestamp time.Time  `json:"timestamp"`
}

// GeofenceEvent represents an entry/exit event for a territory
type GeofenceEvent struct {
	EventType     string    `json:"event_type"` // "entry" or "exit"
	WorkerID      uuid.UUID `json:"worker_id"`
	TerritoryID   uuid.UUID `json:"territory_id"`
	AssignmentID  *uuid.UUID `json:"assignment_id,omitempty"`
	TerritoryName string    `json:"territory_name"`
	Latitude      float64   `json:"latitude"`
	Longitude     float64   `json:"longitude"`
	Timestamp     time.Time `json:"timestamp"`
	SessionID     *uuid.UUID `json:"session_id,omitempty"`
}

// GeofenceRepository defines the interface for geofence data access
type GeofenceRepository interface {
	// Check if point is inside worker's assigned territories
	CheckWorkerInTerritory(workerID uuid.UUID, lat, lng float64) (*GeofenceCheckResult, error)
	// Check if point is inside team's assigned territories
	CheckTeamTerritory(teamID uuid.UUID, lat, lng float64) (*GeofenceCheckResult, error)

	// Work session management
	CreateWorkSession(session *TerritoryWorkSession) error
	GetActiveWorkSession(workerID uuid.UUID) (*TerritoryWorkSession, error)
	EndWorkSession(sessionID uuid.UUID, exitLat, exitLng float64, timeSpent int, distance float64) error
	GetWorkerWorkSessions(workerID uuid.UUID, limit, offset int) ([]*TerritoryWorkSessionWithDetails, error)
	GetTerritoryWorkSessions(territoryID uuid.UUID, limit, offset int) ([]*TerritoryWorkSessionWithDetails, error)

	// Manual check-in/check-out
	CreateWorkSessionWithDetails(session *TerritoryWorkSession, territoryName string) (*TerritoryWorkSessionWithDetails, error)
	GetWorkSession(sessionID uuid.UUID) (*TerritoryWorkSessionWithDetails, error)
	EndWorkSessionWithNotes(sessionID uuid.UUID, notes *string) (*TerritoryWorkSessionWithDetails, error)

	// Visit records
	CreateVisitRecord(visit *VisitRecord) error
	GetSessionVisits(sessionID uuid.UUID) ([]*VisitRecord, error)
	GetWorkerVisits(workerID uuid.UUID, date time.Time) ([]*VisitRecord, error)
	GetVisitStats(sessionID uuid.UUID) (*VisitStats, error)

	// Work sessions by date
	GetWorkerWorkSessionsByDate(workerID uuid.UUID, date time.Time) ([]*TerritoryWorkSessionWithDetails, error)

	// Active workers
	GetAllActiveSessions() ([]*TerritoryWorkSessionWithDetails, error)
	GetTeamActiveSessions(teamID uuid.UUID) ([]*TerritoryWorkSessionWithDetails, error)
}

// GeofenceService defines the interface for geofence business logic
type GeofenceService interface {
	// Process a location update and check geofencing
	ProcessLocationUpdate(update *WorkerLocationUpdate) (*GeofenceEvent, error)

	// Check if worker is currently inside any assigned territory
	CheckWorkerLocation(req *GeofenceCheckRequest) (*GeofenceCheckResult, error)

	// Get worker's current territory (if any)
	GetWorkerCurrentTerritory(workerID uuid.UUID) (*GeofenceCheckResult, error)

	// Get work session history
	GetWorkerWorkSessions(workerID uuid.UUID, limit, offset int) ([]*TerritoryWorkSessionWithDetails, error)

	// Manual check-in/check-out
	CheckIn(req *CheckInRequest) (*TerritoryWorkSessionWithDetails, error)
	CheckOut(req *CheckOutRequest) (*TerritoryWorkSessionWithDetails, error)

	// Visit logging
	LogVisit(req *LogVisitRequest) (*VisitRecord, error)
	GetSessionVisits(sessionID uuid.UUID) ([]*VisitRecord, error)
	GetWorkerVisits(workerID uuid.UUID, date time.Time) ([]*VisitRecord, error)

	// Get worker's current active session with details
	GetWorkerCurrentSession(workerID uuid.UUID) (*TerritoryWorkSessionWithDetails, error)

	// Get work sessions by date
	GetWorkerWorkSessionsByDate(workerID uuid.UUID, date time.Time) ([]*TerritoryWorkSessionWithDetails, error)

	// Active workers
	GetActiveWorkers() ([]*TerritoryWorkSessionWithDetails, error)
	GetTeamActiveWorkers(teamID uuid.UUID) ([]*TerritoryWorkSessionWithDetails, error)
}

// ========== Manual Check-in/Check-out Types ==========

// CheckInRequest for manual worker check-in
type CheckInRequest struct {
	WorkerID      uuid.UUID  `json:"worker_id"`
	TerritoryID   uuid.UUID  `json:"territory_id"`
	TerritoryName string     `json:"territory_name"`
	Latitude      *float64   `json:"latitude,omitempty"`
	Longitude     *float64   `json:"longitude,omitempty"`
}

// CheckOutRequest for manual worker check-out
type CheckOutRequest struct {
	SessionID uuid.UUID `json:"session_id"`
	WorkerID  uuid.UUID `json:"worker_id"`
	Notes     *string   `json:"notes,omitempty"`
}

// ========== Visit Record Types ==========

// VisitRecord represents a single visit during a work session
type VisitRecord struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	SessionID   uuid.UUID  `json:"session_id" db:"session_id"`
	WorkerID    uuid.UUID  `json:"worker_id" db:"worker_id"`
	TerritoryID uuid.UUID  `json:"territory_id" db:"territory_id"`
	Address     string     `json:"address" db:"address"`
	Outcome     string     `json:"outcome" db:"outcome"`
	Notes       *string    `json:"notes,omitempty" db:"notes"`
	Latitude    *float64   `json:"latitude,omitempty" db:"latitude"`
	Longitude   *float64   `json:"longitude,omitempty" db:"longitude"`
	VisitedAt   time.Time  `json:"visited_at" db:"visited_at"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

// LogVisitRequest for logging a visit
type LogVisitRequest struct {
	SessionID   uuid.UUID  `json:"session_id"`
	WorkerID    uuid.UUID  `json:"worker_id"`
	TerritoryID uuid.UUID  `json:"territory_id"`
	Address     string     `json:"address" binding:"required"`
	Outcome     string     `json:"outcome" binding:"required"`
	Notes       *string    `json:"notes,omitempty"`
	Latitude    *float64   `json:"latitude,omitempty"`
	Longitude   *float64   `json:"longitude,omitempty"`
}

// VisitStats aggregated visit statistics
type VisitStats struct {
	TotalVisits int `json:"total_visits"`
	Contacted   int `json:"contacted"`
	NotHome     int `json:"not_home"`
	Interested  int `json:"interested"`
	DoNotCall   int `json:"do_not_call"`
	Completed   int `json:"completed"`
	Other       int `json:"other"`
}
