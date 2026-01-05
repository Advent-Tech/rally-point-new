package service

import (
	"math"
	"sort"

	"rally-point/delivery-service/internal/domain"
)

type routeOptimizer struct{}

// NewRouteOptimizer creates a new route optimizer
func NewRouteOptimizer() domain.RouteOptimizer {
	return &routeOptimizer{}
}

// OptimizeRoute optimizes delivery route using nearest neighbor algorithm
func (ro *routeOptimizer) OptimizeRoute(deliveries []*domain.Delivery, startLocation domain.LocationPoint) ([]*domain.Delivery, error) {
	if len(deliveries) <= 1 {
		return deliveries, nil
	}

	// Create a copy to avoid modifying original slice
	remaining := make([]*domain.Delivery, len(deliveries))
	copy(remaining, deliveries)

	var optimizedRoute []*domain.Delivery
	currentLocation := startLocation

	// Nearest neighbor algorithm
	for len(remaining) > 0 {
		nearestIndex := 0
		nearestDistance := ro.calculateDistance(currentLocation, domain.LocationPoint{
			Latitude:  remaining[0].Latitude,
			Longitude: remaining[0].Longitude,
		})

		// Find nearest delivery
		for i := 1; i < len(remaining); i++ {
			distance := ro.calculateDistance(currentLocation, domain.LocationPoint{
				Latitude:  remaining[i].Latitude,
				Longitude: remaining[i].Longitude,
			})

			if distance < nearestDistance {
				nearestDistance = distance
				nearestIndex = i
			}
		}

		// Add nearest delivery to route
		nearestDelivery := remaining[nearestIndex]
		optimizedRoute = append(optimizedRoute, nearestDelivery)

		// Update current location
		currentLocation = domain.LocationPoint{
			Latitude:  nearestDelivery.Latitude,
			Longitude: nearestDelivery.Longitude,
		}

		// Remove from remaining deliveries
		remaining = append(remaining[:nearestIndex], remaining[nearestIndex+1:]...)
	}

	return optimizedRoute, nil
}

// CalculateRouteDistance calculates total distance for a route
func (ro *routeOptimizer) CalculateRouteDistance(deliveries []*domain.Delivery) (float64, error) {
	if len(deliveries) <= 1 {
		return 0, nil
	}

	totalDistance := 0.0

	for i := 1; i < len(deliveries); i++ {
		from := domain.LocationPoint{
			Latitude:  deliveries[i-1].Latitude,
			Longitude: deliveries[i-1].Longitude,
		}
		to := domain.LocationPoint{
			Latitude:  deliveries[i].Latitude,
			Longitude: deliveries[i].Longitude,
		}

		distance := ro.calculateDistance(from, to)
		totalDistance += distance
	}

	return totalDistance, nil
}

// EstimateRouteTime estimates total time for a route in minutes
func (ro *routeOptimizer) EstimateRouteTime(deliveries []*domain.Delivery) (int, error) {
	if len(deliveries) == 0 {
		return 0, nil
	}

	// Calculate travel time based on distance
	totalDistance, err := ro.CalculateRouteDistance(deliveries)
	if err != nil {
		return 0, err
	}

	// Assume average speed of 30 km/h in urban areas
	averageSpeedKmh := 30.0
	travelTimeHours := totalDistance / averageSpeedKmh
	travelTimeMinutes := travelTimeHours * 60

	// Add estimated delivery time per stop
	deliveryTimePerStop := 15 // minutes
	totalDeliveryTime := len(deliveries) * deliveryTimePerStop

	// Add buffer time (20% of total time)
	totalTime := travelTimeMinutes + float64(totalDeliveryTime)
	bufferTime := totalTime * 0.2

	return int(totalTime + bufferTime), nil
}

// calculateDistance calculates distance between two points using Haversine formula
func (ro *routeOptimizer) calculateDistance(from, to domain.LocationPoint) float64 {
	const earthRadiusKm = 6371.0

	// Convert degrees to radians
	lat1Rad := from.Latitude * math.Pi / 180
	lon1Rad := from.Longitude * math.Pi / 180
	lat2Rad := to.Latitude * math.Pi / 180
	lon2Rad := to.Longitude * math.Pi / 180

	// Haversine formula
	dLat := lat2Rad - lat1Rad
	dLon := lon2Rad - lon1Rad

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
			math.Sin(dLon/2)*math.Sin(dLon/2)

	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	distance := earthRadiusKm * c

	return distance
}

// OptimizeRouteWithPriority optimizes route considering delivery priorities
func (ro *routeOptimizer) OptimizeRouteWithPriority(deliveries []*domain.Delivery, startLocation domain.LocationPoint) ([]*domain.Delivery, error) {
	if len(deliveries) <= 1 {
		return deliveries, nil
	}

	// Sort by priority first
	priorityGroups := make(map[string][]*domain.Delivery)
	for _, delivery := range deliveries {
		priorityGroups[delivery.Priority] = append(priorityGroups[delivery.Priority], delivery)
	}

	// Define priority order
	priorityOrder := []string{
		domain.PriorityUrgent,
		domain.PriorityHigh,
		domain.PriorityMedium,
		domain.PriorityLow,
	}

	var optimizedRoute []*domain.Delivery
	currentLocation := startLocation

	// Process each priority group
	for _, priority := range priorityOrder {
		if group, exists := priorityGroups[priority]; exists && len(group) > 0 {
			// Optimize within priority group
			optimizedGroup, err := ro.OptimizeRoute(group, currentLocation)
			if err != nil {
				return nil, err
			}

			optimizedRoute = append(optimizedRoute, optimizedGroup...)

			// Update current location to last delivery in group
			if len(optimizedGroup) > 0 {
				lastDelivery := optimizedGroup[len(optimizedGroup)-1]
				currentLocation = domain.LocationPoint{
					Latitude:  lastDelivery.Latitude,
					Longitude: lastDelivery.Longitude,
				}
			}
		}
	}

	return optimizedRoute, nil
}

// OptimizeRouteWithTimeWindows optimizes route considering scheduled delivery times
func (ro *routeOptimizer) OptimizeRouteWithTimeWindows(deliveries []*domain.Delivery, startLocation domain.LocationPoint) ([]*domain.Delivery, error) {
	if len(deliveries) <= 1 {
		return deliveries, nil
	}

	// Separate scheduled and unscheduled deliveries
	var scheduledDeliveries []*domain.Delivery
	var unscheduledDeliveries []*domain.Delivery

	for _, delivery := range deliveries {
		if delivery.ScheduledDate != nil {
			scheduledDeliveries = append(scheduledDeliveries, delivery)
		} else {
			unscheduledDeliveries = append(unscheduledDeliveries, delivery)
		}
	}

	// Sort scheduled deliveries by time
	sort.Slice(scheduledDeliveries, func(i, j int) bool {
		return scheduledDeliveries[i].ScheduledDate.Before(*scheduledDeliveries[j].ScheduledDate)
	})

	var optimizedRoute []*domain.Delivery
	currentLocation := startLocation

	// Add scheduled deliveries first
	for _, delivery := range scheduledDeliveries {
		optimizedRoute = append(optimizedRoute, delivery)
		currentLocation = domain.LocationPoint{
			Latitude:  delivery.Latitude,
			Longitude: delivery.Longitude,
		}
	}

	// Optimize remaining unscheduled deliveries
	if len(unscheduledDeliveries) > 0 {
		optimizedUnscheduled, err := ro.OptimizeRoute(unscheduledDeliveries, currentLocation)
		if err != nil {
			return nil, err
		}
		optimizedRoute = append(optimizedRoute, optimizedUnscheduled...)
	}

	return optimizedRoute, nil
}

// GetRouteMetrics calculates various metrics for a route
func (ro *routeOptimizer) GetRouteMetrics(deliveries []*domain.Delivery) (*RouteMetrics, error) {
	if len(deliveries) == 0 {
		return &RouteMetrics{}, nil
	}

	totalDistance, err := ro.CalculateRouteDistance(deliveries)
	if err != nil {
		return nil, err
	}

	estimatedTime, err := ro.EstimateRouteTime(deliveries)
	if err != nil {
		return nil, err
	}

	// Calculate priority distribution
	priorityCount := make(map[string]int)
	for _, delivery := range deliveries {
		priorityCount[delivery.Priority]++
	}

	// Calculate delivery type distribution
	typeCount := make(map[string]int)
	for _, delivery := range deliveries {
		typeCount[delivery.DeliveryType]++
	}

	return &RouteMetrics{
		TotalDeliveries:    len(deliveries),
		TotalDistanceKm:    totalDistance,
		EstimatedTimeMin:   estimatedTime,
		PriorityDistribution: priorityCount,
		TypeDistribution:   typeCount,
	}, nil
}

// RouteMetrics represents metrics for a delivery route
type RouteMetrics struct {
	TotalDeliveries      int            `json:"total_deliveries"`
	TotalDistanceKm      float64        `json:"total_distance_km"`
	EstimatedTimeMin     int            `json:"estimated_time_minutes"`
	PriorityDistribution map[string]int `json:"priority_distribution"`
	TypeDistribution     map[string]int `json:"type_distribution"`
}
