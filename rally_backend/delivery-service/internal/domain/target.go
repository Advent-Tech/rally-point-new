package domain

import (
	"time"

	"github.com/google/uuid"
)

type TargetType string
type TargetUnit string
type PeriodType string
type AssignedToType string
type TargetStatus string

const (
	TargetTypeTerritory TargetType = "territory"
	TargetTypeDonation  TargetType = "donation"
	TargetTypePrayer    TargetType = "prayer"
	TargetTypeVisit     TargetType = "visit"
	TargetTypeSession   TargetType = "session"
)

const (
	TargetUnitCount      TargetUnit = "count"
	TargetUnitAmount     TargetUnit = "amount"
	TargetUnitPercentage TargetUnit = "percentage"
	TargetUnitHours      TargetUnit = "hours"
)

const (
	PeriodDaily      PeriodType = "daily"
	PeriodWeekly     PeriodType = "weekly"
	PeriodMonthly    PeriodType = "monthly"
	PeriodCumulative PeriodType = "cumulative"
)

const (
	AssignedToTeam   AssignedToType = "team"
	AssignedToWorker AssignedToType = "worker"
)

const (
	TargetStatusActive    TargetStatus = "active"
	TargetStatusCompleted TargetStatus = "completed"
	TargetStatusCancelled TargetStatus = "cancelled"
)

// Target represents a target definition
type Target struct {
	ID            uuid.UUID  `json:"id"`
	Name          string     `json:"name"`
	Description   string     `json:"description"`
	TargetType    TargetType `json:"target_type"`
	TargetUnit    TargetUnit `json:"target_unit"`
	TargetValue   float64    `json:"target_value"`
	PeriodType    PeriodType `json:"period_type"`
	CreatedBy     uuid.UUID  `json:"created_by"`
	CreatedByRole string     `json:"created_by_role"`
	IsActive      bool       `json:"is_active"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

// TargetAssignment represents a target assigned to a team or worker
type TargetAssignment struct {
	ID             uuid.UUID      `json:"id"`
	TargetID       uuid.UUID      `json:"target_id"`
	Target         *Target        `json:"target,omitempty"`
	AssignedToType AssignedToType `json:"assigned_to_type"`
	AssignedToID   uuid.UUID      `json:"assigned_to_id"`
	AssignedBy     uuid.UUID      `json:"assigned_by"`
	PeriodStart    *time.Time     `json:"period_start"`
	PeriodEnd      *time.Time     `json:"period_end"`
	Status         TargetStatus   `json:"status"`
	CreatedAt      time.Time      `json:"created_at"`
}

// TargetProgress represents the current progress toward a target
type TargetProgress struct {
	ID           uuid.UUID  `json:"id"`
	AssignmentID uuid.UUID  `json:"assignment_id"`
	CurrentValue float64    `json:"current_value"`
	LastUpdated  time.Time  `json:"last_updated"`
	PeriodStart  *time.Time `json:"period_start"`
	PeriodEnd    *time.Time `json:"period_end"`
}

// WorkerTarget represents a worker's view of their targets with progress
type WorkerTarget struct {
	Assignment  TargetAssignment `json:"assignment"`
	Progress    TargetProgress   `json:"progress"`
	Percentage  float64          `json:"percentage"`
	IsCompleted bool             `json:"is_completed"`
}
