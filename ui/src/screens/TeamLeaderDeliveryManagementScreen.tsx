import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  Platform,
  Alert,
  RefreshControl,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { TeamLeaderService } from '../services/TeamLeaderService';
import { BookDelivery } from '../types/ministry';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS, getStatusColor } from '../constants/Colors';

interface TeamLeaderDeliveryManagementScreenProps {
  navigation: any;
}

const TeamLeaderDeliveryManagementScreen: React.FC<TeamLeaderDeliveryManagementScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [deliveries, setDeliveries] = useState<BookDelivery[]>([]);
  const [todayDeliveries, setTodayDeliveries] = useState<BookDelivery[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    if (user?.team_id) {
      loadTeamDeliveries();
    } else {
      Alert.alert(
        'No Team Assigned',
        'You are not currently assigned to a team. Please contact an administrator.',
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    }
  }, [user?.team_id]);

  const loadTeamDeliveries = async () => {
    try {
      setLoading(true);
      
      if (!user?.team_id) {
        console.warn('⚠️ No teamId found for team leader');
        return;
      }

      console.log('📦 Loading team deliveries for team:', user.team_id);
      const [allDeliveries, todayDels] = await Promise.all([
        TeamLeaderService.getTeamDeliveries(user.team_id),
        TeamLeaderService.getTodayTeamDeliveries(user.team_id)
      ]);
      
      setDeliveries(allDeliveries);
      setTodayDeliveries(todayDels);
      console.log('✅ Loaded team deliveries:', allDeliveries.length);
    } catch (error) {
      console.error('❌ Error loading team deliveries:', error);
      Alert.alert('Error', 'Failed to load team deliveries. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadTeamDeliveries();
    setRefreshing(false);
  };

  const handleDeliveryPress = (delivery: BookDelivery) => {
    Alert.alert(
      'Delivery Details',
      `Worker: ${delivery.workerName}\nBook: ${delivery.bookTitle}\nRecipient: ${delivery.recipientName || 'N/A'}\nAddress: ${delivery.recipientAddress}\nStatus: ${delivery.status}`,
      [{ text: 'OK' }]
    );
  };

  const formatDate = (date: Date) => {
    return new Date(date).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getDeliveryIcon = (type: string) => {
    return type === 'door' ? 'door-front' : 'person';
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.textInverse} />
        </TouchableOpacity>
        <Text style={styles.title}>📦 Team Deliveries</Text>
        <TouchableOpacity onPress={onRefresh}>
          <MaterialIcons name="refresh" size={24} color={COLORS.textInverse} />
        </TouchableOpacity>
      </View>

      {/* Stats Bar */}
      <View style={styles.statsBar}>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{deliveries.length}</Text>
          <Text style={styles.statLabel}>Total</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{todayDeliveries.length}</Text>
          <Text style={styles.statLabel}>Today</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>
            {deliveries.filter(d => d.status === 'delivered_to_person' || d.status === 'delivered_to_door').length}
          </Text>
          <Text style={styles.statLabel}>Delivered</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>
            {deliveries.filter(d => d.followUpRequired).length}
          </Text>
          <Text style={styles.statLabel}>Follow-up</Text>
        </View>
      </View>

      {/* Deliveries List */}
      <ScrollView
        style={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {loading ? (
          <View style={styles.loadingContainer}>
            <Text style={styles.loadingText}>Loading team deliveries...</Text>
          </View>
        ) : deliveries.length === 0 ? (
          <View style={styles.emptyContainer}>
            <MaterialIcons name="local-shipping" size={64} color={COLORS.textSecondary} />
            <Text style={styles.emptyText}>No deliveries found</Text>
            <Text style={styles.emptySubtext}>Team deliveries will appear here</Text>
          </View>
        ) : (
          <>
            {todayDeliveries.length > 0 && (
              <>
                <Text style={styles.sectionTitle}>Today's Deliveries</Text>
                {todayDeliveries.map((delivery) => (
                  <TouchableOpacity
                    key={delivery.id}
                    style={styles.deliveryCard}
                    onPress={() => handleDeliveryPress(delivery)}
                  >
                    <View style={styles.deliveryHeader}>
                      <View style={styles.deliveryInfo}>
                        <Text style={styles.deliveryTitle}>{delivery.bookTitle}</Text>
                        <Text style={styles.deliveryWorker}>by {delivery.workerName}</Text>
                      </View>
                      <View style={[styles.statusBadge, { backgroundColor: getStatusColor(delivery.status) }]}>
                        <Text style={styles.statusText}>{delivery.status.replace('_', ' ')}</Text>
                      </View>
                    </View>

                    <View style={styles.deliveryDetails}>
                      <View style={styles.detailItem}>
                        <MaterialIcons name={getDeliveryIcon(delivery.deliveryType) as any} size={16} color={COLORS.textSecondary} />
                        <Text style={styles.detailText}>
                          {delivery.deliveryType === 'door' ? 'Door-to-door' : 'Person-to-person'}
                        </Text>
                      </View>
                      
                      <View style={styles.detailItem}>
                        <MaterialIcons name="location-on" size={16} color={COLORS.textSecondary} />
                        <Text style={styles.detailText} numberOfLines={1}>
                          {delivery.recipientAddress}
                        </Text>
                      </View>

                      <View style={styles.detailItem}>
                        <MaterialIcons name="access-time" size={16} color={COLORS.textSecondary} />
                        <Text style={styles.detailText}>
                          {formatDate(delivery.deliveryTime)}
                        </Text>
                      </View>

                      {delivery.followUpRequired && (
                        <View style={styles.followUpBadge}>
                          <MaterialIcons name="flag" size={14} color={COLORS.warning} />
                          <Text style={styles.followUpText}>Follow-up required</Text>
                        </View>
                      )}
                    </View>
                  </TouchableOpacity>
                ))}
              </>
            )}

            <Text style={styles.sectionTitle}>All Deliveries</Text>
            {deliveries.slice(0, 20).map((delivery) => (
              <TouchableOpacity
                key={delivery.id}
                style={styles.deliveryCard}
                onPress={() => handleDeliveryPress(delivery)}
              >
                <View style={styles.deliveryHeader}>
                  <View style={styles.deliveryInfo}>
                    <Text style={styles.deliveryTitle}>{delivery.bookTitle}</Text>
                    <Text style={styles.deliveryWorker}>by {delivery.workerName}</Text>
                  </View>
                  <View style={[styles.statusBadge, { backgroundColor: getStatusColor(delivery.status) }]}>
                    <Text style={styles.statusText}>{delivery.status.replace('_', ' ')}</Text>
                  </View>
                </View>

                <View style={styles.deliveryDetails}>
                  <View style={styles.detailItem}>
                    <MaterialIcons name={getDeliveryIcon(delivery.deliveryType) as any} size={16} color={COLORS.textSecondary} />
                    <Text style={styles.detailText}>
                      {delivery.deliveryType === 'door' ? 'Door-to-door' : 'Person-to-person'}
                    </Text>
                  </View>
                  
                  <View style={styles.detailItem}>
                    <MaterialIcons name="access-time" size={16} color={COLORS.textSecondary} />
                    <Text style={styles.detailText}>
                      {formatDate(delivery.deliveryTime)}
                    </Text>
                  </View>
                </View>
              </TouchableOpacity>
            ))}
          </>
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
  sectionTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginTop: SPACING.lg,
    marginBottom: SPACING.md,
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
  },
  deliveryCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.md,
  },
  deliveryHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  deliveryInfo: {
    flex: 1,
    marginRight: SPACING.md,
  },
  deliveryTitle: {
    fontSize: TYPOGRAPHY.base,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginBottom: SPACING.xs,
  },
  deliveryWorker: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  statusBadge: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.lg,
  },
  statusText: {
    fontSize: TYPOGRAPHY.xs,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.white,
    textTransform: 'capitalize',
  },
  deliveryDetails: {
    gap: SPACING.sm,
  },
  detailItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  detailText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    flex: 1,
  },
  followUpBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
    marginTop: SPACING.xs,
  },
  followUpText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.warning,
  },
});

export default TeamLeaderDeliveryManagementScreen;

