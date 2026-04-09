# Geospatial Integration Strategy for Rally Point

## Overview

This document outlines the strategy for integrating GeoPackage, KMZ, and Shapefile territory data into Rally Point.

## Current Data Assets

- **8 GeoPackage files** (~1.7GB total) - Union territory boundaries
- **8 KMZ files** (~700MB total) - Same data in KML format

### Data Structure Per Territory
```
- fid: Unique feature ID
- geom: MULTIPOLYGON geometry
- SOLID: Territory ID (e.g., "E014258-G001")
- Entity: Church name
- EID: Entity/Church ID
- GID: Group/Territory ID within church
- Address, City, State, Zipcode, County
- Population, Housing (demographics)
- Union, Conference (organizational hierarchy)
- GEOID: Census block group ID
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA PIPELINE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   GeoPackage ──┐                                                │
│                ├──► Go Importer ──► PostGIS ──► Tile Server     │
│   KMZ/KML ────┘         │              │            │           │
│                         │              │            │           │
│                    Validation     Spatial        Vector         │
│                    & Transform    Indexes        Tiles          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         API LAYER                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   GET /api/territories?bounds=...     → GeoJSON features        │
│   GET /api/territories/:id            → Single territory        │
│   GET /api/territories/search?q=...   → Search by name/address  │
│   GET /api/tiles/{z}/{x}/{y}.mvt      → Vector tiles (MVT)      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FRONTEND (React Native)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Option A: react-native-maps + GeoJSON overlay                 │
│   Option B: react-native-mapbox-gl + Vector tiles (RECOMMENDED) │
│   Option C: WebView + Leaflet/MapLibre                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Backend - Data Import & Storage

### 1.1 PostgreSQL/PostGIS Schema

```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Territories table
CREATE TABLE territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fid INTEGER UNIQUE,
    solid VARCHAR(50) NOT NULL,

    -- Church/Entity info
    entity_name VARCHAR(255) NOT NULL,
    entity_id VARCHAR(50) NOT NULL,
    group_id VARCHAR(10),

    -- Location
    address TEXT,
    street_address VARCHAR(255),
    city VARCHAR(100),
    county VARCHAR(100),
    state VARCHAR(2),
    zipcode VARCHAR(10),

    -- Demographics
    population INTEGER,
    housing_units INTEGER,

    -- Organizational
    union_name VARCHAR(100),
    conference VARCHAR(100),

    -- Census
    geoid VARCHAR(20),

    -- Geometry (4326 = WGS84 lat/lng)
    geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Spatial index for fast geo queries
CREATE INDEX idx_territories_geom ON territories USING GIST(geom);

-- Other useful indexes
CREATE INDEX idx_territories_entity_id ON territories(entity_id);
CREATE INDEX idx_territories_union ON territories(union_name);
CREATE INDEX idx_territories_conference ON territories(conference);
CREATE INDEX idx_territories_state ON territories(state);
CREATE INDEX idx_territories_zipcode ON territories(zipcode);
```

### 1.2 Go Importer Service

Create a new service to import GeoPackage files:

```go
// territory-service/internal/importer/geopackage.go
package importer

import (
    "database/sql"
    "fmt"
    _ "github.com/mattn/go-sqlite3"
)

type GeoPackageImporter struct {
    targetDB *sql.DB
}

type Territory struct {
    FID        int
    SOLID      string
    Entity     string
    EID        string
    GID        string
    Address    string
    City       string
    State      string
    Zipcode    string
    County     string
    Population string
    Housing    string
    Union      string
    Conference string
    GEOID      string
    Geom       []byte // WKB geometry
}

func (i *GeoPackageImporter) ImportFile(gpkgPath string) error {
    // Open GeoPackage (SQLite)
    db, err := sql.Open("sqlite3", gpkgPath)
    if err != nil {
        return fmt.Errorf("failed to open geopackage: %w", err)
    }
    defer db.Close()

    // Get table name from gpkg_contents
    var tableName string
    err = db.QueryRow(`SELECT table_name FROM gpkg_contents LIMIT 1`).Scan(&tableName)
    if err != nil {
        return fmt.Errorf("failed to get table name: %w", err)
    }

    // Query all features with geometry as WKB
    query := fmt.Sprintf(`
        SELECT
            fid, SOLID, Entity, EID, GID,
            Address, City, State, Zipcode, County,
            Population, Housing, "Union", Conference, GEOID,
            ST_AsBinary(geom) as geom
        FROM "%s"
    `, tableName)

    rows, err := db.Query(query)
    if err != nil {
        return fmt.Errorf("failed to query features: %w", err)
    }
    defer rows.Close()

    // Batch insert into PostGIS
    for rows.Next() {
        var t Territory
        err := rows.Scan(
            &t.FID, &t.SOLID, &t.Entity, &t.EID, &t.GID,
            &t.Address, &t.City, &t.State, &t.Zipcode, &t.County,
            &t.Population, &t.Housing, &t.Union, &t.Conference, &t.GEOID,
            &t.Geom,
        )
        if err != nil {
            continue // Skip invalid rows
        }

        // Insert into PostGIS
        _, err = i.targetDB.Exec(`
            INSERT INTO territories (
                fid, solid, entity_name, entity_id, group_id,
                address, city, state, zipcode, county,
                population, housing_units, union_name, conference, geoid,
                geom
            ) VALUES (
                $1, $2, $3, $4, $5,
                $6, $7, $8, $9, $10,
                $11, $12, $13, $14, $15,
                ST_GeomFromWKB($16, 4326)
            )
            ON CONFLICT (fid) DO UPDATE SET
                entity_name = EXCLUDED.entity_name,
                geom = EXCLUDED.geom,
                updated_at = NOW()
        `, t.FID, t.SOLID, t.Entity, t.EID, t.GID,
           t.Address, t.City, t.State, t.Zipcode, t.County,
           t.Population, t.Housing, t.Union, t.Conference, t.GEOID,
           t.Geom)

        if err != nil {
            return fmt.Errorf("failed to insert territory: %w", err)
        }
    }

    return nil
}
```

### 1.3 Alternative: Use ogr2ogr (Simpler)

```bash
# Install GDAL (includes ogr2ogr)
# macOS: brew install gdal
# Ubuntu: apt install gdal-bin

# Import GeoPackage directly to PostGIS
ogr2ogr -f "PostgreSQL" \
  PG:"host=localhost dbname=rally_point user=rally_user password=rally_pass" \
  "/path/to/Union_Atlantic Union.gpkg" \
  -nln territories \
  -append \
  -t_srs EPSG:4326
```

---

## Phase 2: API Layer

### 2.1 Territory Service Endpoints

```go
// GET /api/territories?bounds=minLng,minLat,maxLng,maxLat
func (h *TerritoryHandler) GetTerritoriesInBounds(c *gin.Context) {
    bounds := c.Query("bounds") // "minLng,minLat,maxLng,maxLat"

    // Parse bounds
    parts := strings.Split(bounds, ",")
    minLng, minLat, maxLng, maxLat := parts[0], parts[1], parts[2], parts[3]

    // Query with spatial filter
    query := `
        SELECT id, solid, entity_name, entity_id,
               ST_AsGeoJSON(geom) as geometry
        FROM territories
        WHERE ST_Intersects(
            geom,
            ST_MakeEnvelope($1, $2, $3, $4, 4326)
        )
        LIMIT 1000
    `

    // Return as GeoJSON FeatureCollection
    features := []GeoJSONFeature{}
    // ... execute query and build response

    c.JSON(200, GeoJSONFeatureCollection{
        Type:     "FeatureCollection",
        Features: features,
    })
}

// GET /api/territories/search?q=church+name
func (h *TerritoryHandler) SearchTerritories(c *gin.Context) {
    query := c.Query("q")

    results, _ := h.repo.SearchByName(query)
    c.JSON(200, results)
}

// GET /api/territories/:id
func (h *TerritoryHandler) GetTerritory(c *gin.Context) {
    id := c.Param("id")

    territory, _ := h.repo.GetByID(id)
    c.JSON(200, territory)
}
```

### 2.2 Vector Tiles (For Large Datasets)

For 200k+ polygons, use vector tiles instead of raw GeoJSON:

```go
// GET /api/tiles/{z}/{x}/{y}.mvt
func (h *TerritoryHandler) GetVectorTile(c *gin.Context) {
    z := c.Param("z")
    x := c.Param("x")
    y := c.Param("y")

    // Use PostGIS ST_AsMVT for vector tiles
    query := `
        WITH bounds AS (
            SELECT ST_TileEnvelope($1, $2, $3) AS geom
        ),
        mvt AS (
            SELECT ST_AsMVTGeom(
                t.geom,
                bounds.geom,
                4096, 64, true
            ) AS geom,
            t.id, t.entity_name, t.solid
            FROM territories t, bounds
            WHERE ST_Intersects(t.geom, bounds.geom)
        )
        SELECT ST_AsMVT(mvt.*, 'territories', 4096, 'geom')
        FROM mvt
    `

    var tile []byte
    h.db.QueryRow(query, z, x, y).Scan(&tile)

    c.Header("Content-Type", "application/vnd.mapbox-vector-tile")
    c.Data(200, "application/vnd.mapbox-vector-tile", tile)
}
```

---

## Phase 3: Frontend Integration

### Option A: react-native-maps + GeoJSON (Simple, Limited Scale)

Good for < 5,000 polygons visible at once.

```typescript
// components/TerritoryMap.tsx
import React, { useEffect, useState } from 'react';
import MapView, { Polygon, PROVIDER_GOOGLE } from 'react-native-maps';

interface Territory {
  id: string;
  name: string;
  coordinates: Array<{ latitude: number; longitude: number }>;
}

export const TerritoryMap: React.FC = () => {
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [region, setRegion] = useState({
    latitude: 40.7128,
    longitude: -74.0060,
    latitudeDelta: 0.5,
    longitudeDelta: 0.5,
  });

  const loadTerritories = async (bounds: string) => {
    const response = await fetch(
      `${API_URL}/api/territories?bounds=${bounds}`
    );
    const geojson = await response.json();

    // Convert GeoJSON to react-native-maps format
    const converted = geojson.features.map((f: any) => ({
      id: f.properties.id,
      name: f.properties.entity_name,
      coordinates: f.geometry.coordinates[0][0].map(([lng, lat]: number[]) => ({
        latitude: lat,
        longitude: lng,
      })),
    }));

    setTerritories(converted);
  };

  const onRegionChange = (newRegion: Region) => {
    setRegion(newRegion);
    const bounds = [
      newRegion.longitude - newRegion.longitudeDelta,
      newRegion.latitude - newRegion.latitudeDelta,
      newRegion.longitude + newRegion.longitudeDelta,
      newRegion.latitude + newRegion.latitudeDelta,
    ].join(',');
    loadTerritories(bounds);
  };

  return (
    <MapView
      style={{ flex: 1 }}
      provider={PROVIDER_GOOGLE}
      region={region}
      onRegionChangeComplete={onRegionChange}
    >
      {territories.map((territory) => (
        <Polygon
          key={territory.id}
          coordinates={territory.coordinates}
          strokeColor="#3b82f6"
          fillColor="rgba(59, 130, 246, 0.3)"
          strokeWidth={1}
          tappable
          onPress={() => console.log('Selected:', territory.name)}
        />
      ))}
    </MapView>
  );
};
```

### Option B: @rnmapbox/maps + Vector Tiles (RECOMMENDED)

Best for large datasets. Uses Mapbox GL Native.

```bash
npm install @rnmapbox/maps
```

```typescript
// components/TerritoryMapGL.tsx
import React from 'react';
import Mapbox, { MapView, VectorSource, FillLayer, LineLayer } from '@rnmapbox/maps';

Mapbox.setAccessToken('YOUR_MAPBOX_TOKEN');

export const TerritoryMapGL: React.FC = () => {
  return (
    <MapView style={{ flex: 1 }}>
      <VectorSource
        id="territories"
        url="http://localhost:8080/api/tiles/{z}/{x}/{y}.mvt"
        minZoomLevel={5}
        maxZoomLevel={18}
      >
        <FillLayer
          id="territory-fill"
          sourceLayerID="territories"
          style={{
            fillColor: 'rgba(59, 130, 246, 0.3)',
            fillOutlineColor: '#3b82f6',
          }}
        />
        <LineLayer
          id="territory-outline"
          sourceLayerID="territories"
          style={{
            lineColor: '#3b82f6',
            lineWidth: 1,
          }}
        />
      </VectorSource>
    </MapView>
  );
};
```

### Option C: WebView + MapLibre (Fallback)

If native maps have issues:

```typescript
// components/TerritoryWebMap.tsx
import React from 'react';
import { WebView } from 'react-native-webview';

export const TerritoryWebMap: React.FC = () => {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <link href="https://unpkg.com/maplibre-gl/dist/maplibre-gl.css" rel="stylesheet" />
      <script src="https://unpkg.com/maplibre-gl/dist/maplibre-gl.js"></script>
      <style>
        body { margin: 0; }
        #map { width: 100vw; height: 100vh; }
      </style>
    </head>
    <body>
      <div id="map"></div>
      <script>
        const map = new maplibregl.Map({
          container: 'map',
          style: 'https://demotiles.maplibre.org/style.json',
          center: [-74.0060, 40.7128],
          zoom: 8
        });

        map.on('load', () => {
          map.addSource('territories', {
            type: 'vector',
            tiles: ['http://localhost:8080/api/tiles/{z}/{x}/{y}.mvt']
          });

          map.addLayer({
            id: 'territory-fill',
            type: 'fill',
            source: 'territories',
            'source-layer': 'territories',
            paint: {
              'fill-color': 'rgba(59, 130, 246, 0.3)',
              'fill-outline-color': '#3b82f6'
            }
          });
        });
      </script>
    </body>
    </html>
  `;

  return <WebView source={{ html }} style={{ flex: 1 }} />;
};
```

---

## Phase 4: Performance Optimization

### 4.1 Geometry Simplification

For overview zooms, simplify polygons:

```sql
-- Create simplified geometries for different zoom levels
ALTER TABLE territories ADD COLUMN geom_simplified GEOMETRY(MULTIPOLYGON, 4326);

UPDATE territories
SET geom_simplified = ST_Simplify(geom, 0.001);

-- Use in queries based on zoom
SELECT
  CASE
    WHEN $1 < 10 THEN ST_AsGeoJSON(geom_simplified)
    ELSE ST_AsGeoJSON(geom)
  END as geometry
FROM territories
```

### 4.2 Clustering

For point-based views (church locations):

```sql
-- Create church locations table (one point per church)
CREATE TABLE church_locations AS
SELECT DISTINCT ON (entity_id)
    entity_id,
    entity_name,
    ST_Centroid(ST_Collect(geom)) as location,
    COUNT(*) as territory_count,
    SUM(population::integer) as total_population
FROM territories
GROUP BY entity_id, entity_name;
```

### 4.3 Caching

```go
// Use Redis for tile caching
func (h *TerritoryHandler) GetVectorTile(c *gin.Context) {
    cacheKey := fmt.Sprintf("tile:%s:%s:%s", z, x, y)

    // Check cache first
    cached, err := h.redis.Get(ctx, cacheKey).Bytes()
    if err == nil {
        c.Data(200, "application/vnd.mapbox-vector-tile", cached)
        return
    }

    // Generate tile...
    tile := generateTile(z, x, y)

    // Cache for 1 hour
    h.redis.Set(ctx, cacheKey, tile, time.Hour)

    c.Data(200, "application/vnd.mapbox-vector-tile", tile)
}
```

---

## Implementation Roadmap

### Week 1: Data Pipeline
- [ ] Set up PostGIS in Docker
- [ ] Create territories table with spatial indexes
- [ ] Build GeoPackage importer (or use ogr2ogr)
- [ ] Import all Union data

### Week 2: API Layer
- [ ] Create territory-service
- [ ] Implement bounds-based GeoJSON endpoint
- [ ] Implement vector tile endpoint
- [ ] Add search endpoint

### Week 3: Frontend Integration
- [ ] Evaluate @rnmapbox/maps vs react-native-maps
- [ ] Build TerritoryMap component
- [ ] Implement territory selection
- [ ] Connect to delivery tracking

### Week 4: Optimization
- [ ] Add geometry simplification
- [ ] Implement tile caching
- [ ] Performance testing with full dataset
- [ ] Mobile optimization

---

## Quick Start Commands

```bash
# 1. Add PostGIS to docker-compose
# Add to postgres service:
#   image: postgis/postgis:15-3.3

# 2. Import a GeoPackage file
docker exec -it rally_postgres ogr2ogr \
  -f "PostgreSQL" \
  PG:"dbname=rally_point user=rally_user" \
  "/data/Union_Atlantic Union.gpkg" \
  -nln territories \
  -t_srs EPSG:4326

# 3. Verify import
docker exec -it rally_postgres psql -U rally_user -d rally_point \
  -c "SELECT COUNT(*), union_name FROM territories GROUP BY union_name;"
```

---

## Resources

- [PostGIS Documentation](https://postgis.net/docs/)
- [GeoPackage Specification](https://www.geopackage.org/)
- [@rnmapbox/maps](https://github.com/rnmapbox/maps)
- [MapLibre GL JS](https://maplibre.org/)
- [Vector Tiles Specification](https://github.com/mapbox/vector-tile-spec)
