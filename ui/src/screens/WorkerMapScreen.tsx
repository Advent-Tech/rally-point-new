import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, Platform } from 'react-native';
import { FontAwesome, MaterialIcons } from '@expo/vector-icons';
import QuickDeliveryModal from '../components/QuickDeliveryModal';
import Icon from '../components/Icon';
import { BookDelivery } from '../types/ministry';

interface WorkerMapScreenProps {
  navigation: any;
  route: {
    params: {
      workerId: string;
      workerName: string;
    };
  };
}

interface WorkerLocation {
  latitude: number;
  longitude: number;
  timestamp: Date;
}

export default function WorkerMapScreen({ navigation, route }: WorkerMapScreenProps) {
  const { workerId, workerName } = route.params;
  const [workerLocation, setWorkerLocation] = useState<WorkerLocation | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());
  const [locationHistory, setLocationHistory] = useState<WorkerLocation[]>([]);
  const [showDeliveryModal, setShowDeliveryModal] = useState(false);
  const [recentDeliveries, setRecentDeliveries] = useState<BookDelivery[]>([]);
  const mapRef = useRef<any>(null);
  const markerRef = useRef<any>(null);

  useEffect(() => {
    console.log('WorkerMapScreen opened for:', workerName, 'ID:', workerId);

    // Real-time location updates would be handled through a service layer
    setIsLoading(false);

    return () => {};
  }, [workerId, workerName]);

  const openInGoogleMaps = () => {
    if (workerLocation) {
      const { latitude, longitude } = workerLocation;
      const url = Platform.select({
        ios: `maps:0,0?q=${latitude},${longitude}`,
        android: `geo:0,0?q=${latitude},${longitude}`,
        web: `https://www.google.com/maps?q=${latitude},${longitude}`,
      });
      
      if (Platform.OS === 'web') {
        window.open(url, '_blank');
      } else {
        // For mobile, you would use Linking.openURL(url)
        Alert.alert('Open in Maps', `Would open: ${url}`);
      }
    }
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const handleDeliveryLogged = (delivery: BookDelivery) => {
    setRecentDeliveries(prev => [delivery, ...prev.slice(0, 4)]); // Keep last 5 deliveries
    Alert.alert(
      'Delivery Logged!',
      `${delivery.deliveryType === 'door' ? 'Door-to-door' : 'Person-to-person'} delivery recorded successfully.`
    );
  };

  if (isLoading) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>Loading...</Text>
        </View>
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading worker location...</Text>
        </View>
      </View>
    );
  }

  if (!workerLocation) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>{workerName}</Text>
        </View>
        <View style={styles.noLocationContainer}>
          <Text style={styles.noLocationText}>📍</Text>
          <Text style={styles.noLocationTitle}>No Location Available</Text>
          <Text style={styles.noLocationSubtitle}>
            This worker hasn't shared their location yet or location tracking is disabled.
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <MaterialIcons name="arrow-back" size={24} color="#ffffff" />
        </TouchableOpacity>
        <Text style={styles.title}>{workerName}</Text>
        <TouchableOpacity onPress={openInGoogleMaps}>
          <Text style={styles.mapsButton}>🗺️</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.map}>
        <View style={styles.mapContainer}>
          <View style={styles.mapHeader}>
            <Text style={styles.mapTitle}>📍 Live Location Map</Text>
            <View style={styles.headerControls}>
              <TouchableOpacity
                style={styles.territoryButton}
                onPress={() => navigation.navigate('MyTerritory')}
              >
                <FontAwesome name="map-o" size={16} color="#3b82f6" />
                <Text style={styles.territoryButtonText}>My Territory</Text>
              </TouchableOpacity>
              <View style={styles.liveIndicator}>
                <View style={styles.liveDot} />
                <Text style={styles.liveText}>LIVE</Text>
              </View>
            </View>
          </View>

          <View style={styles.coordinateDisplay}>
            <Text style={styles.workerNameLarge}>{workerName}</Text>
            <View style={styles.coordinateBox}>
              <Text style={styles.coordinateLabel}>📍 GPS Coordinates</Text>
              <Text style={styles.coordinateValue}>
                Lat: {workerLocation.latitude.toFixed(6)}
              </Text>
              <Text style={styles.coordinateValue}>
                Lng: {workerLocation.longitude.toFixed(6)}
              </Text>
            </View>

            <View style={styles.mapButtons}>
              <TouchableOpacity
                style={styles.mapButton}
                onPress={() => {
                  const url = `https://www.google.com/maps?q=${workerLocation.latitude},${workerLocation.longitude}`;
                  window.open(url, '_blank');
                }}
              >
                <Text style={styles.mapButtonText}>�️ Google Maps</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.mapButton}
                onPress={() => {
                  const url = `https://www.openstreetmap.org/?mlat=${workerLocation.latitude}&mlon=${workerLocation.longitude}&zoom=16`;
                  window.open(url, '_blank');
                }}
              >
                <Text style={styles.mapButtonText}>🌍 OpenStreetMap</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.timestampBox}>
              <Text style={styles.timestampLabel}>⏰ Last Updated</Text>
              <Text style={styles.timestampValue}>
                {formatTime(workerLocation.timestamp)}
              </Text>
            </View>
          </View>
        </View>
      </View>

      <View style={styles.locationInfo}>
        <View style={styles.infoCard}>
          <View style={styles.infoHeader}>
            <Text style={styles.infoTitle}>📍 Live Location</Text>
            <View style={styles.liveIndicator}>
              <View style={styles.liveDot} />
              <Text style={styles.liveText}>LIVE</Text>
            </View>
          </View>

          <Text style={styles.workerNameText}>{workerName}</Text>

          <View style={styles.coordinatesContainer}>
            <Text style={styles.coordinates}>
              Latitude: {workerLocation.latitude.toFixed(6)}
            </Text>
            <Text style={styles.coordinates}>
              Longitude: {workerLocation.longitude.toFixed(6)}
            </Text>
          </View>

          <View style={styles.timestampContainer}>
            <Text style={styles.timestamp}>
              📅 Last updated: {formatTime(workerLocation.timestamp)}
            </Text>
            <Text style={styles.timestamp}>
              🔄 Refreshed: {formatTime(lastUpdate)}
            </Text>
          </View>
        </View>

        <View style={styles.actionButtons}>
          <TouchableOpacity style={styles.mapsButtonLarge} onPress={openInGoogleMaps}>
            <Text style={styles.mapsButtonText}>🗺️ Open in Google Maps</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.refreshButton}
            onPress={() => setLastUpdate(new Date())}
          >
            <Text style={styles.refreshButtonText}>🔄 Refresh</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Floating Action Button for Quick Delivery */}
      <TouchableOpacity
        style={styles.floatingActionButton}
        onPress={() => setShowDeliveryModal(true)}
      >
        <Icon name="literature" size={24} color="#ffffff" />
        <Text style={styles.fabText}>Log Delivery</Text>
      </TouchableOpacity>

      {/* Quick Delivery Modal */}
      <QuickDeliveryModal
        visible={showDeliveryModal}
        onClose={() => setShowDeliveryModal(false)}
        onDeliveryLogged={handleDeliveryLogged}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  header: {
    backgroundColor: '#ffffff',
    paddingTop: 50,
    paddingHorizontal: 20,
    paddingBottom: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  backButton: {
    fontSize: 16,
    color: '#3b82f6',
    fontWeight: '600',
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  mapsButton: {
    fontSize: 20,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 16,
    color: '#64748b',
  },
  noLocationContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 40,
  },
  noLocationText: {
    fontSize: 48,
    marginBottom: 16,
  },
  noLocationTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 8,
    textAlign: 'center',
  },
  noLocationSubtitle: {
    fontSize: 14,
    color: '#64748b',
    textAlign: 'center',
    lineHeight: 20,
  },
  map: {
    flex: 1,
  },
  mapContainer: {
    flex: 1,
    backgroundColor: '#ffffff',
    margin: 16,
    borderRadius: 16,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  mapHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  mapTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  coordinateDisplay: {
    alignItems: 'center',
  },
  workerNameLarge: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#3b82f6',
    marginBottom: 20,
    textAlign: 'center',
  },
  coordinateBox: {
    backgroundColor: '#f1f5f9',
    padding: 20,
    borderRadius: 12,
    marginBottom: 20,
    width: '100%',
    alignItems: 'center',
  },
  coordinateLabel: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 12,
  },
  coordinateValue: {
    fontSize: 18,
    color: '#1e293b',
    fontFamily: 'monospace',
    marginBottom: 8,
    fontWeight: '600',
  },
  mapButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    marginBottom: 20,
  },
  mapButton: {
    backgroundColor: '#3b82f6',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 12,
    flex: 0.48,
    alignItems: 'center',
  },
  mapButtonText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '600',
  },
  timestampBox: {
    backgroundColor: '#f9fafb',
    padding: 16,
    borderRadius: 8,
    width: '100%',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  timestampLabel: {
    fontSize: 14,
    color: '#64748b',
    marginBottom: 4,
  },
  timestampValue: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  mapPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f1f5f9',
    padding: 40,
  },
  mapPlaceholderTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 16,
    textAlign: 'center',
  },
  mapPlaceholderCoords: {
    fontSize: 18,
    color: '#3b82f6',
    fontFamily: 'monospace',
    marginBottom: 16,
    textAlign: 'center',
  },
  mapPlaceholderNote: {
    fontSize: 14,
    color: '#64748b',
    textAlign: 'center',
  },
  locationInfo: {
    backgroundColor: '#ffffff',
    padding: 20,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 5,
  },
  infoCard: {
    marginBottom: 16,
  },
  infoHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  infoTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#10b981',
    marginRight: 6,
  },
  liveText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#10b981',
  },
  workerNameText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#3b82f6',
    marginBottom: 12,
  },
  coordinatesContainer: {
    backgroundColor: '#f1f5f9',
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
  },
  coordinates: {
    fontSize: 14,
    color: '#1e293b',
    fontFamily: 'monospace',
    marginBottom: 4,
    fontWeight: '500',
  },
  timestampContainer: {
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
    paddingTop: 12,
  },
  timestamp: {
    fontSize: 12,
    color: '#64748b',
    marginBottom: 4,
  },
  actionButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  refreshButton: {
    backgroundColor: '#f1f5f9',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 12,
    alignItems: 'center',
    flex: 0.45,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  refreshButtonText: {
    color: '#64748b',
    fontSize: 14,
    fontWeight: '600',
  },
  openMapButton: {
    backgroundColor: '#3b82f6',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 12,
  },
  openMapButtonText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '600',
  },
  mapsButtonLarge: {
    backgroundColor: '#3b82f6',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 12,
    alignItems: 'center',
    flex: 0.45,
  },
  mapsButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
  headerControls: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  territoryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#f0f9ff',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
    marginRight: 12,
    borderWidth: 1,
    borderColor: '#3b82f6',
  },
  territoryButtonText: {
    color: '#3b82f6',
    fontSize: 12,
    fontWeight: '600',
    marginLeft: 6,
  },
  floatingActionButton: {
    position: 'absolute',
    bottom: 30,
    right: 20,
    backgroundColor: '#3b82f6',
    borderRadius: 28,
    paddingHorizontal: 20,
    paddingVertical: 12,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  fabText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 8,
  },
});
