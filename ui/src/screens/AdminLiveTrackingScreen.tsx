import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert, RefreshControl, StatusBar } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { realtimeLocationService, WorkerData } from '../services/RealtimeLocationService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import Header from '../components/Header';

// Worker interface that matches RealtimeLocationService data structure
interface Worker {
  id: string;
  name: string;
  email: string;
  currentLocation?: {
    latitude: number;
    longitude: number;
    timestamp: number; // Changed from Date to number to match RealtimeLocationService
  };
  isActive: boolean;
  lastSeen: number; // Changed from Date to number
  deliveries: number;
  distance: string;
}

interface DeliveryLog {
  id: string;
  workerId: string;
  workerName: string;
  deliveryType: 'door' | 'person';
  location: {
    latitude: number;
    longitude: number;
  };
  timestamp: Date;
  address: string;
}

export default function AdminLiveTrackingScreen({ navigation }: any) {
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [deliveryLogs, setDeliveryLogs] = useState<DeliveryLog[]>([]);
  const [refreshing, setRefreshing] = useState(false);

  // Real-time Firebase data
  useEffect(() => {
    loadRealTimeData();
  }, []);

  const loadRealTimeData = () => {
    console.log('🚀 Loading real-time worker data from RealtimeLocationService...');

    // Listen to real-time worker data from Firebase Realtime Database
    const unsubscribeWorkers = realtimeLocationService.listenToAllWorkers(async (workersData: WorkerData[]) => {
      console.log('📊 Received real-time workers data:', workersData.length, 'workers');

      const processedWorkers: Worker[] = [];

      for (const workerData of workersData) {
        // Get delivery count for this worker (would use service layer)
        let deliveryCount = 0;

        processedWorkers.push({
          id: workerData.id,
          name: workerData.name,
          email: workerData.email || `${workerData.name.toLowerCase().replace(' ', '.')}@example.com`,
          currentLocation: workerData.currentLocation ? {
            latitude: workerData.currentLocation.latitude,
            longitude: workerData.currentLocation.longitude,
            timestamp: workerData.currentLocation.timestamp,
          } : undefined,
          isActive: workerData.isActive,
          lastSeen: workerData.lastSeen || Date.now(),
          deliveries: deliveryCount,
          distance: '0km', // You can calculate this based on location history
        });
      }

      console.log('✅ Processed workers data:', processedWorkers);
      setWorkers(processedWorkers);
    });

    // Deliveries would be loaded through a service layer
    setDeliveryLogs([]);

    // Cleanup subscriptions
    return () => {
      unsubscribeWorkers();
    };
  };

  const onRefresh = () => {
    setRefreshing(true);
    setTimeout(() => {
      loadRealTimeData();
      setRefreshing(false);
      Alert.alert('✅ Refreshed', 'Worker data updated successfully!');
    }, 1000);
  };

  const formatTime = (timestamp: number | Date) => {
    const date = typeof timestamp === 'number' ? new Date(timestamp) : timestamp;
    return date.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  const formatDate = (timestamp: number | Date) => {
    const date = typeof timestamp === 'number' ? new Date(timestamp) : timestamp;
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
    });
  };

  const getWorkerStatus = (worker: Worker) => {
    const now = Date.now();
    const lastSeenTime = typeof worker.lastSeen === 'number' ? worker.lastSeen : worker.lastSeen;
    const timeDiff = now - lastSeenTime;
    const minutesAgo = Math.floor(timeDiff / (1000 * 60));

    if (worker.isActive && minutesAgo < 5) {
      return { status: '🟢 Active', color: '#10b981', text: 'Online now' };
    } else if (minutesAgo < 30) {
      return { status: '🟡 Recent', color: '#f59e0b', text: `${minutesAgo}m ago` };
    } else {
      return { status: '🔴 Offline', color: '#ef4444', text: 'Offline' };
    }
  };

  const openWorkerLocation = (worker: Worker) => {
    console.log('Opening location for worker:', worker.name, 'ID:', worker.id);
    console.log('Worker current location:', worker.currentLocation);

    if (worker.currentLocation) {
      // Navigate to Leaflet map screen
      console.log('Navigating to LeafletMap with params:', {
        workerId: worker.id,
        workerName: worker.name,
      });
      navigation.navigate('LeafletMap', {
        workerId: worker.id,
        workerName: worker.name,
      });
    } else {
      console.log('No location available for worker:', worker.name);
      Alert.alert('❌ No Location', 'Location not available for this worker');
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />

      {/* Modern Header Component */}
      <Header
        showMenu={false}
        showLogo={false}
        showProfile={false}
        showNotifications={false}
        title="Live Worker Tracking"
        showBackButton={true}
        onBackPress={() => navigation.goBack()}
        rightComponent={
          <TouchableOpacity
            style={styles.refreshButton}
            onPress={onRefresh}
            activeOpacity={0.7}
          >
            <MaterialIcons name="refresh" size={24} color={COLORS.primary} />
          </TouchableOpacity>
        }
      />

      <ScrollView
        style={styles.content}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {/* Modern Stats Overview */}
        <View style={styles.statsContainer}>
          <View style={styles.modernStatCard}>
            <View style={[styles.statIconContainer, { backgroundColor: `${COLORS.success}15` }]}>
              <MaterialIcons name="location-on" size={24} color={COLORS.success} />
            </View>
            <View style={styles.statContent}>
              <Text style={styles.statNumber}>{workers.filter(w => w.isActive).length}</Text>
              <Text style={styles.statLabel}>Active Now</Text>
              <Text style={styles.statSubtitle}>Currently tracking</Text>
            </View>
          </View>

          <View style={styles.modernStatCard}>
            <View style={[styles.statIconContainer, { backgroundColor: `${COLORS.primary}15` }]}>
              <MaterialIcons name="people" size={24} color={COLORS.primary} />
            </View>
            <View style={styles.statContent}>
              <Text style={styles.statNumber}>{workers.length}</Text>
              <Text style={styles.statLabel}>Total Workers</Text>
              <Text style={styles.statSubtitle}>All registered</Text>
            </View>
          </View>

          <View style={styles.modernStatCard}>
            <View style={[styles.statIconContainer, { backgroundColor: `${COLORS.warning}15` }]}>
              <MaterialIcons name="local-shipping" size={24} color={COLORS.warning} />
            </View>
            <View style={styles.statContent}>
              <Text style={styles.statNumber}>
                {deliveryLogs.filter(d => {
                  const today = new Date();
                  return d.timestamp.toDateString() === today.toDateString();
                }).length}
              </Text>
              <Text style={styles.statLabel}>Today's Deliveries</Text>
              <Text style={styles.statSubtitle}>Books delivered</Text>
            </View>
          </View>
        </View>

        {/* Workers List */}
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Workers Status</Text>
          <Text style={styles.sectionSubtitle}>Real-time location tracking</Text>
        </View>

        {workers.map((worker) => {
          const status = getWorkerStatus(worker);
          return (
            <TouchableOpacity
              key={worker.id}
              style={[
                styles.modernWorkerCard,
                !worker.isActive && styles.workerCardOffline
              ]}
              onPress={() => openWorkerLocation(worker)}
              activeOpacity={0.7}
            >
              {/* Worker Header with Status Indicator */}
              <View style={styles.workerCardHeader}>
                <View style={styles.workerAvatarContainer}>
                  <View style={[styles.workerAvatar, { backgroundColor: `${status.color}15` }]}>
                    <MaterialIcons name="person" size={24} color={status.color} />
                  </View>
                  <View style={[styles.statusIndicator, { backgroundColor: status.color }]} />
                </View>

                <View style={styles.workerMainInfo}>
                  <Text style={styles.modernWorkerName}>{worker.name}</Text>
                  <Text style={styles.modernWorkerEmail}>{worker.email}</Text>
                  <Text style={[styles.modernWorkerStatus, { color: status.color }]}>
                    {status.status}
                  </Text>
                </View>

                <View style={styles.workerActions}>
                  <MaterialIcons name="location-on" size={20} color={COLORS.primary} />
                </View>
              </View>

              {/* Worker Stats */}
              <View style={styles.modernWorkerStats}>
                <View style={styles.statItem}>
                  <MaterialIcons name="local-shipping" size={16} color={COLORS.textSecondary} />
                  <Text style={styles.modernStatText}>{worker.deliveries} deliveries</Text>
                </View>
                <View style={styles.statItem}>
                  <MaterialIcons name="directions-walk" size={16} color={COLORS.textSecondary} />
                  <Text style={styles.modernStatText}>{worker.distance} traveled</Text>
                </View>
              </View>

              {/* Location Information */}
              {worker.currentLocation ? (
                <View style={styles.modernLocationInfo}>
                  <View style={styles.locationHeader}>
                    <MaterialIcons name="location-on" size={16} color={COLORS.success} />
                    <Text style={styles.locationLabel}>Current Location</Text>
                  </View>
                  <Text style={styles.modernLocationText}>
                    {worker.currentLocation.latitude.toFixed(6)}, {worker.currentLocation.longitude.toFixed(6)}
                  </Text>
                  <Text style={styles.modernLocationTime}>
                    Last updated: {formatTime(worker.currentLocation.timestamp)}
                  </Text>
                </View>
              ) : (
                <View style={styles.modernOfflineInfo}>
                  <View style={styles.offlineHeader}>
                    <MaterialIcons name="location-off" size={16} color={COLORS.textSecondary} />
                    <Text style={styles.offlineLabel}>No Location Data</Text>
                  </View>
                  <Text style={styles.modernOfflineText}>Worker is offline</Text>
                </View>
              )}

              {!worker.isActive && (
                <View style={styles.modernOfflineBanner}>
                  <MaterialIcons name="warning" size={16} color={COLORS.warning} />
                  <Text style={styles.modernOfflineBannerText}>
                    Location tracking paused
                  </Text>
                </View>
              )}
            </TouchableOpacity>
          );
        })}

        {/* Recent Deliveries */}
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Recent Deliveries</Text>
          <Text style={styles.sectionSubtitle}>Latest book deliveries</Text>
        </View>

        {deliveryLogs.slice(0, 10).map((delivery) => (
          <TouchableOpacity
            key={delivery.id}
            style={styles.modernDeliveryCard}
            onPress={() => {
              const { latitude, longitude } = delivery.location;
              Alert.alert(
                'Delivery Location',
                `Book delivered at:\nLat: ${latitude.toFixed(4)}\nLng: ${longitude.toFixed(4)}\n\nOpen in Google Maps?`,
                [
                  { text: 'Cancel', style: 'cancel' },
                  { text: 'Open Maps', onPress: () => console.log('Open delivery location') },
                ]
              );
            }}
            activeOpacity={0.7}
          >
            <View style={styles.deliveryCardHeader}>
              <View style={[styles.deliveryIconContainer, { backgroundColor: `${COLORS.warning}15` }]}>
                <MaterialIcons
                  name={delivery.deliveryType === 'door' ? 'door-front' : 'person'}
                  size={20}
                  color={COLORS.warning}
                />
              </View>
              <View style={styles.deliveryMainInfo}>
                <Text style={styles.modernDeliveryWorker}>{delivery.workerName}</Text>
                <Text style={styles.modernDeliveryType}>
                  {delivery.deliveryType === 'door' ? 'Delivered to Door' : 'Delivered to Person'}
                </Text>
              </View>
              <MaterialIcons name="location-on" size={20} color={COLORS.primary} />
            </View>

            <View style={styles.deliveryDetails}>
              <View style={styles.deliveryLocationRow}>
                <MaterialIcons name="place" size={14} color={COLORS.textSecondary} />
                <Text style={styles.modernDeliveryLocation}>
                  {delivery.location.latitude.toFixed(4)}, {delivery.location.longitude.toFixed(4)}
                </Text>
              </View>
              <View style={styles.deliveryTimeRow}>
                <MaterialIcons name="schedule" size={14} color={COLORS.textSecondary} />
                <Text style={styles.modernDeliveryTime}>
                  {formatDate(delivery.timestamp)} at {formatTime(delivery.timestamp)}
                </Text>
              </View>
            </View>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.secondary,
  },
  refreshButton: {
    padding: SPACING.xs,
    borderRadius: RADIUS.sm,
    backgroundColor: `${COLORS.primary}10`,
  },
  content: {
    flex: 1,
    padding: SPACING.lg,
  },
  // Modern Stats Container
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.xl,
    gap: SPACING.md,
  },
  modernStatCard: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    ...SHADOWS.sm,
    flexDirection: 'row',
    alignItems: 'center',
  },
  statIconContainer: {
    width: 48,
    height: 48,
    borderRadius: RADIUS.md,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  statContent: {
    flex: 1,
  },
  statNumber: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  statSubtitle: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },
  // Section Headers
  sectionHeader: {
    marginBottom: SPACING.lg,
    marginTop: SPACING.lg,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  sectionSubtitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  // Modern Worker Cards
  modernWorkerCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  workerCardOffline: {
    opacity: 0.7,
    borderLeftWidth: 4,
    borderLeftColor: COLORS.textSecondary,
  },
  workerCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  workerAvatarContainer: {
    position: 'relative',
    marginRight: SPACING.md,
  },
  workerAvatar: {
    width: 48,
    height: 48,
    borderRadius: RADIUS.full,
    justifyContent: 'center',
    alignItems: 'center',
  },
  statusIndicator: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 14,
    height: 14,
    borderRadius: RADIUS.full,
    borderWidth: 2,
    borderColor: COLORS.background.primary,
  },
  workerMainInfo: {
    flex: 1,
  },
  modernWorkerName: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  modernWorkerEmail: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  modernWorkerStatus: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  workerActions: {
    justifyContent: 'center',
  },
  modernWorkerStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.md,
  },
  statItem: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  modernStatText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
    marginLeft: SPACING.xs,
  },

  // Modern Location Info
  modernLocationInfo: {
    backgroundColor: `${COLORS.success}10`,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
    borderLeftWidth: 3,
    borderLeftColor: COLORS.success,
  },
  locationHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  locationLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.success,
    marginLeft: SPACING.xs,
  },
  modernLocationText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
    marginBottom: SPACING.xs,
  },
  modernLocationTime: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },

  // Modern Offline Info
  modernOfflineInfo: {
    backgroundColor: `${COLORS.textSecondary}10`,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
    borderLeftWidth: 3,
    borderLeftColor: COLORS.textSecondary,
  },
  offlineHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  offlineLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
  modernOfflineText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },

  // Modern Offline Banner
  modernOfflineBanner: {
    backgroundColor: `${COLORS.warning}15`,
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  modernOfflineBannerText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.warning,
    fontWeight: TYPOGRAPHY.weights.medium,
    marginLeft: SPACING.xs,
  },
  // Modern Delivery Cards
  modernDeliveryCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  deliveryCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  deliveryIconContainer: {
    width: 40,
    height: 40,
    borderRadius: RADIUS.md,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  deliveryMainInfo: {
    flex: 1,
  },
  modernDeliveryWorker: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  modernDeliveryType: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  deliveryDetails: {
    gap: SPACING.xs,
  },
  deliveryLocationRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  modernDeliveryLocation: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
  deliveryTimeRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  modernDeliveryTime: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
});