import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  FlatList,
  Alert,
  StyleSheet,
  SafeAreaView,
  Modal,
  Share,
  Platform
} from 'react-native';
import { MaterialIcons, FontAwesome } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { Header } from '../components';
import { SurveyService } from '../services/SurveyService';
import { 
  Survey, 
  SurveyResponse, 
  SurveyAnalytics,
  AnyQuestion 
} from '../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface SurveyResponsesScreenProps {
  navigation: any;
  route: {
    params: {
      surveyId: string;
    };
  };
}

const SurveyResponsesScreen: React.FC<SurveyResponsesScreenProps> = ({ navigation, route }) => {
  const { surveyId } = route.params;
  const { user } = useAuth();
  
  const [survey, setSurvey] = useState<Survey | null>(null);
  const [responses, setResponses] = useState<SurveyResponse[]>([]);
  const [analytics, setAnalytics] = useState<SurveyAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedResponse, setSelectedResponse] = useState<SurveyResponse | null>(null);
  const [showAnalytics, setShowAnalytics] = useState(false);
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState({
    worker: 'all',
    dateRange: 'all',
    completionStatus: 'all'
  });

  useEffect(() => {
    loadSurveyData();
  }, [surveyId]);

  const loadSurveyData = async () => {
    try {
      setLoading(true);
      
      // Load survey details
      const surveyData = await SurveyService.getSurvey(surveyId);
      if (!surveyData) {
        Alert.alert('Error', 'Survey not found', [
          { text: 'OK', onPress: () => navigation.goBack() }
        ]);
        return;
      }
      setSurvey(surveyData);

      // Load responses
      const responsesData = await SurveyService.getSurveyResponses(surveyId);
      setResponses(responsesData);

      // Load analytics
      const analyticsData = await SurveyService.getSurveyAnalytics(surveyId);
      setAnalytics(analyticsData);
      
    } catch (error) {
      console.error('Error loading survey data:', error);
      Alert.alert('Error', 'Failed to load survey data');
    } finally {
      setLoading(false);
    }
  };

  const exportResponses = async (format: 'csv' | 'json') => {
    try {
      if (!survey || responses.length === 0) {
        Alert.alert('No Data', 'No responses to export');
        return;
      }

      let exportData = '';
      let fileName = `${survey.title.replace(/[^a-zA-Z0-9]/g, '_')}_responses`;

      if (format === 'csv') {
        // Create CSV header
        const headers = ['Response ID', 'Worker Name', 'Submitted At', 'Location'];
        survey.questions.forEach(q => headers.push(q.label));
        exportData = headers.join(',') + '\n';

        // Add response data
        responses.forEach(response => {
          const row = [
            response.id,
            response.respondentName,
            response.submittedAt.toISOString(),
            response.location ? `"${response.location.latitude},${response.location.longitude}"` : ''
          ];
          
          survey.questions.forEach(q => {
            const answer = response.answers[q.id];
            const formattedAnswer = Array.isArray(answer) 
              ? `"${answer.join(', ')}"` 
              : `"${answer || ''}"`;
            row.push(formattedAnswer);
          });
          
          exportData += row.join(',') + '\n';
        });
        fileName += '.csv';
      } else {
        // JSON format
        exportData = JSON.stringify({
          survey: {
            id: survey.id,
            title: survey.title,
            description: survey.description
          },
          responses: responses.map(r => ({
            id: r.id,
            respondentName: r.respondentName,
            submittedAt: r.submittedAt,
            answers: r.answers,
            location: r.location
          })),
          analytics: analytics
        }, null, 2);
        fileName += '.json';
      }

      // Share the data
      if (Platform.OS === 'web') {
        // For web, create download link
        const blob = new Blob([exportData], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;
        link.click();
        URL.revokeObjectURL(url);
      } else {
        // For mobile, use Share API
        await Share.share({
          message: exportData,
          title: `Survey Responses: ${survey.title}`
        });
      }

      Alert.alert('Success', `Responses exported as ${format.toUpperCase()}`);
    } catch (error) {
      console.error('Export error:', error);
      Alert.alert('Error', 'Failed to export responses');
    }
  };

  const getAnswerDisplay = (question: AnyQuestion, answer: any): string => {
    if (!answer && answer !== 0) return 'No answer';
    
    switch (question.type) {
      case 'checkbox':
        return Array.isArray(answer) ? answer.join(', ') : answer;
      case 'rating':
        return `${answer}/${(question as any).scale || 5}`;
      case 'yes_no':
        return answer ? 'Yes' : 'No';
      default:
        return answer.toString();
    }
  };

  const renderResponseCard = ({ item: response }: { item: SurveyResponse }) => (
    <TouchableOpacity
      style={styles.responseCard}
      onPress={() => setSelectedResponse(response)}
      activeOpacity={0.7}
    >
      <View style={styles.responseHeader}>
        <View style={styles.responseInfo}>
          <Text style={styles.workerName}>{response.respondentName}</Text>
          <Text style={styles.submissionDate}>
            {response.submittedAt.toLocaleDateString()} at {response.submittedAt.toLocaleTimeString()}
          </Text>
        </View>
        
        <View style={styles.responseStatus}>
          <View style={[
            styles.statusBadge,
            response.isComplete ? styles.completeBadge : styles.incompleteBadge
          ]}>
            <Text style={[
              styles.statusText,
              response.isComplete ? styles.completeText : styles.incompleteText
            ]}>
              {response.isComplete ? 'Complete' : 'Incomplete'}
            </Text>
          </View>
          
          {response.location && (
            <MaterialIcons name="location-on" size={16} color={COLORS.success} />
          )}
        </View>
      </View>

      <View style={styles.responsePreview}>
        {survey?.questions.slice(0, 2).map(question => (
          <View key={question.id} style={styles.previewAnswer}>
            <Text style={styles.previewQuestion} numberOfLines={1}>
              {question.label}:
            </Text>
            <Text style={styles.previewAnswerText} numberOfLines={1}>
              {getAnswerDisplay(question, response.answers[question.id])}
            </Text>
          </View>
        ))}
      </View>

      <View style={styles.responseFooter}>
        <Text style={styles.responseId}>ID: {response.id.slice(-8)}</Text>
        <MaterialIcons name="chevron-right" size={20} color={COLORS.text.secondary} />
      </View>
    </TouchableOpacity>
  );

  const renderAnalyticsCard = () => {
    if (!analytics) return null;

    return (
      <View style={styles.analyticsCard}>
        <Text style={styles.analyticsTitle}>Survey Analytics</Text>
        
        <View style={styles.analyticsGrid}>
          <View style={styles.analyticsStat}>
            <Text style={styles.analyticsNumber}>{analytics.totalResponses}</Text>
            <Text style={styles.analyticsLabel}>Total Responses</Text>
          </View>
          
          <View style={styles.analyticsStat}>
            <Text style={styles.analyticsNumber}>{analytics.completionRate.toFixed(1)}%</Text>
            <Text style={styles.analyticsLabel}>Completion Rate</Text>
          </View>
          
          <View style={styles.analyticsStat}>
            <Text style={styles.analyticsNumber}>
              {Object.keys(analytics.responsesByWorker).length}
            </Text>
            <Text style={styles.analyticsLabel}>Workers</Text>
          </View>
        </View>

        <TouchableOpacity
          style={styles.viewAnalyticsButton}
          onPress={() => setShowAnalytics(true)}
        >
          <MaterialIcons name="analytics" size={20} color={COLORS.primary} />
          <Text style={styles.viewAnalyticsText}>View Detailed Analytics</Text>
        </TouchableOpacity>
      </View>
    );
  };

  if (loading || !survey) {
    return (
      <SafeAreaView style={styles.container}>
        <Header
          title="Loading..."
          showBackButton
          onBackPress={() => navigation.goBack()}
        />
        <View style={styles.loadingContainer}>
          <MaterialIcons name="hourglass-empty" size={48} color={COLORS.text.secondary} />
          <Text style={styles.loadingText}>Loading responses...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title={`${survey.title} - Responses`}
        showBackButton
        onBackPress={() => navigation.goBack()}
        rightComponent={
          <View style={styles.headerActions}>
            <TouchableOpacity
              onPress={() => exportResponses('csv')}
              style={styles.headerAction}
            >
              <MaterialIcons name="file-download" size={20} color={COLORS.primary} />
            </TouchableOpacity>
            
            <TouchableOpacity
              onPress={() => setShowFilters(true)}
              style={styles.headerAction}
            >
              <MaterialIcons name="filter-list" size={20} color={COLORS.primary} />
            </TouchableOpacity>
          </View>
        }
      />

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Analytics Overview */}
        {renderAnalyticsCard()}

        {/* Export Actions */}
        <View style={styles.exportSection}>
          <Text style={styles.sectionTitle}>Export Options</Text>
          <View style={styles.exportButtons}>
            <TouchableOpacity
              style={styles.exportButton}
              onPress={() => exportResponses('csv')}
            >
              <MaterialIcons name="table-chart" size={20} color={COLORS.success} />
              <Text style={styles.exportButtonText}>Export CSV</Text>
            </TouchableOpacity>
            
            <TouchableOpacity
              style={styles.exportButton}
              onPress={() => exportResponses('json')}
            >
              <MaterialIcons name="code" size={20} color={COLORS.info} />
              <Text style={styles.exportButtonText}>Export JSON</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Responses List */}
        <View style={styles.responsesSection}>
          <Text style={styles.sectionTitle}>
            Responses ({responses.length})
          </Text>
          
          {responses.length > 0 ? (
            <FlatList
              data={responses}
              keyExtractor={(item) => item.id}
              renderItem={renderResponseCard}
              scrollEnabled={false}
              showsVerticalScrollIndicator={false}
            />
          ) : (
            <View style={styles.emptyState}>
              <MaterialIcons name="assignment" size={64} color={COLORS.text.secondary} />
              <Text style={styles.emptyStateText}>No responses yet</Text>
              <Text style={styles.emptyStateSubtext}>
                Responses will appear here once workers start submitting surveys
              </Text>
            </View>
          )}
        </View>
      </ScrollView>

      {/* Response Detail Modal */}
      <Modal
        visible={selectedResponse !== null}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setSelectedResponse(null)}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Response Details</Text>
            <TouchableOpacity
              onPress={() => setSelectedResponse(null)}
              style={styles.closeButton}
            >
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
          </View>

          {selectedResponse && (
            <ScrollView style={styles.modalContent}>
              <View style={styles.responseDetailHeader}>
                <Text style={styles.responseDetailWorker}>
                  {selectedResponse.respondentName}
                </Text>
                <Text style={styles.responseDetailDate}>
                  Submitted: {selectedResponse.submittedAt.toLocaleString()}
                </Text>
                {selectedResponse.location && (
                  <Text style={styles.responseDetailLocation}>
                    📍 {selectedResponse.location.latitude.toFixed(6)}, {selectedResponse.location.longitude.toFixed(6)}
                    {selectedResponse.location.address && ` - ${selectedResponse.location.address}`}
                  </Text>
                )}
              </View>

              <View style={styles.answersContainer}>
                {survey?.questions.map(question => (
                  <View key={question.id} style={styles.answerItem}>
                    <Text style={styles.answerQuestion}>{question.label}</Text>
                    <Text style={styles.answerText}>
                      {getAnswerDisplay(question, selectedResponse.answers[question.id])}
                    </Text>
                    {question.required && !selectedResponse.answers[question.id] && (
                      <Text style={styles.missingAnswer}>⚠️ Required question not answered</Text>
                    )}
                  </View>
                ))}
              </View>
            </ScrollView>
          )}
        </SafeAreaView>
      </Modal>

      {/* Analytics Modal */}
      <Modal
        visible={showAnalytics}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowAnalytics(false)}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Detailed Analytics</Text>
            <TouchableOpacity
              onPress={() => setShowAnalytics(false)}
              style={styles.closeButton}
            >
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
          </View>

          {analytics && (
            <ScrollView style={styles.modalContent}>
              <View style={styles.analyticsDetailSection}>
                <Text style={styles.analyticsDetailTitle}>Response Summary</Text>
                <View style={styles.analyticsDetailGrid}>
                  <View style={styles.analyticsDetailItem}>
                    <Text style={styles.analyticsDetailNumber}>{analytics.totalResponses}</Text>
                    <Text style={styles.analyticsDetailLabel}>Total Responses</Text>
                  </View>
                  <View style={styles.analyticsDetailItem}>
                    <Text style={styles.analyticsDetailNumber}>{analytics.completionRate.toFixed(1)}%</Text>
                    <Text style={styles.analyticsDetailLabel}>Completion Rate</Text>
                  </View>
                </View>
              </View>

              <View style={styles.analyticsDetailSection}>
                <Text style={styles.analyticsDetailTitle}>Responses by Worker</Text>
                {Object.entries(analytics.responsesByWorker).map(([workerId, count]) => (
                  <View key={workerId} style={styles.workerResponseItem}>
                    <Text style={styles.workerResponseName}>Worker {workerId}</Text>
                    <Text style={styles.workerResponseCount}>{count} responses</Text>
                  </View>
                ))}
              </View>

              <View style={styles.analyticsDetailSection}>
                <Text style={styles.analyticsDetailTitle}>Question Analytics</Text>
                {Object.entries(analytics.questionAnalytics).map(([questionId, data]) => {
                  const question = survey?.questions.find(q => q.id === questionId);
                  if (!question) return null;

                  return (
                    <View key={questionId} style={styles.questionAnalyticsItem}>
                      <Text style={styles.questionAnalyticsTitle}>{question.label}</Text>
                      <Text style={styles.questionAnalyticsResponses}>
                        {data.responses} responses
                      </Text>

                      {data.mostCommonAnswer && (
                        <Text style={styles.questionAnalyticsCommon}>
                          Most common: {data.mostCommonAnswer}
                        </Text>
                      )}

                      {data.averageRating && (
                        <Text style={styles.questionAnalyticsRating}>
                          Average rating: {data.averageRating.toFixed(1)}
                        </Text>
                      )}

                      {data.optionCounts && Object.keys(data.optionCounts).length > 0 && (
                        <View style={styles.optionCounts}>
                          {Object.entries(data.optionCounts).map(([option, count]) => (
                            <View key={option} style={styles.optionCountItem}>
                              <Text style={styles.optionCountText}>{option}: {count}</Text>
                            </View>
                          ))}
                        </View>
                      )}
                    </View>
                  );
                })}
              </View>
            </ScrollView>
          )}
        </SafeAreaView>
      </Modal>
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
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  loadingText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  headerActions: {
    flexDirection: 'row',
  },
  headerAction: {
    padding: SPACING.sm,
    marginLeft: SPACING.xs,
  },
  analyticsCard: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  analyticsTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  analyticsGrid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.md,
  },
  analyticsStat: {
    alignItems: 'center',
    flex: 1,
  },
  analyticsNumber: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.primary,
  },
  analyticsLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  viewAnalyticsButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.primary + '20',
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
  },
  viewAnalyticsText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.primary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  exportSection: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  exportButtons: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  exportButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  exportButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  responsesSection: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  responseCard: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.light,
  },
  responseHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.sm,
  },
  responseInfo: {
    flex: 1,
  },
  workerName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  submissionDate: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  responseStatus: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusBadge: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    marginRight: SPACING.sm,
  },
  completeBadge: {
    backgroundColor: COLORS.success + '20',
  },
  incompleteBadge: {
    backgroundColor: COLORS.warning + '20',
  },
  statusText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  completeText: {
    color: COLORS.success,
  },
  incompleteText: {
    color: COLORS.warning,
  },
  responsePreview: {
    marginBottom: SPACING.sm,
  },
  previewAnswer: {
    flexDirection: 'row',
    marginBottom: SPACING.xs,
  },
  previewQuestion: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
    width: 120,
  },
  previewAnswerText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.primary,
    flex: 1,
  },
  responseFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: SPACING.sm,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
  },
  responseId: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },
  emptyState: {
    alignItems: 'center',
    padding: SPACING.xl,
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
  // Modal Styles
  modalContainer: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  modalTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  closeButton: {
    padding: SPACING.xs,
  },
  modalContent: {
    flex: 1,
    padding: SPACING.md,
  },
  responseDetailHeader: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.md,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  responseDetailWorker: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  responseDetailDate: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  responseDetailLocation: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  answersContainer: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.md,
    padding: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  answerItem: {
    marginBottom: SPACING.lg,
    paddingBottom: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  answerQuestion: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  answerText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
  },
  missingAnswer: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.warning,
    marginTop: SPACING.xs,
    fontStyle: 'italic',
  },
  // Analytics Detail Styles
  analyticsDetailSection: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.md,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  analyticsDetailTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  analyticsDetailGrid: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  analyticsDetailItem: {
    alignItems: 'center',
  },
  analyticsDetailNumber: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.primary,
  },
  analyticsDetailLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  workerResponseItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  workerResponseName: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
  },
  workerResponseCount: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  questionAnalyticsItem: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
  },
  questionAnalyticsTitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  questionAnalyticsResponses: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  questionAnalyticsCommon: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.primary,
    marginBottom: SPACING.xs,
  },
  questionAnalyticsRating: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.secondary,
    marginBottom: SPACING.xs,
  },
  optionCounts: {
    marginTop: SPACING.sm,
  },
  optionCountItem: {
    backgroundColor: COLORS.primary + '10',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    marginBottom: SPACING.xs,
  },
  optionCountText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.primary,
  },
});

export default SurveyResponsesScreen;
