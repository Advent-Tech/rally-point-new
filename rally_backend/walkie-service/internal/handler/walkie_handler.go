package handler

import (
	"io"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"rally-point/walkie-service/internal/domain"
	"github.com/rally-point/shared/auth"
)

// In-process WebSocket hub keyed by team ID
var (
	wsMu        sync.RWMutex
	teamSockets = make(map[uuid.UUID]map[*websocket.Conn]struct{})
)

func addSocket(teamID uuid.UUID, conn *websocket.Conn) {
	wsMu.Lock()
	defer wsMu.Unlock()
	if teamSockets[teamID] == nil {
		teamSockets[teamID] = make(map[*websocket.Conn]struct{})
	}
	teamSockets[teamID][conn] = struct{}{}
}

func removeSocket(teamID uuid.UUID, conn *websocket.Conn) {
	wsMu.Lock()
	defer wsMu.Unlock()
	if conns, ok := teamSockets[teamID]; ok {
		delete(conns, conn)
		if len(conns) == 0 {
			delete(teamSockets, teamID)
		}
	}
}

func broadcastToTeam(teamID uuid.UUID, msg *domain.WebSocketMessage) {
	wsMu.RLock()
	defer wsMu.RUnlock()
	if conns, ok := teamSockets[teamID]; ok {
		for c := range conns {
			_ = c.WriteJSON(msg)
		}
	}
}

 type WalkieHandler struct {
	walkieService domain.WalkieService
	jwtManager    *auth.JWTManager
	upgrader      websocket.Upgrader
}

// NewWalkieHandler creates a new walkie handler
func NewWalkieHandler(walkieService domain.WalkieService, jwtManager *auth.JWTManager) *WalkieHandler {
	return &WalkieHandler{
		walkieService: walkieService,
		jwtManager:    jwtManager,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // Allow all origins in development
			},
		},
	}
}

// StartTransmission handles starting a walkie-talkie transmission
func (h *WalkieHandler) StartTransmission(c *gin.Context) {
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

	var req domain.StartTransmissionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, err := h.walkieService.StartTransmission(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	broadcastToTeam(req.TeamID, &domain.WebSocketMessage{Type: domain.WSMessageTypeTransmissionStart, TeamID: req.TeamID, UserID: id, Data: session, Timestamp: time.Now()})
	c.JSON(http.StatusCreated, session)
}

// EndTransmission handles ending a walkie-talkie transmission
func (h *WalkieHandler) EndTransmission(c *gin.Context) {
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

	var req domain.EndTransmissionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, err := h.walkieService.EndTransmission(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	broadcastToTeam(session.TeamID, &domain.WebSocketMessage{Type: domain.WSMessageTypeTransmissionEnd, TeamID: session.TeamID, UserID: id, Data: session, Timestamp: time.Now()})
	c.JSON(http.StatusOK, session)
}

// GetActiveSession handles getting the active session for a team
func (h *WalkieHandler) GetActiveSession(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	session, err := h.walkieService.GetActiveSession(teamID)
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

// SendMessage handles sending a text message
func (h *WalkieHandler) SendMessage(c *gin.Context) {
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

	var req domain.SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	message, err := h.walkieService.SendMessage(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	broadcastToTeam(req.TeamID, &domain.WebSocketMessage{Type: domain.WSMessageTypeMessage, TeamID: req.TeamID, UserID: id, Data: message, Timestamp: time.Now()})
	c.JSON(http.StatusCreated, message)
}

// GetTeamMessages handles getting messages for a team
func (h *WalkieHandler) GetTeamMessages(c *gin.Context) {
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

	messages, err := h.walkieService.GetTeamMessages(teamID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"messages": messages,
		"count":    len(messages),
	})
}

// GetTeamState handles getting the current team state
func (h *WalkieHandler) GetTeamState(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	state, err := h.walkieService.GetTeamState(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, state)
}

// GetTeamMembers handles getting team members
func (h *WalkieHandler) GetTeamMembers(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	members, err := h.walkieService.GetTeamMembers(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"members": members,
		"count":   len(members),
	})
}

// UploadAudio handles audio file upload
func (h *WalkieHandler) UploadAudio(c *gin.Context) {
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

	// Parse multipart form
	err = c.Request.ParseMultipartForm(domain.MaxAudioFileSize)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to parse form"})
		return
	}

	// Get session ID
	sessionIDStr := c.PostForm("session_id")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session ID"})
		return
	}

	// Get duration
	durationStr := c.PostForm("duration")
	duration, err := strconv.Atoi(durationStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid duration"})
		return
	}

	// Get format
	format := c.DefaultPostForm("format", domain.AudioFormatMP3)

	// Get audio file
	file, _, err := c.Request.FormFile("audio")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no audio file provided"})
		return
	}
	defer file.Close()

	// Read audio data
	audioData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to read audio file"})
		return
	}

	// Create upload request
	req := &domain.AudioUploadRequest{
		SessionID: sessionID,
		AudioData: audioData,
		Duration:  duration,
		Format:    format,
	}

	audioURL, err := h.walkieService.UploadAudio(id, req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"audio_url": audioURL,
		"session_id": sessionID,
	})
}

// GetAudioURL handles getting audio URL for a session
func (h *WalkieHandler) GetAudioURL(c *gin.Context) {
	sessionIDStr := c.Param("sessionId")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session ID"})
		return
	}

	audioURL, err := h.walkieService.GetAudioURL(sessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"audio_url": audioURL,
		"session_id": sessionID,
	})
}

// WebSocketHandler handles WebSocket connections for real-time communication
func (h *WalkieHandler) WebSocketHandler(c *gin.Context) {
	// Upgrade HTTP connection to WebSocket
	conn, err := h.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to upgrade connection"})
		return
	}
	defer conn.Close()

	// Get user ID and team ID from query parameters or JWT token
	userIDStr := c.Query("user_id")
	teamIDStr := c.Query("team_id")
	
	if userIDStr == "" || teamIDStr == "" {
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

	if userIDStr == "" || teamIDStr == "" {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "user_id and team_id required"}`))
		return
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "invalid user ID"}`))
		return
	}

	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "invalid team ID"}`))
		return
	}

	// Handle WebSocket connection
	h.handleWebSocketConnection(conn, userID, teamID)
}

// handleWebSocketConnection handles individual WebSocket connections
func (h *WalkieHandler) handleWebSocketConnection(conn *websocket.Conn, userID, teamID uuid.UUID) {
	// Register socket
	addSocket(teamID, conn)
	defer removeSocket(teamID, conn)
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			// Send ping to keep connection alive
			err := conn.WriteMessage(websocket.PingMessage, nil)
			if err != nil {
				return
			}

		default:
			// Read messages from client
			_, _, err := conn.ReadMessage()
			if err != nil {
				return
			}
		}
	}
}

// AuthMiddleware validates JWT tokens
func (h *WalkieHandler) AuthMiddleware() gin.HandlerFunc {
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
func (h *WalkieHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "walkie-service",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
