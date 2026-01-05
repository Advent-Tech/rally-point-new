import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  FlatList,
  Alert,
  StyleSheet,
  SafeAreaView,
  RefreshControl,
  ActivityIndicator
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { Header } from '../components';
import OfflineIndicator from '../components/OfflineIndicator';
import { useOfflineManager } from '../hooks/useOfflineManager';
import {
  SurveyServiceBackend,
  Survey as BackendSurvey,
  SurveyAssignment as BackendSurveyAssignment
} from '../services/SurveyServiceBackend';
// Local types are now replaced by SurveyServiceBackend types
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface SurveysScreenProps {
  navigation: any;
}

const SurveysScreen: React.FC<SurveysScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const { currentLocation } = useLocation();
  const [assignments, setAssignments] = useState<BackendSurveyAssignment[]>([]);
  const [surveys, setSurveys] = useState<Record<string, BackendSurvey>>({});
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [offlineManagerState, offlineManagerActions] = useOfflineManager();

  const loadAssignments = useCallback(async () => {
    if (!user?.id) return;

    try {
      setLoading(true);

      // Get assignments from backend
      const result = await SurveyServiceBackend.getMyAssignments();
      setAssignments(result.assignments);

      // Load survey details for each assignment
      const surveysMap: Record<string, BackendSurvey> = {};

      for (const assignment of result.assignments) {
        try {
          const survey = await SurveyServiceBackend.getSurvey(assignment.survey_id);
          surveysMap[survey.id] = survey;
        } catch (err) {
          console.warn(`Could not load survey ${assignment.survey_id}:`, err);
        }
      }

      setSurveys(surveysMap);
    } catch (error) {
      console.error('Error loading assignments:', error);
      if (offlineManagerState.networkStatus.isConnected) {
        Alert.alert('Error', 'Failed to load surveys');
      }
    } finally {
      setLoading(false);
    }
  }, [user?.id, offlineManagerState.networkStatus.isConnected]);

  useEffect(() => {
    if (user?.id) {
      loadAssignments();
    }
  }, [user?.id, loadAssignments]);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadAssignments();

    // Try to sync offline data
    try {
      await offlineManagerActions.syncNow();
    } catch (error) {
      console.log('Sync failed, will retry later');
    }

    setRefreshing(false);
  };

  const startSurvey = (assignment: BackendSurveyAssignment) => {
    const survey = surveys[assignment.survey_id];
    if (!survey) {
      Alert.alert('Error', 'Survey not found');
      return;
    }

    navigation.navigate('SurveyForm', { surveyId: survey.id });
  };

  const getSurveyStatus = (assignment: BackendSurveyAssignment) => {
    // Check if assignment is complete
    if (assignment.is_complete) {
      return { status: 'completed', label: 'Completed', color: COLORS.success };
    }

    // Check if there's an offline response for this survey
    const hasOfflineResponse = offlineManagerState.offlineResponses.some(
      response => response.surveyId === assignment.survey_id &&
                 response.respondentId === user?.id
    );

    if (hasOfflineResponse) {
      return { status: 'pending_sync', label: 'Pending Sync', color: COLORS.warning };
    }

    return { status: 'not_started', label: 'Not Started', color: COLORS.text.secondary };
  };

  const isOverdue = (assignment: BackendSurveyAssignment) => {
    if (!assignment.due_date) return false;
    return new Date() > new Date(assignment.due_date);
  };

  const renderAssignmentCard = ({ item: assignment }: { item: BackendSurveyAssignment }) => {
    const survey = surveys[assignment.survey_id];
    if (!survey) return null;

    const status = getSurveyStatus(assignment);
    const overdue = isOverdue(assignment);

    return (
      <TouchableOpacity
        style={[
          styles.assignmentCard,
          overdue && styles.overdueCard
        ]}
        onPress={() => startSurvey(assignment)}
        activeOpacity={0.7}
      >
        <View style={styles.cardHeader}>
          <View style={styles.titleContainer}>
            <Text style={styles.surveyTitle}>{survey.title}</Text>
            {overdue && (
              <View style={styles.overdueIndicator}>
                <MaterialIcons name="warning" size={16} color={COLORS.error} />
                <Text style={styles.overdueText}>Overdue</Text>
              </View>
            )}
          </View>

          <View style={[styles.statusBadge, { backgroundColor: status.color + '20' }]}>
            <Text style={[styles.statusText, { color: status.color }]}>
              {status.label}
            </Text>
          </View>
        </View>

        <Text style={styles.surveyDescription} numberOfLines={2}>
          {survey.description || 'No description'}
        </Text>

        <View style={styles.surveyMeta}>
          <View style={styles.metaItem}>
            <MaterialIcons name="quiz" size={16} color={COLORS.text.secondary} />
            <Text style={styles.metaText}>{survey.questions?.length || 0} questions</Text>
          </View>

          {assignment.due_date && (
            <View style={styles.metaItem}>
              <MaterialIcons name="event" size={16} color={COLORS.text.secondary} />
              <Text style={styles.metaText}>
                Due: {new Date(assignment.due_date).toLocaleDateString()}
              </Text>
            </View>
          )}
        </View>

        <View style={styles.cardFooter}>
          <Text style={styles.assignedByText}>
            Assigned on {new Date(assignment.created_at).toLocaleDateString()}
          </Text>

          <TouchableOpacity style={styles.startButton}>
            <Text style={styles.startButtonText}>
              {status.status === 'completed' ? 'View' : status.status === 'pending_sync' ? 'View Response' : 'Start Survey'}
            </Text>
            <MaterialIcons name="arrow-forward" size={16} color={COLORS.background.primary} />
          </TouchableOpacity>
        </View>
      </TouchableOpacity>
    );
  };

  const handleSyncPress = async () => {
    try {
      await offlineManagerActions.syncNow();
      Alert.alert('Success', 'Data synced successfully');
    } catch (error) {
      Alert.alert('Sync Failed', 'Unable to sync data. Please try again later.');
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title="My Surveys"
        showBackButton
        onBackPress={() => navigation.goBack()}
      />

      <View style={styles.content}>
        {/* Offline Indicator */}
        <OfflineIndicator onPress={handleSyncPress} />

        {/* Stats Overview */}
        <View style={styles.statsContainer}>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{assignments.length}</Text>
            <Text style={styles.statLabel}>Assigned</Text>
          </View>
          
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>
              {assignments.filter(a => isOverdue(a)).length}
            </Text>
            <Text style={styles.statLabel}>Overdue</Text>
          </View>
          
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{offlineManagerState.pendingSyncCount}</Text>
            <Text style={styles.statLabel}>Pending</Text>
          </View>
        </View>

        {/* Assignments List */}
        <FlatList
          data={assignments}
          keyExtractor={(item) => item.id}
          renderItem={renderAssignmentCard}
          contentContainerStyle={styles.assignmentsList}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <MaterialIcons name="assignment" size={64} color={COLORS.text.secondary} />
              <Text style={styles.emptyStateText}>No surveys assigned</Text>
              <Text style={styles.emptyStateSubtext}>
                Check back later for new survey assignments
              </Text>
            </View>
          }
        />
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  content: {
    flex: 1,
    padding: SPACING.md,
  },

  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.md,
  },
  statCard: {
    flex: 1,
    backgroundColor: COLORS.background.surface,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    marginHorizontal: SPACING.xs,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  statNumber: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.primary,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  assignmentsList: {
    paddingBottom: SPACING.xl,
  },
  assignmentCard: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  overdueCard: {
    borderColor: COLORS.error,
    borderWidth: 2,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.sm,
  },
  titleContainer: {
    flex: 1,
    marginRight: SPACING.md,
  },
  surveyTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  overdueIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  overdueText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.error,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  statusBadge: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
  },
  statusText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  surveyDescription: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
    marginBottom: SPACING.md,
  },
  surveyMeta: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: SPACING.sm,
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: SPACING.lg,
    marginBottom: SPACING.xs,
  },
  metaText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
  instructionsContainer: {
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.md,
  },
  instructionsLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  instructionsText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    lineHeight: 18,
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  assignedByText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    flex: 1,
  },
  startButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
  },
  startButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.background.primary,
    marginRight: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  emptyState: {
    alignItems: 'center',
    padding: SPACING.xl,
    marginTop: SPACING.xl,
  },
  emptyStateText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  emptyStateSubtext: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
});

export default SurveysScreen;
