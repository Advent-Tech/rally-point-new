package handler

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"rally-point/walkie-service/internal/domain"
)

// WebSocket hub for chat - keyed by conversation ID
var (
	chatMu          sync.RWMutex
	chatSockets     = make(map[uuid.UUID]map[*websocket.Conn]uuid.UUID) // conversationID -> conn -> userID
	userChatSockets = make(map[uuid.UUID]map[*websocket.Conn]struct{})  // userID -> connections
)

func addChatSocket(conversationID, userID uuid.UUID, conn *websocket.Conn) {
	chatMu.Lock()
	defer chatMu.Unlock()

	// Add to conversation map
	if chatSockets[conversationID] == nil {
		chatSockets[conversationID] = make(map[*websocket.Conn]uuid.UUID)
	}
	chatSockets[conversationID][conn] = userID

	// Add to user map
	if userChatSockets[userID] == nil {
		userChatSockets[userID] = make(map[*websocket.Conn]struct{})
	}
	userChatSockets[userID][conn] = struct{}{}
}

func removeChatSocket(conversationID, userID uuid.UUID, conn *websocket.Conn) {
	chatMu.Lock()
	defer chatMu.Unlock()

	// Remove from conversation map
	if conns, ok := chatSockets[conversationID]; ok {
		delete(conns, conn)
		if len(conns) == 0 {
			delete(chatSockets, conversationID)
		}
	}

	// Remove from user map
	if conns, ok := userChatSockets[userID]; ok {
		delete(conns, conn)
		if len(conns) == 0 {
			delete(userChatSockets, userID)
		}
	}
}

func broadcastToConversation(conversationID uuid.UUID, msg *domain.ChatWebSocketMessage) {
	chatMu.RLock()
	defer chatMu.RUnlock()

	if conns, ok := chatSockets[conversationID]; ok {
		for c := range conns {
			_ = c.WriteJSON(msg)
		}
	}
}

func broadcastToUser(userID uuid.UUID, msg *domain.ChatWebSocketMessage) {
	chatMu.RLock()
	defer chatMu.RUnlock()

	if conns, ok := userChatSockets[userID]; ok {
		for c := range conns {
			_ = c.WriteJSON(msg)
		}
	}
}

type ChatHandler struct {
	chatService domain.ChatService
	upgrader    websocket.Upgrader
}

// NewChatHandler creates a new chat handler
func NewChatHandler(chatService domain.ChatService) *ChatHandler {
	return &ChatHandler{
		chatService: chatService,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // Allow all origins in development
			},
		},
	}
}

// CreateConversation creates a new conversation
func (h *ChatHandler) CreateConversation(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.CreateConversationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	conv, err := h.chatService.CreateConversation(uid, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Notify participants about new conversation
	for _, participant := range conv.Participants {
		if participant.UserID != uid {
			broadcastToUser(participant.UserID, &domain.ChatWebSocketMessage{
				Type:           domain.WSMessageTypeChatNewConv,
				ConversationID: conv.ID,
				Data:           conv,
				Timestamp:      time.Now(),
			})
		}
	}

	c.JSON(http.StatusCreated, conv)
}

// GetConversation gets a conversation by ID
func (h *ChatHandler) GetConversation(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	convIDStr := c.Param("conversationId")
	convID, err := uuid.Parse(convIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	conv, err := h.chatService.GetConversation(convID, uid)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, conv)
}

// GetOrCreateDirect gets or creates a direct conversation
func (h *ChatHandler) GetOrCreateDirect(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.GetOrCreateDirectConversationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	conv, err := h.chatService.GetOrCreateDirectConversation(uid, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, conv)
}

// GetUserConversations gets all conversations for the current user
func (h *ChatHandler) GetUserConversations(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	// Parse pagination
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 50
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		offset = 0
	}

	conversations, err := h.chatService.GetUserConversations(uid, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"conversations": conversations,
		"count":         len(conversations),
	})
}

// GetTeamConversation gets or creates the team conversation
func (h *ChatHandler) GetTeamConversation(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	teamName := c.Query("name")
	if teamName == "" {
		teamName = "Team Chat"
	}

	// Get user name from query or use default
	userName := c.Query("user_name")
	if userName == "" {
		userName = "Team Member"
	}

	conv, err := h.chatService.GetOrCreateTeamConversation(uid, teamID, teamName, userName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, conv)
}

// SendMessage sends a message to a conversation
func (h *ChatHandler) SendMessage(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.SendChatMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	message, err := h.chatService.SendMessage(uid, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Broadcast message to all participants via WebSocket
	broadcastToConversation(req.ConversationID, &domain.ChatWebSocketMessage{
		Type:           domain.WSMessageTypeChatMessage,
		ConversationID: req.ConversationID,
		UserID:         uid,
		Data:           message,
		Timestamp:      time.Now(),
	})

	c.JSON(http.StatusCreated, message)
}

// GetMessages gets messages for a conversation
func (h *ChatHandler) GetMessages(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	convIDStr := c.Param("conversationId")
	convID, err := uuid.Parse(convIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	// Parse pagination
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 50
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		offset = 0
	}

	messages, err := h.chatService.GetMessages(uid, convID, limit, offset)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"messages": messages,
		"count":    len(messages),
	})
}

// EditMessage edits a message
func (h *ChatHandler) EditMessage(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	msgIDStr := c.Param("messageId")
	msgID, err := uuid.Parse(msgIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid message ID"})
		return
	}

	var req struct {
		Content string `json:"content" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	message, err := h.chatService.EditMessage(uid, msgID, req.Content)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Broadcast update
	broadcastToConversation(message.ConversationID, &domain.ChatWebSocketMessage{
		Type:           domain.WSMessageTypeChatMessage,
		ConversationID: message.ConversationID,
		UserID:         uid,
		Data:           message,
		Timestamp:      time.Now(),
	})

	c.JSON(http.StatusOK, message)
}

// DeleteMessage deletes a message
func (h *ChatHandler) DeleteMessage(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	msgIDStr := c.Param("messageId")
	msgID, err := uuid.Parse(msgIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid message ID"})
		return
	}

	if err := h.chatService.DeleteMessage(uid, msgID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "message deleted"})
}

// MarkAsRead marks messages as read
func (h *ChatHandler) MarkAsRead(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.MarkReadRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.chatService.MarkAsRead(uid, &req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Notify other participants that user has read messages
	broadcastToConversation(req.ConversationID, &domain.ChatWebSocketMessage{
		Type:           domain.WSMessageTypeChatRead,
		ConversationID: req.ConversationID,
		UserID:         uid,
		Data: gin.H{
			"user_id":    uid,
			"message_id": req.MessageID,
		},
		Timestamp: time.Now(),
	})

	c.JSON(http.StatusOK, gin.H{"message": "marked as read"})
}

// SendTypingIndicator sends a typing indicator
func (h *ChatHandler) SendTypingIndicator(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	convIDStr := c.Param("conversationId")
	convID, err := uuid.Parse(convIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	var req struct {
		IsTyping bool `json:"is_typing"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Broadcast typing indicator
	broadcastToConversation(convID, &domain.ChatWebSocketMessage{
		Type:           domain.WSMessageTypeChatTyping,
		ConversationID: convID,
		UserID:         uid,
		Data: gin.H{
			"user_id":   uid,
			"is_typing": req.IsTyping,
		},
		Timestamp: time.Now(),
	})

	c.JSON(http.StatusOK, gin.H{"message": "ok"})
}

// ChatWebSocketHandler handles WebSocket connections for chat
func (h *ChatHandler) ChatWebSocketHandler(c *gin.Context) {
	conn, err := h.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to upgrade connection"})
		return
	}
	defer conn.Close()

	// Get user ID and conversation ID from query params
	userIDStr := c.Query("user_id")
	convIDStr := c.Query("conversation_id")

	if userIDStr == "" {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "user_id required"}`))
		return
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "invalid user ID"}`))
		return
	}

	var convID uuid.UUID
	if convIDStr != "" {
		convID, err = uuid.Parse(convIDStr)
		if err != nil {
			conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "invalid conversation ID"}`))
			return
		}
	}

	// Register socket
	if convID != uuid.Nil {
		addChatSocket(convID, userID, conn)
		defer removeChatSocket(convID, userID, conn)
	}

	// Notify others that user is online
	if convID != uuid.Nil {
		broadcastToConversation(convID, &domain.ChatWebSocketMessage{
			Type:           domain.WSMessageTypeChatUserOnline,
			ConversationID: convID,
			UserID:         userID,
			Data:           gin.H{"user_id": userID},
			Timestamp:      time.Now(),
		})
	}

	// Keep connection alive with ping/pong
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		default:
			_, msg, err := conn.ReadMessage()
			if err != nil {
				// Notify others that user is offline
				if convID != uuid.Nil {
					broadcastToConversation(convID, &domain.ChatWebSocketMessage{
						Type:           domain.WSMessageTypeChatUserOffline,
						ConversationID: convID,
						UserID:         userID,
						Data:           gin.H{"user_id": userID},
						Timestamp:      time.Now(),
					})
				}
				return
			}

			// Handle incoming messages (typing indicators, etc.)
			_ = msg // Process message if needed
		}
	}
}

// GetParticipants gets participants for a conversation
func (h *ChatHandler) GetParticipants(c *gin.Context) {
	convIDStr := c.Param("conversationId")
	convID, err := uuid.Parse(convIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	participants, err := h.chatService.GetParticipants(convID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"participants": participants,
		"count":        len(participants),
	})
}
