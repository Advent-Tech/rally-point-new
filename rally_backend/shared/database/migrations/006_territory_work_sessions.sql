-- Territory Work Sessions Migration
-- Tracks when workers enter and exit assigned territories

-- Table to track worker sessions within territories
CREATE TABLE IF NOT EXISTS territory_work_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Worker info
    worker_id UUID NOT NULL,

    -- Territory info (from geo territories via assignment)
    territory_id UUID NOT NULL REFERENCES territories(id) ON DELETE CASCADE,
    assignment_id UUID REFERENCES territory_assignments(id) ON DELETE SET NULL,

    -- Session timing
    entry_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    exit_time TIMESTAMPTZ,

    -- Entry/exit locations
    entry_lat DECIMAL(10, 8) NOT NULL,
    entry_lng DECIMAL(11, 8) NOT NULL,
    exit_lat DECIMAL(10, 8),
    exit_lng DECIMAL(11, 8),

    -- Calculated metrics
    time_spent_seconds INTEGER DEFAULT 0,
    distance_covered_meters DECIMAL(10, 2) DEFAULT 0,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_territory_work_sessions_worker ON territory_work_sessions(worker_id);
CREATE INDEX IF NOT EXISTS idx_territory_work_sessions_territory ON territory_work_sessions(territory_id);
CREATE INDEX IF NOT EXISTS idx_territory_work_sessions_assignment ON territory_work_sessions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_territory_work_sessions_active ON territory_work_sessions(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_territory_work_sessions_entry_time ON territory_work_sessions(entry_time);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_territory_work_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS territory_work_sessions_updated_at ON territory_work_sessions;
CREATE TRIGGER territory_work_sessions_updated_at
    BEFORE UPDATE ON territory_work_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_territory_work_sessions_updated_at();

-- Function to check if a point is inside worker's assigned territories
-- Returns the territory info if worker is inside, NULL otherwise
CREATE OR REPLACE FUNCTION check_worker_in_territory(
    p_worker_id UUID,
    p_lat DECIMAL,
    p_lng DECIMAL
) RETURNS TABLE (
    territory_id UUID,
    assignment_id UUID,
    territory_solid VARCHAR,
    entity_name VARCHAR,
    entity_id VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id as territory_id,
        ta.id as assignment_id,
        t.solid as territory_solid,
        t.entity_name,
        t.entity_id
    FROM territory_assignments ta
    JOIN territories t ON ta.territory_id = t.id
    WHERE ta.assigned_worker_id = p_worker_id
    AND ta.status = 'active'
    AND ST_Contains(t.geom, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326));
END;
$$ LANGUAGE plpgsql;

-- Function to check if a point is inside team's assigned territories (for workers without specific assignment)
CREATE OR REPLACE FUNCTION check_team_territory(
    p_team_id UUID,
    p_lat DECIMAL,
    p_lng DECIMAL
) RETURNS TABLE (
    territory_id UUID,
    assignment_id UUID,
    territory_solid VARCHAR,
    entity_name VARCHAR,
    entity_id VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id as territory_id,
        ta.id as assignment_id,
        t.solid as territory_solid,
        t.entity_name,
        t.entity_id
    FROM territory_assignments ta
    JOIN territories t ON ta.territory_id = t.id
    WHERE ta.team_id = p_team_id
    AND ta.status = 'active'
    AND ST_Contains(t.geom, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326));
END;
$$ LANGUAGE plpgsql;

-- Function to get active work session for a worker
CREATE OR REPLACE FUNCTION get_active_work_session(p_worker_id UUID)
RETURNS TABLE (
    session_id UUID,
    territory_id UUID,
    assignment_id UUID,
    entry_time TIMESTAMPTZ,
    entry_lat DECIMAL,
    entry_lng DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        tws.id as session_id,
        tws.territory_id,
        tws.assignment_id,
        tws.entry_time,
        tws.entry_lat,
        tws.entry_lng
    FROM territory_work_sessions tws
    WHERE tws.worker_id = p_worker_id
    AND tws.is_active = true
    ORDER BY tws.entry_time DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- View for territory work session details
CREATE OR REPLACE VIEW territory_work_sessions_view AS
SELECT
    tws.id as session_id,
    tws.worker_id,
    tws.territory_id,
    tws.assignment_id,
    tws.entry_time,
    tws.exit_time,
    tws.entry_lat,
    tws.entry_lng,
    tws.exit_lat,
    tws.exit_lng,
    tws.time_spent_seconds,
    tws.distance_covered_meters,
    tws.is_active,
    t.solid as territory_solid,
    t.entity_name,
    t.entity_id,
    t.city,
    t.state
FROM territory_work_sessions tws
JOIN territories t ON tws.territory_id = t.id;

-- Comments
COMMENT ON TABLE territory_work_sessions IS 'Tracks when workers enter and exit assigned territories';
COMMENT ON FUNCTION check_worker_in_territory IS 'Checks if a GPS point is inside worker assigned territories';
COMMENT ON FUNCTION check_team_territory IS 'Checks if a GPS point is inside team assigned territories';
