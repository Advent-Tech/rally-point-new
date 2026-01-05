import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { realtimeLocationService, WorkerData } from '../services/RealtimeLocationService';

interface RealtimeTrackingScreenProps {
  navigation: any;
}

export default function RealtimeTrackingScreen({ navigation }: RealtimeTrackingScreenProps) {
  const [workers, setWorkers] = useState<WorkerData[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());

  useEffect(() => {
    console.log('🚀 Starting real-time worker tracking...');
    
    // Listen to all workers in real-time
    const unsubscribe = realtimeLocationService.listenToAllWorkers((workersData) => {
      console.log('📊 Real-time workers update:', workersData.length, 'workers');
      setWorkers(workersData);
      setLastUpdate(new Date());
      setIsLoading(false);
    });

    // Auto-refresh timestamp every 5 seconds
    const interval = setInterval(() => {
      setLastUpdate(new Date());
    }, 5000);

    return () => {
      unsubscribe();
      clearInterval(interval);
    };
  }, []);

  const formatTime = (timestamp: number) => {
    return new Date(timestamp).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  const formatDistance = (location: any) => {
    if (!location) return 'Unknown';
    return `${location.latitude.toFixed(6)}, ${location.longitude.toFixed(6)}`;
  };

  const getTimeSince = (timestamp: number) => {
    const now = Date.now();
    const diff = now - timestamp;
    const seconds = Math.floor(diff / 1000);
    
    if (seconds < 60) return `${seconds}s ago`;
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    return `${hours}h ago`;
  };

  const openWorkerMap = (worker: WorkerData) => {
    if (worker.currentLocation) {
      navigation.navigate('LeafletMap', {
        workerId: worker.id,
        workerName: worker.name,
      });
    } else {
      Alert.alert('❌ No Location', 'Real-time location not available for this worker');
    }
  };

  if (isLoading) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>🚀 Real-time Tracking</Text>
        </View>
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>🔄 Loading real-time data...</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.backButton}>← Back</Text>
        </TouchableOpacity>
        <Text style={styles.title}>🚀 Real-time Tracking</Text>
        <View style={styles.liveIndicator}>
          <View style={styles.liveDot} />
          <Text style={styles.liveText}>LIVE</Text>
        </View>
      </View>

      {/* Stats */}
      <View style={styles.statsContainer}>
        <View style={styles.statCard}>
          <Text style={styles.statNumber}>{workers.length}</Text>
          <Text style={styles.statLabel}>Total Workers</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statNumber}>{workers.filter(w => w.isActive).length}</Text>
          <Text style={styles.statLabel}>Active Now</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statNumber}>{workers.filter(w => w.currentLocation).length}</Text>
          <Text style={styles.statLabel}>With Location</Text>
        </View>
      </View>

      {/* Last Update */}
      <View style={styles.updateInfo}>
        <Text style={styles.updateText}>
          🔄 Last update: {formatTime(lastUpdate.getTime())} • Auto-refresh every 5s
        </Text>
      </View>

      {/* Workers List */}
      <ScrollView style={styles.workersList} showsVerticalScrollIndicator={false}>
        {workers.length === 0 ? (
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyIcon}>👥</Text>
            <Text style={styles.emptyTitle}>No Workers Found</Text>
            <Text style={styles.emptySubtitle}>
              Workers will appear here when they start real-time tracking
            </Text>
          </View>
        ) : (
          workers.map((worker) => (
            <View key={worker.id} style={styles.workerCard}>
              <View style={styles.workerHeader}>
                <View style={styles.workerInfo}>
                  <Text style={styles.workerName}>👤 {worker.name}</Text>
                  <Text style={styles.workerEmail}>{worker.email}</Text>
                </View>
                <View style={styles.statusContainer}>
                  <View style={[
                    styles.statusDot, 
                    { backgroundColor: worker.isActive ? '#10b981' : '#ef4444' }
                  ]} />
                  <Text style={[
                    styles.statusText,
                    { color: worker.isActive ? '#10b981' : '#ef4444' }
                  ]}>
                    {worker.isActive ? 'Active' : 'Offline'}
                  </Text>
                </View>
              </View>

              {worker.currentLocation ? (
                <View style={styles.locationContainer}>
                  <Text style={styles.locationLabel}>📍 Real-time Location:</Text>
                  <Text style={styles.locationCoords}>
                    {formatDistance(worker.currentLocation)}
                  </Text>
                  <Text style={styles.locationTime}>
                    Updated: {getTimeSince(worker.currentLocation.timestamp)}
                  </Text>
                  
                  {worker.currentLocation.speed && worker.currentLocation.speed > 0 && (
                    <Text style={styles.speedText}>
                      🚗 Speed: {(worker.currentLocation.speed * 3.6).toFixed(1)} km/h
                    </Text>
                  )}
                </View>
              ) : (
                <View style={styles.noLocationContainer}>
                  <Text style={styles.noLocationText}>📍 No real-time location available</Text>
                </View>
              )}

              <View style={styles.actionButtons}>
                <TouchableOpacity
                  style={[
                    styles.actionButton,
                    !worker.currentLocation && styles.disabledButton
                  ]}
                  onPress={() => openWorkerMap(worker)}
                  disabled={!worker.currentLocation}
                >
                  <Text style={[
                    styles.actionButtonText,
                    !worker.currentLocation && styles.disabledButtonText
                  ]}>
                    🗺️ View on Map
                  </Text>
                </TouchableOpacity>
              </View>
            </View>
          ))
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  header: {
    backgroundColor: '#1e293b',
    paddingTop: 50,
    paddingHorizontal: 20,
    paddingBottom: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  backButton: {
    fontSize: 16,
    color: '#3b82f6',
    fontWeight: '600',
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#ffffff',
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(16, 185, 129, 0.2)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
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
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 18,
    color: '#ffffff',
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
  },
  statCard: {
    backgroundColor: '#1e293b',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    flex: 1,
    marginHorizontal: 4,
  },
  statNumber: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#3b82f6',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    color: '#9ca3af',
  },
  updateInfo: {
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  updateText: {
    fontSize: 12,
    color: '#9ca3af',
    textAlign: 'center',
  },
  workersList: {
    flex: 1,
    paddingHorizontal: 20,
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#ffffff',
    marginBottom: 8,
  },
  emptySubtitle: {
    fontSize: 14,
    color: '#9ca3af',
    textAlign: 'center',
    lineHeight: 20,
  },
  workerCard: {
    backgroundColor: '#1e293b',
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#374151',
  },
  workerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  workerInfo: {
    flex: 1,
  },
  workerName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#ffffff',
    marginBottom: 4,
  },
  workerEmail: {
    fontSize: 12,
    color: '#9ca3af',
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 6,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
  },
  locationContainer: {
    backgroundColor: '#0f172a',
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
  },
  locationLabel: {
    fontSize: 12,
    color: '#9ca3af',
    marginBottom: 4,
  },
  locationCoords: {
    fontSize: 14,
    color: '#3b82f6',
    fontFamily: 'monospace',
    marginBottom: 4,
  },
  locationTime: {
    fontSize: 11,
    color: '#9ca3af',
  },
  speedText: {
    fontSize: 11,
    color: '#10b981',
    marginTop: 4,
  },
  noLocationContainer: {
    backgroundColor: '#0f172a',
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
    alignItems: 'center',
  },
  noLocationText: {
    fontSize: 12,
    color: '#9ca3af',
  },
  actionButtons: {
    flexDirection: 'row',
  },
  actionButton: {
    backgroundColor: '#3b82f6',
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 8,
    flex: 1,
    alignItems: 'center',
  },
  disabledButton: {
    backgroundColor: '#374151',
  },
  actionButtonText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '600',
  },
  disabledButtonText: {
    color: '#9ca3af',
  },
});
