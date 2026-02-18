package service

import (
	"encoding/json"
	"errors"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
	"rally-point/walkie-service/internal/domain"
)

type chatService struct {
	chatRepo domain.ChatRepository
	nc       *nats.Conn
}

// NewChatService creates a new chat service
func NewChatService(chatRepo domain.ChatRepository, nc *nats.Conn) domain.ChatService {
	return &chatService{
		chatRepo: chatRepo,
		nc:       nc,
	}
}

// publishNotify publishes a notification event to NATS
func (s *chatService) publishNotify(subject string, event map[string]interface{}) {
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

// CreateConversation creates a new conversation
func (s *chatService) CreateConversation(userID uuid.UUID, req *domain.CreateConversationRequest) (*domain.ChatConversation, error) {
	// Validate request
	if req.Type == domain.ConversationTypeDirect && len(req.ParticipantIDs) != 1 {
		return nil, errors.New("direct conversations must have exactly one other participant")
	}

	if req.Type == domain.ConversationTypeTeam && req.TeamID == nil {
		return nil, errors.New("team conversations require a team ID")
	}

	// For direct conversations, check if one already exists
	if req.Type == domain.ConversationTypeDirect {
		existing, err := s.chatRepo.GetDirectConversation(userID, req.ParticipantIDs[0])
		if err != nil {
			return nil, err
		}
		if existing != nil {
			// Load participants
			participants, _ := s.chatRepo.GetConversationParticipants(existing.ID)
			existing.Participants = make([]domain.ChatParticipant, len(participants))
			for i, p := range participants {
				existing.Participants[i] = *p
			}
			return existing, nil
		}
	}

	now := time.Now()
	conv := &domain.ChatConversation{
		ID:        uuid.New(),
		Type:      req.Type,
		TeamID:    req.TeamID,
		Name:      req.Name,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := s.chatRepo.CreateConversation(conv); err != nil {
		return nil, err
	}

	// Add the creator as a participant (admin for team chats)
	role := domain.ParticipantRoleMember
	if req.Type == domain.ConversationTypeTeam {
		role = domain.ParticipantRoleAdmin
	}

	// Get creator's name from database
	creatorName := "User"
	if creatorInfo, err := s.chatRepo.GetUserByID(userID); err == nil && creatorInfo != nil {
		creatorName = creatorInfo.Name
	}

	creatorParticipant := &domain.ChatParticipant{
		ID:             uuid.New(),
		ConversationID: conv.ID,
		UserID:         userID,
		UserName:       creatorName,
		Role:           role,
		JoinedAt:       now,
	}
	if err := s.chatRepo.AddParticipant(creatorParticipant); err != nil {
		return nil, err
	}

	// Add other participants
	for _, participantID := range req.ParticipantIDs {
		if participantID == userID {
			continue // Skip if already added
		}
		// Get participant's name from database
		participantName := "User"
		if participantInfo, err := s.chatRepo.GetUserByID(participantID); err == nil && participantInfo != nil {
			participantName = participantInfo.Name
		}

		participant := &domain.ChatParticipant{
			ID:             uuid.New(),
			ConversationID: conv.ID,
			UserID:         participantID,
			UserName:       participantName,
			Role:           domain.ParticipantRoleMember,
			JoinedAt:       now,
		}
		if err := s.chatRepo.AddParticipant(participant); err != nil {
			return nil, err
		}
	}

	// Load participants for response
	participants, _ := s.chatRepo.GetConversationParticipants(conv.ID)
	conv.Participants = make([]domain.ChatParticipant, len(participants))
	for i, p := range participants {
		conv.Participants[i] = *p
	}

	return conv, nil
}

// GetConversation gets a conversation by ID
func (s *chatService) GetConversation(conversationID, userID uuid.UUID) (*domain.ChatConversation, error) {
	// Check if user is in conversation
	isInConv, err := s.chatRepo.IsUserInConversation(conversationID, userID)
	if err != nil {
		return nil, err
	}
	if !isInConv {
		return nil, errors.New("user is not in this conversation")
	}

	conv, err := s.chatRepo.GetConversationByID(conversationID)
	if err != nil {
		return nil, err
	}
	if conv == nil {
		return nil, errors.New("conversation not found")
	}

	// Load participants
	participants, _ := s.chatRepo.GetConversationParticipants(conv.ID)
	conv.Participants = make([]domain.ChatParticipant, len(participants))
	for i, p := range participants {
		conv.Participants[i] = *p
	}

	// Get unread count
	unreadCount, _ := s.chatRepo.GetUnreadCount(conversationID, userID)
	conv.UnreadCount = unreadCount

	return conv, nil
}

// GetOrCreateDirectConversation gets or creates a direct conversation with another user
func (s *chatService) GetOrCreateDirectConversation(userID uuid.UUID, req *domain.GetOrCreateDirectConversationRequest) (*domain.ChatConversation, error) {
	if userID == req.OtherUserID {
		return nil, errors.New("cannot create conversation with yourself")
	}

	// Check if conversation already exists
	existing, err := s.chatRepo.GetDirectConversation(userID, req.OtherUserID)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		// Load participants
		participants, _ := s.chatRepo.GetConversationParticipants(existing.ID)
		existing.Participants = make([]domain.ChatParticipant, len(participants))
		for i, p := range participants {
			existing.Participants[i] = *p
		}
		return existing, nil
	}

	// Create new conversation
	return s.CreateConversation(userID, &domain.CreateConversationRequest{
		Type:           domain.ConversationTypeDirect,
		ParticipantIDs: []uuid.UUID{req.OtherUserID},
	})
}

// GetUserConversations gets all conversations for a user
func (s *chatService) GetUserConversations(userID uuid.UUID, limit, offset int) ([]*domain.ChatConversation, error) {
	if limit <= 0 || limit > domain.ChatMaxMessageLimit {
		limit = domain.ChatDefaultMessageLimit
	}

	conversations, err := s.chatRepo.GetUserConversations(userID, limit, offset)
	if err != nil {
		return nil, err
	}

	// Load participants and unread counts for each conversation
	for _, conv := range conversations {
		participants, _ := s.chatRepo.GetConversationParticipants(conv.ID)
		conv.Participants = make([]domain.ChatParticipant, len(participants))
		for i, p := range participants {
			conv.Participants[i] = *p
		}
		unreadCount, _ := s.chatRepo.GetUnreadCount(conv.ID, userID)
		conv.UnreadCount = unreadCount
	}

	return conversations, nil
}

// GetOrCreateTeamConversation gets or creates a team conversation
func (s *chatService) GetOrCreateTeamConversation(userID uuid.UUID, teamID uuid.UUID, teamName string, userName string) (*domain.ChatConversation, error) {
	// Get all team members
	teamMembers, err := s.chatRepo.GetTeamMembers(teamID)
	if err != nil {
		return nil, err
	}

	// Check if team conversation already exists
	existing, err := s.chatRepo.GetTeamConversation(teamID)
	if err != nil {
		return nil, err
	}

	if existing != nil {
		// Sync team members - add any missing members to the conversation
		for _, member := range teamMembers {
			isInConv, err := s.chatRepo.IsUserInConversation(existing.ID, member.UserID)
			if err != nil {
				continue // Skip on error, don't fail the whole operation
			}
			if !isInConv {
				participant := &domain.ChatParticipant{
					ID:             uuid.New(),
					ConversationID: existing.ID,
					UserID:         member.UserID,
					UserName:       member.Name,
					Role:           domain.ParticipantRoleMember,
					JoinedAt:       time.Now(),
				}
				_ = s.chatRepo.AddParticipant(participant) // Ignore errors for individual adds
			}
		}

		// Load participants
		participants, _ := s.chatRepo.GetConversationParticipants(existing.ID)
		existing.Participants = make([]domain.ChatParticipant, len(participants))
		for i, p := range participants {
			existing.Participants[i] = *p
		}
		return existing, nil
	}

	// Create new team conversation
	conv, err := s.chatRepo.CreateTeamConversation(teamID, teamName)
	if err != nil {
		return nil, err
	}

	// Add all team members as participants
	now := time.Now()
	for i, member := range teamMembers {
		role := domain.ParticipantRoleMember
		// First member (or the requesting user) becomes admin
		if i == 0 || member.UserID == userID {
			role = domain.ParticipantRoleAdmin
		}

		participant := &domain.ChatParticipant{
			ID:             uuid.New(),
			ConversationID: conv.ID,
			UserID:         member.UserID,
			UserName:       member.Name,
			Role:           role,
			JoinedAt:       now,
		}
		_ = s.chatRepo.AddParticipant(participant) // Ignore errors for individual adds
	}

	// Load participants for response
	participants, _ := s.chatRepo.GetConversationParticipants(conv.ID)
	conv.Participants = make([]domain.ChatParticipant, len(participants))
	for i, p := range participants {
		conv.Participants[i] = *p
	}

	return conv, nil
}

// SendMessage sends a message to a conversation
func (s *chatService) SendMessage(userID uuid.UUID, req *domain.SendChatMessageRequest) (*domain.ChatMessage, error) {
	// Validate message
	if len(req.Content) > domain.ChatMaxMessageLength {
		return nil, errors.New("message is too long")
	}

	// Check if user is in conversation
	isInConv, err := s.chatRepo.IsUserInConversation(req.ConversationID, userID)
	if err != nil {
		return nil, err
	}
	if !isInConv {
		return nil, errors.New("user is not in this conversation")
	}

	// Get sender info from participants
	participants, err := s.chatRepo.GetConversationParticipants(req.ConversationID)
	if err != nil {
		return nil, err
	}

	var senderName string
	var senderAvatar *string
	for _, p := range participants {
		if p.UserID == userID {
			senderName = p.UserName
			senderAvatar = p.AvatarURL
			break
		}
	}

	messageType := req.MessageType
	if messageType == "" {
		messageType = domain.ChatMessageTypeText
	}

	now := time.Now()
	message := &domain.ChatMessage{
		ID:             uuid.New(),
		ConversationID: req.ConversationID,
		SenderID:       userID,
		SenderName:     senderName,
		SenderAvatar:   senderAvatar,
		MessageType:    messageType,
		Content:        req.Content,
		MediaURL:       req.MediaURL,
		Metadata:       req.Metadata,
		ReplyToID:      req.ReplyToID,
		IsEdited:       false,
		IsDeleted:      false,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	if err := s.chatRepo.CreateMessage(message); err != nil {
		return nil, err
	}

	// Publish chat notification for each participant (except sender)
	for _, p := range participants {
		if p.UserID != userID {
			s.publishNotify("notify.chat.new_message", map[string]interface{}{
				"event_type":        "chat.new_message",
				"target_type":       "user",
				"target_id":         p.UserID.String(),
				"actor_id":          userID.String(),
				"title":             senderName,
				"body":              message.Content,
				"data":              map[string]interface{}{"conversation_id": req.ConversationID.String(), "message_id": message.ID.String()},
				"priority":          "normal",
				"notification_type": "chat",
				"created_at":        time.Now().Format(time.RFC3339),
			})
		}
	}

	return message, nil
}

// GetMessages gets messages for a conversation
func (s *chatService) GetMessages(userID uuid.UUID, conversationID uuid.UUID, limit, offset int) ([]*domain.ChatMessage, error) {
	// Check if user is in conversation
	isInConv, err := s.chatRepo.IsUserInConversation(conversationID, userID)
	if err != nil {
		return nil, err
	}
	if !isInConv {
		return nil, errors.New("user is not in this conversation")
	}

	if limit <= 0 || limit > domain.ChatMaxMessageLimit {
		limit = domain.ChatDefaultMessageLimit
	}

	return s.chatRepo.GetConversationMessages(conversationID, limit, offset)
}

// EditMessage edits a message
func (s *chatService) EditMessage(userID uuid.UUID, messageID uuid.UUID, newContent string) (*domain.ChatMessage, error) {
	message, err := s.chatRepo.GetMessageByID(messageID)
	if err != nil {
		return nil, err
	}
	if message == nil {
		return nil, errors.New("message not found")
	}

	// Only sender can edit
	if message.SenderID != userID {
		return nil, errors.New("can only edit your own messages")
	}

	if message.IsDeleted {
		return nil, errors.New("cannot edit deleted message")
	}

	message.Content = newContent
	message.IsEdited = true
	message.UpdatedAt = time.Now()

	if err := s.chatRepo.UpdateMessage(message); err != nil {
		return nil, err
	}

	return message, nil
}

// DeleteMessage deletes a message
func (s *chatService) DeleteMessage(userID uuid.UUID, messageID uuid.UUID) error {
	message, err := s.chatRepo.GetMessageByID(messageID)
	if err != nil {
		return err
	}
	if message == nil {
		return errors.New("message not found")
	}

	// Only sender can delete
	if message.SenderID != userID {
		return errors.New("can only delete your own messages")
	}

	return s.chatRepo.DeleteMessage(messageID)
}

// MarkAsRead marks messages as read
func (s *chatService) MarkAsRead(userID uuid.UUID, req *domain.MarkReadRequest) error {
	// Check if user is in conversation
	isInConv, err := s.chatRepo.IsUserInConversation(req.ConversationID, userID)
	if err != nil {
		return err
	}
	if !isInConv {
		return errors.New("user is not in this conversation")
	}

	// Get the message to get its timestamp
	message, err := s.chatRepo.GetMessageByID(req.MessageID)
	if err != nil {
		return err
	}
	if message == nil {
		return errors.New("message not found")
	}

	return s.chatRepo.UpdateLastRead(req.ConversationID, userID, message.CreatedAt)
}

// AddParticipant adds a participant to a conversation
func (s *chatService) AddParticipant(conversationID, userID uuid.UUID, userName string) error {
	// Check if conversation exists
	conv, err := s.chatRepo.GetConversationByID(conversationID)
	if err != nil {
		return err
	}
	if conv == nil {
		return errors.New("conversation not found")
	}

	// Only team conversations can have participants added
	if conv.Type != domain.ConversationTypeTeam {
		return errors.New("can only add participants to team conversations")
	}

	participant := &domain.ChatParticipant{
		ID:             uuid.New(),
		ConversationID: conversationID,
		UserID:         userID,
		UserName:       userName,
		Role:           domain.ParticipantRoleMember,
		JoinedAt:       time.Now(),
	}

	return s.chatRepo.AddParticipant(participant)
}

// RemoveParticipant removes a participant from a conversation
func (s *chatService) RemoveParticipant(conversationID, userID, targetUserID uuid.UUID) error {
	// Check if conversation exists
	conv, err := s.chatRepo.GetConversationByID(conversationID)
	if err != nil {
		return err
	}
	if conv == nil {
		return errors.New("conversation not found")
	}

	// Only team conversations can have participants removed
	if conv.Type != domain.ConversationTypeTeam {
		return errors.New("can only remove participants from team conversations")
	}

	// Users can remove themselves, or admins can remove others
	if userID != targetUserID {
		// Check if user is admin
		participants, err := s.chatRepo.GetConversationParticipants(conversationID)
		if err != nil {
			return err
		}

		isAdmin := false
		for _, p := range participants {
			if p.UserID == userID && p.Role == domain.ParticipantRoleAdmin {
				isAdmin = true
				break
			}
		}

		if !isAdmin {
			return errors.New("only admins can remove other participants")
		}
	}

	return s.chatRepo.RemoveParticipant(conversationID, targetUserID)
}

// GetParticipants gets participants for a conversation
func (s *chatService) GetParticipants(conversationID uuid.UUID) ([]*domain.ChatParticipant, error) {
	return s.chatRepo.GetConversationParticipants(conversationID)
}
