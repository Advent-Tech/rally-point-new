import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useNetworkStatus, useSyncStatus } from '../hooks/useOfflineManager';
import OfflineManager from '../services/OfflineManager';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';

interface OfflineSyncStatusProps {
  style?: any;
  compact?: boolean;
  showLocationCount?: boolean;
  showDeliveryCount?: boolean;
}

export const OfflineSyncStatus: React.FC<OfflineSyncStatusProps> = ({
  style,
  compact = false,
  showLocationCount = false,
  showDeliveryCount = false
}) => {
  const [isSyncing, setIsSyncing] = useState(false);
  const [locationCount, setLocationCount] = useState(0);
  const [deliveryCount, setDeliveryCount] = useState(0);

  const networkStatus = useNetworkStatus();
  const syncStatus = useSyncStatus();
  const offlineManager = OfflineManager.getInstance();

  // Load offline counts
  React.useEffect(() => {
    const loadCounts = async () => {
      try {
        const [locations, deliveries] = await Promise.all([
          offlineManager.getOfflineLocations(),
          offlineManager.getOfflineDeliveries()
        ]);
        
        setLocationCount(locations.filter(l => l.syncStatus === 'pending').length);
        setDeliveryCount(deliveries.filter(d => d.syncStatus === 'pending').length);
      } catch (error) {
        console.error('Error loading offline counts:', error);
      }
    };

    loadCounts();
    const interval = setInterval(loadCounts, 5000);
    return () => clearInterval(interval);
  }, [offlineManager]);

  const totalPendingItems = syncStatus.pendingCount + locationCount + deliveryCount;

  const handleSync = async () => {
    if (!networkStatus.isConnected) {
      Alert.alert('No Internet', 'Please connect to the internet to sync offline data.');
      return;
    }

    if (totalPendingItems === 0) {
      Alert.alert('No Data to Sync', 'All data is already synchronized.');
      return;
    }

    try {
      setIsSyncing(true);
      
      const result = await offlineManager.syncOfflineData();
      
      if (result.success > 0) {
        Alert.alert(
          'Sync Complete', 
          `Successfully synced ${result.success} items.${result.failed > 0 ? ` ${result.failed} items failed.` : ''}`
        );
      } else if (result.failed > 0) {
        Alert.alert('Sync Failed', `Failed to sync ${result.failed} items. Please try again.`);
      }
    } catch (error) {
      console.error('Sync error:', error);
      Alert.alert('Sync Error', 'An error occurred while syncing. Please try again.');
    } finally {
      setIsSyncing(false);
    }
  };

  const getStatusConfig = () => {
    if (!networkStatus.isConnected) {
      return {
        icon: 'cloud-off',
        text: 'Offline',
        color: COLORS.error,
        backgroundColor: COLORS.error + '20',
        canSync: false
      };
    }

    if (syncStatus.syncInProgress || isSyncing) {
      return {
        icon: 'sync',
        text: 'Syncing',
        color: COLORS.primary,
        backgroundColor: COLORS.primary + '20',
        canSync: false
      };
    }

    if (totalPendingItems > 0) {
      return {
        icon: 'cloud-upload',
        text: 'Sync Pending',
        color: COLORS.warning,
        backgroundColor: COLORS.warning + '20',
        canSync: true
      };
    }

    return {
      icon: 'cloud-done',
      text: 'Synced',
      color: COLORS.success,
      backgroundColor: COLORS.success + '20',
      canSync: false
    };
  };

  const config = getStatusConfig();

  if (compact) {
    return (
      <TouchableOpacity
        style={[
          styles.compactContainer,
          { backgroundColor: config.backgroundColor },
          style
        ]}
        onPress={handleSync}
        disabled={!config.canSync}
        activeOpacity={0.7}
      >
        {syncStatus.syncInProgress || isSyncing ? (
          <ActivityIndicator size="small" color={config.color} />
        ) : (
          <MaterialIcons name={config.icon as any} size={16} color={config.color} />
        )}
        {totalPendingItems > 0 && (
          <Text style={[styles.compactBadge, { color: config.color }]}>
            {totalPendingItems}
          </Text>
        )}
      </TouchableOpacity>
    );
  }

  return (
    <TouchableOpacity
      style={[
        styles.container,
        { backgroundColor: config.backgroundColor },
        style
      ]}
      onPress={handleSync}
      disabled={!config.canSync}
      activeOpacity={0.7}
    >
      <View style={styles.iconContainer}>
        {syncStatus.syncInProgress || isSyncing ? (
          <ActivityIndicator size="small" color={config.color} />
        ) : (
          <MaterialIcons name={config.icon as any} size={20} color={config.color} />
        )}
      </View>

      <View style={styles.contentContainer}>
        <Text style={[styles.statusText, { color: config.color }]}>
          {config.text}
        </Text>
        
        {totalPendingItems > 0 && (
          <Text style={[styles.countText, { color: config.color }]}>
            {totalPendingItems} items pending
          </Text>
        )}

        {(showLocationCount || showDeliveryCount) && (
          <View style={styles.detailsContainer}>
            {showLocationCount && locationCount > 0 && (
              <View style={styles.detailItem}>
                <MaterialIcons name="location-on" size={12} color={config.color} />
                <Text style={[styles.detailText, { color: config.color }]}>
                  {locationCount} locations
                </Text>
              </View>
            )}
            {showDeliveryCount && deliveryCount > 0 && (
              <View style={styles.detailItem}>
                <MaterialIcons name="local-shipping" size={12} color={config.color} />
                <Text style={[styles.detailText, { color: config.color }]}>
                  {deliveryCount} deliveries
                </Text>
              </View>
            )}
          </View>
        )}
      </View>

      {config.canSync && (
        <MaterialIcons name="chevron-right" size={16} color={config.color} />
      )}
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    marginHorizontal: SPACING.sm,
    marginVertical: SPACING.xs,
  },
  compactContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    minWidth: 40,
    justifyContent: 'center',
  },
  iconContainer: {
    marginRight: SPACING.sm,
  },
  contentContainer: {
    flex: 1,
  },
  statusText: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
  },
  countText: {
    ...TYPOGRAPHY.caption,
    marginTop: 2,
  },
  compactBadge: {
    ...TYPOGRAPHY.caption,
    fontWeight: '600',
    marginLeft: 4,
  },
  detailsContainer: {
    flexDirection: 'row',
    marginTop: SPACING.xs,
  },
  detailItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  detailText: {
    ...TYPOGRAPHY.caption,
    marginLeft: 2,
  },
});

export default OfflineSyncStatus;
