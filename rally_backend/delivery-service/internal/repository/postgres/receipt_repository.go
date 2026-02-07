package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/delivery-service/internal/domain"
)

// ReceiptRepository implements domain.ReceiptRepository
type ReceiptRepository struct {
	db *sql.DB
}

// NewReceiptRepository creates a new receipt repository
func NewReceiptRepository(db *sql.DB) *ReceiptRepository {
	return &ReceiptRepository{db: db}
}

// CreateReceipt creates a new receipt
func (r *ReceiptRepository) CreateReceipt(receipt *domain.Receipt) error {
	query := `
		INSERT INTO receipts (
			id, delivery_id, session_id, worker_id, worker_name, team_id,
			recipient_name, recipient_phone, recipient_email, address,
			latitude, longitude, receipt_type, total_amount, currency,
			payment_method, payment_ref, notes, receipt_number, status,
			issued_at, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23)
	`

	_, err := r.db.Exec(query,
		receipt.ID, receipt.DeliveryID, receipt.SessionID, receipt.WorkerID, receipt.WorkerName, receipt.TeamID,
		receipt.RecipientName, receipt.RecipientPhone, receipt.RecipientEmail, receipt.Address,
		receipt.Latitude, receipt.Longitude, receipt.ReceiptType, receipt.TotalAmount, receipt.Currency,
		receipt.PaymentMethod, receipt.PaymentRef, receipt.Notes, receipt.ReceiptNumber, receipt.Status,
		receipt.IssuedAt, receipt.CreatedAt, receipt.UpdatedAt,
	)
	return err
}

// GetReceiptByID gets a receipt by ID
func (r *ReceiptRepository) GetReceiptByID(id uuid.UUID) (*domain.Receipt, error) {
	query := `
		SELECT id, delivery_id, session_id, worker_id, worker_name, team_id,
			recipient_name, recipient_phone, recipient_email, address,
			latitude, longitude, receipt_type, total_amount, currency,
			payment_method, payment_ref, notes, receipt_number, status,
			issued_at, created_at, updated_at
		FROM receipts WHERE id = $1
	`

	receipt := &domain.Receipt{}
	err := r.db.QueryRow(query, id).Scan(
		&receipt.ID, &receipt.DeliveryID, &receipt.SessionID, &receipt.WorkerID, &receipt.WorkerName, &receipt.TeamID,
		&receipt.RecipientName, &receipt.RecipientPhone, &receipt.RecipientEmail, &receipt.Address,
		&receipt.Latitude, &receipt.Longitude, &receipt.ReceiptType, &receipt.TotalAmount, &receipt.Currency,
		&receipt.PaymentMethod, &receipt.PaymentRef, &receipt.Notes, &receipt.ReceiptNumber, &receipt.Status,
		&receipt.IssuedAt, &receipt.CreatedAt, &receipt.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return receipt, err
}

// GetReceiptByNumber gets a receipt by receipt number
func (r *ReceiptRepository) GetReceiptByNumber(receiptNumber string) (*domain.Receipt, error) {
	query := `
		SELECT id, delivery_id, session_id, worker_id, worker_name, team_id,
			recipient_name, recipient_phone, recipient_email, address,
			latitude, longitude, receipt_type, total_amount, currency,
			payment_method, payment_ref, notes, receipt_number, status,
			issued_at, created_at, updated_at
		FROM receipts WHERE receipt_number = $1
	`

	receipt := &domain.Receipt{}
	err := r.db.QueryRow(query, receiptNumber).Scan(
		&receipt.ID, &receipt.DeliveryID, &receipt.SessionID, &receipt.WorkerID, &receipt.WorkerName, &receipt.TeamID,
		&receipt.RecipientName, &receipt.RecipientPhone, &receipt.RecipientEmail, &receipt.Address,
		&receipt.Latitude, &receipt.Longitude, &receipt.ReceiptType, &receipt.TotalAmount, &receipt.Currency,
		&receipt.PaymentMethod, &receipt.PaymentRef, &receipt.Notes, &receipt.ReceiptNumber, &receipt.Status,
		&receipt.IssuedAt, &receipt.CreatedAt, &receipt.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return receipt, err
}

// GetReceiptsByWorkerID gets receipts by worker ID
func (r *ReceiptRepository) GetReceiptsByWorkerID(workerID uuid.UUID, limit, offset int) ([]*domain.Receipt, error) {
	query := `
		SELECT id, delivery_id, session_id, worker_id, worker_name, team_id,
			recipient_name, recipient_phone, recipient_email, address,
			latitude, longitude, receipt_type, total_amount, currency,
			payment_method, payment_ref, notes, receipt_number, status,
			issued_at, created_at, updated_at
		FROM receipts WHERE worker_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(query, workerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanReceipts(rows)
}

// GetReceiptsByTeamID gets receipts by team ID
func (r *ReceiptRepository) GetReceiptsByTeamID(teamID uuid.UUID, limit, offset int) ([]*domain.Receipt, error) {
	query := `
		SELECT id, delivery_id, session_id, worker_id, worker_name, team_id,
			recipient_name, recipient_phone, recipient_email, address,
			latitude, longitude, receipt_type, total_amount, currency,
			payment_method, payment_ref, notes, receipt_number, status,
			issued_at, created_at, updated_at
		FROM receipts WHERE team_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(query, teamID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanReceipts(rows)
}

// GetReceiptsBySessionID gets receipts by session ID
func (r *ReceiptRepository) GetReceiptsBySessionID(sessionID uuid.UUID) ([]*domain.Receipt, error) {
	query := `
		SELECT id, delivery_id, session_id, worker_id, worker_name, team_id,
			recipient_name, recipient_phone, recipient_email, address,
			latitude, longitude, receipt_type, total_amount, currency,
			payment_method, payment_ref, notes, receipt_number, status,
			issued_at, created_at, updated_at
		FROM receipts WHERE session_id = $1
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(query, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanReceipts(rows)
}

func (r *ReceiptRepository) scanReceipts(rows *sql.Rows) ([]*domain.Receipt, error) {
	var receipts []*domain.Receipt
	for rows.Next() {
		receipt := &domain.Receipt{}
		err := rows.Scan(
			&receipt.ID, &receipt.DeliveryID, &receipt.SessionID, &receipt.WorkerID, &receipt.WorkerName, &receipt.TeamID,
			&receipt.RecipientName, &receipt.RecipientPhone, &receipt.RecipientEmail, &receipt.Address,
			&receipt.Latitude, &receipt.Longitude, &receipt.ReceiptType, &receipt.TotalAmount, &receipt.Currency,
			&receipt.PaymentMethod, &receipt.PaymentRef, &receipt.Notes, &receipt.ReceiptNumber, &receipt.Status,
			&receipt.IssuedAt, &receipt.CreatedAt, &receipt.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		receipts = append(receipts, receipt)
	}
	return receipts, rows.Err()
}

// UpdateReceipt updates a receipt
func (r *ReceiptRepository) UpdateReceipt(receipt *domain.Receipt) error {
	query := `
		UPDATE receipts SET
			recipient_name = $1, recipient_phone = $2, recipient_email = $3,
			address = $4, latitude = $5, longitude = $6,
			total_amount = $7, payment_method = $8, payment_ref = $9,
			notes = $10, status = $11, updated_at = NOW()
		WHERE id = $12
	`

	_, err := r.db.Exec(query,
		receipt.RecipientName, receipt.RecipientPhone, receipt.RecipientEmail,
		receipt.Address, receipt.Latitude, receipt.Longitude,
		receipt.TotalAmount, receipt.PaymentMethod, receipt.PaymentRef,
		receipt.Notes, receipt.Status, receipt.ID,
	)
	return err
}

// DeleteReceipt deletes a receipt
func (r *ReceiptRepository) DeleteReceipt(id uuid.UUID) error {
	_, err := r.db.Exec("DELETE FROM receipts WHERE id = $1", id)
	return err
}

// GenerateReceiptNumber generates a unique receipt number
func (r *ReceiptRepository) GenerateReceiptNumber(teamID uuid.UUID) (string, error) {
	var seq int64
	err := r.db.QueryRow("SELECT nextval('receipt_number_seq')").Scan(&seq)
	if err != nil {
		return "", err
	}

	// Format: RCP-YYYYMMDD-XXXXX
	now := time.Now()
	return fmt.Sprintf("RCP-%s-%05d", now.Format("20060102"), seq), nil
}

// CreateReceiptItem creates a receipt item
func (r *ReceiptRepository) CreateReceiptItem(item *domain.ReceiptItem) error {
	query := `
		INSERT INTO receipt_items (
			id, receipt_id, item_type, item_name, item_code,
			quantity, unit_price, total_price, description, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	_, err := r.db.Exec(query,
		item.ID, item.ReceiptID, item.ItemType, item.ItemName, item.ItemCode,
		item.Quantity, item.UnitPrice, item.TotalPrice, item.Description, item.CreatedAt,
	)
	return err
}

// GetItemsByReceiptID gets items by receipt ID
func (r *ReceiptRepository) GetItemsByReceiptID(receiptID uuid.UUID) ([]*domain.ReceiptItem, error) {
	query := `
		SELECT id, receipt_id, item_type, item_name, item_code,
			quantity, unit_price, total_price, description, created_at
		FROM receipt_items WHERE receipt_id = $1
		ORDER BY created_at ASC
	`

	rows, err := r.db.Query(query, receiptID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*domain.ReceiptItem
	for rows.Next() {
		item := &domain.ReceiptItem{}
		err := rows.Scan(
			&item.ID, &item.ReceiptID, &item.ItemType, &item.ItemName, &item.ItemCode,
			&item.Quantity, &item.UnitPrice, &item.TotalPrice, &item.Description, &item.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// DeleteReceiptItems deletes all items for a receipt
func (r *ReceiptRepository) DeleteReceiptItems(receiptID uuid.UUID) error {
	_, err := r.db.Exec("DELETE FROM receipt_items WHERE receipt_id = $1", receiptID)
	return err
}

// CreateDonation creates a new donation
func (r *ReceiptRepository) CreateDonation(donation *domain.Donation) error {
	query := `
		INSERT INTO donations (
			id, session_id, worker_id, worker_name, team_id,
			donor_name, donor_phone, donor_email, donor_address,
			latitude, longitude, amount, currency, donation_type,
			purpose, payment_method, payment_ref, receipt_number,
			is_anonymous, notes, status, collected_at, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24)
	`

	_, err := r.db.Exec(query,
		donation.ID, donation.SessionID, donation.WorkerID, donation.WorkerName, donation.TeamID,
		donation.DonorName, donation.DonorPhone, donation.DonorEmail, donation.DonorAddress,
		donation.Latitude, donation.Longitude, donation.Amount, donation.Currency, donation.DonationType,
		donation.Purpose, donation.PaymentMethod, donation.PaymentRef, donation.ReceiptNumber,
		donation.IsAnonymous, donation.Notes, donation.Status, donation.CollectedAt, donation.CreatedAt, donation.UpdatedAt,
	)
	return err
}

// GetDonationByID gets a donation by ID
func (r *ReceiptRepository) GetDonationByID(id uuid.UUID) (*domain.Donation, error) {
	query := `
		SELECT id, session_id, worker_id, worker_name, team_id,
			donor_name, donor_phone, donor_email, donor_address,
			latitude, longitude, amount, currency, donation_type,
			purpose, payment_method, payment_ref, receipt_number,
			is_anonymous, notes, status, collected_at, deposited_at, created_at, updated_at
		FROM donations WHERE id = $1
	`

	donation := &domain.Donation{}
	err := r.db.QueryRow(query, id).Scan(
		&donation.ID, &donation.SessionID, &donation.WorkerID, &donation.WorkerName, &donation.TeamID,
		&donation.DonorName, &donation.DonorPhone, &donation.DonorEmail, &donation.DonorAddress,
		&donation.Latitude, &donation.Longitude, &donation.Amount, &donation.Currency, &donation.DonationType,
		&donation.Purpose, &donation.PaymentMethod, &donation.PaymentRef, &donation.ReceiptNumber,
		&donation.IsAnonymous, &donation.Notes, &donation.Status, &donation.CollectedAt, &donation.DepositedAt, &donation.CreatedAt, &donation.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return donation, err
}

// GetDonationsByWorkerID gets donations by worker ID
func (r *ReceiptRepository) GetDonationsByWorkerID(workerID uuid.UUID, limit, offset int) ([]*domain.Donation, error) {
	query := `
		SELECT id, session_id, worker_id, worker_name, team_id,
			donor_name, donor_phone, donor_email, donor_address,
			latitude, longitude, amount, currency, donation_type,
			purpose, payment_method, payment_ref, receipt_number,
			is_anonymous, notes, status, collected_at, deposited_at, created_at, updated_at
		FROM donations WHERE worker_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(query, workerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanDonations(rows)
}

// GetDonationsByTeamID gets donations by team ID
func (r *ReceiptRepository) GetDonationsByTeamID(teamID uuid.UUID, limit, offset int) ([]*domain.Donation, error) {
	query := `
		SELECT id, session_id, worker_id, worker_name, team_id,
			donor_name, donor_phone, donor_email, donor_address,
			latitude, longitude, amount, currency, donation_type,
			purpose, payment_method, payment_ref, receipt_number,
			is_anonymous, notes, status, collected_at, deposited_at, created_at, updated_at
		FROM donations WHERE team_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(query, teamID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanDonations(rows)
}

// GetAllDonations gets all donations across all teams
func (r *ReceiptRepository) GetAllDonations(limit, offset int) ([]*domain.Donation, error) {
	query := `
		SELECT id, session_id, worker_id, worker_name, team_id,
			donor_name, donor_phone, donor_email, donor_address,
			latitude, longitude, amount, currency, donation_type,
			purpose, payment_method, payment_ref, receipt_number,
			is_anonymous, notes, status, collected_at, deposited_at, created_at, updated_at
		FROM donations
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`

	rows, err := r.db.Query(query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanDonations(rows)
}

// GetDonationsBySessionID gets donations by session ID
func (r *ReceiptRepository) GetDonationsBySessionID(sessionID uuid.UUID) ([]*domain.Donation, error) {
	query := `
		SELECT id, session_id, worker_id, worker_name, team_id,
			donor_name, donor_phone, donor_email, donor_address,
			latitude, longitude, amount, currency, donation_type,
			purpose, payment_method, payment_ref, receipt_number,
			is_anonymous, notes, status, collected_at, deposited_at, created_at, updated_at
		FROM donations WHERE session_id = $1
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(query, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanDonations(rows)
}

func (r *ReceiptRepository) scanDonations(rows *sql.Rows) ([]*domain.Donation, error) {
	var donations []*domain.Donation
	for rows.Next() {
		donation := &domain.Donation{}
		err := rows.Scan(
			&donation.ID, &donation.SessionID, &donation.WorkerID, &donation.WorkerName, &donation.TeamID,
			&donation.DonorName, &donation.DonorPhone, &donation.DonorEmail, &donation.DonorAddress,
			&donation.Latitude, &donation.Longitude, &donation.Amount, &donation.Currency, &donation.DonationType,
			&donation.Purpose, &donation.PaymentMethod, &donation.PaymentRef, &donation.ReceiptNumber,
			&donation.IsAnonymous, &donation.Notes, &donation.Status, &donation.CollectedAt, &donation.DepositedAt, &donation.CreatedAt, &donation.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		donations = append(donations, donation)
	}
	return donations, rows.Err()
}

// UpdateDonation updates a donation
func (r *ReceiptRepository) UpdateDonation(donation *domain.Donation) error {
	query := `
		UPDATE donations SET
			donor_name = $1, donor_phone = $2, donor_email = $3,
			donor_address = $4, latitude = $5, longitude = $6,
			amount = $7, purpose = $8, notes = $9, status = $10,
			deposited_at = $11, updated_at = NOW()
		WHERE id = $12
	`

	_, err := r.db.Exec(query,
		donation.DonorName, donation.DonorPhone, donation.DonorEmail,
		donation.DonorAddress, donation.Latitude, donation.Longitude,
		donation.Amount, donation.Purpose, donation.Notes, donation.Status,
		donation.DepositedAt, donation.ID,
	)
	return err
}

// DeleteDonation deletes a donation
func (r *ReceiptRepository) DeleteDonation(id uuid.UUID) error {
	_, err := r.db.Exec("DELETE FROM donations WHERE id = $1", id)
	return err
}

// MarkDonationDeposited marks a donation as deposited
func (r *ReceiptRepository) MarkDonationDeposited(id uuid.UUID) error {
	query := `
		UPDATE donations SET
			status = 'deposited',
			deposited_at = NOW(),
			updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.db.Exec(query, id)
	return err
}

// GenerateDonationReceiptNumber generates a unique donation receipt number
func (r *ReceiptRepository) GenerateDonationReceiptNumber(teamID uuid.UUID) (string, error) {
	var seq int64
	err := r.db.QueryRow("SELECT nextval('donation_receipt_number_seq')").Scan(&seq)
	if err != nil {
		return "", err
	}

	// Format: DON-YYYYMMDD-XXXXX
	now := time.Now()
	return fmt.Sprintf("DON-%s-%05d", now.Format("20060102"), seq), nil
}

// GetReceiptStats gets receipt statistics
func (r *ReceiptRepository) GetReceiptStats(teamID uuid.UUID, days int) (*domain.ReceiptStats, error) {
	query := `
		SELECT
			COUNT(*) as total_receipts,
			COALESCE(SUM(total_amount), 0) as total_amount,
			COUNT(*) FILTER (WHERE receipt_type = 'book_sale') as book_sales_count,
			COALESCE(SUM(total_amount) FILTER (WHERE receipt_type = 'book_sale'), 0) as book_sales_amount,
			COUNT(*) FILTER (WHERE receipt_type = 'literature') as literature_count,
			COALESCE(SUM(total_amount) FILTER (WHERE receipt_type = 'literature'), 0) as literature_amount,
			COUNT(*) FILTER (WHERE receipt_type = 'donation') as donation_count,
			COALESCE(SUM(total_amount) FILTER (WHERE receipt_type = 'donation'), 0) as donation_amount
		FROM receipts
		WHERE team_id = $1
			AND status = 'completed'
			AND created_at >= NOW() - INTERVAL '1 day' * $2
	`

	stats := &domain.ReceiptStats{}
	err := r.db.QueryRow(query, teamID, days).Scan(
		&stats.TotalReceipts, &stats.TotalAmount,
		&stats.BookSalesCount, &stats.BookSalesAmount,
		&stats.LiteratureCount, &stats.LiteratureAmount,
		&stats.DonationCount, &stats.DonationAmount,
	)
	if err != nil {
		return nil, err
	}

	if stats.TotalReceipts > 0 {
		stats.AverageReceiptValue = stats.TotalAmount / float64(stats.TotalReceipts)
	}

	return stats, nil
}

// GetWorkerReceiptStats gets receipt statistics for a worker
func (r *ReceiptRepository) GetWorkerReceiptStats(workerID uuid.UUID, days int) (*domain.ReceiptStats, error) {
	query := `
		SELECT
			COUNT(*) as total_receipts,
			COALESCE(SUM(total_amount), 0) as total_amount,
			COUNT(*) FILTER (WHERE receipt_type = 'book_sale') as book_sales_count,
			COALESCE(SUM(total_amount) FILTER (WHERE receipt_type = 'book_sale'), 0) as book_sales_amount,
			COUNT(*) FILTER (WHERE receipt_type = 'literature') as literature_count,
			COALESCE(SUM(total_amount) FILTER (WHERE receipt_type = 'literature'), 0) as literature_amount,
			COUNT(*) FILTER (WHERE receipt_type = 'donation') as donation_count,
			COALESCE(SUM(total_amount) FILTER (WHERE receipt_type = 'donation'), 0) as donation_amount
		FROM receipts
		WHERE worker_id = $1
			AND status = 'completed'
			AND created_at >= NOW() - INTERVAL '1 day' * $2
	`

	stats := &domain.ReceiptStats{}
	err := r.db.QueryRow(query, workerID, days).Scan(
		&stats.TotalReceipts, &stats.TotalAmount,
		&stats.BookSalesCount, &stats.BookSalesAmount,
		&stats.LiteratureCount, &stats.LiteratureAmount,
		&stats.DonationCount, &stats.DonationAmount,
	)
	if err != nil {
		return nil, err
	}

	if stats.TotalReceipts > 0 {
		stats.AverageReceiptValue = stats.TotalAmount / float64(stats.TotalReceipts)
	}

	return stats, nil
}

// GetDonationStats gets donation statistics
func (r *ReceiptRepository) GetDonationStats(teamID uuid.UUID, days int) (*domain.DonationStats, error) {
	query := `
		SELECT
			COUNT(*) as total_donations,
			COALESCE(SUM(amount), 0) as total_amount,
			COUNT(*) FILTER (WHERE donation_type = 'one_time') as one_time_donations,
			COALESCE(SUM(amount) FILTER (WHERE donation_type = 'one_time'), 0) as one_time_amount,
			COUNT(*) FILTER (WHERE donation_type = 'recurring') as recurring_donations,
			COALESCE(SUM(amount) FILTER (WHERE donation_type = 'recurring'), 0) as recurring_amount,
			COALESCE(MAX(amount), 0) as largest_donation,
			COUNT(*) FILTER (WHERE is_anonymous = true) as anonymous_donations,
			COALESCE(SUM(amount) FILTER (WHERE status = 'received'), 0) as pending_deposit
		FROM donations
		WHERE team_id = $1
			AND status != 'cancelled'
			AND created_at >= NOW() - INTERVAL '1 day' * $2
	`

	stats := &domain.DonationStats{}
	err := r.db.QueryRow(query, teamID, days).Scan(
		&stats.TotalDonations, &stats.TotalAmount,
		&stats.OneTimeDonations, &stats.OneTimeAmount,
		&stats.RecurringDonations, &stats.RecurringAmount,
		&stats.LargestDonation, &stats.AnonymousDonations,
		&stats.PendingDeposit,
	)
	if err != nil {
		return nil, err
	}

	if stats.TotalDonations > 0 {
		stats.AverageDonation = stats.TotalAmount / float64(stats.TotalDonations)
	}

	return stats, nil
}

// GetGlobalDonationStats gets donation statistics across all teams
func (r *ReceiptRepository) GetGlobalDonationStats(days int) (*domain.DonationStats, error) {
	query := `
		SELECT
			COUNT(*) as total_donations,
			COALESCE(SUM(amount), 0) as total_amount,
			COUNT(*) FILTER (WHERE donation_type = 'one_time') as one_time_donations,
			COALESCE(SUM(amount) FILTER (WHERE donation_type = 'one_time'), 0) as one_time_amount,
			COUNT(*) FILTER (WHERE donation_type = 'recurring') as recurring_donations,
			COALESCE(SUM(amount) FILTER (WHERE donation_type = 'recurring'), 0) as recurring_amount,
			COALESCE(MAX(amount), 0) as largest_donation,
			COUNT(*) FILTER (WHERE is_anonymous = true) as anonymous_donations,
			COALESCE(SUM(amount) FILTER (WHERE status = 'received'), 0) as pending_deposit
		FROM donations
		WHERE status != 'cancelled'
			AND created_at >= NOW() - INTERVAL '1 day' * $1
	`

	stats := &domain.DonationStats{}
	err := r.db.QueryRow(query, days).Scan(
		&stats.TotalDonations, &stats.TotalAmount,
		&stats.OneTimeDonations, &stats.OneTimeAmount,
		&stats.RecurringDonations, &stats.RecurringAmount,
		&stats.LargestDonation, &stats.AnonymousDonations,
		&stats.PendingDeposit,
	)
	if err != nil {
		return nil, err
	}

	if stats.TotalDonations > 0 {
		stats.AverageDonation = stats.TotalAmount / float64(stats.TotalDonations)
	}

	return stats, nil
}

// GetWorkerDonationStats gets donation statistics for a worker
func (r *ReceiptRepository) GetWorkerDonationStats(workerID uuid.UUID, days int) (*domain.DonationStats, error) {
	query := `
		SELECT
			COUNT(*) as total_donations,
			COALESCE(SUM(amount), 0) as total_amount,
			COUNT(*) FILTER (WHERE donation_type = 'one_time') as one_time_donations,
			COALESCE(SUM(amount) FILTER (WHERE donation_type = 'one_time'), 0) as one_time_amount,
			COUNT(*) FILTER (WHERE donation_type = 'recurring') as recurring_donations,
			COALESCE(SUM(amount) FILTER (WHERE donation_type = 'recurring'), 0) as recurring_amount,
			COALESCE(MAX(amount), 0) as largest_donation,
			COUNT(*) FILTER (WHERE is_anonymous = true) as anonymous_donations,
			COALESCE(SUM(amount) FILTER (WHERE status = 'received'), 0) as pending_deposit
		FROM donations
		WHERE worker_id = $1
			AND status != 'cancelled'
			AND created_at >= NOW() - INTERVAL '1 day' * $2
	`

	stats := &domain.DonationStats{}
	err := r.db.QueryRow(query, workerID, days).Scan(
		&stats.TotalDonations, &stats.TotalAmount,
		&stats.OneTimeDonations, &stats.OneTimeAmount,
		&stats.RecurringDonations, &stats.RecurringAmount,
		&stats.LargestDonation, &stats.AnonymousDonations,
		&stats.PendingDeposit,
	)
	if err != nil {
		return nil, err
	}

	if stats.TotalDonations > 0 {
		stats.AverageDonation = stats.TotalAmount / float64(stats.TotalDonations)
	}

	return stats, nil
}
