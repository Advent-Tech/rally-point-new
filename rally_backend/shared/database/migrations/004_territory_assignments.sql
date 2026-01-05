-- Territory Assignments Table Migration
-- Links geo territories to teams and workers for assignment tracking

-- Create territory_assignments table
CREATE TABLE IF NOT EXISTS territory_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Reference to geo territory
    territory_id UUID NOT NULL REFERENCES territories(id) ON DELETE CASCADE,
    territory_solid VARCHAR(50), -- Cached for quick lookup

    -- Assignment target
    team_id UUID NOT NULL,
    assigned_worker_id UUID, -- NULL means assigned to team but not specific worker

    -- Assignment metadata
    assigned_by UUID NOT NULL, -- User who made the assignment
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ, -- Optional expiration for temporary assignments

    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    priority VARCHAR(10) DEFAULT 'medium' CHECK (priority IN ('high', 'medium', 'low')),

    -- Notes
    notes TEXT,

    -- Progress tracking
    last_worked_at TIMESTAMPTZ,
    visits_count INTEGER DEFAULT 0,
    completeness_percentage DECIMAL(5,2) DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure unique assignment per territory per team (a territory can only be assigned once per team)
    UNIQUE(territory_id, team_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_territory_assignments_team ON territory_assignments(team_id);
CREATE INDEX IF NOT EXISTS idx_territory_assignments_worker ON territory_assignments(assigned_worker_id);
CREATE INDEX IF NOT EXISTS idx_territory_assignments_territory ON territory_assignments(territory_id);
CREATE INDEX IF NOT EXISTS idx_territory_assignments_status ON territory_assignments(status);
CREATE INDEX IF NOT EXISTS idx_territory_assignments_solid ON territory_assignments(territory_solid);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_territory_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS territory_assignments_updated_at ON territory_assignments;
CREATE TRIGGER territory_assignments_updated_at
    BEFORE UPDATE ON territory_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_territory_assignments_updated_at();

-- View for easy territory assignment lookups with full territory info
CREATE OR REPLACE VIEW territory_assignments_view AS
SELECT
    ta.id as assignment_id,
    ta.territory_id,
    ta.team_id,
    ta.assigned_worker_id,
    ta.assigned_by,
    ta.assigned_at,
    ta.expires_at,
    ta.status,
    ta.priority,
    ta.notes,
    ta.last_worked_at,
    ta.visits_count,
    ta.completeness_percentage,
    t.solid,
    t.entity_name,
    t.entity_id,
    t.city,
    t.state,
    t.union_name,
    t.conference,
    t.population,
    t.housing_units,
    ST_AsGeoJSON(t.geom) as geometry
FROM territory_assignments ta
JOIN territories t ON ta.territory_id = t.id;

-- Function to get assigned territories for a worker as GeoJSON
CREATE OR REPLACE FUNCTION get_worker_assigned_territories_geojson(worker_uuid UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'type', 'FeatureCollection',
        'features', COALESCE(json_agg(
            json_build_object(
                'type', 'Feature',
                'id', t.id::text,
                'geometry', ST_AsGeoJSON(t.geom)::json,
                'properties', json_build_object(
                    'solid', t.solid,
                    'entity_name', t.entity_name,
                    'entity_id', t.entity_id,
                    'city', t.city,
                    'state', t.state,
                    'union_name', t.union_name,
                    'conference', t.conference,
                    'population', t.population,
                    'housing_units', t.housing_units,
                    'assignment_status', ta.status,
                    'assignment_priority', ta.priority,
                    'visits_count', ta.visits_count,
                    'completeness_percentage', ta.completeness_percentage,
                    'assigned_at', ta.assigned_at
                )
            )
        ), '[]'::json)
    ) INTO result
    FROM territory_assignments ta
    JOIN territories t ON ta.territory_id = t.id
    WHERE ta.assigned_worker_id = worker_uuid
    AND ta.status = 'active';

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to get assigned territories for a team as GeoJSON
CREATE OR REPLACE FUNCTION get_team_assigned_territories_geojson(team_uuid UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'type', 'FeatureCollection',
        'features', COALESCE(json_agg(
            json_build_object(
                'type', 'Feature',
                'id', t.id::text,
                'geometry', ST_AsGeoJSON(t.geom)::json,
                'properties', json_build_object(
                    'solid', t.solid,
                    'entity_name', t.entity_name,
                    'entity_id', t.entity_id,
                    'city', t.city,
                    'state', t.state,
                    'union_name', t.union_name,
                    'conference', t.conference,
                    'population', t.population,
                    'housing_units', t.housing_units,
                    'assignment_id', ta.id,
                    'assigned_worker_id', ta.assigned_worker_id,
                    'assignment_status', ta.status,
                    'assignment_priority', ta.priority,
                    'visits_count', ta.visits_count,
                    'completeness_percentage', ta.completeness_percentage,
                    'assigned_at', ta.assigned_at
                )
            )
        ), '[]'::json)
    ) INTO result
    FROM territory_assignments ta
    JOIN territories t ON ta.territory_id = t.id
    WHERE ta.team_id = team_uuid
    AND ta.status IN ('active', 'paused');

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON TABLE territory_assignments IS 'Links geo territories to teams and workers for ministry assignments';
COMMENT ON COLUMN territory_assignments.territory_solid IS 'Cached SOLID identifier from territories table for quick lookup';
COMMENT ON COLUMN territory_assignments.completeness_percentage IS 'Estimated percentage of territory coverage (0-100)';
