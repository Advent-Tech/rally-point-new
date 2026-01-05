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

// Lazy-load Leaflet only on web to avoid document access on native
let MapContainer: any;
let TileLayer: any;
let Polygon: any;
let Marker: any;
let L: any;

if (Platform.OS === 'web') {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const leaflet = require('react-leaflet');
  MapContainer = leaflet.MapContainer;
  TileLayer = leaflet.TileLayer;
  Polygon = leaflet.Polygon;
  Marker = leaflet.Marker;

  // eslint-disable-next-line @typescript-eslint/no-var-requires
  L = require('leaflet');
  require('leaflet/dist/leaflet.css');

  const DefaultIcon = new L.Icon({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34],
    shadowSize: [41, 41]
  });

  L.Marker.prototype.options.icon = DefaultIcon;

  const style = document.createElement('style');
  style.textContent = `
    .leaflet-container {
      background: #f0f0f0 !important;
      outline: none !important;
      height: 100% !important;
      width: 100% !important;
    }
    .leaflet-tile-pane {
      z-index: 2 !important;
    }
    .leaflet-overlay-pane {
      z-index: 4 !important;
    }
    .leaflet-marker-pane {
      z-index: 5 !important;
    }
    .leaflet-popup-pane {
      z-index: 6 !important;
    }
    .leaflet-container a.leaflet-popup-close-button {
      color: #333 !important;
    }
    .leaflet-control-container {
      margin: 0 !important;
      padding: 0 !important;
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

interface SimpleVisualTerritoryMapProps {
  territories: Territory[];
  onTerritoryPress?: (territory: Territory) => void;
  showUserLocation?: boolean;
  userLocation?: {
    latitude: number;
    longitude: number;
  } | null;
  style?: any;
}

// Web-only map component
const SimpleWebMap: React.FC<SimpleVisualTerritoryMapProps> = ({
  territories,
  onTerritoryPress,
  showUserLocation,
  userLocation,
  style,
}) => {
  // Default to Washington DC area, or center on territories
  const defaultCenter = territories.length > 0 
    ? [territories[0].coordinates[0]?.lat || 38.8977, territories[0].coordinates[0]?.lng || -77.0365]
    : [38.8977, -77.0365];

  const handleTerritoryClick = (territory: Territory) => {
    if (onTerritoryPress) {
      onTerritoryPress(territory);
    }
  };

  return (
    <View style={[styles.container, style]}>
      <MapContainer
        center={defaultCenter}
        zoom={13}
        style={styles.leafletMap}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
          maxZoom={19}
          updateWhenIdle={false}
          updateWhenZooming={false}
          keepBuffer={4}
          errorTileUrl="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        />
        
        {/* Territory polygons */}
        {territories.map(territory => (
          <Polygon
            key={territory.id}
            positions={territory.coordinates.map(coord => [coord.lat, coord.lng])}
            pathOptions={{ 
              color: territory.color, 
              fillOpacity: 0.3,
              weight: 2,
              className: 'territory-polygon'
            }}
            eventHandlers={{
              click: () => handleTerritoryClick(territory),
            }}
          />
        ))}

        {/* User location marker */}
        {showUserLocation && userLocation && (
          <Marker
            position={[userLocation.latitude, userLocation.longitude]}
            icon={L.divIcon({
              className: 'user-location-marker',
              html: `<div style="
                background: ${COLORS.primary}; 
                color: white; 
                border-radius: 50%; 
                width: 20px; 
                height: 20px; 
                display: flex; 
                align-items: center; 
                justify-content: center; 
                border: 2px solid white; 
                box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                z-index: 1000;
              ">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="white">
                  <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
                </svg>
              </div>`,
              iconSize: [20, 20],
              iconAnchor: [10, 10],
              popupAnchor: [0, -10],
            })}
          />
        )}
      </MapContainer>
      
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

// Native fallback component - shows message for native platforms
const NativeFallback: React.FC<SimpleVisualTerritoryMapProps> = (props) => {
  return (
    <View style={[styles.container, props.style]}>
      <View style={styles.fallbackContainer}>
        <MaterialIcons name="map" size={48} color={COLORS.text.secondary} />
        <Text style={styles.fallbackTitle}>Web Maps</Text>
        <Text style={styles.fallbackText}>
          Territory maps are available on web browsers. On mobile devices, please use the web version for the best territory viewing experience.
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
const SimpleVisualTerritoryMap: React.FC<SimpleVisualTerritoryMapProps> = (props) => {
  if (Platform.OS === 'web') {
    return <SimpleWebMap {...props} />;
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
  leafletMap: {
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

export default SimpleVisualTerritoryMap;
