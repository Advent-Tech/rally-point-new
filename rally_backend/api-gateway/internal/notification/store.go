package notification

import (
	"database/sql"
	"encoding/json"
	"time"
)

// Store handles notification persistence in PostgreSQL
type Store struct {
	db *sql.DB
}

// NewStore creates a new notification store
func NewStore(db *sql.DB) *Store {
	return &Store{db: db}
}

// CreateNotification persists a notification and returns its ID
func (s *Store) CreateNotification(n *Notification) error {
	data := n.Data
	if data == nil {
		data = json.RawMessage(`{}`)
	}
	return s.db.QueryRow(`
		INSERT INTO notifications (user_id, type, title, body, data, priority, group_key, actor_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NULLIF($8, '')::uuid)
		RETURNING id, created_at`,
		n.UserID, n.Type, n.Title, n.Body, data, n.Priority, n.GroupKey, n.ActorID,
	).Scan(&n.ID, &n.CreatedAt)
}

// GetNotifications returns paginated notifications for a user
func (s *Store) GetNotifications(userID string, limit, offset int) ([]Notification, error) {
	rows, err := s.db.Query(`
		SELECT id, user_id, type, title, body, data, priority, is_read, read_at, group_key,
		       COALESCE(actor_id::text, '') as actor_id, created_at
		FROM notifications
		WHERE user_id = $1::uuid
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []Notification
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.Data,
			&n.Priority, &n.IsRead, &n.ReadAt, &n.GroupKey, &n.ActorID, &n.CreatedAt); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}
	return notifications, rows.Err()
}

// GetUnreadCount returns the number of unread notifications for a user
func (s *Store) GetUnreadCount(userID string) (int, error) {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM notifications
		WHERE user_id = $1::uuid AND is_read = FALSE`, userID).Scan(&count)
	return count, err
}

// MarkAsRead marks a single notification as read
func (s *Store) MarkAsRead(notificationID, userID string) error {
	_, err := s.db.Exec(`
		UPDATE notifications SET is_read = TRUE, read_at = $1
		WHERE id = $2::uuid AND user_id = $3::uuid`,
		time.Now(), notificationID, userID)
	return err
}

// MarkAllAsRead marks all unread notifications as read for a user
func (s *Store) MarkAllAsRead(userID string) error {
	_, err := s.db.Exec(`
		UPDATE notifications SET is_read = TRUE, read_at = $1
		WHERE user_id = $2::uuid AND is_read = FALSE`,
		time.Now(), userID)
	return err
}

// DeleteNotification deletes a notification
func (s *Store) DeleteNotification(notificationID, userID string) error {
	_, err := s.db.Exec(`DELETE FROM notifications WHERE id = $1::uuid AND user_id = $2::uuid`,
		notificationID, userID)
	return err
}

// SaveDeviceToken upserts a device token for a user
func (s *Store) SaveDeviceToken(token *DeviceToken) error {
	_, err := s.db.Exec(`
		INSERT INTO device_tokens (user_id, token, platform, device_id)
		VALUES ($1::uuid, $2, $3, $4)
		ON CONFLICT (token) DO UPDATE
		SET user_id = $1::uuid, platform = $3, device_id = $4, is_active = TRUE, updated_at = NOW()`,
		token.UserID, token.Token, token.Platform, token.DeviceID)
	return err
}

// RemoveDeviceToken deactivates a device token
func (s *Store) RemoveDeviceToken(token, userID string) error {
	_, err := s.db.Exec(`
		UPDATE device_tokens SET is_active = FALSE, updated_at = NOW()
		WHERE token = $1 AND user_id = $2::uuid`, token, userID)
	return err
}

// GetActiveTokens returns all active device tokens for a user
func (s *Store) GetActiveTokens(userID string) ([]DeviceToken, error) {
	rows, err := s.db.Query(`
		SELECT id, user_id, token, platform, COALESCE(device_id, '') as device_id, is_active, created_at, updated_at
		FROM device_tokens
		WHERE user_id = $1::uuid AND is_active = TRUE`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []DeviceToken
	for rows.Next() {
		var t DeviceToken
		if err := rows.Scan(&t.ID, &t.UserID, &t.Token, &t.Platform, &t.DeviceID,
			&t.IsActive, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

// DeactivateToken marks a specific token as inactive (stale token cleanup)
func (s *Store) DeactivateToken(token string) error {
	_, err := s.db.Exec(`UPDATE device_tokens SET is_active = FALSE, updated_at = NOW() WHERE token = $1`, token)
	return err
}

// GetPreferences returns notification preferences for a user
func (s *Store) GetPreferences(userID string) ([]NotificationPreference, error) {
	rows, err := s.db.Query(`
		SELECT id, user_id, notification_type, in_app_enabled, push_enabled
		FROM notification_preferences
		WHERE user_id = $1::uuid`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var prefs []NotificationPreference
	for rows.Next() {
		var p NotificationPreference
		if err := rows.Scan(&p.ID, &p.UserID, &p.NotificationType, &p.InAppEnabled, &p.PushEnabled); err != nil {
			return nil, err
		}
		prefs = append(prefs, p)
	}
	return prefs, rows.Err()
}

// UpdatePreference upserts a notification preference
func (s *Store) UpdatePreference(userID, notificationType string, inApp, push bool) error {
	_, err := s.db.Exec(`
		INSERT INTO notification_preferences (user_id, notification_type, in_app_enabled, push_enabled)
		VALUES ($1::uuid, $2, $3, $4)
		ON CONFLICT (user_id, notification_type) DO UPDATE
		SET in_app_enabled = $3, push_enabled = $4`,
		userID, notificationType, inApp, push)
	return err
}

// GetTeamMemberIDs returns all user IDs for members of a team
func (s *Store) GetTeamMemberIDs(teamID string) ([]string, error) {
	rows, err := s.db.Query(`
		SELECT id::text FROM users
		WHERE team_id = $1::uuid`, teamID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// GetTeamLeaderID returns the user ID of the team leader for a given team
func (s *Store) GetTeamLeaderID(teamID string) (string, error) {
	var leaderID string
	err := s.db.QueryRow(`
		SELECT id::text FROM users
		WHERE team_id = $1::uuid AND role = 'team_leader'
		LIMIT 1`, teamID).Scan(&leaderID)
	return leaderID, err
}

// GetUserTeamLeaderID returns the team leader's user ID given any team member's user ID
func (s *Store) GetUserTeamLeaderID(userID string) (string, error) {
	var leaderID string
	err := s.db.QueryRow(`
		SELECT l.id::text FROM users u
		JOIN users l ON l.team_id = u.team_id AND l.role = 'team_leader'
		WHERE u.id = $1::uuid
		LIMIT 1`, userID).Scan(&leaderID)
	return leaderID, err
}
