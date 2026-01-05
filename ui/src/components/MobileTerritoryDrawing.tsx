import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  Alert,
  ActivityIndicator,
  Keyboard,
} from 'react-native';
import { WebView } from 'react-native-webview';
import { MaterialIcons } from '@expo/vector-icons';
import * as Location from 'expo-location';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';

interface Territory {
  id: string;
  name: string;
  coordinates: Array<{lat: number, lng: number}>;
  color: string;
  createdAt: number;
  isActive: boolean;
  source?: 'manual' | 'imported';
}

interface MobileTerritoryDrawingProps {
  isDrawingMode: boolean;
  territoryName: string;
  onTerritoryNameChange: (name: string) => void;
  onPolygonDrawn: (coordinates: Array<{lat: number, lng: number}>) => void;
  onStopDrawing: () => void;
  territories: Territory[];
  mapReady: boolean;
  onMapReady: () => void;
}

const MobileTerritoryDrawing: React.FC<MobileTerritoryDrawingProps> = ({
  isDrawingMode,
  territoryName,
  onTerritoryNameChange,
  onPolygonDrawn,
  onStopDrawing,
  territories,
  mapReady,
  onMapReady,
}) => {
  const [webViewRef, setWebViewRef] = useState<WebView | null>(null);
  const [userLocation, setUserLocation] = useState<{lat: number, lng: number} | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [locationLoading, setLocationLoading] = useState(true);

  // Get user's current location on mount
  useEffect(() => {
    getCurrentLocation();
  }, []);

  const getCurrentLocation = async () => {
    try {
      setLocationLoading(true);
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        console.log('Location permission denied');
        setLocationLoading(false);
        return;
      }

      const location = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced,
      });

      const coords = {
        lat: location.coords.latitude,
        lng: location.coords.longitude,
      };
      setUserLocation(coords);

      // Center map on user location when map is ready
      if (webViewRef && mapReady) {
        webViewRef.postMessage(JSON.stringify({
          type: 'centerOnLocation',
          lat: coords.lat,
          lng: coords.lng,
          zoom: 15
        }));
      }
    } catch (error) {
      console.error('Error getting location:', error);
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

        // Move map to searched location
        if (webViewRef) {
          webViewRef.postMessage(JSON.stringify({
            type: 'centerOnLocation',
            lat: coords.lat,
            lng: coords.lng,
            zoom: 16,
            placeName: display_name
          }));
        }
      } else {
        Alert.alert('Not Found', 'Could not find the location. Try a different search term.');
      }
    } catch (error) {
      console.error('Search error:', error);
      Alert.alert('Error', 'Failed to search location. Please try again.');
    } finally {
      setIsSearching(false);
    }
  };

  const handleWebViewMessage = (event: any) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      console.log('📱 Mobile territory drawing message:', data);
      
      if (data.type === 'mapReady') {
        console.log('🗺️ Mobile territory map is ready');
        onMapReady();
        // Center on user location when map is ready
        if (userLocation) {
          setTimeout(() => {
            if (webViewRef) {
              webViewRef.postMessage(JSON.stringify({
                type: 'centerOnLocation',
                lat: userLocation.lat,
                lng: userLocation.lng,
                zoom: 15
              }));
            }
          }, 500);
        }
      } else if (data.type === 'polygonDrawn') {
        console.log('🗺️ Mobile polygon drawn:', data.coordinates);
        onPolygonDrawn(data.coordinates);
      }
    } catch (error) {
      console.error('Error parsing WebView message:', error);
    }
  };

  const startDrawingMode = () => {
    if (webViewRef) {
      webViewRef.postMessage(JSON.stringify({ type: 'startDrawing' }));
    }
  };

  const stopDrawingMode = () => {
    if (webViewRef) {
      webViewRef.postMessage(JSON.stringify({ type: 'stopDrawing' }));
    }
    onStopDrawing();
  };

  const drawTerritoryOnMap = (territory: Territory) => {
    if (webViewRef && mapReady) {
      webViewRef.postMessage(JSON.stringify({
        type: 'drawTerritory',
        territory: territory
      }));
    }
  };

  useEffect(() => {
    if (mapReady && webViewRef) {
      // Draw existing territories
      territories.forEach(territory => {
        drawTerritoryOnMap(territory);
      });
    }
  }, [mapReady, territories.length]); // Only depend on territories.length to prevent constant re-renders

  useEffect(() => {
    if (webViewRef && mapReady) {
      if (isDrawingMode) {
        startDrawingMode();
      } else {
        stopDrawingMode();
      }
    }
  }, [isDrawingMode, mapReady]);

  // Get initial center - use user location if available
  const initialLat = userLocation?.lat || 20.5937;
  const initialLng = userLocation?.lng || 78.9629;

  const getMapHTML = () => `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.css" />
        <style>
            body {
                margin: 0;
                padding: 0;
                font-family: Arial, sans-serif;
                touch-action: manipulation;
            }
            #map {
                height: 100vh;
                width: 100%;
                touch-action: manipulation;
            }
            .leaflet-control-zoom {
                font-size: 18px !important;
            }
            .leaflet-control-zoom a {
                width: 40px !important;
                height: 40px !important;
                line-height: 40px !important;
                font-size: 20px !important;
            }
            .leaflet-draw-toolbar {
                margin-top: 10px !important;
            }
            .leaflet-draw-toolbar a {
                width: 40px !important;
                height: 40px !important;
                line-height: 40px !important;
            }
            .search-marker-popup {
                font-weight: bold;
                color: #002b5b;
            }
        </style>
    </head>
    <body>
        <div id="map"></div>
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.js"></script>
        <script>
            let map = null;
            let drawControl = null;
            let drawnItems = null;
            let isDrawingMode = false;
            let territories = [];
            let searchMarker = null;

            function initMap() {
                console.log('🗺️ Initializing mobile territory drawing map');

                // Initialize map centered on user location or default
                map = L.map('map', {
                    zoomControl: true,
                    attributionControl: true,
                    scrollWheelZoom: true,
                    doubleClickZoom: true,
                    touchZoom: true,
                    dragging: true,
                    tap: true,
                    tapTolerance: 15
                }).setView([${initialLat}, ${initialLng}], 14);

                // Add OpenStreetMap tile layer - this shows roads, buildings, etc.
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '© OpenStreetMap contributors',
                    maxZoom: 19
                }).addTo(map);

                drawnItems = new L.FeatureGroup();
                map.addLayer(drawnItems);

                drawControl = new L.Control.Draw({
                    position: 'topright',
                    draw: {
                        polygon: {
                            allowIntersection: false,
                            drawError: {
                                color: '#e1e100',
                                message: '<strong>Error:</strong> Shape edges cannot cross!'
                            },
                            shapeOptions: {
                                color: '#002b5b',
                                weight: 3,
                                opacity: 0.8,
                                fillOpacity: 0.3
                            }
                        },
                        rectangle: {
                            shapeOptions: {
                                color: '#002b5b',
                                weight: 3,
                                opacity: 0.8,
                                fillOpacity: 0.3
                            }
                        },
                        circle: false,
                        circlemarker: false,
                        marker: false,
                        polyline: false
                    },
                    edit: {
                        featureGroup: drawnItems,
                        remove: true
                    }
                });

                map.on(L.Draw.Event.CREATED, function (e) {
                    const layer = e.layer;
                    drawnItems.addLayer(layer);

                    let coordinates = [];
                    if (e.layerType === 'polygon') {
                        coordinates = layer.getLatLngs()[0].map(latlng => ({
                            lat: latlng.lat,
                            lng: latlng.lng
                        }));
                    } else if (e.layerType === 'rectangle') {
                        const bounds = layer.getBounds();
                        coordinates = [
                            { lat: bounds.getNorth(), lng: bounds.getWest() },
                            { lat: bounds.getNorth(), lng: bounds.getEast() },
                            { lat: bounds.getSouth(), lng: bounds.getEast() },
                            { lat: bounds.getSouth(), lng: bounds.getWest() }
                        ];
                    }

                    console.log('🗺️ Mobile territory drawn with', coordinates.length, 'points');

                    if (window.ReactNativeWebView) {
                        window.ReactNativeWebView.postMessage(JSON.stringify({
                            type: 'polygonDrawn',
                            coordinates: coordinates
                        }));
                    }
                });

                console.log('✅ Mobile territory map initialized with OpenStreetMap tiles');

                if (window.ReactNativeWebView) {
                    window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'mapReady' }));
                }
            }

            function startDrawing() {
                if (!isDrawingMode && map) {
                    map.addControl(drawControl);
                    isDrawingMode = true;
                    console.log('✏️ Mobile drawing mode enabled');
                }
            }

            function stopDrawing() {
                if (isDrawingMode && map) {
                    map.removeControl(drawControl);
                    isDrawingMode = false;
                    console.log('🛑 Mobile drawing mode disabled');
                }
            }

            function drawTerritory(territory) {
                if (!map) return;
                console.log('🗺️ Drawing mobile territory:', territory.name);

                const coordinates = territory.coordinates.map(coord => [coord.lat, coord.lng]);

                const polygon = L.polygon(coordinates, {
                    color: territory.color,
                    weight: 3,
                    opacity: 0.8,
                    fillOpacity: 0.3,
                    fillColor: territory.color
                }).addTo(map);

                const popupContent = '<div style="font-family: Arial, sans-serif; text-align: center;">' +
                    '<div style="font-weight: bold; color: #002b5b; margin-bottom: 4px;">' + territory.name + '</div>' +
                    '<div style="color: #64748b; font-size: 12px;">' +
                    (territory.assignedWorker ? '👤 ' + territory.assignedWorker.name : '⚪ Unassigned') +
                    '</div></div>';

                polygon.bindPopup(popupContent);

                territories.push({
                    id: territory.id,
                    polygon: polygon,
                    data: territory
                });

                // Fit map to show this territory
                if (coordinates.length > 0) {
                    map.fitBounds(polygon.getBounds(), { padding: [20, 20] });
                }
            }

            // Center map on location with optional marker
            function centerOnLocation(lat, lng, zoom, placeName) {
                if (!map) return;
                map.setView([lat, lng], zoom || 15);

                // Add a marker for searched locations
                if (placeName) {
                    if (searchMarker) {
                        map.removeLayer(searchMarker);
                    }
                    searchMarker = L.marker([lat, lng]).addTo(map);
                    searchMarker.bindPopup('<div class="search-marker-popup">' + placeName + '</div>').openPopup();
                }
            }

            // Listen for messages from React Native (iOS)
            document.addEventListener('message', function(event) {
                try {
                    const data = JSON.parse(event.data);
                    console.log('📱 Map received message:', data.type);
                    if (data.type === 'startDrawing') {
                        startDrawing();
                    } else if (data.type === 'stopDrawing') {
                        stopDrawing();
                    } else if (data.type === 'drawTerritory') {
                        drawTerritory(data.territory);
                    } else if (data.type === 'centerOnLocation') {
                        centerOnLocation(data.lat, data.lng, data.zoom, data.placeName);
                    }
                } catch (error) {
                    console.error('Error parsing message:', error);
                }
            });

            // For Android
            window.addEventListener('message', function(event) {
                try {
                    const data = JSON.parse(event.data);
                    console.log('📱 Map received window message:', data.type);
                    if (data.type === 'startDrawing') {
                        startDrawing();
                    } else if (data.type === 'stopDrawing') {
                        stopDrawing();
                    } else if (data.type === 'drawTerritory') {
                        drawTerritory(data.territory);
                    } else if (data.type === 'centerOnLocation') {
                        centerOnLocation(data.lat, data.lng, data.zoom, data.placeName);
                    }
                } catch (error) {
                    console.error('Error parsing window message:', error);
                }
            });

            // Initialize map when DOM is ready
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', initMap);
            } else {
                initMap();
            }
        </script>
    </body>
    </html>
  `;

  return (
    <View style={styles.container}>
      {/* Search Bar - Always visible */}
      <View style={styles.searchContainer}>
        <View style={styles.searchInputContainer}>
          <MaterialIcons name="search" size={20} color={COLORS.textSecondary} style={styles.searchIcon} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search location..."
            value={searchQuery}
            onChangeText={setSearchQuery}
            onSubmitEditing={searchLocation}
            returnKeyType="search"
            placeholderTextColor={COLORS.textSecondary}
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

      {/* Drawing Controls */}
      {isDrawingMode && (
        <View style={styles.drawingControls}>
          <View style={styles.drawingHeader}>
            <Text style={styles.drawingTitle}>Draw Territory</Text>
            <TouchableOpacity
              style={styles.stopButton}
              onPress={stopDrawingMode}
            >
              <MaterialIcons name="close" size={20} color={COLORS.error} />
            </TouchableOpacity>
          </View>

          <TextInput
            style={styles.territoryNameInput}
            placeholder="Enter territory name..."
            value={territoryName}
            onChangeText={onTerritoryNameChange}
          />

          <Text style={styles.instructions}>
            Use the drawing tools on the map to create territory boundaries
          </Text>
        </View>
      )}

      {/* Map */}
      <WebView
        ref={(ref) => setWebViewRef(ref)}
        source={{ html: getMapHTML() }}
        style={styles.webView}
        onMessage={handleWebViewMessage}
        javaScriptEnabled={true}
        domStorageEnabled={true}
        startInLoadingState={true}
        scalesPageToFit={true}
        scrollEnabled={false}
        bounces={false}
        originWhitelist={['*']}
        mixedContentMode="always"
        allowsInlineMediaPlayback={true}
        mediaPlaybackRequiresUserAction={false}
        allowUniversalAccessFromFileURLs={true}
        allowFileAccessFromFileURLs={true}
        onError={(syntheticEvent) => {
          const { nativeEvent } = syntheticEvent;
          console.error('WebView error:', nativeEvent);
        }}
        onHttpError={(syntheticEvent) => {
          const { nativeEvent } = syntheticEvent;
          console.error('WebView HTTP error:', nativeEvent);
        }}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.sm,
    backgroundColor: COLORS.cardBackground,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderLight,
    gap: SPACING.sm,
  },
  searchInputContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.borderLight,
    paddingHorizontal: SPACING.sm,
  },
  searchIcon: {
    marginRight: SPACING.xs,
  },
  searchInput: {
    flex: 1,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.md,
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
  drawingControls: {
    backgroundColor: COLORS.cardBackground,
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderLight,
  },
  drawingHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  drawingTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.primary,
  },
  stopButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.full,
    backgroundColor: `${COLORS.error}20`,
  },
  territoryNameInput: {
    borderWidth: 1,
    borderColor: COLORS.borderLight,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.md,
    marginBottom: SPACING.sm,
    backgroundColor: COLORS.white,
  },
  instructions: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    fontStyle: 'italic',
  },
  webView: {
    flex: 1,
  },
});

export default MobileTerritoryDrawing;
