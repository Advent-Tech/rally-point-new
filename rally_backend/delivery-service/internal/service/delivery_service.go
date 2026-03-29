package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
	"rally-point/delivery-service/internal/domain"
)

type deliveryService struct {
	deliveryRepo       domain.DeliveryRepository
	routeOptimizer     domain.RouteOptimizer
	territoryClient    domain.TerritoryClient
	nc                 *nats.Conn
	achievementService *AchievementService
}

// NewDeliveryService creates a new delivery service
func NewDeliveryService(deliveryRepo domain.DeliveryRepository, routeOptimizer domain.RouteOptimizer, territoryClient domain.TerritoryClient, nc *nats.Conn) domain.DeliveryService {
	return &deliveryService{
		deliveryRepo:    deliveryRepo,
		routeOptimizer:  routeOptimizer,
		territoryClient: territoryClient,
		nc:              nc,
	}
}

// NewDeliveryServiceWithAchievements creates a delivery service with achievement checking
func NewDeliveryServiceWithAchievements(deliveryRepo domain.DeliveryRepository, routeOptimizer domain.RouteOptimizer, territoryClient domain.TerritoryClient, nc *nats.Conn, achievementSvc *AchievementService) domain.DeliveryService {
	return &deliveryService{
		deliveryRepo:       deliveryRepo,
		routeOptimizer:     routeOptimizer,
		territoryClient:    territoryClient,
		nc:                 nc,
		achievementService: achievementSvc,
	}
}

// publishNotify publishes a notification event to NATS
func (s *deliveryService) publishNotify(subject string, event map[string]interface{}) {
	if s.nc == nil {
		return
	}
	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("Failed to marshal notification: %v", err)
		return
	}
	if err := s.nc.Publish(subject, data); err != nil {
		log.Printf("Failed to publish notification %s: %v", subject, err)
	}
}

// CreateDelivery creates a new delivery with items
func (s *deliveryService) CreateDelivery(creatorID uuid.UUID, req *domain.CreateDeliveryRequest) (*domain.DeliveryWithItems, error) {
	// Validate request based on delivery type
	isDonation := req.DeliveryType == domain.DeliveryTypeDonation
	isBookSale := req.DeliveryType == domain.DeliveryTypeBookSale
	if !isDonation && !isBookSale && len(req.Items) == 0 {
		return nil, fmt.Errorf("literature delivery must have at least one item")
	}
	if isBookSale {
		if req.BookTitle == "" {
			return nil, fmt.Errorf("book_title is required for book_sale")
		}
		if req.BookQuantity <= 0 {
			return nil, fmt.Errorf("book_quantity must be greater than 0 for book_sale")
		}
		if req.BookUnitPrice <= 0 {
			return nil, fmt.Errorf("book_unit_price must be greater than 0 for book_sale")
		}
	}

	// Determine worker ID - use provided worker or creator as default
	workerID := creatorID
	if req.WorkerID != nil {
		workerID = *req.WorkerID
	}

	// Determine worker name - use provided name or fallback
	workerName := req.WorkerName
	if workerName == "" {
		workerName = "Worker"
	}

	// Set default priority if not provided
	priority := req.Priority
	if priority == "" {
		priority = domain.PriorityMedium
	}

	// Determine initial status:
	// If donation_amount > 0, it means payment was collected on the spot
	// So we auto-complete the delivery
	initialStatus := domain.StatusPending
	var completedAt *time.Time
	if req.DonationAmount > 0 {
		initialStatus = domain.StatusCompleted
		now := time.Now()
		completedAt = &now
	}

	// Create delivery
	delivery := &domain.Delivery{
		ID:            uuid.New(),
		TeamID:        req.TeamID,
		WorkerID:      workerID,
		WorkerName:    workerName,
		RecipientName: req.RecipientName,
		Address:       req.Address,
		Latitude:      req.Latitude,
		Longitude:     req.Longitude,
		DeliveryType:  req.DeliveryType,
		Priority:      priority,
		Status:        initialStatus,
		CompletedAt:   completedAt,
		ScheduledDate: req.ScheduledDate,
		TerritoryID:   req.TerritoryID,
		HouseholdID:   req.HouseholdID,
		CreatedBy:     creatorID,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}

	// Set territory name if provided
	if req.TerritoryName != "" {
		delivery.TerritoryName = &req.TerritoryName
	}

	// Set optional fields
	if req.RecipientPhone != "" {
		delivery.RecipientPhone = &req.RecipientPhone
	}
	if req.RecipientEmail != "" {
		delivery.RecipientEmail = &req.RecipientEmail
	}
	if req.Notes != "" {
		delivery.Notes = &req.Notes
	}

	// Set payment/donation fields (applicable to both donations and book sales)
	if req.DonationAmount > 0 {
		delivery.DonationAmount = &req.DonationAmount
	}
	if req.PaymentMethod != "" {
		delivery.PaymentMethod = &req.PaymentMethod
		// Cash payments are immediately marked as completed
		if req.PaymentMethod == domain.PaymentMethodCash {
			status := domain.PaymentStatusCompleted
			delivery.PaymentStatus = &status
		} else {
			status := domain.PaymentStatusPending
			delivery.PaymentStatus = &status
		}
	}

	// Handle offline sync
	if req.OfflineID != "" {
		delivery.OfflineID = &req.OfflineID
		delivery.IsOffline = true
	}

	err := s.deliveryRepo.CreateDelivery(delivery)
	if err != nil {
		return nil, fmt.Errorf("failed to create delivery: %w", err)
	}

	// Create delivery items
	var items []*domain.DeliveryItem
	if isBookSale {
		bookItemName := req.BookTitle
		if req.BookCode != "" {
			bookItemName = fmt.Sprintf("%s (%s)", req.BookTitle, req.BookCode)
		}
		bookDescription := ""
		if req.BookLanguage != "" {
			bookDescription = fmt.Sprintf("language=%s", req.BookLanguage)
		}
		bookItem := &domain.DeliveryItem{
			ID:          uuid.New(),
			DeliveryID:  delivery.ID,
			ItemType:    domain.ItemTypeBook,
			ItemName:    bookItemName,
			Quantity:    req.BookQuantity,
			Description: &bookDescription,
			CreatedAt:   time.Now(),
		}
		if err := s.deliveryRepo.CreateDeliveryItem(bookItem); err != nil {
			return nil, fmt.Errorf("failed to create book sale item: %w", err)
		}
		items = append(items, bookItem)
	}

	for _, itemReq := range req.Items {
		item := &domain.DeliveryItem{
			ID:         uuid.New(),
			DeliveryID: delivery.ID,
			ItemType:   itemReq.ItemType,
			ItemName:   itemReq.ItemName,
			Quantity:   itemReq.Quantity,
			CreatedAt:  time.Now(),
		}

		if itemReq.Description != "" {
			item.Description = &itemReq.Description
		}

		err := s.deliveryRepo.CreateDeliveryItem(item)
		if err != nil {
			return nil, fmt.Errorf("failed to create delivery item: %w", err)
		}

		items = append(items, item)
	}

	result := &domain.DeliveryWithItems{
		Delivery: delivery,
		Items:    items,
	}

	// Publish notification — notify team leader about new donation/delivery recorded by worker
	if delivery.TeamID != uuid.Nil {
		notifTitle := fmt.Sprintf("New donation from %s", delivery.RecipientName)
		notifBody := fmt.Sprintf("Recorded by %s", delivery.WorkerName)
		if isBookSale {
			notifTitle = fmt.Sprintf("New book sale: %s", delivery.RecipientName)
			notifBody = fmt.Sprintf("%s sold by %s", req.BookTitle, delivery.WorkerName)
		} else if !isDonation {
			notifTitle = fmt.Sprintf("New literature delivery: %s", delivery.RecipientName)
			notifBody = fmt.Sprintf("Delivery to %s", delivery.Address)
		}
		s.publishNotify("notify.delivery.recorded", map[string]interface{}{
			"event_type":        "delivery.recorded",
			"target_type":       "team_leader",
			"target_id":         delivery.TeamID.String(),
			"actor_id":          creatorID.String(),
			"title":             notifTitle,
			"body":              notifBody,
			"data":              map[string]interface{}{"delivery_id": delivery.ID.String(), "team_id": delivery.TeamID.String()},
			"priority":          "normal",
			"notification_type": "delivery",
			"group_key":         "delivery:" + delivery.ID.String(),
			"created_at":        time.Now().Format(time.RFC3339),
		})
	}

	return result, nil
}

// GetDelivery retrieves a delivery with its items
func (s *deliveryService) GetDelivery(id uuid.UUID) (*domain.DeliveryWithItems, error) {
	delivery, err := s.deliveryRepo.GetDeliveryByID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get delivery: %w", err)
	}

	items, err := s.deliveryRepo.GetItemsByDeliveryID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get delivery items: %w", err)
	}

	return &domain.DeliveryWithItems{
		Delivery: delivery,
		Items:    items,
	}, nil
}

// UpdateDelivery updates a delivery
func (s *deliveryService) UpdateDelivery(id uuid.UUID, req *domain.UpdateDeliveryRequest) (*domain.Delivery, error) {
	delivery, err := s.deliveryRepo.GetDeliveryByID(id)
	if err != nil {
		return nil, fmt.Errorf("delivery not found: %w", err)
	}

	// Update fields if provided
	if req.WorkerID != nil {
		delivery.WorkerID = *req.WorkerID
	}
	if req.RecipientName != nil {
		delivery.RecipientName = *req.RecipientName
	}
	if req.RecipientPhone != nil {
		delivery.RecipientPhone = req.RecipientPhone
	}
	if req.RecipientEmail != nil {
		delivery.RecipientEmail = req.RecipientEmail
	}
	if req.Address != nil {
		delivery.Address = *req.Address
	}
	if req.Latitude != nil {
		delivery.Latitude = *req.Latitude
	}
	if req.Longitude != nil {
		delivery.Longitude = *req.Longitude
	}
	if req.DeliveryType != nil {
		delivery.DeliveryType = *req.DeliveryType
	}
	if req.Priority != nil {
		delivery.Priority = *req.Priority
	}
	if req.Status != nil {
		delivery.Status = *req.Status
	}
	if req.Notes != nil {
		delivery.Notes = req.Notes
	}
	if req.ScheduledDate != nil {
		delivery.ScheduledDate = req.ScheduledDate
	}

	// Update donation fields
	if req.DonationAmount != nil {
		delivery.DonationAmount = req.DonationAmount
	}
	if req.PaymentMethod != nil {
		delivery.PaymentMethod = req.PaymentMethod
	}
	if req.PaymentStatus != nil {
		delivery.PaymentStatus = req.PaymentStatus
	}

	delivery.UpdatedAt = time.Now()

	err = s.deliveryRepo.UpdateDelivery(delivery)
	if err != nil {
		return nil, fmt.Errorf("failed to update delivery: %w", err)
	}

	return delivery, nil
}

// DeleteDelivery deletes a delivery
func (s *deliveryService) DeleteDelivery(id uuid.UUID) error {
	return s.deliveryRepo.DeleteDelivery(id)
}

// GetTeamDeliveries retrieves deliveries for a team
func (s *deliveryService) GetTeamDeliveries(teamID uuid.UUID, status string, limit, offset int) ([]*domain.DeliveryWithItems, error) {
	if limit <= 0 {
		limit = domain.DefaultDeliveryLimit
	}
	if limit > domain.MaxDeliveryLimit {
		limit = domain.MaxDeliveryLimit
	}

	var deliveries []*domain.Delivery
	var err error

	if status != "" {
		deliveries, err = s.deliveryRepo.GetDeliveriesByStatus(teamID, status, limit, offset)
	} else {
		deliveries, err = s.deliveryRepo.GetDeliveriesByTeamID(teamID, limit, offset)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to get deliveries: %w", err)
	}

	return s.enrichDeliveriesWithItems(deliveries)
}

// GetWorkerDeliveries retrieves deliveries for a worker
func (s *deliveryService) GetWorkerDeliveries(workerID uuid.UUID, limit, offset int) ([]*domain.DeliveryWithItems, error) {
	if limit <= 0 {
		limit = domain.DefaultDeliveryLimit
	}
	if limit > domain.MaxDeliveryLimit {
		limit = domain.MaxDeliveryLimit
	}

	deliveries, err := s.deliveryRepo.GetDeliveriesByWorkerID(workerID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker deliveries: %w", err)
	}

	return s.enrichDeliveriesWithItems(deliveries)
}

// UpdateDeliveryStatus updates delivery status with tracking
func (s *deliveryService) UpdateDeliveryStatus(deliveryID, userID uuid.UUID, req *domain.UpdateDeliveryStatusRequest) error {
	delivery, err := s.deliveryRepo.GetDeliveryByID(deliveryID)
	if err != nil {
		return fmt.Errorf("delivery not found: %w", err)
	}

	// Update delivery status
	delivery.Status = req.Status
	now := time.Now()
	delivery.UpdatedAt = now

	// Set completed timestamp for terminal states
	if req.Status == domain.StatusCompleted || req.Status == domain.StatusFailed {
		delivery.CompletedAt = &now
	}

	err = s.deliveryRepo.UpdateDelivery(delivery)
	if err != nil {
		return fmt.Errorf("failed to update delivery: %w", err)
	}

	// Create status update record
	update := &domain.DeliveryUpdate{
		ID:         uuid.New(),
		DeliveryID: deliveryID,
		UserID:     userID,
		UserName:   "User", // Would fetch from user service
		Status:     req.Status,
		Latitude:   req.Latitude,
		Longitude:  req.Longitude,
		CreatedAt:  now,
	}

	if req.Message != "" {
		update.Message = &req.Message
	}

	err = s.deliveryRepo.CreateDeliveryUpdate(update)
	if err != nil {
		return err
	}

	// Publish notification — notify team leader about status change
	s.publishNotify("notify.delivery.status_changed", map[string]interface{}{
		"event_type":        "delivery.status_changed",
		"target_type":       "team_leader",
		"target_id":         delivery.TeamID.String(),
		"actor_id":          userID.String(),
		"title":             fmt.Sprintf("Donation %s", req.Status),
		"body":              fmt.Sprintf("Donation from %s is now %s", delivery.RecipientName, req.Status),
		"data":              map[string]interface{}{"delivery_id": deliveryID.String(), "status": req.Status},
		"priority":          "normal",
		"notification_type": "delivery",
		"group_key":         "delivery:" + deliveryID.String(),
		"created_at":        time.Now().Format(time.RFC3339),
	})

	// Record territory visit when delivery is completed
	// This updates the territory completion percentage
	if req.Status == domain.StatusCompleted && delivery.TerritoryID != nil && s.territoryClient != nil {
		// Best effort - don't fail the delivery if territory service is unavailable
		_ = s.territoryClient.RecordVisit(*delivery.TerritoryID, delivery.WorkerID)

		// Check achievements for visit in background
		if s.achievementService != nil {
			go func() {
				s.checkVisitAchievements(context.Background(), delivery.WorkerID)
			}()
		}
	}

	return nil
}

func (s *deliveryService) checkVisitAchievements(ctx context.Context, workerID uuid.UUID) {
	if s.achievementService == nil {
		return
	}

	// Get worker's completed visit count from delivery repo
	count, err := s.deliveryRepo.GetCompletedVisitCount(workerID)
	if err != nil {
		return
	}

	// Check visit count achievements
	s.achievementService.CheckAndAwardAchievements(ctx, workerID, "visit", float64(count))

	// Also check territory completion achievements (when a delivery with territory is completed)
	territoryCount, err := s.deliveryRepo.GetCompletedTerritoryCount(workerID)
	if err != nil {
		return
	}

	// Check territory count achievements
	s.achievementService.CheckAndAwardAchievements(ctx, workerID, "territory", float64(territoryCount))
}

// AssignDelivery assigns a delivery to a worker (optional - worker can self-assign)
func (s *deliveryService) AssignDelivery(deliveryID, workerID, assignerID uuid.UUID) error {
	delivery, err := s.deliveryRepo.GetDeliveryByID(deliveryID)
	if err != nil {
		return fmt.Errorf("delivery not found: %w", err)
	}

	if delivery.Status != domain.StatusPending {
		return fmt.Errorf("delivery cannot be assigned in current status: %s", delivery.Status)
	}

	delivery.WorkerID = workerID
	delivery.WorkerName = "Worker" // In real implementation, fetch from user service
	delivery.UpdatedAt = time.Now()

	return s.deliveryRepo.UpdateDelivery(delivery)
}

// StartDelivery is deprecated - deliveries go directly from pending to completed
func (s *deliveryService) StartDelivery(deliveryID, workerID uuid.UUID) error {
	// No-op for backwards compatibility - status goes directly to completed
	return nil
}

// CompleteDelivery marks a delivery as completed
func (s *deliveryService) CompleteDelivery(deliveryID, workerID uuid.UUID, req *domain.UpdateDeliveryStatusRequest) error {
	delivery, err := s.deliveryRepo.GetDeliveryByID(deliveryID)
	if err != nil {
		return fmt.Errorf("delivery not found: %w", err)
	}

	if delivery.WorkerID == uuid.Nil || delivery.WorkerID != workerID {
		return fmt.Errorf("delivery not assigned to this worker")
	}

	if delivery.Status != domain.StatusPending {
		return fmt.Errorf("delivery cannot be completed in current status: %s", delivery.Status)
	}

	// Force status to completed
	req.Status = domain.StatusCompleted
	return s.UpdateDeliveryStatus(deliveryID, workerID, req)
}

// CreateRoute creates a new delivery route
func (s *deliveryService) CreateRoute(creatorID uuid.UUID, req *domain.CreateRouteRequest) (*domain.RouteWithStops, error) {
	// Validate deliveries exist and are available
	var deliveries []*domain.Delivery
	for _, deliveryID := range req.DeliveryIDs {
		delivery, err := s.deliveryRepo.GetDeliveryByID(deliveryID)
		if err != nil {
			return nil, fmt.Errorf("delivery %s not found", deliveryID)
		}
		if delivery.Status != domain.StatusPending {
			return nil, fmt.Errorf("delivery %s cannot be added to route (status: %s)", deliveryID, delivery.Status)
		}
		deliveries = append(deliveries, delivery)
	}

	// Optimize route if optimizer is available
	if s.routeOptimizer != nil {
		optimizedDeliveries, err := s.routeOptimizer.OptimizeRoute(deliveries, domain.LocationPoint{
			Latitude:  deliveries[0].Latitude,
			Longitude: deliveries[0].Longitude,
		})
		if err == nil {
			deliveries = optimizedDeliveries
		}
	}

	// Create route
	route := &domain.DeliveryRoute{
		ID:            uuid.New(),
		TeamID:        req.TeamID,
		WorkerID:      req.WorkerID,
		WorkerName:    "Worker", // Would fetch from user service
		RouteName:     req.RouteName,
		RouteDate:     req.RouteDate,
		Status:        domain.RouteStatusPlanned,
		TotalStops:    len(deliveries),
		EstimatedTime: req.EstimatedTime,
		CreatedBy:     creatorID,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}

	// Calculate estimated time if not provided
	if route.EstimatedTime == 0 && s.routeOptimizer != nil {
		if estimatedTime, err := s.routeOptimizer.EstimateRouteTime(deliveries); err == nil {
			route.EstimatedTime = estimatedTime
		}
	}

	err := s.deliveryRepo.CreateRoute(route)
	if err != nil {
		return nil, fmt.Errorf("failed to create route: %w", err)
	}

	// Create route stops
	var stops []*domain.RouteStopWithDelivery
	for i, delivery := range deliveries {
		stop := &domain.RouteStop{
			ID:         uuid.New(),
			RouteID:    route.ID,
			DeliveryID: delivery.ID,
			StopOrder:  i + 1,
			Status:     domain.StopStatusPending,
			CreatedAt:  time.Now(),
		}

		err := s.deliveryRepo.CreateRouteStop(stop)
		if err != nil {
			return nil, fmt.Errorf("failed to create route stop: %w", err)
		}

		// Get delivery items
		items, _ := s.deliveryRepo.GetItemsByDeliveryID(delivery.ID)

		stops = append(stops, &domain.RouteStopWithDelivery{
			Stop: stop,
			Delivery: &domain.DeliveryWithItems{
				Delivery: delivery,
				Items:    items,
			},
		})

		// Assign worker to delivery if not already assigned
		if delivery.WorkerID == uuid.Nil {
			delivery.WorkerID = req.WorkerID
			delivery.UpdatedAt = time.Now()
			s.deliveryRepo.UpdateDelivery(delivery)
		}
	}

	return &domain.RouteWithStops{
		Route: route,
		Stops: stops,
	}, nil
}

// GetRoute retrieves a route with its stops
func (s *deliveryService) GetRoute(id uuid.UUID) (*domain.RouteWithStops, error) {
	route, err := s.deliveryRepo.GetRouteByID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get route: %w", err)
	}

	stops, err := s.deliveryRepo.GetStopsByRouteID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get route stops: %w", err)
	}

	var stopsWithDeliveries []*domain.RouteStopWithDelivery
	for _, stop := range stops {
		delivery, err := s.deliveryRepo.GetDeliveryByID(stop.DeliveryID)
		if err != nil {
			continue // Skip if delivery not found
		}

		items, _ := s.deliveryRepo.GetItemsByDeliveryID(delivery.ID)

		stopsWithDeliveries = append(stopsWithDeliveries, &domain.RouteStopWithDelivery{
			Stop: stop,
			Delivery: &domain.DeliveryWithItems{
				Delivery: delivery,
				Items:    items,
			},
		})
	}

	return &domain.RouteWithStops{
		Route: route,
		Stops: stopsWithDeliveries,
	}, nil
}

// GetTeamRoutes retrieves routes for a team
func (s *deliveryService) GetTeamRoutes(teamID uuid.UUID, limit, offset int) ([]*domain.DeliveryRoute, error) {
	if limit <= 0 {
		limit = domain.DefaultRouteLimit
	}
	if limit > domain.MaxRouteLimit {
		limit = domain.MaxRouteLimit
	}

	return s.deliveryRepo.GetRoutesByTeamID(teamID, limit, offset)
}

// GetWorkerRoutes retrieves routes for a worker
func (s *deliveryService) GetWorkerRoutes(workerID uuid.UUID, limit, offset int) ([]*domain.DeliveryRoute, error) {
	if limit <= 0 {
		limit = domain.DefaultRouteLimit
	}
	if limit > domain.MaxRouteLimit {
		limit = domain.MaxRouteLimit
	}

	return s.deliveryRepo.GetRoutesByWorkerID(workerID, limit, offset)
}

// StartRoute starts a delivery route
func (s *deliveryService) StartRoute(routeID, workerID uuid.UUID) error {
	route, err := s.deliveryRepo.GetRouteByID(routeID)
	if err != nil {
		return fmt.Errorf("route not found: %w", err)
	}

	if route.WorkerID != workerID {
		return fmt.Errorf("route not assigned to this worker")
	}

	if route.Status != domain.RouteStatusPlanned {
		return fmt.Errorf("route cannot be started in current status: %s", route.Status)
	}

	route.Status = domain.RouteStatusActive
	now := time.Now()
	route.StartedAt = &now

	return s.deliveryRepo.UpdateRoute(route)
}

// CompleteRoute completes a delivery route
func (s *deliveryService) CompleteRoute(routeID, workerID uuid.UUID) error {
	route, err := s.deliveryRepo.GetRouteByID(routeID)
	if err != nil {
		return fmt.Errorf("route not found: %w", err)
	}

	if route.WorkerID != workerID {
		return fmt.Errorf("route not assigned to this worker")
	}

	if route.Status != domain.RouteStatusActive {
		return fmt.Errorf("route cannot be completed in current status: %s", route.Status)
	}

	route.Status = domain.RouteStatusCompleted
	now := time.Now()
	route.CompletedAt = &now

	if route.StartedAt != nil {
		actualTime := int(now.Sub(*route.StartedAt).Minutes())
		route.ActualTime = &actualTime
	}

	return s.deliveryRepo.UpdateRoute(route)
}

// OptimizeRoute optimizes an existing route
func (s *deliveryService) OptimizeRoute(routeID uuid.UUID) (*domain.RouteWithStops, error) {
	if s.routeOptimizer == nil {
		return nil, fmt.Errorf("route optimizer not available")
	}

	route, err := s.deliveryRepo.GetRouteByID(routeID)
	if err != nil {
		return nil, fmt.Errorf("route not found: %w", err)
	}

	if route.Status != domain.RouteStatusPlanned {
		return nil, fmt.Errorf("route cannot be optimized in current status: %s", route.Status)
	}

	stops, err := s.deliveryRepo.GetStopsByRouteID(routeID)
	if err != nil {
		return nil, fmt.Errorf("failed to get route stops: %w", err)
	}

	// Get deliveries for optimization
	var deliveries []*domain.Delivery
	for _, stop := range stops {
		delivery, err := s.deliveryRepo.GetDeliveryByID(stop.DeliveryID)
		if err != nil {
			continue
		}
		deliveries = append(deliveries, delivery)
	}

	// Optimize route
	optimizedDeliveries, err := s.routeOptimizer.OptimizeRoute(deliveries, domain.LocationPoint{
		Latitude:  deliveries[0].Latitude,
		Longitude: deliveries[0].Longitude,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to optimize route: %w", err)
	}

	// Update stop orders
	for i, delivery := range optimizedDeliveries {
		for _, stop := range stops {
			if stop.DeliveryID == delivery.ID {
				stop.StopOrder = i + 1
				s.deliveryRepo.UpdateRouteStop(stop)
				break
			}
		}
	}

	return s.GetRoute(routeID)
}

// GetDeliveryStats retrieves delivery statistics
func (s *deliveryService) GetDeliveryStats(teamID uuid.UUID, days int) (*domain.DeliveryStats, error) {
	if days <= 0 {
		days = domain.DefaultStatsDays
	}
	if days > domain.MaxStatsDays {
		days = domain.MaxStatsDays
	}

	return s.deliveryRepo.GetDeliveryStats(teamID, days)
}

// GetWorkerStats retrieves worker statistics
func (s *deliveryService) GetWorkerStats(workerID uuid.UUID, days int) (*domain.WorkerStats, error) {
	if days <= 0 {
		days = domain.DefaultStatsDays
	}
	if days > domain.MaxStatsDays {
		days = domain.MaxStatsDays
	}

	return s.deliveryRepo.GetWorkerStats(workerID, days)
}

// GetTeamWorkerStats retrieves statistics for all workers in a team
func (s *deliveryService) GetTeamWorkerStats(teamID uuid.UUID, days int) ([]*domain.WorkerStats, error) {
	if days <= 0 {
		days = domain.DefaultStatsDays
	}
	if days > domain.MaxStatsDays {
		days = domain.MaxStatsDays
	}

	return s.deliveryRepo.GetTeamWorkerStats(teamID, days)
}

// GetAllDonationDeliveries returns donation-type deliveries formatted as DonationView
func (s *deliveryService) GetAllDonationDeliveries(limit, offset int) ([]*domain.DonationView, error) {
	if limit <= 0 {
		limit = domain.DefaultDeliveryLimit
	}
	if limit > domain.MaxDeliveryLimit {
		limit = domain.MaxDeliveryLimit
	}

	deliveries, err := s.deliveryRepo.GetAllDonationDeliveries(limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get donation deliveries: %w", err)
	}

	return s.convertDeliveriesToDonationViews(deliveries), nil
}

// GetTeamDonationDeliveries returns team-specific donation deliveries formatted as DonationView
func (s *deliveryService) GetTeamDonationDeliveries(teamID uuid.UUID, limit, offset int) ([]*domain.DonationView, error) {
	if limit <= 0 {
		limit = domain.DefaultDeliveryLimit
	}
	if limit > domain.MaxDeliveryLimit {
		limit = domain.MaxDeliveryLimit
	}

	deliveries, err := s.deliveryRepo.GetTeamDonationDeliveries(teamID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get team donation deliveries: %w", err)
	}

	return s.convertDeliveriesToDonationViews(deliveries), nil
}

// GetGlobalDonationDeliveryStats returns aggregated donation stats from deliveries table
// days=0 means all-time (no date filter)
func (s *deliveryService) GetGlobalDonationDeliveryStats(days int) (*domain.DonationDeliveryStats, error) {
	// Default to all-time for donation stats (days=0 means no filter)
	if days < 0 {
		days = 0
	}

	return s.deliveryRepo.GetGlobalDonationDeliveryStats(days)
}

// GetTeamDonationDeliveryStats returns team-specific donation stats from deliveries table
func (s *deliveryService) GetTeamDonationDeliveryStats(teamID uuid.UUID, days int) (*domain.DonationDeliveryStats, error) {
	if days < 0 {
		days = 0
	}

	return s.deliveryRepo.GetTeamDonationDeliveryStats(teamID, days)
}

// GetAllBookSales returns book-sale deliveries formatted as BookSaleView
func (s *deliveryService) GetAllBookSales(limit, offset int) ([]*domain.BookSaleView, error) {
	if limit <= 0 {
		limit = domain.DefaultDeliveryLimit
	}
	if limit > domain.MaxDeliveryLimit {
		limit = domain.MaxDeliveryLimit
	}

	deliveries, err := s.deliveryRepo.GetAllBookSaleDeliveries(limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get book sales: %w", err)
	}

	return s.convertDeliveriesToBookSaleViews(deliveries), nil
}

// GetTeamBookSales returns team-specific book-sale deliveries formatted as BookSaleView
func (s *deliveryService) GetTeamBookSales(teamID uuid.UUID, limit, offset int) ([]*domain.BookSaleView, error) {
	if limit <= 0 {
		limit = domain.DefaultDeliveryLimit
	}
	if limit > domain.MaxDeliveryLimit {
		limit = domain.MaxDeliveryLimit
	}

	deliveries, err := s.deliveryRepo.GetTeamBookSaleDeliveries(teamID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get team book sales: %w", err)
	}

	return s.convertDeliveriesToBookSaleViews(deliveries), nil
}

func (s *deliveryService) GetGlobalBookSaleStats(days int) (*domain.BookSaleStats, error) {
	if days < 0 {
		days = 0
	}
	return s.deliveryRepo.GetGlobalBookSaleStats(days)
}

func (s *deliveryService) GetTeamBookSaleStats(teamID uuid.UUID, days int) (*domain.BookSaleStats, error) {
	if days < 0 {
		days = 0
	}
	return s.deliveryRepo.GetTeamBookSaleStats(teamID, days)
}

// convertDeliveriesToDonationViews converts delivery records to donation view format
func (s *deliveryService) convertDeliveriesToDonationViews(deliveries []*domain.Delivery) []*domain.DonationView {
	var views []*domain.DonationView
	for _, d := range deliveries {
		view := &domain.DonationView{
			ID:           d.ID,
			WorkerID:     d.WorkerID,
			WorkerName:   d.WorkerName,
			TeamID:       d.TeamID,
			DonorName:    d.RecipientName,
			DonorPhone:   d.RecipientPhone,
			DonorEmail:   d.RecipientEmail,
			DonorAddress: d.Address,
			Latitude:     d.Latitude,
			Longitude:    d.Longitude,
			Currency:     "USD",
			DonationType: "one_time",
			Notes:        d.Notes,
			CreatedAt:    d.CreatedAt,
			UpdatedAt:    d.UpdatedAt,
		}

		if d.DonationAmount != nil {
			view.Amount = *d.DonationAmount
		}
		if d.PaymentMethod != nil {
			view.PaymentMethod = *d.PaymentMethod
		}
		if d.ReceiptNumber != nil {
			view.ReceiptNumber = *d.ReceiptNumber
		}

		switch d.Status {
		case domain.StatusCompleted:
			view.Status = "received"
			view.CollectedAt = d.CompletedAt
		case domain.StatusPending:
			view.Status = "pending"
		case domain.StatusCancelled:
			view.Status = "cancelled"
		default:
			view.Status = d.Status
		}

		views = append(views, view)
	}
	return views
}

func (s *deliveryService) convertDeliveriesToBookSaleViews(deliveries []*domain.Delivery) []*domain.BookSaleView {
	var views []*domain.BookSaleView
	for _, d := range deliveries {
		items, _ := s.deliveryRepo.GetItemsByDeliveryID(d.ID)

		var firstItem *domain.DeliveryItem
		if len(items) > 0 {
			firstItem = items[0]
		}

		bookTitle := "Book"
		quantity := 1
		bookCode := ""
		bookLanguage := ""

		if firstItem != nil {
			bookTitle = firstItem.ItemName
			quantity = firstItem.Quantity
			if firstItem.Description != nil {
				bookLanguage = *firstItem.Description
			}
		}

		totalAmount := 0.0
		if d.DonationAmount != nil {
			totalAmount = *d.DonationAmount
		}

		unitPrice := 0.0
		if quantity > 0 {
			unitPrice = totalAmount / float64(quantity)
		}

		view := &domain.BookSaleView{
			ID:            d.ID,
			WorkerID:      d.WorkerID,
			WorkerName:    d.WorkerName,
			TeamID:        d.TeamID,
			BuyerName:     d.RecipientName,
			BuyerPhone:    d.RecipientPhone,
			BuyerEmail:    d.RecipientEmail,
			BuyerAddress:  d.Address,
			Latitude:      d.Latitude,
			Longitude:     d.Longitude,
			BookCode:      &bookCode,
			BookTitle:     bookTitle,
			BookLanguage:  &bookLanguage,
			Quantity:      quantity,
			UnitPrice:     unitPrice,
			TotalAmount:   totalAmount,
			Currency:      "USD",
			PaymentMethod: "cash",
			ReceiptNumber: "",
			Notes:         d.Notes,
			Status:        d.Status,
			SoldAt:        d.CompletedAt,
			CreatedAt:     d.CreatedAt,
			UpdatedAt:     d.UpdatedAt,
		}
		if d.PaymentMethod != nil {
			view.PaymentMethod = *d.PaymentMethod
		}
		if d.ReceiptNumber != nil {
			view.ReceiptNumber = *d.ReceiptNumber
		}
		if bookCode == "" {
			view.BookCode = nil
		}
		if bookLanguage == "" {
			view.BookLanguage = nil
		}

		views = append(views, view)
	}
	return views
}

// Helper function to enrich deliveries with items
func (s *deliveryService) enrichDeliveriesWithItems(deliveries []*domain.Delivery) ([]*domain.DeliveryWithItems, error) {
	var deliveriesWithItems []*domain.DeliveryWithItems

	for _, delivery := range deliveries {
		items, err := s.deliveryRepo.GetItemsByDeliveryID(delivery.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to get items for delivery %s: %w", delivery.ID, err)
		}

		deliveriesWithItems = append(deliveriesWithItems, &domain.DeliveryWithItems{
			Delivery: delivery,
			Items:    items,
		})
	}

	return deliveriesWithItems, nil
}
