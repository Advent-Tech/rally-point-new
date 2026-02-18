package notification

import (
	"encoding/json"
	"time"
)

// NotifyEvent is the standard NATS payload published by services
type NotifyEvent struct {
	EventType        string          `json:"event_type"`
	TargetType       string          `json:"target_type"` // "user" or "team"
	TargetID         string          `json:"target_id"`
	ActorID          string          `json:"actor_id"`
	Title            string          `json:"title"`
	Body             string          `json:"body"`
	Data             json.RawMessage `json:"data,omitempty"`
	Priority         string          `json:"priority,omitempty"`
	NotificationType string          `json:"notification_type"`
	GroupKey         string          `json:"group_key,omitempty"`
	CreatedAt        time.Time       `json:"created_at"`
}

// Notification is a persisted notification record
type Notification struct {
	ID        string          `json:"id"`
	UserID    string          `json:"user_id"`
	Type      string          `json:"type"`
	Title     string          `json:"title"`
	Body      string          `json:"body"`
	Data      json.RawMessage `json:"data"`
	Priority  string          `json:"priority"`
	IsRead    bool            `json:"is_read"`
	ReadAt    *time.Time      `json:"read_at,omitempty"`
	GroupKey  string          `json:"group_key,omitempty"`
	ActorID   string          `json:"actor_id,omitempty"`
	CreatedAt time.Time       `json:"created_at"`
}

// DeviceToken represents a registered FCM device token
type DeviceToken struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Token     string    `json:"token"`
	Platform  string    `json:"platform"`
	DeviceID  string    `json:"device_id,omitempty"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// NotificationPreference represents user notification settings per type
type NotificationPreference struct {
	ID               string `json:"id"`
	UserID           string `json:"user_id"`
	NotificationType string `json:"notification_type"`
	InAppEnabled     bool   `json:"in_app_enabled"`
	PushEnabled      bool   `json:"push_enabled"`
}

// RegisterTokenRequest is the API request to register a device token
type RegisterTokenRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform" binding:"required"`
	DeviceID string `json:"device_id"`
}

// UpdatePreferenceRequest is the API request to update notification preferences
type UpdatePreferenceRequest struct {
	NotificationType string `json:"notification_type" binding:"required"`
	InAppEnabled     *bool  `json:"in_app_enabled"`
	PushEnabled      *bool  `json:"push_enabled"`
}
