import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
  FlatList,
  Dimensions,
} from 'react-native';
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { DeliveryService } from '../services/DeliveryService';
import { BookDelivery } from '../types/ministry';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface AdminDeliveryAnalyticsScreenProps {
  navigation: any;
}

interface DeliveryStats {
  totalDeliveries: number;
  deliveriesThisWeek: number;
  deliveriesThisMonth: number;
  topWorkers: Array<{ workerId: string; workerName: string; count: number }>;
  topBooks: Array<{ bookTitle: string; count: number }>;
  deliveryMethodBreakdown: { door: number; person: number };
  recentDeliveries: BookDelivery[];
}

const { width: screenWidth } = Dimensions.get('window');

const AdminDeliveryAnalyticsScreen: React.FC<AdminDeliveryAnalyticsScreenProps> = ({ navigation }) => {
  const [stats, setStats] = useState<DeliveryStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedTimeRange, setSelectedTimeRange] = useState<'week' | 'month' | 'all'>('week');
  const [deliveries, setDeliveries] = useState<BookDelivery[]>([]);

  useEffect(() => {
    loadDeliveryStats();
  }, [selectedTimeRange]);

  const loadDeliveryStats = async () => {
    try {
      setLoading(true);
      
      // Calculate date range
      const now = new Date();
      let startDate: Date;
      
      switch (selectedTimeRange) {
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
          break;
        default:
          startDate = new Date(0); // All time
      }

      // Get deliveries for the selected time range
      const allDeliveries = await DeliveryService.getAllDeliveries();
      const filteredDeliveries = allDeliveries.filter(
        delivery => delivery.deliveryTime >= startDate
      );

      // Calculate statistics
      const totalDeliveries = filteredDeliveries.length;
      const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      
      const deliveriesThisWeek = allDeliveries.filter(
        delivery => delivery.deliveryTime >= weekAgo
      ).length;
      
      const deliveriesThisMonth = allDeliveries.filter(
        delivery => delivery.deliveryTime >= monthAgo
      ).length;

      // Top workers
      const workerCounts: Record<string, { name: string; count: number }> = {};
      filteredDeliveries.forEach(delivery => {
        if (!workerCounts[delivery.workerId]) {
          workerCounts[delivery.workerId] = { name: delivery.workerName, count: 0 };
        }
        workerCounts[delivery.workerId].count++;
      });

      const topWorkers = Object.entries(workerCounts)
        .map(([workerId, data]) => ({
          workerId,
          workerName: data.name,
          count: data.count,
        }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 5);

      // Top books
      const bookCounts: Record<string, number> = {};
      filteredDeliveries.forEach(delivery => {
        bookCounts[delivery.bookTitle] = (bookCounts[delivery.bookTitle] || 0) + 1;
      });

      const topBooks = Object.entries(bookCounts)
        .map(([bookTitle, count]) => ({ bookTitle, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 5);

      // Delivery method breakdown
      const deliveryMethodBreakdown = {
        door: filteredDeliveries.filter(d => d.deliveryType === 'door').length,
        person: filteredDeliveries.filter(d => d.deliveryType === 'person').length,
      };

      // Recent deliveries (last 10)
      const recentDeliveries = allDeliveries
        .sort((a, b) => b.deliveryTime.getTime() - a.deliveryTime.getTime())
        .slice(0, 10);

      setStats({
        totalDeliveries,
        deliveriesThisWeek,
        deliveriesThisMonth,
        topWorkers,
        topBooks,
        deliveryMethodBreakdown,
        recentDeliveries,
      });

      setDeliveries(filteredDeliveries);
    } catch (error) {
      console.error('Error loading delivery stats:', error);
      Alert.alert('Error', 'Failed to load delivery statistics');
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (date: Date): string => {
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getDeliveryMethodIcon = (type: string): string => {
    return type === 'door' ? 'home' : 'person';
  };

  const getDeliveryMethodColor = (type: string): string => {
    return type === 'door' ? COLORS.primary.main : COLORS.secondary.main;
  };

  const renderStatCard = (title: string, value: string | number, icon: string, color: string) => (
    <View style={[styles.statCard, { borderLeftColor: color }]}>
      <View style={styles.statCardContent}>
        <View style={styles.statCardHeader}>
          <Text style={styles.statCardTitle}>{title}</Text>
          <Ionicons name={icon as any} size={24} color={color} />
        </View>
        <Text style={[styles.statCardValue, { color }]}>{value}</Text>
      </View>
    </View>
  );

  const renderTopWorkerItem = ({ item }: { item: { workerId: string; workerName: string; count: number } }) => (
    <View style={styles.topItem}>
      <View style={styles.topItemInfo}>
        <View style={styles.workerAvatar}>
          <Text style={styles.workerAvatarText}>{item.workerName.charAt(0).toUpperCase()}</Text>
        </View>
        <Text style={styles.topItemName}>{item.workerName}</Text>
      </View>
      <View style={styles.topItemBadge}>
        <Text style={styles.topItemCount}>{item.count}</Text>
      </View>
    </View>
  );

  const renderTopBookItem = ({ item }: { item: { bookTitle: string; count: number } }) => (
    <View style={styles.topItem}>
      <View style={styles.topItemInfo}>
        <View style={styles.bookIcon}>
          <MaterialIcons name="book" size={20} color={COLORS.primary.main} />
        </View>
        <Text style={styles.topItemName} numberOfLines={2}>{item.bookTitle}</Text>
      </View>
      <View style={styles.topItemBadge}>
        <Text style={styles.topItemCount}>{item.count}</Text>
      </View>
    </View>
  );

  const renderRecentDeliveryItem = ({ item }: { item: BookDelivery }) => (
    <View style={styles.deliveryItem}>
      <View style={styles.deliveryHeader}>
        <View style={styles.deliveryInfo}>
          <Text style={styles.deliveryWorker}>{item.workerName}</Text>
          <Text style={styles.deliveryTime}>{formatDate(item.deliveryTime)}</Text>
        </View>
        <View style={[
          styles.deliveryMethodBadge,
          { backgroundColor: getDeliveryMethodColor(item.deliveryType) }
        ]}>
          <Ionicons 
            name={getDeliveryMethodIcon(item.deliveryType) as any} 
            size={16} 
            color="#FFFFFF" 
          />
        </View>
      </View>
      <Text style={styles.deliveryBook}>{item.bookTitle}</Text>
      {item.recipientName && (
        <Text style={styles.deliveryRecipient}>To: {item.recipientName}</Text>
      )}
      {item.notes && (
        <Text style={styles.deliveryNotes} numberOfLines={2}>{item.notes}</Text>
      )}
    </View>
  );

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Ionicons name="arrow-back" size={24} color={COLORS.text.primary} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Delivery Analytics</Text>
          <View style={{ width: 24 }} />
        </View>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary.main} />
          <Text style={styles.loadingText}>Loading analytics...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Delivery Analytics</Text>
        <TouchableOpacity onPress={loadDeliveryStats}>
          <Ionicons name="refresh" size={24} color={COLORS.primary.main} />
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Time Range Selector */}
        <View style={styles.timeRangeContainer}>
          {(['week', 'month', 'all'] as const).map((range) => (
            <TouchableOpacity
              key={range}
              style={[
                styles.timeRangeButton,
                selectedTimeRange === range && styles.selectedTimeRangeButton
              ]}
              onPress={() => setSelectedTimeRange(range)}
            >
              <Text style={[
                styles.timeRangeButtonText,
                selectedTimeRange === range && styles.selectedTimeRangeButtonText
              ]}>
                {range === 'week' ? 'This Week' : range === 'month' ? 'This Month' : 'All Time'}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {stats && (
          <>
            {/* Overview Stats */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Overview</Text>
              <View style={styles.statsGrid}>
                {renderStatCard(
                  'Total Deliveries',
                  stats.totalDeliveries,
                  'cube',
                  COLORS.primary.main
                )}
                {renderStatCard(
                  'This Week',
                  stats.deliveriesThisWeek,
                  'calendar',
                  COLORS.success.main
                )}
                {renderStatCard(
                  'This Month',
                  stats.deliveriesThisMonth,
                  'trending-up',
                  COLORS.secondary.main
                )}
                {renderStatCard(
                  'Door Deliveries',
                  stats.deliveryMethodBreakdown.door,
                  'home',
                  COLORS.warning.main
                )}
              </View>
            </View>

            {/* Top Workers */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Top Workers</Text>
              <FlatList
                data={stats.topWorkers}
                keyExtractor={(item) => item.workerId}
                renderItem={renderTopWorkerItem}
                scrollEnabled={false}
                ItemSeparatorComponent={() => <View style={styles.separator} />}
              />
            </View>

            {/* Top Books */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Most Delivered Books</Text>
              <FlatList
                data={stats.topBooks}
                keyExtractor={(item) => item.bookTitle}
                renderItem={renderTopBookItem}
                scrollEnabled={false}
                ItemSeparatorComponent={() => <View style={styles.separator} />}
              />
            </View>

            {/* Recent Deliveries */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Recent Deliveries</Text>
              <FlatList
                data={stats.recentDeliveries}
                keyExtractor={(item) => item.id}
                renderItem={renderRecentDeliveryItem}
                scrollEnabled={false}
                ItemSeparatorComponent={() => <View style={styles.separator} />}
              />
            </View>
          </>
        )}
      </ScrollView>
    </SafeAreaView>
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
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
    backgroundColor: '#FFFFFF',
  },
  headerTitle: {
    ...TYPOGRAPHY.h2,
    fontWeight: '700',
    color: COLORS.text.primary,
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  content: {
    flex: 1,
  },
  timeRangeContainer: {
    flexDirection: 'row',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    gap: SPACING.sm,
  },
  timeRangeButton: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.light,
    alignItems: 'center',
  },
  selectedTimeRangeButton: {
    backgroundColor: COLORS.primary.main,
    borderColor: COLORS.primary.main,
  },
  timeRangeButtonText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '500',
  },
  selectedTimeRangeButtonText: {
    color: '#FFFFFF',
  },
  section: {
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.lg,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h3,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  statsGrid: {
    gap: SPACING.md,
  },
  statCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: RADIUS.md,
    borderLeftWidth: 4,
    ...SHADOWS.small,
  },
  statCardContent: {
    padding: SPACING.md,
  },
  statCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.xs,
  },
  statCardTitle: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    fontWeight: '500',
  },
  statCardValue: {
    ...TYPOGRAPHY.h2,
    fontWeight: '700',
  },
  topItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#FFFFFF',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    ...SHADOWS.small,
  },
  topItemInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  workerAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: COLORS.primary.main,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  workerAvatarText: {
    ...TYPOGRAPHY.body,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  bookIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: COLORS.primary.light,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  topItemName: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    fontWeight: '500',
    flex: 1,
  },
  topItemBadge: {
    backgroundColor: COLORS.secondary.main,
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: RADIUS.full,
    minWidth: 32,
    alignItems: 'center',
  },
  topItemCount: {
    ...TYPOGRAPHY.caption,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  deliveryItem: {
    backgroundColor: '#FFFFFF',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    ...SHADOWS.small,
  },
  deliveryHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.xs,
  },
  deliveryInfo: {
    flex: 1,
  },
  deliveryWorker: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
    color: COLORS.text.primary,
  },
  deliveryTime: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
  deliveryMethodBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  deliveryBook: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary.main,
    fontWeight: '500',
    marginBottom: SPACING.xs,
  },
  deliveryRecipient: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  deliveryNotes: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontStyle: 'italic',
  },
  separator: {
    height: SPACING.sm,
  },
});

export default AdminDeliveryAnalyticsScreen;
