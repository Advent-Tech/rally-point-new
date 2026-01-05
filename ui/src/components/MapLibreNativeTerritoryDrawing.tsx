import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  StyleSheet,
  TouchableOpacity,
  Text,
  Alert,
  TextInput,
  ActivityIndicator,
  Keyboard,
  SafeAreaView,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import * as Location from 'expo-location';
import { COLORS, SPACING, RADIUS, TYPOGRAPHY } from '../constants/Colors';
import MapLibreGL from '@maplibre/maplibre-react-native';
const { MapView, Camera, ShapeSource, FillLayer, LineLayer, PointAnnotation } = MapLibreGL;

MapLibreGL.setAccessToken(null);

interface Point {
  latitude: number;
  longitude: number;
}

interface MapLibreNativeTerritoryDrawingProps {
  isDrawingMode: boolean;
  territoryName: string;
  onTerritoryNameChange: (name: string) => void;
  onPolygonDrawn: (coordinates: Array<{ lat: number; lng: number }>) => void;
  onStopDrawing: () => void;
  territories: Array<{
    id: string;
    name: string;
    coordinates: Array<{ lat: number; lng: number }>;
    color: string;
  }>;
  mapReady: boolean;
  onMapReady: () => void;
}

const MapLibreNativeTerritoryDrawing: React.FC<MapLibreNativeTerritoryDrawingProps> = ({
  isDrawingMode,
  territoryName,
  onTerritoryNameChange,
  onPolygonDrawn,
  onStopDrawing,
  territories,
  mapReady,
  onMapReady,
}) => {
  const [drawingPoints, setDrawingPoints] = useState<Point[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [userLocation, setUserLocation] = useState<Point | null>(null);
  const [searchMarker, setSearchMarker] = useState<{lat: number, lng: number, name: string} | null>(null);
  const [locationLoading, setLocationLoading] = useState(true);
  const [locationError, setLocationError] = useState<string | null>(null);
  const [cameraCenter, setCameraCenter] = useState<{lng: number, lat: number} | null>(null);
  const [cameraZoom, setCameraZoom] = useState(15);
  const mapRef = useRef<any>(null);
  const cameraRef = useRef<any>(null);

  // Get user's current location on mount
  useEffect(() => {
    getCurrentLocation();
  }, []);

  const getCurrentLocation = async () => {
    try {
      setLocationLoading(true);
      setLocationError(null);
      console.log('📍 Requesting location permission...');

      const { status } = await Location.requestForegroundPermissionsAsync();
      console.log('📍 Permission status:', status);

      if (status !== 'granted') {
        console.log('📍 Location permission denied');
        setLocationError('Location permission denied. Use the search bar to find your area.');
        Alert.alert(
          'Location Permission Required',
          'Please enable location access in your device settings, or use the search bar to find and navigate to your area.',
          [{ text: 'OK' }]
        );
        setLocationLoading(false);
        return;
      }

      console.log('📍 Permission granted, getting location...');

      // Try to get last known position first (faster)
      let location = await Location.getLastKnownPositionAsync({});
      console.log('📍 Last known position:', location);

      // If no last known position, get current position with timeout
      if (!location) {
        console.log('📍 No last known position, getting current position...');
        try {
          location = await Promise.race([
            Location.getCurrentPositionAsync({
              accuracy: Location.Accuracy.Balanced,
            }),
            new Promise<null>((_, reject) =>
              setTimeout(() => reject(new Error('Location timeout')), 10000)
            )
          ]) as Location.LocationObject;
        } catch (timeoutErr) {
          console.log('📍 Current position timed out, trying low accuracy...');
          location = await Location.getCurrentPositionAsync({
            accuracy: Location.Accuracy.Lowest,
          });
        }
      }

      if (!location) {
        throw new Error('Could not determine location');
      }

      const coords: Point = {
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      };
      setUserLocation(coords);
      setLocationError(null);

      // Move camera to user location
      setCameraCenter({ lng: coords.longitude, lat: coords.latitude });
      setCameraZoom(15);
      console.log('📍 Camera moving to user location:', coords.latitude, coords.longitude);
    } catch (err: any) {
      console.error('📍 Error getting location:', err);
      const errorMsg = `Could not get your location: ${err.message || 'Unknown error'}. Use the search bar to find your area.`;
      setLocationError(errorMsg);
      Alert.alert(
        'Location Error',
        'Could not get your current location. Please use the search bar to find and navigate to your area.',
        [{ text: 'OK' }]
      );
    } finally {
      setLocationLoading(false);
    }
  };

  // Search for a location using Nominatim (OpenStreetMap geocoding)
  const searchLocation = async () => {
    if (!searchQuery.trim()) return;

    Keyboard.dismiss();
    setIsSearching(true);

    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(searchQuery)}&limit=1`,
        {
          headers: {
            'User-Agent': 'RallyPointApp/1.0',
          },
        }
      );
      const results = await response.json();

      if (results && results.length > 0) {
        const { lat, lon, display_name } = results[0];
        const coords = { lat: parseFloat(lat), lng: parseFloat(lon) };

        console.log('🔍 Search found location:', display_name, coords);

        // Set search marker
        setSearchMarker({ lat: coords.lat, lng: coords.lng, name: display_name });

        // Move camera to searched location
        setCameraCenter({ lng: coords.lng, lat: coords.lat });
        setCameraZoom(16);

        Alert.alert('Location Found', display_name.substring(0, 100) + (display_name.length > 100 ? '...' : ''));
      } else {
        Alert.alert('Not Found', 'Could not find the location. Try a different search term.');
      }
    } catch (err) {
      console.error('Search error:', err);
      Alert.alert('Error', 'Failed to search location. Please try again.');
    } finally {
      setIsSearching(false);
    }
  };

  // Initial default center (only used if no camera center is set): first territory or India
  const initialCenter = territories.length > 0 && territories[0].coordinates[0]
    ? {
        latitude: territories[0].coordinates[0].lat,
        longitude: territories[0].coordinates[0].lng,
      }
    : { latitude: 20.5937, longitude: 78.9629 };

  // Active camera center: use state if set, otherwise initial
  const activeCameraCenter = cameraCenter
    ? { latitude: cameraCenter.lat, longitude: cameraCenter.lng }
    : initialCenter;

  // Sort points by angle from centroid to create a proper non-self-intersecting polygon
  const sortPointsByAngle = (points: Point[]): Point[] => {
    if (points.length < 3) return points;

    // Calculate centroid
    const centroid = {
      latitude: points.reduce((sum, p) => sum + p.latitude, 0) / points.length,
      longitude: points.reduce((sum, p) => sum + p.longitude, 0) / points.length,
    };

    // Sort by angle from centroid
    return [...points].sort((a, b) => {
      const angleA = Math.atan2(a.latitude - centroid.latitude, a.longitude - centroid.longitude);
      const angleB = Math.atan2(b.latitude - centroid.latitude, b.longitude - centroid.longitude);
      return angleA - angleB;
    });
  };

  // Build GeoJSON for territories
  const buildTerritoriesGeoJSON = () => {
    const features = territories
      .filter((t) => t.coordinates && t.coordinates.length >= 3)
      .map((t) => {
        const coords = t.coordinates.map((c) => [c.lng, c.lat]);
        if (coords.length > 0) {
          coords.push([coords[0][0], coords[0][1]]);
        }
        return {
          type: 'Feature' as const,
          geometry: {
            type: 'Polygon' as const,
            coordinates: [coords],
          },
          properties: {
            id: t.id,
            name: t.name,
            color: t.color,
          },
        };
      });

    return {
      type: 'FeatureCollection' as const,
      features,
    };
  };

  // Build GeoJSON for current drawing (uses sorted points to show proper polygon)
  const buildDrawingGeoJSON = () => {
    if (!drawingPoints || drawingPoints.length < 3) {
      return {
        type: 'FeatureCollection' as const,
        features: [],
      };
    }

    // Sort points to show proper non-self-intersecting polygon preview
    const sortedPoints = sortPointsByAngle(drawingPoints);
    const coords = sortedPoints.map((p) => [p.longitude, p.latitude]);
    coords.push([coords[0][0], coords[0][1]]); // Close the polygon

    return {
      type: 'FeatureCollection' as const,
      features: [
        {
          type: 'Feature' as const,
          geometry: {
            type: 'Polygon' as const,
            coordinates: [coords],
          },
          properties: {},
        },
      ],
    };
  };

  const handleMapPress = (e: any) => {
    if (!isDrawingMode) return;

    try {
      const { geometry } = e;
      const { coordinates } = geometry;
      const [longitude, latitude] = coordinates;

      const newPoint: Point = { latitude, longitude };
      setDrawingPoints((prev) => [...prev, newPoint]);
      setError(null);
      console.log('🗺️ Added point from MapLibre native map:', newPoint);
    } catch (err) {
      console.error('🗺️ Error handling map press:', err);
      setError('Failed to add point. Please try again.');
    }
  };

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
      Alert.alert('Error', 'Please add at least 3 points to create a territory');
      return;
    }

    // Sort points by angle to prevent self-intersecting polygon
    const sortedPoints = sortPointsByAngle(drawingPoints);

    const coordinates = sortedPoints.map((point) => ({
      lat: point.latitude,
      lng: point.longitude,
    }));

    console.log('🗺️ MapLibre native territory drawing completed with', coordinates.length, 'points (sorted by angle)');
    onPolygonDrawn(coordinates);
    setDrawingPoints([]);
    setError(null);
  };

  const handleCancelDrawing = () => {
    setDrawingPoints([]);
    setError(null);
    onStopDrawing();
  };

  // Notify map ready on mount
  useEffect(() => {
    console.log('🗺️ MapLibre native drawing map is ready');
    onMapReady();
  }, [onMapReady]);

  return (
    <SafeAreaView style={styles.container}>
      {/* Search Bar */}
      <View style={styles.searchContainer}>
        <View style={styles.searchInputContainer}>
          <MaterialIcons name="search" size={20} color={COLORS.text.secondary} style={styles.searchIcon} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search location..."
            value={searchQuery}
            onChangeText={setSearchQuery}
            onSubmitEditing={searchLocation}
            returnKeyType="search"
            placeholderTextColor={COLORS.text.secondary}
          />
          {isSearching ? (
            <ActivityIndicator size="small" color={COLORS.primary} style={styles.searchButton} />
          ) : (
            <TouchableOpacity onPress={searchLocation} style={styles.searchButton}>
              <MaterialIcons name="arrow-forward" size={20} color={COLORS.primary} />
            </TouchableOpacity>
          )}
        </View>
        <TouchableOpacity
          onPress={getCurrentLocation}
          style={styles.myLocationButton}
          disabled={locationLoading}
        >
          {locationLoading ? (
            <ActivityIndicator size="small" color={COLORS.white} />
          ) : (
            <MaterialIcons name="my-location" size={20} color={COLORS.white} />
          )}
        </TouchableOpacity>
      </View>

      {/* Location error hint */}
      {locationError && (
        <View style={styles.locationErrorBanner}>
          <MaterialIcons name="location-off" size={16} color={COLORS.warning} />
          <Text style={styles.locationErrorText}>{locationError}</Text>
          <TouchableOpacity onPress={() => setLocationError(null)}>
            <MaterialIcons name="close" size={18} color={COLORS.text.secondary} />
          </TouchableOpacity>
        </View>
      )}

      {error && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>{error}</Text>
          <TouchableOpacity onPress={() => setError(null)}>
            <MaterialIcons name="close" size={20} color={COLORS.white} />
          </TouchableOpacity>
        </View>
      )}

      <MapView
        ref={mapRef}
        style={styles.map}
        onPress={handleMapPress}
        mapStyle="https://basemaps.cartocdn.com/gl/positron-gl-style/style.json"
      >
        <Camera
          ref={cameraRef}
          centerCoordinate={[activeCameraCenter.longitude, activeCameraCenter.latitude]}
          zoomLevel={cameraZoom}
          animationMode={'flyTo'}
          animationDuration={1000}
        />

        {/* Search result marker */}
        {searchMarker && (
          <PointAnnotation
            id="searchMarker"
            coordinate={[searchMarker.lng, searchMarker.lat]}
            title={searchMarker.name}
          >
            <View style={styles.markerContainer}>
              <MaterialIcons name="place" size={32} color={COLORS.error} />
            </View>
          </PointAnnotation>
        )}

        {/* User location marker */}
        {userLocation && (
          <PointAnnotation
            id="userLocation"
            coordinate={[userLocation.longitude, userLocation.latitude]}
            title="Your Location"
          >
            <View style={styles.userLocationMarker}>
              <View style={styles.userLocationDot} />
            </View>
          </PointAnnotation>
        )}

        {/* Existing territories */}
        <ShapeSource id="territories" shape={buildTerritoriesGeoJSON()}>
          <FillLayer
            id="territoriesFill"
            style={{
              fillColor: ['get', 'color'],
              fillOpacity: 0.3,
            }}
          />
          <LineLayer
            id="territoriesOutline"
            style={{
              lineColor: ['get', 'color'],
              lineWidth: 2,
            }}
          />
        </ShapeSource>

        {/* Current drawing polygon */}
        {isDrawingMode && drawingPoints.length >= 3 && (
          <ShapeSource id="currentDrawing" shape={buildDrawingGeoJSON()}>
            <FillLayer
              id="drawingFill"
              style={{
                fillColor: COLORS.primary,
                fillOpacity: 0.5,
              }}
            />
            <LineLayer
              id="drawingOutline"
              style={{
                lineColor: COLORS.primary,
                lineWidth: 3,
              }}
            />
          </ShapeSource>
        )}
      </MapView>

      {/* Drawing Controls - Fixed at bottom so search bar remains visible */}
      {isDrawingMode && (
        <View style={styles.controls}>
          <View style={styles.instructions}>
            <Text style={styles.instructionText}>
              {drawingPoints.length === 0
                ? 'Tap on the map to add boundary points. Add at least 3 points.'
                : `${drawingPoints.length} point${drawingPoints.length > 1 ? 's' : ''} added. ${drawingPoints.length < 3 ? `Add ${3 - drawingPoints.length} more.` : 'Ready to save!'}`}
            </Text>
          </View>

          <View style={styles.actionButtons}>
            <TouchableOpacity
              style={styles.actionButton}
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
                  styles.actionButtonText,
                  drawingPoints.length === 0 && styles.actionButtonTextDisabled,
                ]}
              >
                Undo
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.actionButton}
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
                  styles.actionButtonText,
                  drawingPoints.length === 0 && styles.actionButtonTextDisabled,
                ]}
              >
                Clear All
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.controlButtons}>
            <TouchableOpacity style={styles.cancelButtonLarge} onPress={handleCancelDrawing}>
              <MaterialIcons name="close" size={20} color={COLORS.text.primary} />
              <Text style={styles.cancelButtonText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.finishButtonLarge, drawingPoints.length < 3 && styles.finishButtonDisabled]}
              onPress={handleFinishDrawing}
              disabled={drawingPoints.length < 3}
            >
              <MaterialIcons
                name="check"
                size={20}
                color={drawingPoints.length < 3 ? COLORS.text.disabled : COLORS.white}
              />
              <Text style={[styles.finishButtonText, drawingPoints.length < 3 && styles.finishButtonTextDisabled]}>
                Save Territory
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.sm,
    backgroundColor: COLORS.white,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
    gap: SPACING.sm,
  },
  searchInputContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.sm,
  },
  searchIcon: {
    marginRight: SPACING.xs,
  },
  searchInput: {
    flex: 1,
    paddingVertical: SPACING.sm,
    fontSize: 14,
    color: COLORS.text.primary,
  },
  searchButton: {
    padding: SPACING.xs,
  },
  myLocationButton: {
    backgroundColor: COLORS.primary,
    padding: SPACING.sm,
    borderRadius: RADIUS.full,
    justifyContent: 'center',
    alignItems: 'center',
    width: 40,
    height: 40,
  },
  locationErrorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF9E6',
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    gap: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: '#FFE4A0',
  },
  locationErrorText: {
    flex: 1,
    fontSize: 13,
    color: COLORS.text.secondary,
  },
  markerContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  userLocationMarker: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: 'rgba(66, 133, 244, 0.3)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  userLocationDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#4285F4',
    borderWidth: 2,
    borderColor: COLORS.white,
  },
  map: {
    flex: 1,
  },
  errorContainer: {
    position: 'absolute',
    top: 50,
    left: SPACING.md,
    right: SPACING.md,
    backgroundColor: COLORS.error,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    zIndex: 1000,
  },
  errorText: {
    color: COLORS.white,
    fontSize: 14,
    flex: 1,
    marginRight: SPACING.sm,
  },
  controls: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(255, 255, 255, 0.98)',
    borderTopLeftRadius: RADIUS.lg,
    borderTopRightRadius: RADIUS.lg,
    padding: SPACING.md,
    paddingBottom: SPACING.xl,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 10,
  },
  controlButtons: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginTop: SPACING.sm,
  },
  cancelButtonLarge: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.secondary,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    gap: SPACING.xs,
  },
  cancelButtonText: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  finishButtonLarge: {
    flex: 2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.primary,
    gap: SPACING.xs,
  },
  finishButtonText: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.white,
  },
  finishButtonTextDisabled: {
    color: COLORS.text.disabled,
  },
  finishButtonDisabled: {
    backgroundColor: COLORS.background.secondary,
  },
  actionButtons: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: SPACING.sm,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
  },
  actionButtonText: {
    marginLeft: SPACING.xs,
    fontSize: 14,
    color: COLORS.text.primary,
  },
  actionButtonTextDisabled: {
    color: COLORS.text.disabled,
  },
  instructions: {
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
  },
  instructionText: {
    fontSize: 12,
    color: COLORS.text.secondary,
    textAlign: 'center',
    lineHeight: 16,
  },
});

export default MapLibreNativeTerritoryDrawing;
