import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Platform,
  ActivityIndicator,
  TextInput,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, SPACING, RADIUS, TYPOGRAPHY } from '../constants/Colors';

// Lazy-load Leaflet only on web to avoid `document` access on native
let MapContainer: any;
let TileLayer: any;
let Polygon: any;
let Marker: any;
let useMapEvents: any;
let useMap: any;
let L: any;

if (Platform.OS === 'web') {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const leaflet = require('react-leaflet');
  MapContainer = leaflet.MapContainer;
  TileLayer = leaflet.TileLayer;
  Polygon = leaflet.Polygon;
  Marker = leaflet.Marker;
  useMapEvents = leaflet.useMapEvents;
  useMap = leaflet.useMap;

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
    .modern-marker {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border: 3px solid white;
      border-radius: 50%;
      width: 36px;
      height: 36px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-weight: bold;
      font-size: 14px;
      box-shadow: 0 4px 8px rgba(0,0,0,0.3);
      transition: transform 0.2s ease;
      z-index: 1000;
    }
    .modern-marker:hover {
      transform: scale(1.1);
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

interface Point {
  lat: number;
  lng: number;
}

interface ModernTerritoryDrawingProps {
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

// Map events handler for web
const WebMapEvents: React.FC<{
  onMapClick: (lat: number, lng: number) => void;
  isDrawingMode: boolean;
}> = ({ onMapClick, isDrawingMode }) => {
  useMapEvents({
    click: (e: { latlng: { lat: number; lng: number } }) => {
      if (isDrawingMode) {
        onMapClick(e.latlng.lat, e.latlng.lng);
      }
    },
  });
  return null;
};

// Map controller component for programmatic map control
const MapController: React.FC<{
  center: [number, number] | null;
  zoom?: number;
}> = ({ center, zoom }) => {
  const map = useMap();

  useEffect(() => {
    if (center) {
      map.flyTo(center, zoom || 14, { duration: 1.5 });
    }
  }, [center, zoom, map]);

  return null;
};

// Modern web map component
const ModernWebMap: React.FC<ModernTerritoryDrawingProps> = ({
  isDrawingMode,
  onPolygonDrawn,
  onStopDrawing,
  territories,
  onMapReady,
}) => {
  const [drawingPoints, setDrawingPoints] = useState<Point[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [mapKey, setMapKey] = useState(0);

  // Search and location state
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [searchMarker, setSearchMarker] = useState<{lat: number, lng: number, name: string} | null>(null);
  const [userLocation, setUserLocation] = useState<{lat: number, lng: number} | null>(null);
  const [mapCenter, setMapCenter] = useState<[number, number] | null>(null);

  // Get user's current location on mount
  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const location = {
            lat: position.coords.latitude,
            lng: position.coords.longitude,
          };
          setUserLocation(location);
          setMapCenter([location.lat, location.lng]);
          console.log('📍 Got user location:', location);
        },
        (error) => {
          console.log('📍 Location error:', error.message);
        },
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
      );
    }
  }, []);

  // Center on user location, or first territory, or default to India
  const defaultCenter: [number, number] = userLocation
    ? [userLocation.lat, userLocation.lng]
    : territories.length > 0
      ? [
          territories[0].coordinates[0]?.lat || 20.5937,
          territories[0].coordinates[0]?.lng || 78.9629,
        ]
      : [20.5937, 78.9629];

  useEffect(() => {
    // Force map re-render when territories change
    setMapKey(prev => prev + 1);
    onMapReady();
  }, [onMapReady, territories.length]);

  // Search for a location using Nominatim API
  const searchLocation = async () => {
    if (!searchQuery.trim()) return;

    setIsSearching(true);
    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(searchQuery)}&limit=1`,
        {
          headers: {
            'User-Agent': 'RallyPont Territory App',
          },
        }
      );
      const data = await response.json();

      if (data && data.length > 0) {
        const result = data[0];
        const lat = parseFloat(result.lat);
        const lng = parseFloat(result.lon);

        setSearchMarker({ lat, lng, name: result.display_name });
        setMapCenter([lat, lng]);
        console.log('🔍 Found location:', result.display_name);
      } else {
        Alert.alert('Not Found', 'Could not find the location. Please try a different search term.');
      }
    } catch (err) {
      console.error('Search error:', err);
      Alert.alert('Error', 'Failed to search location. Please try again.');
    } finally {
      setIsSearching(false);
    }
  };

  // Go to user's current location
  const goToMyLocation = () => {
    if (userLocation) {
      setMapCenter([userLocation.lat, userLocation.lng]);
    } else if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const location = {
            lat: position.coords.latitude,
            lng: position.coords.longitude,
          };
          setUserLocation(location);
          setMapCenter([location.lat, location.lng]);
        },
        (error) => {
          console.log('📍 Location error:', error.message);
          Alert.alert('Location Error', 'Could not get your location. Please enable location services.');
        },
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
      );
    }
  };

  // Create search marker icon
  const createSearchMarkerIcon = () => {
    return L.divIcon({
      className: 'search-marker',
      html: `<div style="
        background: #EF4444;
        border: 3px solid white;
        border-radius: 50% 50% 50% 0;
        width: 32px;
        height: 32px;
        transform: rotate(-45deg);
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 4px 8px rgba(0,0,0,0.3);
      "><svg style="transform: rotate(45deg);" width="16" height="16" viewBox="0 0 24 24" fill="white">
        <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
      </svg></div>`,
      iconSize: [32, 32],
      iconAnchor: [16, 32],
      popupAnchor: [0, -32],
    });
  };

  // Create user location marker icon
  const createUserLocationIcon = () => {
    return L.divIcon({
      className: 'user-location-marker',
      html: `<div style="
        background: #4285F4;
        border: 3px solid white;
        border-radius: 50%;
        width: 20px;
        height: 20px;
        box-shadow: 0 2px 6px rgba(0,0,0,0.3);
      "></div>`,
      iconSize: [20, 20],
      iconAnchor: [10, 10],
    });
  };

  const handleMapClick = (lat: number, lng: number) => {
    const newPoint: Point = { lat, lng };
    setDrawingPoints(prev => [...prev, newPoint]);
    setError(null);
    console.log('🗺️ Added point from modern map:', newPoint);
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

    console.log('🗺️ Modern territory drawing completed with', coordinates.length, 'points');
    onPolygonDrawn(coordinates);
    setDrawingPoints([]);
    setError(null);
  };

  const handleCancelDrawing = () => {
    setDrawingPoints([]);
    setError(null);
    onStopDrawing();
  };

  // Create custom numbered markers
  const createNumberedMarker = (number: number) => {
    return L.divIcon({
      className: 'modern-marker',
      html: `<div class="modern-marker">${number}</div>`,
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -18],
    });
  };

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
            ? `Tap map to add points (${drawingPoints.length} added)`
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

      {/* Search Bar */}
      <View style={styles.searchBar}>
        <View style={styles.searchInputContainer}>
          <MaterialIcons name="search" size={20} color={COLORS.text.secondary} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search city, address..."
            placeholderTextColor={COLORS.text.secondary}
            value={searchQuery}
            onChangeText={setSearchQuery}
            onSubmitEditing={searchLocation}
            returnKeyType="search"
          />
          {searchQuery.length > 0 && (
            <TouchableOpacity onPress={() => setSearchQuery('')}>
              <MaterialIcons name="clear" size={20} color={COLORS.text.secondary} />
            </TouchableOpacity>
          )}
        </View>
        <TouchableOpacity
          style={styles.searchButton}
          onPress={searchLocation}
          disabled={isSearching}
        >
          {isSearching ? (
            <ActivityIndicator size="small" color={COLORS.white} />
          ) : (
            <MaterialIcons name="search" size={20} color={COLORS.white} />
          )}
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.myLocationButton}
          onPress={goToMyLocation}
        >
          <MaterialIcons name="my-location" size={20} color={COLORS.primary} />
        </TouchableOpacity>
      </View>

      {/* Modern Map Container */}
      <View style={styles.mapContainer}>
        <div style={styles.mapWrapper}>
          <MapContainer
            key={mapKey}
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
            {/* Map controller for programmatic movement */}
            <MapController center={mapCenter} zoom={14} />

            {/* OpenStreetMap tiles */}
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              maxZoom={19}
              minZoom={3}
              detectRetina={true}
            />

            {/* User location marker */}
            {userLocation && (
              <Marker
                position={[userLocation.lat, userLocation.lng]}
                icon={createUserLocationIcon()}
              />
            )}

            {/* Search result marker */}
            {searchMarker && (
              <Marker
                position={[searchMarker.lat, searchMarker.lng]}
                icon={createSearchMarkerIcon()}
              />
            )}

            {/* Existing territories */}
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
                  click: () => console.log('🗺️ Territory clicked:', territory.name),
                }}
              />
            ))}

            {/* Drawing mode components */}
            {isDrawingMode && (
              <>
                <WebMapEvents onMapClick={handleMapClick} isDrawingMode={isDrawingMode} />
                
                {/* Current drawing polygon */}
                {drawingPoints.length > 0 && (
                  <Polygon
                    positions={drawingPoints.map(point => [point.lat, point.lng])}
                    pathOptions={{ 
                      color: COLORS.primary, 
                      fillOpacity: 0.5, 
                      weight: 3,
                      dashArray: '10, 10',
                      className: 'drawing-polygon'
                    }}
                  />
                )}
                
                {/* Numbered markers */}
                {drawingPoints.map((point, index) => (
                  <Marker
                    key={index}
                    position={[point.lat, point.lng]}
                    icon={createNumberedMarker(index + 1)}
                  />
                ))}
              </>
            )}
          </MapContainer>
        </div>
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
            Click on the map to add boundary points. Need at least 3 points to create a territory.
          </Text>
        </View>
      )}
    </View>
  );
};

// Native fallback
const NativeFallback: React.FC<ModernTerritoryDrawingProps> = (props) => {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={props.onStopDrawing}>
          <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Modern Maps</Text>
        <View style={{ width: 24 }} />
      </View>
      
      <View style={styles.fallbackContainer}>
        <MaterialIcons name="map" size={48} color={COLORS.text.secondary} />
        <Text style={styles.fallbackTitle}>Modern Map Experience</Text>
        <Text style={styles.fallbackText}>
          Experience smooth, modern maps with OpenStreetMap. Available on web browsers for the best territory creation experience.
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

// Main component
const ModernTerritoryDrawing: React.FC<ModernTerritoryDrawingProps> = (props) => {
  if (Platform.OS === 'web') {
    return <ModernWebMap {...props} />;
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
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.sm,
    paddingHorizontal: SPACING.md,
    backgroundColor: COLORS.background.secondary,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
    gap: SPACING.sm,
  },
  searchInputContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.sm,
    height: 40,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  searchInput: {
    flex: 1,
    fontSize: 14,
    color: COLORS.text.primary,
    marginLeft: SPACING.xs,
  },
  searchButton: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    padding: SPACING.sm,
    height: 40,
    width: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  myLocationButton: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.md,
    padding: SPACING.sm,
    height: 40,
    width: 40,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  mapContainer: {
    flex: 1,
    position: 'relative',
    minHeight: 400,
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

export default ModernTerritoryDrawing;
