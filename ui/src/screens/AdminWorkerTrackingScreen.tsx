import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Platform,
  Alert,
  RefreshControl,
} from 'react-native';
import { FontAwesome, MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { realtimeLocationService, WorkerData } from '../services/RealtimeLocationService';
import { Territory } from '../services/TerritoryService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import {
  isWorkerInsideAssignedTerritories,
  getWorkerTerritoryStatus,
  showTerritoryViolationAlert
} from '../utils/territoryUtils';

interface Worker {
  id: string;
  name: string;
  email: string;
  currentLocation?: {
    latitude: number;
    longitude: number;
    timestamp: number;
  };
  assignedTerritories: Territory[];
  isActive: boolean;
  lastSeen: number;
  isInsideTerritory: boolean;
}

interface AdminWorkerTrackingScreenProps {
  navigation: any;
}

const AdminWorkerTrackingScreen: React.FC<AdminWorkerTrackingScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [selectedWorker, setSelectedWorker] = useState<Worker | null>(null);
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadWorkersAndTerritories();
  }, []);

  const loadWorkersAndTerritories = async () => {
    try {
      setLoading(true);

      // Load all territories (using service layer)
      const territoriesData: Territory[] = [];

      setTerritories(territoriesData);
      console.log('📋 Loaded territories:', territoriesData.length);

      // Listen to real-time worker data
      const unsubscribe = realtimeLocationService.listenToAllWorkers(async (workersData: WorkerData[]) => {
        console.log('👥 Received workers data:', workersData.length);
        
        const processedWorkers: Worker[] = [];
        
        for (const workerData of workersData) {
          // Find assigned territories for this worker
          const assignedTerritories = territoriesData.filter(territory => 
            territory.assignedWorker?.email === workerData.email ||
            territory.assignedWorker?.id === workerData.id
          );
          
          // Check if worker is inside any assigned territory using utility function
          const territoryStatus = getWorkerTerritoryStatus(workerData.currentLocation, assignedTerritories);
          const isInsideTerritory = territoryStatus.status === 'inside';
          
          processedWorkers.push({
            id: workerData.id,
            name: workerData.name,
            email: workerData.email || `${workerData.name.toLowerCase().replace(' ', '.')}@example.com`,
            currentLocation: workerData.currentLocation,
            assignedTerritories,
            isActive: workerData.isActive,
            lastSeen: workerData.lastSeen || Date.now(),
            isInsideTerritory,
          });
        }
        
        setWorkers(processedWorkers);
        setLoading(false);
      });

      return () => unsubscribe();
    } catch (error) {
      console.error('❌ Error loading data:', error);
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadWorkersAndTerritories();
    setRefreshing(false);
  };



  const handleWorkerPress = (worker: Worker) => {
    setSelectedWorker(worker);
    
    if (worker.assignedTerritories.length > 0) {
      // Navigate to live map with worker and territory data
      navigation.navigate('AdminLiveMap', {
        workerId: worker.id,
        workerName: worker.name,
        assignedTerritories: worker.assignedTerritories,
        currentLocation: worker.currentLocation,
      });
    } else {
      Alert.alert(
        'No Territory Assigned',
        `${worker.name} doesn't have any territories assigned. Please assign territories first.`,
        [
          { text: 'Assign Territory', onPress: () => navigation.navigate('TerritoryManagement') },
          { text: 'OK', style: 'cancel' }
        ]
      );
    }
  };

  const getWorkerStatus = (worker: Worker) => {
    if (!worker.isActive) {
      return { status: 'Offline', color: COLORS.textSecondary };
    }
    
    if (worker.assignedTerritories.length === 0) {
      return { status: 'No Territory', color: COLORS.warning };
    }
    
    if (worker.isInsideTerritory) {
      return { status: 'In Territory', color: COLORS.success };
    } else {
      return { status: 'Outside Territory', color: COLORS.error };
    }
  };

  const formatLastSeen = (timestamp: number) => {
    const now = Date.now();
    const diff = now - timestamp;
    const minutes = Math.floor(diff / (1000 * 60));
    
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;
    
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    
    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.textInverse} />
        </TouchableOpacity>
        <Text style={styles.title}>👥 Worker Tracking</Text>
        <TouchableOpacity onPress={onRefresh}>
          <MaterialIcons name="refresh" size={24} color={COLORS.textInverse} />
        </TouchableOpacity>
      </View>

      {/* Stats Bar */}
      <View style={styles.statsBar}>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{workers.length}</Text>
          <Text style={styles.statLabel}>Total Workers</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{workers.filter(w => w.isActive).length}</Text>
          <Text style={styles.statLabel}>Active</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{workers.filter(w => w.isInsideTerritory).length}</Text>
          <Text style={styles.statLabel}>In Territory</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{workers.filter(w => w.assignedTerritories.length > 0).length}</Text>
          <Text style={styles.statLabel}>Assigned</Text>
        </View>
      </View>

      {/* Workers List */}
      <ScrollView
        style={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {loading ? (
          <View style={styles.loadingContainer}>
            <Text style={styles.loadingText}>Loading workers...</Text>
          </View>
        ) : workers.length === 0 ? (
          <View style={styles.emptyContainer}>
            <MaterialIcons name="people-outline" size={64} color={COLORS.textSecondary} />
            <Text style={styles.emptyText}>No workers found</Text>
            <Text style={styles.emptySubtext}>Workers will appear here when they start tracking</Text>
          </View>
        ) : (
          workers.map((worker) => {
            const status = getWorkerStatus(worker);
            return (
              <TouchableOpacity
                key={worker.id}
                style={styles.workerCard}
                onPress={() => handleWorkerPress(worker)}
              >
                <View style={styles.workerHeader}>
                  <View style={styles.workerInfo}>
                    <Text style={styles.workerName}>{worker.name}</Text>
                    <Text style={styles.workerEmail}>{worker.email}</Text>
                  </View>
                  <View style={styles.workerStatus}>
                    <View style={[styles.statusDot, { backgroundColor: status.color }]} />
                    <Text style={[styles.statusText, { color: status.color }]}>{status.status}</Text>
                  </View>
                </View>

                <View style={styles.workerDetails}>
                  <View style={styles.detailItem}>
                    <MaterialIcons name="map" size={16} color={COLORS.textSecondary} />
                    <Text style={styles.detailText}>
                      {worker.assignedTerritories.length} territories assigned
                    </Text>
                  </View>
                  
                  <View style={styles.detailItem}>
                    <MaterialIcons name="access-time" size={16} color={COLORS.textSecondary} />
                    <Text style={styles.detailText}>
                      Last seen: {formatLastSeen(worker.lastSeen)}
                    </Text>
                  </View>

                  {worker.currentLocation && (
                    <View style={styles.detailItem}>
                      <MaterialIcons name="location-on" size={16} color={COLORS.textSecondary} />
                      <Text style={styles.detailText}>
                        {worker.currentLocation.latitude.toFixed(4)}, {worker.currentLocation.longitude.toFixed(4)}
                      </Text>
                    </View>
                  )}
                </View>

                {worker.assignedTerritories.length > 0 && (
                  <View style={styles.territoriesPreview}>
                    <Text style={styles.territoriesTitle}>Assigned Territories:</Text>
                    {worker.assignedTerritories.slice(0, 2).map((territory) => (
                      <View key={territory.id} style={styles.territoryTag}>
                        <View style={[styles.territoryColor, { backgroundColor: territory.color }]} />
                        <Text style={styles.territoryName}>{territory.name}</Text>
                      </View>
                    ))}
                    {worker.assignedTerritories.length > 2 && (
                      <Text style={styles.moreTerritoriesText}>
                        +{worker.assignedTerritories.length - 2} more
                      </Text>
                    )}
                  </View>
                )}

                <View style={styles.cardFooter}>
                  <Text style={styles.tapHint}>Tap to view live location and territories</Text>
                  <MaterialIcons name="chevron-right" size={20} color={COLORS.textSecondary} />
                </View>
              </TouchableOpacity>
            );
          })
        )}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  header: {
    backgroundColor: COLORS.primary,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingTop: Platform.OS === 'ios' ? 50 : 30,
    paddingBottom: SPACING.lg,
  },
  title: {
    fontSize: TYPOGRAPHY.xl,
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.textInverse,
  },
  statsBar: {
    backgroundColor: COLORS.cardBackground,
    flexDirection: 'row',
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderLight,
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
  },
  statNumber: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.primary,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.textSecondary,
    marginTop: 2,
  },
  content: {
    flex: 1,
    padding: SPACING.lg,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING['4xl'],
  },
  loadingText: {
    fontSize: TYPOGRAPHY.lg,
    color: COLORS.textSecondary,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING['4xl'],
  },
  emptyText: {
    fontSize: TYPOGRAPHY.xl,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginTop: SPACING.lg,
  },
  emptySubtext: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginTop: SPACING.sm,
  },
  workerCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.md,
  },
  workerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  workerInfo: {
    flex: 1,
  },
  workerName: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
  },
  workerEmail: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    marginTop: 2,
  },
  workerStatus: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: SPACING.xs,
  },
  statusText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
  },
  workerDetails: {
    gap: SPACING.xs,
    marginBottom: SPACING.md,
  },
  detailItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  detailText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
  territoriesPreview: {
    marginBottom: SPACING.md,
  },
  territoriesTitle: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.textPrimary,
    marginBottom: SPACING.xs,
  },
  territoryTag: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  territoryColor: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: SPACING.xs,
  },
  territoryName: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  moreTerritoriesText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    fontStyle: 'italic',
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: SPACING.sm,
    borderTopWidth: 1,
    borderTopColor: COLORS.borderLight,
  },
  tapHint: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.textSecondary,
    fontStyle: 'italic',
  },
});

export default AdminWorkerTrackingScreen;
