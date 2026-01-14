package domain

import (
	"time"

	"github.com/google/uuid"
)

// Prayer request types
const (
	PrayerTypeChurch    = "church_prayer" // Prayer at church
	PrayerTypeHomeVisit = "home_visit"    // Preacher visits home
)

// Prayer request statuses
const (
	PrayerStatusPending    = "pending"
	PrayerStatusScheduled  = "scheduled"
	PrayerStatusInProgress = "in_progress"
	PrayerStatusCompleted  = "completed"
	PrayerStatusCancelled  = "cancelled"
)

// Prayer categories
const (
	PrayerCategoryGeneral      = "general"
	PrayerCategoryHealing      = "healing"
	PrayerCategoryFamily       = "family"
	PrayerCategoryFinancial    = "financial"
	PrayerCategorySpiritual    = "spiritual"
	PrayerCategoryThanksgiving = "thanksgiving"
	PrayerCategoryOther        = "other"
)

// Urgency levels
const (
	UrgencyLow    = "low"
	UrgencyNormal = "normal"
	UrgencyHigh   = "high"
	UrgencyUrgent = "urgent"
)

// PrayerRequest represents a prayer request collected by workers
type PrayerRequest struct {
	ID          uuid.UUID `json:"id" db:"id"`
	WorkerID    uuid.UUID `json:"worker_id" db:"worker_id"`
	TeamID      *uuid.UUID `json:"team_id,omitempty" db:"team_id"`
	TerritoryID *uuid.UUID `json:"territory_id,omitempty" db:"territory_id"`

	// Requester info
	RequesterName    string  `json:"requester_name" db:"requester_name"`
	RequesterPhone   *string `json:"requester_phone,omitempty" db:"requester_phone"`
	RequesterEmail   *string `json:"requester_email,omitempty" db:"requester_email"`
	RequesterAddress *string `json:"requester_address,omitempty" db:"requester_address"`

	// Location
	Latitude  *float64 `json:"latitude,omitempty" db:"latitude"`
	Longitude *float64 `json:"longitude,omitempty" db:"longitude"`

	// Prayer details
	PrayerSubject  string `json:"prayer_subject" db:"prayer_subject"`
	PrayerDetails  string `json:"prayer_details" db:"prayer_details"`
	PrayerCategory string `json:"prayer_category" db:"prayer_category"`

	// Request type
	RequestType string `json:"request_type" db:"request_type"`

	// For home visits
	PreacherID         *uuid.UUID `json:"preacher_id,omitempty" db:"preacher_id"`
	PreferredVisitDate *string    `json:"preferred_visit_date,omitempty" db:"preferred_visit_date"`
	PreferredVisitTime *string    `json:"preferred_visit_time,omitempty" db:"preferred_visit_time"`

	// Status
	Status  string `json:"status" db:"status"`
	Urgency string `json:"urgency" db:"urgency"`

	// Completion
	ScheduledAt     *time.Time `json:"scheduled_at,omitempty" db:"scheduled_at"`
	CompletedAt     *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	CompletedBy     *uuid.UUID `json:"completed_by,omitempty" db:"completed_by"`
	CompletionNotes *string    `json:"completion_notes,omitempty" db:"completion_notes"`

	// Metadata
	Notes     *string   `json:"notes,omitempty" db:"notes"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`

	// Joined data (not in DB)
	WorkerName   string `json:"worker_name,omitempty" db:"worker_name"`
	PreacherName string `json:"preacher_name,omitempty" db:"preacher_name"`
}

// CreatePrayerRequestRequest is the request body for creating a prayer request
type CreatePrayerRequestRequest struct {
	RequesterName      string   `json:"requester_name" binding:"required"`
	RequesterPhone     *string  `json:"requester_phone"`
	RequesterEmail     *string  `json:"requester_email"`
	RequesterAddress   *string  `json:"requester_address"`
	Latitude           *float64 `json:"latitude"`
	Longitude          *float64 `json:"longitude"`
	PrayerSubject      string   `json:"prayer_subject" binding:"required"`
	PrayerDetails      string   `json:"prayer_details" binding:"required"`
	PrayerCategory     string   `json:"prayer_category"`
	RequestType        string   `json:"request_type" binding:"required"`
	PreferredVisitDate *string  `json:"preferred_visit_date"`
	PreferredVisitTime *string  `json:"preferred_visit_time"`
	Urgency            string   `json:"urgency"`
	TerritoryID        *string  `json:"territory_id"`
	Notes              *string  `json:"notes"`
}

// UpdatePrayerRequestRequest is the request body for updating a prayer request
type UpdatePrayerRequestRequest struct {
	RequesterName      *string  `json:"requester_name"`
	RequesterPhone     *string  `json:"requester_phone"`
	RequesterEmail     *string  `json:"requester_email"`
	RequesterAddress   *string  `json:"requester_address"`
	Latitude           *float64 `json:"latitude"`
	Longitude          *float64 `json:"longitude"`
	PrayerSubject      *string  `json:"prayer_subject"`
	PrayerDetails      *string  `json:"prayer_details"`
	PrayerCategory     *string  `json:"prayer_category"`
	RequestType        *string  `json:"request_type"`
	PreferredVisitDate *string  `json:"preferred_visit_date"`
	PreferredVisitTime *string  `json:"preferred_visit_time"`
	Urgency            *string  `json:"urgency"`
	Notes              *string  `json:"notes"`
}

// UpdatePrayerStatusRequest is for updating prayer request status
type UpdatePrayerStatusRequest struct {
	Status          string  `json:"status" binding:"required"`
	CompletionNotes *string `json:"completion_notes"`
}

// AssignPreacherRequest is for assigning a preacher to home visit
type AssignPreacherRequest struct {
	PreacherID  string  `json:"preacher_id" binding:"required"`
	ScheduledAt *string `json:"scheduled_at"`
	Notes       *string `json:"notes"`
}

// PrayerRequestFilter for filtering prayer requests
type PrayerRequestFilter struct {
	WorkerID    *uuid.UUID
	TeamID      *uuid.UUID
	TerritoryID *uuid.UUID
	Status      *string
	RequestType *string
	Category    *string
	Urgency     *string
	StartDate   *time.Time
	EndDate     *time.Time
}

// PrayerRequestListResponse is the paginated response
type PrayerRequestListResponse struct {
	PrayerRequests []PrayerRequest `json:"prayer_requests"`
	Total          int64           `json:"total"`
	Page           int             `json:"page"`
	PageSize       int             `json:"page_size"`
	TotalPages     int             `json:"total_pages"`
}

// PrayerRequestMapMarker for map display
type PrayerRequestMapMarker struct {
	ID             uuid.UUID `json:"id"`
	Latitude       float64   `json:"latitude"`
	Longitude      float64   `json:"longitude"`
	RequesterName  string    `json:"requester_name"`
	PrayerSubject  string    `json:"prayer_subject"`
	PrayerCategory string    `json:"prayer_category"`
	RequestType    string    `json:"request_type"`
	Status         string    `json:"status"`
	Urgency        string    `json:"urgency"`
	CreatedAt      time.Time `json:"created_at"`
}

// PrayerRequestStats for dashboard statistics
type PrayerRequestStats struct {
	TotalRequests     int64            `json:"total_requests"`
	PendingRequests   int64            `json:"pending_requests"`
	CompletedRequests int64            `json:"completed_requests"`
	HomeVisitRequests int64            `json:"home_visit_requests"`
	ByCategory        map[string]int64 `json:"by_category"`
	ByUrgency         map[string]int64 `json:"by_urgency"`
}

// PrayerRequestRepository interface
type PrayerRequestRepository interface {
	Create(request *PrayerRequest) error
	GetByID(id uuid.UUID) (*PrayerRequest, error)
	Update(request *PrayerRequest) error
	Delete(id uuid.UUID) error
	List(filter *PrayerRequestFilter, page, pageSize int) ([]PrayerRequest, int64, error)
	GetMapMarkers(filter *PrayerRequestFilter) ([]PrayerRequestMapMarker, error)
	GetByWorker(workerID uuid.UUID, page, pageSize int) ([]PrayerRequest, int64, error)
	GetByTeam(teamID uuid.UUID, page, pageSize int) ([]PrayerRequest, int64, error)
	GetByTerritory(territoryID uuid.UUID, page, pageSize int) ([]PrayerRequest, int64, error)
	GetStats(filter *PrayerRequestFilter) (*PrayerRequestStats, error)
	UpdateStatus(id uuid.UUID, status string, completedBy *uuid.UUID, notes *string) error
	AssignPreacher(id uuid.UUID, preacherID uuid.UUID, scheduledAt *time.Time, notes *string) error
}

// PrayerRequestService interface
type PrayerRequestService interface {
	CreatePrayerRequest(workerID, teamID uuid.UUID, req *CreatePrayerRequestRequest) (*PrayerRequest, error)
	GetPrayerRequest(id uuid.UUID) (*PrayerRequest, error)
	UpdatePrayerRequest(id uuid.UUID, req *UpdatePrayerRequestRequest) (*PrayerRequest, error)
	DeletePrayerRequest(id uuid.UUID) error
	ListPrayerRequests(filter *PrayerRequestFilter, page, pageSize int) (*PrayerRequestListResponse, error)
	GetMapMarkers(filter *PrayerRequestFilter) ([]PrayerRequestMapMarker, error)
	GetWorkerPrayerRequests(workerID uuid.UUID, page, pageSize int) (*PrayerRequestListResponse, error)
	GetTeamPrayerRequests(teamID uuid.UUID, page, pageSize int) (*PrayerRequestListResponse, error)
	GetTerritoryPrayerRequests(territoryID uuid.UUID, page, pageSize int) (*PrayerRequestListResponse, error)
	GetStats(filter *PrayerRequestFilter) (*PrayerRequestStats, error)
	UpdateStatus(id uuid.UUID, status string, completedBy *uuid.UUID, notes *string) error
	AssignPreacher(id uuid.UUID, preacherID uuid.UUID, scheduledAt *time.Time, notes *string) error
	CompletePrayerRequest(id uuid.UUID, completedBy uuid.UUID, notes *string) error
}
