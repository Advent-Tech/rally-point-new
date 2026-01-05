package domain

import (
	"time"

	"github.com/google/uuid"
)

// Receipt represents a digital receipt for book sales or literature distribution
type Receipt struct {
	ID            uuid.UUID  `json:"id" db:"id"`
	DeliveryID    *uuid.UUID `json:"delivery_id,omitempty" db:"delivery_id"`
	SessionID     *uuid.UUID `json:"session_id,omitempty" db:"session_id"`
	WorkerID      uuid.UUID  `json:"worker_id" db:"worker_id"`
	WorkerName    string     `json:"worker_name" db:"worker_name"`
	TeamID        uuid.UUID  `json:"team_id" db:"team_id"`
	RecipientName string     `json:"recipient_name" db:"recipient_name"`
	RecipientPhone *string   `json:"recipient_phone,omitempty" db:"recipient_phone"`
	RecipientEmail *string   `json:"recipient_email,omitempty" db:"recipient_email"`
	Address       *string    `json:"address,omitempty" db:"address"`
	Latitude      *float64   `json:"latitude,omitempty" db:"latitude"`
	Longitude     *float64   `json:"longitude,omitempty" db:"longitude"`
	ReceiptType   string     `json:"receipt_type" db:"receipt_type"` // "book_sale", "literature", "donation"
	TotalAmount   float64    `json:"total_amount" db:"total_amount"`
	Currency      string     `json:"currency" db:"currency"` // "BDT", "USD", etc.
	PaymentMethod string     `json:"payment_method" db:"payment_method"` // "cash", "mobile", "card"
	PaymentRef    *string    `json:"payment_ref,omitempty" db:"payment_ref"`
	Notes         *string    `json:"notes,omitempty" db:"notes"`
	ReceiptNumber string     `json:"receipt_number" db:"receipt_number"` // Auto-generated
	Status        string     `json:"status" db:"status"` // "pending", "completed", "cancelled", "refunded"
	IssuedAt      time.Time  `json:"issued_at" db:"issued_at"`
	CreatedAt     time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at" db:"updated_at"`
}

// ReceiptItem represents individual items in a receipt
type ReceiptItem struct {
	ID          uuid.UUID `json:"id" db:"id"`
	ReceiptID   uuid.UUID `json:"receipt_id" db:"receipt_id"`
	ItemType    string    `json:"item_type" db:"item_type"` // "book", "magazine", "tract", "brochure", "other"
	ItemName    string    `json:"item_name" db:"item_name"`
	ItemCode    *string   `json:"item_code,omitempty" db:"item_code"`
	Quantity    int       `json:"quantity" db:"quantity"`
	UnitPrice   float64   `json:"unit_price" db:"unit_price"`
	TotalPrice  float64   `json:"total_price" db:"total_price"`
	Description *string   `json:"description,omitempty" db:"description"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// Donation represents a donation collection record
type Donation struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	SessionID       *uuid.UUID `json:"session_id,omitempty" db:"session_id"`
	WorkerID        uuid.UUID  `json:"worker_id" db:"worker_id"`
	WorkerName      string     `json:"worker_name" db:"worker_name"`
	TeamID          uuid.UUID  `json:"team_id" db:"team_id"`
	DonorName       string     `json:"donor_name" db:"donor_name"`
	DonorPhone      *string    `json:"donor_phone,omitempty" db:"donor_phone"`
	DonorEmail      *string    `json:"donor_email,omitempty" db:"donor_email"`
	DonorAddress    *string    `json:"donor_address,omitempty" db:"donor_address"`
	Latitude        *float64   `json:"latitude,omitempty" db:"latitude"`
	Longitude       *float64   `json:"longitude,omitempty" db:"longitude"`
	Amount          float64    `json:"amount" db:"amount"`
	Currency        string     `json:"currency" db:"currency"`
	DonationType    string     `json:"donation_type" db:"donation_type"` // "one_time", "recurring", "pledge"
	Purpose         *string    `json:"purpose,omitempty" db:"purpose"` // Optional purpose/campaign
	PaymentMethod   string     `json:"payment_method" db:"payment_method"` // "cash", "mobile", "card", "check"
	PaymentRef      *string    `json:"payment_ref,omitempty" db:"payment_ref"`
	ReceiptNumber   string     `json:"receipt_number" db:"receipt_number"`
	IsAnonymous     bool       `json:"is_anonymous" db:"is_anonymous"`
	Notes           *string    `json:"notes,omitempty" db:"notes"`
	Status          string     `json:"status" db:"status"` // "received", "deposited", "cancelled"
	CollectedAt     time.Time  `json:"collected_at" db:"collected_at"`
	DepositedAt     *time.Time `json:"deposited_at,omitempty" db:"deposited_at"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

// CreateReceiptRequest represents the request to create a receipt
type CreateReceiptRequest struct {
	DeliveryID     *uuid.UUID              `json:"delivery_id,omitempty"`
	SessionID      *uuid.UUID              `json:"session_id,omitempty"`
	TeamID         uuid.UUID               `json:"team_id" binding:"required"`
	RecipientName  string                  `json:"recipient_name" binding:"required"`
	RecipientPhone *string                 `json:"recipient_phone,omitempty"`
	RecipientEmail *string                 `json:"recipient_email,omitempty"`
	Address        *string                 `json:"address,omitempty"`
	Latitude       *float64                `json:"latitude,omitempty"`
	Longitude      *float64                `json:"longitude,omitempty"`
	ReceiptType    string                  `json:"receipt_type" binding:"required"`
	Currency       string                  `json:"currency,omitempty"` // Defaults to "BDT"
	PaymentMethod  string                  `json:"payment_method" binding:"required"`
	PaymentRef     *string                 `json:"payment_ref,omitempty"`
	Notes          *string                 `json:"notes,omitempty"`
	Items          []CreateReceiptItemRequest `json:"items" binding:"required,min=1"`
}

// CreateReceiptItemRequest represents an item in receipt creation
type CreateReceiptItemRequest struct {
	ItemType    string  `json:"item_type" binding:"required"`
	ItemName    string  `json:"item_name" binding:"required"`
	ItemCode    *string `json:"item_code,omitempty"`
	Quantity    int     `json:"quantity" binding:"required,min=1"`
	UnitPrice   float64 `json:"unit_price" binding:"required,gte=0"`
	Description *string `json:"description,omitempty"`
}

// CreateDonationRequest represents the request to create a donation record
type CreateDonationRequest struct {
	SessionID     *uuid.UUID `json:"session_id,omitempty"`
	TeamID        uuid.UUID  `json:"team_id" binding:"required"`
	DonorName     string     `json:"donor_name" binding:"required"`
	DonorPhone    *string    `json:"donor_phone,omitempty"`
	DonorEmail    *string    `json:"donor_email,omitempty"`
	DonorAddress  *string    `json:"donor_address,omitempty"`
	Latitude      *float64   `json:"latitude,omitempty"`
	Longitude     *float64   `json:"longitude,omitempty"`
	Amount        float64    `json:"amount" binding:"required,gt=0"`
	Currency      string     `json:"currency,omitempty"` // Defaults to "BDT"
	DonationType  string     `json:"donation_type" binding:"required"`
	Purpose       *string    `json:"purpose,omitempty"`
	PaymentMethod string     `json:"payment_method" binding:"required"`
	PaymentRef    *string    `json:"payment_ref,omitempty"`
	IsAnonymous   bool       `json:"is_anonymous"`
	Notes         *string    `json:"notes,omitempty"`
}

// ReceiptWithItems represents a receipt with its items
type ReceiptWithItems struct {
	Receipt *Receipt       `json:"receipt"`
	Items   []*ReceiptItem `json:"items"`
}

// ReceiptStats represents receipt statistics
type ReceiptStats struct {
	TotalReceipts      int     `json:"total_receipts"`
	TotalAmount        float64 `json:"total_amount"`
	BookSalesCount     int     `json:"book_sales_count"`
	BookSalesAmount    float64 `json:"book_sales_amount"`
	LiteratureCount    int     `json:"literature_count"`
	LiteratureAmount   float64 `json:"literature_amount"`
	DonationCount      int     `json:"donation_count"`
	DonationAmount     float64 `json:"donation_amount"`
	AverageReceiptValue float64 `json:"average_receipt_value"`
}

// DonationStats represents donation statistics
type DonationStats struct {
	TotalDonations      int     `json:"total_donations"`
	TotalAmount         float64 `json:"total_amount"`
	OneTimeDonations    int     `json:"one_time_donations"`
	OneTimeAmount       float64 `json:"one_time_amount"`
	RecurringDonations  int     `json:"recurring_donations"`
	RecurringAmount     float64 `json:"recurring_amount"`
	AverageDonation     float64 `json:"average_donation"`
	LargestDonation     float64 `json:"largest_donation"`
	AnonymousDonations  int     `json:"anonymous_donations"`
	PendingDeposit      float64 `json:"pending_deposit"`
}

// ReceiptRepository defines the interface for receipt data access
type ReceiptRepository interface {
	// Receipt management
	CreateReceipt(receipt *Receipt) error
	GetReceiptByID(id uuid.UUID) (*Receipt, error)
	GetReceiptByNumber(receiptNumber string) (*Receipt, error)
	GetReceiptsByWorkerID(workerID uuid.UUID, limit, offset int) ([]*Receipt, error)
	GetReceiptsByTeamID(teamID uuid.UUID, limit, offset int) ([]*Receipt, error)
	GetReceiptsBySessionID(sessionID uuid.UUID) ([]*Receipt, error)
	UpdateReceipt(receipt *Receipt) error
	DeleteReceipt(id uuid.UUID) error
	GenerateReceiptNumber(teamID uuid.UUID) (string, error)

	// Receipt items
	CreateReceiptItem(item *ReceiptItem) error
	GetItemsByReceiptID(receiptID uuid.UUID) ([]*ReceiptItem, error)
	DeleteReceiptItems(receiptID uuid.UUID) error

	// Donation management
	CreateDonation(donation *Donation) error
	GetDonationByID(id uuid.UUID) (*Donation, error)
	GetDonationsByWorkerID(workerID uuid.UUID, limit, offset int) ([]*Donation, error)
	GetDonationsByTeamID(teamID uuid.UUID, limit, offset int) ([]*Donation, error)
	GetDonationsBySessionID(sessionID uuid.UUID) ([]*Donation, error)
	UpdateDonation(donation *Donation) error
	DeleteDonation(id uuid.UUID) error
	MarkDonationDeposited(id uuid.UUID) error
	GenerateDonationReceiptNumber(teamID uuid.UUID) (string, error)

	// Statistics
	GetReceiptStats(teamID uuid.UUID, days int) (*ReceiptStats, error)
	GetWorkerReceiptStats(workerID uuid.UUID, days int) (*ReceiptStats, error)
	GetDonationStats(teamID uuid.UUID, days int) (*DonationStats, error)
	GetWorkerDonationStats(workerID uuid.UUID, days int) (*DonationStats, error)
}

// ReceiptService defines the interface for receipt business logic
type ReceiptService interface {
	// Receipt management
	CreateReceipt(workerID uuid.UUID, workerName string, req *CreateReceiptRequest) (*ReceiptWithItems, error)
	GetReceipt(id uuid.UUID) (*ReceiptWithItems, error)
	GetReceiptByNumber(receiptNumber string) (*ReceiptWithItems, error)
	GetWorkerReceipts(workerID uuid.UUID, limit, offset int) ([]*ReceiptWithItems, error)
	GetTeamReceipts(teamID uuid.UUID, limit, offset int) ([]*ReceiptWithItems, error)
	GetSessionReceipts(sessionID uuid.UUID) ([]*ReceiptWithItems, error)
	CancelReceipt(id uuid.UUID) error
	RefundReceipt(id uuid.UUID) error

	// Donation management
	CreateDonation(workerID uuid.UUID, workerName string, req *CreateDonationRequest) (*Donation, error)
	GetDonation(id uuid.UUID) (*Donation, error)
	GetWorkerDonations(workerID uuid.UUID, limit, offset int) ([]*Donation, error)
	GetTeamDonations(teamID uuid.UUID, limit, offset int) ([]*Donation, error)
	GetSessionDonations(sessionID uuid.UUID) ([]*Donation, error)
	MarkDonationDeposited(id uuid.UUID) error
	CancelDonation(id uuid.UUID) error

	// Statistics
	GetReceiptStats(teamID uuid.UUID, days int) (*ReceiptStats, error)
	GetWorkerReceiptStats(workerID uuid.UUID, days int) (*ReceiptStats, error)
	GetDonationStats(teamID uuid.UUID, days int) (*DonationStats, error)
	GetWorkerDonationStats(workerID uuid.UUID, days int) (*DonationStats, error)
}

// Constants for receipts and donations
const (
	// Receipt types
	ReceiptTypeBookSale   = "book_sale"
	ReceiptTypeLiterature = "literature"
	ReceiptTypeDonation   = "donation"

	// Receipt statuses
	ReceiptStatusPending   = "pending"
	ReceiptStatusCompleted = "completed"
	ReceiptStatusCancelled = "cancelled"
	ReceiptStatusRefunded  = "refunded"

	// Donation types
	DonationTypeOneTime   = "one_time"
	DonationTypeRecurring = "recurring"
	DonationTypePledge    = "pledge"

	// Donation statuses
	DonationStatusReceived  = "received"
	DonationStatusDeposited = "deposited"
	DonationStatusCancelled = "cancelled"

	// Payment methods
	PaymentMethodCash   = "cash"
	PaymentMethodMobile = "mobile"
	PaymentMethodCard   = "card"
	PaymentMethodCheck  = "check"

	// Default currency
	DefaultCurrency = "BDT"

	// Item types for receipts
	ReceiptItemTypeBook     = "book"
	ReceiptItemTypeMagazine = "magazine"
	ReceiptItemTypeTract    = "tract"
	ReceiptItemTypeBrochure = "brochure"
	ReceiptItemTypeOther    = "other"

	// Limits
	DefaultReceiptLimit  = 50
	DefaultDonationLimit = 50
	MaxReceiptLimit      = 200
	MaxDonationLimit     = 200
)
