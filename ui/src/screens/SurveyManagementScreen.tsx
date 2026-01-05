import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  FlatList,
  Alert,
  StyleSheet,
  SafeAreaView,
  Modal,
  RefreshControl
} from 'react-native';
import { MaterialIcons, FontAwesome } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { Header } from '../components';
import { SurveyService } from '../services/SurveyService';
import { 
  Survey, 
  SurveyFilters, 
  SurveyAnalytics,
  SurveyAssignment 
} from '../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface SurveyManagementScreenProps {
  navigation: any;
}

const SurveyManagementScreen: React.FC<SurveyManagementScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [surveys, setSurveys] = useState<Survey[]>([]);
  const [filteredSurveys, setFilteredSurveys] = useState<Survey[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedSurvey, setSelectedSurvey] = useState<Survey | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [analytics, setAnalytics] = useState<SurveyAnalytics | null>(null);
  
  const [filters, setFilters] = useState<SurveyFilters>({
    status: 'all',
    hasResponses: undefined,
    dateRange: undefined
  });

  useEffect(() => {
    loadSurveys();
  }, []);

  useEffect(() => {
    filterSurveys();
  }, [surveys, searchQuery, filters]);

  const loadSurveys = async () => {
    try {
      setLoading(true);
      const surveysData = await SurveyService.getSurveys(filters);
      setSurveys(surveysData);
    } catch (error) {
      console.error('Error loading surveys:', error);
      Alert.alert('Error', 'Failed to load surveys');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadSurveys();
    setRefreshing(false);
  };

  const filterSurveys = () => {
    let filtered = surveys;

    // Search filter
    if (searchQuery) {
      filtered = filtered.filter(survey =>
        survey.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        survey.description.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    // Status filter
    if (filters.status !== 'all') {
      const isActive = filters.status === 'active';
      filtered = filtered.filter(survey => survey.isActive === isActive);
    }

    setFilteredSurveys(filtered);
  };

  const handleSurveyPress = (survey: Survey) => {
    setSelectedSurvey(survey);
    loadSurveyAnalytics(survey.id);
  };

  const loadSurveyAnalytics = async (surveyId: string) => {
    try {
      const analyticsData = await SurveyService.getSurveyAnalytics(surveyId);
      setAnalytics(analyticsData);
    } catch (error) {
      console.error('Error loading analytics:', error);
    }
  };

  const toggleSurveyStatus = async (survey: Survey) => {
    try {
      await SurveyService.updateSurvey(survey.id, { isActive: !survey.isActive });
      await loadSurveys();
      Alert.alert('Success', `Survey ${survey.isActive ? 'deactivated' : 'activated'} successfully`);
    } catch (error) {
      console.error('Error updating survey:', error);
      Alert.alert('Error', 'Failed to update survey status');
    }
  };

  const deleteSurvey = async (survey: Survey) => {
    Alert.alert(
      'Delete Survey',
      `Are you sure you want to delete "${survey.title}"? This action cannot be undone.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await SurveyService.deleteSurvey(survey.id);
              await loadSurveys();
              Alert.alert('Success', 'Survey deleted successfully');
            } catch (error) {
              console.error('Error deleting survey:', error);
              Alert.alert('Error', 'Failed to delete survey');
            }
          }
        }
      ]
    );
  };

  const assignSurvey = (survey: Survey) => {
    setSelectedSurvey(survey);
    setShowAssignModal(true);
  };

  const viewResponses = (survey: Survey) => {
    navigation.navigate('SurveyResponses', { surveyId: survey.id });
  };

  const renderSurveyCard = ({ item: survey }: { item: Survey }) => (
    <TouchableOpacity
      style={styles.surveyCard}
      onPress={() => handleSurveyPress(survey)}
      activeOpacity={0.7}
    >
      <View style={styles.surveyHeader}>
        <View style={styles.surveyTitleContainer}>
          <Text style={styles.surveyTitle}>{survey.title}</Text>
          <View style={[
            styles.statusBadge,
            survey.isActive ? styles.activeBadge : styles.inactiveBadge
          ]}>
            <Text style={[
              styles.statusText,
              survey.isActive ? styles.activeText : styles.inactiveText
            ]}>
              {survey.isActive ? 'Active' : 'Inactive'}
            </Text>
          </View>
        </View>
        
        <View style={styles.surveyActions}>
          <TouchableOpacity
            onPress={() => assignSurvey(survey)}
            style={styles.actionButton}
          >
            <MaterialIcons name="edit" size={20} color={COLORS.primary} />
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() => navigation.navigate('SurveyAssignment', { surveyId: survey.id })}
            style={styles.actionButton}
          >
            <MaterialIcons name="assignment-ind" size={20} color={COLORS.success} />
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() => viewResponses(survey)}
            style={styles.actionButton}
          >
            <MaterialIcons name="analytics" size={20} color={COLORS.secondary} />
          </TouchableOpacity>
          
          <TouchableOpacity
            onPress={() => toggleSurveyStatus(survey)}
            style={styles.actionButton}
          >
            <MaterialIcons 
              name={survey.isActive ? "pause" : "play-arrow"} 
              size={20} 
              color={survey.isActive ? COLORS.warning : COLORS.success} 
            />
          </TouchableOpacity>
          
          <TouchableOpacity
            onPress={() => deleteSurvey(survey)}
            style={styles.actionButton}
          >
            <MaterialIcons name="delete" size={20} color={COLORS.error} />
          </TouchableOpacity>
        </View>
      </View>

      <Text style={styles.surveyDescription} numberOfLines={2}>
        {survey.description}
      </Text>

      <View style={styles.surveyMeta}>
        <View style={styles.metaItem}>
          <MaterialIcons name="quiz" size={16} color={COLORS.text.secondary} />
          <Text style={styles.metaText}>{survey.questions.length} questions</Text>
        </View>
        
        <View style={styles.metaItem}>
          <MaterialIcons name="person" size={16} color={COLORS.text.secondary} />
          <Text style={styles.metaText}>{survey.createdBy.name}</Text>
        </View>
        
        <View style={styles.metaItem}>
          <MaterialIcons name="schedule" size={16} color={COLORS.text.secondary} />
          <Text style={styles.metaText}>
            {new Date(survey.createdAt).toLocaleDateString()}
          </Text>
        </View>
      </View>

      {/* Assigned Teams */}
      {survey.assignedTeams && survey.assignedTeams.length > 0 && (
        <View style={styles.assignedTeamsContainer}>
          <View style={styles.assignedTeamsHeader}>
            <MaterialIcons name="groups" size={14} color={COLORS.primary} />
            <Text style={styles.assignedTeamsLabel}>Assigned to:</Text>
          </View>
          <View style={styles.teamBadgesContainer}>
            {survey.assignedTeams.slice(0, 3).map((team, index) => (
              <View key={index} style={styles.teamBadge}>
                <Text style={styles.teamBadgeText}>{team.teamName}</Text>
              </View>
            ))}
            {survey.assignedTeams.length > 3 && (
              <Text style={styles.moreTeamsText}>+{survey.assignedTeams.length - 3} more</Text>
            )}
          </View>
        </View>
      )}

      {survey.tags && survey.tags.length > 0 && (
        <View style={styles.tagsContainer}>
          {survey.tags.slice(0, 3).map((tag, index) => (
            <View key={index} style={styles.tag}>
              <Text style={styles.tagText}>{tag}</Text>
            </View>
          ))}
          {survey.tags.length > 3 && (
            <Text style={styles.moreTagsText}>+{survey.tags.length - 3} more</Text>
          )}
        </View>
      )}
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title="Survey Management"
        showBackButton
        onBackPress={() => navigation.goBack()}
        rightComponent={
          <TouchableOpacity
            onPress={() => navigation.navigate('SurveyBuilder')}
            style={styles.createButton}
          >
            <MaterialIcons name="add" size={20} color={COLORS.background.primary} />
            <Text style={styles.createButtonText}>Create</Text>
          </TouchableOpacity>
        }
      />

      <View style={styles.content}>
        {/* Search and Filter Bar */}
        <View style={styles.searchContainer}>
          <View style={styles.searchInputContainer}>
            <MaterialIcons name="search" size={20} color={COLORS.text.secondary} />
            <TextInput
              style={styles.searchInput}
              placeholder="Search surveys..."
              placeholderTextColor={COLORS.text.placeholder}
              value={searchQuery}
              onChangeText={setSearchQuery}
            />
          </View>
          
          <TouchableOpacity
            style={styles.filterButton}
            onPress={() => setShowFilters(true)}
          >
            <MaterialIcons name="filter-list" size={20} color={COLORS.primary} />
          </TouchableOpacity>
        </View>

        {/* Stats Overview */}
        <View style={styles.statsContainer}>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{surveys.length}</Text>
            <Text style={styles.statLabel}>Total Surveys</Text>
          </View>
          
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>
              {surveys.filter(s => s.isActive).length}
            </Text>
            <Text style={styles.statLabel}>Active</Text>
          </View>
          
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>0</Text>
            <Text style={styles.statLabel}>Responses Today</Text>
          </View>
        </View>

        {/* Surveys List */}
        <FlatList
          data={filteredSurveys}
          keyExtractor={(item) => item.id}
          renderItem={renderSurveyCard}
          contentContainerStyle={styles.surveysList}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <MaterialIcons name="assignment" size={64} color={COLORS.text.secondary} />
              <Text style={styles.emptyStateText}>No surveys found</Text>
              <Text style={styles.emptyStateSubtext}>
                {searchQuery ? 'Try adjusting your search' : 'Create your first survey to get started'}
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
  createButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
  },
  createButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.background.primary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  searchInputContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    marginRight: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  searchInput: {
    flex: 1,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    marginLeft: SPACING.sm,
  },
  filterButton: {
    backgroundColor: COLORS.background.surface,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
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
  surveysList: {
    paddingBottom: SPACING.xl,
  },
  surveyCard: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  surveyHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.sm,
  },
  surveyTitleContainer: {
    flex: 1,
    marginRight: SPACING.md,
  },
  surveyTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  statusBadge: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    alignSelf: 'flex-start',
  },
  activeBadge: {
    backgroundColor: COLORS.success + '20',
  },
  inactiveBadge: {
    backgroundColor: COLORS.error + '20',
  },
  statusText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  activeText: {
    color: COLORS.success,
  },
  inactiveText: {
    color: COLORS.error,
  },
  surveyActions: {
    flexDirection: 'row',
  },
  actionButton: {
    padding: SPACING.sm,
    marginLeft: SPACING.xs,
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
  tagsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    alignItems: 'center',
  },
  tag: {
    backgroundColor: COLORS.primary + '20',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    marginRight: SPACING.xs,
    marginBottom: SPACING.xs,
  },
  tagText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  moreTagsText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    fontStyle: 'italic',
  },
  assignedTeamsContainer: {
    marginBottom: SPACING.sm,
  },
  assignedTeamsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
    marginBottom: SPACING.xs,
  },
  assignedTeamsLabel: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  teamBadgesContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    alignItems: 'center',
  },
  teamBadge: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.full,
    marginRight: SPACING.xs,
    marginBottom: SPACING.xs,
  },
  teamBadgeText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.textInverse,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
  moreTeamsText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    fontStyle: 'italic',
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

export default SurveyManagementScreen;
