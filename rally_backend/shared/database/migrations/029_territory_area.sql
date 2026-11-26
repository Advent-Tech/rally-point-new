-- Precomputed area (deg^2) so low-zoom vector tiles can drop sub-pixel territories cheaply
ALTER TABLE territories ADD COLUMN IF NOT EXISTS area_deg2 double precision;
UPDATE territories SET area_deg2 = ST_Area(geom) WHERE area_deg2 IS NULL;
CREATE INDEX IF NOT EXISTS idx_territories_area ON territories (area_deg2);
ANALYZE territories;
