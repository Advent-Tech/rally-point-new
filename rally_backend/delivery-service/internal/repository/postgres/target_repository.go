package postgres

import (
	"context"
	"database/sql"
	"time"

	"rally-point/delivery-service/internal/domain"

	"github.com/google/uuid"
)

type TargetRepository struct {
	db *sql.DB
}

func NewTargetRepository(db *sql.DB) *TargetRepository {
	return &TargetRepository{db: db}
}

func (r *TargetRepository) CreateTarget(ctx context.Context, target *domain.Target) error {
	query := `
		INSERT INTO targets (id, name, description, target_type, target_unit, target_value, period_type, created_by, created_by_role, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	_, err := r.db.ExecContext(ctx, query,
		target.ID, target.Name, target.Description, target.TargetType, target.TargetUnit, target.TargetValue,
		target.PeriodType, target.CreatedBy, target.CreatedByRole, target.IsActive, target.CreatedAt, target.UpdatedAt,
	)
	return err
}

func (r *TargetRepository) GetTargetByID(ctx context.Context, id uuid.UUID) (*domain.Target, error) {
	query := `
		SELECT id, name, description, target_type, target_unit, target_value, period_type, created_by, created_by_role, is_active, created_at, updated_at
		FROM targets WHERE id = $1
	`
	target := &domain.Target{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&target.ID, &target.Name, &target.Description, &target.TargetType, &target.TargetUnit,
		&target.TargetValue, &target.PeriodType, &target.CreatedBy, &target.CreatedByRole,
		&target.IsActive, &target.CreatedAt, &target.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return target, err
}

func (r *TargetRepository) GetTargetsByCreator(ctx context.Context, creatorID uuid.UUID) ([]domain.Target, error) {
	query := `
		SELECT id, name, description, target_type, target_unit, target_value, period_type, created_by, created_by_role, is_active, created_at, updated_at
		FROM targets WHERE created_by = $1 ORDER BY created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, creatorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var targets []domain.Target
	for rows.Next() {
		var t domain.Target
		err := rows.Scan(
			&t.ID, &t.Name, &t.Description, &t.TargetType, &t.TargetUnit,
			&t.TargetValue, &t.PeriodType, &t.CreatedBy, &t.CreatedByRole,
			&t.IsActive, &t.CreatedAt, &t.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		targets = append(targets, t)
	}
	return targets, nil
}

func (r *TargetRepository) UpdateTarget(ctx context.Context, target *domain.Target) error {
	query := `
		UPDATE targets SET name = $1, description = $2, target_type = $3, target_unit = $4, 
		target_value = $5, period_type = $6, is_active = $7, updated_at = $8
		WHERE id = $9
	`
	_, err := r.db.ExecContext(ctx, query,
		target.Name, target.Description, target.TargetType, target.TargetUnit,
		target.TargetValue, target.PeriodType, target.IsActive, time.Now(), target.ID,
	)
	return err
}

func (r *TargetRepository) DeleteTarget(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM targets WHERE id = $1", id)
	return err
}

func (r *TargetRepository) CreateAssignment(ctx context.Context, assignment *domain.TargetAssignment) error {
	query := `
		INSERT INTO target_assignments (id, target_id, assigned_to_type, assigned_to_id, assigned_by, period_start, period_end, status, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT DO NOTHING
	`
	_, err := r.db.ExecContext(ctx, query,
		assignment.ID, assignment.TargetID, assignment.AssignedToType, assignment.AssignedToID,
		assignment.AssignedBy, assignment.PeriodStart, assignment.PeriodEnd, assignment.Status, assignment.CreatedAt,
	)
	return err
}

func (r *TargetRepository) GetWorkerTargetsWithProgress(ctx context.Context, workerID uuid.UUID) ([]domain.WorkerTarget, error) {
	query := `
		SELECT ta.id, ta.target_id, ta.assigned_to_type, ta.assigned_to_id, ta.assigned_by, ta.period_start, ta.period_end, ta.status, ta.created_at,
		       t.id, t.name, t.description, t.target_type, t.target_unit, t.target_value, t.period_type,
		       tp.id, tp.current_value, tp.last_updated, tp.period_start, tp.period_end
		FROM target_assignments ta
		JOIN targets t ON ta.target_id = t.id
		LEFT JOIN target_progress tp ON ta.id = tp.assignment_id
		WHERE ta.assigned_to_type = 'worker' AND ta.assigned_to_id = $1 AND ta.status = 'active'
		ORDER BY ta.created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, workerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []domain.WorkerTarget
	for rows.Next() {
		var wt domain.WorkerTarget
		var target domain.Target
		var progressID *uuid.UUID
		var currentValue sql.NullFloat64
		var progressLastUpdated sql.NullTime
		var progressPeriodStart, progressPeriodEnd *time.Time

		err := rows.Scan(
			&wt.Assignment.ID, &wt.Assignment.TargetID, &wt.Assignment.AssignedToType, &wt.Assignment.AssignedToID, &wt.Assignment.AssignedBy,
			&wt.Assignment.PeriodStart, &wt.Assignment.PeriodEnd, &wt.Assignment.Status, &wt.Assignment.CreatedAt,
			&target.ID, &target.Name, &target.Description, &target.TargetType, &target.TargetUnit, &target.TargetValue, &target.PeriodType,
			&progressID, &currentValue, &progressLastUpdated, &progressPeriodStart, &progressPeriodEnd,
		)
		if err != nil {
			return nil, err
		}
		wt.Assignment.Target = &target
		if progressID != nil {
			wt.Progress = domain.TargetProgress{
				ID:           *progressID,
				CurrentValue: currentValue.Float64,
				LastUpdated:  progressLastUpdated.Time,
				PeriodStart:  progressPeriodStart,
				PeriodEnd:    progressPeriodEnd,
			}
		}
		if target.TargetValue > 0 && currentValue.Valid && currentValue.Float64 > 0 {
			wt.Percentage = (currentValue.Float64 / target.TargetValue) * 100
		}
		wt.IsCompleted = wt.Percentage >= 100
		results = append(results, wt)
	}
	return results, nil
}

func (r *TargetRepository) GetTeamTargetsWithProgress(ctx context.Context, teamID uuid.UUID) ([]domain.WorkerTarget, error) {
	query := `
		SELECT ta.id, ta.target_id, ta.assigned_to_type, ta.assigned_to_id, ta.assigned_by, ta.period_start, ta.period_end, ta.status, ta.created_at,
		       t.id, t.name, t.description, t.target_type, t.target_unit, t.target_value, t.period_type,
		       tp.id, tp.current_value, tp.last_updated, tp.period_start, tp.period_end
		FROM target_assignments ta
		JOIN targets t ON ta.target_id = t.id
		LEFT JOIN target_progress tp ON ta.id = tp.assignment_id
		WHERE ta.assigned_to_type = 'team' AND ta.assigned_to_id = $1 AND ta.status = 'active'
		ORDER BY ta.created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, teamID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []domain.WorkerTarget
	for rows.Next() {
		var wt domain.WorkerTarget
		var target domain.Target
		var progressID *uuid.UUID
		var currentValue sql.NullFloat64
		var progressLastUpdated sql.NullTime
		var progressPeriodStart, progressPeriodEnd *time.Time

		err := rows.Scan(
			&wt.Assignment.ID, &wt.Assignment.TargetID, &wt.Assignment.AssignedToType, &wt.Assignment.AssignedToID, &wt.Assignment.AssignedBy,
			&wt.Assignment.PeriodStart, &wt.Assignment.PeriodEnd, &wt.Assignment.Status, &wt.Assignment.CreatedAt,
			&target.ID, &target.Name, &target.Description, &target.TargetType, &target.TargetUnit, &target.TargetValue, &target.PeriodType,
			&progressID, &currentValue, &progressLastUpdated, &progressPeriodStart, &progressPeriodEnd,
		)
		if err != nil {
			return nil, err
		}
		wt.Assignment.Target = &target
		if progressID != nil {
			wt.Progress = domain.TargetProgress{
				ID:           *progressID,
				CurrentValue: currentValue.Float64,
				LastUpdated:  progressLastUpdated.Time,
				PeriodStart:  progressPeriodStart,
				PeriodEnd:    progressPeriodEnd,
			}
		}
		if target.TargetValue > 0 && currentValue.Valid && currentValue.Float64 > 0 {
			wt.Percentage = (currentValue.Float64 / target.TargetValue) * 100
		}
		wt.IsCompleted = wt.Percentage >= 100
		results = append(results, wt)
	}
	return results, nil
}

func (r *TargetRepository) UpsertProgress(ctx context.Context, progress *domain.TargetProgress) error {
	query := `
		INSERT INTO target_progress (id, assignment_id, current_value, last_updated, period_start, period_end)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (assignment_id, COALESCE(period_start, '1970-01-01')) DO UPDATE SET current_value = $3, last_updated = $4
	`
	_, err := r.db.ExecContext(ctx, query,
		progress.ID, progress.AssignmentID, progress.CurrentValue, progress.LastUpdated, progress.PeriodStart, progress.PeriodEnd,
	)
	return err
}

func (r *TargetRepository) DeleteAssignment(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM target_assignments WHERE id = $1", id)
	return err
}

func (r *TargetRepository) GetActiveAssignmentsForWorker(ctx context.Context, workerID uuid.UUID, targetType string) ([]domain.TargetAssignment, error) {
	query := `
		SELECT ta.id, ta.target_id, ta.assigned_to_type, ta.assigned_to_id, ta.assigned_by, ta.period_start, ta.period_end, ta.status, ta.created_at,
		       t.id, t.name, t.description, t.target_type, t.target_unit, t.target_value, t.period_type
		FROM target_assignments ta
		JOIN targets t ON ta.target_id = t.id
		WHERE ta.assigned_to_type = 'worker' AND ta.assigned_to_id = $1 AND ta.status = 'active' AND t.target_type = $2
	`
	rows, err := r.db.QueryContext(ctx, query, workerID, targetType)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assignments []domain.TargetAssignment
	for rows.Next() {
		var a domain.TargetAssignment
		var t domain.Target
		err := rows.Scan(
			&a.ID, &a.TargetID, &a.AssignedToType, &a.AssignedToID, &a.AssignedBy,
			&a.PeriodStart, &a.PeriodEnd, &a.Status, &a.CreatedAt,
			&t.ID, &t.Name, &t.Description, &t.TargetType, &t.TargetUnit, &t.TargetValue, &t.PeriodType,
		)
		if err != nil {
			return nil, err
		}
		a.Target = &t
		assignments = append(assignments, a)
	}
	return assignments, nil
}
