-- Migration: 021_survey_multi_team.sql
-- Description: Add survey_teams junction table for many-to-many relationship between surveys and teams

-- 1. Create survey_teams junction table
CREATE TABLE IF NOT EXISTS survey_teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID NOT NULL,
    team_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE,
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
    UNIQUE(survey_id, team_id)
);

-- 2. Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_survey_teams_survey_id ON survey_teams(survey_id);
CREATE INDEX IF NOT EXISTS idx_survey_teams_team_id ON survey_teams(team_id);

-- 3. Migrate existing team_id data to survey_teams table
INSERT INTO survey_teams (survey_id, team_id)
SELECT id, team_id FROM surveys WHERE team_id IS NOT NULL
ON CONFLICT (survey_id, team_id) DO NOTHING;

-- Note: The team_id column in surveys table is kept for backward compatibility
-- but new surveys should use the survey_teams junction table for team assignments
