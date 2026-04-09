-- Territories Table Migration
-- Stores geographic territory boundaries from GeoPackage files

-- Enable PostGIS extension if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create territories table
CREATE TABLE IF NOT EXISTS territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fid INTEGER UNIQUE NOT NULL,
    solid VARCHAR(50),

    -- Church/Entity info
    entity_name VARCHAR(255),
    entity_id VARCHAR(50),
    group_id VARCHAR(10),

    -- Location
    address TEXT,
    street_address VARCHAR(255),
    city VARCHAR(100),
    county VARCHAR(100),
    state VARCHAR(10),
    zipcode VARCHAR(10),

    -- Demographics
    population INTEGER,
    housing_units INTEGER,

    -- Organizational hierarchy
    union_name VARCHAR(100),
    conference VARCHAR(100),

    -- Census reference
    geoid VARCHAR(20),
    zid VARCHAR(50),

    -- Order/Priority
    territory_order REAL,

    -- Label for display
    label VARCHAR(255),

    -- Geometry (4326 = WGS84 lat/lng)
    geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,

    -- Simplified geometry for lower zoom levels
    geom_simplified GEOMETRY(MULTIPOLYGON, 4326),

    -- Metadata
    source_file VARCHAR(255),
    imported_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Spatial index for fast geo queries (most important)
CREATE INDEX IF NOT EXISTS idx_territories_geom ON territories USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_territories_geom_simplified ON territories USING GIST(geom_simplified);

-- B-tree indexes for common queries
CREATE INDEX IF NOT EXISTS idx_territories_entity_id ON territories(entity_id);
CREATE INDEX IF NOT EXISTS idx_territories_entity_name ON territories(entity_name);
CREATE INDEX IF NOT EXISTS idx_territories_union ON territories(union_name);
CREATE INDEX IF NOT EXISTS idx_territories_conference ON territories(conference);
CREATE INDEX IF NOT EXISTS idx_territories_state ON territories(state);
CREATE INDEX IF NOT EXISTS idx_territories_city ON territories(city);
CREATE INDEX IF NOT EXISTS idx_territories_zipcode ON territories(zipcode);
CREATE INDEX IF NOT EXISTS idx_territories_solid ON territories(solid);

-- Create trigram extension for fuzzy search (must be before trgm index)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Full-text search index for entity name
CREATE INDEX IF NOT EXISTS idx_territories_entity_name_trgm ON territories
    USING GIN (entity_name gin_trgm_ops);

-- Create church_locations materialized view for clustering/point display
CREATE MATERIALIZED VIEW IF NOT EXISTS church_locations AS
SELECT
    entity_id,
    entity_name,
    union_name,
    conference,
    MIN(address) as address,
    MIN(city) as city,
    MIN(state) as state,
    ST_Centroid(ST_Collect(geom)) as location,
    COUNT(*) as territory_count,
    SUM(COALESCE(population, 0)) as total_population,
    SUM(COALESCE(housing_units, 0)) as total_housing
FROM territories
GROUP BY entity_id, entity_name, union_name, conference;

-- Index on church_locations
CREATE INDEX IF NOT EXISTS idx_church_locations_location ON church_locations USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_church_locations_entity_id ON church_locations(entity_id);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_territories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS territories_updated_at ON territories;
CREATE TRIGGER territories_updated_at
    BEFORE UPDATE ON territories
    FOR EACH ROW
    EXECUTE FUNCTION update_territories_updated_at();

-- Comments for documentation
COMMENT ON TABLE territories IS 'Geographic territory boundaries for churches';
COMMENT ON COLUMN territories.solid IS 'Unique territory identifier (Entity ID + Group ID)';
COMMENT ON COLUMN territories.geom IS 'Territory boundary polygon in WGS84 (EPSG:4326)';
COMMENT ON COLUMN territories.geom_simplified IS 'Simplified geometry for lower zoom levels';
COMMENT ON COLUMN territories.geoid IS 'US Census block group identifier';
