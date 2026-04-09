package importer

import (
	"database/sql"
	"encoding/hex"
	"fmt"
	"log"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	_ "github.com/mattn/go-sqlite3"
	"rally-point/territory-service/internal/domain"
)

// GeoPackageImporter handles importing GeoPackage files into PostgreSQL
type GeoPackageImporter struct {
	targetDB  *sql.DB
	progress  map[string]*domain.ImportProgress
	mu        sync.RWMutex
}

// NewGeoPackageImporter creates a new GeoPackage importer
func NewGeoPackageImporter(targetDB *sql.DB) *GeoPackageImporter {
	return &GeoPackageImporter{
		targetDB: targetDB,
		progress: make(map[string]*domain.ImportProgress),
	}
}

// ImportFile imports a single GeoPackage file
func (i *GeoPackageImporter) ImportFile(gpkgPath string) (*domain.ImportProgress, error) {
	fileName := filepath.Base(gpkgPath)

	// Initialize progress
	progress := &domain.ImportProgress{
		FileName:  fileName,
		StartedAt: time.Now(),
		Status:    "in_progress",
	}

	i.mu.Lock()
	i.progress[fileName] = progress
	i.mu.Unlock()

	log.Printf("Starting import of %s", gpkgPath)

	// Open GeoPackage (SQLite)
	gpkgDB, err := sql.Open("sqlite3", gpkgPath)
	if err != nil {
		i.setError(progress, fmt.Errorf("failed to open geopackage: %w", err))
		return progress, err
	}
	defer gpkgDB.Close()

	// Get table name from gpkg_contents
	var tableName string
	err = gpkgDB.QueryRow(`SELECT table_name FROM gpkg_contents WHERE data_type = 'features' LIMIT 1`).Scan(&tableName)
	if err != nil {
		i.setError(progress, fmt.Errorf("failed to get table name: %w", err))
		return progress, err
	}

	log.Printf("Found table: %s", tableName)

	// Get total count
	var totalCount int
	err = gpkgDB.QueryRow(fmt.Sprintf(`SELECT COUNT(*) FROM "%s"`, tableName)).Scan(&totalCount)
	if err != nil {
		i.setError(progress, fmt.Errorf("failed to count records: %w", err))
		return progress, err
	}

	progress.TotalRecords = totalCount
	log.Printf("Total records to import: %d", totalCount)

	// Query all features
	// Note: GeoPackage stores geometry in GeoPackage Binary format (GPKG geometry)
	// We need to extract the WKB portion and convert it
	query := fmt.Sprintf(`
		SELECT
			fid,
			SOLID,
			Entity,
			EID,
			GID,
			Address,
			"Street Add",
			City,
			County,
			State,
			Zipcode,
			Population,
			Housing,
			"Union",
			Conference,
			GEOID,
			ZID,
			Label,
			"Order",
			hex(geom) as geom_hex
		FROM "%s"
	`, tableName)

	rows, err := gpkgDB.Query(query)
	if err != nil {
		i.setError(progress, fmt.Errorf("failed to query features: %w", err))
		return progress, err
	}
	defer rows.Close()

	// Begin transaction
	tx, err := i.targetDB.Begin()
	if err != nil {
		i.setError(progress, fmt.Errorf("failed to begin transaction: %w", err))
		return progress, err
	}
	defer tx.Rollback()

	// Prepare insert statement
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
			$17, $18, $19, $20, ST_GeomFromWKB(decode($21, 'hex'), 4326), $22
		)
		ON CONFLICT (fid) DO UPDATE SET
			entity_name = EXCLUDED.entity_name,
			address = EXCLUDED.address,
			city = EXCLUDED.city,
			state = EXCLUDED.state,
			population = EXCLUDED.population,
			housing_units = EXCLUDED.housing_units,
			geom = EXCLUDED.geom,
			source_file = EXCLUDED.source_file,
			updated_at = NOW()
	`)
	if err != nil {
		i.setError(progress, fmt.Errorf("failed to prepare statement: %w", err))
		return progress, err
	}
	defer stmt.Close()

	// Process rows in batches
	batchSize := 1000
	imported := 0
	failed := 0

	for rows.Next() {
		var fid int
		var solid, entity, eid string
		var gid, address, streetAdd, city, county, state, zipcode sql.NullString
		var population, housing sql.NullString
		var unionName, conference, geoid, zid, label sql.NullString
		var order sql.NullFloat64
		var geomHex sql.NullString

		err := rows.Scan(
			&fid, &solid, &entity, &eid, &gid,
			&address, &streetAdd, &city, &county, &state, &zipcode,
			&population, &housing, &unionName, &conference,
			&geoid, &zid, &label, &order, &geomHex,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			failed++
			continue
		}

		// Skip if no geometry
		if !geomHex.Valid || geomHex.String == "" {
			failed++
			continue
		}

		// Extract WKB from GeoPackage geometry
		wkbHex := extractWKBFromGPKG(geomHex.String)
		if wkbHex == "" {
			log.Printf("Failed to extract WKB for fid %d", fid)
			failed++
			continue
		}

		// Parse population and housing as integers
		var pop, house *int
		if population.Valid && population.String != "" {
			p := parseIntFromString(population.String)
			pop = &p
		}
		if housing.Valid && housing.String != "" {
			h := parseIntFromString(housing.String)
			house = &h
		}

		// Insert into PostGIS
		_, err = stmt.Exec(
			uuid.New(),
			fid,
			solid,
			entity,
			eid,
			nullStringPtr(gid),
			nullStringPtr(address),
			nullStringPtr(streetAdd),
			nullStringPtr(city),
			nullStringPtr(county),
			nullStringPtr(state),
			nullStringPtr(zipcode),
			pop,
			house,
			nullStringPtr(unionName),
			nullStringPtr(conference),
			nullStringPtr(geoid),
			nullStringPtr(zid),
			nullStringPtr(label),
			nullFloat64Ptr(order),
			wkbHex,
			fileName,
		)

		if err != nil {
			log.Printf("Error inserting fid %d: %v", fid, err)
			failed++
			continue
		}

		imported++

		// Update progress every batch
		if imported%batchSize == 0 {
			progress.ImportedCount = imported
			progress.FailedCount = failed
			log.Printf("Progress: %d/%d imported, %d failed", imported, totalCount, failed)
		}
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		i.setError(progress, fmt.Errorf("failed to commit transaction: %w", err))
		return progress, err
	}

	// Update final progress
	now := time.Now()
	progress.ImportedCount = imported
	progress.FailedCount = failed
	progress.CompletedAt = &now
	progress.Status = "completed"

	log.Printf("Import completed: %d imported, %d failed out of %d total", imported, failed, totalCount)

	return progress, nil
}

// ImportDirectory imports all GeoPackage files from a directory
func (i *GeoPackageImporter) ImportDirectory(dirPath string) ([]*domain.ImportProgress, error) {
	files, err := filepath.Glob(filepath.Join(dirPath, "*.gpkg"))
	if err != nil {
		return nil, fmt.Errorf("failed to list files: %w", err)
	}

	log.Printf("Found %d GeoPackage files to import", len(files))

	var results []*domain.ImportProgress

	for _, file := range files {
		progress, err := i.ImportFile(file)
		if err != nil {
			log.Printf("Failed to import %s: %v", file, err)
		}
		results = append(results, progress)
	}

	// After all imports, update simplified geometry and refresh church locations
	log.Println("Updating simplified geometries...")
	_, err = i.targetDB.Exec(`
		UPDATE territories
		SET geom_simplified = ST_Simplify(geom, 0.001)
		WHERE geom_simplified IS NULL
	`)
	if err != nil {
		log.Printf("Warning: failed to update simplified geometries: %v", err)
	}

	log.Println("Refreshing church locations...")
	_, err = i.targetDB.Exec("REFRESH MATERIALIZED VIEW church_locations")
	if err != nil {
		log.Printf("Warning: failed to refresh church locations: %v", err)
	}

	return results, nil
}

// GetProgress returns the progress of an import
func (i *GeoPackageImporter) GetProgress(fileName string) *domain.ImportProgress {
	i.mu.RLock()
	defer i.mu.RUnlock()
	return i.progress[fileName]
}

// Helper functions

func (i *GeoPackageImporter) setError(progress *domain.ImportProgress, err error) {
	errMsg := err.Error()
	progress.ErrorMessage = &errMsg
	progress.Status = "failed"
	log.Printf("Import error: %v", err)
}

// extractWKBFromGPKG extracts the WKB portion from a GeoPackage geometry hex string
// GeoPackage geometry format: magic (2 bytes) + version (1 byte) + flags (1 byte) +
// srs_id (4 bytes) + optional envelope + WKB
func extractWKBFromGPKG(gpkgHex string) string {
	if len(gpkgHex) < 16 { // Minimum header size (8 bytes = 16 hex chars)
		return ""
	}

	// Decode hex to bytes
	data, err := hex.DecodeString(gpkgHex)
	if err != nil {
		return ""
	}

	// Check magic number "GP" (0x47, 0x50)
	if len(data) < 8 || data[0] != 0x47 || data[1] != 0x50 {
		// Not a valid GeoPackage geometry, might be raw WKB
		return gpkgHex
	}

	// Flags byte determines envelope size
	flags := data[3]
	envelopeType := (flags >> 1) & 0x07

	// Calculate envelope size based on type
	var envelopeSize int
	switch envelopeType {
	case 0:
		envelopeSize = 0 // No envelope
	case 1:
		envelopeSize = 32 // minx, maxx, miny, maxy (4 * 8 bytes)
	case 2:
		envelopeSize = 48 // + minz, maxz
	case 3:
		envelopeSize = 48 // + minm, maxm
	case 4:
		envelopeSize = 64 // + minz, maxz, minm, maxm
	default:
		envelopeSize = 0
	}

	// WKB starts after header (8 bytes) + envelope
	wkbStart := 8 + envelopeSize
	if wkbStart >= len(data) {
		return ""
	}

	// Return WKB as hex
	return hex.EncodeToString(data[wkbStart:])
}

func parseIntFromString(s string) int {
	// Remove commas and other formatting
	s = strings.ReplaceAll(s, ",", "")
	s = strings.TrimSpace(s)

	// Try to parse as float first (in case it's "123.0")
	if f, err := strconv.ParseFloat(s, 64); err == nil {
		return int(f)
	}

	// Try to parse as int
	if i, err := strconv.Atoi(s); err == nil {
		return i
	}

	return 0
}

func nullStringPtr(ns sql.NullString) *string {
	if ns.Valid && ns.String != "" {
		return &ns.String
	}
	return nil
}

func nullFloat64Ptr(nf sql.NullFloat64) *float64 {
	if nf.Valid {
		return &nf.Float64
	}
	return nil
}
