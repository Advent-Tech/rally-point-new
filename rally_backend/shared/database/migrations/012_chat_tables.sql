-- Chat feature tables for member-to-member and team messaging
-- Migration: 012_chat_tables.sql

-- Chat conversations table
CREATE TABLE IF NOT EXISTS chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL CHECK (type IN ('direct', 'team')),
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_message_at TIMESTAMP WITH TIME ZONE,
    last_message TEXT,
    last_message_by VARCHAR(255)
);

-- Create index for team conversations
CREATE INDEX IF NOT EXISTS idx_chat_conversations_team ON chat_conversations(team_id) WHERE team_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_chat_conversations_type ON chat_conversations(type);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_last_message ON chat_conversations(last_message_at DESC NULLS LAST);

-- Chat participants table
CREATE TABLE IF NOT EXISTS chat_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    role VARCHAR(20) NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_read_at TIMESTAMP WITH TIME ZONE,
    is_muted BOOLEAN DEFAULT FALSE,
    UNIQUE(conversation_id, user_id)
);

-- Create indexes for participants
CREATE INDEX IF NOT EXISTS idx_chat_participants_conversation ON chat_participants(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_last_read ON chat_participants(last_read_at);

-- Chat messages table
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    sender_name VARCHAR(255) NOT NULL,
    sender_avatar TEXT,
    message_type VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'location', 'system')),
    content TEXT NOT NULL,
    media_url TEXT,
    metadata JSONB,
    reply_to_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL,
    is_edited BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for messages
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation ON chat_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON chat_messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_reply ON chat_messages(reply_to_id) WHERE reply_to_id IS NOT NULL;

-- Create trigger to update updated_at on conversation changes
CREATE OR REPLACE FUNCTION update_chat_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS chat_conversation_updated ON chat_conversations;
CREATE TRIGGER chat_conversation_updated
    BEFORE UPDATE ON chat_conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_conversation_timestamp();

-- Create trigger to update updated_at on message changes
CREATE OR REPLACE FUNCTION update_chat_message_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS chat_message_updated ON chat_messages;
CREATE TRIGGER chat_message_updated
    BEFORE UPDATE ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_message_timestamp();

-- Add comments for documentation
COMMENT ON TABLE chat_conversations IS 'Chat conversations for direct and team messaging';
COMMENT ON TABLE chat_participants IS 'Participants in chat conversations';
COMMENT ON TABLE chat_messages IS 'Chat messages within conversations';
COMMENT ON COLUMN chat_conversations.type IS 'Type of conversation: direct (1-to-1) or team (group)';
COMMENT ON COLUMN chat_messages.message_type IS 'Type of message content: text, image, file, location, or system';
