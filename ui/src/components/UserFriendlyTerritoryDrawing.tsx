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

// Web map imports ONLY - no native imports
import { MapContainer, TileLayer, Polygon, Marker, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L, { Icon } from 'leaflet';

// Fix for Leaflet default markers in web - more robust fix
const DefaultIcon = new Icon({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

L.Marker.prototype.options.icon = DefaultIcon;

// Add custom CSS to fix map rendering issues
if (Platform.OS === 'web') {
  const style = document.createElement('style');
  style.textContent = `
    .leaflet-container {
      background: #f0f0f0 !important;
      outline: none !important;
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
    .custom-numbered-marker {
      background: transparent !important;
      border: none !important;
    }
    .leaflet-container a.leaflet-popup-close-button {
      color: #333 !important;
    }
  `;
  document.head.appendChild(style);
}

interface Point {
  lat: number;
  lng: number;
}

interface UserFriendlyTerritoryDrawingProps {
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

// Web map events component
const WebMapEvents = ({ onMapClick }: { onMapClick: (lat: number, lng: number) => void }) => {
  useMapEvents({
    click: (e) => {
      onMapClick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
};

// Web-only map component - no native imports
const WebTerritoryMap: React.FC<UserFriendlyTerritoryDrawingProps> = ({
  isDrawingMode,
  territoryName,
  onPolygonDrawn,
  onStopDrawing,
  territories,
  onMapReady,
}) => {
  const [drawingPoints, setDrawingPoints] = useState<Point[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [mapKey, setMapKey] = useState(0); // Force re-render when needed

  // Default to Washington DC area
  const defaultCenter = { lat: 38.8977, lng: -77.0365 };
  const defaultZoom = 13;

  useEffect(() => {
    // Force map re-render when component mounts or territories change
    setMapKey(prev => prev + 1);
    onMapReady();
  }, [onMapReady, territories.length]);

  const handleMapClick = (lat: number, lng: number) => {
    if (!isDrawingMode) return;
    
    const newPoint: Point = { lat, lng };
    setDrawingPoints(prev => [...prev, newPoint]);
    setError(null);
    console.log('🗺️ Added point from map click:', newPoint);
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

    console.log('🗺️ Web territory drawing completed with', coordinates.length, 'points');
    onPolygonDrawn(coordinates);
    setDrawingPoints([]);
    setError(null);
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

      {/* Map Container */}
      <View style={styles.mapContainer}>
        <div 
          key={mapKey}
          style={styles.leafletMapWrapper}
        >
          <MapContainer
            center={[defaultCenter.lat, defaultCenter.lng]}
            zoom={defaultZoom}
            style={styles.leafletMap}
            whenReady={() => {
              console.log('🗺️ Map is ready');
              onMapReady();
            }}
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
            
            {/* Existing territories */}
            {territories.map(territory => (
              <Polygon
                key={territory.id}
                positions={territory.coordinates.map(coord => [coord.lat, coord.lng])}
                pathOptions={{ color: territory.color, fillOpacity: 0.3 }}
              />
            ))}

            {/* Drawing mode */}
            {isDrawingMode && (
              <>
                <WebMapEvents onMapClick={handleMapClick} />
                
                {/* Current drawing polygon */}
                {drawingPoints.length > 0 && (
                  <Polygon
                    positions={drawingPoints.map(point => [point.lat, point.lng])}
                    pathOptions={{ color: COLORS.primary, fillOpacity: 0.5, weight: 2 }}
                  />
                )}
                
                {/* Point markers - using numbered markers */}
                {drawingPoints.map((point, index) => (
                  <Marker
                    key={index}
                    position={[point.lat, point.lng]}
                    icon={L.divIcon({
                      className: 'custom-numbered-marker',
                      html: `<div style="
                        background: ${COLORS.primary}; 
                        color: white; 
                        border-radius: 50%; 
                        width: 30px; 
                        height: 30px; 
                        display: flex; 
                        align-items: center; 
                        justify-content: center; 
                        font-size: 14px; 
                        font-weight: bold;
                        border: 2px solid white;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                        z-index: 1000;
                        position: relative;
                      ">${index + 1}</div>`,
                      iconSize: [30, 30],
                      iconAnchor: [15, 15],
                      popupAnchor: [0, -15],
                    })}
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
              Undo Last
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
              Clear All
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

// Native fallback component - shows message for native platforms
const NativeFallback: React.FC<UserFriendlyTerritoryDrawingProps> = (props) => {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={props.onStopDrawing}>
          <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Map Drawing</Text>
        <View style={{ width: 24 }} />
      </View>
      
      <View style={styles.fallbackContainer}>
        <MaterialIcons name="warning" size={48} color={COLORS.warning} />
        <Text style={styles.fallbackTitle}>Native Map Drawing</Text>
        <Text style={styles.fallbackText}>
          Map drawing is currently optimized for web. On mobile devices, please use the web version for the best territory creation experience.
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
const UserFriendlyTerritoryDrawing: React.FC<UserFriendlyTerritoryDrawingProps> = (props) => {
  if (Platform.OS === 'web') {
    return <WebTerritoryMap {...props} />;
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
  leafletMapWrapper: {
    height: '100%',
    width: '100%',
    position: 'relative',
    overflow: 'hidden',
  },
  leafletMap: {
    height: '100%',
    width: '100%',
    zIndex: 1,
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
  pointMarker: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  pointMarkerText: {
    fontSize: 12,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.white,
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

export default UserFriendlyTerritoryDrawing;
