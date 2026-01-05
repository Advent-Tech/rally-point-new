import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { MinistrySessionService, MinistrySession } from '../services/MinistrySessionService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface SessionReportsScreenProps {
  navigation: any;
}

export default function SessionReportsScreen({ navigation }: SessionReportsScreenProps) {
  const { user } = useAuth();
  const [sessions, setSessions] = useState<MinistrySession[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [selectedPeriod, setSelectedPeriod] = useState<'today' | 'week' | 'month' | 'all'>('week');
  const [totalStats, setTotalStats] = useState({
    totalSessions: 0,
    totalDistance: 0,
    totalDuration: 0,
    averageDistance: 0,
    averageDuration: 0,
  });

  useEffect(() => {
    if (user) {
      loadSessions();
    }
  }, [user, selectedPeriod]);

  const loadSessions = async () => {
    if (!user) return;

    try {
      setLoading(true);
      
      let startDate: Date | undefined;
      const now = new Date();
      
      switch (selectedPeriod) {
        case 'today':
          startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
          break;
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getFullYear(), now.getMonth(), 1);
          break;
        case 'all':
        default:
          startDate = undefined;
          break;
      }

      // Load sessions based on user role
      let sessionData: MinistrySession[] = [];
      
      if (user.role === 'admin') {
        // Admins can see all sessions
        sessionData = await MinistrySessionService.getAllSessions(startDate);
      } else if (user.role === 'team_leader') {
        // Team leaders can see their team's sessions
        sessionData = await MinistrySessionService.getTeamSessions(user.teamId || '', startDate);
      } else {
        // Workers can only see their own sessions
        sessionData = await MinistrySessionService.getUserSessions(user.uid, startDate);
      }

      setSessions(sessionData);
      calculateStats(sessionData);
    } catch (error) {
      console.error('Error loading sessions:', error);
      Alert.alert('Error', 'Failed to load session reports');
    } finally {
      setLoading(false);
    }
  };

  const calculateStats = (sessionData: MinistrySession[]) => {
    const completedSessions = sessionData.filter(s => !s.isActive);
    const totalSessions = completedSessions.length;
    const totalDistance = completedSessions.reduce((sum, s) => sum + s.totalDistance, 0);
    const totalDuration = completedSessions.reduce((sum, s) => {
      if (s.endTime) {
        return sum + (s.endTime.getTime() - s.startTime.getTime());
      }
      return sum;
    }, 0);

    setTotalStats({
      totalSessions,
      totalDistance,
      totalDuration,
      averageDistance: totalSessions > 0 ? totalDistance / totalSessions : 0,
      averageDuration: totalSessions > 0 ? totalDuration / totalSessions : 0,
    });
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadSessions();
    setRefreshing(false);
  };

  const formatDistance = (meters: number): string => {
    if (meters < 1000) {
      return `${Math.round(meters)}m`;
    }
    return `${(meters / 1000).toFixed(2)}km`;
  };

  const formatDuration = (milliseconds: number): string => {
    const seconds = Math.floor(milliseconds / 1000);
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  const formatDate = (date: Date): string => {
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const handleSessionPress = (session: MinistrySession) => {
    navigation.navigate('SessionDetails', { sessionId: session.id });
  };

  const renderPeriodSelector = () => (
    <View style={styles.periodSelector}>
      {(['today', 'week', 'month', 'all'] as const).map((period) => (
        <TouchableOpacity
          key={period}
          style={[
            styles.periodButton,
            selectedPeriod === period && styles.periodButtonActive,
          ]}
          onPress={() => setSelectedPeriod(period)}
        >
          <Text
            style={[
              styles.periodButtonText,
              selectedPeriod === period && styles.periodButtonTextActive,
            ]}
          >
            {period.charAt(0).toUpperCase() + period.slice(1)}
          </Text>
        </TouchableOpacity>
      ))}
    </View>
  );

  const renderStatsCards = () => (
    <View style={styles.statsContainer}>
      <View style={styles.statsRow}>
        <View style={styles.statCard}>
          <MaterialIcons name="assignment" size={24} color={COLORS.primary} />
          <Text style={styles.statValue}>{totalStats.totalSessions}</Text>
          <Text style={styles.statLabel}>Sessions</Text>
        </View>
        <View style={styles.statCard}>
          <MaterialIcons name="timeline" size={24} color={COLORS.secondary} />
          <Text style={styles.statValue}>{formatDistance(totalStats.totalDistance)}</Text>
          <Text style={styles.statLabel}>Total Distance</Text>
        </View>
      </View>
      <View style={styles.statsRow}>
        <View style={styles.statCard}>
          <MaterialIcons name="schedule" size={24} color={COLORS.primary} />
          <Text style={styles.statValue}>{formatDuration(totalStats.totalDuration)}</Text>
          <Text style={styles.statLabel}>Total Time</Text>
        </View>
        <View style={styles.statCard}>
          <MaterialIcons name="trending-up" size={24} color={COLORS.secondary} />
          <Text style={styles.statValue}>{formatDistance(totalStats.averageDistance)}</Text>
          <Text style={styles.statLabel}>Avg Distance</Text>
        </View>
      </View>
    </View>
  );

  const renderSessionItem = (session: MinistrySession) => {
    const duration = session.endTime 
      ? session.endTime.getTime() - session.startTime.getTime()
      : Date.now() - session.startTime.getTime();

    return (
      <TouchableOpacity
        key={session.id}
        style={styles.sessionCard}
        onPress={() => handleSessionPress(session)}
      >
        <View style={styles.sessionHeader}>
          <View style={styles.sessionInfo}>
            <Text style={styles.sessionName}>{session.sessionName}</Text>
            <Text style={styles.sessionUser}>{session.userName}</Text>
          </View>
          <View style={styles.sessionStatus}>
            <View style={[
              styles.statusIndicator,
              { backgroundColor: session.isActive ? COLORS.success : COLORS.text.secondary }
            ]} />
            <Text style={styles.statusText}>
              {session.isActive ? 'Active' : 'Completed'}
            </Text>
          </View>
        </View>
        
        <View style={styles.sessionStats}>
          <View style={styles.sessionStat}>
            <MaterialIcons name="timeline" size={16} color={COLORS.text.secondary} />
            <Text style={styles.sessionStatText}>{formatDistance(session.totalDistance)}</Text>
          </View>
          <View style={styles.sessionStat}>
            <MaterialIcons name="schedule" size={16} color={COLORS.text.secondary} />
            <Text style={styles.sessionStatText}>{formatDuration(duration)}</Text>
          </View>
          <View style={styles.sessionStat}>
            <MaterialIcons name="place" size={16} color={COLORS.text.secondary} />
            <Text style={styles.sessionStatText}>{session.pathPoints.length} points</Text>
          </View>
        </View>
        
        <Text style={styles.sessionDate}>{formatDate(session.startTime)}</Text>
      </TouchableOpacity>
    );
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={COLORS.primary} />
        <Text style={styles.loadingText}>Loading session reports...</Text>
      </View>
    );
  }

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
        <Text style={styles.headerTitle}>Session Reports</Text>
        <TouchableOpacity
          style={styles.refreshButton}
          onPress={onRefresh}
        >
          <MaterialIcons name="refresh" size={24} color={COLORS.primary} />
        </TouchableOpacity>
      </View>

      <ScrollView
        style={styles.content}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {renderPeriodSelector()}
        {renderStatsCards()}
        
        <View style={styles.sessionsSection}>
          <Text style={styles.sectionTitle}>Recent Sessions</Text>
          {sessions.length === 0 ? (
            <View style={styles.emptyState}>
              <MaterialIcons name="assignment" size={48} color={COLORS.text.disabled} />
              <Text style={styles.emptyStateText}>No sessions found</Text>
              <Text style={styles.emptyStateSubtext}>
                Sessions will appear here once workers start ministry tracking
              </Text>
            </View>
          ) : (
            sessions.map(renderSessionItem)
          )}
        </View>
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
  refreshButton: {
    padding: SPACING.xs,
  },
  content: {
    flex: 1,
  },
  periodSelector: {
    flexDirection: 'row',
    margin: SPACING.lg,
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.xs,
    ...SHADOWS.small,
  },
  periodButton: {
    flex: 1,
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
  },
  periodButtonActive: {
    backgroundColor: COLORS.primary,
  },
  periodButtonText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '600',
  },
  periodButtonTextActive: {
    color: COLORS.surface,
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
  sessionsSection: {
    marginHorizontal: SPACING.lg,
    marginBottom: SPACING.xl,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
    fontWeight: '600',
  },
  sessionCard: {
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.small,
  },
  sessionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  sessionInfo: {
    flex: 1,
  },
  sessionName: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    fontWeight: '600',
    marginBottom: SPACING.xs,
  },
  sessionUser: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
  sessionStatus: {
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
  sessionStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.sm,
  },
  sessionStat: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  sessionStatText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
  sessionDate: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.disabled,
    textAlign: 'right',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: SPACING.xl * 2,
  },
  emptyStateText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
    fontWeight: '500',
  },
  emptyStateSubtext: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.disabled,
    textAlign: 'center',
    marginTop: SPACING.xs,
    paddingHorizontal: SPACING.xl,
  },
});
