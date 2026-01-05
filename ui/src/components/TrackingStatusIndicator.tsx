import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';

export interface TrackingStatus {
  isTracking: boolean;
  isConnected: boolean;
  locationPermission: boolean;
  lastUpdate?: number;
  error?: string;
  workerCount?: number;
  territoryStatus?: 'inside' | 'outside' | 'no-territory' | 'no-location';
}

interface TrackingStatusIndicatorProps {
  status: TrackingStatus;
  onRetry?: () => void;
  onSettings?: () => void;
  compact?: boolean;
  showDetails?: boolean;
}

const TrackingStatusIndicator: React.FC<TrackingStatusIndicatorProps> = ({
  status,
  onRetry,
  onSettings,
  compact = false,
  showDetails = true
}) => {
  const getStatusInfo = () => {
    if (status.error) {
      return {
        icon: 'error',
        color: COLORS.error,
        text: 'Error',
        description: status.error,
        action: 'Retry'
      };
    }

    if (!status.locationPermission) {
      return {
        icon: 'location-disabled',
        color: COLORS.warning,
        text: 'Permission Required',
        description: 'Location access is required for tracking',
        action: 'Enable'
      };
    }

    if (!status.isConnected) {
      return {
        icon: 'cloud-off',
        color: COLORS.warning,
        text: 'Offline',
        description: 'Data will sync when connection is restored',
        action: 'Retry'
      };
    }

    if (!status.isTracking) {
      return {
        icon: 'location-off',
        color: COLORS.textSecondary,
        text: 'Not Tracking',
        description: 'Location tracking is stopped',
        action: null
      };
    }

    // Tracking is active
    const territoryInfo = getTerritoryStatusInfo();
    return {
      icon: 'gps-fixed',
      color: territoryInfo.color,
      text: 'Tracking Active',
      description: territoryInfo.description,
      action: null
    };
  };

  const getTerritoryStatusInfo = () => {
    switch (status.territoryStatus) {
      case 'inside':
        return {
          color: COLORS.success,
          description: 'Worker is inside assigned territory'
        };
      case 'outside':
        return {
          color: COLORS.error,
          description: 'Worker is outside assigned territory'
        };
      case 'no-territory':
        return {
          color: COLORS.warning,
          description: 'No territory assigned to worker'
        };
      case 'no-location':
        return {
          color: COLORS.textSecondary,
          description: 'Location data not available'
        };
      default:
        return {
          color: COLORS.success,
          description: 'Location tracking active'
        };
    }
  };

  const formatLastUpdate = () => {
    if (!status.lastUpdate) return 'Never';
    
    const now = Date.now();
    const diff = now - status.lastUpdate;
    
    if (diff < 60000) { // Less than 1 minute
      return 'Just now';
    } else if (diff < 3600000) { // Less than 1 hour
      return `${Math.floor(diff / 60000)}m ago`;
    } else {
      return `${Math.floor(diff / 3600000)}h ago`;
    }
  };

  const statusInfo = getStatusInfo();

  if (compact) {
    return (
      <View style={styles.compactContainer}>
        <MaterialIcons 
          name={statusInfo.icon as any} 
          size={16} 
          color={statusInfo.color} 
        />
        <Text style={[styles.compactText, { color: statusInfo.color }]}>
          {statusInfo.text}
        </Text>
        {status.workerCount !== undefined && (
          <Text style={styles.workerCount}>
            ({status.workerCount})
          </Text>
        )}
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={styles.statusIcon}>
          <MaterialIcons 
            name={statusInfo.icon as any} 
            size={24} 
            color={statusInfo.color} 
          />
        </View>
        <View style={styles.statusText}>
          <Text style={[styles.statusTitle, { color: statusInfo.color }]}>
            {statusInfo.text}
          </Text>
          {showDetails && (
            <Text style={styles.statusDescription}>
              {statusInfo.description}
            </Text>
          )}
        </View>
        {statusInfo.action && (
          <TouchableOpacity
            style={[styles.actionButton, { borderColor: statusInfo.color }]}
            onPress={statusInfo.action === 'Enable' ? onSettings : onRetry}
          >
            <Text style={[styles.actionText, { color: statusInfo.color }]}>
              {statusInfo.action}
            </Text>
          </TouchableOpacity>
        )}
      </View>

      {showDetails && status.isTracking && (
        <View style={styles.details}>
          <View style={styles.detailItem}>
            <MaterialIcons name="update" size={16} color={COLORS.textSecondary} />
            <Text style={styles.detailText}>
              Last update: {formatLastUpdate()}
            </Text>
          </View>
          
          {status.workerCount !== undefined && (
            <View style={styles.detailItem}>
              <MaterialIcons name="people" size={16} color={COLORS.textSecondary} />
              <Text style={styles.detailText}>
                {status.workerCount} active workers
              </Text>
            </View>
          )}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginVertical: SPACING.xs,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  compactContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    backgroundColor: COLORS.backgroundSecondary,
    borderRadius: RADIUS.sm,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusIcon: {
    marginRight: SPACING.sm,
  },
  statusText: {
    flex: 1,
  },
  statusTitle: {
    fontSize: TYPOGRAPHY.sizes.base,
    fontWeight: TYPOGRAPHY.weights.semibold,
    marginBottom: 2,
  },
  statusDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.textSecondary,
    lineHeight: 18,
  },
  actionButton: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderWidth: 1,
    borderRadius: RADIUS.sm,
  },
  actionText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  compactText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    marginLeft: SPACING.xs,
  },
  workerCount: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
  details: {
    marginTop: SPACING.sm,
    paddingTop: SPACING.sm,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
  },
  detailItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  detailText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
});

export default TrackingStatusIndicator;
