import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Platform,
  ActivityIndicator,
} from 'react-native';
import { WebView } from 'react-native-webview';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, SPACING, RADIUS, TYPOGRAPHY } from '../constants/Colors';

// Lazy-load Leaflet only on web to avoid `document` access on native
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

  // Import Leaflet assets from CDN
  delete (L.Icon.Default.prototype as any)._getIconUrl;
  L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  });

  // Add modern CSS for smooth maps
  const style = document.createElement('style');
  style.textContent = `
    .leaflet-container {
      background: #f0f0f0 !important;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
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
    .leaflet-control-zoom {
      border: 2px solid rgba(0,0,0,0.2) !important;
      background: white !important;
    }
    .leaflet-control-zoom a {
      background: white !important;
      color: #333 !important;
      font-weight: bold !important;
    }
    .leaflet-control-zoom a:hover {
      background: #f4f4f4 !important;
    }
    .user-location-marker {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border: 3px solid white;
      border-radius: 50%;
      width: 24px;
      height: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      box-shadow: 0 4px 8px rgba(0,0,0,0.3);
      z-index: 1000;
    }
    .territory-polygon {
      transition: all 0.3s ease;
    }
    .territory-polygon:hover {
      fill-opacity: 0.6 !important;
      stroke-width: 3px !important;
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

// Modern web map component
const ModernWebMap: React.FC<ModernVisualTerritoryMapProps> = ({
  territories,
  onTerritoryPress,
  showUserLocation,
  userLocation,
  style,
}) => {
  // Center on first territory or default to DC
  const defaultCenter: [number, number] = territories.length > 0 
    ? [
        territories[0].coordinates[0]?.lat || 38.8977,
        territories[0].coordinates[0]?.lng || -77.0365,
      ]
    : [38.8977, -77.0365];

  const handleTerritoryClick = (territory: Territory) => {
    if (onTerritoryPress) {
      onTerritoryPress(territory);
    }
  };

  // Create user location marker
  const createUserLocationMarker = () => {
    return L.divIcon({
      className: 'user-location-marker',
      html: `<div class="user-location-marker">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="white">
          <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
        </svg>
      </div>`,
      iconSize: [24, 24],
      iconAnchor: [12, 12],
      popupAnchor: [0, -12],
    });
  };

  return (
    <View style={[styles.container, style]}>
      <div style={styles.mapWrapper}>
        <MapContainer
          center={defaultCenter}
          zoom={13}
          style={styles.leafletMap}
          zoomControl={true}
          attributionControl={false}
          scrollWheelZoom={true}
          zoomAnimation={true}
          markerZoomAnimation={true}
          preferCanvas={true}
          zoomSnap={0.25}
          zoomDelta={0.5}
        >
          {/* OpenStreetMap tiles */}
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            maxZoom={19}
            minZoom={3}
            detectRetina={true}
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
              icon={createUserLocationMarker()}
            />
          )}
        </MapContainer>
      </div>
      
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

// Native WebView map component - shows actual map with OpenStreetMap tiles
const NativeWebViewMap: React.FC<ModernVisualTerritoryMapProps> = ({
  territories,
  onTerritoryPress,
  showUserLocation,
  userLocation,
  style,
}) => {
  const webViewRef = useRef<WebView>(null);

  // Calculate center from territories or use default (India)
  const getCenter = (): [number, number] => {
    if (territories.length > 0 && territories[0].coordinates.length > 0) {
      return [territories[0].coordinates[0].lat, territories[0].coordinates[0].lng];
    }
    return [20.5937, 78.9629]; // Default to India
  };

  const center = getCenter();

  const getMapHTML = () => {
    const territoriesJSON = JSON.stringify(territories);
    const userLocationJSON = userLocation ? JSON.stringify(userLocation) : 'null';

    return `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <style>
          body { margin: 0; padding: 0; }
          #map { height: 100vh; width: 100%; }
          .territory-popup { font-family: Arial, sans-serif; text-align: center; }
          .territory-popup-name { font-weight: bold; color: #002b5b; margin-bottom: 4px; }
          .territory-popup-desc { color: #64748b; font-size: 12px; }
        </style>
      </head>
      <body>
        <div id="map"></div>
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <script>
          const territories = ${territoriesJSON};
          const userLocation = ${userLocationJSON};
          const showUserLocation = ${showUserLocation || false};

          const map = L.map('map', {
            zoomControl: true,
            attributionControl: true,
            scrollWheelZoom: true,
            touchZoom: true,
            dragging: true
          }).setView([${center[0]}, ${center[1]}], 12);

          // Add OpenStreetMap tiles - shows roads, buildings, etc.
          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors',
            maxZoom: 19
          }).addTo(map);

          // Draw territories
          territories.forEach(function(territory) {
            if (territory.coordinates && territory.coordinates.length > 0) {
              const coords = territory.coordinates.map(function(c) {
                return [c.lat, c.lng];
              });

              const polygon = L.polygon(coords, {
                color: territory.color,
                fillColor: territory.color,
                fillOpacity: 0.3,
                weight: 2
              }).addTo(map);

              polygon.bindPopup(
                '<div class="territory-popup">' +
                  '<div class="territory-popup-name">' + territory.name + '</div>' +
                  (territory.description ? '<div class="territory-popup-desc">' + territory.description + '</div>' : '') +
                '</div>'
              );

              polygon.on('click', function() {
                if (window.ReactNativeWebView) {
                  window.ReactNativeWebView.postMessage(JSON.stringify({
                    type: 'territoryPress',
                    territory: territory
                  }));
                }
              });
            }
          });

          // Fit bounds to show all territories
          if (territories.length > 0) {
            const allCoords = [];
            territories.forEach(function(t) {
              t.coordinates.forEach(function(c) {
                allCoords.push([c.lat, c.lng]);
              });
            });
            if (allCoords.length > 0) {
              map.fitBounds(allCoords, { padding: [20, 20] });
            }
          }

          // Show user location if available
          if (showUserLocation && userLocation) {
            L.circleMarker([userLocation.latitude, userLocation.longitude], {
              radius: 8,
              fillColor: '#4285F4',
              color: '#ffffff',
              weight: 2,
              opacity: 1,
              fillOpacity: 1
            }).addTo(map);
          }

          // Notify React Native that map is ready
          if (window.ReactNativeWebView) {
            window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'mapReady' }));
          }
        </script>
      </body>
      </html>
    `;
  };

  const handleWebViewMessage = (event: any) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      if (data.type === 'territoryPress' && onTerritoryPress) {
        onTerritoryPress(data.territory);
      }
    } catch (error) {
      console.error('Error parsing WebView message:', error);
    }
  };

  return (
    <View style={[styles.container, style]}>
      <WebView
        ref={webViewRef}
        source={{ html: getMapHTML() }}
        style={styles.webView}
        onMessage={handleWebViewMessage}
        javaScriptEnabled={true}
        domStorageEnabled={true}
        startInLoadingState={true}
        originWhitelist={['*']}
        mixedContentMode="always"
        allowUniversalAccessFromFileURLs={true}
        allowFileAccessFromFileURLs={true}
        onError={(error) => console.error('WebView error:', error)}
        renderLoading={() => (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color={COLORS.primary} />
            <Text style={styles.loadingText}>Loading Map...</Text>
          </View>
        )}
      />
    </View>
  );
};

// Main component that chooses between web and native
const ModernVisualTerritoryMap: React.FC<ModernVisualTerritoryMapProps> = (props) => {
  if (Platform.OS === 'web') {
    return <ModernWebMap {...props} />;
  } else {
    return <NativeWebViewMap {...props} />;
  }
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    position: 'relative',
    minHeight: 400,
  },
  webView: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
  },
  loadingText: {
    fontSize: 14,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
  },
  mapWrapper: {
    height: '100%',
    width: '100%',
    position: 'relative',
    overflow: 'hidden',
  },
  leafletMap: {
    height: '100%',
    width: '100%',
    borderRadius: 0,
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

export default ModernVisualTerritoryMap;
