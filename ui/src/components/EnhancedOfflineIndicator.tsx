import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Modal,
  ScrollView,
  Alert
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useNetworkStatus, useSyncStatus } from '../hooks/useOfflineManager';
import { useOfflineLocationStats } from '../hooks/useOfflineLocationTracking';
import { useDeliveryStats } from '../hooks/useOfflineDeliveryTracking';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';

interface EnhancedOfflineIndicatorProps {
  userId?: string;
  workerId?: string;
  style?: any;
  showWhenOnline?: boolean;
  compact?: boolean;
  onSyncPress?: () => Promise<void>;
}

export const EnhancedOfflineIndicator: React.FC<EnhancedOfflineIndicatorProps> = ({
  userId,
  workerId,
  style,
  showWhenOnline = false,
  compact = false,
  onSyncPress
}) => {
  const [showDetails, setShowDetails] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);

  const networkStatus = useNetworkStatus();
  const syncStatus = useSyncStatus();
  const locationStats = useOfflineLocationStats(userId);
  const deliveryStats = useDeliveryStats(workerId || '', 7);

  const totalPendingItems = syncStatus.pendingCount + locationStats.pendingSync + deliveryStats.pendingSync;

  const getIndicatorConfig = () => {
    if (!networkStatus.isConnected) {
      return {
        icon: 'cloud-off',
        text: 'Offline',
        subtext: `${totalPendingItems} items pending sync`,
        color: COLORS.error,
        backgroundColor: COLORS.error + '20',
        borderColor: COLORS.error + '40',
        showIndicator: true
      };
    }

    if (syncStatus.syncInProgress || isSyncing) {
      return {
        icon: 'sync',
        text: 'Syncing',
        subtext: 'Uploading offline data...',
        color: COLORS.primary,
        backgroundColor: COLORS.primary + '20',
        borderColor: COLORS.primary + '40',
        showIndicator: true
      };
    }

    if (totalPendingItems > 0) {
      return {
        icon: 'cloud-upload',
        text: 'Sync Pending',
        subtext: `${totalPendingItems} items to sync`,
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
          : 'All data synced',
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

  const handlePress = () => {
    if (totalPendingItems > 0 && networkStatus.isConnected) {
      setShowDetails(true);
    }
  };

  const handleSync = async () => {
    if (!networkStatus.isConnected) {
      Alert.alert('No Internet', 'Please connect to the internet to sync data.');
      return;
    }

    try {
      setIsSyncing(true);
      
      if (onSyncPress) {
        await onSyncPress();
      }
      
      Alert.alert('Sync Complete', 'All offline data has been synchronized.');
    } catch (error) {
      console.error('Sync error:', error);
      Alert.alert('Sync Failed', 'Failed to sync some data. Please try again.');
    } finally {
      setIsSyncing(false);
      setShowDetails(false);
    }
  };

  const config = getIndicatorConfig();

  if (!config.showIndicator) {
    return null;
  }

  if (compact) {
    return (
      <>
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
          {syncStatus.syncInProgress || isSyncing ? (
            <ActivityIndicator size="small" color={config.color} />
          ) : (
            <MaterialIcons name={config.icon as any} size={16} color={config.color} />
          )}
          <Text style={[styles.compactText, { color: config.color }]}>
            {totalPendingItems > 0 ? totalPendingItems : ''}
          </Text>
        </TouchableOpacity>

        <Modal
          visible={showDetails}
          transparent
          animationType="slide"
          onRequestClose={() => setShowDetails(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={styles.modalContent}>
              <View style={styles.modalHeader}>
                <Text style={styles.modalTitle}>Offline Data Status</Text>
                <TouchableOpacity
                  onPress={() => setShowDetails(false)}
                  style={styles.closeButton}
                >
                  <MaterialIcons name="close" size={24} color={COLORS.text} />
                </TouchableOpacity>
              </View>

              <ScrollView style={styles.modalBody}>
                <View style={styles.statusSection}>
                  <Text style={styles.sectionTitle}>Network Status</Text>
                  <View style={styles.statusRow}>
                    <MaterialIcons 
                      name={networkStatus.isConnected ? 'wifi' : 'wifi-off'} 
                      size={20} 
                      color={networkStatus.isConnected ? COLORS.success : COLORS.error} 
                    />
                    <Text style={styles.statusText}>
                      {networkStatus.isConnected ? 'Connected' : 'Offline'}
                    </Text>
                  </View>
                </View>

                <View style={styles.statusSection}>
                  <Text style={styles.sectionTitle}>Location Data</Text>
                  <View style={styles.statusRow}>
                    <MaterialIcons name="location-on" size={20} color={COLORS.primary} />
                    <Text style={styles.statusText}>
                      {locationStats.totalLocations} locations tracked
                    </Text>
                  </View>
                  <View style={styles.statusRow}>
                    <MaterialIcons name="cloud-upload" size={20} color={COLORS.warning} />
                    <Text style={styles.statusText}>
                      {locationStats.pendingSync} pending sync
                    </Text>
                  </View>
                  {locationStats.lastUpdate && (
                    <View style={styles.statusRow}>
                      <MaterialIcons name="schedule" size={20} color={COLORS.textSecondary} />
                      <Text style={styles.statusText}>
                        Last update: {locationStats.lastUpdate.toLocaleTimeString()}
                      </Text>
                    </View>
                  )}
                </View>

                <View style={styles.statusSection}>
                  <Text style={styles.sectionTitle}>Delivery Data</Text>
                  <View style={styles.statusRow}>
                    <MaterialIcons name="local-shipping" size={20} color={COLORS.primary} />
                    <Text style={styles.statusText}>
                      {deliveryStats.totalDeliveries} deliveries recorded
                    </Text>
                  </View>
                  <View style={styles.statusRow}>
                    <MaterialIcons name="cloud-upload" size={20} color={COLORS.warning} />
                    <Text style={styles.statusText}>
                      {deliveryStats.pendingSync} pending sync
                    </Text>
                  </View>
                  <View style={styles.statusRow}>
                    <MaterialIcons name="storage" size={20} color={COLORS.textSecondary} />
                    <Text style={styles.statusText}>
                      {deliveryStats.offlineDeliveries} stored offline
                    </Text>
                  </View>
                </View>

                <View style={styles.statusSection}>
                  <Text style={styles.sectionTitle}>General Sync</Text>
                  <View style={styles.statusRow}>
                    <MaterialIcons name="sync" size={20} color={COLORS.primary} />
                    <Text style={styles.statusText}>
                      {syncStatus.pendingCount} items in sync queue
                    </Text>
                  </View>
                  {syncStatus.lastSyncTime && (
                    <View style={styles.statusRow}>
                      <MaterialIcons name="schedule" size={20} color={COLORS.textSecondary} />
                      <Text style={styles.statusText}>
                        Last sync: {syncStatus.lastSyncTime.toLocaleTimeString()}
                      </Text>
                    </View>
                  )}
                </View>
              </ScrollView>

              {totalPendingItems > 0 && networkStatus.isConnected && (
                <TouchableOpacity
                  style={styles.syncButton}
                  onPress={handleSync}
                  disabled={isSyncing}
                >
                  {isSyncing ? (
                    <ActivityIndicator size="small" color={COLORS.white} />
                  ) : (
                    <MaterialIcons name="sync" size={20} color={COLORS.white} />
                  )}
                  <Text style={styles.syncButtonText}>
                    {isSyncing ? 'Syncing...' : `Sync ${totalPendingItems} Items`}
                  </Text>
                </TouchableOpacity>
              )}
            </View>
          </View>
        </Modal>
      </>
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
        {syncStatus.syncInProgress || isSyncing ? (
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

      {(networkStatus.isConnected && totalPendingItems > 0 && !syncStatus.syncInProgress && !isSyncing) && (
        <View style={styles.actionContainer}>
          <MaterialIcons name="sync" size={16} color={config.color} />
          <Text style={[styles.actionText, { color: config.color }]}>
            Tap for details
          </Text>
        </View>
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
    borderWidth: 1,
    marginHorizontal: SPACING.sm,
  },
  compactContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    borderWidth: 1,
    minWidth: 40,
    justifyContent: 'center',
  },
  iconContainer: {
    marginRight: SPACING.sm,
  },
  textContainer: {
    flex: 1,
  },
  mainText: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
  },
  subText: {
    ...TYPOGRAPHY.caption,
    marginTop: 2,
  },
  compactText: {
    ...TYPOGRAPHY.caption,
    fontWeight: '600',
    marginLeft: 4,
  },
  actionContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginLeft: SPACING.sm,
  },
  actionText: {
    ...TYPOGRAPHY.caption,
    marginLeft: 4,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: COLORS.white,
    borderTopLeftRadius: RADIUS.lg,
    borderTopRightRadius: RADIUS.lg,
    maxHeight: '80%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  modalTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text,
  },
  closeButton: {
    padding: SPACING.xs,
  },
  modalBody: {
    padding: SPACING.lg,
  },
  statusSection: {
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h4,
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  statusText: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    marginLeft: SPACING.sm,
  },
  syncButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.primary,
    margin: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
  },
  syncButtonText: {
    ...TYPOGRAPHY.body,
    color: COLORS.white,
    fontWeight: '600',
    marginLeft: SPACING.sm,
  },
});

export default EnhancedOfflineIndicator;
