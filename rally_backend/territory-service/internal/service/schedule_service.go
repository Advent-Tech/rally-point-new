package service

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// scheduleService implements ScheduleService
type scheduleService struct {
	repo domain.ScheduleRepository
}

// NewScheduleService creates a new schedule service
func NewScheduleService(repo domain.ScheduleRepository) domain.ScheduleService {
	return &scheduleService{repo: repo}
}

// CreateSchedule creates a new work schedule
func (s *scheduleService) CreateSchedule(createdBy uuid.UUID, req *domain.CreateScheduleRequest) (*domain.WorkSchedule, error) {
	// Validate required fields
	if req.TeamID == uuid.Nil {
		return nil, fmt.Errorf("team_id is required")
	}
	if req.WorkerID == uuid.Nil {
		return nil, fmt.Errorf("worker_id is required")
	}
	if req.Date == "" {
		return nil, fmt.Errorf("date is required")
	}
	if req.StartTime == "" {
		return nil, fmt.Errorf("start_time is required")
	}
	if req.EndTime == "" {
		return nil, fmt.Errorf("end_time is required")
	}

	// Parse the date
	scheduledDate, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		return nil, fmt.Errorf("invalid date format, expected YYYY-MM-DD: %w", err)
	}

	// Build schedule
	schedule := &domain.WorkSchedule{
		ID:            uuid.New(),
		TeamID:        req.TeamID,
		WorkerID:      req.WorkerID,
		WorkerName:    req.WorkerName,
		TerritoryID:   req.TerritoryID,
		ScheduledDate: scheduledDate,
		StartTime:     req.StartTime,
		EndTime:       req.EndTime,
		Status:        domain.ScheduleStatusScheduled,
		Notes:         req.Notes,
		CreatedBy:     createdBy,
	}

	// If territory ID provided, try to get territory name
	if req.TerritoryID != nil {
		// For now, we just save it - territory name can be set separately
		// In a full implementation, we'd look up the territory name here
	}

	err = s.repo.Create(schedule)
	if err != nil {
		return nil, fmt.Errorf("failed to create schedule: %w", err)
	}

	return schedule, nil
}

// GetSchedule gets a schedule by ID
func (s *scheduleService) GetSchedule(id uuid.UUID) (*domain.WorkSchedule, error) {
	schedule, err := s.repo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get schedule: %w", err)
	}
	return schedule, nil
}

// UpdateSchedule updates a schedule
func (s *scheduleService) UpdateSchedule(id uuid.UUID, req *domain.UpdateScheduleRequest) (*domain.WorkSchedule, error) {
	// Verify schedule exists
	existing, err := s.repo.GetByID(id)
	if err != nil {
		return nil, err
	}

	// Can't update completed or missed schedules
	if existing.Status == domain.ScheduleStatusCompleted || existing.Status == domain.ScheduleStatusMissed {
		return nil, fmt.Errorf("cannot update %s schedule", existing.Status)
	}

	err = s.repo.Update(id, req)
	if err != nil {
		return nil, fmt.Errorf("failed to update schedule: %w", err)
	}

	// Return updated schedule
	return s.repo.GetByID(id)
}

// DeleteSchedule deletes a schedule
func (s *scheduleService) DeleteSchedule(id uuid.UUID) error {
	// Verify schedule exists
	existing, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}

	// Can't delete in_progress schedules
	if existing.Status == domain.ScheduleStatusInProgress {
		return fmt.Errorf("cannot delete in_progress schedule")
	}

	return s.repo.Delete(id)
}

// GetTeamSchedules gets all schedules for a team on a specific date
func (s *scheduleService) GetTeamSchedules(teamID uuid.UUID, date time.Time) (*domain.ScheduleListResponse, error) {
	schedules, err := s.repo.GetByTeamAndDate(teamID, date)
	if err != nil {
		return nil, fmt.Errorf("failed to get team schedules: %w", err)
	}

	if schedules == nil {
		schedules = []*domain.WorkSchedule{}
	}

	return &domain.ScheduleListResponse{
		Schedules: schedules,
		Count:     len(schedules),
	}, nil
}

// GetWorkerSchedules gets all schedules for a worker on a specific date
func (s *scheduleService) GetWorkerSchedules(workerID uuid.UUID, date time.Time) (*domain.ScheduleListResponse, error) {
	schedules, err := s.repo.GetByWorkerAndDate(workerID, date)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker schedules: %w", err)
	}

	if schedules == nil {
		schedules = []*domain.WorkSchedule{}
	}

	return &domain.ScheduleListResponse{
		Schedules: schedules,
		Count:     len(schedules),
	}, nil
}

// GetWorkerScheduleRange gets schedules for a worker within a date range
func (s *scheduleService) GetWorkerScheduleRange(workerID uuid.UUID, startDate, endDate time.Time) (*domain.ScheduleListResponse, error) {
	schedules, err := s.repo.GetByWorkerDateRange(workerID, startDate, endDate)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker schedule range: %w", err)
	}

	if schedules == nil {
		schedules = []*domain.WorkSchedule{}
	}

	return &domain.ScheduleListResponse{
		Schedules: schedules,
		Count:     len(schedules),
	}, nil
}

// StartScheduledSession marks a schedule as in progress with actual start time
func (s *scheduleService) StartScheduledSession(scheduleID uuid.UUID) error {
	// Verify schedule exists and is in scheduled status
	schedule, err := s.repo.GetByID(scheduleID)
	if err != nil {
		return err
	}

	if schedule.Status != domain.ScheduleStatusScheduled {
		return fmt.Errorf("schedule is not in scheduled status")
	}

	return s.repo.SetActualStartTime(scheduleID, time.Now())
}

// CompleteScheduledSession marks a schedule as completed with actual end time
func (s *scheduleService) CompleteScheduledSession(scheduleID uuid.UUID) error {
	// Verify schedule exists and is in progress
	schedule, err := s.repo.GetByID(scheduleID)
	if err != nil {
		return err
	}

	if schedule.Status != domain.ScheduleStatusInProgress {
		return fmt.Errorf("schedule is not in progress")
	}

	return s.repo.SetActualEndTime(scheduleID, time.Now())
}

// CancelSchedule cancels a scheduled shift
func (s *scheduleService) CancelSchedule(scheduleID uuid.UUID) error {
	// Verify schedule exists
	schedule, err := s.repo.GetByID(scheduleID)
	if err != nil {
		return err
	}

	// Can only cancel scheduled status
	if schedule.Status != domain.ScheduleStatusScheduled {
		return fmt.Errorf("can only cancel scheduled shifts")
	}

	return s.repo.UpdateStatus(scheduleID, domain.ScheduleStatusCancelled)
}
