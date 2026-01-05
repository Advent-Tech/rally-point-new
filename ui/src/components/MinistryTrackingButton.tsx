import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { realtimeLocationService } from '../services/RealtimeLocationService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import ErrorHandlingService from '../services/ErrorHandlingService';
import TrackingStatusIndicator, { TrackingStatus } from './TrackingStatusIndicator';

interface MinistryTrackingButtonProps {
  isTracking: boolean;
  onTrackingChange: (isTracking: boolean) => void;
  disabled?: boolean;
  style?: any;
}

const MinistryTrackingButton: React.FC<MinistryTrackingButtonProps> = ({
  isTracking: propIsTracking,
  onTrackingChange,
  disabled = false,
  style,
}) => {
  const { user } = useAuth();
  const { isTracking: contextIsTracking, startTracking, stopTracking, requestPermission, locationPermission } = useLocation();
  const [isLoading, setIsLoading] = useState(false);
  const [trackingStatus, setTrackingStatus] = useState<TrackingStatus>({
    isTracking: false,
    isConnected: true,
    locationPermission: false,
  });
  const errorHandler = ErrorHandlingService.getInstance();

  // Use LocationContext tracking state as the source of truth
  const isTracking = contextIsTracking;

  // Update tracking status
  useEffect(() => {
    setTrackingStatus(prev => ({
      ...prev,
      isTracking: contextIsTracking,
      locationPermission,
      lastUpdate: contextIsTracking ? Date.now() : prev.lastUpdate,
    }));
  }, [contextIsTracking, locationPermission]);

  // Request location permission helper
  const requestLocationPermission = async (): Promise<boolean> => {
    try {
      return await requestPermission();
    } catch (error) {
      const errorInfo = errorHandler.handleLocationError(error, 'requestLocationPermission');
      setTrackingStatus(prev => ({ ...prev, error: errorInfo.message }));
      return false;
    }
  };

  const handleTrackingToggle = async () => {
    if (!user) {
      Alert.alert('Error', 'User not authenticated');
      return;
    }

    if (isLoading) return;

    setIsLoading(true);

    try {
      if (isTracking) {
        // Stop tracking
        console.log('🛑 Stopping ministry tracking...');

        // Stop both LocationContext and RealtimeLocationService
        await stopTracking();
        await realtimeLocationService.stopLocationTracking();

        Alert.alert(
          'Ministry Tracking Stopped',
          'Your location tracking has been stopped successfully.',
          [{ text: 'OK' }]
        );

        onTrackingChange(false);
      } else {
        // Start tracking - ensure location permission first
        console.log('🚀 Starting ministry tracking...');

        // Request location permission first
        const hasPermission = await requestLocationPermission();
        if (!hasPermission) {
          Alert.alert(
            'Location Permission Required',
            'Please allow location access to start ministry tracking.',
            [{ text: 'OK' }]
          );
          return;
        }

        // Start LocationContext tracking (for local state management)
        await startTracking();

        // Start RealtimeLocationService tracking (for Firebase real-time updates)
        await realtimeLocationService.startLocationTracking(
          user.id || user.email,
          user.displayName || user.email
        );

        Alert.alert(
          'Ministry Tracking Started',
          'Your location is now being tracked for ministry work. Stay safe!',
          [{ text: 'OK' }]
        );

        onTrackingChange(true);
      }
    } catch (error: any) {
      console.error('❌ Ministry tracking error:', error);

      const errorInfo = errorHandler.handleTrackingError(
        error,
        !isTracking, // isStarting
        'handleTrackingToggle'
      );

      setTrackingStatus(prev => ({ ...prev, error: errorInfo.message }));

      // Show specific alert for permission errors
      if (error.message && error.message.includes('PERMISSION_DENIED')) {
        Alert.alert(
          '🔒 Database Permission Error',
          'Firebase Realtime Database security rules are blocking location updates.\n\nThis needs to be fixed in Firebase Console:\n\n1. Go to Firebase Console\n2. Navigate to Realtime Database > Rules\n3. Update rules to allow authenticated users\n4. Click Publish\n\nContact your administrator to fix this issue.',
          [
            { text: 'OK', style: 'cancel' },
            {
              text: 'Copy Solution',
              onPress: () => {
                // Copy solution to clipboard if available
                console.log('📋 Firebase Rules Solution:');
                console.log('{"rules": {".read": "auth != null", ".write": "auth != null"}}');
              }
            }
          ]
        );
      } else if (error.message && error.message.includes('timeout')) {
        Alert.alert(
          '⏱️ Location Timeout',
          'Location request timed out. This can happen if:\n\n• GPS is disabled\n• Location permission is not granted\n• Poor network connection\n• Browser location services are slow\n\nPlease check your settings and try again.',
          [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Try Again', onPress: () => handleTrackingToggle() },
            {
              text: 'Help',
              onPress: () => {
                Alert.alert(
                  'Location Help',
                  'To fix location issues:\n\n1. Enable GPS/Location Services\n2. Allow location access for this app\n3. Refresh the page and try again\n4. Try using a different browser if the issue persists',
                  [{ text: 'OK' }]
                );
              }
            }
          ]
        );
      } else {
        errorHandler.showErrorAlert(
          errorInfo,
          () => handleTrackingToggle(), // Retry
          () => {
            // Open settings - could navigate to app settings
            console.log('Open settings requested');
          }
        );
      }
    } finally {
      setIsLoading(false);
    }
  };



  const getButtonText = () => {
    if (isLoading) {
      return isTracking ? 'Stopping...' : 'Getting Location...';
    }
    return isTracking ? 'Stop Ministry' : 'Start Ministry';
  };

  const getButtonIcon = () => {
    if (isLoading) return null;
    return isTracking ? 'stop' : 'play-arrow';
  };

  const getButtonColor = () => {
    if (disabled) return COLORS.textSecondary;
    return isTracking ? COLORS.error : COLORS.success;
  };

  const getButtonBackgroundColor = () => {
    if (disabled) return COLORS.backgroundSecondary;
    return isTracking ? `${COLORS.error}20` : `${COLORS.success}20`;
  };

  return (
    <View style={style}>
      {/* Status Indicator */}
      <TrackingStatusIndicator
        status={trackingStatus}
        onRetry={() => handleTrackingToggle()}
        onSettings={() => {
          console.log('Open settings requested');
        }}
        compact={false}
        showDetails={true}
      />

      {/* Main Tracking Button */}
      <TouchableOpacity
        style={[
          styles.button,
          {
            backgroundColor: getButtonBackgroundColor(),
            borderColor: getButtonColor(),
          },
          disabled && styles.disabledButton,
        ]}
        onPress={handleTrackingToggle}
        disabled={disabled || isLoading}
        activeOpacity={0.8}
      >
        <View style={styles.buttonContent}>
          {isLoading ? (
            <ActivityIndicator size="small" color={getButtonColor()} />
          ) : (
            <MaterialIcons
              name={getButtonIcon() as any}
              size={24}
              color={getButtonColor()}
            />
          )}

          <Text style={[styles.buttonText, { color: getButtonColor() }]}>
            {getButtonText()}
          </Text>

          {isTracking && !isLoading && (
            <View style={styles.liveIndicator}>
              <View style={styles.liveDot} />
              <Text style={styles.liveText}>LIVE</Text>
            </View>
          )}
        </View>

        {isTracking && !isLoading && (
          <View style={styles.trackingStatus}>
            <MaterialIcons name="gps-fixed" size={16} color={COLORS.success} />
            <Text style={styles.trackingStatusText}>Location tracking active</Text>
          </View>
        )}
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  button: {
    borderRadius: RADIUS.lg,
    borderWidth: 2,
    padding: SPACING.lg,
    ...SHADOWS.md,
  },
  disabledButton: {
    opacity: 0.5,
  },
  buttonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: SPACING.xs,
  },
  buttonText: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.bold,
    marginLeft: SPACING.sm,
    marginRight: SPACING.sm,
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: `${COLORS.success}20`,
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    borderWidth: 1,
    borderColor: COLORS.success,
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.success,
    marginRight: SPACING.xs,
  },
  liveText: {
    fontSize: TYPOGRAPHY.xs,
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.success,
  },
  trackingStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  trackingStatusText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.success,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.medium,
  },
});

export default MinistryTrackingButton;
