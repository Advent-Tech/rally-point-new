-- Custom Territories Table Migration
-- Separate table for team-created custom territories (distinct from imported GeoPackage territories)

-- Create custom_territories table for manually created territories
CREATE TABLE IF NOT EXISTS custom_territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    team_id UUID NOT NULL,
    assigned_worker_id UUID,
    boundary GEOMETRY(POLYGON, 4326),
    color VARCHAR(20) DEFAULT '#3B82F6',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_custom_territories_team ON custom_territories(team_id);
CREATE INDEX IF NOT EXISTS idx_custom_territories_worker ON custom_territories(assigned_worker_id);
CREATE INDEX IF NOT EXISTS idx_custom_territories_boundary ON custom_territories USING GIST(boundary);
CREATE INDEX IF NOT EXISTS idx_custom_territories_active ON custom_territories(is_active);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_custom_territories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS custom_territories_updated_at ON custom_territories;
CREATE TRIGGER custom_territories_updated_at
    BEFORE UPDATE ON custom_territories
    FOR EACH ROW
    EXECUTE FUNCTION update_custom_territories_updated_at();

-- Territory entries table (for tracking worker entry/exit from territories)
CREATE TABLE IF NOT EXISTS territory_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    territory_id UUID NOT NULL,
    entry_time TIMESTAMPTZ NOT NULL,
    exit_time TIMESTAMPTZ,
    entry_location GEOMETRY(POINT, 4326),
    exit_location GEOMETRY(POINT, 4326),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_territory_entries_user ON territory_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_territory_entries_territory ON territory_entries(territory_id);
CREATE INDEX IF NOT EXISTS idx_territory_entries_active ON territory_entries(is_active);

-- Territory alerts table
CREATE TABLE IF NOT EXISTS territory_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    territory_id UUID NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    message TEXT,
    location GEOMETRY(POINT, 4326),
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_territory_alerts_user ON territory_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_territory_alerts_territory ON territory_alerts(territory_id);
CREATE INDEX IF NOT EXISTS idx_territory_alerts_read ON territory_alerts(is_read);

-- Comments
COMMENT ON TABLE custom_territories IS 'Team-created custom territories (separate from imported GeoPackage territories)';
COMMENT ON TABLE territory_entries IS 'Tracks worker entry and exit from territories';
COMMENT ON TABLE territory_alerts IS 'Territory-related alerts for workers';
