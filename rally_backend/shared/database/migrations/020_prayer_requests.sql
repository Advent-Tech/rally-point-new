-- Prayer Requests Table
-- Workers collect prayer requests from people during door-to-door visits

CREATE TABLE IF NOT EXISTS prayer_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Worker and team info
    worker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
    territory_id UUID REFERENCES territories(id) ON DELETE SET NULL,

    -- Requester information
    requester_name VARCHAR(255) NOT NULL,
    requester_phone VARCHAR(50),
    requester_email VARCHAR(255),
    requester_address TEXT,

    -- Location for map markers
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- Prayer request details
    prayer_subject VARCHAR(255) NOT NULL,
    prayer_details TEXT NOT NULL,
    prayer_category VARCHAR(50) DEFAULT 'general',
    -- Categories: general, healing, family, financial, spiritual, thanksgiving, other

    -- Request type
    request_type VARCHAR(50) NOT NULL DEFAULT 'church_prayer',
    -- Types: church_prayer (pray at church), home_visit (preacher visits home)

    -- For home visits
    preacher_id UUID REFERENCES users(id) ON DELETE SET NULL,
    preferred_visit_date DATE,
    preferred_visit_time VARCHAR(50),

    -- Status tracking
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    -- Status: pending, scheduled, in_progress, completed, cancelled

    urgency VARCHAR(20) DEFAULT 'normal',
    -- Urgency: low, normal, high, urgent

    -- Completion info
    scheduled_at TIMESTAMP,
    completed_at TIMESTAMP,
    completed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    completion_notes TEXT,

    -- Metadata
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_prayer_requests_worker_id ON prayer_requests(worker_id);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_team_id ON prayer_requests(team_id);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_territory_id ON prayer_requests(territory_id);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_status ON prayer_requests(status);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_request_type ON prayer_requests(request_type);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_created_at ON prayer_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_location ON prayer_requests(latitude, longitude);

-- Spatial index for location-based queries
CREATE INDEX IF NOT EXISTS idx_prayer_requests_geom ON prayer_requests USING gist (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_prayer_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_prayer_requests_updated_at ON prayer_requests;
CREATE TRIGGER trigger_prayer_requests_updated_at
    BEFORE UPDATE ON prayer_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_prayer_requests_updated_at();
