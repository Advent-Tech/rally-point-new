-- Materialized view read by GetUnionStats (was missing from migrations; fresh DBs returned HTTP 500).
-- Refresh after bulk imports: REFRESH MATERIALIZED VIEW CONCURRENTLY union_stats_mv;
CREATE MATERIALIZED VIEW IF NOT EXISTS union_stats_mv AS
SELECT
    union_name,
    COUNT(*)::int                              AS territory_count,
    COUNT(DISTINCT entity_id)::int             AS church_count,
    COUNT(DISTINCT conference)::int            AS conference_count,
    COALESCE(SUM(COALESCE(population, 0)), 0)::bigint    AS total_population,
    COALESCE(SUM(COALESCE(housing_units, 0)), 0)::bigint AS total_housing
FROM territories
WHERE union_name IS NOT NULL
GROUP BY union_name;

CREATE UNIQUE INDEX IF NOT EXISTS idx_union_stats_mv_union ON union_stats_mv (union_name);
