package handler

import (
	"fmt"
	"math"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/rally-point/shared/auth"
	"rally-point/location-service/internal/domain"
)

type LocationHandler struct {
	locationService domain.LocationService
	jwtManager      *auth.JWTManager
	upgrader        websocket.Upgrader
	recentMu        sync.RWMutex
	recentByUser    map[uuid.UUID]recentLocationSample
}

type recentLocationSample struct {
	Latitude  float64
	Longitude float64
	At        time.Time
}

// NewLocationHandler creates a new location handler
func NewLocationHandler(locationService domain.LocationService, jwtManager *auth.JWTManager) *LocationHandler {
	return &LocationHandler{
		locationService: locationService,
		jwtManager:      jwtManager,
		recentByUser:    make(map[uuid.UUID]recentLocationSample),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // Allow all origins in development
			},
		},
	}
}

// UpdateLocation handles location updates
func (h *LocationHandler) UpdateLocation(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.LocationUpdate
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get filtering config
	filterConfig := DefaultFilterConfig()

	trackedAt := time.Now().UTC()
	prev, hasPrev := h.getRecentSample(id)

	// Apply server-side GPS filtering before saving.
	valid, reason := validateLocationUpdate(
		&req,
		filterConfig,
		trackedAt,
		func() *recentLocationSample {
			if !hasPrev {
				return nil
			}
			return &prev
		}(),
	)
	if !valid {
		// Log filtered location but don't fail - prevents retry spam
		fmt.Printf("[GPS_FILTER] user_id=%s reason=%s lat=%.6f lng=%.6f\n",
			userID, reason, req.Latitude, req.Longitude)

		// Return success to prevent client from retrying immediately
		// but don't save the filtered location
		c.JSON(http.StatusAccepted, gin.H{
			"message":  "location_filtered",
			"reason":   reason,
			"filtered": true,
		})
		return
	}

	track, err := h.locationService.UpdateLocation(id, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Update in-memory recent sample only after an accepted location update.
	h.setRecentSample(id, recentLocationSample{
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		At:        trackedAt,
	})

	c.JSON(http.StatusOK, track)
}

func (h *LocationHandler) getRecentSample(userID uuid.UUID) (recentLocationSample, bool) {
	h.recentMu.RLock()
	defer h.recentMu.RUnlock()
	s, ok := h.recentByUser[userID]
	return s, ok
}

func (h *LocationHandler) setRecentSample(userID uuid.UUID, sample recentLocationSample) {
	h.recentMu.Lock()
	defer h.recentMu.Unlock()
	h.recentByUser[userID] = sample
}

// GetUserLocations handles getting user location history
func (h *LocationHandler) GetUserLocations(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	// Parse query parameters
	var query domain.LocationQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set default limit
	if query.Limit == 0 {
		query.Limit = domain.DefaultLocationLimit
	}

	tracks, err := h.locationService.GetUserLocations(id, &query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"tracks": tracks,
		"count":  len(tracks),
	})
}

// StartSession handles starting a location tracking session
func (h *LocationHandler) StartSession(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	session, err := h.locationService.StartSession(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, session)
}

// EndSession handles ending a location tracking session
func (h *LocationHandler) EndSession(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	sessionIDStr := c.Param("id")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session ID"})
		return
	}

	session, err := h.locationService.EndSession(id, sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, session)
}

// GetActiveSession handles getting the active session
func (h *LocationHandler) GetActiveSession(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	session, err := h.locationService.GetActiveSession(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if session == nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "no active session"})
		return
	}

	c.JSON(http.StatusOK, session)
}

// GetUserSessions handles getting user sessions
func (h *LocationHandler) GetUserSessions(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	// Parse pagination parameters
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit parameter"})
		return
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid offset parameter"})
		return
	}

	sessions, err := h.locationService.GetUserSessions(id, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"sessions": sessions,
		"count":    len(sessions),
	})
}

// GetLocationStats handles getting location statistics
func (h *LocationHandler) GetLocationStats(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid days parameter"})
		return
	}

	stats, err := h.locationService.GetLocationStats(id, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetActiveWorkers handles getting all active workers
func (h *LocationHandler) GetActiveWorkers(c *gin.Context) {
	workers, err := h.locationService.GetActiveWorkers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"workers": workers,
		"count":   len(workers),
	})
}

// GetTeamActiveWorkers handles getting active workers for a specific team with their live locations
func (h *LocationHandler) GetTeamActiveWorkers(c *gin.Context) {
	teamID := c.Query("team_id")
	if teamID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "team_id is required"})
		return
	}

	workers, err := h.locationService.GetActiveWorkersByTeam(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"workers": workers,
		"count":   len(workers),
	})
}

// SetWorkerOffline handles setting a worker offline
func (h *LocationHandler) SetWorkerOffline(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	err = h.locationService.SetWorkerOffline(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "worker set offline"})
}

// WebSocketHandler handles WebSocket connections for real-time location updates
func (h *LocationHandler) WebSocketHandler(c *gin.Context) {
	// Upgrade HTTP connection to WebSocket
	conn, err := h.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to upgrade connection"})
		return
	}
	defer conn.Close()

	// Get user ID and team ID from query parameter or JWT token
	userIDStr := c.Query("user_id")
	teamIDStr := c.Query("team_id") // Optional team_id for filtering
	if userIDStr == "" {
		// Try to get from JWT token in query
		token := c.Query("token")
		if token != "" {
			claims, err := h.jwtManager.VerifyToken(token)
			if err == nil {
				userIDStr = claims.UserID.String()
				if claims.TeamID != nil {
					teamIDStr = claims.TeamID.String()
				}
			}
		}
	}

	if userIDStr == "" {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "unauthorized"}`))
		return
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "invalid user ID"}`))
		return
	}

	// Subscribe to location updates - pass teamID for team-based filtering
	locationCh, err := h.locationService.SubscribeToLocationUpdates(userID, teamIDStr)
	if err != nil {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "failed to subscribe"}`))
		return
	}

	// Handle WebSocket connection
	go h.handleWebSocketConnection(conn, userID, locationCh)

	// Keep connection alive
	for {
		_, _, err := conn.ReadMessage()
		if err != nil {
			break
		}
	}

	// Cleanup
	h.locationService.UnsubscribeFromLocationUpdates(userID)
}

// handleWebSocketConnection handles individual WebSocket connections
func (h *LocationHandler) handleWebSocketConnection(conn *websocket.Conn, userID uuid.UUID, locationCh <-chan *domain.WorkerLocation) {
	pingTicker := time.NewTicker(30 * time.Second)
	defer pingTicker.Stop()
	flushTicker := time.NewTicker(250 * time.Millisecond)
	defer flushTicker.Stop()

	pending := make(map[uuid.UUID]*domain.WorkerLocation)

	for {
		select {
		case location, ok := <-locationCh:
			if !ok {
				return
			}
			if location == nil {
				continue
			}
			// Coalesce by worker: only latest update per worker is sent each flush.
			pending[location.UserID] = location

		case <-flushTicker.C:
			if len(pending) == 0 {
				continue
			}
			for _, location := range pending {
				message := domain.WebSocketMessage{
					Type:      domain.WSMessageTypeWorkerLocationBroadcast,
					UserID:    location.UserID,
					Data:      location,
					Timestamp: time.Now(),
				}
				if err := conn.WriteJSON(message); err != nil {
					return
				}
			}
			clear(pending)

		case <-pingTicker.C:
			// Send ping to keep connection alive
			err := conn.WriteMessage(websocket.PingMessage, nil)
			if err != nil {
				return
			}
		}
	}
}

// AuthMiddleware validates JWT tokens
func (h *LocationHandler) AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization header required"})
			c.Abort()
			return
		}

		token := auth.ExtractTokenFromHeader(authHeader)
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header format"})
			c.Abort()
			return
		}

		claims, err := h.jwtManager.VerifyToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			c.Abort()
			return
		}

		if claims.TokenType != "access" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token type"})
			c.Abort()
			return
		}

		c.Set("user_id", claims.UserID.String())
		c.Set("user_email", claims.Email)
		c.Set("user_role", claims.Role)
		if claims.TeamID != nil {
			c.Set("team_id", claims.TeamID.String())
		}

		c.Next()
	}
}

// HealthCheck handles health check
func (h *LocationHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "location-service",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// LocationFilterConfig contains GPS filtering configuration
type LocationFilterConfig struct {
	MaxSpeedKmh        float64 // 80 km/h - allows both foot and car modes
	MaxDistanceKm      float64 // 50 km outlier threshold
	MinAccuracyMeters  float64 // 50m accuracy threshold
	MinIntervalSeconds int     // 3 seconds minimum between updates
	MinSpeedKmh        float64 // 0.5 km/h minimum (not completely stuck)
}

// DefaultFilterConfig returns the default filtering configuration
func DefaultFilterConfig() LocationFilterConfig {
	return LocationFilterConfig{
		MaxSpeedKmh:        80.0,
		MaxDistanceKm:      50.0,
		MinAccuracyMeters:  50.0,
		MinIntervalSeconds: 3,
		MinSpeedKmh:        0.5,
	}
}

// filterOutlierPoints filters out GPS glitches (>50km jumps) from location track
func filterOutlierPoints(tracks []*domain.LocationTrack) []*domain.LocationTrack {
	if len(tracks) <= 1 {
		return tracks
	}

	const maxJumpMeters = 50000.0 // 50km threshold (updated from 100km)

	filtered := []*domain.LocationTrack{tracks[0]}
	for i := 1; i < len(tracks); i++ {
		distance := haversineDistance(
			filtered[len(filtered)-1].Latitude, filtered[len(filtered)-1].Longitude,
			tracks[i].Latitude, tracks[i].Longitude,
		)
		if distance <= maxJumpMeters {
			filtered = append(filtered, tracks[i])
		} else {
			fmt.Printf("Filtered outlier point: %.2f km jump\n", distance/1000)
		}
	}
	return filtered
}

// validateLocationUpdate validates incoming GPS data before saving
func validateLocationUpdate(
	newLoc *domain.LocationUpdate,
	config LocationFilterConfig,
	now time.Time,
	prev *recentLocationSample,
) (bool, string) {
	// 0. Basic coordinate sanity
	if newLoc.Latitude < -90 || newLoc.Latitude > 90 || newLoc.Longitude < -180 || newLoc.Longitude > 180 {
		return false, "invalid_coordinates"
	}

	// 1. Accuracy check - reject inaccurate GPS readings
	if newLoc.Accuracy != nil && *newLoc.Accuracy > config.MinAccuracyMeters {
		return false, fmt.Sprintf("accuracy_too_low: %.1fm > %.1fm", *newLoc.Accuracy, config.MinAccuracyMeters)
	}

	if prev != nil {
		timeDiff := now.Sub(prev.At).Seconds()
		if timeDiff <= 0 {
			return false, "non_monotonic_timestamp"
		}
		if timeDiff < float64(config.MinIntervalSeconds) {
			return false, fmt.Sprintf("too_frequent: %.2fs < %ds", timeDiff, config.MinIntervalSeconds)
		}

		distanceMeters := haversineDistance(prev.Latitude, prev.Longitude, newLoc.Latitude, newLoc.Longitude)
		if distanceMeters > config.MaxDistanceKm*1000.0 {
			return false, fmt.Sprintf("outlier_jump: %.1fkm > %.1fkm", distanceMeters/1000.0, config.MaxDistanceKm)
		}

		// Prefer device speed if available (m/s from Geolocator), fallback to computed speed.
		speedKmh := (distanceMeters / timeDiff) * 3.6
		if newLoc.Speed != nil && *newLoc.Speed >= 0 {
			speedKmh = *newLoc.Speed * 3.6
		}
		if speedKmh > config.MaxSpeedKmh {
			return false, fmt.Sprintf("speed_too_high: %.1fkm/h > %.1fkm/h", speedKmh, config.MaxSpeedKmh)
		}
	}

	return true, ""
}

// haversineDistance calculates distance between two points in meters
func haversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadius = 6371000.0 // meters

	lat1Rad := lat1 * math.Pi / 180
	lat2Rad := lat2 * math.Pi / 180
	deltaLatRad := (lat2 - lat1) * math.Pi / 180
	deltaLonRad := (lon2 - lon1) * math.Pi / 180

	a := math.Sin(deltaLatRad/2)*math.Sin(deltaLatRad/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
			math.Sin(deltaLonRad/2)*math.Sin(deltaLonRad/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadius * c
}

// GetWorkerPathHistory handles getting path history for a specific worker
// Accessible by team leaders and admins
func (h *LocationHandler) GetWorkerPathHistory(c *gin.Context) {
	// Verify caller is authenticated
	callerRole := c.GetString("user_role")
	if callerRole != "admin" && callerRole != "team_leader" {
		c.JSON(http.StatusForbidden, gin.H{"error": "insufficient permissions"})
		return
	}

	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	// Parse query parameters
	startTimeStr := c.Query("start_time")
	endTimeStr := c.Query("end_time")
	limitStr := c.DefaultQuery("limit", "500")
	sampleMetersStr := c.DefaultQuery("sample_meters", "5")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 500
	}
	if limit > domain.MaxLocationLimit {
		limit = domain.MaxLocationLimit
	}
	sampleMeters, err := strconv.ParseFloat(sampleMetersStr, 64)
	if err != nil || sampleMeters < 0 {
		sampleMeters = 5
	}
	if sampleMeters > 100 {
		sampleMeters = 100
	}

	var tracks []*domain.LocationTrack

	// If time range specified, use time-based query
	if startTimeStr != "" && endTimeStr != "" {
		startTime, err := time.Parse(time.RFC3339, startTimeStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid start_time format, use RFC3339"})
			return
		}
		endTime, err := time.Parse(time.RFC3339, endTimeStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid end_time format, use RFC3339"})
			return
		}

		query := &domain.LocationQuery{
			StartTime: &startTime,
			EndTime:   &endTime,
			Limit:     limit,
		}
		tracks, err = h.locationService.GetUserLocations(workerID, query)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	} else {
		// Default to last 24 hours
		now := time.Now()
		yesterday := now.Add(-24 * time.Hour)
		query := &domain.LocationQuery{
			StartTime: &yesterday,
			EndTime:   &now,
			Limit:     limit,
		}
		tracks, err = h.locationService.GetUserLocations(workerID, query)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}

	// Filter out GPS glitches (>100km jumps)
	tracks = filterOutlierPoints(tracks)
	rawCount := len(tracks)
	tracks = downsampleTracks(tracks, limit, sampleMeters)

	// Format response with path points - use smoothed coordinates if available
	pathPoints := make([]gin.H, 0, len(tracks))
	for _, track := range tracks {
		// Use smoothed coordinates if available, otherwise use raw
		lat := track.Latitude
		lng := track.Longitude
		if track.SmoothedLatitude != nil && track.SmoothedLongitude != nil {
			lat = *track.SmoothedLatitude
			lng = *track.SmoothedLongitude
		}

		point := gin.H{
			"latitude":      lat,
			"longitude":     lng,
			"raw_latitude":  track.Latitude,
			"raw_longitude": track.Longitude,
			"timestamp":     track.TrackedAt.Unix(),
			"tracked_at":    track.TrackedAt.Format(time.RFC3339),
		}
		if track.Accuracy != nil {
			point["accuracy"] = *track.Accuracy
		}
		if track.Speed != nil {
			point["speed"] = *track.Speed
		}
		if track.SessionID != nil {
			point["session_id"] = track.SessionID.String()
		}
		pathPoints = append(pathPoints, point)
	}

	c.JSON(http.StatusOK, gin.H{
		"worker_id":   workerID.String(),
		"path_points": pathPoints,
		"count":       len(pathPoints),
		"raw_count":   rawCount,
	})
}

func downsampleTracks(tracks []*domain.LocationTrack, maxPoints int, minStepMeters float64) []*domain.LocationTrack {
	if len(tracks) <= 1 {
		return tracks
	}

	// 1) Distance-based thinning to remove dense GPS noise.
	filtered := make([]*domain.LocationTrack, 0, len(tracks))
	filtered = append(filtered, tracks[0])
	last := tracks[0]
	for i := 1; i < len(tracks); i++ {
		d := haversineDistance(last.Latitude, last.Longitude, tracks[i].Latitude, tracks[i].Longitude)
		if d >= minStepMeters {
			filtered = append(filtered, tracks[i])
			last = tracks[i]
		}
	}
	if len(filtered) > 0 && filtered[len(filtered)-1].ID != tracks[len(tracks)-1].ID {
		filtered = append(filtered, tracks[len(tracks)-1])
	}

	if len(filtered) <= maxPoints {
		return filtered
	}

	// 2) Uniform stride sampling to bound payload size deterministically.
	step := float64(len(filtered)-1) / float64(maxPoints-1)
	out := make([]*domain.LocationTrack, 0, maxPoints)
	for i := 0; i < maxPoints; i++ {
		idx := int(math.Round(float64(i) * step))
		if idx >= len(filtered) {
			idx = len(filtered) - 1
		}
		out = append(out, filtered[idx])
	}
	return out
}

// GetWorkerLocationStats handles getting location statistics for a specific worker
// Accessible by team leaders and admins
func (h *LocationHandler) GetWorkerLocationStats(c *gin.Context) {
	// Verify caller is authenticated
	callerRole := c.GetString("user_role")
	if callerRole != "admin" && callerRole != "team_leader" {
		c.JSON(http.StatusForbidden, gin.H{"error": "insufficient permissions"})
		return
	}

	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil || days <= 0 {
		days = 30
	}
	if days > 365 {
		days = 365
	}

	stats, err := h.locationService.GetLocationStats(workerID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Convert total_time_seconds to hours for convenience
	totalHours := float64(stats.TotalTime) / 3600.0

	c.JSON(http.StatusOK, gin.H{
		"worker_id":          workerID.String(),
		"total_distance_km":  stats.TotalDistance,
		"total_time_seconds": stats.TotalTime,
		"total_hours":        totalHours,
		"average_speed_kmh":  stats.AverageSpeed,
		"max_speed_kmh":      stats.MaxSpeed,
		"location_count":     stats.LocationCount,
		"session_count":      stats.SessionCount,
		"last_location_time": stats.LastLocationTime,
		"days":               days,
	})
}

// GetWorkerSessions handles getting sessions for a specific worker
// Accessible by team leaders and admins
func (h *LocationHandler) GetWorkerSessions(c *gin.Context) {
	// Verify caller is authenticated
	callerRole := c.GetString("user_role")
	if callerRole != "admin" && callerRole != "team_leader" {
		c.JSON(http.StatusForbidden, gin.H{"error": "insufficient permissions"})
		return
	}

	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 50
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	sessions, err := h.locationService.GetUserSessions(workerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"worker_id": workerID.String(),
		"sessions":  sessions,
		"count":     len(sessions),
	})
}
