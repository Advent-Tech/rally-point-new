package service

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
	"rally-point/territory-service/internal/importer"
)

type geoTerritoryService struct {
	repo     domain.GeoTerritoryRepository
	importer *importer.GeoPackageImporter
}

// NewGeoTerritoryService creates a new geo territory service
func NewGeoTerritoryService(repo domain.GeoTerritoryRepository, imp *importer.GeoPackageImporter) domain.GeoTerritoryService {
	return &geoTerritoryService{
		repo:     repo,
		importer: imp,
	}
}

// GetTerritory retrieves a territory by ID
func (s *geoTerritoryService) GetTerritory(id uuid.UUID) (*domain.GeoTerritory, error) {
	territory, err := s.repo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get territory: %w", err)
	}
	return territory, nil
}

// GetTerritoryBySOLID retrieves a territory by SOLID
func (s *geoTerritoryService) GetTerritoryBySOLID(solid string) (*domain.GeoTerritory, error) {
	territory, err := s.repo.GetBySOLID(solid)
	if err != nil {
		return nil, fmt.Errorf("failed to get territory by SOLID: %w", err)
	}
	return territory, nil
}

// GetTerritoriesByEntity retrieves all territories for an entity
func (s *geoTerritoryService) GetTerritoriesByEntity(entityID string) ([]*domain.GeoTerritory, error) {
	territories, err := s.repo.GetByEntityID(entityID)
	if err != nil {
		return nil, fmt.Errorf("failed to get territories by entity: %w", err)
	}
	return territories, nil
}

// GetTerritoriesInBounds retrieves territories within geographic bounds as GeoJSON
func (s *geoTerritoryService) GetTerritoriesInBounds(bounds domain.BoundsQuery) (*domain.GeoJSONFeatureCollection, error) {
	// Validate bounds
	if bounds.MinLng >= bounds.MaxLng || bounds.MinLat >= bounds.MaxLat {
		return nil, fmt.Errorf("invalid bounds: min must be less than max")
	}

	// Apply defaults
	if bounds.Limit <= 0 {
		bounds.Limit = domain.DefaultGeoLimit
	}
	if bounds.Limit > domain.MaxGeoLimit {
		bounds.Limit = domain.MaxGeoLimit
	}

	return s.repo.GetInBoundsGeoJSON(bounds)
}

// GetTerritoriesAtPoint retrieves territories containing a point
func (s *geoTerritoryService) GetTerritoriesAtPoint(lat, lng float64) ([]*domain.GeoTerritory, error) {
	// Validate coordinates
	if lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		return nil, fmt.Errorf("invalid coordinates: lat must be -90 to 90, lng must be -180 to 180")
	}

	return s.repo.GetByPoint(lat, lng)
}

// SearchTerritories searches for territories
func (s *geoTerritoryService) SearchTerritories(query domain.TerritorySearchQuery) ([]*domain.GeoTerritorySimple, error) {
	// Apply defaults
	if query.Limit <= 0 {
		query.Limit = domain.DefaultSearchLimit
	}
	if query.Limit > domain.MaxSearchLimit {
		query.Limit = domain.MaxSearchLimit
	}

	return s.repo.Search(query)
}

// SearchTerritoriesWithGeometry searches for territories and includes geometry data
func (s *geoTerritoryService) SearchTerritoriesWithGeometry(query domain.TerritorySearchQuery) ([]*domain.GeoTerritory, error) {
	// Apply defaults
	if query.Limit <= 0 {
		query.Limit = domain.DefaultSearchLimit
	}
	if query.Limit > domain.MaxSearchLimit {
		query.Limit = domain.MaxSearchLimit
	}

	return s.repo.SearchWithGeometry(query)
}

// ListTerritories lists territories with filters
func (s *geoTerritoryService) ListTerritories(filters domain.TerritoryFilters) ([]*domain.GeoTerritorySimple, int, error) {
	// Apply defaults
	if filters.Limit <= 0 {
		filters.Limit = domain.DefaultSearchLimit
	}
	if filters.Limit > domain.MaxSearchLimit {
		filters.Limit = domain.MaxSearchLimit
	}

	return s.repo.List(filters)
}

// ListTerritoriesWithGeometry lists territories with filters and includes geometry data
func (s *geoTerritoryService) ListTerritoriesWithGeometry(filters domain.TerritoryFilters) ([]*domain.GeoTerritory, int, error) {
	// Apply defaults
	if filters.Limit <= 0 {
		filters.Limit = domain.DefaultSearchLimit
	}
	if filters.Limit > domain.MaxSearchLimit {
		filters.Limit = domain.MaxSearchLimit
	}

	return s.repo.ListWithGeometry(filters)
}

// GetChurchLocations retrieves church point locations
func (s *geoTerritoryService) GetChurchLocations(bounds *domain.BoundsQuery) ([]*domain.ChurchLocation, error) {
	return s.repo.GetChurchLocations(bounds)
}

// GetChurch retrieves a church by entity ID
func (s *geoTerritoryService) GetChurch(entityID string) (*domain.ChurchLocation, error) {
	return s.repo.GetChurchByEntityID(entityID)
}

// GetUnionStats retrieves statistics for all unions
func (s *geoTerritoryService) GetUnionStats() ([]*domain.UnionStats, error) {
	return s.repo.GetUnionStats()
}

// GetConferenceStats retrieves statistics for conferences in a union
func (s *geoTerritoryService) GetConferenceStats(unionName string) ([]*domain.ConferenceStats, error) {
	if unionName == "" {
		return nil, fmt.Errorf("union name is required")
	}
	return s.repo.GetConferenceStats(unionName)
}

// GetVectorTile retrieves a vector tile for the specified coordinates
func (s *geoTerritoryService) GetVectorTile(z, x, y int) ([]byte, error) {
	// Validate tile coordinates
	if z < domain.MinTileZoom || z > domain.MaxTileZoom {
		return nil, fmt.Errorf("invalid zoom level: must be between %d and %d", domain.MinTileZoom, domain.MaxTileZoom)
	}

	maxTile := 1 << z
	if x < 0 || x >= maxTile || y < 0 || y >= maxTile {
		return nil, fmt.Errorf("invalid tile coordinates for zoom level %d", z)
	}

	return s.repo.GetVectorTile(z, x, y)
}

// CreateTerritory creates a new territory
func (s *geoTerritoryService) CreateTerritory(req *domain.CreateGeoTerritoryRequest) (*domain.GeoTerritory, error) {
	// Validate geometry
	validation, err := s.repo.ValidateGeometry(req.Geometry)
	if err != nil {
		return nil, fmt.Errorf("failed to validate geometry: %w", err)
	}
	if !validation.IsValid {
		return nil, fmt.Errorf("invalid geometry: %s", validation.Reason)
	}

	// Check overlaps (warn, don't block)
	overlaps, err := s.repo.CheckOverlaps(req.Geometry, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to check overlaps: %w", err)
	}
	_ = overlaps // overlaps are informational only

	// Get next FID
	fid, err := s.repo.GetNextFID()
	if err != nil {
		return nil, fmt.Errorf("failed to get next FID: %w", err)
	}

	// Auto-generate SOLID if not provided
	id := uuid.New()
	solid := ""
	if req.SOLID != nil {
		solid = *req.SOLID
	} else {
		solid = fmt.Sprintf("MANUAL-%s", id.String()[:8])
	}

	sourceFile := "manual"
	now := time.Now()

	territory := &domain.GeoTerritory{
		ID:            id,
		FID:           fid,
		SOLID:         solid,
		EntityName:    req.EntityName,
		EntityID:      req.EntityID,
		GroupID:        req.GroupID,
		Address:       req.Address,
		StreetAddress: req.StreetAddress,
		City:          req.City,
		County:        req.County,
		State:         req.State,
		Zipcode:       req.Zipcode,
		Population:    req.Population,
		HousingUnits:  req.HousingUnits,
		UnionName:     req.UnionName,
		Conference:    req.Conference,
		GEOID:         req.GEOID,
		ZID:           req.ZID,
		Label:         req.Label,
		Order:         req.Order,
		Geometry:      req.Geometry,
		SourceFile:    &sourceFile,
		ImportedAt:    now,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	if err := s.repo.Create(territory); err != nil {
		return nil, fmt.Errorf("failed to create territory: %w", err)
	}

	// Re-fetch to get the full object
	return s.repo.GetByID(id)
}

// UpdateTerritory updates an existing territory
func (s *geoTerritoryService) UpdateTerritory(id uuid.UUID, req *domain.UpdateGeoTerritoryRequest) (*domain.GeoTerritory, error) {
	// Verify exists
	_, err := s.repo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("territory not found: %w", err)
	}

	// If geometry changed, validate and check overlaps
	if len(req.Geometry) > 0 {
		validation, err := s.repo.ValidateGeometry(req.Geometry)
		if err != nil {
			return nil, fmt.Errorf("failed to validate geometry: %w", err)
		}
		if !validation.IsValid {
			return nil, fmt.Errorf("invalid geometry: %s", validation.Reason)
		}
	}

	if err := s.repo.Update(id, req); err != nil {
		return nil, fmt.Errorf("failed to update territory: %w", err)
	}

	return s.repo.GetByID(id)
}

// DeleteTerritory deletes a territory
func (s *geoTerritoryService) DeleteTerritory(id uuid.UUID) error {
	return s.repo.Delete(id)
}

// ValidateGeometry validates a GeoJSON geometry and checks for overlaps
func (s *geoTerritoryService) ValidateGeometry(geojson json.RawMessage) (*domain.GeometryValidationResult, error) {
	validation, err := s.repo.ValidateGeometry(geojson)
	if err != nil {
		return nil, fmt.Errorf("failed to validate geometry: %w", err)
	}

	// Also check overlaps
	overlaps, err := s.repo.CheckOverlaps(geojson, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to check overlaps: %w", err)
	}
	validation.OverlappingIDs = overlaps

	return validation, nil
}

// ImportGeoPackage imports a GeoPackage file
func (s *geoTerritoryService) ImportGeoPackage(filePath string) (*domain.ImportProgress, error) {
	if s.importer == nil {
		return nil, fmt.Errorf("importer not configured")
	}
	return s.importer.ImportFile(filePath)
}

// GetImportProgress retrieves the progress of an import
func (s *geoTerritoryService) GetImportProgress(fileName string) (*domain.ImportProgress, error) {
	if s.importer == nil {
		return nil, fmt.Errorf("importer not configured")
	}
	progress := s.importer.GetProgress(fileName)
	if progress == nil {
		return nil, fmt.Errorf("no import found for file: %s", fileName)
	}
	return progress, nil
}
