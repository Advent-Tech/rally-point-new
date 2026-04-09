-- Migration: 013_survey_enhancements.sql
-- Description: Add new fields for dynamic survey form builder

-- Add requires_location to surveys table
ALTER TABLE surveys ADD COLUMN IF NOT EXISTS requires_location BOOLEAN DEFAULT false;

-- Add placeholder and validation to survey_questions table
ALTER TABLE survey_questions ADD COLUMN IF NOT EXISTS placeholder TEXT;
ALTER TABLE survey_questions ADD COLUMN IF NOT EXISTS validation JSONB;

-- Add photo_urls and signature_url to survey_answers table
ALTER TABLE survey_answers ADD COLUMN IF NOT EXISTS photo_urls JSONB;
ALTER TABLE survey_answers ADD COLUMN IF NOT EXISTS signature_url TEXT;

-- Create index for faster survey lookups by team and active status
CREATE INDEX IF NOT EXISTS idx_surveys_team_active ON surveys(team_id, is_active);

-- Create index for questions order
CREATE INDEX IF NOT EXISTS idx_survey_questions_order ON survey_questions(survey_id, order_index);
