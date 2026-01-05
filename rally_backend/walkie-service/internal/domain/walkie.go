package domain

import (
	"time"

	"github.com/google/uuid"
)

// WalkieSession represents a walkie-talkie session
type WalkieSession struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	TeamID      uuid.UUID  `json:"team_id" db:"team_id"`
	SpeakerID   uuid.UUID  `json:"speaker_id" db:"speaker_id"`
	SpeakerName string     `json:"speaker_name" db:"speaker_name"`
	AudioURL    *string    `json:"audio_url,omitempty" db:"audio_url"`
	Duration    *int       `json:"duration,omitempty" db:"duration"` // in seconds
	IsActive    bool       `json:"is_active" db:"is_active"`
	StartedAt   time.Time  `json:"started_at" db:"started_at"`
	EndedAt     *time.Time `json:"ended_at,omitempty" db:"ended_at"`
}

// WalkieMessage represents a walkie-talkie message (text fallback)
type WalkieMessage struct {
	ID          uuid.UUID `json:"id" db:"id"`
	TeamID      uuid.UUID `json:"team_id" db:"team_id"`
	SenderID    uuid.UUID `json:"sender_id" db:"sender_id"`
	SenderName  string    `json:"sender_name" db:"sender_name"`
	Message     string    `json:"message" db:"message"`
	MessageType string    `json:"message_type" db:"message_type"` // "text", "audio", "system"
	SentAt      time.Time `json:"sent_at" db:"sent_at"`
}

// StartTransmissionRequest represents a request to start transmission
type StartTransmissionRequest struct {
	TeamID      uuid.UUID `json:"team_id" binding:"required"`
	SpeakerName string    `json:"speaker_name" binding:"required"`
}

// EndTransmissionRequest represents a request to end transmission
type EndTransmissionRequest struct {
	SessionID uuid.UUID `json:"session_id" binding:"required"`
	AudioURL  *string   `json:"audio_url,omitempty"`
	Duration  *int      `json:"duration,omitempty"`
}

// SendMessageRequest represents a request to send a text message
type SendMessageRequest struct {
	TeamID      uuid.UUID `json:"team_id" binding:"required"`
	Message     string    `json:"message" binding:"required"`
	MessageType string    `json:"message_type,omitempty"`
}

// TeamMember represents a team member for walkie-talkie
type TeamMember struct {
	UserID   uuid.UUID `json:"user_id"`
	Name     string    `json:"name"`
	Email    string    `json:"email"`
	IsOnline bool      `json:"is_online"`
}

// WalkieState represents the current state of walkie-talkie for a team
type WalkieState struct {
	TeamID           uuid.UUID      `json:"team_id"`
	IsTransmitting   bool           `json:"is_transmitting"`
	CurrentSpeaker   *TeamMember    `json:"current_speaker,omitempty"`
	ActiveSession    *WalkieSession `json:"active_session,omitempty"`
	TeamMembers      []TeamMember   `json:"team_members"`
	LastActivity     *time.Time     `json:"last_activity,omitempty"`
}

// AudioUploadRequest represents an audio file upload request
type AudioUploadRequest struct {
	SessionID uuid.UUID `json:"session_id" binding:"required"`
	AudioData []byte    `json:"audio_data" binding:"required"`
	Duration  int       `json:"duration" binding:"required"`
	Format    string    `json:"format,omitempty"` // "mp3", "wav", "m4a"
}

// WebSocketMessage represents a WebSocket message for real-time communication
type WebSocketMessage struct {
	Type      string      `json:"type"`
	TeamID    uuid.UUID   `json:"team_id"`
	UserID    uuid.UUID   `json:"user_id,omitempty"`
	Data      interface{} `json:"data"`
	Timestamp time.Time   `json:"timestamp"`
}

// WebSocketConnection represents a WebSocket connection
type WebSocketConnection struct {
	UserID     uuid.UUID
	TeamID     uuid.UUID
	Connection interface{} // WebSocket connection interface
	LastPing   time.Time
}

// WalkieRepository defines the interface for walkie-talkie data access
type WalkieRepository interface {
	// Session management
	CreateSession(session *WalkieSession) error
	GetSessionByID(id uuid.UUID) (*WalkieSession, error)
	GetActiveSession(teamID uuid.UUID) (*WalkieSession, error)
	UpdateSession(session *WalkieSession) error
	EndSession(sessionID uuid.UUID, audioURL *string, duration *int) error
	GetTeamSessions(teamID uuid.UUID, limit, offset int) ([]*WalkieSession, error)
	
	// Message management
	CreateMessage(message *WalkieMessage) error
	GetTeamMessages(teamID uuid.UUID, limit, offset int) ([]*WalkieMessage, error)
	DeleteMessage(id uuid.UUID) error
	
	// Team and user management
	GetTeamMembers(teamID uuid.UUID) ([]*TeamMember, error)
	IsUserInTeam(userID, teamID uuid.UUID) (bool, error)
}

// WalkieService defines the interface for walkie-talkie business logic
type WalkieService interface {
	// Transmission management
	StartTransmission(userID uuid.UUID, req *StartTransmissionRequest) (*WalkieSession, error)
	EndTransmission(userID uuid.UUID, req *EndTransmissionRequest) (*WalkieSession, error)
	GetActiveSession(teamID uuid.UUID) (*WalkieSession, error)
	
	// Message management
	SendMessage(userID uuid.UUID, req *SendMessageRequest) (*WalkieMessage, error)
	GetTeamMessages(teamID uuid.UUID, limit, offset int) ([]*WalkieMessage, error)
	
	// Team state
	GetTeamState(teamID uuid.UUID) (*WalkieState, error)
	GetTeamMembers(teamID uuid.UUID) ([]*TeamMember, error)
	
	// Audio management
	UploadAudio(userID uuid.UUID, req *AudioUploadRequest) (string, error)
	GetAudioURL(sessionID uuid.UUID) (string, error)
}

// RealtimeManager defines the interface for real-time walkie-talkie management
type RealtimeManager interface {
	// Connection management
	AddConnection(userID, teamID uuid.UUID, conn interface{}) error
	RemoveConnection(userID uuid.UUID) error
	GetTeamConnections(teamID uuid.UUID) []*WebSocketConnection
	
	// Broadcasting
	BroadcastToTeam(teamID uuid.UUID, message *WebSocketMessage) error
	BroadcastToUser(userID uuid.UUID, message *WebSocketMessage) error
	
	// State management
	UpdateTeamState(teamID uuid.UUID, state *WalkieState) error
	GetTeamState(teamID uuid.UUID) (*WalkieState, error)
}

// AudioManager defines the interface for audio file management
type AudioManager interface {
	SaveAudioFile(sessionID uuid.UUID, audioData []byte, format string) (string, error)
	GetAudioFile(sessionID uuid.UUID) ([]byte, error)
	DeleteAudioFile(sessionID uuid.UUID) error
	GetAudioURL(sessionID uuid.UUID) (string, error)
}

// Constants
const (
	// Message types
	MessageTypeText   = "text"
	MessageTypeAudio  = "audio"
	MessageTypeSystem = "system"
	
	// WebSocket message types
	WSMessageTypeTransmissionStart = "transmission_start"
	WSMessageTypeTransmissionEnd   = "transmission_end"
	WSMessageTypeMessage           = "message"
	WSMessageTypeUserJoined        = "user_joined"
	WSMessageTypeUserLeft          = "user_left"
	WSMessageTypeTeamState         = "team_state"
	WSMessageTypeError             = "error"
	
	// Audio formats
	AudioFormatMP3 = "mp3"
	AudioFormatWAV = "wav"
	AudioFormatM4A = "m4a"
	
	// Limits
	MaxMessageLength    = 1000
	MaxAudioDuration    = 300 // 5 minutes in seconds
	MaxAudioFileSize    = 10 * 1024 * 1024 // 10MB
	DefaultMessageLimit = 50
	MaxMessageLimit     = 200
	
	// Session timeouts
	SessionTimeout     = 30 * time.Second
	ConnectionTimeout  = 60 * time.Second
	PingInterval      = 30 * time.Second
)
