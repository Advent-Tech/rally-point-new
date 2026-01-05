import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import { MinistryDataService, RecentActivity as ActivityType } from '../services/MinistryDataService';
import { ProfessionalActivityCard } from './ModernCards';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface RecentActivityProps {
  onRefresh?: () => void;
}

const RecentActivity: React.FC<RecentActivityProps> = ({ onRefresh }) => {
  const { user } = useAuth();
  const [activities, setActivities] = useState<ActivityType[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user?.uid) return;

    console.log('📊 Setting up Recent Activity real-time data for user:', user.uid);
    
    const unsubscribe = MinistryDataService.subscribeToRecentActivities(
      user.uid,
      (newActivities) => {
        console.log('📊 Recent activities updated:', newActivities.length, 'activities');
        setActivities(newActivities);
        setLoading(false);
      }
    );

    return () => {
      console.log('📊 Cleaning up Recent Activity subscription');
      unsubscribe();
    };
  }, [user?.uid]);

  const getActivityStatus = (activity: ActivityType): 'completed' | 'pending' | 'active' => {
    return activity.status;
  };

  const getActivityIcon = (activity: ActivityType): string => {
    switch (activity.type) {
      case 'delivery':
        return 'literature';
      case 'survey':
        return 'assignment';
      case 'session':
        return activity.status === 'active' ? 'timer' : 'check-circle';
      case 'contact':
        return 'contact';
      default:
        return 'info';
    }
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <Text style={styles.sectionTitle}>Recent Activity</Text>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading recent activities...</Text>
        </View>
      </View>
    );
  }

  if (activities.length === 0) {
    return (
      <View style={styles.container}>
        <Text style={styles.sectionTitle}>Recent Activity</Text>
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>No recent activities</Text>
          <Text style={styles.emptySubtext}>
            Start your ministry work to see activities here
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.sectionTitle}>Recent Activity</Text>
      
      {activities.slice(0, 5).map((activity) => (
        <ProfessionalActivityCard
          key={activity.id}
          title={activity.title}
          subtitle={activity.subtitle}
          icon={getActivityIcon(activity)}
          status={getActivityStatus(activity)}
          value={MinistryDataService.formatTimestamp(activity.timestamp)}
          style={styles.activityCard}
        />
      ))}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginHorizontal: SPACING.md,
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: 28,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: '#000000',
    marginBottom: SPACING.xl,
  },
  loadingContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING.xl,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
    textAlign: 'center',
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING.xl,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
  },
  emptyText: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  emptySubtext: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.disabled,
    textAlign: 'center',
    marginTop: SPACING.sm,
  },
  activityCard: {
    marginBottom: SPACING.md,
  },
});

export default RecentActivity;
