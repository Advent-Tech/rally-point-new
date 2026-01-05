import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Animated,
  ActivityIndicator
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useOfflineManager, useNetworkStatus, useSyncStatus } from '../hooks/useOfflineManager';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';

interface OfflineIndicatorProps {
  style?: any;
  showWhenOnline?: boolean;
  compact?: boolean;
  onPress?: () => void;
}

const OfflineIndicator: React.FC<OfflineIndicatorProps> = ({
  style,
  showWhenOnline = false,
  compact = false,
  onPress
}) => {
  const networkStatus = useNetworkStatus();
  const syncStatus = useSyncStatus();
  const [, { syncNow }] = useOfflineManager();

  const handlePress = async () => {
    if (onPress) {
      onPress();
    } else if (networkStatus.isConnected && syncStatus.pendingCount > 0) {
      try {
        await syncNow();
      } catch (error) {
        console.error('Manual sync failed:', error);
      }
    }
  };

  const getIndicatorConfig = () => {
    if (!networkStatus.isConnected) {
      return {
        icon: 'cloud-off',
        text: 'Offline',
        subtext: syncStatus.pendingCount > 0 ? `${syncStatus.pendingCount} pending` : 'No connection',
        color: COLORS.error,
        backgroundColor: COLORS.error + '20',
        borderColor: COLORS.error + '40',
        showIndicator: true
      };
    }

    if (syncStatus.syncInProgress) {
      return {
        icon: 'sync',
        text: 'Syncing...',
        subtext: 'Uploading data',
        color: COLORS.info,
        backgroundColor: COLORS.info + '20',
        borderColor: COLORS.info + '40',
        showIndicator: true
      };
    }

    if (syncStatus.pendingCount > 0) {
      return {
        icon: 'cloud-upload',
        text: 'Sync Pending',
        subtext: `${syncStatus.pendingCount} items to sync`,
        color: COLORS.warning,
        backgroundColor: COLORS.warning + '20',
        borderColor: COLORS.warning + '40',
        showIndicator: true
      };
    }

    if (showWhenOnline && networkStatus.isConnected) {
      return {
        icon: 'cloud-done',
        text: 'Online',
        subtext: syncStatus.lastSyncTime 
          ? `Last sync: ${syncStatus.lastSyncTime.toLocaleTimeString()}`
          : 'Connected',
        color: COLORS.success,
        backgroundColor: COLORS.success + '20',
        borderColor: COLORS.success + '40',
        showIndicator: true
      };
    }

    return {
      showIndicator: false
    };
  };

  const config = getIndicatorConfig();

  if (!config.showIndicator) {
    return null;
  }

  if (compact) {
    return (
      <TouchableOpacity
        style={[
          styles.compactContainer,
          { 
            backgroundColor: config.backgroundColor,
            borderColor: config.borderColor 
          },
          style
        ]}
        onPress={handlePress}
        activeOpacity={0.7}
      >
        {syncStatus.syncInProgress ? (
          <ActivityIndicator size="small" color={config.color} />
        ) : (
          <MaterialIcons name={config.icon as any} size={16} color={config.color} />
        )}
        <Text style={[styles.compactText, { color: config.color }]}>
          {syncStatus.pendingCount > 0 ? syncStatus.pendingCount : ''}
        </Text>
      </TouchableOpacity>
    );
  }

  return (
    <TouchableOpacity
      style={[
        styles.container,
        {
          backgroundColor: config.backgroundColor,
          borderColor: config.borderColor
        },
        style
      ]}
      onPress={handlePress}
      activeOpacity={0.7}
    >
      <View style={styles.iconContainer}>
        {syncStatus.syncInProgress ? (
          <ActivityIndicator size="small" color={config.color} />
        ) : (
          <MaterialIcons name={config.icon as any} size={20} color={config.color} />
        )}
      </View>
      
      <View style={styles.textContainer}>
        <Text style={[styles.mainText, { color: config.color }]}>
          {config.text}
        </Text>
        <Text style={[styles.subText, { color: config.color }]}>
          {config.subtext}
        </Text>
      </View>

      {(networkStatus.isConnected && syncStatus.pendingCount > 0 && !syncStatus.syncInProgress) && (
        <View style={styles.actionContainer}>
          <MaterialIcons name="sync" size={16} color={config.color} />
          <Text style={[styles.actionText, { color: config.color }]}>
            Tap to sync
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
};

// Floating offline indicator that appears at the top of the screen
export const FloatingOfflineIndicator: React.FC = () => {
  const networkStatus = useNetworkStatus();
  const syncStatus = useSyncStatus();

  if (networkStatus.isConnected && syncStatus.pendingCount === 0) {
    return null;
  }

  return (
    <View style={styles.floatingContainer}>
      <OfflineIndicator compact />
    </View>
  );
};

// Banner-style offline indicator
export const OfflineBanner: React.FC<{ onDismiss?: () => void }> = ({ onDismiss }) => {
  const networkStatus = useNetworkStatus();
  const syncStatus = useSyncStatus();

  if (networkStatus.isConnected && syncStatus.pendingCount === 0) {
    return null;
  }

  return (
    <View style={styles.bannerContainer}>
      <OfflineIndicator style={styles.bannerIndicator} />
      {onDismiss && (
        <TouchableOpacity onPress={onDismiss} style={styles.dismissButton}>
          <MaterialIcons name="close" size={16} color={COLORS.text.secondary} />
        </TouchableOpacity>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    marginVertical: SPACING.xs,
  },
  compactContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.full,
    borderWidth: 1,
    minWidth: 32,
    minHeight: 24,
  },
  iconContainer: {
    marginRight: SPACING.sm,
  },
  textContainer: {
    flex: 1,
  },
  mainText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  subText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    marginTop: 2,
    opacity: 0.8,
  },
  compactText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    fontWeight: TYPOGRAPHY.weights.bold,
    marginLeft: SPACING.xs,
  },
  actionContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginLeft: SPACING.sm,
  },
  actionText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  floatingContainer: {
    position: 'absolute',
    top: 50,
    right: SPACING.md,
    zIndex: 1000,
    elevation: 10,
  },
  bannerContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.surface,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  bannerIndicator: {
    flex: 1,
    marginVertical: 0,
  },
  dismissButton: {
    padding: SPACING.xs,
    marginLeft: SPACING.sm,
  },
});

export default OfflineIndicator;
