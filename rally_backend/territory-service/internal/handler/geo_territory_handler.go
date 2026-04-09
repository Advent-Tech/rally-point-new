package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

// GeoTerritoryHandler handles geo territory HTTP requests
type GeoTerritoryHandler struct {
	service domain.GeoTerritoryService
}

// NewGeoTerritoryHandler creates a new geo territory handler
func NewGeoTerritoryHandler(service domain.GeoTerritoryService) *GeoTerritoryHandler {
	return &GeoTerritoryHandler{
		service: service,
	}
}

// GetTerritoriesInBounds returns territories within geographic bounds as GeoJSON
// GET /api/geo/territories?bounds=minLng,minLat,maxLng,maxLat&limit=1000&zoom=10
func (h *GeoTerritoryHandler) GetTerritoriesInBounds(c *gin.Context) {
	boundsStr := c.Query("bounds")
	if boundsStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bounds parameter is required (format: minLng,minLat,maxLng,maxLat)"})
		return
	}

	parts := strings.Split(boundsStr, ",")
	if len(parts) != 4 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bounds must have 4 values: minLng,minLat,maxLng,maxLat"})
		return
	}

	minLng, err1 := strconv.ParseFloat(parts[0], 64)
	minLat, err2 := strconv.ParseFloat(parts[1], 64)
	maxLng, err3 := strconv.ParseFloat(parts[2], 64)
	maxLat, err4 := strconv.ParseFloat(parts[3], 64)

	if err1 != nil || err2 != nil || err3 != nil || err4 != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid bounds values"})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "1000"))
	zoom, _ := strconv.Atoi(c.DefaultQuery("zoom", "0"))

	bounds := domain.BoundsQuery{
		MinLng: minLng,
		MinLat: minLat,
		MaxLng: maxLng,
		MaxLat: maxLat,
		Limit:  limit,
		Zoom:   zoom,
	}

	geojson, err := h.service.GetTerritoriesInBounds(bounds)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, geojson)
}

// GetTerritoryByID returns a single territory by ID
// GET /api/geo/territories/:id
func (h *GeoTerritoryHandler) GetTerritoryByID(c *gin.Context) {
	idStr := c.Param("id")

	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	territory, err := h.service.GetTerritory(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "territory not found"})
		return
	}

	c.JSON(http.StatusOK, territory)
}

// GetTerritoryBySOLID returns a territory by SOLID
// GET /api/geo/territories/solid/:solid
func (h *GeoTerritoryHandler) GetTerritoryBySOLID(c *gin.Context) {
	solid := c.Param("solid")

	territory, err := h.service.GetTerritoryBySOLID(solid)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "territory not found"})
		return
	}

	c.JSON(http.StatusOK, territory)
}

// GetTerritoriesByEntity returns all territories for an entity
// GET /api/geo/territories/entity/:entityId
func (h *GeoTerritoryHandler) GetTerritoriesByEntity(c *gin.Context) {
	entityID := c.Param("entityId")

	territories, err := h.service.GetTerritoriesByEntity(entityID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"entity_id":   entityID,
		"territories": territories,
		"count":       len(territories),
	})
}

// GetTerritoriesAtPoint returns territories containing a point
// GET /api/geo/territories/at?lat=40.7128&lng=-74.0060
func (h *GeoTerritoryHandler) GetTerritoriesAtPoint(c *gin.Context) {
	latStr := c.Query("lat")
	lngStr := c.Query("lng")

	if latStr == "" || lngStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "lat and lng parameters are required"})
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid lat value"})
		return
	}

	lng, err := strconv.ParseFloat(lngStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid lng value"})
		return
	}

	territories, err := h.service.GetTerritoriesAtPoint(lat, lng)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"lat":         lat,
		"lng":         lng,
		"territories": territories,
		"count":       len(territories),
	})
}

// SearchTerritories searches for territories
// GET /api/geo/territories/search?q=church+name&union=Atlantic&state=NY&include_geometry=true
func (h *GeoTerritoryHandler) SearchTerritories(c *gin.Context) {
	query := domain.TerritorySearchQuery{
		Query:      c.Query("q"),
		Union:      c.Query("union"),
		Conference: c.Query("conference"),
		State:      c.Query("state"),
		City:       c.Query("city"),
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	includeGeometry := c.Query("include_geometry") == "true"
	query.Limit = limit
	query.Offset = offset
	query.IncludeGeometry = includeGeometry

	// Use geometry-enabled method if requested
	if includeGeometry {
		territories, err := h.service.SearchTerritoriesWithGeometry(query)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"territories": territories,
			"count":       len(territories),
			"limit":       limit,
			"offset":      offset,
		})
		return
	}

	territories, err := h.service.SearchTerritories(query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"territories": territories,
		"count":       len(territories),
		"limit":       limit,
		"offset":      offset,
	})
}

// ListTerritories lists territories with filters
// GET /api/geo/territories/list?union=Atlantic&conference=Greater+New+York&limit=50&include_geometry=true
func (h *GeoTerritoryHandler) ListTerritories(c *gin.Context) {
	filters := domain.TerritoryFilters{
		UnionName:  c.Query("union"),
		Conference: c.Query("conference"),
		State:      c.Query("state"),
		City:       c.Query("city"),
		EntityID:   c.Query("entity_id"),
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	includeGeometry := c.Query("include_geometry") == "true"
	filters.Limit = limit
	filters.Offset = offset
	filters.IncludeGeometry = includeGeometry

	// Use geometry-enabled method if requested
	if includeGeometry {
		territories, total, err := h.service.ListTerritoriesWithGeometry(filters)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"territories": territories,
			"total":       total,
			"count":       len(territories),
			"limit":       limit,
			"offset":      offset,
		})
		return
	}

	territories, total, err := h.service.ListTerritories(filters)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"territories": territories,
		"total":       total,
		"count":       len(territories),
		"limit":       limit,
		"offset":      offset,
	})
}

// GetChurchLocations returns church point locations
// GET /api/geo/churches?bounds=minLng,minLat,maxLng,maxLat
func (h *GeoTerritoryHandler) GetChurchLocations(c *gin.Context) {
	boundsStr := c.Query("bounds")

	var bounds *domain.BoundsQuery
	if boundsStr != "" {
		parts := strings.Split(boundsStr, ",")
		if len(parts) == 4 {
			minLng, _ := strconv.ParseFloat(parts[0], 64)
			minLat, _ := strconv.ParseFloat(parts[1], 64)
			maxLng, _ := strconv.ParseFloat(parts[2], 64)
			maxLat, _ := strconv.ParseFloat(parts[3], 64)
			bounds = &domain.BoundsQuery{
				MinLng: minLng,
				MinLat: minLat,
				MaxLng: maxLng,
				MaxLat: maxLat,
			}
		}
	}

	churches, err := h.service.GetChurchLocations(bounds)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"churches": churches,
		"count":    len(churches),
	})
}

// GetChurch returns a church by entity ID
// GET /api/geo/churches/:entityId
func (h *GeoTerritoryHandler) GetChurch(c *gin.Context) {
	entityID := c.Param("entityId")

	church, err := h.service.GetChurch(entityID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "church not found"})
		return
	}

	c.JSON(http.StatusOK, church)
}

// GetUnionStats returns statistics for all unions
// GET /api/geo/stats/unions
func (h *GeoTerritoryHandler) GetUnionStats(c *gin.Context) {
	stats, err := h.service.GetUnionStats()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"unions": stats,
		"count":  len(stats),
	})
}

// GetConferenceStats returns statistics for conferences in a union
// GET /api/geo/stats/conferences?union=Atlantic+Union
func (h *GeoTerritoryHandler) GetConferenceStats(c *gin.Context) {
	unionName := c.Query("union")
	if unionName == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "union parameter is required"})
		return
	}

	stats, err := h.service.GetConferenceStats(unionName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"union":       unionName,
		"conferences": stats,
		"count":       len(stats),
	})
}

// GetVectorTile returns a vector tile for map rendering
// GET /api/geo/tiles/:z/:x/:y.mvt
func (h *GeoTerritoryHandler) GetVectorTile(c *gin.Context) {
	z, err := strconv.Atoi(c.Param("z"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid z coordinate"})
		return
	}

	x, err := strconv.Atoi(c.Param("x"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid x coordinate"})
		return
	}

	// Remove .mvt extension if present
	yStr := strings.TrimSuffix(c.Param("y"), ".mvt")
	y, err := strconv.Atoi(yStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid y coordinate"})
		return
	}

	tile, err := h.service.GetVectorTile(z, x, y)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Set cache headers (tiles can be cached for a long time)
	c.Header("Content-Type", "application/vnd.mapbox-vector-tile")
	c.Header("Cache-Control", "public, max-age=86400") // 24 hours
	c.Header("Access-Control-Allow-Origin", "*")

	c.Data(http.StatusOK, "application/vnd.mapbox-vector-tile", tile)
}

// ImportGeoPackage triggers a GeoPackage import (admin only)
// POST /api/geo/import
func (h *GeoTerritoryHandler) ImportGeoPackage(c *gin.Context) {
	var req struct {
		FilePath string `json:"file_path" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	progress, err := h.service.ImportGeoPackage(req.FilePath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusAccepted, progress)
}

// GetImportProgress returns the progress of an import
// GET /api/geo/import/:fileName
func (h *GeoTerritoryHandler) GetImportProgress(c *gin.Context) {
	fileName := c.Param("fileName")

	progress, err := h.service.GetImportProgress(fileName)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, progress)
}

// CreateTerritory creates a new territory
// POST /api/geo/territories
func (h *GeoTerritoryHandler) CreateTerritory(c *gin.Context) {
	var req domain.CreateGeoTerritoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	territory, err := h.service.CreateTerritory(&req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, territory)
}

// UpdateTerritory updates an existing territory
// PUT /api/geo/territories/:id
func (h *GeoTerritoryHandler) UpdateTerritory(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	var req domain.UpdateGeoTerritoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	territory, err := h.service.UpdateTerritory(id, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, territory)
}

// DeleteTerritory deletes a territory
// DELETE /api/geo/territories/:id
func (h *GeoTerritoryHandler) DeleteTerritory(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid territory ID"})
		return
	}

	if err := h.service.DeleteTerritory(id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "territory deleted"})
}

// ValidateGeometry validates a GeoJSON geometry
// POST /api/geo/territories/validate
func (h *GeoTerritoryHandler) ValidateGeometry(c *gin.Context) {
	var req struct {
		Geometry json.RawMessage `json:"geometry" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := h.service.ValidateGeometry(req.Geometry)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// RegisterRoutes registers the geo territory routes
func (h *GeoTerritoryHandler) RegisterRoutes(router *gin.RouterGroup) {
	geo := router.Group("/geo")
	{
		// Territory endpoints
		geo.GET("/territories", h.GetTerritoriesInBounds)
		geo.GET("/territories/search", h.SearchTerritories)
		geo.GET("/territories/list", h.ListTerritories)
		geo.GET("/territories/at", h.GetTerritoriesAtPoint)
		geo.GET("/territories/:id", h.GetTerritoryByID)
		geo.GET("/territories/solid/:solid", h.GetTerritoryBySOLID)
		geo.GET("/territories/entity/:entityId", h.GetTerritoriesByEntity)

		// Territory CRUD
		geo.POST("/territories", h.CreateTerritory)
		geo.POST("/territories/validate", h.ValidateGeometry)
		geo.PUT("/territories/:id", h.UpdateTerritory)
		geo.DELETE("/territories/:id", h.DeleteTerritory)

		// Church endpoints
		geo.GET("/churches", h.GetChurchLocations)
		geo.GET("/churches/:entityId", h.GetChurch)

		// Statistics endpoints
		geo.GET("/stats/unions", h.GetUnionStats)
		geo.GET("/stats/conferences", h.GetConferenceStats)

		// Vector tiles
		geo.GET("/tiles/:z/:x/:y", h.GetVectorTile)

		// Import (admin only - should add auth middleware)
		geo.POST("/import", h.ImportGeoPackage)
		geo.GET("/import/:fileName", h.GetImportProgress)
	}
}
