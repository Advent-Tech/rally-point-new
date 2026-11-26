-- Speed up territory search/list endpoints (~235k rows)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ILIKE '%q%' search on address and city (entity_name trigram index already exists)
CREATE INDEX IF NOT EXISTS idx_territories_address_trgm ON territories USING gin (address gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_territories_city_trgm ON territories USING gin (city gin_trgm_ops);

-- Matches ORDER BY in Search/SearchWithGeometry so LIMIT can stop early
CREATE INDEX IF NOT EXISTS idx_territories_name_order ON territories (entity_name, territory_order);

-- Matches ORDER BY in List/ListWithGeometry
CREATE INDEX IF NOT EXISTS idx_territories_list_order ON territories (union_name, conference, entity_name, territory_order);

-- Composite for common filter combos
CREATE INDEX IF NOT EXISTS idx_territories_state_city ON territories (state, city);

ANALYZE territories;
