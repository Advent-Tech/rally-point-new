-- Rally Point Database Schema
-- Initial migration for all microservices

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable PostGIS for location data
CREATE EXTENSION IF NOT EXISTS postgis;

-- =====================================================
-- USER SERVICE TABLES
-- =====================================================

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'worker',
    phone VARCHAR(20),
    profile_photo_url TEXT,
    team_id UUID,
    is_online BOOLEAN DEFAULT FALSE,
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Teams table
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    leader_id UUID NOT NULL,
    photo_url TEXT,
    worker_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (leader_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Add foreign key for team_id in users table
ALTER TABLE users ADD CONSTRAINT fk_users_team_id 
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;

-- User sessions for JWT management
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    refresh_token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================
-- LOCATION SERVICE TABLES
-- =====================================================

-- Location tracking table
CREATE TABLE location_tracks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    location GEOMETRY(POINT, 4326) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy DECIMAL(8, 2),
    speed DECIMAL(8, 2),
    heading DECIMAL(5, 2),
    session_id UUID,
    tracked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Location sessions for tracking periods
CREATE TABLE location_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    total_distance DECIMAL(10, 2) DEFAULT 0,
    location_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================
-- TERRITORY SERVICE TABLES
-- =====================================================

-- Custom territories table (for manually created team territories)
-- Note: GeoPackage imported territories use the 'territories' table created in 003_territories_table.sql
CREATE TABLE custom_territories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    team_id UUID NOT NULL,
    assigned_worker_id UUID,
    boundary GEOMETRY(POLYGON, 4326) NOT NULL,
    color VARCHAR(7) DEFAULT '#007AFF',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_worker_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Territory entries/exits tracking (references custom_territories)
CREATE TABLE territory_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    territory_id UUID NOT NULL,
    entry_time TIMESTAMP WITH TIME ZONE NOT NULL,
    exit_time TIMESTAMP WITH TIME ZONE,
    entry_location GEOMETRY(POINT, 4326) NOT NULL,
    exit_location GEOMETRY(POINT, 4326),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (territory_id) REFERENCES custom_territories(id) ON DELETE CASCADE
);

-- Territory alerts (references custom_territories)
CREATE TABLE territory_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    territory_id UUID NOT NULL,
    alert_type VARCHAR(50) NOT NULL, -- 'entry', 'exit', 'boundary_violation'
    message TEXT NOT NULL,
    location GEOMETRY(POINT, 4326) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (territory_id) REFERENCES custom_territories(id) ON DELETE CASCADE
);

-- =====================================================
-- SURVEY SERVICE TABLES
-- =====================================================

-- Surveys table
CREATE TABLE surveys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    team_id UUID NOT NULL,
    created_by UUID NOT NULL,
    questions JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

-- Survey assignments
CREATE TABLE survey_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID NOT NULL,
    assigned_to UUID NOT NULL,
    assigned_by UUID NOT NULL,
    due_date TIMESTAMP WITH TIME ZONE,
    is_completed BOOLEAN DEFAULT FALSE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_by) REFERENCES users(id) ON DELETE CASCADE
);

-- Survey responses
CREATE TABLE survey_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID NOT NULL,
    assignment_id UUID,
    respondent_id UUID NOT NULL,
    answers JSONB NOT NULL,
    location GEOMETRY(POINT, 4326),
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE,
    FOREIGN KEY (assignment_id) REFERENCES survey_assignments(id) ON DELETE SET NULL,
    FOREIGN KEY (respondent_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================
-- DELIVERY SERVICE TABLES
-- =====================================================

-- Deliveries table
CREATE TABLE deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_id UUID NOT NULL,
    team_id UUID NOT NULL,
    book_title VARCHAR(255) NOT NULL,
    delivery_type VARCHAR(50) NOT NULL, -- 'door', 'person'
    recipient_name VARCHAR(255),
    recipient_phone VARCHAR(20),
    address TEXT,
    location GEOMETRY(POINT, 4326),
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    notes TEXT,
    donation_amount DECIMAL(10, 2) DEFAULT 0,
    delivery_time TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (worker_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
);

-- Delivery sessions
CREATE TABLE delivery_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_id UUID NOT NULL,
    team_id UUID NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    total_deliveries INTEGER DEFAULT 0,
    total_distance DECIMAL(10, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (worker_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
);

-- =====================================================
-- WALKIE TALKIE SERVICE TABLES
-- =====================================================

-- Walkie talkie sessions
CREATE TABLE walkie_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL,
    speaker_id UUID NOT NULL,
    speaker_name VARCHAR(255) NOT NULL,
    audio_url TEXT,
    duration INTEGER, -- in seconds
    is_active BOOLEAN DEFAULT TRUE,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
    FOREIGN KEY (speaker_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Walkie talkie messages (for text fallback)
CREATE TABLE walkie_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    sender_name VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'text', -- 'text', 'audio', 'system'
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================
-- MINISTRY CONTACT TABLES (Additional)
-- =====================================================

-- Ministry contacts
CREATE TABLE ministry_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    location GEOMETRY(POINT, 4326),
    interests JSONB, -- Store interest categories
    contact_method VARCHAR(50), -- 'phone', 'email', 'visit', 'letter'
    contact_sent BOOLEAN DEFAULT FALSE,
    contact_sent_at TIMESTAMP WITH TIME ZONE,
    appointment_scheduled BOOLEAN DEFAULT FALSE,
    appointment_date TIMESTAMP WITH TIME ZONE,
    appointment_time VARCHAR(10),
    appointment_notes TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (worker_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- User indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_team_id ON users(team_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_is_online ON users(is_online);

-- Team indexes
CREATE INDEX idx_teams_leader_id ON teams(leader_id);

-- Location indexes
CREATE INDEX idx_location_tracks_user_id ON location_tracks(user_id);
CREATE INDEX idx_location_tracks_tracked_at ON location_tracks(tracked_at);
CREATE INDEX idx_location_tracks_session_id ON location_tracks(session_id);
CREATE INDEX idx_location_tracks_location ON location_tracks USING GIST(location);

-- Custom territory indexes
CREATE INDEX idx_custom_territories_team_id ON custom_territories(team_id);
CREATE INDEX idx_custom_territories_assigned_worker_id ON custom_territories(assigned_worker_id);
CREATE INDEX idx_custom_territories_boundary ON custom_territories USING GIST(boundary);
CREATE INDEX idx_territory_entries_user_id ON territory_entries(user_id);
CREATE INDEX idx_territory_entries_territory_id ON territory_entries(territory_id);
CREATE INDEX idx_territory_entries_entry_time ON territory_entries(entry_time);

-- Survey indexes
CREATE INDEX idx_surveys_team_id ON surveys(team_id);
CREATE INDEX idx_surveys_created_by ON surveys(created_by);
CREATE INDEX idx_survey_assignments_survey_id ON survey_assignments(survey_id);
CREATE INDEX idx_survey_assignments_assigned_to ON survey_assignments(assigned_to);
CREATE INDEX idx_survey_responses_survey_id ON survey_responses(survey_id);
CREATE INDEX idx_survey_responses_respondent_id ON survey_responses(respondent_id);

-- Delivery indexes
CREATE INDEX idx_deliveries_worker_id ON deliveries(worker_id);
CREATE INDEX idx_deliveries_team_id ON deliveries(team_id);
CREATE INDEX idx_deliveries_status ON deliveries(status);
CREATE INDEX idx_deliveries_delivery_time ON deliveries(delivery_time);
CREATE INDEX idx_deliveries_location ON deliveries USING GIST(location);

-- Walkie talkie indexes
CREATE INDEX idx_walkie_sessions_team_id ON walkie_sessions(team_id);
CREATE INDEX idx_walkie_sessions_speaker_id ON walkie_sessions(speaker_id);
CREATE INDEX idx_walkie_sessions_started_at ON walkie_sessions(started_at);
CREATE INDEX idx_walkie_messages_team_id ON walkie_messages(team_id);
CREATE INDEX idx_walkie_messages_sent_at ON walkie_messages(sent_at);

-- Ministry contact indexes
CREATE INDEX idx_ministry_contacts_worker_id ON ministry_contacts(worker_id);
CREATE INDEX idx_ministry_contacts_location ON ministry_contacts USING GIST(location);

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_location_sessions_updated_at BEFORE UPDATE ON location_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_custom_territories_updated_at BEFORE UPDATE ON custom_territories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_territory_entries_updated_at BEFORE UPDATE ON territory_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_surveys_updated_at BEFORE UPDATE ON surveys FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_deliveries_updated_at BEFORE UPDATE ON deliveries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_delivery_sessions_updated_at BEFORE UPDATE ON delivery_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ministry_contacts_updated_at BEFORE UPDATE ON ministry_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate distance between two points
CREATE OR REPLACE FUNCTION calculate_distance(lat1 DECIMAL, lon1 DECIMAL, lat2 DECIMAL, lon2 DECIMAL)
RETURNS DECIMAL AS $$
BEGIN
    RETURN ST_Distance(
        ST_GeogFromText('POINT(' || lon1 || ' ' || lat1 || ')'),
        ST_GeogFromText('POINT(' || lon2 || ' ' || lat2 || ')')
    );
END;
$$ LANGUAGE plpgsql;

-- Function to check if point is inside territory
CREATE OR REPLACE FUNCTION point_in_territory(lat DECIMAL, lon DECIMAL, territory_boundary GEOMETRY)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN ST_Within(
        ST_GeomFromText('POINT(' || lon || ' ' || lat || ')', 4326),
        territory_boundary
    );
END;
$$ LANGUAGE plpgsql;
