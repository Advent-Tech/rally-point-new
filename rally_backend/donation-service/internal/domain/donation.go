package domain

import (
	"time"

	"github.com/google/uuid"
)

// Donation represents a donation record
type Donation struct {
	ID            uuid.UUID  `json:"id" db:"id"`
	TeamID        uuid.UUID  `json:"team_id" db:"team_id"`
	WorkerID      uuid.UUID  `json:"worker_id" db:"worker_id"`
	WorkerName    string     `json:"worker_name" db:"worker_name"`
	DonorName     string     `json:"donor_name" db:"donor_name"`
	DonorEmail    string     `json:"donor_email,omitempty" db:"donor_email"`
	DonorPhone    string     `json:"donor_phone,omitempty" db:"donor_phone"`
	Amount        float64    `json:"amount" db:"amount"`
	Currency      string     `json:"currency" db:"currency"`
	PaymentMethod string     `json:"payment_method" db:"payment_method"` // cash, card, check, online
	DonationType  string     `json:"donation_type" db:"donation_type"`   // one_time, recurring, pledge
	Purpose       string     `json:"purpose,omitempty" db:"purpose"`     // general, books, outreach, etc.
	Notes         string     `json:"notes,omitempty" db:"notes"`
	Latitude      *float64   `json:"latitude,omitempty" db:"latitude"`
	Longitude     *float64   `json:"longitude,omitempty" db:"longitude"`
	DeliveryID    *uuid.UUID `json:"delivery_id,omitempty" db:"delivery_id"` // Optional link to delivery
	ReceiptNumber string     `json:"receipt_number,omitempty" db:"receipt_number"`
	DonatedAt     time.Time  `json:"donated_at" db:"donated_at"`
	CreatedAt     time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at" db:"updated_at"`
}

// DonationStats represents donation statistics
type DonationStats struct {
	TotalDonations      int     `json:"total_donations"`
	TotalAmount         float64 `json:"total_amount"`
	TodayDonations      int     `json:"today_donations"`
	TodayAmount         float64 `json:"today_amount"`
	WeekDonations       int     `json:"week_donations"`
	WeekAmount          float64 `json:"week_amount"`
	MonthDonations      int     `json:"month_donations"`
	MonthAmount         float64 `json:"month_amount"`
	AverageDonation     float64 `json:"average_donation"`
	LargestDonation     float64 `json:"largest_donation"`
	UniqueDonors        int     `json:"unique_donors"`
	CashAmount          float64 `json:"cash_amount"`
	CardAmount          float64 `json:"card_amount"`
	CheckAmount         float64 `json:"check_amount"`
	OnlineAmount        float64 `json:"online_amount"`
}

// WorkerDonationStats represents per-worker donation statistics
type WorkerDonationStats struct {
	WorkerID        uuid.UUID `json:"worker_id"`
	WorkerName      string    `json:"worker_name"`
	TotalDonations  int       `json:"total_donations"`
	TotalAmount     float64   `json:"total_amount"`
	AverageDonation float64   `json:"average_donation"`
	UniqueDonors    int       `json:"unique_donors"`
}

// CreateDonationRequest represents a request to create a donation
type CreateDonationRequest struct {
	TeamID        uuid.UUID  `json:"team_id" binding:"required"`
	DonorName     string     `json:"donor_name" binding:"required"`
	DonorEmail    string     `json:"donor_email"`
	DonorPhone    string     `json:"donor_phone"`
	Amount        float64    `json:"amount" binding:"required,gt=0"`
	Currency      string     `json:"currency"`
	PaymentMethod string     `json:"payment_method" binding:"required"`
	DonationType  string     `json:"donation_type"`
	Purpose       string     `json:"purpose"`
	Notes         string     `json:"notes"`
	Latitude      *float64   `json:"latitude"`
	Longitude     *float64   `json:"longitude"`
	DeliveryID    *uuid.UUID `json:"delivery_id"`
}

// UpdateDonationRequest represents a request to update a donation
type UpdateDonationRequest struct {
	DonorName     *string  `json:"donor_name"`
	DonorEmail    *string  `json:"donor_email"`
	DonorPhone    *string  `json:"donor_phone"`
	Amount        *float64 `json:"amount"`
	PaymentMethod *string  `json:"payment_method"`
	DonationType  *string  `json:"donation_type"`
	Purpose       *string  `json:"purpose"`
	Notes         *string  `json:"notes"`
}

// DonationQuery represents query parameters for listing donations
type DonationQuery struct {
	TeamID        *uuid.UUID `form:"team_id"`
	WorkerID      *uuid.UUID `form:"worker_id"`
	StartDate     *time.Time `form:"start_date"`
	EndDate       *time.Time `form:"end_date"`
	PaymentMethod *string    `form:"payment_method"`
	MinAmount     *float64   `form:"min_amount"`
	MaxAmount     *float64   `form:"max_amount"`
	Limit         int        `form:"limit"`
	Offset        int        `form:"offset"`
}

// DonationRepository defines the interface for donation data access
type DonationRepository interface {
	Create(donation *Donation) error
	GetByID(id uuid.UUID) (*Donation, error)
	Update(donation *Donation) error
	Delete(id uuid.UUID) error
	List(query *DonationQuery) ([]*Donation, error)
	GetWorkerDonations(workerID uuid.UUID, limit, offset int) ([]*Donation, error)
	GetTeamDonations(teamID uuid.UUID, limit, offset int) ([]*Donation, error)
	GetWorkerStats(workerID uuid.UUID, days int) (*DonationStats, error)
	GetTeamStats(teamID uuid.UUID, days int) (*DonationStats, error)
	GetTeamWorkerStats(teamID uuid.UUID) ([]*WorkerDonationStats, error)
}

// DonationService defines the interface for donation business logic
type DonationService interface {
	CreateDonation(workerID uuid.UUID, workerName string, req *CreateDonationRequest) (*Donation, error)
	GetDonation(id uuid.UUID) (*Donation, error)
	UpdateDonation(id, workerID uuid.UUID, req *UpdateDonationRequest) (*Donation, error)
	DeleteDonation(id, workerID uuid.UUID) error
	ListDonations(query *DonationQuery) ([]*Donation, error)
	GetWorkerDonations(workerID uuid.UUID, limit, offset int) ([]*Donation, error)
	GetTeamDonations(teamID uuid.UUID, limit, offset int) ([]*Donation, error)
	GetWorkerStats(workerID uuid.UUID, days int) (*DonationStats, error)
	GetTeamStats(teamID uuid.UUID, days int) (*DonationStats, error)
	GetTeamWorkerStats(teamID uuid.UUID) ([]*WorkerDonationStats, error)
}

// Constants
const (
	PaymentMethodCash   = "cash"
	PaymentMethodCard   = "card"
	PaymentMethodCheck  = "check"
	PaymentMethodOnline = "online"

	DonationTypeOneTime   = "one_time"
	DonationTypeRecurring = "recurring"
	DonationTypePledge    = "pledge"

	DefaultCurrency = "USD"
)
