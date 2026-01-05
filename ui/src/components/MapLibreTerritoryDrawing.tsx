import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Platform,
  ActivityIndicator,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, SPACING, RADIUS, TYPOGRAPHY } from '../constants/Colors';

// MapLibre GL imports - open-source successor to Mapbox GL
import Map, {
  Marker,
  Source,
  Layer,
  NavigationControl,
  ScaleControl,
  FullscreenControl,
} from 'react-map-gl';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';

// MapLibre GL - no API key needed, open source
const map = maplibregl;

interface Point {
  lat: number;
  lng: number;
}

interface MapLibreTerritoryDrawingProps {
  isDrawingMode: boolean;
  territoryName: string;
  onTerritoryNameChange: (name: string) => void;
  onPolygonDrawn: (coordinates: Array<{lat: number, lng: number}>) => void;
  onStopDrawing: () => void;
  territories: Array<{
    id: string;
    name: string;
    coordinates: Array<{lat: number, lng: number}>;
    color: string;
  }>;
  mapReady: boolean;
  onMapReady: () => void;
}

// MapLibre GL web component
const MapLibreWebMap: React.FC<MapLibreTerritoryDrawingProps> = ({
  isDrawingMode,
  territoryName,
  onPolygonDrawn,
  onStopDrawing,
  territories,
  onMapReady,
}) => {
  const [drawingPoints, setDrawingPoints] = useState<Point[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [viewState, setViewState] = useState({
    longitude: -77.0365,
    latitude: 38.8977,
    zoom: 13,
  });

  const mapRef = useRef<any>(null);

  useEffect(() => {
    onMapReady();
  }, [onMapReady]);

  const handleMapClick = (lng: number, lat: number) => {
    const newPoint: Point = { lat, lng };
    setDrawingPoints(prev => [...prev, newPoint]);
    setError(null);
    console.log('🗺️ MapLibre GL: Added point:', newPoint);
  };

  const handleUndoPoint = () => {
    setDrawingPoints(prev => prev.slice(0, -1));
    setError(null);
  };

  const handleClearAll = () => {
    setDrawingPoints([]);
    setError(null);
  };

  const handleFinishDrawing = () => {
    if (drawingPoints.length < 3) {
      Alert.alert('Error', 'Please add at least 3 points to create a territory');
      return;
    }

    const coordinates = drawingPoints.map(point => ({
      lat: point.lat,
      lng: point.lng,
    }));

    console.log('🗺️ MapLibre GL: Territory drawing completed with', coordinates.length, 'points');
    onPolygonDrawn(coordinates);
    setDrawingPoints([]);
    setError(null);
  };

  const handleCancelDrawing = () => {
    setDrawingPoints([]);
    setError(null);
    onStopDrawing();
  };

  // Convert drawing points to GeoJSON polygon
  const drawingPolygon = drawingPoints.length > 0 ? {
    type: 'Feature',
    geometry: {
      type: 'Polygon',
      coordinates: [[...drawingPoints.map(point => [point.lng, point.lat]), drawingPoints[0] ? [drawingPoints[0].lng, drawingPoints[0].lat] : []]]
    },
    properties: {}
  } : null;

  // Convert existing territories to GeoJSON
  const territoryPolygons = territories.map(territory => ({
    type: 'Feature',
    geometry: {
      type: 'Polygon',
      coordinates: [[...territory.coordinates.map(coord => [coord.lng, coord.lat]), territory.coordinates[0] ? [territory.coordinates[0].lng, territory.coordinates[0].lat] : []]]
    },
    properties: {
      id: territory.id,
      name: territory.name,
      color: territory.color,
    }
  }));

  return (
    <View style={styles.container}>
      {/* Header Controls */}
      <View style={styles.header}>
        <TouchableOpacity
          style={styles.cancelButton}
          onPress={handleCancelDrawing}
        >
          <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>
          {isDrawingMode 
            ? `Tap on map to add points (${drawingPoints.length} added)` 
            : "Viewing territories"
          }
        </Text>
        <TouchableOpacity
          style={[
            styles.finishButton,
            drawingPoints.length < 3 && styles.finishButtonDisabled
          ]}
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

      {/* MapLibre GL Map Container */}
      <View style={styles.mapContainer}>
        <Map
          ref={mapRef}
          {...viewState}
          onMove={(evt: any) => setViewState(evt.viewState)}
          onClick={(e: any) => {
            if (isDrawingMode) {
              const { lng, lat } = e.lngLat;
              handleMapClick(lng, lat);
            }
          }}
          style={styles.maplibreMap}
          mapStyle="https://api.maptiler.com/maps/streets-v2/style.json?key=F4M1q3nTzAcrBXZgA61h"
          mapLibre={maplibregl}
        >
          {/* Existing territories */}
          {territoryPolygons.map((polygon, index) => (
            <Source key={territories[index].id} type="geojson" data={polygon}>
              <Layer 
                type="fill"
                paint={{
                  'fill-color': territories[index].color,
                  'fill-opacity': 0.3,
                  'fill-outline-color': territories[index].color,
                }}
              />
            </Source>
          ))}

          {/* Current drawing polygon */}
          {drawingPolygon && (
            <Source type="geojson" data={drawingPolygon}>
              <Layer 
                type="fill"
                paint={{
                  'fill-color': COLORS.primary,
                  'fill-opacity': 0.5,
                  'fill-outline-color': COLORS.primary,
                }}
              />
            </Source>
          )}

          {/* Point markers */}
          {drawingPoints.map((point, index) => (
            <Marker
              key={index}
              longitude={point.lng}
              latitude={point.lat}
              anchor="center"
            >
              <View style={styles.maplibreMarker}>
                <Text style={styles.maplibreMarkerText}>{index + 1}</Text>
              </View>
            </Marker>
          ))}

          {/* Map controls */}
          <NavigationControl position="top-left" />
          <ScaleControl position="bottom-left" />
          <FullscreenControl position="top-right" />
        </Map>
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
            <Text style={[
              styles.controlButtonText,
              drawingPoints.length === 0 && styles.controlButtonTextDisabled
            ]}>
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
            <Text style={[
              styles.controlButtonText,
              drawingPoints.length === 0 && styles.controlButtonTextDisabled
            ]}>
              Clear
            </Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Instructions */}
      {isDrawingMode && (
        <View style={styles.instructionBox}>
          <MaterialIcons name="info" size={20} color={COLORS.info} />
          <Text style={styles.instructionText}>
            Click on the map to add boundary points. You need at least 3 points to create a territory.
          </Text>
        </View>
      )}
    </View>
  );
};

// Native fallback component
const NativeFallback: React.FC<MapLibreTerritoryDrawingProps> = (props) => {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={props.onStopDrawing}>
          <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>MapLibre GL</Text>
        <View style={{ width: 24 }} />
      </View>
      
      <View style={styles.fallbackContainer}>
        <MaterialIcons name="map" size={48} color={COLORS.text.secondary} />
        <Text style={styles.fallbackTitle}>Open Source Maps</Text>
        <Text style={styles.fallbackText}>
          MapLibre GL provides smooth, open-source mapping. Available on web browsers for the best territory creation experience.
        </Text>
        <TouchableOpacity 
          style={styles.fallbackButton}
          onPress={props.onStopDrawing}
        >
          <Text style={styles.fallbackButtonText}>Go Back</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

// Main component that chooses between web and native
const MapLibreTerritoryDrawing: React.FC<MapLibreTerritoryDrawingProps> = (props) => {
  if (Platform.OS === 'web') {
    return <MapLibreWebMap {...props} />;
  } else {
    return <NativeFallback {...props} />;
  }
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
    backgroundColor: COLORS.background.secondary,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  cancelButton: {
    padding: SPACING.sm,
  },
  finishButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
    backgroundColor: COLORS.primary,
  },
  finishButtonDisabled: {
    backgroundColor: COLORS.background.secondary,
  },
  headerTitle: {
    flex: 1,
    textAlign: 'center',
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginHorizontal: SPACING.sm,
  },
  mapContainer: {
    flex: 1,
    position: 'relative',
    minHeight: 400,
    backgroundColor: '#f0f0f0',
  },
  maplibreMap: {
    height: '100%',
    width: '100%',
  },
  maplibreMarker: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: COLORS.white,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 5,
  },
  maplibreMarkerText: {
    fontSize: 14,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.white,
  },
  errorBox: {
    flexDirection: 'row',
    backgroundColor: '#FEE2E2',
    padding: SPACING.md,
    margin: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
  },
  errorText: {
    flex: 1,
    fontSize: 14,
    color: COLORS.error,
    marginLeft: SPACING.sm,
  },
  drawingControls: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    padding: SPACING.md,
    backgroundColor: COLORS.background.secondary,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.default,
  },
  controlButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.primary,
  },
  controlButtonText: {
    marginLeft: SPACING.xs,
    fontSize: 14,
    color: COLORS.text.primary,
  },
  controlButtonTextDisabled: {
    color: COLORS.text.disabled,
  },
  instructionBox: {
    flexDirection: 'row',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    margin: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
  },
  instructionText: {
    flex: 1,
    fontSize: 14,
    color: COLORS.text.secondary,
    marginLeft: SPACING.sm,
    lineHeight: 20,
  },
  fallbackContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  fallbackTitle: {
    fontSize: 20,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  fallbackText: {
    fontSize: 16,
    color: COLORS.text.secondary,
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: SPACING.lg,
  },
  fallbackButton: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
  },
  fallbackButtonText: {
    color: COLORS.white,
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
});

export default MapLibreTerritoryDrawing;
