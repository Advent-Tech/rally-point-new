package handler

import (
	"net/http"
	"strconv"
	"time"

	"rally-point/territory-service/internal/domain"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/rally-point/shared/auth"
)

type TerritoryHandler struct {
	territoryService domain.TerritoryService
	jwtManager       *auth.JWTManager
	upgrader         websocket.Upgrader
}

// NewTerritoryHandler creates a new territory handler
func NewTerritoryHandler(territoryService domain.TerritoryService, jwtManager *auth.JWTManager) *TerritoryHandler {
	return &TerritoryHandler{
		territoryService: territoryService,
		jwtManager:       jwtManager,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // Allow all origins in development
			},
		},
	}
}

// CreateTerritory handles territory creation
func (h *TerritoryHandler) CreateTerritory(c *gin.Context) {
	var req domain.CreateTerritoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	territory, err := h.territoryService.CreateTerritory(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, territory)
}

// GetTerritory handles getting a territory by ID
func (h *TerritoryHandler) GetTerritory(c *gin.Context) {
	territoryIDStr := c.Param("id")
	territoryID, err := uuid.Parse(territoryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	territory, err := h.territoryService.GetTerritory(territoryID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, territory)
}

// UpdateTerritory handles territory updates
func (h *TerritoryHandler) UpdateTerritory(c *gin.Context) {
	territoryIDStr := c.Param("id")
	territoryID, err := uuid.Parse(territoryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	var req domain.UpdateTerritoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	territory, err := h.territoryService.UpdateTerritory(territoryID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, territory)
}

// DeleteTerritory handles territory deletion
func (h *TerritoryHandler) DeleteTerritory(c *gin.Context) {
	territoryIDStr := c.Param("id")
	territoryID, err := uuid.Parse(territoryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	err = h.territoryService.DeleteTerritory(territoryID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "territory deleted successfully"})
}

// GetTeamTerritories handles getting territories for a team
func (h *TerritoryHandler) GetTeamTerritories(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	territories, err := h.territoryService.GetTeamTerritories(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"territories": territories,
		"count":       len(territories),
	})
}

// GetWorkerTerritories handles getting territories for a worker
func (h *TerritoryHandler) GetWorkerTerritories(c *gin.Context) {
	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	territories, err := h.territoryService.GetWorkerTerritories(workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"territories": territories,
		"count":       len(territories),
	})
}

// TrackWorkerLocation handles worker location tracking
func (h *TerritoryHandler) TrackWorkerLocation(c *gin.Context) {
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

	var location domain.LocationPoint
	if err := c.ShouldBindJSON(&location); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	status, err := h.territoryService.TrackWorkerLocation(id, location)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, status)
}

// GetWorkerStatus handles getting worker status
func (h *TerritoryHandler) GetWorkerStatus(c *gin.Context) {
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

	status, err := h.territoryService.GetWorkerStatus(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, status)
}

// GetUserEntries handles getting user territory entries
func (h *TerritoryHandler) GetUserEntries(c *gin.Context) {
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
	limitStr := c.DefaultQuery("limit", "100")
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

	entries, err := h.territoryService.GetUserEntries(id, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"entries": entries,
		"count":   len(entries),
	})
}

// GetTerritoryEntries handles getting territory entries
func (h *TerritoryHandler) GetTerritoryEntries(c *gin.Context) {
	territoryIDStr := c.Param("id")
	territoryID, err := uuid.Parse(territoryIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	// Parse pagination parameters
	limitStr := c.DefaultQuery("limit", "100")
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

	entries, err := h.territoryService.GetTerritoryEntries(territoryID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"entries": entries,
		"count":   len(entries),
	})
}

// GetUserAlerts handles getting user alerts
func (h *TerritoryHandler) GetUserAlerts(c *gin.Context) {
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

	alerts, err := h.territoryService.GetUserAlerts(id, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"alerts": alerts,
		"count":  len(alerts),
	})
}

// GetTeamAlerts handles getting team alerts
func (h *TerritoryHandler) GetTeamAlerts(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
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

	alerts, err := h.territoryService.GetTeamAlerts(teamID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"alerts": alerts,
		"count":  len(alerts),
	})
}

// MarkAlertRead handles marking an alert as read
func (h *TerritoryHandler) MarkAlertRead(c *gin.Context) {
	alertIDStr := c.Param("alertId")
	alertID, err := uuid.Parse(alertIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid alert ID"})
		return
	}

	err = h.territoryService.MarkAlertRead(alertID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "alert marked as read"})
}

// GetTerritoryStats handles getting territory statistics
func (h *TerritoryHandler) GetTerritoryStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	stats, err := h.territoryService.GetTerritoryStats(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetUserTerritoryStats handles getting user territory statistics
func (h *TerritoryHandler) GetUserTerritoryStats(c *gin.Context) {
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

	stats, err := h.territoryService.GetUserTerritoryStats(id, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// WebSocketHandler handles WebSocket connections for real-time alerts
func (h *TerritoryHandler) WebSocketHandler(c *gin.Context) {
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

	// Subscribe to alerts
	alertCh, err := h.territoryService.SubscribeToAlerts(userID)
	if err != nil {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "failed to subscribe"}`))
		return
	}

	// Handle WebSocket connection
	go h.handleWebSocketConnection(conn, userID, alertCh)

	// Keep connection alive
	for {
		_, _, err := conn.ReadMessage()
		if err != nil {
			break
		}
	}

	// Cleanup
	h.territoryService.UnsubscribeFromAlerts(userID)
}

// handleWebSocketConnection handles individual WebSocket connections
func (h *TerritoryHandler) handleWebSocketConnection(conn *websocket.Conn, _ uuid.UUID, alertCh <-chan *domain.TerritoryAlert) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case alert := <-alertCh:
			// Send alert to client
			message := domain.WebSocketMessage{
				Type:      domain.WSMessageTypeTerritoryAlert,
				UserID:    alert.UserID,
				Data:      alert,
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
func (h *TerritoryHandler) AuthMiddleware() gin.HandlerFunc {
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
func (h *TerritoryHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "territory-service",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
