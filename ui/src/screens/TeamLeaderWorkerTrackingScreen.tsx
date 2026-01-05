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
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { WorkerData } from '../services/RealtimeLocationService';
import { Territory, territoryService } from '../services/TerritoryService';
import { TeamLeaderService } from '../services/TeamLeaderService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import {
  getWorkerTerritoryStatus,
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

interface TeamLeaderWorkerTrackingScreenProps {
  navigation: any;
}

const TeamLeaderWorkerTrackingScreen: React.FC<TeamLeaderWorkerTrackingScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  // Normalize team id across possible shapes
  const teamId = user?.team_id || (user as any)?.teamId || (user as any)?.teamID || null;
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [selectedWorker, setSelectedWorker] = useState<Worker | null>(null);
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [unsubscribeRef, setUnsubscribeRef] = useState<(() => void) | null>(null);

  useEffect(() => {
    if (teamId) {
      loadTeamWorkersAndTerritories(teamId);
    } else {
      // Show an empty state instead of navigating away
      setLoading(false);
    }
  }, [teamId]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (unsubscribeRef) {
        console.log('🧹 Component unmounting - cleaning up Firebase listener');
        unsubscribeRef();
      }
    };
  }, [unsubscribeRef]);

  const loadTeamWorkersAndTerritories = async (teamIdParam: string) => {
    try {
      setLoading(true);
      
      if (!teamIdParam) {
        console.warn('⚠️ No teamId found for team leader');
        setLoading(false);
        return;
      }

      // Clean up previous listener if it exists
      if (unsubscribeRef) {
        console.log('🧹 Cleaning up previous Firebase listener');
        unsubscribeRef();
        setUnsubscribeRef(null);
      }

      console.log('📋 Loading team territories for team:', teamIdParam);
      
      // Load team territories
      const teamTerritories = await TeamLeaderService.getTeamTerritories(teamIdParam);
      setTerritories(teamTerritories);
      console.log('📋 Loaded team territories:', teamTerritories.length);

      // Listen to real-time worker data (team-scoped)
      const unsubscribe = TeamLeaderService.listenToTeamActiveWorkers(
        teamIdParam,
        async (workersData: WorkerData[]) => {
          console.log('👥 Received team workers data:', workersData.length);
          
          const processedWorkers: Worker[] = [];
          
          for (const workerData of workersData) {
            // Find assigned territories for this worker
            const assignedTerritories = teamTerritories.filter(territory => 
              territory.assignedWorker?.email === workerData.email ||
              territory.assignedWorker?.id === workerData.id
            );
            
            // Check if worker is inside any assigned territory
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
          
          if (processedWorkers.length === 0) {
            setWorkers([]);
          } else {
            setWorkers(processedWorkers);
          }
          setLoading(false);
        }
      );

      // Store the unsubscribe function
      setUnsubscribeRef(() => unsubscribe);
      
      // Add timeout to ensure loading state clears
      setTimeout(() => {
        console.log('⏰ Timeout: Ensuring loading state is cleared');
        setLoading(false);
      }, 5000); // 5 second timeout
    } catch (error) {
      console.error('❌ Error loading team data:', error);
      setLoading(false);
      Alert.alert('Error', 'Failed to load team worker data. Please try again.');
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    if (teamId) {
      await loadTeamWorkersAndTerritories(teamId);
    }
    setRefreshing(false);
  };

  const handleWorkerPress = (worker: Worker) => {
    setSelectedWorker(worker);

    // Navigate to worker detail screen to show full stats
    navigation.navigate('WorkerDetail', {
      workerId: worker.id,
      workerName: worker.name,
      workerEmail: worker.email,
    });
  };

  const handleViewOnMap = (worker: Worker) => {
    if (worker.assignedTerritories.length > 0 || worker.currentLocation) {
      navigation.navigate('AdminLiveMap', {
        workerId: worker.id,
        workerName: worker.name,
        assignedTerritories: worker.assignedTerritories,
        currentLocation: worker.currentLocation,
      });
    } else {
      Alert.alert(
        'No Location Data',
        `${worker.name} doesn't have location data available.`,
        [{ text: 'OK', style: 'cancel' }]
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
        <Text style={styles.title}>👥 Team Worker Tracking</Text>
        <TouchableOpacity onPress={onRefresh}>
          <MaterialIcons name="refresh" size={24} color={COLORS.textInverse} />
        </TouchableOpacity>
      </View>


      {/* Stats Bar */}
      <View style={styles.statsBar}>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{workers.length}</Text>
          <Text style={styles.statLabel}>Team Workers</Text>
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
        {!teamId ? (
          <View style={styles.emptyContainer}>
            <MaterialIcons name="group" size={64} color={COLORS.textSecondary} />
            <Text style={styles.emptyText}>No team assigned</Text>
            <Text style={styles.emptySubtext}>Join a team or contact an administrator to get started.</Text>
            <TouchableOpacity style={styles.actionButton} onPress={() => navigation.navigate('TeamLeaderWorkerManagement')}>
              <Text style={styles.actionButtonText}>Open Team Management</Text>
            </TouchableOpacity>
          </View>
        ) : loading ? (
          <View style={styles.loadingContainer}>
            <Text style={styles.loadingText}>Loading team workers...</Text>
          </View>
        ) : workers.length === 0 ? (
          <View style={styles.emptyContainer}>
            <MaterialIcons name="people-outline" size={64} color={COLORS.textSecondary} />
            <Text style={styles.emptyText}>No workers to display</Text>
            <Text style={styles.emptySubtext}>When your team members start tracking, they will appear here.</Text>
            <TouchableOpacity style={styles.actionButton} onPress={onRefresh}>
              <Text style={styles.actionButtonText}>Refresh</Text>
            </TouchableOpacity>
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
                  <Text style={styles.tapHint}>Tap to view worker details</Text>
                  <View style={styles.cardActions}>
                    <TouchableOpacity
                      style={styles.mapButton}
                      onPress={(e) => {
                        e.stopPropagation();
                        handleViewOnMap(worker);
                      }}
                    >
                      <MaterialIcons name="map" size={18} color={COLORS.primary} />
                      <Text style={styles.mapButtonText}>Map</Text>
                    </TouchableOpacity>
                    <MaterialIcons name="chevron-right" size={20} color={COLORS.textSecondary} />
                  </View>
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
    paddingTop: Platform.OS === 'ios' ? 50 : 40,
    paddingHorizontal: SPACING.xl,
    paddingBottom: SPACING.lg,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    ...SHADOWS.lg,
  },
  title: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.white,
  },
  statsBar: {
    flexDirection: 'row',
    backgroundColor: COLORS.white,
    paddingVertical: SPACING.lg,
    paddingHorizontal: SPACING.md,
    ...SHADOWS.sm,
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
  },
  statNumber: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.primary,
    marginBottom: SPACING.xs,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
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
    fontSize: TYPOGRAPHY.base,
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
    fontSize: TYPOGRAPHY.base,
    color: COLORS.textSecondary,
    marginTop: SPACING.sm,
    textAlign: 'center',
  },
  workerCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
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
    marginBottom: SPACING.xs,
  },
  workerEmail: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  workerStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: RADIUS.full,
  },
  statusText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
  },
  workerDetails: {
    gap: SPACING.sm,
    marginBottom: SPACING.md,
  },
  detailItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  detailText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  territoriesPreview: {
    marginTop: SPACING.md,
    paddingTop: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.borderFlat,
  },
  territoriesTitle: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.textPrimary,
    marginBottom: SPACING.sm,
  },
  territoryTag: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    marginBottom: SPACING.xs,
  },
  territoryColor: {
    width: 12,
    height: 12,
    borderRadius: RADIUS.sm,
  },
  territoryName: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  moreTerritoriesText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    fontStyle: 'italic',
    marginTop: SPACING.xs,
  },
  cardFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: SPACING.md,
    paddingTop: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.borderFlat,
  },
  tapHint: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.info,
    fontWeight: TYPOGRAPHY.medium,
  },
  cardActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.md,
  },
  mapButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.backgroundSecondary,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.primary,
    gap: SPACING.xs,
  },
  mapButtonText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.primary,
  },
  actionButton: {
    marginTop: SPACING.lg,
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.xl,
    borderRadius: RADIUS.xl,
  },
  actionButtonText: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
  },
});

export default TeamLeaderWorkerTrackingScreen;

