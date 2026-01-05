import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Image,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { WorkerStatsService, WorkerStats } from '../services/WorkerStatsService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface OverviewCardProps {
  iconSource?: any; // PNG icon from assets
  materialIcon?: string; // Fallback MaterialIcon
  title: string;
  value: string;
  unit: string;
  subtitle: string;
  trend: 'up' | 'down' | 'neutral';
  trendValue: string;
  onMenuPress?: () => void;
}

interface MinistryOverviewProps {
  onRefresh?: () => void;
}

const OverviewCard: React.FC<OverviewCardProps> = ({
  iconSource,
  materialIcon,
  title,
  value,
  unit,
  subtitle,
  trend,
  trendValue,
  onMenuPress,
}) => {
  return (
    <View style={styles.card}>
      {/* Header with Icon and Menu */}
      <View style={styles.cardHeader}>
        <View style={styles.iconContainer}>
          {iconSource ? (
            <Image
              source={iconSource}
              style={styles.cardIcon}
              resizeMode="contain"
            />
          ) : (
            <MaterialIcons
              name={materialIcon as any}
              size={24}
              color="#1e40af"
            />
          )}
        </View>
        <TouchableOpacity
          style={styles.menuButton}
          onPress={onMenuPress}
          activeOpacity={0.7}
        >
          <MaterialIcons name="more-horiz" size={20} color="#9ca3af" />
        </TouchableOpacity>
      </View>

      {/* Title */}
      <Text style={styles.cardTitle}>{title}</Text>

      {/* Value and Trend */}
      <View style={styles.valueContainer}>
        <Text style={styles.value}>{value}</Text>
        <Text style={styles.unit}>{unit}</Text>
        <View style={[
          styles.trendContainer,
          trend === 'up' ? styles.trendUp : trend === 'down' ? styles.trendDown : styles.trendNeutral
        ]}>
          <MaterialIcons
            name={trend === 'up' ? 'trending-up' : trend === 'down' ? 'trending-down' : 'remove'}
            size={16}
            color={trend === 'up' ? '#10b981' : trend === 'down' ? '#ef4444' : '#6b7280'}
          />
          <Text style={[
            styles.trendText,
            trend === 'up' ? styles.trendTextUp : trend === 'down' ? styles.trendTextDown : styles.trendTextNeutral
          ]}>
            {trendValue}
          </Text>
        </View>
      </View>

      {/* Subtitle */}
      <Text style={styles.subtitle}>{subtitle}</Text>
    </View>
  );
};

const MinistryOverview: React.FC<MinistryOverviewProps> = ({ onRefresh }) => {
  const { user } = useAuth();
  const { totalDistance: liveDistance, sessionDuration, isTracking } = useLocation();

  const [stats, setStats] = useState<WorkerStats>({
    totalDistance: 0,
    totalTimeSeconds: 0,
    averageSpeed: 0,
    maxSpeed: 0,
    locationCount: 0,
    sessionCount: 0,
    lastLocationTime: null,
    totalDeliveries: 0,
    todayDeliveries: 0,
    totalDonations: 0,
    totalSurveys: 0,
    totalHours: 0,
    territoriesCovered: 0,
  });
  const [loading, setLoading] = useState(true);

  // Load stats from backend
  const loadStats = useCallback(async () => {
    if (!user?.id) return;

    try {
      console.log('📊 Loading worker stats for user:', user.id);
      const workerStats = await WorkerStatsService.getWorkerStats(30);
      setStats(workerStats);
    } catch (error) {
      console.error('❌ Error loading worker stats:', error);
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => {
    loadStats();

    // Refresh stats every 60 seconds
    const interval = setInterval(loadStats, 60000);
    return () => clearInterval(interval);
  }, [loadStats]);

  // Calculate display values - combine backend stats with live tracking data
  const displayDistance = isTracking
    ? stats.totalDistance + liveDistance
    : stats.totalDistance;

  const displayHours = isTracking
    ? stats.totalHours + (sessionDuration / 60)
    : stats.totalHours;

  const handleMenuPress = (cardType: string) => {
    console.log(`Menu pressed for ${cardType}`);
    if (onRefresh) {
      onRefresh();
    }
    // Refresh stats when menu pressed
    loadStats();
  };

  const formatLastActivity = (timestamp: string | null): string => {
    if (!timestamp) return 'No data';

    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins} min ago`;
    if (diffHours < 24) return `${diffHours} hr ago`;
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;

    return date.toLocaleDateString();
  };

  return (
    <View style={styles.container}>
      {/* Section Title */}
      <Text style={styles.sectionTitle}>Ministry Overview</Text>

      {/* Cards Grid */}
      <View style={styles.grid}>
        <OverviewCard
          iconSource={require('../../assets/distanceIcon.png')}
          title="Distance Covered"
          value={displayDistance.toFixed(1)}
          unit="km"
          subtitle="Total distance"
          trend={stats.sessionCount > 0 ? 'up' : 'neutral'}
          trendValue={stats.sessionCount > 0 ? `${stats.sessionCount} sessions` : 'No data'}
          onMenuPress={() => handleMenuPress('distance')}
        />

        <OverviewCard
          iconSource={require('../../assets/bookIcon.png')}
          title="Books Delivered"
          value={stats.totalDeliveries.toString()}
          unit="books"
          subtitle="Total deliveries"
          trend={stats.totalDeliveries > 0 ? 'up' : 'neutral'}
          trendValue={stats.todayDeliveries > 0 ? `${stats.todayDeliveries} today` : 'No activity'}
          onMenuPress={() => handleMenuPress('books')}
        />

        <OverviewCard
          iconSource={require('../../assets/clockIcon.png')}
          title="Hours Active"
          value={displayHours.toFixed(1)}
          unit="hours"
          subtitle="Total ministry time"
          trend={stats.totalSurveys > 0 ? 'up' : 'neutral'}
          trendValue={stats.totalSurveys > 0 ? `${stats.totalSurveys} surveys` : 'No surveys'}
          onMenuPress={() => handleMenuPress('hours')}
        />

        <OverviewCard
          materialIcon="account-balance-wallet"
          title="Donations Collected"
          value={`$${stats.totalDonations.toFixed(0)}`}
          unit=""
          subtitle="Total donations"
          trend={stats.totalDonations > 0 ? 'up' : 'neutral'}
          trendValue={formatLastActivity(stats.lastLocationTime)}
          onMenuPress={() => handleMenuPress('donations')}
        />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingVertical: SPACING.xl,
    backgroundColor: 'transparent',
  },
  sectionTitle: {
    fontSize: 28,
    fontWeight: TYPOGRAPHY.weights.bold as any,
    color: '#000000',
    marginBottom: SPACING.xl,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },

  card: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    width: '48%',
    marginBottom: SPACING.lg,
    ...SHADOWS.md,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  iconContainer: {
    backgroundColor: '#dbeafe',
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardIcon: {
    width: 24,
    height: 24,
    tintColor: '#1e40af',
  },
  menuButton: {
    padding: SPACING.xs,
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: TYPOGRAPHY.weights.semibold as any,
    color: '#000000',
    marginBottom: SPACING.md,
    lineHeight: 22,
  },
  valueContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
    marginBottom: SPACING.xs,
    flexWrap: 'wrap',
  },
  value: {
    fontSize: 32,
    fontWeight: TYPOGRAPHY.weights.bold as any,
    color: '#000000',
    marginRight: SPACING.xs,
  },
  unit: {
    fontSize: 14,
    color: '#6b7280',
    marginRight: SPACING.sm,
  },
  trendContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  trendUp: {},
  trendDown: {},
  trendNeutral: {},
  trendText: {
    fontSize: 12,
    fontWeight: TYPOGRAPHY.weights.medium as any,
    marginLeft: 2,
  },
  trendTextUp: {
    color: '#10b981',
  },
  trendTextDown: {
    color: '#ef4444',
  },
  trendTextNeutral: {
    color: '#6b7280',
  },
  subtitle: {
    fontSize: 14,
    color: '#6b7280',
    fontWeight: TYPOGRAPHY.weights.normal as any,
  },
});

export default MinistryOverview;
