import React, { useState, useRef } from 'react';
import {
  View,
  StyleSheet,
  TouchableOpacity,
  Text,
  Alert,
  Dimensions,
  Platform,
} from 'react-native';
import MapView, { 
  Polygon, 
  Circle, 
  Marker,
  PROVIDER_GOOGLE,
  PROVIDER_DEFAULT,
  Region 
} from 'react-native-maps';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, SPACING, RADIUS, TYPOGRAPHY } from '../constants/Colors';

const { width, height } = Dimensions.get('window');

interface Point {
  latitude: number;
  longitude: number;
}

interface NativeTerritoryDrawingProps {
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

const NativeTerritoryDrawing: React.FC<NativeTerritoryDrawingProps> = ({
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
  const [currentRegion, setCurrentRegion] = useState<Region>({
    latitude: 38.8977, // Washington DC
    longitude: -77.0365,
    latitudeDelta: 0.01,
    longitudeDelta: 0.01,
  });
  const [mapError, setMapError] = useState<string | null>(null);
  const mapRef = useRef<MapView>(null);

  // Default DC area for initial map center
  const initialRegion: Region = {
    latitude: 38.8977,
    longitude: -77.0365,
    latitudeDelta: 0.01,
    longitudeDelta: 0.01,
  };

  const handleMapPress = (event: any) => {
    if (!isDrawingMode) return;
    
    try {
      const { coordinate } = event.nativeEvent;
      console.log('🗺️ Map pressed at:', coordinate);
      
      const newPoint: Point = {
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
      };
      
      setDrawingPoints(prev => [...prev, newPoint]);
    } catch (error) {
      console.error('🗺️ Error handling map press:', error);
      setMapError('Failed to add point. Please try again.');
    }
  };

  const handleUndoPoint = () => {
    setDrawingPoints(prev => prev.slice(0, -1));
  };

  const handleClearAll = () => {
    setDrawingPoints([]);
  };

  const handleFinishDrawing = () => {
    if (drawingPoints.length < 3) {
      Alert.alert('Error', 'Please add at least 3 points to create a territory');
      return;
    }

    // Convert to the expected format
    const coordinates = drawingPoints.map(point => ({
      lat: point.latitude,
      lng: point.longitude,
    }));

    console.log('🗺️ Territory drawing completed with', coordinates.length, 'points');
    onPolygonDrawn(coordinates);
    setDrawingPoints([]);
  };

  const handleCancelDrawing = () => {
    setDrawingPoints([]);
    onStopDrawing();
  };

  // Convert existing territories to MapView format
  const existingTerritories = territories.map(territory => ({
    ...territory,
    coordinates: territory.coordinates.map(coord => ({
      latitude: coord.lat,
      longitude: coord.lng,
    })),
  }));

  return (
    <View style={styles.container}>
      {mapError && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>{mapError}</Text>
          <TouchableOpacity onPress={() => setMapError(null)}>
            <MaterialIcons name="close" size={20} color={COLORS.white} />
          </TouchableOpacity>
        </View>
      )}
      
      <MapView
        ref={mapRef}
        style={styles.map}
        provider={Platform.OS === 'android' ? PROVIDER_GOOGLE : PROVIDER_DEFAULT}
        initialRegion={initialRegion}
        onPress={handleMapPress}
        onMapReady={() => {
          console.log('🗺️ Native drawing map is ready');
          onMapReady();
        }}
        onRegionChangeComplete={setCurrentRegion}
      >
        {/* Show existing territories */}
        {existingTerritories.map((territory) => (
          <Polygon
            key={territory.id}
            coordinates={territory.coordinates}
            strokeColor={territory.color}
            fillColor={territory.color + '40'} // Add transparency
            strokeWidth={2}
          />
        ))}

        {/* Show current drawing */}
        {isDrawingMode && drawingPoints.length > 0 && (
          <>
            {/* Draw polygon if we have at least 3 points */}
            {drawingPoints.length >= 3 && (
              <Polygon
                coordinates={drawingPoints}
                strokeColor={COLORS.primary}
                fillColor={COLORS.primary + '40'}
                strokeWidth={2}
              />
            )}

            {/* Draw lines between points */}
            {drawingPoints.map((point, index) => {
              if (index === 0) return null;
              return (
                <MapView.Polyline
                  key={`line-${index}`}
                  coordinates={[drawingPoints[index - 1], point]}
                  strokeColor={COLORS.primary}
                  strokeWidth={2}
                />
              );
            })}

            {/* Draw markers for each point */}
            {drawingPoints.map((point, index) => (
              <Marker
                key={index}
                coordinate={point}
                title={`Point ${index + 1}`}
              >
                <View style={styles.pointMarker}>
                  <Text style={styles.pointText}>{index + 1}</Text>
                </View>
              </Marker>
            ))}
          </>
        )}
      </MapView>

      {/* Drawing Controls */}
      {isDrawingMode && (
        <View style={styles.controls}>
          <View style={styles.header}>
            <TouchableOpacity
              style={styles.cancelButton}
              onPress={handleCancelDrawing}
            >
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
            <Text style={styles.headerTitle}>
              {drawingPoints.length === 0 
                ? "Tap map to add points" 
                : `${drawingPoints.length} point${drawingPoints.length > 1 ? 's' : ''} added`
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
              <Text style={[
                styles.actionButtonText,
                drawingPoints.length === 0 && styles.actionButtonTextDisabled
              ]}>
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
              <Text style={[
                styles.actionButtonText,
                drawingPoints.length === 0 && styles.actionButtonTextDisabled
              ]}>
                Clear All
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.instructions}>
            <Text style={styles.instructionText}>
              Tap on the map to add boundary points. Add at least 3 points to create a territory.
            </Text>
          </View>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
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
    top: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
    borderBottomLeftRadius: RADIUS.md,
    borderBottomRightRadius: RADIUS.md,
    padding: SPACING.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.sm,
  },
  cancelButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
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
  pointMarker: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: COLORS.primary,
    borderWidth: 2,
    borderColor: COLORS.white,
    justifyContent: 'center',
    alignItems: 'center',
  },
  pointText: {
    fontSize: 12,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.white,
  },
});

export default NativeTerritoryDrawing;
