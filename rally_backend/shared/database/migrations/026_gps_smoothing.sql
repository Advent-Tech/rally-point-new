-- Migration: Add smoothed GPS coordinates to location_tracks table
-- This adds Kalman-filtered coordinates for cleaner path visualization

ALTER TABLE location_tracks 
ADD COLUMN IF NOT EXISTS smoothed_latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS smoothed_longitude DOUBLE PRECISION;

-- Create index for faster queries on smoothed coordinates (if needed)
-- CREATE INDEX IF NOT EXISTS idx_location_tracks_smoothed ON location_tracks(user_id, smoothed_latitude, smoothed_longitude);

COMMENT ON COLUMN location_tracks.smoothed_latitude IS 'Kalman-filtered/smoothed latitude for cleaner path display';
COMMENT ON COLUMN location_tracks.smoothed_longitude IS 'Kalman-filtered/smoothed longitude for cleaner path display';
