package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/delivery-service/internal/domain"
)

type deliveryRepository struct {
	db *sql.DB
}

func NewDeliveryRepository(db *sql.DB) domain.DeliveryRepository {
	return &deliveryRepository{db: db}
}

func (r *deliveryRepository) CreateDelivery(delivery *domain.Delivery) error {
	query := `INSERT INTO deliveries (id, team_id, worker_id, worker_name, recipient_name, recipient_phone, recipient_email,
		address, latitude, longitude, delivery_type, priority, status, notes, scheduled_date, completed_at,
		territory_id, territory_name, household_id, donation_amount, payment_method, payment_status,
		stripe_payment_id, receipt_number, receipt_url, is_offline, synced_at, offline_id,
		created_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31)`

	_, err := r.db.Exec(query, delivery.ID, delivery.TeamID, delivery.WorkerID, delivery.WorkerName,
		delivery.RecipientName, delivery.RecipientPhone, delivery.RecipientEmail, delivery.Address,
		delivery.Latitude, delivery.Longitude, delivery.DeliveryType, delivery.Priority, delivery.Status,
		delivery.Notes, delivery.ScheduledDate, delivery.CompletedAt,
		delivery.TerritoryID, delivery.TerritoryName, delivery.HouseholdID,
		delivery.DonationAmount, delivery.PaymentMethod, delivery.PaymentStatus,
		delivery.StripePaymentID, delivery.ReceiptNumber, delivery.ReceiptURL,
		delivery.IsOffline, delivery.SyncedAt, delivery.OfflineID,
		delivery.CreatedBy, delivery.CreatedAt, delivery.UpdatedAt)
	return err
}

func (r *deliveryRepository) GetDeliveryByID(id uuid.UUID) (*domain.Delivery, error) {
	query := `SELECT id, team_id, worker_id, worker_name, recipient_name, recipient_phone, recipient_email,
		address, latitude, longitude, delivery_type, priority, status, notes, scheduled_date, completed_at,
		territory_id, territory_name, household_id, donation_amount, payment_method, payment_status,
		stripe_payment_id, receipt_number, receipt_url, is_offline, synced_at, offline_id,
		created_by, created_at, updated_at
		FROM deliveries WHERE id = $1`

	delivery := &domain.Delivery{}
	err := r.db.QueryRow(query, id).Scan(&delivery.ID, &delivery.TeamID, &delivery.WorkerID, &delivery.WorkerName,
		&delivery.RecipientName, &delivery.RecipientPhone, &delivery.RecipientEmail, &delivery.Address,
		&delivery.Latitude, &delivery.Longitude, &delivery.DeliveryType, &delivery.Priority, &delivery.Status,
		&delivery.Notes, &delivery.ScheduledDate, &delivery.CompletedAt,
		&delivery.TerritoryID, &delivery.TerritoryName, &delivery.HouseholdID,
		&delivery.DonationAmount, &delivery.PaymentMethod, &delivery.PaymentStatus,
		&delivery.StripePaymentID, &delivery.ReceiptNumber, &delivery.ReceiptURL,
		&delivery.IsOffline, &delivery.SyncedAt, &delivery.OfflineID,
		&delivery.CreatedBy, &delivery.CreatedAt, &delivery.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("delivery not found")
	}
	return delivery, err
}

func (r *deliveryRepository) GetDeliveriesByTeamID(teamID uuid.UUID, limit, offset int) ([]*domain.Delivery, error) {
	query := `SELECT id, team_id, worker_id, worker_name, recipient_name, recipient_phone, recipient_email,
		address, latitude, longitude, delivery_type, priority, status, notes, scheduled_date, completed_at,
		territory_id, territory_name, household_id, donation_amount, payment_method, payment_status,
		stripe_payment_id, receipt_number, receipt_url, is_offline, synced_at, offline_id,
		created_by, created_at, updated_at
		FROM deliveries WHERE team_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`

	return r.scanDeliveries(r.db.Query(query, teamID, limit, offset))
}

func (r *deliveryRepository) GetDeliveriesByWorkerID(workerID uuid.UUID, limit, offset int) ([]*domain.Delivery, error) {
	query := `SELECT id, team_id, worker_id, worker_name, recipient_name, recipient_phone, recipient_email,
		address, latitude, longitude, delivery_type, priority, status, notes, scheduled_date, completed_at,
		territory_id, territory_name, household_id, donation_amount, payment_method, payment_status,
		stripe_payment_id, receipt_number, receipt_url, is_offline, synced_at, offline_id,
		created_by, created_at, updated_at
		FROM deliveries WHERE worker_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`

	return r.scanDeliveries(r.db.Query(query, workerID, limit, offset))
}

func (r *deliveryRepository) GetDeliveriesByStatus(teamID uuid.UUID, status string, limit, offset int) ([]*domain.Delivery, error) {
	query := `SELECT id, team_id, worker_id, worker_name, recipient_name, recipient_phone, recipient_email,
		address, latitude, longitude, delivery_type, priority, status, notes, scheduled_date, completed_at,
		territory_id, territory_name, household_id, donation_amount, payment_method, payment_status,
		stripe_payment_id, receipt_number, receipt_url, is_offline, synced_at, offline_id,
		created_by, created_at, updated_at
		FROM deliveries WHERE team_id = $1 AND status = $2 ORDER BY created_at DESC LIMIT $3 OFFSET $4`

	return r.scanDeliveries(r.db.Query(query, teamID, status, limit, offset))
}

func (r *deliveryRepository) scanDeliveries(rows *sql.Rows, err error) ([]*domain.Delivery, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var deliveries []*domain.Delivery
	for rows.Next() {
		delivery := &domain.Delivery{}
		err := rows.Scan(&delivery.ID, &delivery.TeamID, &delivery.WorkerID, &delivery.WorkerName,
			&delivery.RecipientName, &delivery.RecipientPhone, &delivery.RecipientEmail, &delivery.Address,
			&delivery.Latitude, &delivery.Longitude, &delivery.DeliveryType, &delivery.Priority, &delivery.Status,
			&delivery.Notes, &delivery.ScheduledDate, &delivery.CompletedAt,
			&delivery.TerritoryID, &delivery.TerritoryName, &delivery.HouseholdID,
			&delivery.DonationAmount, &delivery.PaymentMethod, &delivery.PaymentStatus,
			&delivery.StripePaymentID, &delivery.ReceiptNumber, &delivery.ReceiptURL,
			&delivery.IsOffline, &delivery.SyncedAt, &delivery.OfflineID,
			&delivery.CreatedBy, &delivery.CreatedAt, &delivery.UpdatedAt)
		if err != nil {
			return nil, err
		}
		deliveries = append(deliveries, delivery)
	}
	return deliveries, nil
}

func (r *deliveryRepository) UpdateDelivery(delivery *domain.Delivery) error {
	query := `UPDATE deliveries SET worker_id = $2, worker_name = $3, recipient_name = $4, recipient_phone = $5,
		recipient_email = $6, address = $7, latitude = $8, longitude = $9, delivery_type = $10, priority = $11,
		status = $12, notes = $13, scheduled_date = $14, completed_at = $15,
		territory_id = $16, territory_name = $17, household_id = $18,
		donation_amount = $19, payment_method = $20, payment_status = $21,
		stripe_payment_id = $22, receipt_number = $23, receipt_url = $24,
		is_offline = $25, synced_at = $26, offline_id = $27, updated_at = $28 WHERE id = $1`

	delivery.UpdatedAt = time.Now()
	_, err := r.db.Exec(query, delivery.ID, delivery.WorkerID, delivery.WorkerName, delivery.RecipientName,
		delivery.RecipientPhone, delivery.RecipientEmail, delivery.Address, delivery.Latitude, delivery.Longitude,
		delivery.DeliveryType, delivery.Priority, delivery.Status, delivery.Notes,
		delivery.ScheduledDate, delivery.CompletedAt,
		delivery.TerritoryID, delivery.TerritoryName, delivery.HouseholdID,
		delivery.DonationAmount, delivery.PaymentMethod, delivery.PaymentStatus,
		delivery.StripePaymentID, delivery.ReceiptNumber, delivery.ReceiptURL,
		delivery.IsOffline, delivery.SyncedAt, delivery.OfflineID, delivery.UpdatedAt)
	return err
}

func (r *deliveryRepository) DeleteDelivery(id uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM deliveries WHERE id = $1`, id)
	return err
}

// Simplified implementations for remaining methods
func (r *deliveryRepository) CreateDeliveryItem(item *domain.DeliveryItem) error {
	query := `INSERT INTO delivery_items (id, delivery_id, item_type, item_name, quantity, description, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`
	_, err := r.db.Exec(query, item.ID, item.DeliveryID, item.ItemType, item.ItemName, item.Quantity, item.Description, item.CreatedAt)
	return err
}

func (r *deliveryRepository) GetItemsByDeliveryID(deliveryID uuid.UUID) ([]*domain.DeliveryItem, error) {
	query := `SELECT id, delivery_id, item_type, item_name, quantity, description, created_at FROM delivery_items WHERE delivery_id = $1 ORDER BY created_at`
	rows, err := r.db.Query(query, deliveryID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*domain.DeliveryItem
	for rows.Next() {
		item := &domain.DeliveryItem{}
		err := rows.Scan(&item.ID, &item.DeliveryID, &item.ItemType, &item.ItemName, &item.Quantity, &item.Description, &item.CreatedAt)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, nil
}

func (r *deliveryRepository) UpdateDeliveryItem(item *domain.DeliveryItem) error {
	_, err := r.db.Exec(`UPDATE delivery_items SET item_type = $2, item_name = $3, quantity = $4, description = $5 WHERE id = $1`,
		item.ID, item.ItemType, item.ItemName, item.Quantity, item.Description)
	return err
}

func (r *deliveryRepository) DeleteDeliveryItem(id uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM delivery_items WHERE id = $1`, id)
	return err
}

func (r *deliveryRepository) CreateDeliveryUpdate(update *domain.DeliveryUpdate) error {
	query := `INSERT INTO delivery_updates (id, delivery_id, user_id, user_name, status, message, latitude, longitude, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`
	_, err := r.db.Exec(query, update.ID, update.DeliveryID, update.UserID, update.UserName,
		update.Status, update.Message, update.Latitude, update.Longitude, update.CreatedAt)
	return err
}

func (r *deliveryRepository) GetUpdatesByDeliveryID(deliveryID uuid.UUID) ([]*domain.DeliveryUpdate, error) {
	query := `SELECT id, delivery_id, user_id, user_name, status, message, latitude, longitude, created_at
		FROM delivery_updates WHERE delivery_id = $1 ORDER BY created_at DESC`
	rows, err := r.db.Query(query, deliveryID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var updates []*domain.DeliveryUpdate
	for rows.Next() {
		update := &domain.DeliveryUpdate{}
		err := rows.Scan(&update.ID, &update.DeliveryID, &update.UserID, &update.UserName,
			&update.Status, &update.Message, &update.Latitude, &update.Longitude, &update.CreatedAt)
		if err != nil {
			return nil, err
		}
		updates = append(updates, update)
	}
	return updates, nil
}

// Route methods - simplified
func (r *deliveryRepository) CreateRoute(route *domain.DeliveryRoute) error {
	query := `INSERT INTO delivery_routes (id, team_id, worker_id, worker_name, route_name, route_date, status,
		total_stops, completed_stops, estimated_time, actual_time, started_at, completed_at, created_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`
	_, err := r.db.Exec(query, route.ID, route.TeamID, route.WorkerID, route.WorkerName, route.RouteName,
		route.RouteDate, route.Status, route.TotalStops, route.CompletedStops, route.EstimatedTime,
		route.ActualTime, route.StartedAt, route.CompletedAt, route.CreatedBy, route.CreatedAt, route.UpdatedAt)
	return err
}

func (r *deliveryRepository) GetRouteByID(id uuid.UUID) (*domain.DeliveryRoute, error) {
	query := `SELECT id, team_id, worker_id, worker_name, route_name, route_date, status,
		total_stops, completed_stops, estimated_time, actual_time, started_at, completed_at, created_by, created_at, updated_at
		FROM delivery_routes WHERE id = $1`
	route := &domain.DeliveryRoute{}
	err := r.db.QueryRow(query, id).Scan(&route.ID, &route.TeamID, &route.WorkerID, &route.WorkerName,
		&route.RouteName, &route.RouteDate, &route.Status, &route.TotalStops, &route.CompletedStops,
		&route.EstimatedTime, &route.ActualTime, &route.StartedAt, &route.CompletedAt, &route.CreatedBy,
		&route.CreatedAt, &route.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("route not found")
	}
	return route, err
}

func (r *deliveryRepository) GetRoutesByTeamID(teamID uuid.UUID, limit, offset int) ([]*domain.DeliveryRoute, error) {
	query := `SELECT id, team_id, worker_id, worker_name, route_name, route_date, status,
		total_stops, completed_stops, estimated_time, actual_time, started_at, completed_at, created_by, created_at, updated_at
		FROM delivery_routes WHERE team_id = $1 ORDER BY route_date DESC LIMIT $2 OFFSET $3`
	return r.scanRoutes(r.db.Query(query, teamID, limit, offset))
}

func (r *deliveryRepository) GetRoutesByWorkerID(workerID uuid.UUID, limit, offset int) ([]*domain.DeliveryRoute, error) {
	query := `SELECT id, team_id, worker_id, worker_name, route_name, route_date, status,
		total_stops, completed_stops, estimated_time, actual_time, started_at, completed_at, created_by, created_at, updated_at
		FROM delivery_routes WHERE worker_id = $1 ORDER BY route_date DESC LIMIT $2 OFFSET $3`
	return r.scanRoutes(r.db.Query(query, workerID, limit, offset))
}

func (r *deliveryRepository) scanRoutes(rows *sql.Rows, err error) ([]*domain.DeliveryRoute, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var routes []*domain.DeliveryRoute
	for rows.Next() {
		route := &domain.DeliveryRoute{}
		err := rows.Scan(&route.ID, &route.TeamID, &route.WorkerID, &route.WorkerName,
			&route.RouteName, &route.RouteDate, &route.Status, &route.TotalStops, &route.CompletedStops,
			&route.EstimatedTime, &route.ActualTime, &route.StartedAt, &route.CompletedAt, &route.CreatedBy,
			&route.CreatedAt, &route.UpdatedAt)
		if err != nil {
			return nil, err
		}
		routes = append(routes, route)
	}
	return routes, nil
}

func (r *deliveryRepository) UpdateRoute(route *domain.DeliveryRoute) error {
	route.UpdatedAt = time.Now()
	_, err := r.db.Exec(`UPDATE delivery_routes SET status = $2, completed_stops = $3, actual_time = $4, started_at = $5, completed_at = $6, updated_at = $7 WHERE id = $1`,
		route.ID, route.Status, route.CompletedStops, route.ActualTime, route.StartedAt, route.CompletedAt, route.UpdatedAt)
	return err
}

func (r *deliveryRepository) DeleteRoute(id uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM delivery_routes WHERE id = $1`, id)
	return err
}

func (r *deliveryRepository) CreateRouteStop(stop *domain.RouteStop) error {
	_, err := r.db.Exec(`INSERT INTO route_stops (id, route_id, delivery_id, stop_order, status, arrived_at, completed_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		stop.ID, stop.RouteID, stop.DeliveryID, stop.StopOrder, stop.Status, stop.ArrivedAt, stop.CompletedAt, stop.CreatedAt)
	return err
}

func (r *deliveryRepository) GetStopsByRouteID(routeID uuid.UUID) ([]*domain.RouteStop, error) {
	rows, err := r.db.Query(`SELECT id, route_id, delivery_id, stop_order, status, arrived_at, completed_at, created_at
		FROM route_stops WHERE route_id = $1 ORDER BY stop_order`, routeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stops []*domain.RouteStop
	for rows.Next() {
		stop := &domain.RouteStop{}
		err := rows.Scan(&stop.ID, &stop.RouteID, &stop.DeliveryID, &stop.StopOrder,
			&stop.Status, &stop.ArrivedAt, &stop.CompletedAt, &stop.CreatedAt)
		if err != nil {
			return nil, err
		}
		stops = append(stops, stop)
	}
	return stops, nil
}

func (r *deliveryRepository) UpdateRouteStop(stop *domain.RouteStop) error {
	_, err := r.db.Exec(`UPDATE route_stops SET status = $2, arrived_at = $3, completed_at = $4 WHERE id = $1`,
		stop.ID, stop.Status, stop.ArrivedAt, stop.CompletedAt)
	return err
}

// GetAllDonationDeliveries returns all deliveries with delivery_type='donation'
func (r *deliveryRepository) GetAllDonationDeliveries(limit, offset int) ([]*domain.Delivery, error) {
	query := `SELECT id, team_id, worker_id, worker_name, recipient_name, recipient_phone, recipient_email,
		address, latitude, longitude, delivery_type, priority, status, notes, scheduled_date, completed_at,
		territory_id, territory_name, household_id, donation_amount, payment_method, payment_status,
		stripe_payment_id, receipt_number, receipt_url, is_offline, synced_at, offline_id,
		created_by, created_at, updated_at
		FROM deliveries WHERE delivery_type = 'donation' ORDER BY created_at DESC LIMIT $1 OFFSET $2`

	return r.scanDeliveries(r.db.Query(query, limit, offset))
}

// GetTeamDonationDeliveries returns team-specific deliveries with delivery_type='donation'
func (r *deliveryRepository) GetTeamDonationDeliveries(teamID uuid.UUID, limit, offset int) ([]*domain.Delivery, error) {
	query := `SELECT id, team_id, worker_id, worker_name, recipient_name, recipient_phone, recipient_email,
		address, latitude, longitude, delivery_type, priority, status, notes, scheduled_date, completed_at,
		territory_id, territory_name, household_id, donation_amount, payment_method, payment_status,
		stripe_payment_id, receipt_number, receipt_url, is_offline, synced_at, offline_id,
		created_by, created_at, updated_at
		FROM deliveries WHERE delivery_type = 'donation' AND team_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`

	return r.scanDeliveries(r.db.Query(query, teamID, limit, offset))
}

// GetGlobalDonationDeliveryStats returns aggregated donation stats from deliveries table
func (r *deliveryRepository) GetGlobalDonationDeliveryStats(days int) (*domain.DonationDeliveryStats, error) {
	// days <= 0 means all-time
	dateFilter := ""
	if days > 0 {
		dateFilter = fmt.Sprintf("AND created_at >= NOW() - INTERVAL '%d days'", days)
	}

	query := fmt.Sprintf(`SELECT
		COUNT(*) as total_donations,
		COALESCE(SUM(donation_amount), 0) as total_amount,
		COALESCE(AVG(donation_amount), 0) as average_donation,
		COALESCE(MAX(donation_amount), 0) as largest_donation,
		COALESCE(SUM(CASE WHEN payment_method != 'cash' AND (payment_status IS NULL OR payment_status = 'pending') THEN donation_amount ELSE 0 END), 0) as pending_deposit
		FROM deliveries
		WHERE delivery_type = 'donation'
		AND donation_amount IS NOT NULL
		AND donation_amount > 0
		%s`, dateFilter)

	stats := &domain.DonationDeliveryStats{}
	err := r.db.QueryRow(query).Scan(
		&stats.TotalDonations,
		&stats.TotalAmount,
		&stats.AverageDonation,
		&stats.LargestDonation,
		&stats.PendingDeposit,
	)
	if err != nil {
		return nil, err
	}

	stats.OneTimeDonations = stats.TotalDonations
	stats.OneTimeAmount = stats.TotalAmount

	return stats, nil
}

// GetTeamDonationDeliveryStats returns team-specific donation stats from deliveries table
func (r *deliveryRepository) GetTeamDonationDeliveryStats(teamID uuid.UUID, days int) (*domain.DonationDeliveryStats, error) {
	dateFilter := ""
	if days > 0 {
		dateFilter = fmt.Sprintf("AND created_at >= NOW() - INTERVAL '%d days'", days)
	}

	query := fmt.Sprintf(`SELECT
		COUNT(*) as total_donations,
		COALESCE(SUM(donation_amount), 0) as total_amount,
		COALESCE(AVG(donation_amount), 0) as average_donation,
		COALESCE(MAX(donation_amount), 0) as largest_donation,
		COALESCE(SUM(CASE WHEN payment_method != 'cash' AND (payment_status IS NULL OR payment_status = 'pending') THEN donation_amount ELSE 0 END), 0) as pending_deposit
		FROM deliveries
		WHERE delivery_type = 'donation'
		AND team_id = $1
		AND donation_amount IS NOT NULL
		AND donation_amount > 0
		%s`, dateFilter)

	stats := &domain.DonationDeliveryStats{}
	err := r.db.QueryRow(query, teamID).Scan(
		&stats.TotalDonations,
		&stats.TotalAmount,
		&stats.AverageDonation,
		&stats.LargestDonation,
		&stats.PendingDeposit,
	)
	if err != nil {
		return nil, err
	}

	stats.OneTimeDonations = stats.TotalDonations
	stats.OneTimeAmount = stats.TotalAmount

	return stats, nil
}

// Stats methods - basic implementations
func (r *deliveryRepository) GetDeliveryStats(teamID uuid.UUID, days int) (*domain.DeliveryStats, error) {
	// Simplified statuses: pending, completed, failed, cancelled
	query := `SELECT COUNT(*) as total,
		COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
		COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
		COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed
		FROM deliveries WHERE team_id = $1 AND created_at >= NOW() - INTERVAL '%d days'`

	stats := &domain.DeliveryStats{}
	err := r.db.QueryRow(fmt.Sprintf(query, days), teamID).Scan(&stats.TotalDeliveries, &stats.PendingDeliveries,
		&stats.CompletedDeliveries, &stats.FailedDeliveries)
	if err != nil {
		return nil, err
	}

	// In simplified flow, there's no in_progress status
	stats.InProgressDeliveries = 0

	if stats.TotalDeliveries > 0 {
		stats.CompletionRate = float64(stats.CompletedDeliveries) / float64(stats.TotalDeliveries) * 100
	}

	// Get route stats
	r.db.QueryRow(fmt.Sprintf(`SELECT COUNT(*), COUNT(CASE WHEN status = 'active' THEN 1 END) FROM delivery_routes WHERE team_id = $1 AND created_at >= NOW() - INTERVAL '%d days'`, days), teamID).Scan(&stats.TotalRoutes, &stats.ActiveRoutes)
	return stats, nil
}

func (r *deliveryRepository) GetWorkerStats(workerID uuid.UUID, days int) (*domain.WorkerStats, error) {
	stats := &domain.WorkerStats{WorkerID: workerID}
	query := `SELECT COALESCE(worker_name, 'Worker'), COUNT(*) as total,
		COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
		COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed
		FROM deliveries WHERE worker_id = $1 AND created_at >= NOW() - INTERVAL '%d days' GROUP BY worker_name`

	err := r.db.QueryRow(fmt.Sprintf(query, days), workerID).Scan(&stats.WorkerName, &stats.TotalDeliveries,
		&stats.CompletedDeliveries, &stats.FailedDeliveries)
	if err == sql.ErrNoRows {
		stats.WorkerName = "Unknown"
		return stats, nil
	}
	if err != nil {
		return nil, err
	}

	if stats.TotalDeliveries > 0 {
		stats.CompletionRate = float64(stats.CompletedDeliveries) / float64(stats.TotalDeliveries) * 100
	}

	r.db.QueryRow(fmt.Sprintf(`SELECT COUNT(*) FROM delivery_routes WHERE worker_id = $1 AND created_at >= NOW() - INTERVAL '%d days'`, days), workerID).Scan(&stats.TotalRoutes)
	return stats, nil
}

func (r *deliveryRepository) GetTeamWorkerStats(teamID uuid.UUID, days int) ([]*domain.WorkerStats, error) {
	query := `SELECT worker_id, COALESCE(worker_name, 'Worker'), COUNT(*) as total,
		COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
		COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed
		FROM deliveries WHERE team_id = $1 AND worker_id IS NOT NULL AND created_at >= NOW() - INTERVAL '%d days'
		GROUP BY worker_id, worker_name ORDER BY total DESC`

	rows, err := r.db.Query(fmt.Sprintf(query, days), teamID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var workerStats []*domain.WorkerStats
	for rows.Next() {
		stats := &domain.WorkerStats{}
		err := rows.Scan(&stats.WorkerID, &stats.WorkerName, &stats.TotalDeliveries,
			&stats.CompletedDeliveries, &stats.FailedDeliveries)
		if err != nil {
			return nil, err
		}

		if stats.TotalDeliveries > 0 {
			stats.CompletionRate = float64(stats.CompletedDeliveries) / float64(stats.TotalDeliveries) * 100
		}
		workerStats = append(workerStats, stats)
	}
	return workerStats, nil
}

// GetCompletedVisitCount returns the count of completed deliveries (visits) for a worker
func (r *deliveryRepository) GetCompletedVisitCount(workerID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(
		"SELECT COUNT(*) FROM deliveries WHERE worker_id = $1 AND status = 'completed'",
		workerID,
	).Scan(&count)
	return count, err
}

// GetCompletedTerritoryCount returns the count of completed deliveries with territory for a worker
func (r *deliveryRepository) GetCompletedTerritoryCount(workerID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(
		"SELECT COUNT(*) FROM deliveries WHERE worker_id = $1 AND status = 'completed' AND territory_id IS NOT NULL",
		workerID,
	).Scan(&count)
	return count, err
}
