import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  Modal,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  TextInput,
  Platform,
  Alert,
  ActivityIndicator,
  KeyboardAvoidingView,
  Dimensions,
} from 'react-native';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import { MaterialIcons } from '@expo/vector-icons';
import * as Location from 'expo-location';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

interface LocationData {
  latitude: number;
  longitude: number;
  address: string;
}

interface LocationPickerModalProps {
  visible: boolean;
  onClose: () => void;
  onLocationSelected: (location: LocationData) => void;
  initialLocation?: {
    latitude: number;
    longitude: number;
  };
  initialAddress?: string;
}

const LocationPickerModal: React.FC<LocationPickerModalProps> = ({
  visible,
  onClose,
  onLocationSelected,
  initialLocation,
  initialAddress = '',
}) => {
  const mapRef = useRef<MapView>(null);
  const [selectedLocation, setSelectedLocation] = useState<{
    latitude: number;
    longitude: number;
  } | null>(initialLocation || null);
  const [address, setAddress] = useState(initialAddress);
  const [isLoading, setIsLoading] = useState(false);
  const [isReverseGeocoding, setIsReverseGeocoding] = useState(false);
  const [region, setRegion] = useState({
    latitude: initialLocation?.latitude || 37.78825,
    longitude: initialLocation?.longitude || -122.4324,
    latitudeDelta: 0.01,
    longitudeDelta: 0.01,
  });

  useEffect(() => {
    if (visible && !initialLocation) {
      getCurrentLocation();
    }
  }, [visible]);

  useEffect(() => {
    if (initialLocation) {
      setSelectedLocation(initialLocation);
      setRegion({
        ...region,
        latitude: initialLocation.latitude,
        longitude: initialLocation.longitude,
      });
    }
    if (initialAddress) {
      setAddress(initialAddress);
    }
  }, [initialLocation, initialAddress]);

  const getCurrentLocation = async () => {
    setIsLoading(true);
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Location permission is required to use this feature.');
        setIsLoading(false);
        return;
      }

      const location = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.High,
      });

      const newLocation = {
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      };

      setSelectedLocation(newLocation);
      setRegion({
        ...region,
        latitude: newLocation.latitude,
        longitude: newLocation.longitude,
      });

      // Animate to the location
      mapRef.current?.animateToRegion({
        latitude: newLocation.latitude,
        longitude: newLocation.longitude,
        latitudeDelta: 0.01,
        longitudeDelta: 0.01,
      });

      // Reverse geocode to get address
      await reverseGeocode(newLocation.latitude, newLocation.longitude);
    } catch (error) {
      console.error('Error getting current location:', error);
      Alert.alert('Error', 'Failed to get current location.');
    } finally {
      setIsLoading(false);
    }
  };

  const reverseGeocode = async (latitude: number, longitude: number) => {
    setIsReverseGeocoding(true);
    try {
      const results = await Location.reverseGeocodeAsync({
        latitude,
        longitude,
      });

      if (results.length > 0) {
        const result = results[0];
        const addressParts = [
          result.streetNumber,
          result.street,
          result.city,
          result.region,
          result.postalCode,
        ].filter(Boolean);
        const formattedAddress = addressParts.join(', ');
        setAddress(formattedAddress || `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`);
      }
    } catch (error) {
      console.error('Error reverse geocoding:', error);
      setAddress(`${latitude.toFixed(6)}, ${longitude.toFixed(6)}`);
    } finally {
      setIsReverseGeocoding(false);
    }
  };

  const handleMapPress = async (event: any) => {
    const { latitude, longitude } = event.nativeEvent.coordinate;
    const newLocation = { latitude, longitude };
    setSelectedLocation(newLocation);
    await reverseGeocode(latitude, longitude);
  };

  const handleMarkerDrag = async (event: any) => {
    const { latitude, longitude } = event.nativeEvent.coordinate;
    const newLocation = { latitude, longitude };
    setSelectedLocation(newLocation);
    await reverseGeocode(latitude, longitude);
  };

  const handleConfirm = () => {
    if (!selectedLocation) {
      Alert.alert('No Location Selected', 'Please select a location on the map.');
      return;
    }

    onLocationSelected({
      latitude: selectedLocation.latitude,
      longitude: selectedLocation.longitude,
      address: address || `${selectedLocation.latitude.toFixed(6)}, ${selectedLocation.longitude.toFixed(6)}`,
    });
    onClose();
  };

  const handleSearchAddress = async () => {
    if (!address.trim()) return;

    setIsLoading(true);
    try {
      const results = await Location.geocodeAsync(address);
      if (results.length > 0) {
        const { latitude, longitude } = results[0];
        const newLocation = { latitude, longitude };
        setSelectedLocation(newLocation);

        // Update region state to move the map
        const newRegion = {
          latitude,
          longitude,
          latitudeDelta: 0.01,
          longitudeDelta: 0.01,
        };
        setRegion(newRegion);

        // Also animate for smooth transition
        mapRef.current?.animateToRegion(newRegion, 500);
      } else {
        Alert.alert('Not Found', 'Could not find the specified address.');
      }
    } catch (error) {
      console.error('Error geocoding address:', error);
      Alert.alert('Error', 'Failed to search for address.');
    } finally {
      setIsLoading(false);
    }
  };

  // Render Map UI
  const renderMapUI = () => (
    <KeyboardAvoidingView
      style={styles.content}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      {/* Search Bar */}
      <View style={styles.searchContainer}>
        <View style={styles.searchInputContainer}>
          <MaterialIcons name="search" size={20} color={COLORS.text.secondary} />
          <TextInput
            style={styles.searchInput}
            value={address}
            onChangeText={setAddress}
            placeholder="Enter address or search..."
            placeholderTextColor={COLORS.text.secondary}
            onSubmitEditing={handleSearchAddress}
            returnKeyType="search"
          />
          {isReverseGeocoding && (
            <ActivityIndicator size="small" color={COLORS.primary} />
          )}
        </View>
        <TouchableOpacity
          style={styles.searchButton}
          onPress={handleSearchAddress}
          disabled={isLoading}
        >
          <MaterialIcons name="search" size={20} color={COLORS.background.primary} />
        </TouchableOpacity>
      </View>

      {/* Map */}
      <View style={styles.mapContainer}>
        {isLoading && (
          <View style={styles.loadingOverlay}>
            <ActivityIndicator size="large" color={COLORS.primary} />
            <Text style={styles.loadingText}>Getting location...</Text>
          </View>
        )}
        <MapView
          ref={mapRef}
          style={styles.map}
          provider={Platform.OS === 'android' ? PROVIDER_GOOGLE : undefined}
          region={region}
          onRegionChangeComplete={(newRegion) => setRegion(newRegion)}
          onPress={handleMapPress}
          showsUserLocation
          showsMyLocationButton={false}
        >
          {selectedLocation && Marker && (
            <Marker
              coordinate={selectedLocation}
              draggable
              onDragEnd={handleMarkerDrag}
            >
              <View style={styles.markerContainer}>
                <MaterialIcons name="location-on" size={40} color={COLORS.error} />
              </View>
            </Marker>
          )}
        </MapView>

        {/* Map Controls */}
        <View style={styles.mapControls}>
          <TouchableOpacity
            style={styles.mapControlButton}
            onPress={getCurrentLocation}
          >
            <MaterialIcons name="my-location" size={24} color={COLORS.primary} />
          </TouchableOpacity>
        </View>

        {/* Instructions */}
        <View style={styles.instructionsContainer}>
          <MaterialIcons name="touch-app" size={16} color={COLORS.text.secondary} />
          <Text style={styles.instructionsText}>
            Tap on map to select location or drag the marker
          </Text>
        </View>
      </View>

      {/* Selected Location Info */}
      {selectedLocation && (
        <View style={styles.locationInfo}>
          <View style={styles.locationInfoHeader}>
            <MaterialIcons name="place" size={20} color={COLORS.primary} />
            <Text style={styles.locationInfoTitle}>Selected Location</Text>
          </View>
          <Text style={styles.locationAddress} numberOfLines={2}>
            {address || 'Loading address...'}
          </Text>
          <Text style={styles.locationCoords}>
            {selectedLocation.latitude.toFixed(6)}, {selectedLocation.longitude.toFixed(6)}
          </Text>
        </View>
      )}
    </KeyboardAvoidingView>
  );

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="fullScreen"
      onRequestClose={onClose}
    >
      <SafeAreaView style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose} style={styles.headerButton}>
            <MaterialIcons name="close" size={24} color={COLORS.text.secondary} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Select Location</Text>
          <TouchableOpacity
            onPress={handleConfirm}
            style={[styles.headerButton, styles.confirmButton]}
            disabled={!selectedLocation}
          >
            <Text style={[
              styles.confirmButtonText,
              !selectedLocation && styles.confirmButtonTextDisabled
            ]}>
              Confirm
            </Text>
          </TouchableOpacity>
        </View>

        {renderMapUI()}
      </SafeAreaView>
    </Modal>
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
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
    backgroundColor: COLORS.background.surface,
  },
  headerButton: {
    padding: SPACING.sm,
  },
  headerTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  confirmButton: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
  },
  confirmButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.background.primary,
  },
  confirmButtonTextDisabled: {
    opacity: 0.5,
  },
  content: {
    flex: 1,
  },
  searchContainer: {
    flexDirection: 'row',
    padding: SPACING.md,
    backgroundColor: COLORS.background.surface,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  searchInputContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    marginRight: SPACING.sm,
  },
  searchInput: {
    flex: 1,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.sm,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
  },
  searchButton: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  mapContainer: {
    flex: 1,
    position: 'relative',
  },
  map: {
    flex: 1,
    width: SCREEN_WIDTH,
    minHeight: SCREEN_HEIGHT * 0.4,
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
  },
  loadingText: {
    marginTop: SPACING.md,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
  },
  markerContainer: {
    alignItems: 'center',
  },
  mapControls: {
    position: 'absolute',
    right: SPACING.md,
    top: SPACING.md,
  },
  mapControlButton: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.full,
    padding: SPACING.md,
    ...SHADOWS.md,
  },
  instructionsContainer: {
    position: 'absolute',
    bottom: SPACING.md,
    left: SPACING.md,
    right: SPACING.md,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    borderRadius: RADIUS.md,
    padding: SPACING.sm,
  },
  instructionsText: {
    marginLeft: SPACING.xs,
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.background.primary,
  },
  locationInfo: {
    backgroundColor: COLORS.background.surface,
    padding: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.default,
  },
  locationInfoHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  locationInfoTitle: {
    marginLeft: SPACING.xs,
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  locationAddress: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  locationCoords: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
});

export default LocationPickerModal;
