import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
  Dimensions,
} from 'react-native';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { MinistrySessionService, MinistrySession } from '../services/MinistrySessionService';
import TerritoryMap from '../components/TerritoryMap';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

const { width, height } = Dimensions.get('window');

interface SessionDetailsScreenProps {
  navigation: any;
  route: {
    params: {
      sessionId: string;
    };
  };
}

export default function SessionDetailsScreen({ navigation, route }: SessionDetailsScreenProps) {
  const { user } = useAuth();
  const { sessionId } = route.params;
  const [session, setSession] = useState<MinistrySession | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (user && sessionId) {
      loadSessionDetails();
    }
  }, [user, sessionId]);

  const loadSessionDetails = async () => {
    try {
      setLoading(true);
      const sessionData = await MinistrySessionService.getSession(sessionId);
      
      if (!sessionData) {
        Alert.alert('Error', 'Session not found');
        navigation.goBack();
        return;
      }

      // Check if user has permission to view this session
      if (user?.role !== 'admin' && 
          user?.role !== 'team_leader' && 
          sessionData.userId !== user?.uid) {
        Alert.alert('Access Denied', 'You do not have permission to view this session');
        navigation.goBack();
        return;
      }

      setSession(sessionData);
    } catch (error) {
      console.error('Error loading session details:', error);
      Alert.alert('Error', 'Failed to load session details');
      navigation.goBack();
    } finally {
      setLoading(false);
    }
  };

  const formatDistance = (meters: number): string => {
    if (meters < 1000) {
      return `${Math.round(meters)}m`;
    }
    return `${(meters / 1000).toFixed(2)}km`;
  };

  const formatDuration = (startTime: Date, endTime?: Date): string => {
    const duration = endTime 
      ? endTime.getTime() - startTime.getTime()
      : Date.now() - startTime.getTime();
    
    const seconds = Math.floor(duration / 1000);
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return `${hours}h ${minutes}m ${remainingSeconds}s`;
    } else if (minutes > 0) {
      return `${minutes}m ${remainingSeconds}s`;
    }
    return `${remainingSeconds}s`;
  };

  const formatDateTime = (date: Date): string => {
    return date.toLocaleString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  const calculateAverageSpeed = (session: MinistrySession): number => {
    if (!session.endTime || session.pathPoints.length < 2) return 0;
    
    const durationHours = (session.endTime.getTime() - session.startTime.getTime()) / (1000 * 60 * 60);
    const distanceKm = session.totalDistance / 1000;
    
    return distanceKm / durationHours;
  };

  const getMapCenter = (session: MinistrySession) => {
    if (session.pathPoints.length === 0) return null;
    
    const latSum = session.pathPoints.reduce((sum, point) => sum + point.latitude, 0);
    const lngSum = session.pathPoints.reduce((sum, point) => sum + point.longitude, 0);
    
    return {
      latitude: latSum / session.pathPoints.length,
      longitude: lngSum / session.pathPoints.length,
    };
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={COLORS.primary} />
        <Text style={styles.loadingText}>Loading session details...</Text>
      </View>
    );
  }

  if (!session) {
    return (
      <View style={styles.errorContainer}>
        <MaterialIcons name="error-outline" size={48} color={COLORS.error} />
        <Text style={styles.errorText}>Session not found</Text>
      </View>
    );
  }

  const mapCenter = getMapCenter(session);
  const averageSpeed = calculateAverageSpeed(session);

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity
          style={styles.backButton}
          onPress={() => navigation.goBack()}
        >
          <Ionicons name="arrow-back" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Session Details</Text>
        <View style={styles.headerSpacer} />
      </View>

      <ScrollView style={styles.content}>
        {/* Session Info Card */}
        <View style={styles.infoCard}>
          <View style={styles.infoHeader}>
            <Text style={styles.sessionName}>{session.sessionName}</Text>
            <View style={styles.statusContainer}>
              <View style={[
                styles.statusIndicator,
                { backgroundColor: session.isActive ? COLORS.success : COLORS.text.secondary }
              ]} />
              <Text style={styles.statusText}>
                {session.isActive ? 'Active' : 'Completed'}
              </Text>
            </View>
          </View>
          
          <Text style={styles.userName}>{session.userName}</Text>
          <Text style={styles.userRole}>{session.userRole}</Text>
          
          <View style={styles.timeInfo}>
            <Text style={styles.timeLabel}>Started:</Text>
            <Text style={styles.timeValue}>{formatDateTime(session.startTime)}</Text>
          </View>
          
          {session.endTime && (
            <View style={styles.timeInfo}>
              <Text style={styles.timeLabel}>Ended:</Text>
              <Text style={styles.timeValue}>{formatDateTime(session.endTime)}</Text>
            </View>
          )}
        </View>

        {/* Stats Cards */}
        <View style={styles.statsContainer}>
          <View style={styles.statsRow}>
            <View style={styles.statCard}>
              <MaterialIcons name="timeline" size={24} color={COLORS.primary} />
              <Text style={styles.statValue}>{formatDistance(session.totalDistance)}</Text>
              <Text style={styles.statLabel}>Distance</Text>
            </View>
            <View style={styles.statCard}>
              <MaterialIcons name="schedule" size={24} color={COLORS.secondary} />
              <Text style={styles.statValue}>
                {formatDuration(session.startTime, session.endTime)}
              </Text>
              <Text style={styles.statLabel}>Duration</Text>
            </View>
          </View>
          
          <View style={styles.statsRow}>
            <View style={styles.statCard}>
              <MaterialIcons name="place" size={24} color={COLORS.primary} />
              <Text style={styles.statValue}>{session.pathPoints.length}</Text>
              <Text style={styles.statLabel}>Path Points</Text>
            </View>
            <View style={styles.statCard}>
              <MaterialIcons name="speed" size={24} color={COLORS.secondary} />
              <Text style={styles.statValue}>{averageSpeed.toFixed(1)} km/h</Text>
              <Text style={styles.statLabel}>Avg Speed</Text>
            </View>
          </View>
        </View>

        {/* Path Map */}
        {session.pathPoints.length > 0 && mapCenter && (
          <View style={styles.mapSection}>
            <Text style={styles.sectionTitle}>Session Path</Text>
            <View style={styles.mapContainer}>
              <TerritoryMap
                territories={[]}
                currentLocation={mapCenter}
                pathPoints={session.pathPoints}
                showPath={true}
                pathColor="#002b5b"
                showUserLocation={false}
                style={styles.map}
              />
            </View>
          </View>
        )}

        {/* Path Points Details */}
        {session.pathPoints.length > 0 && (
          <View style={styles.pathPointsSection}>
            <Text style={styles.sectionTitle}>Path Points ({session.pathPoints.length})</Text>
            <View style={styles.pathPointsList}>
              {session.pathPoints.slice(0, 10).map((point, index) => (
                <View key={index} style={styles.pathPointItem}>
                  <View style={styles.pathPointIndex}>
                    <Text style={styles.pathPointIndexText}>{index + 1}</Text>
                  </View>
                  <View style={styles.pathPointInfo}>
                    <Text style={styles.pathPointCoords}>
                      {point.latitude.toFixed(6)}, {point.longitude.toFixed(6)}
                    </Text>
                    <Text style={styles.pathPointTime}>
                      {new Date(point.timestamp).toLocaleTimeString()}
                    </Text>
                  </View>
                  {point.accuracy && (
                    <Text style={styles.pathPointAccuracy}>±{Math.round(point.accuracy)}m</Text>
                  )}
                </View>
              ))}
              
              {session.pathPoints.length > 10 && (
                <View style={styles.morePointsIndicator}>
                  <Text style={styles.morePointsText}>
                    ... and {session.pathPoints.length - 10} more points
                  </Text>
                </View>
              )}
            </View>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.background,
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.background,
  },
  errorText: {
    ...TYPOGRAPHY.body,
    color: COLORS.error,
    marginTop: SPACING.md,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    backgroundColor: COLORS.surface,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
    ...SHADOWS.small,
  },
  backButton: {
    padding: SPACING.xs,
  },
  headerTitle: {
    ...TYPOGRAPHY.h2,
    color: COLORS.text.primary,
    flex: 1,
    textAlign: 'center',
  },
  headerSpacer: {
    width: 40,
  },
  content: {
    flex: 1,
  },
  infoCard: {
    backgroundColor: COLORS.surface,
    margin: SPACING.lg,
    padding: SPACING.lg,
    borderRadius: RADIUS.lg,
    ...SHADOWS.small,
  },
  infoHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  sessionName: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    flex: 1,
    fontWeight: '600',
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: SPACING.xs,
  },
  statusText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '500',
  },
  userName: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    fontWeight: '500',
    marginBottom: SPACING.xs,
  },
  userRole: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginBottom: SPACING.md,
    textTransform: 'capitalize',
  },
  timeInfo: {
    flexDirection: 'row',
    marginBottom: SPACING.xs,
  },
  timeLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    width: 60,
    fontWeight: '500',
  },
  timeValue: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.primary,
    flex: 1,
  },
  statsContainer: {
    marginHorizontal: SPACING.lg,
    marginBottom: SPACING.lg,
  },
  statsRow: {
    flexDirection: 'row',
    marginBottom: SPACING.md,
  },
  statCard: {
    flex: 1,
    backgroundColor: COLORS.surface,
    padding: SPACING.lg,
    borderRadius: RADIUS.lg,
    alignItems: 'center',
    marginHorizontal: SPACING.xs,
    ...SHADOWS.small,
  },
  statValue: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    marginTop: SPACING.xs,
    fontWeight: 'bold',
  },
  statLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  mapSection: {
    marginHorizontal: SPACING.lg,
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
    fontWeight: '600',
  },
  mapContainer: {
    height: 300,
    borderRadius: RADIUS.lg,
    overflow: 'hidden',
    ...SHADOWS.small,
  },
  map: {
    flex: 1,
  },
  pathPointsSection: {
    marginHorizontal: SPACING.lg,
    marginBottom: SPACING.xl,
  },
  pathPointsList: {
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.lg,
    ...SHADOWS.small,
  },
  pathPointItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  pathPointIndex: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  pathPointIndexText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.surface,
    fontWeight: 'bold',
  },
  pathPointInfo: {
    flex: 1,
  },
  pathPointCoords: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.primary,
    fontWeight: '500',
  },
  pathPointTime: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  pathPointAccuracy: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.disabled,
  },
  morePointsIndicator: {
    padding: SPACING.md,
    alignItems: 'center',
  },
  morePointsText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontStyle: 'italic',
  },
});
