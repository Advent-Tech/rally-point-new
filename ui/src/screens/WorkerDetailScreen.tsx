import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  Platform,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { DeliveryServiceBackend, Delivery } from '../services/DeliveryServiceBackend';
import { DonationServiceBackend } from '../services/DonationServiceBackend';
import { WorkerStatsService, WorkerLocationStats, WorkerSurveyStats } from '../services/WorkerStatsService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface WorkerDetailScreenProps {
  navigation: any;
  route: {
    params: {
      workerId: string;
      workerName: string;
      workerEmail?: string;
      currentLocation?: {
        latitude: number;
        longitude: number;
      };
    };
  };
}

interface WorkerFullStats {
  deliveries: {
    total: number;
    completed: number;
    pending: number;
    today: number;
  };
  surveys: {
    assigned: number;
    completed: number;
    pending: number;
  };
  donations: {
    total: number;
    amount: number;
    today: number;
  };
  location: {
    totalDistance: number;
    totalHours: number;
    sessionCount: number;
  };
}

const WorkerDetailScreen: React.FC<WorkerDetailScreenProps> = ({ navigation, route }) => {
  const { workerId, workerName, workerEmail, currentLocation } = route.params;
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [stats, setStats] = useState<WorkerFullStats>({
    deliveries: { total: 0, completed: 0, pending: 0, today: 0 },
    surveys: { assigned: 0, completed: 0, pending: 0 },
    donations: { total: 0, amount: 0, today: 0 },
    location: { totalDistance: 0, totalHours: 0, sessionCount: 0 },
  });
  const [recentDeliveries, setRecentDeliveries] = useState<Delivery[]>([]);

  const loadWorkerStats = useCallback(async () => {
    try {
      setLoading(true);

      // Load all stats in parallel
      const [
        deliveryResult,
        workerDeliveryStats,
        workerDonationStats,
        workerLocationStats,
        workerSurveyStats,
      ] = await Promise.all([
        DeliveryServiceBackend.getWorkerDeliveries(workerId, 10).catch(() => ({ deliveries: [] })),
        DeliveryServiceBackend.getWorkerStats(workerId).catch(() => ({
          total_deliveries: 0,
          completed_deliveries: 0,
        })),
        DonationServiceBackend.getWorkerStats(workerId, 30).catch(() => ({
          total_donations: 0,
          total_amount: 0,
          today_donations: 0,
        })),
        WorkerStatsService.getWorkerLocationStats(workerId, 30).catch(() => ({
          total_distance_km: 0,
          total_hours: 0,
          session_count: 0,
        })),
        WorkerStatsService.getWorkerSurveyStats(workerId).catch(() => ({
          assigned_count: 0,
          completed_count: 0,
          pending_count: 0,
        })),
      ]);

      const deliveriesList = deliveryResult.deliveries || [];
      const todayDeliveries = deliveriesList.filter(d => {
        const today = new Date().toDateString();
        return new Date(d.created_at).toDateString() === today;
      }).length;

      setStats({
        deliveries: {
          total: workerDeliveryStats.total_deliveries || 0,
          completed: workerDeliveryStats.completed_deliveries || 0,
          pending: (workerDeliveryStats.total_deliveries || 0) - (workerDeliveryStats.completed_deliveries || 0),
          today: todayDeliveries,
        },
        surveys: {
          assigned: workerSurveyStats.assigned_count || 0,
          completed: workerSurveyStats.completed_count || 0,
          pending: workerSurveyStats.pending_count || 0,
        },
        donations: {
          total: workerDonationStats.total_donations || 0,
          amount: workerDonationStats.total_amount || 0,
          today: workerDonationStats.today_donations || 0,
        },
        location: {
          totalDistance: workerLocationStats.total_distance_km || 0,
          totalHours: workerLocationStats.total_hours || 0,
          sessionCount: workerLocationStats.session_count || 0,
        },
      });
      setRecentDeliveries(deliveriesList);

    } catch (error) {
      console.error('Error loading worker stats:', error);
    } finally {
      setLoading(false);
    }
  }, [workerId]);

  useEffect(() => {
    loadWorkerStats();
  }, [loadWorkerStats]);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadWorkerStats();
    setRefreshing(false);
  };

  const handleViewOnMap = () => {
    navigation.navigate('WorkerPathMap', {
      workerId,
      workerName,
      currentLocation,
    });
  };

  const handleViewDeliveries = () => {
    navigation.navigate('WorkerDeliveriesMap', {
      workerId,
      workerName,
      deliveries: recentDeliveries,
    });
  };

  const formatCurrency = (amount: number) => {
    return `$${amount.toFixed(2)}`;
  };

  const formatDistance = (km: number) => {
    return `${km.toFixed(1)} km`;
  };

  const formatHours = (hours: number) => {
    return `${hours.toFixed(1)} hrs`;
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.white} />
        </TouchableOpacity>
        <View style={styles.headerContent}>
          <Text style={styles.headerTitle}>{workerName}</Text>
          {workerEmail && <Text style={styles.headerSubtitle}>{workerEmail}</Text>}
        </View>
        <TouchableOpacity onPress={onRefresh} style={styles.refreshButton}>
          <MaterialIcons name="refresh" size={24} color={COLORS.white} />
        </TouchableOpacity>
      </View>

      {/* Current Location Banner */}
      {currentLocation && (
        <TouchableOpacity style={styles.locationBanner} onPress={handleViewOnMap}>
          <View style={styles.locationInfo}>
            <View style={styles.locationDot} />
            <Text style={styles.locationText}>Currently Active</Text>
          </View>
          <View style={styles.locationAction}>
            <Text style={styles.locationActionText}>View on Map</Text>
            <MaterialIcons name="map" size={20} color={COLORS.primary} />
          </View>
        </TouchableOpacity>
      )}

      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {loading ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color={COLORS.primary} />
            <Text style={styles.loadingText}>Loading worker statistics...</Text>
          </View>
        ) : (
          <>
            {/* Stats Overview */}
            <Text style={styles.sectionTitle}>Performance Overview</Text>
            <View style={styles.statsGrid}>
              {/* Deliveries Card */}
              <TouchableOpacity style={styles.statCard} onPress={handleViewDeliveries}>
                <View style={[styles.statIconContainer, { backgroundColor: '#dbeafe' }]}>
                  <MaterialIcons name="local-shipping" size={24} color="#3b82f6" />
                </View>
                <Text style={styles.statValue}>{stats.deliveries.total}</Text>
                <Text style={styles.statLabel}>Deliveries</Text>
                <View style={styles.statDetails}>
                  <Text style={styles.statDetailText}>
                    {stats.deliveries.completed} completed
                  </Text>
                  <Text style={styles.statDetailText}>
                    {stats.deliveries.today} today
                  </Text>
                </View>
              </TouchableOpacity>

              {/* Surveys Card */}
              <View style={styles.statCard}>
                <View style={[styles.statIconContainer, { backgroundColor: '#dcfce7' }]}>
                  <MaterialIcons name="assignment" size={24} color="#22c55e" />
                </View>
                <Text style={styles.statValue}>{stats.surveys.completed}</Text>
                <Text style={styles.statLabel}>Surveys</Text>
                <View style={styles.statDetails}>
                  <Text style={styles.statDetailText}>
                    {stats.surveys.pending} pending
                  </Text>
                </View>
              </View>

              {/* Donations Card */}
              <View style={styles.statCard}>
                <View style={[styles.statIconContainer, { backgroundColor: '#fef3c7' }]}>
                  <MaterialIcons name="attach-money" size={24} color="#f59e0b" />
                </View>
                <Text style={styles.statValue}>{formatCurrency(stats.donations.amount)}</Text>
                <Text style={styles.statLabel}>Donations</Text>
                <View style={styles.statDetails}>
                  <Text style={styles.statDetailText}>
                    {stats.donations.total} collected
                  </Text>
                  <Text style={styles.statDetailText}>
                    {stats.donations.today} today
                  </Text>
                </View>
              </View>

              {/* Distance Card */}
              <TouchableOpacity style={styles.statCard} onPress={handleViewOnMap}>
                <View style={[styles.statIconContainer, { backgroundColor: '#fce7f3' }]}>
                  <MaterialIcons name="directions-walk" size={24} color="#ec4899" />
                </View>
                <Text style={styles.statValue}>{formatDistance(stats.location.totalDistance)}</Text>
                <Text style={styles.statLabel}>Distance</Text>
                <View style={styles.statDetails}>
                  <Text style={styles.statDetailText}>
                    {formatHours(stats.location.totalHours)} active
                  </Text>
                  <Text style={styles.statDetailText}>
                    {stats.location.sessionCount} sessions
                  </Text>
                </View>
              </TouchableOpacity>
            </View>

            {/* Quick Actions */}
            <Text style={styles.sectionTitle}>Quick Actions</Text>
            <View style={styles.actionsContainer}>
              <TouchableOpacity style={styles.actionCard} onPress={handleViewOnMap}>
                <MaterialIcons name="map" size={28} color={COLORS.primary} />
                <Text style={styles.actionTitle}>View Path</Text>
                <Text style={styles.actionDescription}>See traveled route on map</Text>
              </TouchableOpacity>

              <TouchableOpacity style={styles.actionCard} onPress={handleViewDeliveries}>
                <MaterialIcons name="place" size={28} color={COLORS.success} />
                <Text style={styles.actionTitle}>Delivery Map</Text>
                <Text style={styles.actionDescription}>View delivery locations</Text>
              </TouchableOpacity>
            </View>

            {/* Recent Deliveries */}
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>Recent Deliveries</Text>
              {recentDeliveries.length > 0 && (
                <TouchableOpacity onPress={handleViewDeliveries}>
                  <Text style={styles.viewAllText}>View All</Text>
                </TouchableOpacity>
              )}
            </View>

            {recentDeliveries.length === 0 ? (
              <View style={styles.emptyState}>
                <MaterialIcons name="local-shipping" size={48} color={COLORS.text.secondary} />
                <Text style={styles.emptyText}>No deliveries recorded yet</Text>
              </View>
            ) : (
              recentDeliveries.slice(0, 5).map((delivery) => (
                <View key={delivery.id} style={styles.deliveryCard}>
                  <View style={styles.deliveryHeader}>
                    <View style={styles.deliveryInfo}>
                      <Text style={styles.deliveryTitle}>{delivery.recipient_name}</Text>
                      <Text style={styles.deliveryAddress} numberOfLines={1}>
                        {delivery.address}
                      </Text>
                    </View>
                    <View style={[
                      styles.deliveryStatus,
                      { backgroundColor: delivery.status === 'delivered' ? '#dcfce7' : '#fef3c7' }
                    ]}>
                      <Text style={[
                        styles.deliveryStatusText,
                        { color: delivery.status === 'delivered' ? '#22c55e' : '#f59e0b' }
                      ]}>
                        {delivery.status}
                      </Text>
                    </View>
                  </View>
                  <View style={styles.deliveryMeta}>
                    <View style={styles.deliveryMetaItem}>
                      <MaterialIcons name="schedule" size={14} color={COLORS.text.secondary} />
                      <Text style={styles.deliveryMetaText}>
                        {new Date(delivery.created_at).toLocaleDateString()}
                      </Text>
                    </View>
                    {delivery.latitude && delivery.longitude && (
                      <View style={styles.deliveryMetaItem}>
                        <MaterialIcons name="location-on" size={14} color={COLORS.text.secondary} />
                        <Text style={styles.deliveryMetaText}>
                          {delivery.latitude.toFixed(4)}, {delivery.longitude.toFixed(4)}
                        </Text>
                      </View>
                    )}
                  </View>
                </View>
              ))
            )}

            <View style={styles.bottomPadding} />
          </>
        )}
      </ScrollView>
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
    paddingBottom: SPACING.lg,
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
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.white,
  },
  headerSubtitle: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.8)',
    marginTop: 2,
  },
  refreshButton: {
    padding: SPACING.sm,
  },
  locationBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: COLORS.white,
    marginHorizontal: SPACING.lg,
    marginTop: SPACING.md,
    padding: SPACING.md,
    borderRadius: RADIUS.lg,
    ...SHADOWS.sm,
  },
  locationInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  locationDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#22c55e',
    marginRight: SPACING.sm,
  },
  locationText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#22c55e',
  },
  locationAction: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  locationActionText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.primary,
    marginRight: SPACING.xs,
  },
  content: {
    flex: 1,
    padding: SPACING.lg,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 60,
  },
  loadingText: {
    marginTop: SPACING.md,
    fontSize: 14,
    color: COLORS.text.secondary,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#1e293b',
    marginBottom: SPACING.md,
    marginTop: SPACING.lg,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  viewAllText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.primary,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  statCard: {
    width: '48%',
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  statIconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  statValue: {
    fontSize: 24,
    fontWeight: '700',
    color: '#1e293b',
    marginBottom: 2,
  },
  statLabel: {
    fontSize: 14,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
  },
  statDetails: {
    borderTopWidth: 1,
    borderTopColor: '#f1f5f9',
    paddingTop: SPACING.sm,
  },
  statDetailText: {
    fontSize: 12,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  actionCard: {
    width: '48%',
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    ...SHADOWS.sm,
  },
  actionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1e293b',
    marginTop: SPACING.sm,
  },
  actionDescription: {
    fontSize: 12,
    color: COLORS.text.secondary,
    marginTop: 2,
    textAlign: 'center',
  },
  deliveryCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    ...SHADOWS.sm,
  },
  deliveryHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  deliveryInfo: {
    flex: 1,
    marginRight: SPACING.sm,
  },
  deliveryTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1e293b',
  },
  deliveryAddress: {
    fontSize: 12,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  deliveryStatus: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: RADIUS.sm,
  },
  deliveryStatusText: {
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'capitalize',
  },
  deliveryMeta: {
    flexDirection: 'row',
    marginTop: SPACING.sm,
    paddingTop: SPACING.sm,
    borderTopWidth: 1,
    borderTopColor: '#f1f5f9',
  },
  deliveryMetaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: SPACING.lg,
  },
  deliveryMetaText: {
    fontSize: 12,
    color: COLORS.text.secondary,
    marginLeft: 4,
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: SPACING.xl,
  },
  emptyText: {
    fontSize: 14,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
  },
  bottomPadding: {
    height: 40,
  },
});

export default WorkerDetailScreen;
