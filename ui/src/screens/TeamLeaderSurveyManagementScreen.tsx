import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  Platform,
  Alert,
  RefreshControl,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { TeamLeaderService } from '../services/TeamLeaderService';
import { SurveyService } from '../services/SurveyService';
import { Survey } from '../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface TeamLeaderSurveyManagementScreenProps {
  navigation: any;
}

const TeamLeaderSurveyManagementScreen: React.FC<TeamLeaderSurveyManagementScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [surveys, setSurveys] = useState<Survey[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    if (user?.team_id) {
      loadTeamSurveys();
    } else {
      Alert.alert(
        'No Team Assigned',
        'You are not currently assigned to a team. Please contact an administrator.',
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    }
  }, [user?.team_id]);

  const loadTeamSurveys = async () => {
    try {
      setLoading(true);
      
      if (!user?.team_id) {
        console.warn('⚠️ No teamId found for team leader');
        return;
      }

      console.log('📋 Loading team surveys for team:', user.team_id);
      const teamSurveys = await TeamLeaderService.getTeamSurveys(user.team_id);
      setSurveys(teamSurveys);
      console.log('✅ Loaded team surveys:', teamSurveys.length);
    } catch (error) {
      console.error('❌ Error loading team surveys:', error);
      Alert.alert('Error', 'Failed to load team surveys. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadTeamSurveys();
    setRefreshing(false);
  };

  const handleCreateSurvey = () => {
    navigation.navigate('SurveyBuilder');
  };

  const handleSurveyPress = (survey: Survey) => {
    navigation.navigate('SurveyResponses', { surveyId: survey.id });
  };

  const handleAssignSurvey = (survey: Survey) => {
    navigation.navigate('SurveyAssignment', { surveyId: survey.id });
  };

  const getSurveyStatusColor = (survey: Survey) => {
    return survey.isActive ? COLORS.success : COLORS.textSecondary;
  };

  const formatDate = (date: Date) => {
    return new Date(date).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.textInverse} />
        </TouchableOpacity>
        <Text style={styles.title}>📋 Team Surveys</Text>
        <TouchableOpacity onPress={handleCreateSurvey}>
          <MaterialIcons name="add" size={24} color={COLORS.textInverse} />
        </TouchableOpacity>
      </View>

      {/* Stats Bar */}
      <View style={styles.statsBar}>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{surveys.length}</Text>
          <Text style={styles.statLabel}>Total Surveys</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{surveys.filter(s => s.isActive).length}</Text>
          <Text style={styles.statLabel}>Active</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statNumber}>{surveys.filter(s => !s.isActive).length}</Text>
          <Text style={styles.statLabel}>Inactive</Text>
        </View>
      </View>

      {/* Surveys List */}
      <ScrollView
        style={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {loading ? (
          <View style={styles.loadingContainer}>
            <Text style={styles.loadingText}>Loading team surveys...</Text>
          </View>
        ) : surveys.length === 0 ? (
          <View style={styles.emptyContainer}>
            <MaterialIcons name="assignment" size={64} color={COLORS.textSecondary} />
            <Text style={styles.emptyText}>No surveys found</Text>
            <Text style={styles.emptySubtext}>Create a survey to get started</Text>
            <TouchableOpacity style={styles.createButton} onPress={handleCreateSurvey}>
              <MaterialIcons name="add" size={20} color={COLORS.white} />
              <Text style={styles.createButtonText}>Create Survey</Text>
            </TouchableOpacity>
          </View>
        ) : (
          surveys.map((survey) => (
            <TouchableOpacity
              key={survey.id}
              style={styles.surveyCard}
              onPress={() => handleSurveyPress(survey)}
            >
              <View style={styles.surveyHeader}>
                <View style={styles.surveyInfo}>
                  <Text style={styles.surveyTitle}>{survey.title}</Text>
                  <Text style={styles.surveyDescription} numberOfLines={2}>
                    {survey.description}
                  </Text>
                </View>
                <View style={[styles.statusBadge, { backgroundColor: getSurveyStatusColor(survey) }]}>
                  <Text style={styles.statusText}>
                    {survey.isActive ? 'Active' : 'Inactive'}
                  </Text>
                </View>
              </View>

              <View style={styles.surveyDetails}>
                <View style={styles.detailItem}>
                  <MaterialIcons name="help-outline" size={16} color={COLORS.textSecondary} />
                  <Text style={styles.detailText}>
                    {survey.questions.length} questions
                  </Text>
                </View>
                
                <View style={styles.detailItem}>
                  <MaterialIcons name="calendar-today" size={16} color={COLORS.textSecondary} />
                  <Text style={styles.detailText}>
                    Created: {formatDate(survey.createdAt)}
                  </Text>
                </View>

                {survey.assignedTo && survey.assignedTo.length > 0 && (
                  <View style={styles.detailItem}>
                    <MaterialIcons name="people" size={16} color={COLORS.textSecondary} />
                    <Text style={styles.detailText}>
                      Assigned to {survey.assignedTo.length} workers
                    </Text>
                  </View>
                )}
              </View>

              <View style={styles.cardActions}>
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => handleAssignSurvey(survey)}
                >
                  <MaterialIcons name="person-add" size={18} color={COLORS.primary} />
                  <Text style={styles.actionButtonText}>Assign</Text>
                </TouchableOpacity>
                
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => handleSurveyPress(survey)}
                >
                  <MaterialIcons name="bar-chart" size={18} color={COLORS.secondary} />
                  <Text style={styles.actionButtonText}>View Responses</Text>
                </TouchableOpacity>
              </View>
            </TouchableOpacity>
          ))
        )}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  header: {
    backgroundColor: COLORS.primary,
    paddingTop: Platform.OS === 'ios' ? 50 : 40,
    paddingHorizontal: SPACING.xl,
    paddingBottom: SPACING.lg,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    ...SHADOWS.lg,
  },
  title: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.white,
  },
  statsBar: {
    flexDirection: 'row',
    backgroundColor: COLORS.white,
    paddingVertical: SPACING.lg,
    paddingHorizontal: SPACING.md,
    ...SHADOWS.sm,
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
  },
  statNumber: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.primary,
    marginBottom: SPACING.xs,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  content: {
    flex: 1,
    padding: SPACING.lg,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING['4xl'],
  },
  loadingText: {
    fontSize: TYPOGRAPHY.base,
    color: COLORS.textSecondary,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING['4xl'],
  },
  emptyText: {
    fontSize: TYPOGRAPHY.xl,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginTop: SPACING.lg,
  },
  emptySubtext: {
    fontSize: TYPOGRAPHY.base,
    color: COLORS.textSecondary,
    marginTop: SPACING.sm,
    marginBottom: SPACING.xl,
  },
  createButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.lg,
  },
  createButtonText: {
    fontSize: TYPOGRAPHY.base,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.white,
  },
  surveyCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.md,
  },
  surveyHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  surveyInfo: {
    flex: 1,
    marginRight: SPACING.md,
  },
  surveyTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginBottom: SPACING.xs,
  },
  surveyDescription: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  statusBadge: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.lg,
  },
  statusText: {
    fontSize: TYPOGRAPHY.xs,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.white,
  },
  surveyDetails: {
    gap: SPACING.sm,
    marginBottom: SPACING.md,
  },
  detailItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  detailText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  cardActions: {
    flexDirection: 'row',
    gap: SPACING.md,
    marginTop: SPACING.md,
    paddingTop: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.borderFlat,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: SPACING.xs,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.lg,
    backgroundColor: COLORS.backgroundSecondary,
  },
  actionButtonText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.textPrimary,
  },
});

export default TeamLeaderSurveyManagementScreen;

