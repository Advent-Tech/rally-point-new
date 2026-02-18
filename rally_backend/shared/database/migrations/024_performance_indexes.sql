-- Performance indexes for scalability
-- Migration: 024_performance_indexes.sql

-- Composite index for GetLastTrackForSession query:
-- SELECT ... FROM location_tracks WHERE session_id = $1 ORDER BY tracked_at DESC LIMIT 1
-- The existing idx_location_tracks_session_id is single-column and requires a sort step.
-- This composite index serves the query directly via index-only backward scan.
CREATE INDEX IF NOT EXISTS idx_location_tracks_session_tracked
    ON location_tracks (session_id, tracked_at DESC);

-- Partial index for active session lookup:
-- SELECT ... FROM location_sessions WHERE user_id = $1 AND is_active = true
-- Only indexes active sessions (typically <1% of rows), very small and fast.
CREATE INDEX IF NOT EXISTS idx_location_sessions_user_active
    ON location_sessions (user_id) WHERE is_active = true;

-- Index for batch writer: tracks created in recent time window
-- Helps cleanup queries and analytics that filter by created_at
CREATE INDEX IF NOT EXISTS idx_location_tracks_created_at
    ON location_tracks (created_at DESC);

-- Index for prayer_requests common queries (by status, by territory)
CREATE INDEX IF NOT EXISTS idx_prayer_requests_status
    ON prayer_requests (status) WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_prayer_requests_territory
    ON prayer_requests (territory_id) WHERE territory_id IS NOT NULL;

-- Index for donations time-range queries
CREATE INDEX IF NOT EXISTS idx_donations_created_at
    ON donations (created_at DESC);

-- Index for blog listing (published, ordered by date)
CREATE INDEX IF NOT EXISTS idx_blogs_published
    ON blogs (created_at DESC) WHERE is_published = true;
