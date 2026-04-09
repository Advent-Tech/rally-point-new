-- Migration: Make team_id optional in surveys table
-- This allows admins to create surveys without associating them with a specific team

-- Step 1: Drop the foreign key constraint
ALTER TABLE surveys DROP CONSTRAINT IF EXISTS surveys_team_id_fkey;

-- Step 2: Make team_id nullable
ALTER TABLE surveys ALTER COLUMN team_id DROP NOT NULL;

-- Step 3: Re-add the foreign key constraint (but allow NULL)
ALTER TABLE surveys ADD CONSTRAINT surveys_team_id_fkey
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;

-- Note: Existing surveys will keep their team_id values
-- New surveys can now be created without a team_id
