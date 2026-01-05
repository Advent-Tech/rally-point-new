package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"rally-point/location-service/internal/domain"
	"github.com/rally-point/shared/auth"
)

type LocationHandler struct {
	locationService domain.LocationService
	jwtManager      *auth.JWTManager
	upgrader        websocket.Upgrader
}

// NewLocationHandler creates a new location handler
func NewLocationHandler(locationService domain.LocationService, jwtManager *auth.JWTManager) *LocationHandler {
	return &LocationHandler{
		locationService: locationService,
		jwtManager:      jwtManager,
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

	track, err := h.locationService.UpdateLocation(id, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, track)
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

	// Get user ID from query parameter or JWT token
	userIDStr := c.Query("user_id")
	if userIDStr == "" {
		// Try to get from JWT token in query
		token := c.Query("token")
		if token != "" {
			claims, err := h.jwtManager.VerifyToken(token)
			if err == nil {
				userIDStr = claims.UserID.String()
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

	// Subscribe to location updates
	locationCh, err := h.locationService.SubscribeToLocationUpdates(userID)
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
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case location := <-locationCh:
			// Send location update to client
			message := domain.WebSocketMessage{
				Type:      domain.WSMessageTypeLocationUpdate,
				UserID:    location.UserID,
				Data:      location,
				Timestamp: time.Now(),
			}

			err := conn.WriteJSON(message)
			if err != nil {
				return
			}

		case <-ticker.C:
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

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 500
	}
	if limit > domain.MaxLocationLimit {
		limit = domain.MaxLocationLimit
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

	// Format response with path points
	pathPoints := make([]gin.H, 0, len(tracks))
	for _, track := range tracks {
		point := gin.H{
			"latitude":   track.Latitude,
			"longitude":  track.Longitude,
			"timestamp":  track.TrackedAt.Unix(),
			"tracked_at": track.TrackedAt.Format(time.RFC3339),
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
	})
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
