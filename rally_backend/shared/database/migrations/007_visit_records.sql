-- Visit Records Migration
-- Tracks individual visits/addresses logged by workers during work sessions

-- Table to track individual visits during work sessions
CREATE TABLE IF NOT EXISTS visit_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Session reference
    session_id UUID NOT NULL REFERENCES territory_work_sessions(id) ON DELETE CASCADE,
    worker_id UUID NOT NULL,
    territory_id UUID NOT NULL REFERENCES territories(id) ON DELETE CASCADE,

    -- Visit details
    address VARCHAR(500) NOT NULL,
    outcome VARCHAR(50) NOT NULL CHECK (outcome IN ('contacted', 'not_home', 'interested', 'do_not_call', 'completed', 'other')),
    notes TEXT,

    -- Location (optional GPS coordinates of the visit)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- Timing
    visited_at TIMESTAMPTZ DEFAULT NOW(),

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_visit_records_session ON visit_records(session_id);
CREATE INDEX IF NOT EXISTS idx_visit_records_worker ON visit_records(worker_id);
CREATE INDEX IF NOT EXISTS idx_visit_records_territory ON visit_records(territory_id);
CREATE INDEX IF NOT EXISTS idx_visit_records_visited_at ON visit_records(visited_at);
CREATE INDEX IF NOT EXISTS idx_visit_records_outcome ON visit_records(outcome);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_visit_records_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS visit_records_updated_at ON visit_records;
CREATE TRIGGER visit_records_updated_at
    BEFORE UPDATE ON visit_records
    FOR EACH ROW
    EXECUTE FUNCTION update_visit_records_updated_at();

-- Function to get visits for a session
CREATE OR REPLACE FUNCTION get_session_visits(p_session_id UUID)
RETURNS TABLE (
    visit_id UUID,
    address VARCHAR,
    outcome VARCHAR,
    notes TEXT,
    latitude DECIMAL,
    longitude DECIMAL,
    visited_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        vr.id as visit_id,
        vr.address,
        vr.outcome,
        vr.notes,
        vr.latitude,
        vr.longitude,
        vr.visited_at
    FROM visit_records vr
    WHERE vr.session_id = p_session_id
    ORDER BY vr.visited_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to count visits by outcome for a session
CREATE OR REPLACE FUNCTION get_session_visit_stats(p_session_id UUID)
RETURNS TABLE (
    total_visits BIGINT,
    contacted BIGINT,
    not_home BIGINT,
    interested BIGINT,
    do_not_call BIGINT,
    completed BIGINT,
    other BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) as total_visits,
        COUNT(*) FILTER (WHERE outcome = 'contacted') as contacted,
        COUNT(*) FILTER (WHERE outcome = 'not_home') as not_home,
        COUNT(*) FILTER (WHERE outcome = 'interested') as interested,
        COUNT(*) FILTER (WHERE outcome = 'do_not_call') as do_not_call,
        COUNT(*) FILTER (WHERE outcome = 'completed') as completed,
        COUNT(*) FILTER (WHERE outcome = 'other') as other
    FROM visit_records
    WHERE session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- View for visit records with session details
CREATE OR REPLACE VIEW visit_records_view AS
SELECT
    vr.id as visit_id,
    vr.session_id,
    vr.worker_id,
    vr.territory_id,
    vr.address,
    vr.outcome,
    vr.notes,
    vr.latitude,
    vr.longitude,
    vr.visited_at,
    t.entity_name as territory_name,
    t.entity_id as territory_entity_id
FROM visit_records vr
JOIN territories t ON vr.territory_id = t.id;

-- Add territory_name column to territory_work_sessions for convenience
ALTER TABLE territory_work_sessions ADD COLUMN IF NOT EXISTS territory_name VARCHAR(255);

-- Comments
COMMENT ON TABLE visit_records IS 'Tracks individual visits/addresses logged by workers during work sessions';
COMMENT ON FUNCTION get_session_visits IS 'Gets all visits for a given work session';
COMMENT ON FUNCTION get_session_visit_stats IS 'Gets aggregated visit statistics for a work session';
