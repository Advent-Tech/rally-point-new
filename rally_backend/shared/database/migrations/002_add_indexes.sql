-- Add performance indexes for Rally Point application
-- Migration: 002_add_indexes.sql

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_team_id ON users(team_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_online ON users(is_online);

-- Teams table indexes
-- CREATE INDEX IF NOT EXISTS idx_teams_code ON teams(invitation_code); -- Column doesn't exist
CREATE INDEX IF NOT EXISTS idx_teams_leader_id ON teams(leader_id);
CREATE INDEX IF NOT EXISTS idx_teams_created_at ON teams(created_at);

-- Location tracks table indexes (actual table name is location_tracks)
CREATE INDEX IF NOT EXISTS idx_location_tracks_user_id ON location_tracks(user_id);
CREATE INDEX IF NOT EXISTS idx_location_tracks_tracked_at ON location_tracks(tracked_at);
CREATE INDEX IF NOT EXISTS idx_location_tracks_session_id ON location_tracks(session_id);
CREATE INDEX IF NOT EXISTS idx_location_tracks_user_tracked ON location_tracks(user_id, tracked_at);
CREATE INDEX IF NOT EXISTS idx_location_tracks_location ON location_tracks USING GIST(location);

-- Custom territories table indexes (for manually created team territories)
-- Note: Geo territories indexes are created in 003_territories_table.sql
CREATE INDEX IF NOT EXISTS idx_custom_territories_team_id ON custom_territories(team_id);
CREATE INDEX IF NOT EXISTS idx_custom_territories_assigned_worker_id ON custom_territories(assigned_worker_id);
CREATE INDEX IF NOT EXISTS idx_custom_territories_is_active ON custom_territories(is_active);
CREATE INDEX IF NOT EXISTS idx_custom_territories_created_at ON custom_territories(created_at);
CREATE INDEX IF NOT EXISTS idx_custom_territories_team_active ON custom_territories(team_id, is_active);
CREATE INDEX IF NOT EXISTS idx_custom_territories_assigned_active ON custom_territories(assigned_worker_id, is_active);

-- Territory entries table indexes (actual table name is territory_entries)
CREATE INDEX IF NOT EXISTS idx_territory_entries_territory_id ON territory_entries(territory_id);
CREATE INDEX IF NOT EXISTS idx_territory_entries_user_id ON territory_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_territory_entries_entry_time ON territory_entries(entry_time);
CREATE INDEX IF NOT EXISTS idx_territory_entries_territory_entry ON territory_entries(territory_id, entry_time);

-- Surveys table indexes
CREATE INDEX IF NOT EXISTS idx_surveys_team_id ON surveys(team_id);
CREATE INDEX IF NOT EXISTS idx_surveys_created_by ON surveys(created_by);
CREATE INDEX IF NOT EXISTS idx_surveys_is_active ON surveys(is_active);
CREATE INDEX IF NOT EXISTS idx_surveys_created_at ON surveys(created_at);
CREATE INDEX IF NOT EXISTS idx_surveys_team_active ON surveys(team_id, is_active);

-- Survey responses table indexes
CREATE INDEX IF NOT EXISTS idx_survey_responses_survey_id ON survey_responses(survey_id);
CREATE INDEX IF NOT EXISTS idx_survey_responses_respondent_id ON survey_responses(respondent_id);
CREATE INDEX IF NOT EXISTS idx_survey_responses_submitted_at ON survey_responses(submitted_at);
CREATE INDEX IF NOT EXISTS idx_survey_responses_survey_respondent ON survey_responses(survey_id, respondent_id);

-- Survey assignments table indexes
CREATE INDEX IF NOT EXISTS idx_survey_assignments_survey_id ON survey_assignments(survey_id);
CREATE INDEX IF NOT EXISTS idx_survey_assignments_assigned_to ON survey_assignments(assigned_to);
CREATE INDEX IF NOT EXISTS idx_survey_assignments_assigned_by ON survey_assignments(assigned_by);
CREATE INDEX IF NOT EXISTS idx_survey_assignments_due_date ON survey_assignments(due_date);
CREATE INDEX IF NOT EXISTS idx_survey_assignments_survey_assigned ON survey_assignments(survey_id, assigned_to);

-- Deliveries table indexes
CREATE INDEX IF NOT EXISTS idx_deliveries_team_id ON deliveries(team_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_worker_id ON deliveries(worker_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON deliveries(status);
CREATE INDEX IF NOT EXISTS idx_deliveries_created_at ON deliveries(created_at);
CREATE INDEX IF NOT EXISTS idx_deliveries_delivery_time ON deliveries(delivery_time);
CREATE INDEX IF NOT EXISTS idx_deliveries_team_status ON deliveries(team_id, status);
CREATE INDEX IF NOT EXISTS idx_deliveries_worker_status ON deliveries(worker_id, status);
CREATE INDEX IF NOT EXISTS idx_deliveries_location ON deliveries USING GIST(location);

-- Delivery sessions table indexes
CREATE INDEX IF NOT EXISTS idx_delivery_sessions_worker_id ON delivery_sessions(worker_id);
CREATE INDEX IF NOT EXISTS idx_delivery_sessions_team_id ON delivery_sessions(team_id);
CREATE INDEX IF NOT EXISTS idx_delivery_sessions_start_time ON delivery_sessions(start_time);

-- Walkie sessions table indexes (actual table name is walkie_sessions)
CREATE INDEX IF NOT EXISTS idx_walkie_sessions_team_id ON walkie_sessions(team_id);
CREATE INDEX IF NOT EXISTS idx_walkie_sessions_speaker_id ON walkie_sessions(speaker_id);
CREATE INDEX IF NOT EXISTS idx_walkie_sessions_is_active ON walkie_sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_walkie_sessions_started_at ON walkie_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_walkie_sessions_team_active ON walkie_sessions(team_id, is_active);
CREATE INDEX IF NOT EXISTS idx_walkie_sessions_team_started ON walkie_sessions(team_id, started_at);

-- Walkie messages table indexes (actual table name is walkie_messages)
CREATE INDEX IF NOT EXISTS idx_walkie_messages_team_id ON walkie_messages(team_id);
CREATE INDEX IF NOT EXISTS idx_walkie_messages_sender_id ON walkie_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_walkie_messages_sent_at ON walkie_messages(sent_at);
CREATE INDEX IF NOT EXISTS idx_walkie_messages_team_sent ON walkie_messages(team_id, sent_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_users_team_role ON users(team_id, role);
CREATE INDEX IF NOT EXISTS idx_location_tracks_user_tracked ON location_tracks(user_id, tracked_at);
CREATE INDEX IF NOT EXISTS idx_custom_territories_team_assigned_active ON custom_territories(team_id, assigned_worker_id, is_active);
CREATE INDEX IF NOT EXISTS idx_deliveries_team_worker_status ON deliveries(team_id, worker_id, status);
CREATE INDEX IF NOT EXISTS idx_surveys_team_created_active ON surveys(team_id, created_by, is_active);

-- Full-text search indexes (if using PostgreSQL with full-text search)
CREATE INDEX IF NOT EXISTS idx_custom_territories_name_fts ON custom_territories USING gin(to_tsvector('english', name));
CREATE INDEX IF NOT EXISTS idx_custom_territories_description_fts ON custom_territories USING gin(to_tsvector('english', description));
CREATE INDEX IF NOT EXISTS idx_surveys_title_fts ON surveys USING gin(to_tsvector('english', title));
CREATE INDEX IF NOT EXISTS idx_surveys_description_fts ON surveys USING gin(to_tsvector('english', description));

-- Partial indexes for active records
CREATE INDEX IF NOT EXISTS idx_users_online_email ON users(email) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_custom_territories_active_assigned ON custom_territories(assigned_worker_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_deliveries_pending ON deliveries(team_id, created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_walkie_active_sessions ON walkie_sessions(team_id, started_at) WHERE is_active = true;
