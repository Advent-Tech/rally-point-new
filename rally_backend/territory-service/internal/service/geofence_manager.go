package service

import (
	"encoding/json"
	"fmt"
	"math"

	"rally-point/territory-service/internal/domain"
)

type geofenceManager struct{}

// NewGeofenceManager creates a new geofence manager
func NewGeofenceManager() domain.GeofenceManager {
	return &geofenceManager{}
}

// GeoJSONGeometry represents a GeoJSON geometry
type GeoJSONGeometry struct {
	Type        string        `json:"type"`
	Coordinates [][][]float64 `json:"coordinates"`
}

// GeoJSONPolygon represents a GeoJSON polygon
type GeoJSONPolygon struct {
	Type     string          `json:"type"`
	Geometry GeoJSONGeometry `json:"geometry"`
}

// IsPointInTerritory checks if a point is inside a territory boundary
func (gm *geofenceManager) IsPointInTerritory(point domain.LocationPoint, boundary string) (bool, error) {
	// Parse GeoJSON boundary
	var polygon GeoJSONPolygon
	err := json.Unmarshal([]byte(boundary), &polygon)
	if err != nil {
		return false, fmt.Errorf("failed to parse boundary: %w", err)
	}

	if polygon.Geometry.Type != "Polygon" {
		return false, fmt.Errorf("unsupported geometry type: %s", polygon.Geometry.Type)
	}

	if len(polygon.Geometry.Coordinates) == 0 {
		return false, fmt.Errorf("empty polygon coordinates")
	}

	// Use the first ring (exterior ring) for point-in-polygon test
	ring := polygon.Geometry.Coordinates[0]
	return gm.pointInPolygon(point, ring), nil
}

// pointInPolygon uses the ray casting algorithm to determine if a point is inside a polygon
func (gm *geofenceManager) pointInPolygon(point domain.LocationPoint, polygon [][]float64) bool {
	x := point.Longitude
	y := point.Latitude
	n := len(polygon)
	inside := false

	p1x := polygon[0][0]
	p1y := polygon[0][1]

	for i := 1; i <= n; i++ {
		p2x := polygon[i%n][0]
		p2y := polygon[i%n][1]

		if y > math.Min(p1y, p2y) {
			if y <= math.Max(p1y, p2y) {
				if x <= math.Max(p1x, p2x) {
					var xinters float64
					if p1y != p2y {
						xinters = (y-p1y)*(p2x-p1x)/(p2y-p1y) + p1x
					}
					if p1x == p2x || x <= xinters {
						inside = !inside
					}
				}
			}
		}
		p1x = p2x
		p1y = p2y
	}

	return inside
}

// CalculateDistance calculates the distance between two points using Haversine formula
func (gm *geofenceManager) CalculateDistance(point1, point2 domain.LocationPoint) float64 {
	const earthRadius = 6371000 // Earth radius in meters

	// Convert degrees to radians
	lat1Rad := point1.Latitude * math.Pi / 180
	lat2Rad := point2.Latitude * math.Pi / 180
	deltaLatRad := (point2.Latitude - point1.Latitude) * math.Pi / 180
	deltaLonRad := (point2.Longitude - point1.Longitude) * math.Pi / 180

	a := math.Sin(deltaLatRad/2)*math.Sin(deltaLatRad/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
			math.Sin(deltaLonRad/2)*math.Sin(deltaLonRad/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadius * c
}

// ValidateBoundary validates a GeoJSON boundary
func (gm *geofenceManager) ValidateBoundary(boundary string) error {
	var polygon GeoJSONPolygon
	err := json.Unmarshal([]byte(boundary), &polygon)
	if err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}

	if polygon.Type != "Feature" && polygon.Type != "" {
		if polygon.Geometry.Type == "" {
			return fmt.Errorf("missing geometry type")
		}
	}

	if polygon.Geometry.Type != "Polygon" {
		return fmt.Errorf("only Polygon geometry is supported, got: %s", polygon.Geometry.Type)
	}

	if len(polygon.Geometry.Coordinates) == 0 {
		return fmt.Errorf("empty coordinates")
	}

	// Validate the first ring (exterior ring)
	ring := polygon.Geometry.Coordinates[0]
	if len(ring) < 4 {
		return fmt.Errorf("polygon ring must have at least 4 coordinates")
	}

	// Check if the ring is closed (first and last points are the same)
	first := ring[0]
	last := ring[len(ring)-1]
	if first[0] != last[0] || first[1] != last[1] {
		return fmt.Errorf("polygon ring must be closed (first and last coordinates must be the same)")
	}

	// Validate coordinate ranges
	for i, coord := range ring {
		if len(coord) < 2 {
			return fmt.Errorf("coordinate %d must have at least 2 values (longitude, latitude)", i)
		}

		lon := coord[0]
		lat := coord[1]

		if lon < -180 || lon > 180 {
			return fmt.Errorf("longitude %f at coordinate %d is out of range [-180, 180]", lon, i)
		}

		if lat < -90 || lat > 90 {
			return fmt.Errorf("latitude %f at coordinate %d is out of range [-90, 90]", lat, i)
		}
	}

	return nil
}
