import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, SPACING, RADIUS, TYPOGRAPHY } from '../constants/Colors';
import maplibregl, { Map as MapLibreMap, Marker as MapLibreMarker } from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';

// Inject CSS for drawing markers if running in a browser
if (typeof document !== 'undefined') {
  const style = document.createElement('style');
  style.textContent = `
    .maplibre-drawing-marker {
      background: linear-gradient(135deg, #007AFF 0%, #4c1d95 100%);
      border: 3px solid white;
      border-radius: 50%;
      width: 40px;
      height: 40px;
      display: flex !important;
      align-items: center !important;
      justify-content: center !important;
      color: white;
      font-weight: 700;
      font-size: 16px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.5);
      pointer-events: none;
      z-index: 10000 !important;
      position: absolute !important;
      transform: translate(-50%, -50%) !important;
    }
    .maplibre-drawing-marker::after {
      content: '';
      position: absolute;
      bottom: -8px;
      left: 50%;
      transform: translateX(-50%);
      width: 0;
      height: 0;
      border-left: 6px solid transparent;
      border-right: 6px solid transparent;
      border-top: 8px solid white;
    }
    .maplibregl-marker {
      z-index: 10000 !important;
    }
    .maplibregl-marker canvas {
      display: none !important;
    }
  `;
  document.head.appendChild(style);
}

interface Point {
  lat: number;
  lng: number;
}

interface Territory {
  id: string;
  name: string;
  coordinates: Array<{ lat: number; lng: number }>;
  color: string;
}

interface ModernTerritoryDrawingProps {
  isDrawingMode: boolean;
  territoryName: string;
  onTerritoryNameChange: (name: string) => void;
  onPolygonDrawn: (coordinates: Array<{ lat: number; lng: number }>) => void;
  onStopDrawing: () => void;
  territories?: Territory[];
  onMapReady: () => void;
  onSaveTerritory?: () => void;
}

const TERRITORY_SOURCE_ID = 'drawing-territories';
const TERRITORY_FILL_LAYER_ID = 'drawing-territories-fill';
const TERRITORY_OUTLINE_LAYER_ID = 'drawing-territories-outline';
const DRAWING_SOURCE_ID = 'current-drawing';
const DRAWING_FILL_LAYER_ID = 'current-drawing-fill';
const DRAWING_OUTLINE_LAYER_ID = 'current-drawing-outline';

// Helper function to check if polygon self-intersects
const doesPolygonSelfIntersect = (points: Point[]): boolean => {
  if (points.length < 4) return false; // Need at least 4 points (3 + closing point)
  
  // Convert to array of coordinates for easier calculation
  const coords = points.map(p => [p.lng, p.lat]);
  
  // Check each edge against every other non-adjacent edge
  for (let i = 0; i < coords.length - 1; i++) {
    for (let j = i + 2; j < coords.length - 1; j++) {
      // Skip adjacent edges and the first/last edge
      if (j === i + 1 || (i === 0 && j === coords.length - 2)) continue;
      
      if (doLinesIntersect(coords[i], coords[i + 1], coords[j], coords[j + 1])) {
        return true;
      }
    }
  }
  return false;
};

// Helper function to check if two line segments intersect
const doLinesIntersect = (p1: number[], p2: number[], p3: number[], p4: number[]): boolean => {
  const ccw = (A: number[], B: number[], C: number[]) => {
    return (C[1] - A[1]) * (B[0] - A[0]) > (B[1] - A[1]) * (C[0] - A[0]);
  };
  
  return ccw(p1, p3, p4) !== ccw(p2, p3, p4) && ccw(p1, p2, p3) !== ccw(p1, p2, p4);
};

const ModernTerritoryDrawing: React.FC<ModernTerritoryDrawingProps> = ({
  isDrawingMode,
  territoryName,
  onTerritoryNameChange,
  onPolygonDrawn,
  onStopDrawing,
  territories = [],
  onMapReady,
  onSaveTerritory,
}) => {
  const [drawingPoints, setDrawingPoints] = useState<Point[]>([]);
  const [error, setError] = useState<string | null>(null);

  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const markersRef = useRef<MapLibreMarker[]>([]);
  const isDrawingModeRef = useRef<boolean>(isDrawingMode);

  // Keep ref in sync so click handler sees latest drawing mode
  useEffect(() => {
    isDrawingModeRef.current = isDrawingMode;
  }, [isDrawingMode]);

  // Default center: first territory or Washington DC (lng, lat)
  const defaultCenter: [number, number] =
    territories.length > 0 && territories[0].coordinates[0]
      ? [
          territories[0].coordinates[0].lng,
          territories[0].coordinates[0].lat,
        ]
      : [-77.0365, 38.8977];

  const buildTerritoriesGeoJSON = (
    items: ModernTerritoryDrawingProps['territories'],
  ): GeoJSON.FeatureCollection => {
    const features: GeoJSON.Feature[] = (items || [])
      .filter((t) => t.coordinates && t.coordinates.length >= 3)
      .map((t) => {
        const coords = t.coordinates.map((c) => [c.lng, c.lat]);
        if (coords.length > 0) {
          coords.push([coords[0][0], coords[0][1]]);
        }
        return {
          type: 'Feature',
          geometry: {
            type: 'Polygon',
            coordinates: [coords],
          },
          properties: {
            id: t.id,
            name: t.name,
            color: t.color,
          },
        } as GeoJSON.Feature;
      });

    return {
      type: 'FeatureCollection',
      features,
    } as GeoJSON.FeatureCollection;
  };

  const updateTerritoriesOnMap = (
    map: MapLibreMap,
    items: ModernTerritoryDrawingProps['territories'],
  ) => {
    const data = buildTerritoriesGeoJSON(items);
    const existingSource = map.getSource(TERRITORY_SOURCE_ID) as
      | maplibregl.GeoJSONSource
      | undefined;

    if (existingSource) {
      existingSource.setData(data as any);
      return;
    }

    map.addSource(TERRITORY_SOURCE_ID, {
      type: 'geojson',
      data: data as any,
    });

    map.addLayer({
      id: TERRITORY_FILL_LAYER_ID,
      type: 'fill',
      source: TERRITORY_SOURCE_ID,
      paint: {
        'fill-color': ['get', 'color'],
        'fill-opacity': 0.3,
      },
    });

    map.addLayer({
      id: TERRITORY_OUTLINE_LAYER_ID,
      type: 'line',
      source: TERRITORY_SOURCE_ID,
      paint: {
        'line-color': ['get', 'color'],
        'line-width': 2,
      },
    });
  };

  const buildDrawingGeoJSON = (points: Point[]): GeoJSON.FeatureCollection => {
    if (!points || points.length < 3) {
      return {
        type: 'FeatureCollection',
        features: [],
      } as GeoJSON.FeatureCollection;
    }

    const coords = points.map((p) => [p.lng, p.lat]);
    coords.push([coords[0][0], coords[0][1]]);

    const feature: GeoJSON.Feature = {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [coords],
      },
      properties: {},
    };

    return {
      type: 'FeatureCollection',
      features: [feature],
    } as GeoJSON.FeatureCollection;
  };

  const updateDrawingOnMap = (map: MapLibreMap, points: Point[]) => {
    const data = buildDrawingGeoJSON(points);
    const existingSource = map.getSource(DRAWING_SOURCE_ID) as
      | maplibregl.GeoJSONSource
      | undefined;

    if (existingSource) {
      existingSource.setData(data as any);
      return;
    }

    map.addSource(DRAWING_SOURCE_ID, {
      type: 'geojson',
      data: data as any,
    });

    map.addLayer({
      id: DRAWING_FILL_LAYER_ID,
      type: 'fill',
      source: DRAWING_SOURCE_ID,
      paint: {
        'fill-color': COLORS.primary,
        'fill-opacity': 0.5,
      },
    });

    map.addLayer({
      id: DRAWING_OUTLINE_LAYER_ID,
      type: 'line',
      source: DRAWING_SOURCE_ID,
      paint: {
        'line-color': COLORS.primary,
        'line-width': 3,
      },
    });
  };

  const updateDrawingMarkers = (map: MapLibreMap, points: Point[]) => {
    // Clear old markers
    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    console.log('📍 Updating drawing markers for points:', points.length);

    points.forEach((p, index) => {
      const el = document.createElement('div');
      el.className = 'maplibre-drawing-marker';
      el.textContent = String(index + 1);
      el.style.cssText = `
        background: linear-gradient(135deg, #007AFF 0%, #4c1d95 100%);
        border: 3px solid white;
        border-radius: 50%;
        width: 40px;
        height: 40px;
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        color: white;
        font-weight: 700;
        font-size: 16px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.5);
        pointer-events: none;
        z-index: 10000 !important;
        position: absolute !important;
        transform: translate(-50%, -50%) !important;
      `;

      console.log(`📍 Creating marker ${index + 1} at:`, p.lat, p.lng);

      const marker = new maplibregl.Marker({ 
        element: el,
        anchor: 'center'
      })
        .setLngLat([p.lng, p.lat])
        .addTo(map);

      markersRef.current.push(marker);
    });
  };

  // Initialize MapLibre map once
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) {
      return;
    }

    const styleUrl = 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

    const map = new maplibregl.Map({
      container: mapContainerRef.current,
      style: styleUrl,
      center: defaultCenter,
      zoom: 13,
    });

    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-left');
    map.addControl(new maplibregl.ScaleControl({}), 'bottom-left');

    mapRef.current = map;

    map.on('load', () => {
      updateTerritoriesOnMap(map, territories);
      updateDrawingOnMap(map, drawingPoints);
      updateDrawingMarkers(map, drawingPoints);
      onMapReady();
    });

    map.on('click', (e) => {
      if (!isDrawingModeRef.current) {
        console.log('🖱️ Map clicked but not in drawing mode');
        return;
      }
      
      const { lng, lat } = e.lngLat;
      console.log('🖱️ Map clicked in drawing mode at:', lng, lat);
      
      const newPoint: Point = { lat, lng };
      
      setDrawingPoints((prev) => {
        const updated = [...prev, newPoint];
        
        // Check for self-intersection if we have enough points
        if (updated.length >= 4) {
          if (doesPolygonSelfIntersect(updated)) {
            console.warn('⚠️ Polygon would self-intersect');
            setError('⚠️ This would create a self-intersecting polygon. Please choose a different point.');
            return prev; // Don't add the point
          }
        }
        
        console.log('📍 Drawing points updated:', updated.length);
        setError(null); // Clear any previous errors
        return updated;
      });
    });

    return () => {
      markersRef.current.forEach((m) => m.remove());
      markersRef.current = [];
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Update territories when they change
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (!map.isStyleLoaded()) {
      map.once('load', () => updateTerritoriesOnMap(map, territories));
      return;
    }

    updateTerritoriesOnMap(map, territories);
  }, [territories]);

  // Update drawing polygon and markers when points change
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (!map.isStyleLoaded()) {
      map.once('load', () => {
        updateDrawingOnMap(map, drawingPoints);
        updateDrawingMarkers(map, drawingPoints);
      });
      return;
    }

    updateDrawingOnMap(map, drawingPoints);
    updateDrawingMarkers(map, drawingPoints);
  }, [drawingPoints]);

  const handleUndoPoint = () => {
    setDrawingPoints((prev) => prev.slice(0, -1));
    setError(null);
  };

  const handleClearAll = () => {
    setDrawingPoints([]);
    setError(null);
  };

  const handleFinishDrawing = () => {
    if (drawingPoints.length < 3) {
      setError('⚠️ At least 3 points are required to create a territory');
      return;
    }
    
    // Final validation for self-intersection
    if (doesPolygonSelfIntersect(drawingPoints)) {
      setError('⚠️ The polygon self-intersects. Please redraw to create a valid territory.');
      return;
    }
    
    console.log('🏁 Finishing territory drawing with', drawingPoints.length, 'points');
    onPolygonDrawn(drawingPoints);
    setError(null);
    
    // Call save territory callback if provided
    if (onSaveTerritory) {
      onSaveTerritory();
    }
  };

  const handleCancelDrawing = () => {
    setDrawingPoints([]);
    setError(null);
    onStopDrawing();
  };

  return (
    <View style={styles.container}>
      {/* Header Controls */}
      <View style={styles.header}>
        <TouchableOpacity style={styles.cancelButton} onPress={handleCancelDrawing}>
          <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>
          {isDrawingMode
            ? `Tap map to add points (${drawingPoints.length} added)`
            : 'Viewing territories'}
        </Text>
        <TouchableOpacity
          style={[styles.finishButton, drawingPoints.length < 3 && styles.finishButtonDisabled]}
          onPress={handleFinishDrawing}
          disabled={drawingPoints.length < 3}
        >
          <MaterialIcons
            name="check"
            size={24}
            color={drawingPoints.length < 3 ? COLORS.text.disabled : COLORS.white}
          />
        </TouchableOpacity>
      </View>

      {/* Drawing Mode Indicator */}
      {isDrawingMode && (
        <View style={styles.drawingModeIndicator}>
          <View style={styles.drawingModeDot} />
          <Text style={styles.drawingModeText}>Drawing Mode Active</Text>
          <Text style={styles.pointCount}>{drawingPoints.length} points</Text>
        </View>
      )}

      {/* MapLibre GL Map Container */}
      <View style={styles.mapContainer}>
        <div ref={mapContainerRef} style={styles.mapWrapper as any} />
      </View>

      {/* Error Display */}
      {error && (
        <View style={styles.errorBox}>
          <MaterialIcons name="error" size={20} color={COLORS.error} />
          <Text style={styles.errorText}>{error}</Text>
        </View>
      )}

      {/* Drawing Controls */}
      {isDrawingMode && (
        <View style={styles.drawingControls}>
          <TouchableOpacity
            style={styles.controlButton}
            onPress={handleUndoPoint}
            disabled={drawingPoints.length === 0}
          >
            <MaterialIcons
              name="undo"
              size={20}
              color={drawingPoints.length === 0 ? COLORS.text.disabled : COLORS.primary}
            />
            <Text
              style={[
                styles.controlButtonText,
                drawingPoints.length === 0 && styles.controlButtonTextDisabled,
              ]}
            >
              Undo
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.controlButton}
            onPress={handleClearAll}
            disabled={drawingPoints.length === 0}
          >
            <MaterialIcons
              name="clear"
              size={20}
              color={drawingPoints.length === 0 ? COLORS.text.disabled : COLORS.error}
            />
            <Text
              style={[
                styles.controlButtonText,
                drawingPoints.length === 0 && styles.controlButtonTextDisabled,
              ]}
            >
              Clear
            </Text>
          </TouchableOpacity>

          {drawingPoints.length >= 3 && onSaveTerritory && (
            <TouchableOpacity
              style={[styles.controlButton, styles.saveButton]}
              onPress={handleFinishDrawing}
            >
              <MaterialIcons
                name="save"
                size={20}
                color={COLORS.white}
              />
              <Text style={styles.saveButtonText}>Save Territory</Text>
            </TouchableOpacity>
          )}
        </View>
      )}

      {/* Instructions */}
      {isDrawingMode && (
        <View style={styles.instructionBox}>
          <MaterialIcons name="touch-app" size={20} color={COLORS.info} />
          <Text style={styles.instructionText}>
            {drawingPoints.length === 0 
              ? "Tap on the map to add the first boundary point"
              : drawingPoints.length < 3
              ? `Add ${3 - drawingPoints.length} more point${3 - drawingPoints.length > 1 ? 's' : ''} to complete the territory`
              : "Territory complete! You can add more points or finish."
            }
          </Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: SPACING.md,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 3,
  },
  cancelButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
    backgroundColor: COLORS.background.secondary,
  },
  finishButton: {
    padding: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.sm,
    backgroundColor: COLORS.primary,
    shadowColor: COLORS.primary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 3,
  },
  finishButtonDisabled: {
    backgroundColor: COLORS.background.disabled,
    shadowOpacity: 0,
    elevation: 0,
  },
  headerTitle: {
    flex: 1,
    textAlign: 'center',
    fontSize: 18,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginHorizontal: SPACING.sm,
  },
  mapContainer: {
    flex: 1,
    position: 'relative',
  },
  mapWrapper: {
    width: '100%',
    height: '100%',
  },
  errorBox: {
    position: 'absolute',
    top: SPACING.md,
    left: SPACING.md,
    right: SPACING.md,
    backgroundColor: COLORS.error,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 5,
    zIndex: 1000,
  },
  errorText: {
    color: COLORS.white,
    marginLeft: SPACING.sm,
    fontSize: 14,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  drawingControls: {
    position: 'absolute',
    bottom: SPACING.lg,
    left: SPACING.md,
    right: SPACING.md,
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: 'white',
    padding: SPACING.md,
    borderRadius: RADIUS.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 8,
  },
  controlButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.secondary,
    minWidth: 80,
    justifyContent: 'center',
  },
  controlButtonText: {
    marginLeft: SPACING.xs,
    fontSize: 14,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  controlButtonTextDisabled: {
    color: COLORS.text.disabled,
  },
  saveButton: {
    backgroundColor: COLORS.success,
    borderColor: COLORS.success,
  },
  saveButtonText: {
    color: COLORS.white,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
  instructionBox: {
    position: 'absolute',
    top: SPACING.md,
    left: SPACING.md,
    right: SPACING.md,
    backgroundColor: COLORS.info,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 5,
  },
  instructionText: {
    color: COLORS.white,
    marginLeft: SPACING.sm,
    fontSize: 14,
    fontWeight: TYPOGRAPHY.weights.medium,
    flex: 1,
  },
  drawingModeIndicator: {
    position: 'absolute',
    top: SPACING.md,
    left: SPACING.md,
    right: SPACING.md,
    backgroundColor: 'rgba(76, 29, 149, 0.9)',
    padding: SPACING.sm,
    borderRadius: RADIUS.md,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 5,
    zIndex: 1000,
  },
  drawingModeDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#4ade80',
    marginRight: SPACING.sm,
  },
  drawingModeText: {
    color: COLORS.white,
    fontSize: 14,
    fontWeight: TYPOGRAPHY.weights.semibold,
    flex: 1,
  },
  pointCount: {
    color: COLORS.white,
    fontSize: 12,
    fontWeight: TYPOGRAPHY.weights.medium,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    paddingHorizontal: SPACING.xs,
    paddingVertical: 2,
    borderRadius: RADIUS.sm,
  },
});

export default ModernTerritoryDrawing;
