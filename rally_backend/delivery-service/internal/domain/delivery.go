package domain

import (
	"time"

	"github.com/google/uuid"
)

// Delivery represents a delivery in the system
type Delivery struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	TeamID         uuid.UUID  `json:"team_id" db:"team_id"`
	WorkerID       uuid.UUID  `json:"worker_id" db:"worker_id"`
	WorkerName     string     `json:"worker_name" db:"worker_name"`
	RecipientName  string     `json:"recipient_name" db:"recipient_name"`
	RecipientPhone *string    `json:"recipient_phone,omitempty" db:"recipient_phone"`
	RecipientEmail *string    `json:"recipient_email,omitempty" db:"recipient_email"`
	Address        string     `json:"address" db:"address"`
	Latitude       float64    `json:"latitude" db:"latitude"`
	Longitude      float64    `json:"longitude" db:"longitude"`
	DeliveryType   string     `json:"delivery_type" db:"delivery_type"` // "door_to_door", "person_to_person", "donation"
	Priority       string     `json:"priority" db:"priority"`           // "low", "medium", "high", "urgent"
	Status         string     `json:"status" db:"status"`               // "pending", "completed", "failed", "cancelled"
	Notes          *string    `json:"notes,omitempty" db:"notes"`
	ScheduledDate  *time.Time `json:"scheduled_date,omitempty" db:"scheduled_date"`
	CompletedAt    *time.Time `json:"completed_at,omitempty" db:"completed_at"`

	// Territory context
	TerritoryID   *uuid.UUID `json:"territory_id,omitempty" db:"territory_id"`
	TerritoryName *string    `json:"territory_name,omitempty" db:"territory_name"`
	HouseholdID   *uuid.UUID `json:"household_id,omitempty" db:"household_id"`

	// Donation-specific fields (only for delivery_type = "donation")
	DonationAmount  *float64 `json:"donation_amount,omitempty" db:"donation_amount"`   // Amount in cents
	PaymentMethod   *string  `json:"payment_method,omitempty" db:"payment_method"`     // "cash", "card", "online"
	PaymentStatus   *string  `json:"payment_status,omitempty" db:"payment_status"`     // "pending", "completed", "failed"
	StripePaymentID *string  `json:"stripe_payment_id,omitempty" db:"stripe_payment_id"`
	ReceiptNumber   *string  `json:"receipt_number,omitempty" db:"receipt_number"`
	ReceiptURL      *string  `json:"receipt_url,omitempty" db:"receipt_url"`

	// Offline sync support
	IsOffline  bool       `json:"is_offline" db:"is_offline"`
	SyncedAt   *time.Time `json:"synced_at,omitempty" db:"synced_at"`
	OfflineID  *string    `json:"offline_id,omitempty" db:"offline_id"` // Client-generated ID for offline records

	CreatedBy uuid.UUID `json:"created_by" db:"created_by"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

// DeliveryItem represents items in a delivery
type DeliveryItem struct {
	ID          uuid.UUID `json:"id" db:"id"`
	DeliveryID  uuid.UUID `json:"delivery_id" db:"delivery_id"`
	ItemType    string    `json:"item_type" db:"item_type"` // "book", "magazine", "tract", "package", "other"
	ItemName    string    `json:"item_name" db:"item_name"`
	Quantity    int       `json:"quantity" db:"quantity"`
	Description *string   `json:"description,omitempty" db:"description"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// DeliveryUpdate represents status updates for deliveries
type DeliveryUpdate struct {
	ID         uuid.UUID `json:"id" db:"id"`
	DeliveryID uuid.UUID `json:"delivery_id" db:"delivery_id"`
	UserID     uuid.UUID `json:"user_id" db:"user_id"`
	UserName   string    `json:"user_name" db:"user_name"`
	Status     string    `json:"status" db:"status"`
	Message    *string   `json:"message,omitempty" db:"message"`
	Latitude   *float64  `json:"latitude,omitempty" db:"latitude"`
	Longitude  *float64  `json:"longitude,omitempty" db:"longitude"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

// DeliveryRoute represents optimized delivery routes
type DeliveryRoute struct {
	ID          uuid.UUID `json:"id" db:"id"`
	TeamID      uuid.UUID `json:"team_id" db:"team_id"`
	WorkerID    uuid.UUID `json:"worker_id" db:"worker_id"`
	WorkerName  string    `json:"worker_name" db:"worker_name"`
	RouteName   string    `json:"route_name" db:"route_name"`
	RouteDate   time.Time `json:"route_date" db:"route_date"`
	Status      string    `json:"status" db:"status"` // "planned", "active", "completed", "cancelled"
	TotalStops  int       `json:"total_stops" db:"total_stops"`
	CompletedStops int    `json:"completed_stops" db:"completed_stops"`
	EstimatedTime int     `json:"estimated_time" db:"estimated_time"` // minutes
	ActualTime    *int    `json:"actual_time,omitempty" db:"actual_time"` // minutes
	StartedAt     *time.Time `json:"started_at,omitempty" db:"started_at"`
	CompletedAt   *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	CreatedBy     uuid.UUID `json:"created_by" db:"created_by"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
}

// RouteStop represents stops in a delivery route
type RouteStop struct {
	ID         uuid.UUID `json:"id" db:"id"`
	RouteID    uuid.UUID `json:"route_id" db:"route_id"`
	DeliveryID uuid.UUID `json:"delivery_id" db:"delivery_id"`
	StopOrder  int       `json:"stop_order" db:"stop_order"`
	Status     string    `json:"status" db:"status"` // "pending", "completed", "skipped"
	ArrivedAt  *time.Time `json:"arrived_at,omitempty" db:"arrived_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

// CreateDeliveryRequest represents the request to create a delivery
type CreateDeliveryRequest struct {
	TeamID         uuid.UUID                   `json:"team_id" binding:"required"`
	WorkerID       *uuid.UUID                  `json:"worker_id,omitempty"`
	WorkerName     string                      `json:"worker_name,omitempty"`
	RecipientName  string                      `json:"recipient_name" binding:"required"`
	RecipientPhone string                      `json:"recipient_phone,omitempty"`
	RecipientEmail string                      `json:"recipient_email,omitempty"`
	Address        string                      `json:"address" binding:"required"`
	Latitude       float64                     `json:"latitude" binding:"required"`
	Longitude      float64                     `json:"longitude" binding:"required"`
	DeliveryType   string                      `json:"delivery_type" binding:"required"` // door_to_door, person_to_person, donation
	Priority       string                      `json:"priority"`                         // defaults to medium
	Notes          string                      `json:"notes,omitempty"`
	ScheduledDate  *time.Time                  `json:"scheduled_date,omitempty"`
	Items          []CreateDeliveryItemRequest `json:"items"` // Required for door_to_door and person_to_person

	// Territory context
	TerritoryID   *uuid.UUID `json:"territory_id,omitempty"`
	TerritoryName string     `json:"territory_name,omitempty"`
	HouseholdID   *uuid.UUID `json:"household_id,omitempty"`

	// Donation fields (only for delivery_type = "donation")
	DonationAmount float64 `json:"donation_amount,omitempty"` // Amount in cents
	PaymentMethod  string  `json:"payment_method,omitempty"`  // "cash", "card", "online"

	// Offline support
	OfflineID string `json:"offline_id,omitempty"` // Client-generated ID for offline records
}

// CreateDeliveryItemRequest represents an item in delivery creation
type CreateDeliveryItemRequest struct {
	ItemType    string `json:"item_type" binding:"required"`
	ItemName    string `json:"item_name" binding:"required"`
	Quantity    int    `json:"quantity" binding:"required,min=1"`
	Description string `json:"description,omitempty"`
}

// UpdateDeliveryRequest represents the request to update a delivery
type UpdateDeliveryRequest struct {
	WorkerID       *uuid.UUID `json:"worker_id,omitempty"`
	RecipientName  *string    `json:"recipient_name,omitempty"`
	RecipientPhone *string    `json:"recipient_phone,omitempty"`
	RecipientEmail *string    `json:"recipient_email,omitempty"`
	Address        *string    `json:"address,omitempty"`
	Latitude       *float64   `json:"latitude,omitempty"`
	Longitude      *float64   `json:"longitude,omitempty"`
	DeliveryType   *string    `json:"delivery_type,omitempty"`
	Priority       *string    `json:"priority,omitempty"`
	Status         *string    `json:"status,omitempty"`
	Notes          *string    `json:"notes,omitempty"`
	ScheduledDate  *time.Time `json:"scheduled_date,omitempty"`

	// Donation fields
	DonationAmount *float64 `json:"donation_amount,omitempty"`
	PaymentMethod  *string  `json:"payment_method,omitempty"`
	PaymentStatus  *string  `json:"payment_status,omitempty"`
}

// UpdateDeliveryStatusRequest represents status update request
type UpdateDeliveryStatusRequest struct {
	Status    string   `json:"status" binding:"required"`
	Message   string   `json:"message,omitempty"`
	Latitude  *float64 `json:"latitude,omitempty"`
	Longitude *float64 `json:"longitude,omitempty"`
}

// CreateRouteRequest represents the request to create a delivery route
type CreateRouteRequest struct {
	TeamID        uuid.UUID   `json:"team_id" binding:"required"`
	WorkerID      uuid.UUID   `json:"worker_id" binding:"required"`
	RouteName     string      `json:"route_name" binding:"required"`
	RouteDate     time.Time   `json:"route_date" binding:"required"`
	DeliveryIDs   []uuid.UUID `json:"delivery_ids" binding:"required,min=1"`
	EstimatedTime int         `json:"estimated_time,omitempty"`
}

// DeliveryWithItems represents a delivery with its items
type DeliveryWithItems struct {
	Delivery *Delivery       `json:"delivery"`
	Items    []*DeliveryItem `json:"items"`
}

// RouteWithStops represents a route with its stops and deliveries
type RouteWithStops struct {
	Route     *DeliveryRoute    `json:"route"`
	Stops     []*RouteStopWithDelivery `json:"stops"`
}

// RouteStopWithDelivery represents a route stop with delivery details
type RouteStopWithDelivery struct {
	Stop     *RouteStop        `json:"stop"`
	Delivery *DeliveryWithItems `json:"delivery"`
}

// DeliveryStats represents delivery statistics
type DeliveryStats struct {
	TotalDeliveries    int     `json:"total_deliveries"`
	PendingDeliveries  int     `json:"pending_deliveries"`
	InProgressDeliveries int   `json:"in_progress_deliveries"`
	CompletedDeliveries int    `json:"completed_deliveries"`
	FailedDeliveries   int     `json:"failed_deliveries"`
	CompletionRate     float64 `json:"completion_rate"`
	AverageDeliveryTime float64 `json:"average_delivery_time"`
	TotalRoutes        int     `json:"total_routes"`
	ActiveRoutes       int     `json:"active_routes"`
}

// WorkerStats represents worker delivery statistics
type WorkerStats struct {
	WorkerID            uuid.UUID `json:"worker_id"`
	WorkerName          string    `json:"worker_name"`
	TotalDeliveries     int       `json:"total_deliveries"`
	CompletedDeliveries int       `json:"completed_deliveries"`
	FailedDeliveries    int       `json:"failed_deliveries"`
	CompletionRate      float64   `json:"completion_rate"`
	AverageDeliveryTime float64   `json:"average_delivery_time"`
	TotalDistance       float64   `json:"total_distance"`
	TotalRoutes         int       `json:"total_routes"`
}

// DonationView represents a delivery with delivery_type='donation' formatted for admin consumption
type DonationView struct {
	ID            uuid.UUID  `json:"id"`
	SessionID     *uuid.UUID `json:"session_id,omitempty"`
	WorkerID      uuid.UUID  `json:"worker_id"`
	WorkerName    string     `json:"worker_name"`
	TeamID        uuid.UUID  `json:"team_id"`
	DonorName     string     `json:"donor_name"`
	DonorPhone    *string    `json:"donor_phone,omitempty"`
	DonorEmail    *string    `json:"donor_email,omitempty"`
	DonorAddress  string     `json:"donor_address,omitempty"`
	Latitude      float64    `json:"latitude"`
	Longitude     float64    `json:"longitude"`
	Amount        float64    `json:"amount"`
	Currency      string     `json:"currency"`
	DonationType  string     `json:"donation_type"`
	Purpose       *string    `json:"purpose,omitempty"`
	PaymentMethod string     `json:"payment_method"`
	PaymentRef    *string    `json:"payment_ref,omitempty"`
	ReceiptNumber string     `json:"receipt_number"`
	IsAnonymous   bool       `json:"is_anonymous"`
	Notes         *string    `json:"notes,omitempty"`
	Status        string     `json:"status"`
	CollectedAt   *time.Time `json:"collected_at,omitempty"`
	DepositedAt   *time.Time `json:"deposited_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

// DonationDeliveryStats represents donation statistics derived from the deliveries table
type DonationDeliveryStats struct {
	TotalDonations     int     `json:"total_donations"`
	TotalAmount        float64 `json:"total_amount"`
	OneTimeDonations   int     `json:"one_time_donations"`
	OneTimeAmount      float64 `json:"one_time_amount"`
	RecurringDonations int     `json:"recurring_donations"`
	RecurringAmount    float64 `json:"recurring_amount"`
	AverageDonation    float64 `json:"average_donation"`
	LargestDonation    float64 `json:"largest_donation"`
	AnonymousDonations int     `json:"anonymous_donations"`
	PendingDeposit     float64 `json:"pending_deposit"`
}

// DeliveryRepository defines the interface for delivery data access
type DeliveryRepository interface {
	// Delivery management
	CreateDelivery(delivery *Delivery) error
	GetDeliveryByID(id uuid.UUID) (*Delivery, error)
	GetDeliveriesByTeamID(teamID uuid.UUID, limit, offset int) ([]*Delivery, error)
	GetDeliveriesByWorkerID(workerID uuid.UUID, limit, offset int) ([]*Delivery, error)
	GetDeliveriesByStatus(teamID uuid.UUID, status string, limit, offset int) ([]*Delivery, error)
	UpdateDelivery(delivery *Delivery) error
	DeleteDelivery(id uuid.UUID) error
	
	// Delivery items
	CreateDeliveryItem(item *DeliveryItem) error
	GetItemsByDeliveryID(deliveryID uuid.UUID) ([]*DeliveryItem, error)
	UpdateDeliveryItem(item *DeliveryItem) error
	DeleteDeliveryItem(id uuid.UUID) error
	
	// Delivery updates
	CreateDeliveryUpdate(update *DeliveryUpdate) error
	GetUpdatesByDeliveryID(deliveryID uuid.UUID) ([]*DeliveryUpdate, error)
	
	// Route management
	CreateRoute(route *DeliveryRoute) error
	GetRouteByID(id uuid.UUID) (*DeliveryRoute, error)
	GetRoutesByTeamID(teamID uuid.UUID, limit, offset int) ([]*DeliveryRoute, error)
	GetRoutesByWorkerID(workerID uuid.UUID, limit, offset int) ([]*DeliveryRoute, error)
	UpdateRoute(route *DeliveryRoute) error
	DeleteRoute(id uuid.UUID) error
	
	// Route stops
	CreateRouteStop(stop *RouteStop) error
	GetStopsByRouteID(routeID uuid.UUID) ([]*RouteStop, error)
	UpdateRouteStop(stop *RouteStop) error
	
	// Statistics
	GetDeliveryStats(teamID uuid.UUID, days int) (*DeliveryStats, error)
	GetWorkerStats(workerID uuid.UUID, days int) (*WorkerStats, error)
	GetTeamWorkerStats(teamID uuid.UUID, days int) ([]*WorkerStats, error)

	// Donation deliveries (delivery_type = 'donation')
	GetAllDonationDeliveries(limit, offset int) ([]*Delivery, error)
	GetTeamDonationDeliveries(teamID uuid.UUID, limit, offset int) ([]*Delivery, error)
	GetGlobalDonationDeliveryStats(days int) (*DonationDeliveryStats, error)
	GetTeamDonationDeliveryStats(teamID uuid.UUID, days int) (*DonationDeliveryStats, error)
}

// DeliveryService defines the interface for delivery business logic
type DeliveryService interface {
	// Delivery management
	CreateDelivery(creatorID uuid.UUID, req *CreateDeliveryRequest) (*DeliveryWithItems, error)
	GetDelivery(id uuid.UUID) (*DeliveryWithItems, error)
	UpdateDelivery(id uuid.UUID, req *UpdateDeliveryRequest) (*Delivery, error)
	DeleteDelivery(id uuid.UUID) error
	GetTeamDeliveries(teamID uuid.UUID, status string, limit, offset int) ([]*DeliveryWithItems, error)
	GetWorkerDeliveries(workerID uuid.UUID, limit, offset int) ([]*DeliveryWithItems, error)
	
	// Delivery status management
	UpdateDeliveryStatus(deliveryID, userID uuid.UUID, req *UpdateDeliveryStatusRequest) error
	AssignDelivery(deliveryID, workerID, assignerID uuid.UUID) error
	StartDelivery(deliveryID, workerID uuid.UUID) error
	CompleteDelivery(deliveryID, workerID uuid.UUID, req *UpdateDeliveryStatusRequest) error
	
	// Route management
	CreateRoute(creatorID uuid.UUID, req *CreateRouteRequest) (*RouteWithStops, error)
	GetRoute(id uuid.UUID) (*RouteWithStops, error)
	GetTeamRoutes(teamID uuid.UUID, limit, offset int) ([]*DeliveryRoute, error)
	GetWorkerRoutes(workerID uuid.UUID, limit, offset int) ([]*DeliveryRoute, error)
	StartRoute(routeID, workerID uuid.UUID) error
	CompleteRoute(routeID, workerID uuid.UUID) error
	OptimizeRoute(routeID uuid.UUID) (*RouteWithStops, error)
	
	// Statistics and analytics
	GetDeliveryStats(teamID uuid.UUID, days int) (*DeliveryStats, error)
	GetWorkerStats(workerID uuid.UUID, days int) (*WorkerStats, error)
	GetTeamWorkerStats(teamID uuid.UUID, days int) ([]*WorkerStats, error)

	// Donation deliveries (delivery_type = 'donation')
	GetAllDonationDeliveries(limit, offset int) ([]*DonationView, error)
	GetTeamDonationDeliveries(teamID uuid.UUID, limit, offset int) ([]*DonationView, error)
	GetGlobalDonationDeliveryStats(days int) (*DonationDeliveryStats, error)
	GetTeamDonationDeliveryStats(teamID uuid.UUID, days int) (*DonationDeliveryStats, error)
}

// RouteOptimizer defines the interface for route optimization
type RouteOptimizer interface {
	OptimizeRoute(deliveries []*Delivery, startLocation LocationPoint) ([]*Delivery, error)
	CalculateRouteDistance(deliveries []*Delivery) (float64, error)
	EstimateRouteTime(deliveries []*Delivery) (int, error)
}

// TerritoryClient defines the interface for communicating with the territory service
type TerritoryClient interface {
	// RecordVisit records a visit/delivery completion for a worker's territory assignment
	RecordVisit(territoryID, workerID uuid.UUID) error
}

// LocationPoint represents a geographic point
type LocationPoint struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// Constants
const (
	// Delivery types (simplified)
	DeliveryTypeDoorToDoor     = "door_to_door"     // Literature delivery to address
	DeliveryTypePersonToPerson = "person_to_person" // Direct handoff to specific person
	DeliveryTypeDonation       = "donation"         // Donation collection

	// Priority levels
	PriorityLow    = "low"
	PriorityMedium = "medium"
	PriorityHigh   = "high"
	PriorityUrgent = "urgent"

	// Delivery statuses (simplified - worker-centric)
	StatusPending    = "pending"   // Created, waiting to be done
	StatusCompleted  = "completed" // Delivery/donation completed
	StatusFailed     = "failed"    // Couldn't complete
	StatusCancelled  = "cancelled" // Cancelled by user
	
	// Route statuses
	RouteStatusPlanned   = "planned"
	RouteStatusActive    = "active"
	RouteStatusCompleted = "completed"
	RouteStatusCancelled = "cancelled"
	
	// Stop statuses
	StopStatusPending   = "pending"
	StopStatusCompleted = "completed"
	StopStatusSkipped   = "skipped"

	// Item types (literature only)
	ItemTypeBook     = "book"
	ItemTypeMagazine = "magazine"
	ItemTypeTract    = "tract"
	ItemTypeBrochure = "brochure"
	ItemTypeOther    = "other"

	// Payment statuses (for donations)
	PaymentStatusPending   = "pending"
	PaymentStatusCompleted = "completed"
	PaymentStatusFailed    = "failed"
	PaymentStatusRefunded  = "refunded"

	// Payment methods are defined in receipt.go
	
	// Default values
	DefaultDeliveryLimit = 50
	DefaultRouteLimit    = 20
	MaxDeliveryLimit     = 200
	MaxRouteLimit        = 100
	
	// Statistics
	DefaultStatsDays = 30
	MaxStatsDays     = 365
)
