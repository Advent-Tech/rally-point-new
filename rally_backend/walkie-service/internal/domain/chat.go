package domain

import (
	"time"

	"github.com/google/uuid"
)

// ChatConversation represents a chat conversation (direct or team)
type ChatConversation struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	Type            string     `json:"type" db:"type"` // "direct" or "team"
	TeamID          *uuid.UUID `json:"team_id,omitempty" db:"team_id"`
	Name            *string    `json:"name,omitempty" db:"name"` // For team chats
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
	LastMessageAt   *time.Time `json:"last_message_at,omitempty" db:"last_message_at"`
	LastMessage     *string    `json:"last_message,omitempty" db:"last_message"`
	LastMessageBy   *string    `json:"last_message_by,omitempty" db:"last_message_by"`
	UnreadCount     int        `json:"unread_count" db:"-"` // Computed per user
	ParticipantIDs  []string   `json:"participant_ids,omitempty" db:"-"`
	Participants    []ChatParticipant `json:"participants,omitempty" db:"-"`
}

// ChatParticipant represents a participant in a conversation
type ChatParticipant struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	ConversationID uuid.UUID  `json:"conversation_id" db:"conversation_id"`
	UserID         uuid.UUID  `json:"user_id" db:"user_id"`
	UserName       string     `json:"user_name" db:"user_name"`
	AvatarURL      *string    `json:"avatar_url,omitempty" db:"avatar_url"`
	Role           string     `json:"role" db:"role"` // "member", "admin"
	JoinedAt       time.Time  `json:"joined_at" db:"joined_at"`
	LastReadAt     *time.Time `json:"last_read_at,omitempty" db:"last_read_at"`
	IsOnline       bool       `json:"is_online" db:"-"`
	IsMuted        bool       `json:"is_muted" db:"is_muted"`
}

// ChatMessage represents a chat message
type ChatMessage struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	ConversationID uuid.UUID  `json:"conversation_id" db:"conversation_id"`
	SenderID       uuid.UUID  `json:"sender_id" db:"sender_id"`
	SenderName     string     `json:"sender_name" db:"sender_name"`
	SenderAvatar   *string    `json:"sender_avatar,omitempty" db:"sender_avatar"`
	MessageType    string     `json:"message_type" db:"message_type"` // "text", "image", "file", "location", "system"
	Content        string     `json:"content" db:"content"`
	MediaURL       *string    `json:"media_url,omitempty" db:"media_url"`
	Metadata       *string    `json:"metadata,omitempty" db:"metadata"` // JSON for extra data
	ReplyToID      *uuid.UUID `json:"reply_to_id,omitempty" db:"reply_to_id"`
	IsEdited       bool       `json:"is_edited" db:"is_edited"`
	IsDeleted      bool       `json:"is_deleted" db:"is_deleted"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
	ReadBy         []string   `json:"read_by,omitempty" db:"-"` // User IDs who read this message
}

// CreateConversationRequest represents a request to create a conversation
type CreateConversationRequest struct {
	Type           string      `json:"type" binding:"required,oneof=direct team"` // "direct" or "team"
	ParticipantIDs []uuid.UUID `json:"participant_ids" binding:"required,min=1"`
	TeamID         *uuid.UUID  `json:"team_id,omitempty"`
	Name           *string     `json:"name,omitempty"`
}

// SendChatMessageRequest represents a request to send a message
type SendChatMessageRequest struct {
	ConversationID uuid.UUID  `json:"conversation_id" binding:"required"`
	MessageType    string     `json:"message_type,omitempty"` // defaults to "text"
	Content        string     `json:"content" binding:"required"`
	MediaURL       *string    `json:"media_url,omitempty"`
	Metadata       *string    `json:"metadata,omitempty"`
	ReplyToID      *uuid.UUID `json:"reply_to_id,omitempty"`
}

// MarkReadRequest represents a request to mark messages as read
type MarkReadRequest struct {
	ConversationID uuid.UUID `json:"conversation_id" binding:"required"`
	MessageID      uuid.UUID `json:"message_id" binding:"required"` // Mark all messages up to this one as read
}

// GetOrCreateDirectConversationRequest for getting or creating a direct conversation
type GetOrCreateDirectConversationRequest struct {
	OtherUserID uuid.UUID `json:"other_user_id" binding:"required"`
}

// ChatWebSocketMessage represents a WebSocket message for chat
type ChatWebSocketMessage struct {
	Type           string      `json:"type"`
	ConversationID uuid.UUID   `json:"conversation_id"`
	UserID         uuid.UUID   `json:"user_id,omitempty"`
	Data           interface{} `json:"data"`
	Timestamp      time.Time   `json:"timestamp"`
}

// ChatRepository defines the interface for chat data access
type ChatRepository interface {
	// Conversation management
	CreateConversation(conv *ChatConversation) error
	GetConversationByID(id uuid.UUID) (*ChatConversation, error)
	GetDirectConversation(userID1, userID2 uuid.UUID) (*ChatConversation, error)
	GetUserConversations(userID uuid.UUID, limit, offset int) ([]*ChatConversation, error)
	UpdateConversation(conv *ChatConversation) error
	DeleteConversation(id uuid.UUID) error

	// Participant management
	AddParticipant(participant *ChatParticipant) error
	RemoveParticipant(conversationID, userID uuid.UUID) error
	GetConversationParticipants(conversationID uuid.UUID) ([]*ChatParticipant, error)
	IsUserInConversation(conversationID, userID uuid.UUID) (bool, error)
	UpdateLastRead(conversationID, userID uuid.UUID, timestamp time.Time) error

	// Message management
	CreateMessage(message *ChatMessage) error
	GetMessageByID(id uuid.UUID) (*ChatMessage, error)
	GetConversationMessages(conversationID uuid.UUID, limit, offset int) ([]*ChatMessage, error)
	UpdateMessage(message *ChatMessage) error
	DeleteMessage(id uuid.UUID) error
	GetUnreadCount(conversationID, userID uuid.UUID) (int, error)

	// Team conversations
	GetTeamConversation(teamID uuid.UUID) (*ChatConversation, error)
	CreateTeamConversation(teamID uuid.UUID, teamName string) (*ChatConversation, error)
	GetTeamMembers(teamID uuid.UUID) ([]*TeamMember, error)

	// User info
	GetUserByID(userID uuid.UUID) (*TeamMember, error)
}

// ChatService defines the interface for chat business logic
type ChatService interface {
	// Conversation management
	CreateConversation(userID uuid.UUID, req *CreateConversationRequest) (*ChatConversation, error)
	GetConversation(conversationID, userID uuid.UUID) (*ChatConversation, error)
	GetOrCreateDirectConversation(userID uuid.UUID, req *GetOrCreateDirectConversationRequest) (*ChatConversation, error)
	GetUserConversations(userID uuid.UUID, limit, offset int) ([]*ChatConversation, error)
	GetOrCreateTeamConversation(userID uuid.UUID, teamID uuid.UUID, teamName string, userName string) (*ChatConversation, error)

	// Message management
	SendMessage(userID uuid.UUID, req *SendChatMessageRequest) (*ChatMessage, error)
	GetMessages(userID uuid.UUID, conversationID uuid.UUID, limit, offset int) ([]*ChatMessage, error)
	EditMessage(userID uuid.UUID, messageID uuid.UUID, newContent string) (*ChatMessage, error)
	DeleteMessage(userID uuid.UUID, messageID uuid.UUID) error
	MarkAsRead(userID uuid.UUID, req *MarkReadRequest) error

	// Participant management
	AddParticipant(conversationID, userID uuid.UUID, userName string) error
	RemoveParticipant(conversationID, userID, targetUserID uuid.UUID) error
	GetParticipants(conversationID uuid.UUID) ([]*ChatParticipant, error)
}

// Chat-related WebSocket message types
const (
	WSMessageTypeChatMessage     = "chat_message"
	WSMessageTypeChatTyping      = "chat_typing"
	WSMessageTypeChatRead        = "chat_read"
	WSMessageTypeChatUserOnline  = "chat_user_online"
	WSMessageTypeChatUserOffline = "chat_user_offline"
	WSMessageTypeChatNewConv     = "chat_new_conversation"
	WSMessageTypeChatMemberAdded = "chat_member_added"
	WSMessageTypeChatMemberLeft  = "chat_member_left"
)

// Chat message types
const (
	ChatMessageTypeText     = "text"
	ChatMessageTypeImage    = "image"
	ChatMessageTypeFile     = "file"
	ChatMessageTypeLocation = "location"
	ChatMessageTypeSystem   = "system"
)

// Conversation types
const (
	ConversationTypeDirect = "direct"
	ConversationTypeTeam   = "team"
)

// Participant roles
const (
	ParticipantRoleMember = "member"
	ParticipantRoleAdmin  = "admin"
)

// Chat limits
const (
	ChatMaxMessageLength      = 5000
	ChatMaxConversationName   = 100
	ChatDefaultMessageLimit   = 50
	ChatMaxMessageLimit       = 200
	ChatMaxParticipantsInTeam = 100
)
