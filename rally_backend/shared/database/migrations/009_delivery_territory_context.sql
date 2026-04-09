-- Delivery Territory Context Migration
-- Adds territory_id, territory_name, and household_id to deliveries table
-- This connects deliveries to geographic territories for analytics and tracking

-- Add territory context columns to deliveries table
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS territory_id UUID;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS territory_name VARCHAR(255);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS household_id UUID;

-- Add index for territory_id lookups
CREATE INDEX IF NOT EXISTS idx_deliveries_territory_id ON deliveries(territory_id);

-- Add index for household tracking
CREATE INDEX IF NOT EXISTS idx_deliveries_household_id ON deliveries(household_id);

-- Comments for documentation
COMMENT ON COLUMN deliveries.territory_id IS 'UUID of the territory this delivery is in (from geo_territories)';
COMMENT ON COLUMN deliveries.territory_name IS 'Name of the territory for display purposes';
COMMENT ON COLUMN deliveries.household_id IS 'UUID of the household record if linked to household tracking';

-- Update survey_responses to include territory context as well
ALTER TABLE survey_responses ADD COLUMN IF NOT EXISTS territory_id UUID;
ALTER TABLE survey_responses ADD COLUMN IF NOT EXISTS territory_name VARCHAR(255);
CREATE INDEX IF NOT EXISTS idx_survey_responses_territory_id ON survey_responses(territory_id);

COMMENT ON COLUMN survey_responses.territory_id IS 'UUID of the territory where survey was conducted';
COMMENT ON COLUMN survey_responses.territory_name IS 'Name of the territory for display purposes';

-- Create households table for persistent household tracking
CREATE TABLE IF NOT EXISTS households (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    territory_id UUID,
    address TEXT NOT NULL,
    city VARCHAR(100),
    state VARCHAR(10),
    zipcode VARCHAR(10),
    location GEOMETRY(POINT, 4326),
    status VARCHAR(50) DEFAULT 'not_visited', -- 'not_visited', 'visited', 'interested', 'not_interested', 'callback'
    visit_count INTEGER DEFAULT 0,
    last_visited_at TIMESTAMPTZ,
    last_visited_by UUID,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for households
CREATE INDEX IF NOT EXISTS idx_households_territory_id ON households(territory_id);
CREATE INDEX IF NOT EXISTS idx_households_location ON households USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_households_status ON households(status);
CREATE INDEX IF NOT EXISTS idx_households_address ON households(address);

-- Trigger for updated_at on households
CREATE OR REPLACE FUNCTION update_households_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS households_updated_at ON households;
CREATE TRIGGER households_updated_at
    BEFORE UPDATE ON households
    FOR EACH ROW
    EXECUTE FUNCTION update_households_updated_at();

-- Comments
COMMENT ON TABLE households IS 'Persistent household records for territory coverage tracking';
COMMENT ON COLUMN households.status IS 'Current status: not_visited, visited, interested, not_interested, callback';
COMMENT ON COLUMN households.visit_count IS 'Number of times this household has been visited';

-- Create household_visits table for visit history
CREATE TABLE IF NOT EXISTS household_visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    worker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    territory_id UUID,
    visit_type VARCHAR(50) NOT NULL, -- 'delivery', 'survey', 'canvassing', 'follow_up'
    outcome VARCHAR(50), -- 'not_home', 'interested', 'not_interested', 'callback', 'completed'
    notes TEXT,
    location GEOMETRY(POINT, 4326),
    visited_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for household_visits
CREATE INDEX IF NOT EXISTS idx_household_visits_household_id ON household_visits(household_id);
CREATE INDEX IF NOT EXISTS idx_household_visits_worker_id ON household_visits(worker_id);
CREATE INDEX IF NOT EXISTS idx_household_visits_territory_id ON household_visits(territory_id);
CREATE INDEX IF NOT EXISTS idx_household_visits_visited_at ON household_visits(visited_at);
CREATE INDEX IF NOT EXISTS idx_household_visits_visit_type ON household_visits(visit_type);

-- Comments
COMMENT ON TABLE household_visits IS 'History of all visits to households';
COMMENT ON COLUMN household_visits.visit_type IS 'Type of visit: delivery, survey, canvassing, follow_up';
COMMENT ON COLUMN household_visits.outcome IS 'Result of visit: not_home, interested, not_interested, callback, completed';
