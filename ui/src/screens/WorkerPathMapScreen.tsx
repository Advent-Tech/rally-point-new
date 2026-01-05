import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Platform,
  ActivityIndicator,
  ScrollView,
  Dimensions,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import MapView, { Marker, Polyline, PROVIDER_GOOGLE, Region } from 'react-native-maps';
import { DeliveryServiceBackend, Delivery } from '../services/DeliveryServiceBackend';
import { WorkerStatsService, PathPoint } from '../services/WorkerStatsService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

const { width, height } = Dimensions.get('window');

interface WorkerPathMapScreenProps {
  navigation: any;
  route: {
    params: {
      workerId: string;
      workerName: string;
      currentLocation?: {
        latitude: number;
        longitude: number;
      };
      pathPoints?: Array<{
        latitude: number;
        longitude: number;
        timestamp: number;
      }>;
    };
  };
}

interface LocalPathPoint {
  latitude: number;
  longitude: number;
  timestamp: number;
}

const WorkerPathMapScreen: React.FC<WorkerPathMapScreenProps> = ({ navigation, route }) => {
  const { workerId, workerName, currentLocation, pathPoints: initialPathPoints } = route.params;
  const mapRef = useRef<MapView>(null);
  const [loading, setLoading] = useState(true);
  const [pathPoints, setPathPoints] = useState<LocalPathPoint[]>(initialPathPoints || []);
  const [deliveries, setDeliveries] = useState<Delivery[]>([]);
  const [selectedDelivery, setSelectedDelivery] = useState<Delivery | null>(null);
  const [showDeliveryPanel, setShowDeliveryPanel] = useState(false);
  const [mapRegion, setMapRegion] = useState<Region>({
    latitude: currentLocation?.latitude || 0,
    longitude: currentLocation?.longitude || 0,
    latitudeDelta: 0.01,
    longitudeDelta: 0.01,
  });

  useEffect(() => {
    loadWorkerData();
  }, [workerId]);

  const loadWorkerData = async () => {
    try {
      setLoading(true);

      // Load worker's deliveries and path history in parallel
      const [deliveryResult, pathHistoryResult] = await Promise.all([
        DeliveryServiceBackend.getWorkerDeliveries(workerId, 50).catch(() => ({ deliveries: [] })),
        WorkerStatsService.getWorkerPathHistory(workerId).catch(() => ({ path_points: [] })),
      ]);

      const deliveriesWithLocation = (deliveryResult.deliveries || []).filter(
        d => d.latitude && d.longitude
      );
      setDeliveries(deliveriesWithLocation);

      // Convert backend path points to local format
      const backendPathPoints = pathHistoryResult.path_points || [];
      if (backendPathPoints.length > 0) {
        const convertedPoints: LocalPathPoint[] = backendPathPoints.map((p: PathPoint) => ({
          latitude: p.latitude,
          longitude: p.longitude,
          timestamp: p.timestamp,
        }));
        setPathPoints(convertedPoints);
      }

      // Calculate map region to fit all points
      if (deliveriesWithLocation.length > 0 || currentLocation) {
        const allPoints: { latitude: number; longitude: number }[] = [];

        if (currentLocation) {
          allPoints.push(currentLocation);
        }

        deliveriesWithLocation.forEach(d => {
          if (d.latitude && d.longitude) {
            allPoints.push({ latitude: d.latitude, longitude: d.longitude });
          }
        });

        if (pathPoints.length > 0) {
          pathPoints.forEach(p => allPoints.push(p));
        }

        if (allPoints.length > 0) {
          const lats = allPoints.map(p => p.latitude);
          const lngs = allPoints.map(p => p.longitude);
          const minLat = Math.min(...lats);
          const maxLat = Math.max(...lats);
          const minLng = Math.min(...lngs);
          const maxLng = Math.max(...lngs);

          const centerLat = (minLat + maxLat) / 2;
          const centerLng = (minLng + maxLng) / 2;
          const latDelta = Math.max(0.01, (maxLat - minLat) * 1.5);
          const lngDelta = Math.max(0.01, (maxLng - minLng) * 1.5);

          setMapRegion({
            latitude: centerLat,
            longitude: centerLng,
            latitudeDelta: latDelta,
            longitudeDelta: lngDelta,
          });
        }
      }
    } catch (error) {
      console.error('Error loading worker data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleDeliveryPress = (delivery: Delivery) => {
    setSelectedDelivery(delivery);
    setShowDeliveryPanel(true);

    // Center map on selected delivery
    if (delivery.latitude && delivery.longitude) {
      mapRef.current?.animateToRegion({
        latitude: delivery.latitude,
        longitude: delivery.longitude,
        latitudeDelta: 0.005,
        longitudeDelta: 0.005,
      }, 500);
    }
  };

  const handleCenterOnWorker = () => {
    if (currentLocation) {
      mapRef.current?.animateToRegion({
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        latitudeDelta: 0.01,
        longitudeDelta: 0.01,
      }, 500);
    }
  };

  const handleFitAll = () => {
    mapRef.current?.animateToRegion(mapRegion, 500);
  };

  const getDeliveryMarkerColor = (status: string) => {
    switch (status) {
      case 'delivered':
        return '#22c55e';
      case 'pending':
        return '#f59e0b';
      case 'in_progress':
        return '#3b82f6';
      case 'failed':
        return '#ef4444';
      default:
        return '#6b7280';
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.white} />
        </TouchableOpacity>
        <View style={styles.headerContent}>
          <Text style={styles.headerTitle}>{workerName}'s Route</Text>
          <Text style={styles.headerSubtitle}>
            {deliveries.length} delivery locations
          </Text>
        </View>
      </View>

      {/* Map */}
      <View style={styles.mapContainer}>
        {loading ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color={COLORS.primary} />
            <Text style={styles.loadingText}>Loading map data...</Text>
          </View>
        ) : (
          <MapView
            ref={mapRef}
            style={styles.map}
            provider={Platform.OS === 'android' ? PROVIDER_GOOGLE : undefined}
            initialRegion={mapRegion}
            showsUserLocation={false}
            showsMyLocationButton={false}
          >
            {/* Worker's Current Location */}
            {currentLocation && (
              <Marker
                coordinate={currentLocation}
                title={workerName}
                description="Current location"
              >
                <View style={styles.workerMarker}>
                  <MaterialIcons name="person-pin" size={32} color={COLORS.primary} />
                </View>
              </Marker>
            )}

            {/* Worker's Path */}
            {pathPoints.length > 1 && (
              <Polyline
                coordinates={pathPoints}
                strokeColor={COLORS.primary}
                strokeWidth={4}
                lineDashPattern={[0]}
              />
            )}

            {/* Delivery Markers */}
            {deliveries.map((delivery) => (
              delivery.latitude && delivery.longitude && (
                <Marker
                  key={delivery.id}
                  coordinate={{
                    latitude: delivery.latitude,
                    longitude: delivery.longitude,
                  }}
                  onPress={() => handleDeliveryPress(delivery)}
                  title={delivery.recipient_name}
                  description={delivery.address}
                >
                  <View style={[
                    styles.deliveryMarker,
                    { backgroundColor: getDeliveryMarkerColor(delivery.status) }
                  ]}>
                    <MaterialIcons name="local-shipping" size={16} color={COLORS.white} />
                  </View>
                </Marker>
              )
            ))}
          </MapView>
        )}

        {/* Map Controls */}
        <View style={styles.mapControls}>
          {currentLocation && (
            <TouchableOpacity style={styles.mapControlButton} onPress={handleCenterOnWorker}>
              <MaterialIcons name="person-pin-circle" size={24} color={COLORS.primary} />
            </TouchableOpacity>
          )}
          <TouchableOpacity style={styles.mapControlButton} onPress={handleFitAll}>
            <MaterialIcons name="zoom-out-map" size={24} color={COLORS.primary} />
          </TouchableOpacity>
        </View>
      </View>

      {/* Legend */}
      <View style={styles.legend}>
        <View style={styles.legendItem}>
          <View style={[styles.legendDot, { backgroundColor: '#22c55e' }]} />
          <Text style={styles.legendText}>Delivered</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.legendDot, { backgroundColor: '#f59e0b' }]} />
          <Text style={styles.legendText}>Pending</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.legendDot, { backgroundColor: '#3b82f6' }]} />
          <Text style={styles.legendText}>In Progress</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.legendDot, { backgroundColor: '#ef4444' }]} />
          <Text style={styles.legendText}>Failed</Text>
        </View>
      </View>

      {/* Delivery List Panel */}
      <View style={styles.deliveryListPanel}>
        <Text style={styles.panelTitle}>Delivery Locations</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          {deliveries.map((delivery) => (
            <TouchableOpacity
              key={delivery.id}
              style={[
                styles.deliveryListItem,
                selectedDelivery?.id === delivery.id && styles.deliveryListItemSelected,
              ]}
              onPress={() => handleDeliveryPress(delivery)}
            >
              <View style={[
                styles.deliveryListStatus,
                { backgroundColor: getDeliveryMarkerColor(delivery.status) }
              ]} />
              <View style={styles.deliveryListContent}>
                <Text style={styles.deliveryListName} numberOfLines={1}>
                  {delivery.recipient_name}
                </Text>
                <Text style={styles.deliveryListAddress} numberOfLines={1}>
                  {delivery.address}
                </Text>
                <Text style={styles.deliveryListDate}>
                  {formatDate(delivery.created_at)}
                </Text>
              </View>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {/* Selected Delivery Detail Panel */}
      {showDeliveryPanel && selectedDelivery && (
        <View style={styles.detailPanel}>
          <View style={styles.detailPanelHeader}>
            <Text style={styles.detailPanelTitle}>Delivery Details</Text>
            <TouchableOpacity onPress={() => setShowDeliveryPanel(false)}>
              <MaterialIcons name="close" size={24} color={COLORS.text.secondary} />
            </TouchableOpacity>
          </View>
          <View style={styles.detailPanelContent}>
            <View style={styles.detailRow}>
              <MaterialIcons name="person" size={20} color={COLORS.text.secondary} />
              <Text style={styles.detailText}>{selectedDelivery.recipient_name}</Text>
            </View>
            <View style={styles.detailRow}>
              <MaterialIcons name="location-on" size={20} color={COLORS.text.secondary} />
              <Text style={styles.detailText}>{selectedDelivery.address}</Text>
            </View>
            <View style={styles.detailRow}>
              <MaterialIcons name="schedule" size={20} color={COLORS.text.secondary} />
              <Text style={styles.detailText}>{formatDate(selectedDelivery.created_at)}</Text>
            </View>
            <View style={styles.detailRow}>
              <MaterialIcons name="info" size={20} color={COLORS.text.secondary} />
              <View style={[
                styles.statusBadge,
                { backgroundColor: getDeliveryMarkerColor(selectedDelivery.status) + '20' }
              ]}>
                <Text style={[
                  styles.statusBadgeText,
                  { color: getDeliveryMarkerColor(selectedDelivery.status) }
                ]}>
                  {selectedDelivery.status}
                </Text>
              </View>
            </View>
            {selectedDelivery.notes && (
              <View style={styles.detailRow}>
                <MaterialIcons name="notes" size={20} color={COLORS.text.secondary} />
                <Text style={styles.detailText}>{selectedDelivery.notes}</Text>
              </View>
            )}
          </View>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  header: {
    backgroundColor: COLORS.primary,
    paddingTop: Platform.OS === 'ios' ? 50 : 40,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.md,
    flexDirection: 'row',
    alignItems: 'center',
  },
  backButton: {
    padding: SPACING.sm,
    marginRight: SPACING.sm,
  },
  headerContent: {
    flex: 1,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: COLORS.white,
  },
  headerSubtitle: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.8)',
    marginTop: 2,
  },
  mapContainer: {
    flex: 1,
    position: 'relative',
  },
  map: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
  },
  loadingText: {
    marginTop: SPACING.md,
    fontSize: 14,
    color: COLORS.text.secondary,
  },
  mapControls: {
    position: 'absolute',
    right: SPACING.md,
    top: SPACING.md,
  },
  mapControlButton: {
    backgroundColor: COLORS.white,
    padding: SPACING.sm,
    borderRadius: RADIUS.lg,
    marginBottom: SPACING.sm,
    ...SHADOWS.md,
  },
  workerMarker: {
    backgroundColor: COLORS.white,
    padding: 4,
    borderRadius: 20,
    ...SHADOWS.sm,
  },
  deliveryMarker: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: COLORS.white,
    ...SHADOWS.sm,
  },
  legend: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: COLORS.white,
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  legendDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 6,
  },
  legendText: {
    fontSize: 12,
    color: COLORS.text.secondary,
  },
  deliveryListPanel: {
    backgroundColor: COLORS.white,
    paddingVertical: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
  },
  panelTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1e293b',
    marginHorizontal: SPACING.lg,
    marginBottom: SPACING.sm,
  },
  deliveryListItem: {
    backgroundColor: '#f8fafc',
    borderRadius: RADIUS.md,
    padding: SPACING.sm,
    marginLeft: SPACING.md,
    width: 160,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  deliveryListItemSelected: {
    borderColor: COLORS.primary,
    backgroundColor: '#eff6ff',
  },
  deliveryListStatus: {
    width: 8,
    height: 8,
    borderRadius: 4,
    position: 'absolute',
    top: SPACING.sm,
    right: SPACING.sm,
  },
  deliveryListContent: {
    flex: 1,
  },
  deliveryListName: {
    fontSize: 13,
    fontWeight: '600',
    color: '#1e293b',
    marginBottom: 2,
  },
  deliveryListAddress: {
    fontSize: 11,
    color: COLORS.text.secondary,
    marginBottom: 4,
  },
  deliveryListDate: {
    fontSize: 10,
    color: COLORS.text.secondary,
  },
  detailPanel: {
    position: 'absolute',
    bottom: 120,
    left: SPACING.md,
    right: SPACING.md,
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    ...SHADOWS.lg,
  },
  detailPanelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  detailPanelTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#1e293b',
  },
  detailPanelContent: {
    gap: SPACING.sm,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  detailText: {
    fontSize: 14,
    color: COLORS.text.secondary,
    flex: 1,
  },
  statusBadge: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: RADIUS.sm,
  },
  statusBadgeText: {
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'capitalize',
  },
});

export default WorkerPathMapScreen;
