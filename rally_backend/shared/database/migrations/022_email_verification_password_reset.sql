-- Email Verification and Password Reset Migration
-- Migration: 022_email_verification_password_reset.sql

-- =====================================================
-- ADD EMAIL VERIFIED COLUMNS TO USERS TABLE
-- =====================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP WITH TIME ZONE;

-- Set existing verified users as email_verified (grandfathering existing users)
UPDATE users SET email_verified = TRUE WHERE verification_status = 'verified';

-- Also mark admins and superadmins as email verified (they are pre-verified)
UPDATE users SET email_verified = TRUE WHERE role IN ('admin', 'superadmin');

-- Create index for filtering by email_verified
CREATE INDEX IF NOT EXISTS idx_users_email_verified ON users(email_verified);

-- =====================================================
-- VERIFICATION TOKENS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS verification_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL,
    token_type VARCHAR(20) NOT NULL CHECK (token_type IN ('email_verification', 'password_reset')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for verification_tokens
CREATE INDEX IF NOT EXISTS idx_verification_tokens_user_id ON verification_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_tokens_token_hash ON verification_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_verification_tokens_type ON verification_tokens(token_type);
CREATE INDEX IF NOT EXISTS idx_verification_tokens_expires_at ON verification_tokens(expires_at);

-- Composite index for finding active tokens
CREATE INDEX IF NOT EXISTS idx_verification_tokens_active
    ON verification_tokens(user_id, token_type)
    WHERE used_at IS NULL;

-- =====================================================
-- CLEANUP FUNCTION FOR EXPIRED TOKENS
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_expired_verification_tokens()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM verification_tokens
    WHERE expires_at < NOW() OR used_at IS NOT NULL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE verification_tokens IS 'Stores email verification and password reset tokens';
COMMENT ON COLUMN verification_tokens.token_hash IS 'SHA256 hash of the token (plain token sent to user)';
COMMENT ON COLUMN verification_tokens.token_type IS 'Type of token: email_verification or password_reset';
COMMENT ON COLUMN verification_tokens.used_at IS 'Timestamp when token was used (NULL if still valid)';
COMMENT ON COLUMN users.email_verified IS 'Whether the user has verified their email address';
COMMENT ON COLUMN users.email_verified_at IS 'Timestamp when email was verified';
