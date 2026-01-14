-- Multi-Role System Migration
-- Adds superadmin role, verification system, team join requests, and leader territory allocations

-- =====================================================
-- USER VERIFICATION SYSTEM
-- =====================================================

-- Add verification columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_status VARCHAR(20) DEFAULT 'pending';
ALTER TABLE users ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Set existing users as verified (they were already in the system)
UPDATE users SET verification_status = 'verified' WHERE verification_status IS NULL OR verification_status = 'pending';

-- Create index on verification_status for filtering
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON users(verification_status);

-- =====================================================
-- TEAM JOIN REQUESTS
-- =====================================================

-- Create team join requests table
CREATE TABLE IF NOT EXISTS team_join_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, approved, rejected
    message TEXT, -- optional message from worker
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, team_id)
);

-- Indexes for team join requests
CREATE INDEX IF NOT EXISTS idx_team_join_requests_user_id ON team_join_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_team_join_requests_team_id ON team_join_requests(team_id);
CREATE INDEX IF NOT EXISTS idx_team_join_requests_status ON team_join_requests(status);

-- Trigger for updated_at
CREATE TRIGGER update_team_join_requests_updated_at
    BEFORE UPDATE ON team_join_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- LEADER TERRITORY ALLOCATIONS
-- =====================================================

-- Create leader territory allocations table
-- This tracks which territories admin has allocated to team leaders
CREATE TABLE IF NOT EXISTS leader_territory_allocations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    leader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    territory_id UUID NOT NULL REFERENCES territories(id) ON DELETE CASCADE,
    allocated_by UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    allocated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active', -- active, revoked, expired
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(leader_id, territory_id)
);

-- Indexes for leader territory allocations
CREATE INDEX IF NOT EXISTS idx_leader_territory_allocations_leader_id ON leader_territory_allocations(leader_id);
CREATE INDEX IF NOT EXISTS idx_leader_territory_allocations_territory_id ON leader_territory_allocations(territory_id);
CREATE INDEX IF NOT EXISTS idx_leader_territory_allocations_status ON leader_territory_allocations(status);

-- Trigger for updated_at
CREATE TRIGGER update_leader_territory_allocations_updated_at
    BEFORE UPDATE ON leader_territory_allocations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SEED SUPERADMIN USER
-- =====================================================

-- Insert superadmin user (password: SuperAdmin123! - CHANGE IN PRODUCTION)
-- bcrypt hash for 'SuperAdmin123!'
INSERT INTO users (id, email, password_hash, display_name, role, verification_status, is_online, last_active_at, created_at, updated_at)
VALUES (
    uuid_generate_v4(),
    'superadmin@rallypoint.com',
    '$2a$10$rQEY9S4f8N8TJuXWg8ZB4.G3HJtLXJz5Y8kT5YJzQ8R8Z5X8G9K2a', -- SuperAdmin123!
    'Super Admin',
    'superadmin',
    'verified',
    false,
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to check if a user can assign a territory to a worker
-- (Leader must have the territory allocated to them by admin)
CREATE OR REPLACE FUNCTION can_leader_assign_territory(
    p_leader_id UUID,
    p_territory_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_allocation_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM leader_territory_allocations
        WHERE leader_id = p_leader_id
        AND territory_id = p_territory_id
        AND status = 'active'
        AND (expires_at IS NULL OR expires_at > NOW())
    ) INTO v_allocation_exists;

    RETURN v_allocation_exists;
END;
$$ LANGUAGE plpgsql;

-- Function to get all territories allocated to a leader
CREATE OR REPLACE FUNCTION get_leader_allocated_territories(p_leader_id UUID)
RETURNS TABLE (
    allocation_id UUID,
    territory_id UUID,
    territory_solid VARCHAR,
    territory_name VARCHAR,
    allocated_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        lta.id as allocation_id,
        lta.territory_id,
        t.solid as territory_solid,
        t.entity_name as territory_name,
        lta.allocated_at,
        lta.expires_at,
        lta.status
    FROM leader_territory_allocations lta
    JOIN territories t ON t.id = lta.territory_id
    WHERE lta.leader_id = p_leader_id
    AND lta.status = 'active'
    AND (lta.expires_at IS NULL OR lta.expires_at > NOW())
    ORDER BY lta.allocated_at DESC;
END;
$$ LANGUAGE plpgsql;
