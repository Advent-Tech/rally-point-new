package domain

import (
	"time"

	"github.com/google/uuid"
)

// WorkSchedule represents a scheduled work shift for a worker
type WorkSchedule struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	TeamID          uuid.UUID  `json:"team_id" db:"team_id"`
	WorkerID        uuid.UUID  `json:"worker_id" db:"worker_id"`
	WorkerName      string     `json:"worker_name" db:"worker_name"`
	TerritoryID     *uuid.UUID `json:"territory_id,omitempty" db:"territory_id"`
	TerritoryName   *string    `json:"territory_name,omitempty" db:"territory_name"`
	ScheduledDate   time.Time  `json:"date" db:"scheduled_date"`
	StartTime       string     `json:"start_time" db:"start_time"`
	EndTime         string     `json:"end_time" db:"end_time"`
	Status          string     `json:"status" db:"status"` // scheduled, in_progress, completed, cancelled, missed
	Notes           *string    `json:"notes,omitempty" db:"notes"`
	ActualStartTime *time.Time `json:"actual_start_time,omitempty" db:"actual_start_time"`
	ActualEndTime   *time.Time `json:"actual_end_time,omitempty" db:"actual_end_time"`
	CreatedBy       uuid.UUID  `json:"created_by" db:"created_by"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

// Schedule status constants
const (
	ScheduleStatusScheduled  = "scheduled"
	ScheduleStatusInProgress = "in_progress"
	ScheduleStatusCompleted  = "completed"
	ScheduleStatusCancelled  = "cancelled"
	ScheduleStatusMissed     = "missed"
)

// CreateScheduleRequest for creating a new schedule
type CreateScheduleRequest struct {
	TeamID      uuid.UUID  `json:"team_id" binding:"required"`
	WorkerID    uuid.UUID  `json:"worker_id" binding:"required"`
	WorkerName  string     `json:"worker_name"`
	TerritoryID *uuid.UUID `json:"territory_id"`
	Date        string     `json:"date" binding:"required"` // YYYY-MM-DD
	StartTime   string     `json:"start_time" binding:"required"` // HH:MM
	EndTime     string     `json:"end_time" binding:"required"` // HH:MM
	Notes       *string    `json:"notes"`
}

// UpdateScheduleRequest for updating a schedule
type UpdateScheduleRequest struct {
	WorkerID      *uuid.UUID `json:"worker_id"`
	WorkerName    *string    `json:"worker_name"`
	TerritoryID   *uuid.UUID `json:"territory_id"`
	TerritoryName *string    `json:"territory_name"`
	Date          *string    `json:"date"`      // YYYY-MM-DD
	StartTime     *string    `json:"start_time"` // HH:MM
	EndTime       *string    `json:"end_time"`   // HH:MM
	Status        *string    `json:"status"`
	Notes         *string    `json:"notes"`
}

// ScheduleFilters for querying schedules
type ScheduleFilters struct {
	TeamID    *uuid.UUID `json:"team_id" form:"team_id"`
	WorkerID  *uuid.UUID `json:"worker_id" form:"worker_id"`
	Date      string     `json:"date" form:"date"` // YYYY-MM-DD
	StartDate string     `json:"start_date" form:"start_date"`
	EndDate   string     `json:"end_date" form:"end_date"`
	Status    string     `json:"status" form:"status"`
}

// ScheduleListResponse for list endpoints
type ScheduleListResponse struct {
	Schedules []*WorkSchedule `json:"schedules"`
	Count     int             `json:"count"`
}

// ScheduleRepository defines the interface for schedule data access
type ScheduleRepository interface {
	// CRUD operations
	Create(schedule *WorkSchedule) error
	GetByID(id uuid.UUID) (*WorkSchedule, error)
	Update(id uuid.UUID, req *UpdateScheduleRequest) error
	Delete(id uuid.UUID) error

	// Query operations
	GetByTeamAndDate(teamID uuid.UUID, date time.Time) ([]*WorkSchedule, error)
	GetByWorkerAndDate(workerID uuid.UUID, date time.Time) ([]*WorkSchedule, error)
	GetByWorkerDateRange(workerID uuid.UUID, startDate, endDate time.Time) ([]*WorkSchedule, error)
	GetByTeamDateRange(teamID uuid.UUID, startDate, endDate time.Time) ([]*WorkSchedule, error)

	// Status updates
	UpdateStatus(id uuid.UUID, status string) error
	SetActualStartTime(id uuid.UUID, startTime time.Time) error
	SetActualEndTime(id uuid.UUID, endTime time.Time) error

	// Utility
	MarkMissedSchedules() (int, error)
}

// ScheduleService defines the interface for schedule business logic
type ScheduleService interface {
	// CRUD operations
	CreateSchedule(createdBy uuid.UUID, req *CreateScheduleRequest) (*WorkSchedule, error)
	GetSchedule(id uuid.UUID) (*WorkSchedule, error)
	UpdateSchedule(id uuid.UUID, req *UpdateScheduleRequest) (*WorkSchedule, error)
	DeleteSchedule(id uuid.UUID) error

	// Query operations
	GetTeamSchedules(teamID uuid.UUID, date time.Time) (*ScheduleListResponse, error)
	GetWorkerSchedules(workerID uuid.UUID, date time.Time) (*ScheduleListResponse, error)
	GetWorkerScheduleRange(workerID uuid.UUID, startDate, endDate time.Time) (*ScheduleListResponse, error)

	// Session integration
	StartScheduledSession(scheduleID uuid.UUID) error
	CompleteScheduledSession(scheduleID uuid.UUID) error
	CancelSchedule(scheduleID uuid.UUID) error
}
