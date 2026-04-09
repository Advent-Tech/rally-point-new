package service

import (
	"math"
	"sync"

	"github.com/google/uuid"
)

// GPSSmoother applies Exponential Moving Average (EMA) smoothing to GPS coordinates.
// This reduces noise and produces cleaner path trails.
type GPSSmoother struct {
	mu sync.RWMutex

	// Per-user state for EMA smoothing
	// We maintain the last smoothed position for each user
	lastSmoothedLat map[uuid.UUID]float64
	lastSmoothedLng map[uuid.UUID]float64

	// EMA alpha factor - higher = more responsive to new points, lower = smoother
	// Typical values: 0.1-0.3 for GPS smoothing
	alpha float64
}

// NewGPSSmoother creates a new GPS smoother with the given alpha value.
// Alpha range: 0.05 (very smooth) to 0.5 (very responsive). Recommended: 0.2
func NewGPSSmoother(alpha float64) *GPSSmoother {
	if alpha <= 0 || alpha > 1 {
		alpha = 0.2 // default
	}
	return &GPSSmoother{
		lastSmoothedLat: make(map[uuid.UUID]float64),
		lastSmoothedLng: make(map[uuid.UUID]float64),
		alpha:           alpha,
	}
}

// Smooth applies EMA smoothing to the given GPS coordinates.
// Returns smoothed latitude and longitude.
// For the first point from a user, returns the raw coordinates (no smoothing applied yet).
func (s *GPSSmoother) Smooth(userID uuid.UUID, lat, lng float64) (smoothedLat, smoothedLng float64) {
	s.mu.Lock()
	defer s.mu.Unlock()

	lastLat, hasLastLat := s.lastSmoothedLat[userID]
	lastLng, hasLastLng := s.lastSmoothedLng[userID]

	if !hasLastLat || !hasLastLng {
		// First point - no smoothing, store as-is
		s.lastSmoothedLat[userID] = lat
		s.lastSmoothedLng[userID] = lng
		return lat, lng
	}

	// Apply EMA: smoothed = alpha * new + (1 - alpha) * previous
	smoothedLat = s.alpha*lat + (1-s.alpha)*lastLat
	smoothedLng = s.alpha*lng + (1-s.alpha)*lastLng

	// Store smoothed values for next iteration
	s.lastSmoothedLat[userID] = smoothedLat
	s.lastSmoothedLng[userID] = smoothedLng

	return smoothedLat, smoothedLng
}

// Reset clears the smoothing state for a specific user.
// Call this when a new tracking session starts.
func (s *GPSSmoother) Reset(userID uuid.UUID) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.lastSmoothedLat, userID)
	delete(s.lastSmoothedLng, userID)
}

// ResetAll clears all smoothing state.
func (s *GPSSmoother) ResetAll() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.lastSmoothedLat = make(map[uuid.UUID]float64)
	s.lastSmoothedLng = make(map[uuid.UUID]float64)
}

// HaversineDistance calculates the distance in meters between two GPS coordinates.
func HaversineDistance(lat1, lng1, lat2, lng2 float64) float64 {
	const earthRadius = 6371000 // meters

	lat1Rad := lat1 * math.Pi / 180
	lat2Rad := lat2 * math.Pi / 180
	deltaLat := (lat2 - lat1) * math.Pi / 180
	deltaLng := (lng2 - lng1) * math.Pi / 180

	a := math.Sin(deltaLat/2)*math.Sin(deltaLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
			math.Sin(deltaLng/2)*math.Sin(deltaLng/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadius * c
}

// KalmanSmoothedPoint represents a Kalman-filtered GPS point
type KalmanSmoothedPoint struct {
	Lat         float64
	Lng         float64
	VelocityLat float64
	VelocityLng float64
	Variance    float64
}

// KalmanFilter provides more advanced smoothing using a simple Kalman filter.
// It's better at handling variable accuracy and sudden direction changes.
type KalmanFilter struct {
	mu sync.RWMutex

	// Per-user state
	state map[uuid.UUID]*KalmanSmoothedPoint

	// Process noise - how much we expect the position to change between updates
	processNoise float64

	// Measurement noise - expected GPS accuracy variance (typical GPS: ~10-30m)
	measurementNoise float64
}

// NewKalmanFilter creates a new Kalman filter for GPS smoothing.
func NewKalmanFilter(processNoise, measurementNoise float64) *KalmanFilter {
	if processNoise <= 0 {
		processNoise = 3.0 // meters
	}
	if measurementNoise <= 0 {
		measurementNoise = 100.0 // variance, ~10m std dev
	}

	return &KalmanFilter{
		state:            make(map[uuid.UUID]*KalmanSmoothedPoint),
		processNoise:     processNoise,
		measurementNoise: measurementNoise,
	}
}

// Smooth applies Kalman filtering to GPS coordinates.
// Takes accuracy into account - more accurate GPS readings are weighted more.
func (kf *KalmanFilter) Smooth(userID uuid.UUID, lat, lng float64, accuracy *float64) (smoothedLat, smoothedLng float64) {
	kf.mu.Lock()
	defer kf.mu.Unlock()

	// Determine measurement noise based on GPS accuracy if available
	measurementNoise := kf.measurementNoise
	if accuracy != nil && *accuracy > 0 {
		// Convert accuracy (meters) to variance
		measurementNoise = (*accuracy) * (*accuracy)
	}

	current, exists := kf.state[userID]

	if !exists {
		// First measurement - initialize state
		kf.state[userID] = &KalmanSmoothedPoint{
			Lat:      lat,
			Lng:      lng,
			Variance: measurementNoise,
		}
		return lat, lng
	}

	// Time update (prediction)
	// Assume constant velocity model with some process noise
	current.Variance += kf.processNoise * kf.processNoise

	// Measurement update (correction)
	kalmanGain := current.Variance / (current.Variance + measurementNoise)

	// Update position estimate
	current.Lat += kalmanGain * (lat - current.Lat)
	current.Lng += kalmanGain * (lng - current.Lng)

	// Update variance
	current.Variance = (1 - kalmanGain) * current.Variance

	return current.Lat, current.Lng
}

// Reset clears the Kalman state for a user.
func (kf *KalmanFilter) Reset(userID uuid.UUID) {
	kf.mu.Lock()
	defer kf.mu.Unlock()
	delete(kf.state, userID)
}
