import React, { useState } from 'react';
import {
  View,
  StyleSheet,
  TouchableOpacity,
  Text,
  Alert,
  ScrollView,
  TextInput,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, SPACING, RADIUS, TYPOGRAPHY } from '../constants/Colors';

interface Point {
  latitude: number;
  longitude: number;
}

interface WebTerritoryDrawingProps {
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

const WebTerritoryDrawing: React.FC<WebTerritoryDrawingProps> = ({
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
  const [manualLat, setManualLat] = useState('');
  const [manualLng, setManualLng] = useState('');
  const [error, setError] = useState<string | null>(null);

  // Default DC area coordinates for reference
  const defaultCenter = { latitude: 38.8977, longitude: -77.0365 };
  const samplePoints = [
    { latitude: 38.8977, longitude: -77.0365 }, // White House
    { latitude: 38.8985, longitude: -77.0350 }, // Near White House
    { latitude: 38.8965, longitude: -77.0340 }, // Another nearby point
    { latitude: 38.8950, longitude: -77.0360 }, // Closing point area
  ];

  React.useEffect(() => {
    if (isDrawingMode) {
      onMapReady();
    }
  }, [isDrawingMode, onMapReady]);

  const handleAddManualPoint = () => {
    const lat = parseFloat(manualLat);
    const lng = parseFloat(manualLng);

    if (isNaN(lat) || isNaN(lng)) {
      setError('Please enter valid latitude and longitude numbers');
      return;
    }

    if (lat < -90 || lat > 90) {
      setError('Latitude must be between -90 and 90');
      return;
    }

    if (lng < -180 || lng > 180) {
      setError('Longitude must be between -180 and 180');
      return;
    }

    const newPoint: Point = { latitude: lat, longitude: lng };
    setDrawingPoints(prev => [...prev, newPoint]);
    setManualLat('');
    setManualLng('');
    setError(null);
    console.log('🗺️ Added manual point:', newPoint);
  };

  const handleAddSamplePoint = (point: Point) => {
    setDrawingPoints(prev => [...prev, point]);
    setError(null);
    console.log('🗺️ Added sample point:', point);
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

    // Convert to the expected format
    const coordinates = drawingPoints.map(point => ({
      lat: point.latitude,
      lng: point.longitude,
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

  if (!isDrawingMode) {
    return null;
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity
          style={styles.cancelButton}
          onPress={handleCancelDrawing}
        >
          <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>
          {drawingPoints.length === 0 
            ? "Add territory boundary points" 
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

      <ScrollView style={styles.content} contentContainerStyle={styles.contentContainer}>
        {/* Instructions */}
        <View style={styles.instructionBox}>
          <MaterialIcons name="info" size={20} color={COLORS.info} />
          <Text style={styles.instructionText}>
            Add boundary points to create a territory. You can use sample DC area points or enter coordinates manually.
          </Text>
        </View>

        {/* Error Display */}
        {error && (
          <View style={styles.errorBox}>
            <MaterialIcons name="error" size={20} color={COLORS.error} />
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        {/* Sample Points */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Quick Add (DC Area)</Text>
          <Text style={styles.sectionSubtitle}>Add sample points around Washington DC</Text>
          
          {samplePoints.map((point, index) => (
            <TouchableOpacity
              key={index}
              style={styles.samplePointButton}
              onPress={() => handleAddSamplePoint(point)}
            >
              <View style={styles.pointInfo}>
                <Text style={styles.pointName}>Point {index + 1}</Text>
                <Text style={styles.pointCoords}>
                  {point.latitude.toFixed(4)}, {point.longitude.toFixed(4)}
                </Text>
              </View>
              <MaterialIcons name="add" size={20} color={COLORS.primary} />
            </TouchableOpacity>
          ))}
        </View>

        {/* Manual Coordinate Entry */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Manual Coordinate Entry</Text>
          <Text style={styles.sectionSubtitle}>Enter exact latitude and longitude</Text>
          
          <View style={styles.inputGroup}>
            <View style={styles.inputRow}>
              <Text style={styles.inputLabel}>Latitude:</Text>
              <TextInput
                style={styles.input}
                value={manualLat}
                onChangeText={setManualLat}
                placeholder="38.8977"
                placeholderTextColor={COLORS.text.secondary}
                keyboardType="numeric"
              />
            </View>
            
            <View style={styles.inputRow}>
              <Text style={styles.inputLabel}>Longitude:</Text>
              <TextInput
                style={styles.input}
                value={manualLng}
                onChangeText={setManualLng}
                placeholder="-77.0365"
                placeholderTextColor={COLORS.text.secondary}
                keyboardType="numeric"
              />
            </View>
            
            <TouchableOpacity
              style={styles.addButton}
              onPress={handleAddManualPoint}
            >
              <MaterialIcons name="add-location" size={20} color={COLORS.white} />
              <Text style={styles.addButtonText}>Add Point</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Current Points */}
        {drawingPoints.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Current Boundary Points</Text>
            
            {drawingPoints.map((point, index) => (
              <View key={index} style={styles.currentPoint}>
                <View style={styles.pointNumber}>
                  <Text style={styles.pointNumberText}>{index + 1}</Text>
                </View>
                <Text style={styles.currentPointCoords}>
                  {point.latitude.toFixed(6)}, {point.longitude.toFixed(6)}
                </Text>
              </View>
            ))}
          </View>
        )}

        {/* Action Buttons */}
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
              Undo Last
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
      </ScrollView>
    </View>
  );
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
  content: {
    flex: 1,
  },
  contentContainer: {
    padding: SPACING.md,
  },
  instructionBox: {
    flexDirection: 'row',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.md,
    alignItems: 'center',
  },
  instructionText: {
    flex: 1,
    fontSize: 14,
    color: COLORS.text.secondary,
    marginLeft: SPACING.sm,
    lineHeight: 20,
  },
  errorBox: {
    flexDirection: 'row',
    backgroundColor: '#FEE2E2',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.md,
    alignItems: 'center',
  },
  errorText: {
    flex: 1,
    fontSize: 14,
    color: COLORS.error,
    marginLeft: SPACING.sm,
  },
  section: {
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  sectionSubtitle: {
    fontSize: 14,
    color: COLORS.text.secondary,
    marginBottom: SPACING.md,
  },
  samplePointButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
  },
  pointInfo: {
    flex: 1,
  },
  pointName: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  pointCoords: {
    fontSize: 14,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  inputGroup: {
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  inputLabel: {
    fontSize: 14,
    color: COLORS.text.primary,
    width: 80,
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    padding: SPACING.sm,
    fontSize: 14,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.primary,
  },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.primary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
  },
  addButtonText: {
    color: COLORS.white,
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    marginLeft: SPACING.sm,
  },
  currentPoint: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
  },
  pointNumber: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  pointNumberText: {
    fontSize: 12,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.white,
  },
  currentPointCoords: {
    flex: 1,
    fontSize: 14,
    color: COLORS.text.primary,
  },
  actionButtons: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingTop: SPACING.md,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.secondary,
  },
  actionButtonText: {
    marginLeft: SPACING.xs,
    fontSize: 14,
    color: COLORS.text.primary,
  },
  actionButtonTextDisabled: {
    color: COLORS.text.disabled,
  },
});

export default WebTerritoryDrawing;
