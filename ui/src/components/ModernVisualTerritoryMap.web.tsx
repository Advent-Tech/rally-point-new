import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { COLORS, SPACING, RADIUS, TYPOGRAPHY } from '../constants/Colors';
import maplibregl, { Map as MapLibreMap, Marker as MapLibreMarker } from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';

// Inject simple CSS for the user location marker
if (typeof document !== 'undefined') {
  const style = document.createElement('style');
  style.textContent = `
    .maplibre-user-marker {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border: 3px solid white;
      border-radius: 50%;
      width: 28px;
      height: 28px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      box-shadow: 0 4px 8px rgba(0,0,0,0.3);
    }
  `;
  document.head.appendChild(style);
}

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

interface ModernVisualTerritoryMapProps {
  territories: Territory[];
  onTerritoryPress?: (territory: Territory) => void;
  showUserLocation?: boolean;
  userLocation?: {
    latitude: number;
    longitude: number;
  } | null;
  style?: any;
}

const TERRITORY_SOURCE_ID = 'territories';
const TERRITORY_FILL_LAYER_ID = 'territories-fill';
const TERRITORY_OUTLINE_LAYER_ID = 'territories-outline';

const ModernVisualTerritoryMap: React.FC<ModernVisualTerritoryMapProps> = ({
  territories,
  onTerritoryPress,
  showUserLocation,
  userLocation,
  style,
}) => {
  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const userMarkerRef = useRef<MapLibreMarker | null>(null);

  // Default center: first territory or Washington DC
  const defaultCenter: [number, number] = territories.length > 0 && territories[0].coordinates[0]
    ? [
        territories[0].coordinates[0].lng,
        territories[0].coordinates[0].lat,
      ]
    : [-77.0365, 38.8977];

  // Helper: build GeoJSON from territories
  const buildTerritoriesGeoJSON = (items: Territory[]): GeoJSON.FeatureCollection => {
    const features: GeoJSON.Feature[] = items
      .filter(t => t.coordinates && t.coordinates.length >= 3)
      .map(t => {
        const coords = t.coordinates.map(c => [c.lng, c.lat]);
        // Close polygon ring
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

  const updateTerritoriesOnMap = (map: MapLibreMap, items: Territory[]) => {
    const data = buildTerritoriesGeoJSON(items);
    const existingSource = map.getSource(TERRITORY_SOURCE_ID) as maplibregl.GeoJSONSource | undefined;

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
        'fill-opacity': 0.4,
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

    if (onTerritoryPress) {
      map.on('click', TERRITORY_FILL_LAYER_ID, (e) => {
        const feature = e.features && e.features[0];
        if (!feature || !feature.properties) return;
        const id = (feature.properties as any).id as string | undefined;
        const name = (feature.properties as any).name as string | undefined;
        const color = (feature.properties as any).color as string | undefined;
        if (!id) return;

        const territory: Territory = {
          id,
          name: name || 'Territory',
          description: undefined,
          color: color || COLORS.primary,
          coordinates: [],
        };

        onTerritoryPress(territory);
      });
    }
  };

  const updateUserLocationOnMap = (
    map: MapLibreMap,
    location: { latitude: number; longitude: number } | null | undefined,
    enabled?: boolean,
  ) => {
    if (!enabled || !location) {
      if (userMarkerRef.current) {
        userMarkerRef.current.remove();
        userMarkerRef.current = null;
      }
      return;
    }

    const lngLat: [number, number] = [location.longitude, location.latitude];

    if (!userMarkerRef.current) {
      const el = document.createElement('div');
      el.className = 'maplibre-user-marker';
      userMarkerRef.current = new maplibregl.Marker({ element: el }).setLngLat(lngLat).addTo(map);
    } else {
      userMarkerRef.current.setLngLat(lngLat);
    }
  };

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
      updateUserLocationOnMap(map, userLocation, showUserLocation);
    });

    return () => {
      if (userMarkerRef.current) {
        userMarkerRef.current.remove();
        userMarkerRef.current = null;
      }
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (!map.isStyleLoaded()) {
      map.once('load', () => updateTerritoriesOnMap(map, territories));
      return;
    }

    updateTerritoriesOnMap(map, territories);
  }, [territories]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (!map.isStyleLoaded()) {
      map.once('load', () => updateUserLocationOnMap(map, userLocation, showUserLocation));
      return;
    }

    updateUserLocationOnMap(map, userLocation, showUserLocation);
  }, [userLocation?.latitude, userLocation?.longitude, showUserLocation]);

  return (
    <View style={[styles.container, style]}>
      <div ref={mapContainerRef} style={styles.mapWrapper as any} />

      {territories.length === 0 && (
        <View style={styles.noTerritoriesOverlay}>
          <Text style={styles.noTerritoriesText}>No territories to display</Text>
          <Text style={styles.noTerritoriesSubtext}>
            Create your first territory to see it on the map
          </Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    position: 'relative',
    minHeight: 400,
  },
  mapWrapper: {
    height: '100%',
    width: '100%',
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
});

export default ModernVisualTerritoryMap;
