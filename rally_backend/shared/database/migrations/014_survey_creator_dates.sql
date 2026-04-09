-- Migration: 014_survey_creator_dates.sql
-- Description: Add creator_id alias and date range columns to surveys table

-- Add creator_id column (alias for created_by for consistency with new code)
-- Using a generated column approach or just adding the column
ALTER TABLE surveys ADD COLUMN IF NOT EXISTS creator_id UUID;

-- Copy existing created_by values to creator_id
UPDATE surveys SET creator_id = created_by WHERE creator_id IS NULL;

-- Add start_date and end_date columns for survey scheduling
ALTER TABLE surveys ADD COLUMN IF NOT EXISTS start_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE surveys ADD COLUMN IF NOT EXISTS end_date TIMESTAMP WITH TIME ZONE;

-- Create index for date range queries
CREATE INDEX IF NOT EXISTS idx_surveys_date_range ON surveys(start_date, end_date);

-- Create index for creator lookups
CREATE INDEX IF NOT EXISTS idx_surveys_creator ON surveys(creator_id);
