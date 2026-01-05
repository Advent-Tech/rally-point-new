package service

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/delivery-service/internal/domain"
)

// receiptService implements domain.ReceiptService
type receiptService struct {
	repo domain.ReceiptRepository
}

// NewReceiptService creates a new receipt service
func NewReceiptService(repo domain.ReceiptRepository) domain.ReceiptService {
	return &receiptService{repo: repo}
}

// CreateReceipt creates a new receipt with items
func (s *receiptService) CreateReceipt(workerID uuid.UUID, workerName string, req *domain.CreateReceiptRequest) (*domain.ReceiptWithItems, error) {
	// Generate receipt number
	receiptNumber, err := s.repo.GenerateReceiptNumber(req.TeamID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate receipt number: %w", err)
	}

	// Set default currency if not provided
	currency := req.Currency
	if currency == "" {
		currency = domain.DefaultCurrency
	}

	// Calculate total amount
	var totalAmount float64
	for _, item := range req.Items {
		totalAmount += float64(item.Quantity) * item.UnitPrice
	}

	now := time.Now()
	receipt := &domain.Receipt{
		ID:             uuid.New(),
		DeliveryID:     req.DeliveryID,
		SessionID:      req.SessionID,
		WorkerID:       workerID,
		WorkerName:     workerName,
		TeamID:         req.TeamID,
		RecipientName:  req.RecipientName,
		RecipientPhone: req.RecipientPhone,
		RecipientEmail: req.RecipientEmail,
		Address:        req.Address,
		Latitude:       req.Latitude,
		Longitude:      req.Longitude,
		ReceiptType:    req.ReceiptType,
		TotalAmount:    totalAmount,
		Currency:       currency,
		PaymentMethod:  req.PaymentMethod,
		PaymentRef:     req.PaymentRef,
		Notes:          req.Notes,
		ReceiptNumber:  receiptNumber,
		Status:         domain.ReceiptStatusCompleted,
		IssuedAt:       now,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	if err := s.repo.CreateReceipt(receipt); err != nil {
		return nil, fmt.Errorf("failed to create receipt: %w", err)
	}

	// Create receipt items
	var items []*domain.ReceiptItem
	for _, itemReq := range req.Items {
		item := &domain.ReceiptItem{
			ID:          uuid.New(),
			ReceiptID:   receipt.ID,
			ItemType:    itemReq.ItemType,
			ItemName:    itemReq.ItemName,
			ItemCode:    itemReq.ItemCode,
			Quantity:    itemReq.Quantity,
			UnitPrice:   itemReq.UnitPrice,
			TotalPrice:  float64(itemReq.Quantity) * itemReq.UnitPrice,
			Description: itemReq.Description,
			CreatedAt:   now,
		}

		if err := s.repo.CreateReceiptItem(item); err != nil {
			return nil, fmt.Errorf("failed to create receipt item: %w", err)
		}

		items = append(items, item)
	}

	return &domain.ReceiptWithItems{
		Receipt: receipt,
		Items:   items,
	}, nil
}

// GetReceipt gets a receipt by ID with items
func (s *receiptService) GetReceipt(id uuid.UUID) (*domain.ReceiptWithItems, error) {
	receipt, err := s.repo.GetReceiptByID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get receipt: %w", err)
	}
	if receipt == nil {
		return nil, nil
	}

	items, err := s.repo.GetItemsByReceiptID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get receipt items: %w", err)
	}

	return &domain.ReceiptWithItems{
		Receipt: receipt,
		Items:   items,
	}, nil
}

// GetReceiptByNumber gets a receipt by receipt number
func (s *receiptService) GetReceiptByNumber(receiptNumber string) (*domain.ReceiptWithItems, error) {
	receipt, err := s.repo.GetReceiptByNumber(receiptNumber)
	if err != nil {
		return nil, fmt.Errorf("failed to get receipt: %w", err)
	}
	if receipt == nil {
		return nil, nil
	}

	items, err := s.repo.GetItemsByReceiptID(receipt.ID)
	if err != nil {
		return nil, fmt.Errorf("failed to get receipt items: %w", err)
	}

	return &domain.ReceiptWithItems{
		Receipt: receipt,
		Items:   items,
	}, nil
}

// GetWorkerReceipts gets receipts by worker ID
func (s *receiptService) GetWorkerReceipts(workerID uuid.UUID, limit, offset int) ([]*domain.ReceiptWithItems, error) {
	if limit <= 0 || limit > domain.MaxReceiptLimit {
		limit = domain.DefaultReceiptLimit
	}

	receipts, err := s.repo.GetReceiptsByWorkerID(workerID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker receipts: %w", err)
	}

	return s.getReceiptsWithItems(receipts)
}

// GetTeamReceipts gets receipts by team ID
func (s *receiptService) GetTeamReceipts(teamID uuid.UUID, limit, offset int) ([]*domain.ReceiptWithItems, error) {
	if limit <= 0 || limit > domain.MaxReceiptLimit {
		limit = domain.DefaultReceiptLimit
	}

	receipts, err := s.repo.GetReceiptsByTeamID(teamID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get team receipts: %w", err)
	}

	return s.getReceiptsWithItems(receipts)
}

// GetSessionReceipts gets receipts by session ID
func (s *receiptService) GetSessionReceipts(sessionID uuid.UUID) ([]*domain.ReceiptWithItems, error) {
	receipts, err := s.repo.GetReceiptsBySessionID(sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get session receipts: %w", err)
	}

	return s.getReceiptsWithItems(receipts)
}

func (s *receiptService) getReceiptsWithItems(receipts []*domain.Receipt) ([]*domain.ReceiptWithItems, error) {
	result := make([]*domain.ReceiptWithItems, len(receipts))
	for i, receipt := range receipts {
		items, err := s.repo.GetItemsByReceiptID(receipt.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to get items for receipt %s: %w", receipt.ID, err)
		}
		result[i] = &domain.ReceiptWithItems{
			Receipt: receipt,
			Items:   items,
		}
	}
	return result, nil
}

// CancelReceipt cancels a receipt
func (s *receiptService) CancelReceipt(id uuid.UUID) error {
	receipt, err := s.repo.GetReceiptByID(id)
	if err != nil {
		return fmt.Errorf("failed to get receipt: %w", err)
	}
	if receipt == nil {
		return fmt.Errorf("receipt not found")
	}

	if receipt.Status != domain.ReceiptStatusCompleted && receipt.Status != domain.ReceiptStatusPending {
		return fmt.Errorf("cannot cancel receipt with status: %s", receipt.Status)
	}

	receipt.Status = domain.ReceiptStatusCancelled
	return s.repo.UpdateReceipt(receipt)
}

// RefundReceipt marks a receipt as refunded
func (s *receiptService) RefundReceipt(id uuid.UUID) error {
	receipt, err := s.repo.GetReceiptByID(id)
	if err != nil {
		return fmt.Errorf("failed to get receipt: %w", err)
	}
	if receipt == nil {
		return fmt.Errorf("receipt not found")
	}

	if receipt.Status != domain.ReceiptStatusCompleted {
		return fmt.Errorf("can only refund completed receipts")
	}

	receipt.Status = domain.ReceiptStatusRefunded
	return s.repo.UpdateReceipt(receipt)
}

// CreateDonation creates a new donation
func (s *receiptService) CreateDonation(workerID uuid.UUID, workerName string, req *domain.CreateDonationRequest) (*domain.Donation, error) {
	// Generate donation receipt number
	receiptNumber, err := s.repo.GenerateDonationReceiptNumber(req.TeamID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate donation receipt number: %w", err)
	}

	// Set default currency if not provided
	currency := req.Currency
	if currency == "" {
		currency = domain.DefaultCurrency
	}

	now := time.Now()
	donation := &domain.Donation{
		ID:            uuid.New(),
		SessionID:     req.SessionID,
		WorkerID:      workerID,
		WorkerName:    workerName,
		TeamID:        req.TeamID,
		DonorName:     req.DonorName,
		DonorPhone:    req.DonorPhone,
		DonorEmail:    req.DonorEmail,
		DonorAddress:  req.DonorAddress,
		Latitude:      req.Latitude,
		Longitude:     req.Longitude,
		Amount:        req.Amount,
		Currency:      currency,
		DonationType:  req.DonationType,
		Purpose:       req.Purpose,
		PaymentMethod: req.PaymentMethod,
		PaymentRef:    req.PaymentRef,
		ReceiptNumber: receiptNumber,
		IsAnonymous:   req.IsAnonymous,
		Notes:         req.Notes,
		Status:        domain.DonationStatusReceived,
		CollectedAt:   now,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	if err := s.repo.CreateDonation(donation); err != nil {
		return nil, fmt.Errorf("failed to create donation: %w", err)
	}

	return donation, nil
}

// GetDonation gets a donation by ID
func (s *receiptService) GetDonation(id uuid.UUID) (*domain.Donation, error) {
	donation, err := s.repo.GetDonationByID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get donation: %w", err)
	}
	return donation, nil
}

// GetWorkerDonations gets donations by worker ID
func (s *receiptService) GetWorkerDonations(workerID uuid.UUID, limit, offset int) ([]*domain.Donation, error) {
	if limit <= 0 || limit > domain.MaxDonationLimit {
		limit = domain.DefaultDonationLimit
	}

	donations, err := s.repo.GetDonationsByWorkerID(workerID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker donations: %w", err)
	}
	return donations, nil
}

// GetTeamDonations gets donations by team ID
func (s *receiptService) GetTeamDonations(teamID uuid.UUID, limit, offset int) ([]*domain.Donation, error) {
	if limit <= 0 || limit > domain.MaxDonationLimit {
		limit = domain.DefaultDonationLimit
	}

	donations, err := s.repo.GetDonationsByTeamID(teamID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get team donations: %w", err)
	}
	return donations, nil
}

// GetSessionDonations gets donations by session ID
func (s *receiptService) GetSessionDonations(sessionID uuid.UUID) ([]*domain.Donation, error) {
	donations, err := s.repo.GetDonationsBySessionID(sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get session donations: %w", err)
	}
	return donations, nil
}

// MarkDonationDeposited marks a donation as deposited
func (s *receiptService) MarkDonationDeposited(id uuid.UUID) error {
	donation, err := s.repo.GetDonationByID(id)
	if err != nil {
		return fmt.Errorf("failed to get donation: %w", err)
	}
	if donation == nil {
		return fmt.Errorf("donation not found")
	}

	if donation.Status != domain.DonationStatusReceived {
		return fmt.Errorf("can only deposit donations with received status")
	}

	return s.repo.MarkDonationDeposited(id)
}

// CancelDonation cancels a donation
func (s *receiptService) CancelDonation(id uuid.UUID) error {
	donation, err := s.repo.GetDonationByID(id)
	if err != nil {
		return fmt.Errorf("failed to get donation: %w", err)
	}
	if donation == nil {
		return fmt.Errorf("donation not found")
	}

	if donation.Status == domain.DonationStatusDeposited {
		return fmt.Errorf("cannot cancel deposited donations")
	}

	donation.Status = domain.DonationStatusCancelled
	return s.repo.UpdateDonation(donation)
}

// GetReceiptStats gets receipt statistics
func (s *receiptService) GetReceiptStats(teamID uuid.UUID, days int) (*domain.ReceiptStats, error) {
	if days <= 0 {
		days = domain.DefaultStatsDays
	}
	return s.repo.GetReceiptStats(teamID, days)
}

// GetWorkerReceiptStats gets receipt statistics for a worker
func (s *receiptService) GetWorkerReceiptStats(workerID uuid.UUID, days int) (*domain.ReceiptStats, error) {
	if days <= 0 {
		days = domain.DefaultStatsDays
	}
	return s.repo.GetWorkerReceiptStats(workerID, days)
}

// GetDonationStats gets donation statistics
func (s *receiptService) GetDonationStats(teamID uuid.UUID, days int) (*domain.DonationStats, error) {
	if days <= 0 {
		days = domain.DefaultStatsDays
	}
	return s.repo.GetDonationStats(teamID, days)
}

// GetWorkerDonationStats gets donation statistics for a worker
func (s *receiptService) GetWorkerDonationStats(workerID uuid.UUID, days int) (*domain.DonationStats, error) {
	if days <= 0 {
		days = domain.DefaultStatsDays
	}
	return s.repo.GetWorkerDonationStats(workerID, days)
}
