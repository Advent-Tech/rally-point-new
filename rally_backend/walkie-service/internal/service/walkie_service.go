package service

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
	"rally-point/walkie-service/internal/domain"
)

type walkieService struct {
	walkieRepo      domain.WalkieRepository
	realtimeManager domain.RealtimeManager
	audioManager    domain.AudioManager
	nc              *nats.Conn
}

// NewWalkieService creates a new walkie service
func NewWalkieService(walkieRepo domain.WalkieRepository, realtimeManager domain.RealtimeManager, audioManager domain.AudioManager, nc *nats.Conn) domain.WalkieService {
	return &walkieService{
		walkieRepo:      walkieRepo,
		realtimeManager: realtimeManager,
		audioManager:    audioManager,
		nc:              nc,
	}
}

// publishNotify publishes a notification event to NATS
func (s *walkieService) publishNotify(subject string, event map[string]interface{}) {
	if s.nc == nil {
		return
	}
	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("Failed to marshal notification: %v", err)
		return
	}
	if err := s.nc.Publish(subject, data); err != nil {
		log.Printf("Failed to publish notification %s: %v", subject, err)
	}
}

// StartTransmission starts a new walkie-talkie transmission
func (s *walkieService) StartTransmission(userID uuid.UUID, req *domain.StartTransmissionRequest) (*domain.WalkieSession, error) {
	// Check if user is in team
	isInTeam, err := s.walkieRepo.IsUserInTeam(userID, req.TeamID)
	if err != nil {
		return nil, fmt.Errorf("failed to check team membership: %w", err)
	}
	if !isInTeam {
		return nil, fmt.Errorf("user is not a member of this team")
	}

	// Check if there's already an active session
	activeSession, err := s.walkieRepo.GetActiveSession(req.TeamID)
	if err != nil {
		return nil, fmt.Errorf("failed to check active session: %w", err)
	}
	if activeSession != nil && activeSession.SpeakerID != userID {
		return nil, fmt.Errorf("another user is currently transmitting")
	}

	// Create new session if none exists
	if activeSession == nil {
		session := &domain.WalkieSession{
			ID:          uuid.New(),
			TeamID:      req.TeamID,
			SpeakerID:   userID,
			SpeakerName: req.SpeakerName,
			IsActive:    true,
			StartedAt:   time.Now(),
		}

		err = s.walkieRepo.CreateSession(session)
		if err != nil {
			return nil, fmt.Errorf("failed to create session: %w", err)
		}

		activeSession = session
	}

	// Broadcast transmission start to team
	message := &domain.WebSocketMessage{
		Type:      domain.WSMessageTypeTransmissionStart,
		TeamID:    req.TeamID,
		UserID:    userID,
		Data:      activeSession,
		Timestamp: time.Now(),
	}

	err = s.realtimeManager.BroadcastToTeam(req.TeamID, message)
	if err != nil {
		fmt.Printf("Warning: failed to broadcast transmission start: %v\n", err)
	}

	return activeSession, nil
}

// EndTransmission ends a walkie-talkie transmission
func (s *walkieService) EndTransmission(userID uuid.UUID, req *domain.EndTransmissionRequest) (*domain.WalkieSession, error) {
	session, err := s.walkieRepo.GetSessionByID(req.SessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get session: %w", err)
	}

	if session.SpeakerID != userID {
		return nil, fmt.Errorf("only the speaker can end the transmission")
	}

	if !session.IsActive {
		return session, nil // Already ended
	}

	// End the session
	err = s.walkieRepo.EndSession(req.SessionID, req.AudioURL, req.Duration)
	if err != nil {
		return nil, fmt.Errorf("failed to end session: %w", err)
	}

	// Update session object
	session.AudioURL = req.AudioURL
	session.Duration = req.Duration
	session.IsActive = false
	now := time.Now()
	session.EndedAt = &now

	// Broadcast transmission end to team
	message := &domain.WebSocketMessage{
		Type:      domain.WSMessageTypeTransmissionEnd,
		TeamID:    session.TeamID,
		UserID:    userID,
		Data:      session,
		Timestamp: time.Now(),
	}

	err = s.realtimeManager.BroadcastToTeam(session.TeamID, message)
	if err != nil {
		fmt.Printf("Warning: failed to broadcast transmission end: %v\n", err)
	}

	// Publish voice message notification (target: team members)
	s.publishNotify("notify.walkie.voice_message", map[string]interface{}{
		"event_type":        "walkie.voice_message",
		"target_type":       "team",
		"target_id":         session.TeamID.String(),
		"actor_id":          userID.String(),
		"title":             fmt.Sprintf("Voice message from %s", session.SpeakerName),
		"body":              fmt.Sprintf("%ds voice message", req.Duration),
		"data":              map[string]interface{}{"session_id": session.ID.String(), "team_id": session.TeamID.String()},
		"priority":          "normal",
		"notification_type": "walkie",
		"created_at":        time.Now().Format(time.RFC3339),
	})

	return session, nil
}

// GetActiveSession retrieves the active session for a team
func (s *walkieService) GetActiveSession(teamID uuid.UUID) (*domain.WalkieSession, error) {
	return s.walkieRepo.GetActiveSession(teamID)
}

// SendMessage sends a text message to the team
func (s *walkieService) SendMessage(userID uuid.UUID, req *domain.SendMessageRequest) (*domain.WalkieMessage, error) {
	// Check if user is in team
	isInTeam, err := s.walkieRepo.IsUserInTeam(userID, req.TeamID)
	if err != nil {
		return nil, fmt.Errorf("failed to check team membership: %w", err)
	}
	if !isInTeam {
		return nil, fmt.Errorf("user is not a member of this team")
	}

	// Validate message
	if len(req.Message) > domain.MaxMessageLength {
		return nil, fmt.Errorf("message too long (max %d characters)", domain.MaxMessageLength)
	}

	// Set default message type
	messageType := req.MessageType
	if messageType == "" {
		messageType = domain.MessageTypeText
	}

	// Get sender name from request, fallback to "User" if not provided
	senderName := req.SenderName
	if senderName == "" {
		senderName = "User" // Fallback if name not provided
	}

	// Create message
	message := &domain.WalkieMessage{
		ID:          uuid.New(),
		TeamID:      req.TeamID,
		SenderID:    userID,
		SenderName:  senderName,
		Message:     req.Message,
		MessageType: messageType,
		SentAt:      time.Now(),
	}

	err = s.walkieRepo.CreateMessage(message)
	if err != nil {
		return nil, fmt.Errorf("failed to create message: %w", err)
	}

	// Broadcast message to team
	wsMessage := &domain.WebSocketMessage{
		Type:      domain.WSMessageTypeMessage,
		TeamID:    req.TeamID,
		UserID:    userID,
		Data:      message,
		Timestamp: time.Now(),
	}

	err = s.realtimeManager.BroadcastToTeam(req.TeamID, wsMessage)
	if err != nil {
		fmt.Printf("Warning: failed to broadcast message: %v\n", err)
	}

	return message, nil
}

// GetTeamMessages retrieves messages for a team
func (s *walkieService) GetTeamMessages(teamID uuid.UUID, limit, offset int) ([]*domain.WalkieMessage, error) {
	if limit <= 0 {
		limit = domain.DefaultMessageLimit
	}
	if limit > domain.MaxMessageLimit {
		limit = domain.MaxMessageLimit
	}

	return s.walkieRepo.GetTeamMessages(teamID, limit, offset)
}

// GetTeamState retrieves the current state of walkie-talkie for a team
func (s *walkieService) GetTeamState(teamID uuid.UUID) (*domain.WalkieState, error) {
	// Get active session
	activeSession, err := s.walkieRepo.GetActiveSession(teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get active session: %w", err)
	}

	// Get team members
	members, err := s.walkieRepo.GetTeamMembers(teamID)
	if err != nil {
		return nil, fmt.Errorf("failed to get team members: %w", err)
	}

	// Build team state
	state := &domain.WalkieState{
		TeamID:         teamID,
		IsTransmitting: activeSession != nil && activeSession.IsActive,
		ActiveSession:  activeSession,
		TeamMembers:    make([]domain.TeamMember, len(members)),
	}

	// Convert team members
	for i, member := range members {
		state.TeamMembers[i] = *member
	}

	// Set current speaker if there's an active session
	if activeSession != nil && activeSession.IsActive {
		for _, member := range members {
			if member.UserID == activeSession.SpeakerID {
				state.CurrentSpeaker = member
				break
			}
		}
	}

	// Set last activity time
	if activeSession != nil {
		state.LastActivity = &activeSession.StartedAt
	}

	return state, nil
}

// GetTeamMembers retrieves team members for walkie-talkie
func (s *walkieService) GetTeamMembers(teamID uuid.UUID) ([]*domain.TeamMember, error) {
	return s.walkieRepo.GetTeamMembers(teamID)
}

// UploadAudio handles audio file upload
func (s *walkieService) UploadAudio(userID uuid.UUID, req *domain.AudioUploadRequest) (string, error) {
	// Validate audio data
	if len(req.AudioData) == 0 {
		return "", fmt.Errorf("audio data is empty")
	}

	if len(req.AudioData) > domain.MaxAudioFileSize {
		return "", fmt.Errorf("audio file too large (max %d bytes)", domain.MaxAudioFileSize)
	}

	if req.Duration > domain.MaxAudioDuration {
		return "", fmt.Errorf("audio duration too long (max %d seconds)", domain.MaxAudioDuration)
	}

	// Set default format
	format := req.Format
	if format == "" {
		format = domain.AudioFormatMP3
	}

	// Save audio file
	audioURL, err := s.audioManager.SaveAudioFile(req.SessionID, req.AudioData, format)
	if err != nil {
		return "", fmt.Errorf("failed to save audio file: %w", err)
	}

	return audioURL, nil
}

// GetAudioURL retrieves the audio URL for a session
func (s *walkieService) GetAudioURL(sessionID uuid.UUID) (string, error) {
	session, err := s.walkieRepo.GetSessionByID(sessionID)
	if err != nil {
		return "", fmt.Errorf("failed to get session: %w", err)
	}

	if session.AudioURL == nil {
		return "", fmt.Errorf("no audio available for this session")
	}

	return *session.AudioURL, nil
}

// AudioManager implementation
type audioManager struct {
	storagePath string
}

// NewAudioManager creates a new audio manager
func NewAudioManager(storagePath string) domain.AudioManager {
	return &audioManager{
		storagePath: storagePath,
	}
}

// SaveAudioFile saves an audio file and returns the URL
func (am *audioManager) SaveAudioFile(sessionID uuid.UUID, audioData []byte, format string) (string, error) {
	// Create storage directory if it doesn't exist
	err := os.MkdirAll(am.storagePath, 0755)
	if err != nil {
		return "", fmt.Errorf("failed to create storage directory: %w", err)
	}

	// Generate filename
	filename := fmt.Sprintf("%s.%s", sessionID.String(), format)
	filePath := filepath.Join(am.storagePath, filename)

	// Write audio data to file
	err = os.WriteFile(filePath, audioData, 0644)
	if err != nil {
		return "", fmt.Errorf("failed to write audio file: %w", err)
	}

	// Return URL (in production, this would be a public URL)
	audioURL := fmt.Sprintf("/audio/%s", filename)
	return audioURL, nil
}

// GetAudioFile retrieves audio file data
func (am *audioManager) GetAudioFile(sessionID uuid.UUID) ([]byte, error) {
	// Try different formats
	formats := []string{domain.AudioFormatMP3, domain.AudioFormatWAV, domain.AudioFormatM4A}
	
	for _, format := range formats {
		filename := fmt.Sprintf("%s.%s", sessionID.String(), format)
		filePath := filepath.Join(am.storagePath, filename)
		
		data, err := os.ReadFile(filePath)
		if err == nil {
			return data, nil
		}
	}
	
	return nil, fmt.Errorf("audio file not found")
}

// DeleteAudioFile deletes an audio file
func (am *audioManager) DeleteAudioFile(sessionID uuid.UUID) error {
	// Try to delete all possible formats
	formats := []string{domain.AudioFormatMP3, domain.AudioFormatWAV, domain.AudioFormatM4A}
	
	var lastErr error
	for _, format := range formats {
		filename := fmt.Sprintf("%s.%s", sessionID.String(), format)
		filePath := filepath.Join(am.storagePath, filename)
		
		err := os.Remove(filePath)
		if err != nil && !os.IsNotExist(err) {
			lastErr = err
		}
	}
	
	return lastErr
}

// GetAudioURL returns the public URL for an audio file
func (am *audioManager) GetAudioURL(sessionID uuid.UUID) (string, error) {
	// Check if file exists
	_, err := am.GetAudioFile(sessionID)
	if err != nil {
		return "", err
	}
	
	// Return URL (format doesn't matter for URL generation)
	audioURL := fmt.Sprintf("/audio/%s.mp3", sessionID.String())
	return audioURL, nil
}
