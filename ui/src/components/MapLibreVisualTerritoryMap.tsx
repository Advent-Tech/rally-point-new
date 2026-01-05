import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
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

interface TerritoryPoint {
  lat: number;
  lng: number;
}

interface Territory {
  id: string;
  name: string;
  description?: string;
  coordinates: TerritoryPoint[];
  color: string;
}

interface MapLibreVisualTerritoryMapProps {
  territories: Territory[];
  onTerritoryPress?: (territory: Territory) => void;
  showUserLocation?: boolean;
  userLocation?: {
    latitude: number;
    longitude: number;
  } | null;
  style?: any;
}

// MapLibre GL web component
const MapLibreWebMap: React.FC<MapLibreVisualTerritoryMapProps> = ({
  territories,
  onTerritoryPress,
  showUserLocation,
  userLocation,
  style,
}) => {
  // Default to Washington DC area, or center on territories
  const [viewState, setViewState] = useState({
    longitude: territories.length > 0 
      ? territories[0].coordinates[0]?.lng || -77.0365
      : -77.0365,
    latitude: territories.length > 0 
      ? territories[0].coordinates[0]?.lat || 38.8977
      : 38.8977,
    zoom: 13,
  });

  const handleTerritoryClick = (territory: Territory) => {
    if (onTerritoryPress) {
      onTerritoryPress(territory);
    }
  };

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
    <View style={[styles.container, style]}>
      <Map
        {...viewState}
        onMove={(evt: any) => setViewState(evt.viewState)}
        style={styles.maplibreMap}
        mapStyle="https://api.maptiler.com/maps/streets-v2/style.json?key=F4M1q3nTzAcrBXZgA61h"
        mapLibre={maplibregl}
      >
        {/* Territory polygons */}
        {territoryPolygons.map((polygon, index) => (
          <Source key={territories[index].id} type="geojson" data={polygon}>
            <Layer 
              type="fill"
              paint={{
                'fill-color': territories[index].color,
                'fill-opacity': 0.3,
                'fill-outline-color': territories[index].color,
              }}
              onClick={() => handleTerritoryClick(territories[index])}
            />
          </Source>
        ))}

        {/* User location marker */}
        {showUserLocation && userLocation && (
          <Marker
            longitude={userLocation.longitude}
            latitude={userLocation.latitude}
            anchor="center"
          >
            <View style={styles.userLocationMarker}>
              <MaterialIcons name="location-on" size={20} color={COLORS.white} />
            </View>
          </Marker>
        )}

        {/* Map controls */}
        <NavigationControl position="top-left" />
        <ScaleControl position="bottom-left" />
        <FullscreenControl position="top-right" />
      </Map>
      
      {/* Territory info overlay */}
      {territories.length === 0 && (
        <View style={styles.noTerritoriesOverlay}>
          <MaterialIcons name="map" size={48} color={COLORS.text.secondary} />
          <Text style={styles.noTerritoriesText}>No territories to display</Text>
          <Text style={styles.noTerritoriesSubtext}>Create your first territory to see it on the map</Text>
        </View>
      )}
    </View>
  );
};

// Native fallback component
const NativeFallback: React.FC<MapLibreVisualTerritoryMapProps> = (props) => {
  return (
    <View style={[styles.container, props.style]}>
      <View style={styles.fallbackContainer}>
        <MaterialIcons name="map" size={48} color={COLORS.text.secondary} />
        <Text style={styles.fallbackTitle}>Open Source Maps</Text>
        <Text style={styles.fallbackText}>
          MapLibre GL provides smooth, open-source mapping. Available on web browsers for the best territory viewing experience.
        </Text>
        <View style={styles.territoryListFallback}>
          <Text style={styles.territoryListTitle}>Territories ({props.territories.length})</Text>
          {props.territories.map(territory => (
            <View key={territory.id} style={styles.territoryItem}>
              <View style={[styles.territoryColorDot, { backgroundColor: territory.color }]} />
              <Text style={styles.territoryName}>{territory.name}</Text>
            </View>
          ))}
        </View>
      </View>
    </View>
  );
};

// Main component that chooses between web and native
const MapLibreVisualTerritoryMap: React.FC<MapLibreVisualTerritoryMapProps> = (props) => {
  if (Platform.OS === 'web') {
    return <MapLibreWebMap {...props} />;
  } else {
    return <NativeFallback {...props} />;
  }
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    position: 'relative',
    minHeight: 400,
  },
  maplibreMap: {
    height: '100%',
    width: '100%',
  },
  userLocationMarker: {
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
  noTerritoriesOverlay: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    transform: [{ translateX: -100 }, { translateY: -100 }],
    alignItems: 'center',
    backgroundColor: COLORS.background.primary,
    padding: SPACING.lg,
    borderRadius: RADIUS.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  noTerritoriesText: {
    fontSize: 18,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    textAlign: 'center',
  },
  noTerritoriesSubtext: {
    fontSize: 14,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
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
  territoryListFallback: {
    width: '100%',
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
  },
  territoryListTitle: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  territoryItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.sm,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.sm,
    marginBottom: SPACING.xs,
  },
  territoryColorDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: SPACING.sm,
  },
  territoryName: {
    flex: 1,
    fontSize: 14,
    color: COLORS.text.primary,
  },
});

export default MapLibreVisualTerritoryMap;
