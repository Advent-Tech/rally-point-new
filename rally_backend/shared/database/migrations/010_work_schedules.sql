-- Work Schedules Migration
-- Allows team leaders to schedule work shifts for workers

-- Table to store work schedules
CREATE TABLE IF NOT EXISTS work_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Team and worker info
    team_id UUID NOT NULL,
    worker_id UUID NOT NULL,
    worker_name VARCHAR(255),

    -- Territory assignment (optional)
    territory_id UUID REFERENCES territories(id) ON DELETE SET NULL,
    territory_name VARCHAR(255),

    -- Schedule timing
    scheduled_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,

    -- Status tracking
    status VARCHAR(20) DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled', 'missed')),

    -- Actual times (filled when worker checks in/out)
    actual_start_time TIMESTAMPTZ,
    actual_end_time TIMESTAMPTZ,

    -- Notes
    notes TEXT,

    -- Audit fields
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_work_schedules_team_date ON work_schedules(team_id, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_work_schedules_worker_date ON work_schedules(worker_id, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_work_schedules_status ON work_schedules(status);
CREATE INDEX IF NOT EXISTS idx_work_schedules_date ON work_schedules(scheduled_date);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_work_schedules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS work_schedules_updated_at ON work_schedules;
CREATE TRIGGER work_schedules_updated_at
    BEFORE UPDATE ON work_schedules
    FOR EACH ROW
    EXECUTE FUNCTION update_work_schedules_updated_at();

-- Function to get worker's schedule for a date
CREATE OR REPLACE FUNCTION get_worker_schedule(
    p_worker_id UUID,
    p_date DATE
) RETURNS TABLE (
    schedule_id UUID,
    team_id UUID,
    territory_id UUID,
    territory_name VARCHAR,
    scheduled_date DATE,
    start_time TIME,
    end_time TIME,
    status VARCHAR,
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ws.id as schedule_id,
        ws.team_id,
        ws.territory_id,
        ws.territory_name,
        ws.scheduled_date,
        ws.start_time,
        ws.end_time,
        ws.status,
        ws.notes
    FROM work_schedules ws
    WHERE ws.worker_id = p_worker_id
    AND ws.scheduled_date = p_date
    AND ws.status NOT IN ('cancelled')
    ORDER BY ws.start_time;
END;
$$ LANGUAGE plpgsql;

-- Function to get team's schedules for a date
CREATE OR REPLACE FUNCTION get_team_schedules(
    p_team_id UUID,
    p_date DATE
) RETURNS TABLE (
    schedule_id UUID,
    worker_id UUID,
    worker_name VARCHAR,
    territory_id UUID,
    territory_name VARCHAR,
    scheduled_date DATE,
    start_time TIME,
    end_time TIME,
    status VARCHAR,
    actual_start_time TIMESTAMPTZ,
    actual_end_time TIMESTAMPTZ,
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ws.id as schedule_id,
        ws.worker_id,
        ws.worker_name,
        ws.territory_id,
        ws.territory_name,
        ws.scheduled_date,
        ws.start_time,
        ws.end_time,
        ws.status,
        ws.actual_start_time,
        ws.actual_end_time,
        ws.notes
    FROM work_schedules ws
    WHERE ws.team_id = p_team_id
    AND ws.scheduled_date = p_date
    ORDER BY ws.start_time, ws.worker_name;
END;
$$ LANGUAGE plpgsql;

-- Function to mark missed schedules (can be called periodically)
CREATE OR REPLACE FUNCTION mark_missed_schedules()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE work_schedules
    SET status = 'missed', updated_at = NOW()
    WHERE status = 'scheduled'
    AND scheduled_date < CURRENT_DATE
    AND actual_start_time IS NULL;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- View for schedule details with computed fields
CREATE OR REPLACE VIEW work_schedules_view AS
SELECT
    ws.id as schedule_id,
    ws.team_id,
    ws.worker_id,
    ws.worker_name,
    ws.territory_id,
    ws.territory_name,
    ws.scheduled_date,
    ws.start_time,
    ws.end_time,
    ws.status,
    ws.actual_start_time,
    ws.actual_end_time,
    ws.notes,
    ws.created_by,
    ws.created_at,
    ws.updated_at,
    -- Computed: scheduled duration in minutes
    EXTRACT(EPOCH FROM (ws.end_time - ws.start_time)) / 60 as scheduled_duration_minutes,
    -- Computed: actual duration in minutes (if completed)
    CASE
        WHEN ws.actual_start_time IS NOT NULL AND ws.actual_end_time IS NOT NULL
        THEN EXTRACT(EPOCH FROM (ws.actual_end_time - ws.actual_start_time)) / 60
        ELSE NULL
    END as actual_duration_minutes
FROM work_schedules ws;

-- Comments
COMMENT ON TABLE work_schedules IS 'Stores work schedules created by team leaders for workers';
COMMENT ON FUNCTION get_worker_schedule IS 'Gets a worker schedule for a specific date';
COMMENT ON FUNCTION get_team_schedules IS 'Gets all team schedules for a specific date';
COMMENT ON FUNCTION mark_missed_schedules IS 'Marks past schedules without actual start time as missed';
