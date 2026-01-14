package postgres

import (
	"database/sql"
	"fmt"
	"math"
	"time"

	"rally-point/delivery-service/internal/domain"

	"github.com/google/uuid"
)

type PrayerRequestRepository struct {
	db *sql.DB
}

func NewPrayerRequestRepository(db *sql.DB) *PrayerRequestRepository {
	return &PrayerRequestRepository{db: db}
}

func (r *PrayerRequestRepository) Create(request *domain.PrayerRequest) error {
	query := `
		INSERT INTO prayer_requests (
			id, worker_id, team_id, territory_id,
			requester_name, requester_phone, requester_email, requester_address,
			latitude, longitude,
			prayer_subject, prayer_details, prayer_category,
			request_type, preferred_visit_date, preferred_visit_time,
			status, urgency, notes
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
		) RETURNING created_at, updated_at`

	return r.db.QueryRow(
		query,
		request.ID, request.WorkerID, request.TeamID, request.TerritoryID,
		request.RequesterName, request.RequesterPhone, request.RequesterEmail, request.RequesterAddress,
		request.Latitude, request.Longitude,
		request.PrayerSubject, request.PrayerDetails, request.PrayerCategory,
		request.RequestType, request.PreferredVisitDate, request.PreferredVisitTime,
		request.Status, request.Urgency, request.Notes,
	).Scan(&request.CreatedAt, &request.UpdatedAt)
}

func (r *PrayerRequestRepository) GetByID(id uuid.UUID) (*domain.PrayerRequest, error) {
	query := `
		SELECT
			pr.id, pr.worker_id, pr.team_id, pr.territory_id,
			pr.requester_name, pr.requester_phone, pr.requester_email, pr.requester_address,
			pr.latitude, pr.longitude,
			pr.prayer_subject, pr.prayer_details, pr.prayer_category,
			pr.request_type, pr.preacher_id, pr.preferred_visit_date, pr.preferred_visit_time,
			pr.status, pr.urgency,
			pr.scheduled_at, pr.completed_at, pr.completed_by, pr.completion_notes,
			pr.notes, pr.created_at, pr.updated_at,
			COALESCE(u.display_name, '') as worker_name,
			COALESCE(p.display_name, '') as preacher_name
		FROM prayer_requests pr
		LEFT JOIN users u ON pr.worker_id = u.id
		LEFT JOIN users p ON pr.preacher_id = p.id
		WHERE pr.id = $1`

	var request domain.PrayerRequest
	err := r.db.QueryRow(query, id).Scan(
		&request.ID, &request.WorkerID, &request.TeamID, &request.TerritoryID,
		&request.RequesterName, &request.RequesterPhone, &request.RequesterEmail, &request.RequesterAddress,
		&request.Latitude, &request.Longitude,
		&request.PrayerSubject, &request.PrayerDetails, &request.PrayerCategory,
		&request.RequestType, &request.PreacherID, &request.PreferredVisitDate, &request.PreferredVisitTime,
		&request.Status, &request.Urgency,
		&request.ScheduledAt, &request.CompletedAt, &request.CompletedBy, &request.CompletionNotes,
		&request.Notes, &request.CreatedAt, &request.UpdatedAt,
		&request.WorkerName, &request.PreacherName,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("prayer request not found")
		}
		return nil, err
	}
	return &request, nil
}

func (r *PrayerRequestRepository) Update(request *domain.PrayerRequest) error {
	query := `
		UPDATE prayer_requests SET
			requester_name = $2,
			requester_phone = $3,
			requester_email = $4,
			requester_address = $5,
			latitude = $6,
			longitude = $7,
			prayer_subject = $8,
			prayer_details = $9,
			prayer_category = $10,
			request_type = $11,
			preferred_visit_date = $12,
			preferred_visit_time = $13,
			urgency = $14,
			notes = $15,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = $1
		RETURNING updated_at`

	return r.db.QueryRow(
		query,
		request.ID, request.RequesterName, request.RequesterPhone, request.RequesterEmail,
		request.RequesterAddress, request.Latitude, request.Longitude,
		request.PrayerSubject, request.PrayerDetails, request.PrayerCategory,
		request.RequestType, request.PreferredVisitDate, request.PreferredVisitTime,
		request.Urgency, request.Notes,
	).Scan(&request.UpdatedAt)
}

func (r *PrayerRequestRepository) Delete(id uuid.UUID) error {
	result, err := r.db.Exec("DELETE FROM prayer_requests WHERE id = $1", id)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return fmt.Errorf("prayer request not found")
	}
	return nil
}

func (r *PrayerRequestRepository) List(filter *domain.PrayerRequestFilter, page, pageSize int) ([]domain.PrayerRequest, int64, error) {
	baseQuery := `
		FROM prayer_requests pr
		LEFT JOIN users u ON pr.worker_id = u.id
		LEFT JOIN users p ON pr.preacher_id = p.id
		WHERE 1=1`

	args := []interface{}{}
	argCount := 0

	if filter != nil {
		if filter.WorkerID != nil {
			argCount++
			baseQuery += fmt.Sprintf(" AND pr.worker_id = $%d", argCount)
			args = append(args, *filter.WorkerID)
		}
		if filter.TeamID != nil {
			argCount++
			baseQuery += fmt.Sprintf(" AND pr.team_id = $%d", argCount)
			args = append(args, *filter.TeamID)
		}
		if filter.TerritoryID != nil {
			argCount++
			baseQuery += fmt.Sprintf(" AND pr.territory_id = $%d", argCount)
			args = append(args, *filter.TerritoryID)
		}
		if filter.Status != nil {
			argCount++
			baseQuery += fmt.Sprintf(" AND pr.status = $%d", argCount)
			args = append(args, *filter.Status)
		}
		if filter.RequestType != nil {
			argCount++
			baseQuery += fmt.Sprintf(" AND pr.request_type = $%d", argCount)
			args = append(args, *filter.RequestType)
		}
		if filter.Category != nil {
			argCount++
			baseQuery += fmt.Sprintf(" AND pr.prayer_category = $%d", argCount)
			args = append(args, *filter.Category)
		}
		if filter.Urgency != nil {
			argCount++
			baseQuery += fmt.Sprintf(" AND pr.urgency = $%d", argCount)
			args = append(args, *filter.Urgency)
		}
	}

	// Count total
	var total int64
	countQuery := "SELECT COUNT(*) " + baseQuery
	err := r.db.QueryRow(countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	// Get paginated results
	offset := (page - 1) * pageSize
	selectQuery := fmt.Sprintf(`
		SELECT
			pr.id, pr.worker_id, pr.team_id, pr.territory_id,
			pr.requester_name, pr.requester_phone, pr.requester_email, pr.requester_address,
			pr.latitude, pr.longitude,
			pr.prayer_subject, pr.prayer_details, pr.prayer_category,
			pr.request_type, pr.preacher_id, pr.preferred_visit_date, pr.preferred_visit_time,
			pr.status, pr.urgency,
			pr.scheduled_at, pr.completed_at, pr.completed_by, pr.completion_notes,
			pr.notes, pr.created_at, pr.updated_at,
			COALESCE(u.display_name, '') as worker_name,
			COALESCE(p.display_name, '') as preacher_name
		%s
		ORDER BY pr.created_at DESC
		LIMIT $%d OFFSET $%d`,
		baseQuery, argCount+1, argCount+2)

	args = append(args, pageSize, offset)

	rows, err := r.db.Query(selectQuery, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var requests []domain.PrayerRequest
	for rows.Next() {
		var req domain.PrayerRequest
		err := rows.Scan(
			&req.ID, &req.WorkerID, &req.TeamID, &req.TerritoryID,
			&req.RequesterName, &req.RequesterPhone, &req.RequesterEmail, &req.RequesterAddress,
			&req.Latitude, &req.Longitude,
			&req.PrayerSubject, &req.PrayerDetails, &req.PrayerCategory,
			&req.RequestType, &req.PreacherID, &req.PreferredVisitDate, &req.PreferredVisitTime,
			&req.Status, &req.Urgency,
			&req.ScheduledAt, &req.CompletedAt, &req.CompletedBy, &req.CompletionNotes,
			&req.Notes, &req.CreatedAt, &req.UpdatedAt,
			&req.WorkerName, &req.PreacherName,
		)
		if err != nil {
			return nil, 0, err
		}
		requests = append(requests, req)
	}

	return requests, total, nil
}

func (r *PrayerRequestRepository) GetMapMarkers(filter *domain.PrayerRequestFilter) ([]domain.PrayerRequestMapMarker, error) {
	query := `
		SELECT
			id, latitude, longitude, requester_name, prayer_subject,
			prayer_category, request_type, status, urgency, created_at
		FROM prayer_requests
		WHERE latitude IS NOT NULL AND longitude IS NOT NULL`

	args := []interface{}{}
	argCount := 0

	if filter != nil {
		if filter.TeamID != nil {
			argCount++
			query += fmt.Sprintf(" AND team_id = $%d", argCount)
			args = append(args, *filter.TeamID)
		}
		if filter.TerritoryID != nil {
			argCount++
			query += fmt.Sprintf(" AND territory_id = $%d", argCount)
			args = append(args, *filter.TerritoryID)
		}
		if filter.Status != nil {
			argCount++
			query += fmt.Sprintf(" AND status = $%d", argCount)
			args = append(args, *filter.Status)
		}
		if filter.RequestType != nil {
			argCount++
			query += fmt.Sprintf(" AND request_type = $%d", argCount)
			args = append(args, *filter.RequestType)
		}
	}

	query += " ORDER BY created_at DESC LIMIT 1000"

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var markers []domain.PrayerRequestMapMarker
	for rows.Next() {
		var m domain.PrayerRequestMapMarker
		var lat, lng sql.NullFloat64
		err := rows.Scan(&m.ID, &lat, &lng, &m.RequesterName, &m.PrayerSubject,
			&m.PrayerCategory, &m.RequestType, &m.Status, &m.Urgency, &m.CreatedAt)
		if err != nil {
			return nil, err
		}
		if lat.Valid && lng.Valid {
			m.Latitude = lat.Float64
			m.Longitude = lng.Float64
			markers = append(markers, m)
		}
	}

	return markers, nil
}

func (r *PrayerRequestRepository) GetByWorker(workerID uuid.UUID, page, pageSize int) ([]domain.PrayerRequest, int64, error) {
	filter := &domain.PrayerRequestFilter{WorkerID: &workerID}
	return r.List(filter, page, pageSize)
}

func (r *PrayerRequestRepository) GetByTeam(teamID uuid.UUID, page, pageSize int) ([]domain.PrayerRequest, int64, error) {
	filter := &domain.PrayerRequestFilter{TeamID: &teamID}
	return r.List(filter, page, pageSize)
}

func (r *PrayerRequestRepository) GetByTerritory(territoryID uuid.UUID, page, pageSize int) ([]domain.PrayerRequest, int64, error) {
	filter := &domain.PrayerRequestFilter{TerritoryID: &territoryID}
	return r.List(filter, page, pageSize)
}

func (r *PrayerRequestRepository) GetStats(filter *domain.PrayerRequestFilter) (*domain.PrayerRequestStats, error) {
	stats := &domain.PrayerRequestStats{
		ByCategory: make(map[string]int64),
		ByUrgency:  make(map[string]int64),
	}

	baseWhere := "WHERE 1=1"
	args := []interface{}{}
	argCount := 0

	if filter != nil {
		if filter.TeamID != nil {
			argCount++
			baseWhere += fmt.Sprintf(" AND team_id = $%d", argCount)
			args = append(args, *filter.TeamID)
		}
		if filter.TerritoryID != nil {
			argCount++
			baseWhere += fmt.Sprintf(" AND territory_id = $%d", argCount)
			args = append(args, *filter.TerritoryID)
		}
	}

	// Total requests
	err := r.db.QueryRow("SELECT COUNT(*) FROM prayer_requests "+baseWhere, args...).Scan(&stats.TotalRequests)
	if err != nil {
		return nil, err
	}

	// Pending requests
	pendingArgs := append([]interface{}{}, args...)
	pendingArgs = append(pendingArgs, domain.PrayerStatusPending)
	err = r.db.QueryRow(
		fmt.Sprintf("SELECT COUNT(*) FROM prayer_requests %s AND status = $%d", baseWhere, argCount+1),
		pendingArgs...).Scan(&stats.PendingRequests)
	if err != nil {
		return nil, err
	}

	// Completed requests
	completedArgs := append([]interface{}{}, args...)
	completedArgs = append(completedArgs, domain.PrayerStatusCompleted)
	err = r.db.QueryRow(
		fmt.Sprintf("SELECT COUNT(*) FROM prayer_requests %s AND status = $%d", baseWhere, argCount+1),
		completedArgs...).Scan(&stats.CompletedRequests)
	if err != nil {
		return nil, err
	}

	// Home visit requests
	homeVisitArgs := append([]interface{}{}, args...)
	homeVisitArgs = append(homeVisitArgs, domain.PrayerTypeHomeVisit)
	err = r.db.QueryRow(
		fmt.Sprintf("SELECT COUNT(*) FROM prayer_requests %s AND request_type = $%d", baseWhere, argCount+1),
		homeVisitArgs...).Scan(&stats.HomeVisitRequests)
	if err != nil {
		return nil, err
	}

	// By category
	categoryQuery := fmt.Sprintf(`
		SELECT prayer_category, COUNT(*) as count
		FROM prayer_requests %s
		GROUP BY prayer_category`, baseWhere)
	rows, err := r.db.Query(categoryQuery, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var category string
		var count int64
		if err := rows.Scan(&category, &count); err != nil {
			return nil, err
		}
		stats.ByCategory[category] = count
	}

	// By urgency
	urgencyQuery := fmt.Sprintf(`
		SELECT urgency, COUNT(*) as count
		FROM prayer_requests %s
		GROUP BY urgency`, baseWhere)
	rows2, err := r.db.Query(urgencyQuery, args...)
	if err != nil {
		return nil, err
	}
	defer rows2.Close()

	for rows2.Next() {
		var urgency string
		var count int64
		if err := rows2.Scan(&urgency, &count); err != nil {
			return nil, err
		}
		stats.ByUrgency[urgency] = count
	}

	return stats, nil
}

func (r *PrayerRequestRepository) UpdateStatus(id uuid.UUID, status string, completedBy *uuid.UUID, notes *string) error {
	var completedAt *time.Time
	if status == domain.PrayerStatusCompleted {
		now := time.Now()
		completedAt = &now
	}

	query := `
		UPDATE prayer_requests SET
			status = $2,
			completed_at = $3,
			completed_by = $4,
			completion_notes = $5,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = $1`

	result, err := r.db.Exec(query, id, status, completedAt, completedBy, notes)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return fmt.Errorf("prayer request not found")
	}
	return nil
}

func (r *PrayerRequestRepository) AssignPreacher(id uuid.UUID, preacherID uuid.UUID, scheduledAt *time.Time, notes *string) error {
	query := `
		UPDATE prayer_requests SET
			preacher_id = $2,
			scheduled_at = $3,
			status = $4,
			notes = COALESCE($5, notes),
			updated_at = CURRENT_TIMESTAMP
		WHERE id = $1`

	result, err := r.db.Exec(query, id, preacherID, scheduledAt, domain.PrayerStatusScheduled, notes)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return fmt.Errorf("prayer request not found")
	}
	return nil
}

// Helper function to calculate total pages
func calculateTotalPages(total int64, pageSize int) int {
	return int(math.Ceil(float64(total) / float64(pageSize)))
}
