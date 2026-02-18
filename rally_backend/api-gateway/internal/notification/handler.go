package notification

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"rally-point/api-gateway/internal/websocket"

	"github.com/gin-gonic/gin"
	"github.com/nats-io/nats.go"
)

// Handler orchestrates notification delivery: persist → WebSocket → FCM
type Handler struct {
	store  *Store
	hub    *websocket.Hub
	fcm    *FCMSender // nil if Firebase not configured
	nc     *nats.Conn
}

// NewHandler creates a new notification handler
func NewHandler(store *Store, hub *websocket.Hub, fcm *FCMSender, nc *nats.Conn) *Handler {
	return &Handler{
		store: store,
		hub:   hub,
		fcm:   fcm,
		nc:    nc,
	}
}

// SubscribeNATS subscribes to notify.> wildcard and processes events
func (h *Handler) SubscribeNATS() error {
	_, err := h.nc.Subscribe("notify.>", func(msg *nats.Msg) {
		var event NotifyEvent
		if err := json.Unmarshal(msg.Data, &event); err != nil {
			log.Printf("Notification: failed to parse NATS event on %s: %v", msg.Subject, err)
			return
		}
		h.processEvent(event)
	})
	return err
}

func (h *Handler) processEvent(event NotifyEvent) {
	// Resolve target user IDs
	var targetUserIDs []string

	switch event.TargetType {
	case "user":
		targetUserIDs = []string{event.TargetID}
	case "team":
		ids, err := h.store.GetTeamMemberIDs(event.TargetID)
		if err != nil {
			log.Printf("Notification: failed to get team members for %s: %v", event.TargetID, err)
			return
		}
		targetUserIDs = ids
	default:
		log.Printf("Notification: unknown target_type: %s", event.TargetType)
		return
	}

	priority := event.Priority
	if priority == "" {
		priority = "normal"
	}

	for _, userID := range targetUserIDs {
		// Skip self-notifications
		if userID == event.ActorID {
			continue
		}

		// Check user preferences
		prefs, _ := h.store.GetPreferences(userID)
		inApp, push := true, true
		for _, p := range prefs {
			if p.NotificationType == event.NotificationType {
				inApp = p.InAppEnabled
				push = p.PushEnabled
				break
			}
		}

		// Persist notification
		n := &Notification{
			UserID:   userID,
			Type:     event.NotificationType,
			Title:    event.Title,
			Body:     event.Body,
			Data:     event.Data,
			Priority: priority,
			GroupKey: event.GroupKey,
			ActorID:  event.ActorID,
		}
		if err := h.store.CreateNotification(n); err != nil {
			log.Printf("Notification: failed to persist for user %s: %v", userID, err)
			continue
		}

		// In-app via WebSocket (if preference allows)
		if inApp {
			wsMsg := websocket.Message{
				Type: "notification",
				Data: map[string]interface{}{
					"id":         n.ID,
					"type":       n.Type,
					"title":      n.Title,
					"body":       n.Body,
					"data":       json.RawMessage(n.Data),
					"priority":   n.Priority,
					"group_key":  n.GroupKey,
					"created_at": n.CreatedAt.Format(time.RFC3339),
				},
				Timestamp: time.Now().UnixMilli(),
			}
			h.hub.SendToUser(userID, wsMsg)
		}

		// FCM push (if user offline and preference allows)
		if push && h.fcm != nil && !h.hub.IsUserConnected(userID) {
			go h.sendPush(userID, n)
		}
	}
}

func (h *Handler) sendPush(userID string, n *Notification) {
	tokens, err := h.store.GetActiveTokens(userID)
	if err != nil || len(tokens) == 0 {
		return
	}

	data := map[string]string{
		"notification_id":   n.ID,
		"notification_type": n.Type,
		"group_key":         n.GroupKey,
	}
	// Merge extra data from notification
	if n.Data != nil {
		var extra map[string]interface{}
		if json.Unmarshal(n.Data, &extra) == nil {
			for k, v := range extra {
				if s, ok := v.(string); ok {
					data[k] = s
				}
			}
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	staleTokens := h.fcm.SendToUser(ctx, tokens, n.Title, n.Body, data)
	for _, token := range staleTokens {
		if err := h.store.DeactivateToken(token); err != nil {
			log.Printf("Notification: failed to deactivate stale token: %v", err)
		}
	}
}

// --- REST Handlers ---

// RegisterDeviceToken handles POST /api/notifications/device-token
func (h *Handler) RegisterDeviceToken(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req RegisterTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	token := &DeviceToken{
		UserID:   userID,
		Token:    req.Token,
		Platform: req.Platform,
		DeviceID: req.DeviceID,
	}
	if err := h.store.SaveDeviceToken(token); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "token registered"})
}

// RemoveDeviceToken handles DELETE /api/notifications/device-token
func (h *Handler) RemoveDeviceToken(c *gin.Context) {
	userID := c.GetString("user_id")
	token := c.Query("token")
	if token == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token query parameter required"})
		return
	}

	if err := h.store.RemoveDeviceToken(token, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to remove token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "token removed"})
}

// GetNotifications handles GET /api/notifications
func (h *Handler) GetNotifications(c *gin.Context) {
	userID := c.GetString("user_id")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	notifications, err := h.store.GetNotifications(userID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch notifications"})
		return
	}
	if notifications == nil {
		notifications = []Notification{}
	}

	c.JSON(http.StatusOK, gin.H{"notifications": notifications})
}

// GetUnreadCount handles GET /api/notifications/unread-count
func (h *Handler) GetUnreadCount(c *gin.Context) {
	userID := c.GetString("user_id")

	count, err := h.store.GetUnreadCount(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get unread count"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"unread_count": count})
}

// MarkAsRead handles PUT /api/notifications/:id/read
func (h *Handler) MarkAsRead(c *gin.Context) {
	userID := c.GetString("user_id")
	notifID := c.Param("id")

	if err := h.store.MarkAsRead(notifID, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to mark as read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "marked as read"})
}

// MarkAllAsRead handles PUT /api/notifications/read-all
func (h *Handler) MarkAllAsRead(c *gin.Context) {
	userID := c.GetString("user_id")

	if err := h.store.MarkAllAsRead(userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to mark all as read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "all marked as read"})
}

// DeleteNotification handles DELETE /api/notifications/:id
func (h *Handler) DeleteNotification(c *gin.Context) {
	userID := c.GetString("user_id")
	notifID := c.Param("id")

	if err := h.store.DeleteNotification(notifID, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete notification"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}

// GetPreferences handles GET /api/notifications/preferences
func (h *Handler) GetPreferences(c *gin.Context) {
	userID := c.GetString("user_id")

	prefs, err := h.store.GetPreferences(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get preferences"})
		return
	}
	if prefs == nil {
		prefs = []NotificationPreference{}
	}

	c.JSON(http.StatusOK, gin.H{"preferences": prefs})
}

// UpdatePreferences handles PUT /api/notifications/preferences
func (h *Handler) UpdatePreferences(c *gin.Context) {
	userID := c.GetString("user_id")

	var req UpdatePreferenceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	inApp := true
	push := true
	if req.InAppEnabled != nil {
		inApp = *req.InAppEnabled
	}
	if req.PushEnabled != nil {
		push = *req.PushEnabled
	}

	if err := h.store.UpdatePreference(userID, req.NotificationType, inApp, push); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update preferences"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "preferences updated"})
}
