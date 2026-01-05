import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ViewStyle,
  TextStyle,
} from 'react-native';
import Icon from './Icon';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

// Professional Activity Card
interface ActivityCardProps {
  title: string;
  subtitle: string;
  icon: string;
  status?: 'active' | 'completed' | 'pending';
  value?: string | number;
  onPress?: () => void;
  style?: ViewStyle;
}

export const ProfessionalActivityCard: React.FC<ActivityCardProps> = ({
  title,
  subtitle,
  icon,
  status,
  value,
  onPress,
  style,
}) => {
  const getStatusColor = () => {
    switch (status) {
      case 'active': return COLORS.success;
      case 'completed': return COLORS.secondary;
      case 'pending': return COLORS.warning;
      default: return COLORS.primary;
    }
  };

  return (
    <TouchableOpacity
      style={[styles.activityCard, style]}
      onPress={onPress}
      activeOpacity={0.8}
    >
      <View style={styles.cardHeader}>
        <View style={[styles.iconContainer, { backgroundColor: `${getStatusColor()}15` }]}>
          <Icon name={icon} size={24} color={getStatusColor()} />
        </View>
        {value && (
          <View style={styles.valueContainer}>
            <Text style={styles.valueText}>{value}</Text>
          </View>
        )}
      </View>
      
      <View style={styles.cardContent}>
        <Text style={styles.cardTitle}>{title}</Text>
        <Text style={styles.cardSubtitle}>{subtitle}</Text>
      </View>

      {status && (
        <View style={styles.statusContainer}>
          <View style={[styles.statusDot, { backgroundColor: getStatusColor() }]} />
          <Text style={[styles.statusText, { color: getStatusColor() }]}>
            {status.toUpperCase()}
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
};

// Modern Stats Card
interface StatsCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon: string;
  trend?: 'up' | 'down' | 'neutral';
  trendValue?: string;
  color?: string;
  style?: ViewStyle;
}

export const ModernStatsCard: React.FC<StatsCardProps> = ({
  title,
  value,
  subtitle,
  icon,
  trend,
  trendValue,
  color = COLORS.primary,
  style,
}) => {
  const getTrendColor = () => {
    switch (trend) {
      case 'up': return COLORS.success;
      case 'down': return COLORS.error;
      default: return COLORS.darkGray;
    }
  };

  const getTrendIcon = () => {
    switch (trend) {
      case 'up': return 'trending-up';
      case 'down': return 'trending-down';
      default: return 'trending-flat';
    }
  };

  return (
    <View style={[styles.statsCard, style]}>
      <View style={styles.statsHeader}>
        <View style={[styles.statsIconContainer, { backgroundColor: `${color}15` }]}>
          <Icon name={icon} size={20} color={color} />
        </View>
        {trend && trendValue && (
          <View style={styles.trendContainer}>
            <Icon name={getTrendIcon()} size={12} color={getTrendColor()} />
            <Text style={[styles.trendText, { color: getTrendColor() }]}>
              {trendValue}
            </Text>
          </View>
        )}
      </View>
      
      <Text style={styles.statsValue}>{value}</Text>
      <Text style={styles.statsTitle}>{title}</Text>
      {subtitle && <Text style={styles.statsSubtitle}>{subtitle}</Text>}
    </View>
  );
};

// Progress Card
interface ProgressCardProps {
  title: string;
  progress: number; // 0-100
  current: number;
  total: number;
  icon: string;
  color?: string;
  style?: ViewStyle;
}

export const ProgressCard: React.FC<ProgressCardProps> = ({
  title,
  progress,
  current,
  total,
  icon,
  color = COLORS.secondary,
  style,
}) => {
  return (
    <View style={[styles.progressCard, style]}>
      <View style={styles.progressHeader}>
        <View style={[styles.progressIconContainer, { backgroundColor: `${color}15` }]}>
          <Icon name={icon} size={20} color={color} />
        </View>
        <Text style={styles.progressTitle}>{title}</Text>
      </View>
      
      <View style={styles.progressContent}>
        <View style={styles.progressNumbers}>
          <Text style={styles.progressCurrent}>{current}</Text>
          <Text style={styles.progressTotal}>/ {total}</Text>
        </View>
        
        <View style={styles.progressBarContainer}>
          <View style={styles.progressBarBackground}>
            <View 
              style={[
                styles.progressBarFill, 
                { 
                  width: `${Math.min(progress, 100)}%`,
                  backgroundColor: color,
                }
              ]} 
            />
          </View>
          <Text style={styles.progressPercentage}>{Math.round(progress)}%</Text>
        </View>
      </View>
    </View>
  );
};

// Status Card
interface StatusCardProps {
  title: string;
  subtitle: string;
  status?: 'active' | 'inactive' | 'pending' | 'completed';
  icon?: string;
  value?: string | number;
  onPress?: () => void;
  style?: ViewStyle;
}

export const StatusCard: React.FC<StatusCardProps> = ({
  title,
  subtitle,
  status = 'active',
  icon = 'info',
  value,
  onPress,
  style,
}) => {
  const getStatusColor = () => {
    switch (status) {
      case 'active': return COLORS.success;
      case 'completed': return COLORS.secondary;
      case 'pending': return COLORS.warning;
      case 'inactive': return COLORS.darkGray;
      default: return COLORS.primary;
    }
  };

  const Component = onPress ? TouchableOpacity : View;

  return (
    <Component
      style={[styles.statusCard, style]}
      onPress={onPress}
      activeOpacity={onPress ? 0.8 : 1}
    >
      <View style={styles.statusHeader}>
        <View style={[styles.statusIconContainer, { backgroundColor: `${getStatusColor()}15` }]}>
          <Icon name={icon} size={20} color={getStatusColor()} />
        </View>
        {value && (
          <View style={styles.statusValueContainer}>
            <Text style={styles.statusValue}>{value}</Text>
          </View>
        )}
      </View>
      
      <View style={styles.statusContent}>
        <Text style={styles.statusTitle}>{title}</Text>
        <Text style={styles.statusSubtitle}>{subtitle}</Text>
      </View>

      <View style={styles.statusIndicator}>
        <View style={[styles.statusDot, { backgroundColor: getStatusColor() }]} />
        <Text style={[styles.statusText, { color: getStatusColor() }]}>
          {status.toUpperCase()}
        </Text>
      </View>
    </Component>
  );
};

// Quick Action Card
interface QuickActionCardProps {
  title: string;
  icon: string;
  color?: string;
  onPress?: () => void;
  style?: ViewStyle;
}

export const QuickActionCard: React.FC<QuickActionCardProps> = ({
  title,
  icon,
  color = COLORS.primary,
  onPress,
  style,
}) => {
  return (
    <TouchableOpacity
      style={[styles.quickActionCard, style]}
      onPress={onPress}
      activeOpacity={0.8}
    >
      <View style={[styles.quickActionIcon, { backgroundColor: `${color}15` }]}>
        <Icon name={icon} size={24} color={color} />
      </View>
      <Text style={styles.quickActionTitle}>{title}</Text>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  // Activity Card Styles
  activityCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.cardBorder,
    ...SHADOWS.md,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: RADIUS.lg,
    justifyContent: 'center',
    alignItems: 'center',
  },
  valueContainer: {
    backgroundColor: COLORS.lightGray,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.lg,
  },
  valueText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
  },
  cardContent: {
    marginBottom: SPACING.sm,
  },
  cardTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginBottom: SPACING.xs,
  },
  cardSubtitle: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    lineHeight: TYPOGRAPHY.lineHeight.normal * TYPOGRAPHY.sm,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 6,
    height: 6,
    borderRadius: RADIUS.full,
    marginRight: SPACING.xs,
  },
  statusText: {
    fontSize: TYPOGRAPHY.xs,
    fontWeight: TYPOGRAPHY.semibold,
    letterSpacing: 0.5,
  },

  // Stats Card Styles
  statsCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.cardBorder,
    ...SHADOWS.sm,
  },
  statsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  statsIconContainer: {
    width: 36,
    height: 36,
    borderRadius: RADIUS.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  trendContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  trendText: {
    fontSize: TYPOGRAPHY.xs,
    fontWeight: TYPOGRAPHY.medium,
    marginLeft: SPACING.xs,
  },
  statsValue: {
    fontSize: TYPOGRAPHY['3xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.textPrimary,
    marginBottom: SPACING.xs,
  },
  statsTitle: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.textSecondary,
  },
  statsSubtitle: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.textTertiary,
    marginTop: SPACING.xs,
  },

  // Progress Card Styles
  progressCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.cardBorder,
    ...SHADOWS.sm,
  },
  progressHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  progressIconContainer: {
    width: 32,
    height: 32,
    borderRadius: RADIUS.md,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  progressTitle: {
    fontSize: TYPOGRAPHY.base,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.textPrimary,
  },
  progressContent: {
    gap: SPACING.md,
  },
  progressNumbers: {
    flexDirection: 'row',
    alignItems: 'baseline',
  },
  progressCurrent: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.textPrimary,
  },
  progressTotal: {
    fontSize: TYPOGRAPHY.base,
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
  progressBarContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.md,
  },
  progressBarBackground: {
    flex: 1,
    height: 6,
    backgroundColor: COLORS.lightGray,
    borderRadius: RADIUS.full,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: RADIUS.full,
  },
  progressPercentage: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.textSecondary,
    minWidth: 35,
    textAlign: 'right',
  },

  // Status Card Styles
  statusCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.cardBorder,
    ...SHADOWS.sm,
  },
  statusHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  statusIconContainer: {
    width: 36,
    height: 36,
    borderRadius: RADIUS.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  statusValueContainer: {
    backgroundColor: COLORS.lightGray,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.lg,
  },
  statusValue: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
  },
  statusContent: {
    marginBottom: SPACING.md,
  },
  statusTitle: {
    fontSize: TYPOGRAPHY.base,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginBottom: SPACING.xs,
  },
  statusSubtitle: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    lineHeight: TYPOGRAPHY.lineHeight.normal * TYPOGRAPHY.sm,
  },
  statusIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
  },

  // Quick Action Card Styles
  quickActionCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.cardBorder,
    ...SHADOWS.sm,
  },
  quickActionIcon: {
    width: 48,
    height: 48,
    borderRadius: RADIUS.lg,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  quickActionTitle: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.textPrimary,
    textAlign: 'center',
  },
});
