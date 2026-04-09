package postgres

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
	"rally-point/walkie-service/internal/domain"
)

type chatRepository struct {
	db *sql.DB
}

// NewChatRepository creates a new chat repository
func NewChatRepository(db *sql.DB) domain.ChatRepository {
	return &chatRepository{db: db}
}

// CreateConversation creates a new conversation
func (r *chatRepository) CreateConversation(conv *domain.ChatConversation) error {
	query := `
		INSERT INTO chat_conversations (id, type, team_id, name, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.db.Exec(query, conv.ID, conv.Type, conv.TeamID, conv.Name, conv.CreatedAt, conv.UpdatedAt)
	return err
}

// GetConversationByID gets a conversation by ID
func (r *chatRepository) GetConversationByID(id uuid.UUID) (*domain.ChatConversation, error) {
	query := `
		SELECT id, type, team_id, name, created_at, updated_at, last_message_at, last_message, last_message_by
		FROM chat_conversations WHERE id = $1
	`
	conv := &domain.ChatConversation{}
	err := r.db.QueryRow(query, id).Scan(
		&conv.ID, &conv.Type, &conv.TeamID, &conv.Name,
		&conv.CreatedAt, &conv.UpdatedAt, &conv.LastMessageAt,
		&conv.LastMessage, &conv.LastMessageBy,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return conv, nil
}

// GetDirectConversation finds an existing direct conversation between two users
func (r *chatRepository) GetDirectConversation(userID1, userID2 uuid.UUID) (*domain.ChatConversation, error) {
	query := `
		SELECT c.id, c.type, c.team_id, c.name, c.created_at, c.updated_at,
		       c.last_message_at, c.last_message, c.last_message_by
		FROM chat_conversations c
		WHERE c.type = 'direct'
		AND c.id IN (
			SELECT conversation_id FROM chat_participants WHERE user_id = $1
			INTERSECT
			SELECT conversation_id FROM chat_participants WHERE user_id = $2
		)
		AND (SELECT COUNT(*) FROM chat_participants WHERE conversation_id = c.id) = 2
		LIMIT 1
	`
	conv := &domain.ChatConversation{}
	err := r.db.QueryRow(query, userID1, userID2).Scan(
		&conv.ID, &conv.Type, &conv.TeamID, &conv.Name,
		&conv.CreatedAt, &conv.UpdatedAt, &conv.LastMessageAt,
		&conv.LastMessage, &conv.LastMessageBy,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return conv, nil
}

// GetUserConversations gets all conversations for a user
func (r *chatRepository) GetUserConversations(userID uuid.UUID, limit, offset int) ([]*domain.ChatConversation, error) {
	query := `
		SELECT c.id, c.type, c.team_id, c.name, c.created_at, c.updated_at,
		       c.last_message_at, c.last_message, c.last_message_by
		FROM chat_conversations c
		JOIN chat_participants p ON c.id = p.conversation_id
		WHERE p.user_id = $1
		ORDER BY COALESCE(c.last_message_at, c.created_at) DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var conversations []*domain.ChatConversation
	for rows.Next() {
		conv := &domain.ChatConversation{}
		err := rows.Scan(
			&conv.ID, &conv.Type, &conv.TeamID, &conv.Name,
			&conv.CreatedAt, &conv.UpdatedAt, &conv.LastMessageAt,
			&conv.LastMessage, &conv.LastMessageBy,
		)
		if err != nil {
			return nil, err
		}
		conversations = append(conversations, conv)
	}
	return conversations, nil
}

// UpdateConversation updates a conversation
func (r *chatRepository) UpdateConversation(conv *domain.ChatConversation) error {
	query := `
		UPDATE chat_conversations
		SET name = $2, updated_at = $3, last_message_at = $4, last_message = $5, last_message_by = $6
		WHERE id = $1
	`
	_, err := r.db.Exec(query, conv.ID, conv.Name, conv.UpdatedAt, conv.LastMessageAt, conv.LastMessage, conv.LastMessageBy)
	return err
}

// DeleteConversation deletes a conversation
func (r *chatRepository) DeleteConversation(id uuid.UUID) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Delete messages first
	_, err = tx.Exec("DELETE FROM chat_messages WHERE conversation_id = $1", id)
	if err != nil {
		return err
	}

	// Delete participants
	_, err = tx.Exec("DELETE FROM chat_participants WHERE conversation_id = $1", id)
	if err != nil {
		return err
	}

	// Delete conversation
	_, err = tx.Exec("DELETE FROM chat_conversations WHERE id = $1", id)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// AddParticipant adds a participant to a conversation
func (r *chatRepository) AddParticipant(participant *domain.ChatParticipant) error {
	query := `
		INSERT INTO chat_participants (id, conversation_id, user_id, user_name, avatar_url, role, joined_at, is_muted)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (conversation_id, user_id) DO NOTHING
	`
	_, err := r.db.Exec(query,
		participant.ID, participant.ConversationID, participant.UserID,
		participant.UserName, participant.AvatarURL, participant.Role,
		participant.JoinedAt, participant.IsMuted,
	)
	return err
}

// RemoveParticipant removes a participant from a conversation
func (r *chatRepository) RemoveParticipant(conversationID, userID uuid.UUID) error {
	query := `DELETE FROM chat_participants WHERE conversation_id = $1 AND user_id = $2`
	_, err := r.db.Exec(query, conversationID, userID)
	return err
}

// GetConversationParticipants gets all participants in a conversation
func (r *chatRepository) GetConversationParticipants(conversationID uuid.UUID) ([]*domain.ChatParticipant, error) {
	query := `
		SELECT id, conversation_id, user_id, user_name, avatar_url, role, joined_at, last_read_at, is_muted
		FROM chat_participants
		WHERE conversation_id = $1
		ORDER BY joined_at ASC
	`
	rows, err := r.db.Query(query, conversationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var participants []*domain.ChatParticipant
	for rows.Next() {
		p := &domain.ChatParticipant{}
		err := rows.Scan(
			&p.ID, &p.ConversationID, &p.UserID, &p.UserName,
			&p.AvatarURL, &p.Role, &p.JoinedAt, &p.LastReadAt, &p.IsMuted,
		)
		if err != nil {
			return nil, err
		}
		participants = append(participants, p)
	}
	return participants, nil
}

// IsUserInConversation checks if a user is in a conversation
func (r *chatRepository) IsUserInConversation(conversationID, userID uuid.UUID) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM chat_participants WHERE conversation_id = $1 AND user_id = $2)`
	var exists bool
	err := r.db.QueryRow(query, conversationID, userID).Scan(&exists)
	return exists, err
}

// UpdateLastRead updates the last read timestamp for a user in a conversation
func (r *chatRepository) UpdateLastRead(conversationID, userID uuid.UUID, timestamp time.Time) error {
	query := `UPDATE chat_participants SET last_read_at = $3 WHERE conversation_id = $1 AND user_id = $2`
	_, err := r.db.Exec(query, conversationID, userID, timestamp)
	return err
}

// CreateMessage creates a new message
func (r *chatRepository) CreateMessage(message *domain.ChatMessage) error {
	query := `
		INSERT INTO chat_messages (id, conversation_id, sender_id, sender_name, sender_avatar,
		                           message_type, content, media_url, metadata, reply_to_id,
		                           is_edited, is_deleted, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
	`
	_, err := r.db.Exec(query,
		message.ID, message.ConversationID, message.SenderID, message.SenderName,
		message.SenderAvatar, message.MessageType, message.Content, message.MediaURL,
		message.Metadata, message.ReplyToID, message.IsEdited, message.IsDeleted,
		message.CreatedAt, message.UpdatedAt,
	)
	if err != nil {
		return err
	}

	// Update conversation's last message
	updateQuery := `
		UPDATE chat_conversations
		SET last_message_at = $2, last_message = $3, last_message_by = $4, updated_at = $5
		WHERE id = $1
	`
	_, err = r.db.Exec(updateQuery, message.ConversationID, message.CreatedAt, message.Content, message.SenderName, message.CreatedAt)
	return err
}

// GetMessageByID gets a message by ID
func (r *chatRepository) GetMessageByID(id uuid.UUID) (*domain.ChatMessage, error) {
	query := `
		SELECT id, conversation_id, sender_id, sender_name, sender_avatar, message_type,
		       content, media_url, metadata, reply_to_id, is_edited, is_deleted, created_at, updated_at
		FROM chat_messages WHERE id = $1
	`
	msg := &domain.ChatMessage{}
	err := r.db.QueryRow(query, id).Scan(
		&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.SenderName,
		&msg.SenderAvatar, &msg.MessageType, &msg.Content, &msg.MediaURL,
		&msg.Metadata, &msg.ReplyToID, &msg.IsEdited, &msg.IsDeleted,
		&msg.CreatedAt, &msg.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return msg, nil
}

// GetConversationMessages gets messages for a conversation
func (r *chatRepository) GetConversationMessages(conversationID uuid.UUID, limit, offset int) ([]*domain.ChatMessage, error) {
	query := `
		SELECT id, conversation_id, sender_id, sender_name, sender_avatar, message_type,
		       content, media_url, metadata, reply_to_id, is_edited, is_deleted, created_at, updated_at
		FROM chat_messages
		WHERE conversation_id = $1 AND is_deleted = false
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(query, conversationID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []*domain.ChatMessage
	for rows.Next() {
		msg := &domain.ChatMessage{}
		err := rows.Scan(
			&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.SenderName,
			&msg.SenderAvatar, &msg.MessageType, &msg.Content, &msg.MediaURL,
			&msg.Metadata, &msg.ReplyToID, &msg.IsEdited, &msg.IsDeleted,
			&msg.CreatedAt, &msg.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}

	// Reverse to get oldest first for display
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, nil
}

// UpdateMessage updates a message
func (r *chatRepository) UpdateMessage(message *domain.ChatMessage) error {
	query := `
		UPDATE chat_messages
		SET content = $2, is_edited = $3, updated_at = $4
		WHERE id = $1
	`
	_, err := r.db.Exec(query, message.ID, message.Content, true, time.Now())
	return err
}

// DeleteMessage soft deletes a message
func (r *chatRepository) DeleteMessage(id uuid.UUID) error {
	query := `UPDATE chat_messages SET is_deleted = true, content = '[Message deleted]', updated_at = $2 WHERE id = $1`
	_, err := r.db.Exec(query, id, time.Now())
	return err
}

// GetUnreadCount gets the unread message count for a user in a conversation
func (r *chatRepository) GetUnreadCount(conversationID, userID uuid.UUID) (int, error) {
	query := `
		SELECT COUNT(*) FROM chat_messages m
		JOIN chat_participants p ON m.conversation_id = p.conversation_id AND p.user_id = $2
		WHERE m.conversation_id = $1
		AND m.sender_id != $2
		AND m.is_deleted = false
		AND (p.last_read_at IS NULL OR m.created_at > p.last_read_at)
	`
	var count int
	err := r.db.QueryRow(query, conversationID, userID).Scan(&count)
	return count, err
}

// GetTeamConversation gets the team conversation for a team
func (r *chatRepository) GetTeamConversation(teamID uuid.UUID) (*domain.ChatConversation, error) {
	query := `
		SELECT id, type, team_id, name, created_at, updated_at, last_message_at, last_message, last_message_by
		FROM chat_conversations WHERE type = 'team' AND team_id = $1
		LIMIT 1
	`
	conv := &domain.ChatConversation{}
	err := r.db.QueryRow(query, teamID).Scan(
		&conv.ID, &conv.Type, &conv.TeamID, &conv.Name,
		&conv.CreatedAt, &conv.UpdatedAt, &conv.LastMessageAt,
		&conv.LastMessage, &conv.LastMessageBy,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return conv, nil
}

// CreateTeamConversation creates a team conversation
func (r *chatRepository) CreateTeamConversation(teamID uuid.UUID, teamName string) (*domain.ChatConversation, error) {
	now := time.Now()
	conv := &domain.ChatConversation{
		ID:        uuid.New(),
		Type:      domain.ConversationTypeTeam,
		TeamID:    &teamID,
		Name:      &teamName,
		CreatedAt: now,
		UpdatedAt: now,
	}

	err := r.CreateConversation(conv)
	if err != nil {
		return nil, err
	}
	return conv, nil
}

// GetTeamMembers gets all members of a team from the users table
func (r *chatRepository) GetTeamMembers(teamID uuid.UUID) ([]*domain.TeamMember, error) {
	query := `
		SELECT id, display_name, email, is_online
		FROM users
		WHERE team_id = $1
		ORDER BY display_name ASC
	`
	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []*domain.TeamMember
	for rows.Next() {
		m := &domain.TeamMember{}
		err := rows.Scan(&m.UserID, &m.Name, &m.Email, &m.IsOnline)
		if err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, nil
}

// GetUserByID gets a user's info from the users table
func (r *chatRepository) GetUserByID(userID uuid.UUID) (*domain.TeamMember, error) {
	query := `
		SELECT id, COALESCE(display_name, 'User'), COALESCE(email, ''), COALESCE(is_online, false)
		FROM users
		WHERE id = $1
	`
	m := &domain.TeamMember{}
	err := r.db.QueryRow(query, userID).Scan(&m.UserID, &m.Name, &m.Email, &m.IsOnline)
	if err != nil {
		return nil, err
	}
	return m, nil
}
