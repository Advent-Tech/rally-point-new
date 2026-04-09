-- Legacy Data Reconciliation Migration
-- Handles existing data from before the multi-role verification system
-- This migration is IDEMPOTENT - safe to run multiple times

-- =====================================================
-- 1. ENSURE ALL EXISTING USERS ARE VERIFIED
-- =====================================================
-- Users who were in the system before verification was required
-- should be able to continue logging in

UPDATE users
SET verification_status = 'verified',
    verified_at = COALESCE(verified_at, created_at)
WHERE verification_status IS NULL
   OR verification_status = 'pending'
   OR verification_status = '';

-- =====================================================
-- 2. CREATE ADMIN IF NOT EXISTS
-- =====================================================
-- If no admin exists (besides superadmin), create a default admin
-- for managing the system during transition

INSERT INTO users (id, email, password_hash, display_name, role, verification_status, is_online, last_active_at, created_at, updated_at)
SELECT
    uuid_generate_v4(),
    'admin@rallypoint.com',
    '$2a$10$YabTJ3GmOUnoLHEkQGtOXuodb97tIYW6vE4SVfyF.9aJOAeDIBpDe', -- admin123
    'System Admin',
    'admin',
    'verified',
    false,
    NOW(),
    NOW(),
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM users WHERE role = 'admin'
);

-- =====================================================
-- 3. RETROACTIVE JOIN REQUESTS FOR EXISTING WORKERS
-- =====================================================
-- Workers who already have team_id set were approved before
-- the join request system. Create approved records for them.

INSERT INTO team_join_requests (
    id,
    user_id,
    team_id,
    status,
    message,
    requested_at,
    reviewed_at,
    created_at,
    updated_at
)
SELECT
    uuid_generate_v4(),
    u.id,
    u.team_id,
    'approved',
    'Legacy worker - pre-existing team membership',
    u.created_at,  -- Assume they requested when they were created
    u.created_at,  -- Assume approved immediately (legacy)
    NOW(),
    NOW()
FROM users u
WHERE u.role = 'worker'
  AND u.team_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM team_join_requests tjr
      WHERE tjr.user_id = u.id AND tjr.team_id = u.team_id
  )
ON CONFLICT (user_id, team_id) DO NOTHING;

-- =====================================================
-- 4. ENSURE TEAM LEADERS HAVE TEAMS
-- =====================================================
-- Legacy team leaders who created teams during signup
-- Verify they are properly linked

-- First, ensure team leader's team has them as leader
UPDATE teams t
SET leader_id = u.id
FROM users u
WHERE u.role = 'team_leader'
  AND u.team_id = t.id
  AND t.leader_id IS NULL;

-- =====================================================
-- 5. RETROACTIVE TERRITORY ALLOCATIONS
-- =====================================================
-- For existing territory assignments to workers,
-- create allocation records for their team leaders
-- so they have proper authority over those territories

INSERT INTO leader_territory_allocations (
    id,
    leader_id,
    territory_id,
    allocated_by,
    allocated_at,
    status,
    notes,
    created_at,
    updated_at
)
SELECT DISTINCT
    uuid_generate_v4(),
    t.leader_id,
    ta.territory_id,
    (SELECT id FROM users WHERE role = 'superadmin' LIMIT 1), -- Allocated by superadmin
    ta.assigned_at,
    'active',
    'Legacy allocation - retroactively created for existing territory assignments',
    NOW(),
    NOW()
FROM territory_assignments ta
JOIN teams t ON ta.team_id = t.id
WHERE t.leader_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM leader_territory_allocations lta
      WHERE lta.leader_id = t.leader_id
        AND lta.territory_id = ta.territory_id
  )
ON CONFLICT (leader_id, territory_id) DO NOTHING;

-- =====================================================
-- 6. UPDATE WORKER COUNTS ON TEAMS
-- =====================================================
-- Ensure worker_count is accurate

UPDATE teams t
SET worker_count = (
    SELECT COUNT(*)
    FROM users u
    WHERE u.team_id = t.id
      AND u.role = 'worker'
);

-- =====================================================
-- 7. DATA INTEGRITY REPORT
-- =====================================================
-- This creates a temporary view to check migration results
-- (Can be queried after migration to verify)

DO $$
DECLARE
    v_total_users INTEGER;
    v_verified_users INTEGER;
    v_pending_users INTEGER;
    v_workers_with_teams INTEGER;
    v_workers_without_teams INTEGER;
    v_leaders_count INTEGER;
    v_teams_count INTEGER;
    v_join_requests_count INTEGER;
    v_allocations_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_users FROM users;
    SELECT COUNT(*) INTO v_verified_users FROM users WHERE verification_status = 'verified';
    SELECT COUNT(*) INTO v_pending_users FROM users WHERE verification_status = 'pending';
    SELECT COUNT(*) INTO v_workers_with_teams FROM users WHERE role = 'worker' AND team_id IS NOT NULL;
    SELECT COUNT(*) INTO v_workers_without_teams FROM users WHERE role = 'worker' AND team_id IS NULL;
    SELECT COUNT(*) INTO v_leaders_count FROM users WHERE role = 'team_leader';
    SELECT COUNT(*) INTO v_teams_count FROM teams;
    SELECT COUNT(*) INTO v_join_requests_count FROM team_join_requests;
    SELECT COUNT(*) INTO v_allocations_count FROM leader_territory_allocations;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'LEGACY DATA RECONCILIATION COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total Users: %', v_total_users;
    RAISE NOTICE 'Verified Users: %', v_verified_users;
    RAISE NOTICE 'Pending Users: %', v_pending_users;
    RAISE NOTICE 'Workers with Teams: %', v_workers_with_teams;
    RAISE NOTICE 'Workers without Teams: %', v_workers_without_teams;
    RAISE NOTICE 'Team Leaders: %', v_leaders_count;
    RAISE NOTICE 'Teams: %', v_teams_count;
    RAISE NOTICE 'Join Requests (created): %', v_join_requests_count;
    RAISE NOTICE 'Territory Allocations (created): %', v_allocations_count;
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- 8. HANDLE EDGE CASE: WORKERS WITHOUT TEAMS
-- =====================================================
-- Workers who registered but never got a team assignment
-- They are now verified but need to request to join a team
-- Option 1: Leave them as verified, they can login and request team
-- Option 2: Set them to pending until they join a team

-- We'll go with Option 1 (more user-friendly)
-- But add a note in their profile that they need a team

COMMENT ON COLUMN users.team_id IS
'Workers must have a team_id to access full functionality.
 Legacy workers without teams can login but should request to join a team.';
