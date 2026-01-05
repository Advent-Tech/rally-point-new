import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useLocation } from '../contexts/LocationContext';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { formatDistance } from '../utils/territoryUtils';

interface DistanceTrackingDisplayProps {
  style?: any;
  compact?: boolean;
  showPath?: boolean;
}

const DistanceTrackingDisplay: React.FC<DistanceTrackingDisplayProps> = ({
  style,
  compact = false,
  showPath = false
}) => {
  const { 
    isTracking, 
    totalDistance, 
    sessionDuration, 
    currentMinistrySession,
    getSessionSummary 
  } = useLocation();
  
  const [animatedDistance] = useState(new Animated.Value(0));
  const [displayDistance, setDisplayDistance] = useState(0);

  // Animate distance changes
  useEffect(() => {
    const targetDistance = currentMinistrySession?.totalDistance || totalDistance;
    
    Animated.timing(animatedDistance, {
      toValue: targetDistance,
      duration: 500,
      useNativeDriver: false,
    }).start();

    // Update display distance smoothly
    const listener = animatedDistance.addListener(({ value }) => {
      setDisplayDistance(value);
    });

    return () => {
      animatedDistance.removeListener(listener);
    };
  }, [currentMinistrySession?.totalDistance, totalDistance]);

  // Format duration for display
  const formatDuration = (minutes: number): string => {
    if (minutes < 60) {
      return `${Math.floor(minutes)}m`;
    } else {
      const hours = Math.floor(minutes / 60);
      const remainingMinutes = Math.floor(minutes % 60);
      return `${hours}h ${remainingMinutes}m`;
    }
  };

  // Get session summary
  const sessionSummary = getSessionSummary();

  if (!isTracking && !sessionSummary) {
    return null;
  }

  if (compact) {
    return (
      <View style={[styles.compactContainer, style]}>
        <View style={styles.compactMetric}>
          <MaterialIcons name="straighten" size={16} color={COLORS.primary} />
          <Text style={styles.compactValue}>
            {formatDistance(displayDistance)}
          </Text>
        </View>
        
        {sessionDuration > 0 && (
          <View style={styles.compactMetric}>
            <MaterialIcons name="schedule" size={16} color={COLORS.secondary} />
            <Text style={styles.compactValue}>
              {formatDuration(sessionDuration)}
            </Text>
          </View>
        )}

        {showPath && sessionSummary && (
          <View style={styles.compactMetric}>
            <MaterialIcons name="timeline" size={16} color={COLORS.success} />
            <Text style={styles.compactValue}>
              {sessionSummary.points}
            </Text>
          </View>
        )}
      </View>
    );
  }

  return (
    <View style={[styles.container, style]}>
      {/* Header */}
      <View style={styles.header}>
        <MaterialIcons name="directions-walk" size={20} color={COLORS.primary} />
        <Text style={styles.headerText}>Ministry Session</Text>
        {isTracking && (
          <View style={styles.liveIndicator}>
            <View style={styles.liveDot} />
            <Text style={styles.liveText}>LIVE</Text>
          </View>
        )}
      </View>

      {/* Metrics */}
      <View style={styles.metricsContainer}>
        {/* Distance */}
        <View style={styles.metric}>
          <View style={styles.metricIcon}>
            <MaterialIcons name="straighten" size={24} color={COLORS.primary} />
          </View>
          <View style={styles.metricContent}>
            <Text style={styles.metricLabel}>Distance</Text>
            <Text style={styles.metricValue}>
              {formatDistance(displayDistance)}
            </Text>
          </View>
        </View>

        {/* Duration */}
        {sessionDuration > 0 && (
          <View style={styles.metric}>
            <View style={styles.metricIcon}>
              <MaterialIcons name="schedule" size={24} color={COLORS.secondary} />
            </View>
            <View style={styles.metricContent}>
              <Text style={styles.metricLabel}>Duration</Text>
              <Text style={styles.metricValue}>
                {formatDuration(sessionDuration)}
              </Text>
            </View>
          </View>
        )}

        {/* Path Points */}
        {showPath && sessionSummary && (
          <View style={styles.metric}>
            <View style={styles.metricIcon}>
              <MaterialIcons name="timeline" size={24} color={COLORS.success} />
            </View>
            <View style={styles.metricContent}>
              <Text style={styles.metricLabel}>Path Points</Text>
              <Text style={styles.metricValue}>
                {sessionSummary.points}
              </Text>
            </View>
          </View>
        )}
      </View>

      {/* Session Info */}
      {currentMinistrySession && (
        <View style={styles.sessionInfo}>
          <Text style={styles.sessionName}>
            {currentMinistrySession.sessionName}
          </Text>
          {currentMinistrySession.territoryName && (
            <Text style={styles.territoryName}>
              📍 {currentMinistrySession.territoryName}
            </Text>
          )}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.background,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginVertical: SPACING.xs,
    ...SHADOWS.sm,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  compactContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: `${COLORS.primary}10`,
    borderRadius: RADIUS.sm,
    padding: SPACING.xs,
    marginVertical: SPACING.xs,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  headerText: {
    ...TYPOGRAPHY.h6,
    color: COLORS.text.primary,
    marginLeft: SPACING.xs,
    flex: 1,
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.error,
    paddingHorizontal: SPACING.xs,
    paddingVertical: 2,
    borderRadius: RADIUS.xs,
  },
  liveDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: COLORS.background,
    marginRight: 4,
  },
  liveText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.background,
    fontWeight: 'bold',
  },
  metricsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.sm,
  },
  metric: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: SPACING.xs,
  },
  metricIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: `${COLORS.primary}15`,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.xs,
  },
  metricContent: {
    flex: 1,
  },
  metricLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginBottom: 2,
  },
  metricValue: {
    ...TYPOGRAPHY.h6,
    color: COLORS.text.primary,
    fontWeight: 'bold',
  },
  compactMetric: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: SPACING.sm,
  },
  compactValue: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.primary,
    fontWeight: 'bold',
    marginLeft: 4,
  },
  sessionInfo: {
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
    paddingTop: SPACING.sm,
  },
  sessionName: {
    ...TYPOGRAPHY.body2,
    color: COLORS.text.primary,
    fontWeight: '600',
    marginBottom: 2,
  },
  territoryName: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
});

export default DistanceTrackingDisplay;
