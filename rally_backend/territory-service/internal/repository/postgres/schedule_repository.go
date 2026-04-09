package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// scheduleRepository implements ScheduleRepository
type scheduleRepository struct {
	db *sql.DB
}

// NewScheduleRepository creates a new schedule repository
func NewScheduleRepository(db *sql.DB) domain.ScheduleRepository {
	return &scheduleRepository{db: db}
}

// Create creates a new work schedule
func (r *scheduleRepository) Create(schedule *domain.WorkSchedule) error {
	query := `
		INSERT INTO work_schedules (
			id, team_id, worker_id, worker_name, territory_id, territory_name,
			scheduled_date, start_time, end_time, status, notes, created_by,
			created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
		)
	`

	now := time.Now()
	if schedule.ID == uuid.Nil {
		schedule.ID = uuid.New()
	}
	schedule.CreatedAt = now
	schedule.UpdatedAt = now

	if schedule.Status == "" {
		schedule.Status = domain.ScheduleStatusScheduled
	}

	_, err := r.db.Exec(query,
		schedule.ID,
		schedule.TeamID,
		schedule.WorkerID,
		schedule.WorkerName,
		schedule.TerritoryID,
		schedule.TerritoryName,
		schedule.ScheduledDate,
		schedule.StartTime,
		schedule.EndTime,
		schedule.Status,
		schedule.Notes,
		schedule.CreatedBy,
		schedule.CreatedAt,
		schedule.UpdatedAt,
	)

	return err
}

// GetByID retrieves a schedule by ID
func (r *scheduleRepository) GetByID(id uuid.UUID) (*domain.WorkSchedule, error) {
	query := `
		SELECT
			id, team_id, worker_id, worker_name, territory_id, territory_name,
			scheduled_date, start_time::text, end_time::text, status, notes,
			actual_start_time, actual_end_time, created_by, created_at, updated_at
		FROM work_schedules
		WHERE id = $1
	`

	var s domain.WorkSchedule
	err := r.db.QueryRow(query, id).Scan(
		&s.ID, &s.TeamID, &s.WorkerID, &s.WorkerName, &s.TerritoryID, &s.TerritoryName,
		&s.ScheduledDate, &s.StartTime, &s.EndTime, &s.Status, &s.Notes,
		&s.ActualStartTime, &s.ActualEndTime, &s.CreatedBy, &s.CreatedAt, &s.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("schedule not found")
		}
		return nil, fmt.Errorf("failed to get schedule: %w", err)
	}

	return &s, nil
}

// Update updates a schedule
func (r *scheduleRepository) Update(id uuid.UUID, req *domain.UpdateScheduleRequest) error {
	// Build dynamic update query
	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIndex := 1

	if req.WorkerID != nil {
		setClauses = append(setClauses, fmt.Sprintf("worker_id = $%d", argIndex))
		args = append(args, *req.WorkerID)
		argIndex++
	}
	if req.WorkerName != nil {
		setClauses = append(setClauses, fmt.Sprintf("worker_name = $%d", argIndex))
		args = append(args, *req.WorkerName)
		argIndex++
	}
	if req.TerritoryID != nil {
		setClauses = append(setClauses, fmt.Sprintf("territory_id = $%d", argIndex))
		args = append(args, *req.TerritoryID)
		argIndex++
	}
	if req.TerritoryName != nil {
		setClauses = append(setClauses, fmt.Sprintf("territory_name = $%d", argIndex))
		args = append(args, *req.TerritoryName)
		argIndex++
	}
	if req.Date != nil {
		setClauses = append(setClauses, fmt.Sprintf("scheduled_date = $%d", argIndex))
		args = append(args, *req.Date)
		argIndex++
	}
	if req.StartTime != nil {
		setClauses = append(setClauses, fmt.Sprintf("start_time = $%d", argIndex))
		args = append(args, *req.StartTime)
		argIndex++
	}
	if req.EndTime != nil {
		setClauses = append(setClauses, fmt.Sprintf("end_time = $%d", argIndex))
		args = append(args, *req.EndTime)
		argIndex++
	}
	if req.Status != nil {
		setClauses = append(setClauses, fmt.Sprintf("status = $%d", argIndex))
		args = append(args, *req.Status)
		argIndex++
	}
	if req.Notes != nil {
		setClauses = append(setClauses, fmt.Sprintf("notes = $%d", argIndex))
		args = append(args, *req.Notes)
		argIndex++
	}

	// Add ID as the last argument
	args = append(args, id)

	query := fmt.Sprintf("UPDATE work_schedules SET %s WHERE id = $%d",
		joinStrings(setClauses, ", "), argIndex)

	result, err := r.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update schedule: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rowsAffected == 0 {
		return fmt.Errorf("schedule not found")
	}

	return nil
}

// Delete deletes a schedule
func (r *scheduleRepository) Delete(id uuid.UUID) error {
	result, err := r.db.Exec("DELETE FROM work_schedules WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("failed to delete schedule: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rowsAffected == 0 {
		return fmt.Errorf("schedule not found")
	}

	return nil
}

// GetByTeamAndDate gets all schedules for a team on a specific date
func (r *scheduleRepository) GetByTeamAndDate(teamID uuid.UUID, date time.Time) ([]*domain.WorkSchedule, error) {
	query := `
		SELECT
			id, team_id, worker_id, worker_name, territory_id, territory_name,
			scheduled_date, start_time::text, end_time::text, status, notes,
			actual_start_time, actual_end_time, created_by, created_at, updated_at
		FROM work_schedules
		WHERE team_id = $1 AND scheduled_date = $2
		ORDER BY start_time, worker_name
	`

	rows, err := r.db.Query(query, teamID, date.Format("2006-01-02"))
	if err != nil {
		return nil, fmt.Errorf("failed to query schedules: %w", err)
	}
	defer rows.Close()

	return r.scanSchedules(rows)
}

// GetByWorkerAndDate gets all schedules for a worker on a specific date
func (r *scheduleRepository) GetByWorkerAndDate(workerID uuid.UUID, date time.Time) ([]*domain.WorkSchedule, error) {
	query := `
		SELECT
			id, team_id, worker_id, worker_name, territory_id, territory_name,
			scheduled_date, start_time::text, end_time::text, status, notes,
			actual_start_time, actual_end_time, created_by, created_at, updated_at
		FROM work_schedules
		WHERE worker_id = $1 AND scheduled_date = $2 AND status != 'cancelled'
		ORDER BY start_time
	`

	rows, err := r.db.Query(query, workerID, date.Format("2006-01-02"))
	if err != nil {
		return nil, fmt.Errorf("failed to query schedules: %w", err)
	}
	defer rows.Close()

	return r.scanSchedules(rows)
}

// GetByWorkerDateRange gets schedules for a worker within a date range
func (r *scheduleRepository) GetByWorkerDateRange(workerID uuid.UUID, startDate, endDate time.Time) ([]*domain.WorkSchedule, error) {
	query := `
		SELECT
			id, team_id, worker_id, worker_name, territory_id, territory_name,
			scheduled_date, start_time::text, end_time::text, status, notes,
			actual_start_time, actual_end_time, created_by, created_at, updated_at
		FROM work_schedules
		WHERE worker_id = $1 AND scheduled_date BETWEEN $2 AND $3 AND status != 'cancelled'
		ORDER BY scheduled_date, start_time
	`

	rows, err := r.db.Query(query, workerID, startDate.Format("2006-01-02"), endDate.Format("2006-01-02"))
	if err != nil {
		return nil, fmt.Errorf("failed to query schedules: %w", err)
	}
	defer rows.Close()

	return r.scanSchedules(rows)
}

// GetByTeamDateRange gets schedules for a team within a date range
func (r *scheduleRepository) GetByTeamDateRange(teamID uuid.UUID, startDate, endDate time.Time) ([]*domain.WorkSchedule, error) {
	query := `
		SELECT
			id, team_id, worker_id, worker_name, territory_id, territory_name,
			scheduled_date, start_time::text, end_time::text, status, notes,
			actual_start_time, actual_end_time, created_by, created_at, updated_at
		FROM work_schedules
		WHERE team_id = $1 AND scheduled_date BETWEEN $2 AND $3
		ORDER BY scheduled_date, start_time, worker_name
	`

	rows, err := r.db.Query(query, teamID, startDate.Format("2006-01-02"), endDate.Format("2006-01-02"))
	if err != nil {
		return nil, fmt.Errorf("failed to query schedules: %w", err)
	}
	defer rows.Close()

	return r.scanSchedules(rows)
}

// UpdateStatus updates just the status of a schedule
func (r *scheduleRepository) UpdateStatus(id uuid.UUID, status string) error {
	query := "UPDATE work_schedules SET status = $1, updated_at = NOW() WHERE id = $2"
	result, err := r.db.Exec(query, status, id)
	if err != nil {
		return fmt.Errorf("failed to update status: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("schedule not found")
	}

	return nil
}

// SetActualStartTime sets the actual start time when worker begins scheduled session
func (r *scheduleRepository) SetActualStartTime(id uuid.UUID, startTime time.Time) error {
	query := `
		UPDATE work_schedules
		SET actual_start_time = $1, status = 'in_progress', updated_at = NOW()
		WHERE id = $2
	`
	result, err := r.db.Exec(query, startTime, id)
	if err != nil {
		return fmt.Errorf("failed to set actual start time: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("schedule not found")
	}

	return nil
}

// SetActualEndTime sets the actual end time when worker completes scheduled session
func (r *scheduleRepository) SetActualEndTime(id uuid.UUID, endTime time.Time) error {
	query := `
		UPDATE work_schedules
		SET actual_end_time = $1, status = 'completed', updated_at = NOW()
		WHERE id = $2
	`
	result, err := r.db.Exec(query, endTime, id)
	if err != nil {
		return fmt.Errorf("failed to set actual end time: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("schedule not found")
	}

	return nil
}

// MarkMissedSchedules marks past schedules without actual start time as missed
func (r *scheduleRepository) MarkMissedSchedules() (int, error) {
	query := `
		UPDATE work_schedules
		SET status = 'missed', updated_at = NOW()
		WHERE status = 'scheduled'
		AND scheduled_date < CURRENT_DATE
		AND actual_start_time IS NULL
	`

	result, err := r.db.Exec(query)
	if err != nil {
		return 0, fmt.Errorf("failed to mark missed schedules: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return 0, err
	}

	return int(rowsAffected), nil
}

// scanSchedules helper to scan multiple schedule rows
func (r *scheduleRepository) scanSchedules(rows *sql.Rows) ([]*domain.WorkSchedule, error) {
	var schedules []*domain.WorkSchedule

	for rows.Next() {
		var s domain.WorkSchedule
		err := rows.Scan(
			&s.ID, &s.TeamID, &s.WorkerID, &s.WorkerName, &s.TerritoryID, &s.TerritoryName,
			&s.ScheduledDate, &s.StartTime, &s.EndTime, &s.Status, &s.Notes,
			&s.ActualStartTime, &s.ActualEndTime, &s.CreatedBy, &s.CreatedAt, &s.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan schedule: %w", err)
		}
		schedules = append(schedules, &s)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating schedules: %w", err)
	}

	return schedules, nil
}

// joinStrings joins strings with a separator
func joinStrings(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += sep + strs[i]
	}
	return result
}
