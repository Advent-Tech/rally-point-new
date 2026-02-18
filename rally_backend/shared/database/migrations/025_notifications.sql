-- 025_notifications.sql
-- Notification system: device tokens, notifications, and preferences

-- Device tokens for push notifications (FCM)
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL DEFAULT 'android', -- android, ios, web
    device_id VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(token)
);

-- Index for looking up active tokens by user
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_active
    ON device_tokens (user_id, is_active) WHERE is_active = TRUE;

-- Notifications table (persistent history)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- geofence, prayer, delivery, survey, team, walkie, chat, session
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    data JSONB DEFAULT '{}',
    priority VARCHAR(20) NOT NULL DEFAULT 'normal', -- low, normal, high
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    group_key VARCHAR(255), -- for grouping related notifications
    actor_id UUID, -- who triggered this notification (to skip self-notify)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unread notifications (most common query)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications (user_id, is_read, created_at DESC) WHERE is_read = FALSE;

-- All notifications for a user (notification center)
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON notifications (user_id, created_at DESC);

-- Notification preferences per user per type
CREATE TABLE IF NOT EXISTS notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL,
    in_app_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(user_id, notification_type)
);
