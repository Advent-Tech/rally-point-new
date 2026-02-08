package postgres

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

type geoTerritoryRepository struct {
	db *sql.DB
}

// NewGeoTerritoryRepository creates a new geo territory repository
func NewGeoTerritoryRepository(db *sql.DB) domain.GeoTerritoryRepository {
	return &geoTerritoryRepository{db: db}
}

func (r *geoTerritoryRepository) GetByID(id uuid.UUID) (*domain.GeoTerritory, error) {
	query := `
		SELECT id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			ST_AsGeoJSON(geom) as geometry,
			source_file, imported_at, created_at, updated_at
		FROM territories
		WHERE id = $1
	`

	return r.scanTerritory(r.db.QueryRow(query, id))
}

func (r *geoTerritoryRepository) GetByFID(fid int) (*domain.GeoTerritory, error) {
	query := `
		SELECT id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			ST_AsGeoJSON(geom) as geometry,
			source_file, imported_at, created_at, updated_at
		FROM territories
		WHERE fid = $1
	`

	return r.scanTerritory(r.db.QueryRow(query, fid))
}

func (r *geoTerritoryRepository) GetBySOLID(solid string) (*domain.GeoTerritory, error) {
	query := `
		SELECT id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			ST_AsGeoJSON(geom) as geometry,
			source_file, imported_at, created_at, updated_at
		FROM territories
		WHERE solid = $1
	`

	return r.scanTerritory(r.db.QueryRow(query, solid))
}

func (r *geoTerritoryRepository) GetByEntityID(entityID string) ([]*domain.GeoTerritory, error) {
	query := `
		SELECT id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			ST_AsGeoJSON(geom) as geometry,
			source_file, imported_at, created_at, updated_at
		FROM territories
		WHERE entity_id = $1
		ORDER BY territory_order, group_id
	`

	return r.scanTerritories(r.db.Query(query, entityID))
}

func (r *geoTerritoryRepository) GetInBounds(bounds domain.BoundsQuery) ([]*domain.GeoTerritory, error) {
	limit := bounds.Limit
	if limit <= 0 || limit > domain.MaxGeoLimit {
		limit = domain.DefaultGeoLimit
	}

	// Use simplified geometry for lower zoom levels
	geomColumn := "geom"
	if bounds.Zoom > 0 && bounds.Zoom < domain.ZoomThresholdSimplified {
		geomColumn = "COALESCE(geom_simplified, geom)"
	}

	query := fmt.Sprintf(`
		SELECT id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			ST_AsGeoJSON(%s) as geometry,
			source_file, imported_at, created_at, updated_at
		FROM territories
		WHERE ST_Intersects(geom, ST_MakeEnvelope($1, $2, $3, $4, 4326))
		LIMIT $5
	`, geomColumn)

	return r.scanTerritories(r.db.Query(query,
		bounds.MinLng, bounds.MinLat, bounds.MaxLng, bounds.MaxLat, limit))
}

func (r *geoTerritoryRepository) GetInBoundsGeoJSON(bounds domain.BoundsQuery) (*domain.GeoJSONFeatureCollection, error) {
	limit := bounds.Limit
	if limit <= 0 || limit > domain.MaxGeoLimit {
		limit = domain.DefaultGeoLimit
	}

	// Use simplified geometry for lower zoom levels
	geomColumn := "geom"
	if bounds.Zoom > 0 && bounds.Zoom < domain.ZoomThresholdSimplified {
		geomColumn = "COALESCE(geom_simplified, geom)"
	}

	query := fmt.Sprintf(`
		SELECT
			id,
			solid,
			entity_name,
			entity_id,
			city,
			state,
			union_name,
			conference,
			population,
			housing_units,
			ST_AsGeoJSON(%s) as geometry
		FROM territories
		WHERE ST_Intersects(geom, ST_MakeEnvelope($1, $2, $3, $4, 4326))
		LIMIT $5
	`, geomColumn)

	rows, err := r.db.Query(query,
		bounds.MinLng, bounds.MinLat, bounds.MaxLng, bounds.MaxLat, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	features := []domain.GeoJSONFeature{}

	for rows.Next() {
		var (
			id, solid, entityName, entityID string
			city, state, unionName, conference sql.NullString
			population, housingUnits sql.NullInt64
			geometryJSON string
		)

		err := rows.Scan(
			&id, &solid, &entityName, &entityID,
			&city, &state, &unionName, &conference,
			&population, &housingUnits, &geometryJSON,
		)
		if err != nil {
			continue
		}

		// Parse geometry JSON
		var geometry interface{}
		json.Unmarshal([]byte(geometryJSON), &geometry)

		properties := map[string]interface{}{
			"solid":       solid,
			"entity_name": entityName,
			"entity_id":   entityID,
		}

		if city.Valid {
			properties["city"] = city.String
		}
		if state.Valid {
			properties["state"] = state.String
		}
		if unionName.Valid {
			properties["union_name"] = unionName.String
		}
		if conference.Valid {
			properties["conference"] = conference.String
		}
		if population.Valid {
			properties["population"] = population.Int64
		}
		if housingUnits.Valid {
			properties["housing_units"] = housingUnits.Int64
		}

		features = append(features, domain.GeoJSONFeature{
			Type:       "Feature",
			ID:         id,
			Geometry:   geometry,
			Properties: properties,
		})
	}

	return &domain.GeoJSONFeatureCollection{
		Type:     "FeatureCollection",
		Features: features,
	}, nil
}

func (r *geoTerritoryRepository) GetByPoint(lat, lng float64) ([]*domain.GeoTerritory, error) {
	query := `
		SELECT id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			ST_AsGeoJSON(geom) as geometry,
			source_file, imported_at, created_at, updated_at
		FROM territories
		WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint($1, $2), 4326))
		ORDER BY entity_name, territory_order
	`

	return r.scanTerritories(r.db.Query(query, lng, lat))
}

func (r *geoTerritoryRepository) Search(query domain.TerritorySearchQuery) ([]*domain.GeoTerritorySimple, error) {
	limit := query.Limit
	if limit <= 0 || limit > domain.MaxSearchLimit {
		limit = domain.DefaultSearchLimit
	}
	offset := query.Offset
	if offset < 0 {
		offset = 0
	}

	// Build dynamic query
	conditions := []string{}
	args := []interface{}{}
	argNum := 1

	if query.Query != "" {
		conditions = append(conditions, fmt.Sprintf(
			"(entity_name ILIKE $%d OR address ILIKE $%d OR city ILIKE $%d)",
			argNum, argNum, argNum))
		args = append(args, "%"+query.Query+"%")
		argNum++
	}
	if query.Union != "" {
		conditions = append(conditions, fmt.Sprintf("union_name = $%d", argNum))
		args = append(args, query.Union)
		argNum++
	}
	if query.Conference != "" {
		conditions = append(conditions, fmt.Sprintf("conference = $%d", argNum))
		args = append(args, query.Conference)
		argNum++
	}
	if query.State != "" {
		conditions = append(conditions, fmt.Sprintf("state = $%d", argNum))
		args = append(args, query.State)
		argNum++
	}
	if query.City != "" {
		conditions = append(conditions, fmt.Sprintf("city ILIKE $%d", argNum))
		args = append(args, "%"+query.City+"%")
		argNum++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	args = append(args, limit, offset)

	sqlQuery := fmt.Sprintf(`
		SELECT id, solid, entity_name, entity_id, city, state,
			union_name, conference, population
		FROM territories
		%s
		ORDER BY entity_name, territory_order
		LIMIT $%d OFFSET $%d
	`, whereClause, argNum, argNum+1)

	rows, err := r.db.Query(sqlQuery, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanSimpleTerritories(rows)
}

func (r *geoTerritoryRepository) List(filters domain.TerritoryFilters) ([]*domain.GeoTerritorySimple, int, error) {
	limit := filters.Limit
	if limit <= 0 || limit > domain.MaxSearchLimit {
		limit = domain.DefaultSearchLimit
	}
	offset := filters.Offset
	if offset < 0 {
		offset = 0
	}

	// Build dynamic query
	conditions := []string{}
	args := []interface{}{}
	argNum := 1

	if filters.UnionName != "" {
		conditions = append(conditions, fmt.Sprintf("union_name = $%d", argNum))
		args = append(args, filters.UnionName)
		argNum++
	}
	if filters.Conference != "" {
		conditions = append(conditions, fmt.Sprintf("conference = $%d", argNum))
		args = append(args, filters.Conference)
		argNum++
	}
	if filters.State != "" {
		conditions = append(conditions, fmt.Sprintf("state = $%d", argNum))
		args = append(args, filters.State)
		argNum++
	}
	if filters.City != "" {
		conditions = append(conditions, fmt.Sprintf("city = $%d", argNum))
		args = append(args, filters.City)
		argNum++
	}
	if filters.EntityID != "" {
		conditions = append(conditions, fmt.Sprintf("entity_id = $%d", argNum))
		args = append(args, filters.EntityID)
		argNum++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	// Get total count
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM territories %s", whereClause)
	var totalCount int
	if len(args) > 0 {
		r.db.QueryRow(countQuery, args...).Scan(&totalCount)
	} else {
		r.db.QueryRow(countQuery).Scan(&totalCount)
	}

	// Get results
	args = append(args, limit, offset)
	sqlQuery := fmt.Sprintf(`
		SELECT id, solid, entity_name, entity_id, city, state,
			union_name, conference, population
		FROM territories
		%s
		ORDER BY union_name, conference, entity_name, territory_order
		LIMIT $%d OFFSET $%d
	`, whereClause, argNum, argNum+1)

	rows, err := r.db.Query(sqlQuery, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	results, err := r.scanSimpleTerritories(rows)
	return results, totalCount, err
}

func (r *geoTerritoryRepository) SearchWithGeometry(query domain.TerritorySearchQuery) ([]*domain.GeoTerritory, error) {
	limit := query.Limit
	if limit <= 0 || limit > domain.MaxSearchLimit {
		limit = domain.DefaultSearchLimit
	}
	offset := query.Offset
	if offset < 0 {
		offset = 0
	}

	// Build dynamic query
	conditions := []string{}
	args := []interface{}{}
	argNum := 1

	if query.Query != "" {
		conditions = append(conditions, fmt.Sprintf(
			"(entity_name ILIKE $%d OR address ILIKE $%d OR city ILIKE $%d)",
			argNum, argNum, argNum))
		args = append(args, "%"+query.Query+"%")
		argNum++
	}
	if query.Union != "" {
		conditions = append(conditions, fmt.Sprintf("union_name = $%d", argNum))
		args = append(args, query.Union)
		argNum++
	}
	if query.Conference != "" {
		conditions = append(conditions, fmt.Sprintf("conference = $%d", argNum))
		args = append(args, query.Conference)
		argNum++
	}
	if query.State != "" {
		conditions = append(conditions, fmt.Sprintf("state = $%d", argNum))
		args = append(args, query.State)
		argNum++
	}
	if query.City != "" {
		conditions = append(conditions, fmt.Sprintf("city ILIKE $%d", argNum))
		args = append(args, "%"+query.City+"%")
		argNum++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	args = append(args, limit, offset)

	sqlQuery := fmt.Sprintf(`
		SELECT id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			ST_AsGeoJSON(geom) as geometry,
			source_file, imported_at, created_at, updated_at
		FROM territories
		%s
		ORDER BY entity_name, territory_order
		LIMIT $%d OFFSET $%d
	`, whereClause, argNum, argNum+1)

	return r.scanTerritories(r.db.Query(sqlQuery, args...))
}

func (r *geoTerritoryRepository) ListWithGeometry(filters domain.TerritoryFilters) ([]*domain.GeoTerritory, int, error) {
	limit := filters.Limit
	if limit <= 0 || limit > domain.MaxSearchLimit {
		limit = domain.DefaultSearchLimit
	}
	offset := filters.Offset
	if offset < 0 {
		offset = 0
	}

	// Build dynamic query
	conditions := []string{}
	args := []interface{}{}
	argNum := 1

	if filters.UnionName != "" {
		conditions = append(conditions, fmt.Sprintf("union_name = $%d", argNum))
		args = append(args, filters.UnionName)
		argNum++
	}
	if filters.Conference != "" {
		conditions = append(conditions, fmt.Sprintf("conference = $%d", argNum))
		args = append(args, filters.Conference)
		argNum++
	}
	if filters.State != "" {
		conditions = append(conditions, fmt.Sprintf("state = $%d", argNum))
		args = append(args, filters.State)
		argNum++
	}
	if filters.City != "" {
		conditions = append(conditions, fmt.Sprintf("city = $%d", argNum))
		args = append(args, filters.City)
		argNum++
	}
	if filters.EntityID != "" {
		conditions = append(conditions, fmt.Sprintf("entity_id = $%d", argNum))
		args = append(args, filters.EntityID)
		argNum++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	// Get total count
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM territories %s", whereClause)
	var totalCount int
	if len(args) > 0 {
		r.db.QueryRow(countQuery, args...).Scan(&totalCount)
	} else {
		r.db.QueryRow(countQuery).Scan(&totalCount)
	}

	// Get results with geometry
	args = append(args, limit, offset)
	sqlQuery := fmt.Sprintf(`
		SELECT id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			ST_AsGeoJSON(geom) as geometry,
			source_file, imported_at, created_at, updated_at
		FROM territories
		%s
		ORDER BY union_name, conference, entity_name, territory_order
		LIMIT $%d OFFSET $%d
	`, whereClause, argNum, argNum+1)

	results, err := r.scanTerritories(r.db.Query(sqlQuery, args...))
	return results, totalCount, err
}

func (r *geoTerritoryRepository) GetChurchLocations(bounds *domain.BoundsQuery) ([]*domain.ChurchLocation, error) {
	var query string
	var args []interface{}

	if bounds != nil {
		query = `
			SELECT entity_id, entity_name, union_name, conference,
				address, city, state,
				ST_Y(location) as latitude, ST_X(location) as longitude,
				territory_count, total_population, total_housing
			FROM church_locations
			WHERE ST_Intersects(location, ST_MakeEnvelope($1, $2, $3, $4, 4326))
			ORDER BY entity_name
		`
		args = []interface{}{bounds.MinLng, bounds.MinLat, bounds.MaxLng, bounds.MaxLat}
	} else {
		query = `
			SELECT entity_id, entity_name, union_name, conference,
				address, city, state,
				ST_Y(location) as latitude, ST_X(location) as longitude,
				territory_count, total_population, total_housing
			FROM church_locations
			ORDER BY entity_name
			LIMIT 1000
		`
	}

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var locations []*domain.ChurchLocation
	for rows.Next() {
		loc := &domain.ChurchLocation{}
		var unionName, conference, address, city, state sql.NullString

		err := rows.Scan(
			&loc.EntityID, &loc.EntityName, &unionName, &conference,
			&address, &city, &state,
			&loc.Latitude, &loc.Longitude,
			&loc.TerritoryCount, &loc.TotalPopulation, &loc.TotalHousing,
		)
		if err != nil {
			continue
		}

		if unionName.Valid {
			loc.UnionName = &unionName.String
		}
		if conference.Valid {
			loc.Conference = &conference.String
		}
		if address.Valid {
			loc.Address = &address.String
		}
		if city.Valid {
			loc.City = &city.String
		}
		if state.Valid {
			loc.State = &state.String
		}

		locations = append(locations, loc)
	}

	return locations, nil
}

func (r *geoTerritoryRepository) GetChurchByEntityID(entityID string) (*domain.ChurchLocation, error) {
	query := `
		SELECT entity_id, entity_name, union_name, conference,
			address, city, state,
			ST_Y(location) as latitude, ST_X(location) as longitude,
			territory_count, total_population, total_housing
		FROM church_locations
		WHERE entity_id = $1
	`

	row := r.db.QueryRow(query, entityID)

	loc := &domain.ChurchLocation{}
	var unionName, conference, address, city, state sql.NullString

	err := row.Scan(
		&loc.EntityID, &loc.EntityName, &unionName, &conference,
		&address, &city, &state,
		&loc.Latitude, &loc.Longitude,
		&loc.TerritoryCount, &loc.TotalPopulation, &loc.TotalHousing,
	)
	if err != nil {
		return nil, err
	}

	if unionName.Valid {
		loc.UnionName = &unionName.String
	}
	if conference.Valid {
		loc.Conference = &conference.String
	}
	if address.Valid {
		loc.Address = &address.String
	}
	if city.Valid {
		loc.City = &city.String
	}
	if state.Valid {
		loc.State = &state.String
	}

	return loc, nil
}

func (r *geoTerritoryRepository) GetUnionStats() ([]*domain.UnionStats, error) {
	// Use materialized view for fast stats retrieval
	// The view is pre-computed and indexed, taking <1ms instead of 50+ seconds
	query := `
		SELECT
			union_name,
			territory_count,
			church_count,
			conference_count,
			total_population,
			total_housing
		FROM union_stats_mv
		ORDER BY union_name
	`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stats []*domain.UnionStats
	for rows.Next() {
		s := &domain.UnionStats{}
		err := rows.Scan(
			&s.UnionName, &s.TerritoryCount, &s.ChurchCount,
			&s.ConferenceCount, &s.TotalPopulation, &s.TotalHousing,
		)
		if err != nil {
			continue
		}
		stats = append(stats, s)
	}

	return stats, nil
}

func (r *geoTerritoryRepository) GetConferenceStats(unionName string) ([]*domain.ConferenceStats, error) {
	query := `
		SELECT
			conference,
			union_name,
			COUNT(*) as territory_count,
			COUNT(DISTINCT entity_id) as church_count,
			SUM(COALESCE(population, 0)) as total_population,
			SUM(COALESCE(housing_units, 0)) as total_housing
		FROM territories
		WHERE union_name = $1 AND conference IS NOT NULL
		GROUP BY conference, union_name
		ORDER BY conference
	`

	rows, err := r.db.Query(query, unionName)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stats []*domain.ConferenceStats
	for rows.Next() {
		s := &domain.ConferenceStats{}
		err := rows.Scan(
			&s.Conference, &s.UnionName, &s.TerritoryCount,
			&s.ChurchCount, &s.TotalPopulation, &s.TotalHousing,
		)
		if err != nil {
			continue
		}
		stats = append(stats, s)
	}

	return stats, nil
}

func (r *geoTerritoryRepository) GetTotalCount() (int, error) {
	var count int
	err := r.db.QueryRow("SELECT COUNT(*) FROM territories").Scan(&count)
	return count, err
}

func (r *geoTerritoryRepository) GetVectorTile(z, x, y int) ([]byte, error) {
	query := `
		WITH bounds AS (
			SELECT ST_TileEnvelope($1, $2, $3) AS geom
		),
		mvt AS (
			SELECT
				ST_AsMVTGeom(
					t.geom,
					bounds.geom,
					4096, 64, true
				) AS geom,
				t.id::text,
				t.solid,
				t.entity_name,
				t.entity_id,
				t.city,
				t.state,
				t.union_name,
				t.conference,
				t.population
			FROM territories t, bounds
			WHERE ST_Intersects(t.geom, bounds.geom)
		)
		SELECT ST_AsMVT(mvt.*, 'territories', 4096, 'geom')
		FROM mvt
	`

	var tile []byte
	err := r.db.QueryRow(query, z, x, y).Scan(&tile)
	if err != nil {
		return nil, err
	}

	return tile, nil
}

func (r *geoTerritoryRepository) GetNextFID() (int, error) {
	var nextFID int
	err := r.db.QueryRow("SELECT COALESCE(MAX(fid), 0) + 1 FROM territories").Scan(&nextFID)
	return nextFID, err
}

func (r *geoTerritoryRepository) Create(territory *domain.GeoTerritory) error {
	query := `
		INSERT INTO territories (
			id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order,
			geom, source_file
		) VALUES (
			$1, $2, $3, $4, $5, $6,
			$7, $8, $9, $10, $11, $12,
			$13, $14, $15, $16,
			$17, $18, $19, $20,
			ST_Multi(ST_GeomFromGeoJSON($21)), $22
		)
	`
	_, err := r.db.Exec(query,
		territory.ID, territory.FID, territory.SOLID, territory.EntityName, territory.EntityID, territory.GroupID,
		territory.Address, territory.StreetAddress, territory.City, territory.County, territory.State, territory.Zipcode,
		territory.Population, territory.HousingUnits, territory.UnionName, territory.Conference,
		territory.GEOID, territory.ZID, territory.Label, territory.Order,
		string(territory.Geometry), territory.SourceFile,
	)
	return err
}

func (r *geoTerritoryRepository) Update(id uuid.UUID, req *domain.UpdateGeoTerritoryRequest) error {
	setClauses := []string{}
	args := []interface{}{}
	argNum := 1

	if req.EntityName != nil {
		setClauses = append(setClauses, fmt.Sprintf("entity_name = $%d", argNum))
		args = append(args, *req.EntityName)
		argNum++
	}
	if req.EntityID != nil {
		setClauses = append(setClauses, fmt.Sprintf("entity_id = $%d", argNum))
		args = append(args, *req.EntityID)
		argNum++
	}
	if req.SOLID != nil {
		setClauses = append(setClauses, fmt.Sprintf("solid = $%d", argNum))
		args = append(args, *req.SOLID)
		argNum++
	}
	if req.GroupID != nil {
		setClauses = append(setClauses, fmt.Sprintf("group_id = $%d", argNum))
		args = append(args, *req.GroupID)
		argNum++
	}
	if req.Address != nil {
		setClauses = append(setClauses, fmt.Sprintf("address = $%d", argNum))
		args = append(args, *req.Address)
		argNum++
	}
	if req.StreetAddress != nil {
		setClauses = append(setClauses, fmt.Sprintf("street_address = $%d", argNum))
		args = append(args, *req.StreetAddress)
		argNum++
	}
	if req.City != nil {
		setClauses = append(setClauses, fmt.Sprintf("city = $%d", argNum))
		args = append(args, *req.City)
		argNum++
	}
	if req.County != nil {
		setClauses = append(setClauses, fmt.Sprintf("county = $%d", argNum))
		args = append(args, *req.County)
		argNum++
	}
	if req.State != nil {
		setClauses = append(setClauses, fmt.Sprintf("state = $%d", argNum))
		args = append(args, *req.State)
		argNum++
	}
	if req.Zipcode != nil {
		setClauses = append(setClauses, fmt.Sprintf("zipcode = $%d", argNum))
		args = append(args, *req.Zipcode)
		argNum++
	}
	if req.Population != nil {
		setClauses = append(setClauses, fmt.Sprintf("population = $%d", argNum))
		args = append(args, *req.Population)
		argNum++
	}
	if req.HousingUnits != nil {
		setClauses = append(setClauses, fmt.Sprintf("housing_units = $%d", argNum))
		args = append(args, *req.HousingUnits)
		argNum++
	}
	if req.UnionName != nil {
		setClauses = append(setClauses, fmt.Sprintf("union_name = $%d", argNum))
		args = append(args, *req.UnionName)
		argNum++
	}
	if req.Conference != nil {
		setClauses = append(setClauses, fmt.Sprintf("conference = $%d", argNum))
		args = append(args, *req.Conference)
		argNum++
	}
	if req.GEOID != nil {
		setClauses = append(setClauses, fmt.Sprintf("geoid = $%d", argNum))
		args = append(args, *req.GEOID)
		argNum++
	}
	if req.ZID != nil {
		setClauses = append(setClauses, fmt.Sprintf("zid = $%d", argNum))
		args = append(args, *req.ZID)
		argNum++
	}
	if req.Label != nil {
		setClauses = append(setClauses, fmt.Sprintf("label = $%d", argNum))
		args = append(args, *req.Label)
		argNum++
	}
	if req.Order != nil {
		setClauses = append(setClauses, fmt.Sprintf("territory_order = $%d", argNum))
		args = append(args, *req.Order)
		argNum++
	}
	if len(req.Geometry) > 0 {
		setClauses = append(setClauses, fmt.Sprintf("geom = ST_Multi(ST_GeomFromGeoJSON($%d))", argNum))
		args = append(args, string(req.Geometry))
		argNum++
		setClauses = append(setClauses, "geom_simplified = NULL")
	}

	if len(setClauses) == 0 {
		return nil
	}

	setClauses = append(setClauses, "updated_at = NOW()")

	query := fmt.Sprintf("UPDATE territories SET %s WHERE id = $%d",
		strings.Join(setClauses, ", "), argNum)
	args = append(args, id)

	result, err := r.db.Exec(query, args...)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return fmt.Errorf("territory not found")
	}
	return nil
}

func (r *geoTerritoryRepository) Delete(id uuid.UUID) error {
	result, err := r.db.Exec("DELETE FROM territories WHERE id = $1", id)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return fmt.Errorf("territory not found")
	}
	return nil
}

func (r *geoTerritoryRepository) ValidateGeometry(geojson json.RawMessage) (*domain.GeometryValidationResult, error) {
	var isValid bool
	var reason string
	err := r.db.QueryRow(
		"SELECT ST_IsValid(ST_GeomFromGeoJSON($1)), ST_IsValidReason(ST_GeomFromGeoJSON($1))",
		string(geojson),
	).Scan(&isValid, &reason)
	if err != nil {
		return nil, err
	}
	result := &domain.GeometryValidationResult{
		IsValid: isValid,
		Reason:  reason,
	}
	return result, nil
}

func (r *geoTerritoryRepository) CheckOverlaps(geojson json.RawMessage, excludeID *uuid.UUID) ([]string, error) {
	var query string
	var args []interface{}

	if excludeID != nil {
		query = `
			SELECT id::text FROM territories
			WHERE ST_Intersects(geom, ST_Multi(ST_GeomFromGeoJSON($1)))
			AND NOT ST_Touches(geom, ST_Multi(ST_GeomFromGeoJSON($1)))
			AND id != $2
		`
		args = []interface{}{string(geojson), *excludeID}
	} else {
		query = `
			SELECT id::text FROM territories
			WHERE ST_Intersects(geom, ST_Multi(ST_GeomFromGeoJSON($1)))
			AND NOT ST_Touches(geom, ST_Multi(ST_GeomFromGeoJSON($1)))
		`
		args = []interface{}{string(geojson)}
	}

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			continue
		}
		ids = append(ids, id)
	}
	return ids, nil
}

func (r *geoTerritoryRepository) CreateBatch(territories []*domain.GeoTerritory) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`
		INSERT INTO territories (
			id, fid, solid, entity_name, entity_id, group_id,
			address, street_address, city, county, state, zipcode,
			population, housing_units, union_name, conference,
			geoid, zid, label, territory_order, geom, source_file
		) VALUES (
			$1, $2, $3, $4, $5, $6,
			$7, $8, $9, $10, $11, $12,
			$13, $14, $15, $16,
			$17, $18, $19, $20, ST_GeomFromGeoJSON($21), $22
		)
		ON CONFLICT (fid) DO UPDATE SET
			entity_name = EXCLUDED.entity_name,
			address = EXCLUDED.address,
			population = EXCLUDED.population,
			housing_units = EXCLUDED.housing_units,
			geom = EXCLUDED.geom,
			updated_at = NOW()
	`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, t := range territories {
		_, err := stmt.Exec(
			t.ID, t.FID, t.SOLID, t.EntityName, t.EntityID, t.GroupID,
			t.Address, t.StreetAddress, t.City, t.County, t.State, t.Zipcode,
			t.Population, t.HousingUnits, t.UnionName, t.Conference,
			t.GEOID, t.ZID, t.Label, t.Order, t.Geometry, t.SourceFile,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (r *geoTerritoryRepository) UpdateSimplifiedGeometry(tolerance float64) error {
	query := `
		UPDATE territories
		SET geom_simplified = ST_Simplify(geom, $1)
		WHERE geom_simplified IS NULL
	`
	_, err := r.db.Exec(query, tolerance)
	return err
}

func (r *geoTerritoryRepository) RefreshChurchLocations() error {
	_, err := r.db.Exec("REFRESH MATERIALIZED VIEW CONCURRENTLY church_locations")
	return err
}

// Helper functions

func (r *geoTerritoryRepository) scanTerritory(row *sql.Row) (*domain.GeoTerritory, error) {
	t := &domain.GeoTerritory{}

	var groupID, address, streetAddress, city, county, state, zipcode sql.NullString
	var unionName, conference, geoid, zid, label, sourceFile sql.NullString
	var population, housingUnits sql.NullInt64
	var order sql.NullFloat64
	var geometryJSON sql.NullString

	err := row.Scan(
		&t.ID, &t.FID, &t.SOLID, &t.EntityName, &t.EntityID, &groupID,
		&address, &streetAddress, &city, &county, &state, &zipcode,
		&population, &housingUnits, &unionName, &conference,
		&geoid, &zid, &label, &order,
		&geometryJSON,
		&sourceFile, &t.ImportedAt, &t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	// Convert geometry string to json.RawMessage
	if geometryJSON.Valid && geometryJSON.String != "" {
		t.Geometry = json.RawMessage(geometryJSON.String)
	}

	// Set nullable fields
	if groupID.Valid {
		t.GroupID = &groupID.String
	}
	if address.Valid {
		t.Address = &address.String
	}
	if streetAddress.Valid {
		t.StreetAddress = &streetAddress.String
	}
	if city.Valid {
		t.City = &city.String
	}
	if county.Valid {
		t.County = &county.String
	}
	if state.Valid {
		t.State = &state.String
	}
	if zipcode.Valid {
		t.Zipcode = &zipcode.String
	}
	if population.Valid {
		pop := int(population.Int64)
		t.Population = &pop
	}
	if housingUnits.Valid {
		hu := int(housingUnits.Int64)
		t.HousingUnits = &hu
	}
	if unionName.Valid {
		t.UnionName = &unionName.String
	}
	if conference.Valid {
		t.Conference = &conference.String
	}
	if geoid.Valid {
		t.GEOID = &geoid.String
	}
	if zid.Valid {
		t.ZID = &zid.String
	}
	if label.Valid {
		t.Label = &label.String
	}
	if order.Valid {
		t.Order = &order.Float64
	}
	if sourceFile.Valid {
		t.SourceFile = &sourceFile.String
	}

	return t, nil
}

func (r *geoTerritoryRepository) scanTerritories(rows *sql.Rows, err error) ([]*domain.GeoTerritory, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var territories []*domain.GeoTerritory

	for rows.Next() {
		t := &domain.GeoTerritory{}

		var groupID, address, streetAddress, city, county, state, zipcode sql.NullString
		var unionName, conference, geoid, zid, label, sourceFile sql.NullString
		var population, housingUnits sql.NullInt64
		var order sql.NullFloat64
		var geometryJSON sql.NullString

		err := rows.Scan(
			&t.ID, &t.FID, &t.SOLID, &t.EntityName, &t.EntityID, &groupID,
			&address, &streetAddress, &city, &county, &state, &zipcode,
			&population, &housingUnits, &unionName, &conference,
			&geoid, &zid, &label, &order,
			&geometryJSON,
			&sourceFile, &t.ImportedAt, &t.CreatedAt, &t.UpdatedAt,
		)
		if err != nil {
			continue
		}

		// Convert geometry string to json.RawMessage
		if geometryJSON.Valid && geometryJSON.String != "" {
			t.Geometry = json.RawMessage(geometryJSON.String)
		}

		// Set nullable fields
		if groupID.Valid {
			t.GroupID = &groupID.String
		}
		if address.Valid {
			t.Address = &address.String
		}
		if streetAddress.Valid {
			t.StreetAddress = &streetAddress.String
		}
		if city.Valid {
			t.City = &city.String
		}
		if county.Valid {
			t.County = &county.String
		}
		if state.Valid {
			t.State = &state.String
		}
		if zipcode.Valid {
			t.Zipcode = &zipcode.String
		}
		if population.Valid {
			pop := int(population.Int64)
			t.Population = &pop
		}
		if housingUnits.Valid {
			hu := int(housingUnits.Int64)
			t.HousingUnits = &hu
		}
		if unionName.Valid {
			t.UnionName = &unionName.String
		}
		if conference.Valid {
			t.Conference = &conference.String
		}
		if geoid.Valid {
			t.GEOID = &geoid.String
		}
		if zid.Valid {
			t.ZID = &zid.String
		}
		if label.Valid {
			t.Label = &label.String
		}
		if order.Valid {
			t.Order = &order.Float64
		}
		if sourceFile.Valid {
			t.SourceFile = &sourceFile.String
		}

		territories = append(territories, t)
	}

	return territories, nil
}

func (r *geoTerritoryRepository) scanSimpleTerritories(rows *sql.Rows) ([]*domain.GeoTerritorySimple, error) {
	var territories []*domain.GeoTerritorySimple

	for rows.Next() {
		t := &domain.GeoTerritorySimple{}
		var city, state, unionName, conference sql.NullString
		var population sql.NullInt64

		err := rows.Scan(
			&t.ID, &t.SOLID, &t.EntityName, &t.EntityID,
			&city, &state, &unionName, &conference, &population,
		)
		if err != nil {
			continue
		}

		if city.Valid {
			t.City = &city.String
		}
		if state.Valid {
			t.State = &state.String
		}
		if unionName.Valid {
			t.UnionName = &unionName.String
		}
		if conference.Valid {
			t.Conference = &conference.String
		}
		if population.Valid {
			pop := int(population.Int64)
			t.Population = &pop
		}

		territories = append(territories, t)
	}

	return territories, nil
}
