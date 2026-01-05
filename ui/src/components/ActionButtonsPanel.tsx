import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Modal, SafeAreaView, ScrollView, Alert, Animated, Dimensions, Platform } from 'react-native';
// import { BlurView } from 'expo-blur'; // Removed - using platform-specific glassmorphism instead
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { SurveyService } from '../services/SurveyService';
import { SurveyQuestion } from './survey';
import { Survey, SurveyAssignment, SurveyResponse, AnyQuestion } from '../types/survey';
import { BookDelivery } from '../types/ministry';
import ComprehensiveDeliveryModal from './ComprehensiveDeliveryModal';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { EnhancedWalkieTalkiePanel } from './walkie-talkie/EnhancedWalkieTalkiePanel';
import TeamMessagingBottomSheet from './TeamMessagingBottomSheet';

interface ActionButtonsPanelProps {
  onBookDelivery?: () => void;
  onSurvey?: () => void;
  onStartMinistry?: () => void;
  onStopMinistry?: () => void;
  onTeamMessage?: () => void;
  onMicPress?: () => void;
  isMinistryActive?: boolean;
  isLoading?: boolean;
  style?: any;
  hideMic?: boolean; // When true, hides the mic (walkie-talkie) button and panel
}

const { height: screenHeight } = Dimensions.get('window');

const ActionButtonsPanel: React.FC<ActionButtonsPanelProps> = ({
  onBookDelivery,
  onSurvey,
  onStartMinistry,
  onStopMinistry,
  onTeamMessage,
  onMicPress,
  isMinistryActive = false,
  isLoading = false,
  style,
  hideMic = false,
}) => {
  const { user } = useAuth();
  const { currentLocation } = useLocation();

  // Book Delivery State
  const [showDeliveryModal, setShowDeliveryModal] = useState(false);

  // Survey Bottom Sheet State
  const [showSurveySheet, setShowSurveySheet] = useState(false);
  const [assignments, setAssignments] = useState<SurveyAssignment[]>([]);
  const [surveys, setSurveys] = useState<Record<string, Survey>>({});
  const [selectedSurvey, setSelectedSurvey] = useState<Survey | null>(null);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, any>>({});
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [loadingSurveys, setLoadingSurveys] = useState(false);

  // Animation for bottom sheet
  const slideAnim = useState(new Animated.Value(screenHeight))[0];

  // Team Messaging State
  const [showTeamMessaging, setShowTeamMessaging] = useState(false);

  // Parallel Walkie Talkie State
  const [showWalkieTalkieBottomSheet, setShowWalkieTalkieBottomSheet] = useState(false);

  // Load surveys when sheet opens
  useEffect(() => {
    if (showSurveySheet && user) {
      loadAssignments();
    }
  }, [showSurveySheet, user]);

  const loadAssignments = async () => {
    if (!user) return;

    try {
      setLoadingSurveys(true);
      const assignmentsData = await SurveyService.getAssignmentsForUser(user.id);
      setAssignments(assignmentsData);

      // Load survey details for each assignment
      const surveyPromises = assignmentsData.map(assignment =>
        SurveyService.getSurvey(assignment.surveyId)
      );

      const surveysData = await Promise.all(surveyPromises);
      const surveysMap: Record<string, Survey> = {};

      surveysData.forEach(survey => {
        if (survey) {
          surveysMap[survey.id] = survey;
        }
      });

      setSurveys(surveysMap);
    } catch (error) {
      console.error('Error loading assignments:', error);
      Alert.alert('Error', 'Failed to load surveys');
    } finally {
      setLoadingSurveys(false);
    }
  };

  // Handle book delivery button press
  const handleBookDeliveryPress = () => {
    if (onBookDelivery) {
      onBookDelivery();
    } else {
      setShowDeliveryModal(true);
    }
  };

  // Handle delivery logged
  const handleDeliveryLogged = (delivery: BookDelivery) => {
    console.log('📦 Delivery logged successfully:', delivery);
    // You can add additional logic here like updating local state,
    // showing notifications, etc.
  };

  // Handle survey button press
  const handleSurveyPress = () => {
    if (onSurvey) {
      onSurvey();
    } else {
      setShowSurveySheet(true);
      // Animate sheet up
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }
  };

  // Close survey sheet
  const closeSurveySheet = () => {
    Animated.timing(slideAnim, {
      toValue: screenHeight,
      duration: 300,
      useNativeDriver: true,
    }).start(() => {
      setShowSurveySheet(false);
      setSelectedSurvey(null);
      setCurrentQuestionIndex(0);
      setAnswers({});
      setValidationErrors({});
    });
  };

  // Start a survey
  const startSurvey = (assignment: SurveyAssignment) => {
    const survey = surveys[assignment.surveyId];
    if (!survey) {
      Alert.alert('Error', 'Survey not found');
      return;
    }
    setSelectedSurvey(survey);
    setCurrentQuestionIndex(0);
    setAnswers({});
    setValidationErrors({});
  };

  // Handle answer change
  const handleAnswerChange = (questionId: string, value: any) => {
    setAnswers(prev => ({ ...prev, [questionId]: value }));
    // Clear validation error when user starts typing
    if (validationErrors[questionId]) {
      setValidationErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[questionId];
        return newErrors;
      });
    }
  };

  // Validate current question
  const validateQuestion = (question: AnyQuestion): string | null => {
    const value = answers[question.id];

    if (question.required && (!value || (Array.isArray(value) && value.length === 0))) {
      return 'This field is required';
    }

    if (question.type === 'email' && value) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(value)) {
        return 'Please enter a valid email address';
      }
    }

    if (question.type === 'phone' && value) {
      const phoneRegex = /^[\+]?[1-9][\d]{0,15}$/;
      if (!phoneRegex.test(value.replace(/\s/g, ''))) {
        return 'Please enter a valid phone number';
      }
    }

    if (question.type === 'number' && value !== undefined && value !== '') {
      const numValue = Number(value);
      if (isNaN(numValue)) {
        return 'Please enter a valid number';
      }
      if (question.min !== undefined && numValue < question.min) {
        return `Value must be at least ${question.min}`;
      }
      if (question.max !== undefined && numValue > question.max) {
        return `Value must be at most ${question.max}`;
      }
    }

    return null;
  };

  // Handle survey submission
  const handleSurveySubmit = async () => {
    if (!selectedSurvey || !user) return;

    // Validate all questions
    const errors: Record<string, string> = {};
    selectedSurvey.questions.forEach(question => {
      const error = validateQuestion(question);
      if (error) {
        errors[question.id] = error;
      }
    });

    if (Object.keys(errors).length > 0) {
      setValidationErrors(errors);
      Alert.alert('Validation Error', 'Please fix the errors before submitting');
      return;
    }

    setSubmitting(true);
    try {
      const response: Omit<SurveyResponse, 'id' | 'submittedAt'> = {
        surveyId: selectedSurvey.id,
        respondentId: user.id,
        respondentName: user.display_name || user.email?.split('@')[0] || 'Unknown',
        answers,
        ...(currentLocation && {
          location: {
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude,
            ...(currentLocation.address && { address: currentLocation.address })
          }
        }),
        isComplete: true,
        syncStatus: 'synced',
        deviceInfo: {
          platform: 'mobile',
          version: '1.0.0'
        }
      };

      await SurveyService.submitResponse(response);

      Alert.alert(
        'Success',
        'Survey submitted successfully!',
        [{ text: 'OK', onPress: closeSurveySheet }]
      );
    } catch (error) {
      console.error('Error submitting survey:', error);
      Alert.alert('Error', 'Failed to submit survey. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
    <View style={[Platform.OS === 'web' ? styles.glassmorphismWrapper : styles.mobileGlassmorphism, style]}>
      <View style={styles.glassContent}>


        {/* Top Row - Book Delivery and Camera */}
        <View style={styles.topRow}>
        <TouchableOpacity
          style={styles.primaryButton}
          onPress={handleBookDeliveryPress}
          activeOpacity={0.8}
        >
          <View style={styles.buttonContent}>
            <View style={[styles.iconContainer, styles.blueIconContainer]}>
              <Ionicons name="book" size={24} color="#FFFFFF" />
            </View>
            <Text style={styles.buttonText}>Book Delivery</Text>
          </View>
        </TouchableOpacity>

      </View>

      {/* Middle Row - Survey */}
      <View style={styles.middleRow}>
        <TouchableOpacity
          style={styles.primaryButton}
          onPress={handleSurveyPress}
          activeOpacity={0.8}
        >
          <View style={styles.buttonContent}>
            <View style={[styles.iconContainer, styles.redIconContainer]}>
              <Ionicons name="clipboard" size={24} color="#FFFFFF" />
            </View>
            <Text style={styles.buttonText}>Survey</Text>
          </View>
        </TouchableOpacity>
      </View>

      {/* Bottom Row - Stop Ministry, Team Message, Mic */}
      <View style={styles.bottomRow}>
        <TouchableOpacity
          style={[styles.stopButton, isMinistryActive ? styles.stopButtonActive : styles.stopButtonInactive]}
          onPress={isMinistryActive ? onStopMinistry : onStartMinistry}
          activeOpacity={0.8}
          disabled={isLoading}
        >
          <Text style={styles.stopButtonText}>
            {isLoading ? 'Loading...' : (isMinistryActive ? 'Stop Ministry' : 'Start Ministry')}
          </Text>
        </TouchableOpacity>

        <View style={styles.rightButtons}>
          <TouchableOpacity
            style={[styles.iconButton, styles.teamMessageButton]}
            onPress={() => setShowTeamMessaging(true)}
            activeOpacity={0.8}
          >
            <View style={[styles.iconContainer, styles.darkBlueIconContainer]}>
              <Ionicons name="chatbubbles" size={24} color="#FFFFFF" />
            </View>
          </TouchableOpacity>

          {!hideMic && (
            <TouchableOpacity
              style={[styles.iconButton, styles.micButton]}
              onPress={() => setShowWalkieTalkieBottomSheet(true)}
            >
              <View style={styles.iconContainer}>
                <Ionicons name="mic" size={24} color="#FFFFFF" />
              </View>
            </TouchableOpacity>
          )}
        </View>
      </View>
      </View>
    </View>

      {/* Survey Bottom Sheet Modal */}
      <Modal
        visible={showSurveySheet}
        transparent
        animationType="none"
        onRequestClose={closeSurveySheet}
      >
        <View style={styles.modalOverlay}>
          <TouchableOpacity
            style={styles.modalBackdrop}
            activeOpacity={1}
            onPress={closeSurveySheet}
          />

          <Animated.View
            style={[
              styles.bottomSheet,
              {
                transform: [{ translateY: slideAnim }],
              },
            ]}
          >
            <SafeAreaView style={styles.sheetContainer}>
              {/* Sheet Header */}
              <View style={styles.sheetHeader}>
                <View style={styles.sheetHandle} />
                <View style={styles.headerContent}>
                  <Text style={styles.sheetTitle}>
                    {selectedSurvey ? selectedSurvey.title : 'Available Surveys'}
                  </Text>
                  <TouchableOpacity
                    onPress={closeSurveySheet}
                    style={styles.closeButton}
                  >
                    <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
                  </TouchableOpacity>
                </View>
              </View>

              {/* Sheet Content */}
              <ScrollView style={styles.sheetContent} showsVerticalScrollIndicator={false}>
                {!selectedSurvey ? (
                  // Survey List View
                  <View style={styles.surveyListContainer}>
                    {loadingSurveys ? (
                      <View style={styles.loadingContainer}>
                        <Text style={styles.loadingText}>Loading surveys...</Text>
                      </View>
                    ) : assignments.length === 0 ? (
                      <View style={styles.emptyState}>
                        <MaterialIcons name="assignment" size={64} color={COLORS.text.secondary} />
                        <Text style={styles.emptyStateText}>No surveys assigned</Text>
                        <Text style={styles.emptyStateSubtext}>
                          Check back later for new survey assignments
                        </Text>
                      </View>
                    ) : (
                      assignments.map((assignment) => {
                        const survey = surveys[assignment.surveyId];
                        if (!survey) return null;

                        return (
                          <TouchableOpacity
                            key={assignment.id}
                            style={styles.surveyCard}
                            onPress={() => startSurvey(assignment)}
                            activeOpacity={0.7}
                          >
                            <View style={styles.surveyCardHeader}>
                              <Text style={styles.surveyTitle}>{survey.title}</Text>
                              <View style={styles.surveyMeta}>
                                <MaterialIcons name="quiz" size={16} color={COLORS.text.secondary} />
                                <Text style={styles.surveyMetaText}>{survey.questions.length} questions</Text>
                              </View>
                            </View>
                            <Text style={styles.surveyDescription} numberOfLines={2}>
                              {survey.description}
                            </Text>
                            <View style={styles.surveyFooter}>
                              <Text style={styles.assignedByText}>
                                Assigned by {assignment.assignedBy.name}
                              </Text>
                              <MaterialIcons name="arrow-forward" size={20} color={COLORS.primary} />
                            </View>
                          </TouchableOpacity>
                        );
                      })
                    )}
                  </View>
                ) : (
                  // Survey Form View
                  <SurveyFormContent
                    survey={selectedSurvey}
                    currentQuestionIndex={currentQuestionIndex}
                    answers={answers}
                    validationErrors={validationErrors}
                    submitting={submitting}
                    onAnswerChange={handleAnswerChange}
                    onNext={() => setCurrentQuestionIndex(prev => prev + 1)}
                    onPrevious={() => setCurrentQuestionIndex(prev => prev - 1)}
                    onSubmit={handleSurveySubmit}
                    onBack={() => setSelectedSurvey(null)}
                  />
                )}
              </ScrollView>
            </SafeAreaView>
          </Animated.View>
        </View>
      </Modal>

      {/* Book Delivery Modal */}
      <ComprehensiveDeliveryModal
        visible={showDeliveryModal}
        onClose={() => setShowDeliveryModal(false)}
        onDeliveryLogged={handleDeliveryLogged}
      />

      {/* Enhanced Walkie-Talkie Panel */}
      {!hideMic && showWalkieTalkieBottomSheet && user && (
        <Modal
          visible={showWalkieTalkieBottomSheet}
          transparent
          animationType="slide"
          onRequestClose={() => setShowWalkieTalkieBottomSheet(false)}
        >
          <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' }}>
            <EnhancedWalkieTalkiePanel
              teamId={user.team_id || `territory_${(user.id || '').slice(-8)}`}
              userId={user.id}
              userName={user.display_name || user.email?.split('@')[0] || 'User'}
              teamName={user.team_name}
              onClose={() => setShowWalkieTalkieBottomSheet(false)}
            />
          </View>
        </Modal>
      )}

      {/* Team Messaging Bottom Sheet */}
      <TeamMessagingBottomSheet
        visible={showTeamMessaging}
        onClose={() => setShowTeamMessaging(false)}
      />

    </>
  );
};

// Survey Form Content Component
interface SurveyFormContentProps {
  survey: Survey;
  currentQuestionIndex: number;
  answers: Record<string, any>;
  validationErrors: Record<string, string>;
  submitting: boolean;
  onAnswerChange: (questionId: string, value: any) => void;
  onNext: () => void;
  onPrevious: () => void;
  onSubmit: () => void;
  onBack: () => void;
}

const SurveyFormContent: React.FC<SurveyFormContentProps> = ({
  survey,
  currentQuestionIndex,
  answers,
  validationErrors,
  submitting,
  onAnswerChange,
  onNext,
  onPrevious,
  onSubmit,
  onBack
}) => {
  const currentQuestion = survey.questions[currentQuestionIndex];
  const progress = ((currentQuestionIndex + 1) / survey.questions.length) * 100;
  const isLastQuestion = currentQuestionIndex === survey.questions.length - 1;

  return (
    <View style={styles.surveyFormContainer}>
      {/* Back Button */}
      <TouchableOpacity onPress={onBack} style={styles.backButton}>
        <MaterialIcons name="arrow-back" size={24} color={COLORS.text.primary} />
        <Text style={styles.backButtonText}>Back to Surveys</Text>
      </TouchableOpacity>

      {/* Progress Bar */}
      <View style={styles.progressContainer}>
        <View style={styles.progressBar}>
          <View style={[styles.progressFill, { width: `${progress}%` }]} />
        </View>
        <Text style={styles.progressText}>
          Question {currentQuestionIndex + 1} of {survey.questions.length}
        </Text>
      </View>

      {/* Current Question */}
      <View style={styles.questionContainer}>
        <SurveyQuestion
          question={currentQuestion}
          value={answers[currentQuestion.id] || ''}
          onChange={(value) => onAnswerChange(currentQuestion.id, value)}
          error={validationErrors[currentQuestion.id]}
        />
      </View>

      {/* Navigation Buttons */}
      <View style={styles.navigationButtons}>
        <TouchableOpacity
          style={[styles.navButton, styles.previousButton, currentQuestionIndex === 0 && styles.disabledButton]}
          onPress={onPrevious}
          disabled={currentQuestionIndex === 0}
        >
          <Text style={[styles.navButtonText, currentQuestionIndex === 0 && styles.disabledButtonText]}>
            Previous
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.navButton, styles.nextButton]}
          onPress={isLastQuestion ? onSubmit : onNext}
          disabled={submitting}
        >
          <Text style={styles.nextButtonText}>
            {submitting ? 'Submitting...' : (isLastQuestion ? 'Submit' : 'Next')}
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  glassmorphismWrapper: {
    borderRadius: 20,
    marginHorizontal: 16,
    marginBottom: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.2)',
    padding: 20,
    // shadowColor: '#000',
    // shadowOffset: {
    //   width: 0,
    //   height: 4,
    // },
    // shadowOpacity: 0.1,
    // shadowRadius: 12,
    // elevation: 8,
  },
  mobileGlassmorphism: {
    padding: 20,
    borderRadius: 20,
    marginHorizontal: 16,
    marginBottom: 20,
    // Enhanced glassmorphism effect for mobile
    backgroundColor: 'rgba(255, 255, 255, 0.7)', // Semi-transparent white
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.9)', // Bright border for glass effect
    // Strong shadow for depth
    // shadowColor: '#000',
    // shadowOffset: {
    //   width: 0,
    //   height: 12,
    // },
    // shadowOpacity: 0.2,
    // shadowRadius: 20,
    // elevation: 15, // High elevation for Android
    // Additional visual enhancements
    borderTopWidth: 1.5,
    borderTopColor: 'rgba(255, 255, 255, 0.7)', // Brighter top border
    borderBottomWidth: 0.5,
    borderBottomColor: 'rgba(255, 255, 255, 0.80)', // Subtle bottom border
  },
  blurContainer: {
    flex: 1,
    borderRadius: 20,
    padding: 20,
    overflow: 'hidden',
  },
  glassContent: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  container: {
    borderRadius: 20,
    padding: 20,
    marginHorizontal: 16,
    marginBottom: 20,
    overflow: 'hidden',
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  middleRow: {
    marginBottom: 20,
  },
  bottomRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  primaryButton: {
    flex: 1,
    marginRight: 12,
  },
  buttonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 20,
    backgroundColor: 'rgba(248, 250, 252, 0.8)',
    borderRadius: 16,
    // borderWidth: 1,
    // borderColor: 'rgba(226, 232, 240, 0.5)',
  },
  buttonText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1F2937',
    marginLeft: 16,
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  blueIconContainer: {
    backgroundColor: '#3B82F6',
    borderRadius : 50,
  },
  redIconContainer: {
    backgroundColor: '#EF4444',
  },
  grayIconContainer: {
    backgroundColor: '#F3F4F6',
    borderWidth: 1,
    borderColor: '#E5E7EB',
  },
  darkBlueIconContainer: {
    backgroundColor: '#1E3A8A',
    marginRight : -10,
  },
  goldIconContainer: {
    backgroundColor: '#D7A638',
  },
  iconButton: {
    padding: 4,
  },
  stopButton: {
    paddingVertical: 10,
    paddingHorizontal: 32,
    borderRadius: 45,
    minWidth: 160,
    alignItems: 'center',
    // borderWidth: 4,
    // borderColor: 'rgba(255, 255, 255, 0.90)'
  },
  stopButtonActive: {
    backgroundColor: '#EF4444',
  },
  stopButtonInactive: {
    backgroundColor: '#10B981',
  },
  stopButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  rightButtons: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  teamMessageButton: {
    marginRight: 12,
  },
  micButton: {
    backgroundColor: '#10B981', // Green background to make it visible
    borderRadius: 24,
    padding: 4,
  },

  // Bottom Sheet Styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalBackdrop: {
    flex: 1,
  },
  bottomSheet: {
    backgroundColor: COLORS.background.surface,
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    maxHeight: screenHeight * 0.9,
    minHeight: screenHeight * 0.6,
    ...SHADOWS.xl,
  },
  sheetContainer: {
    flex: 1,
  },
  sheetHeader: {
    paddingTop: SPACING.md,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  sheetHandle: {
    width: 40,
    height: 4,
    backgroundColor: COLORS.border.default,
    borderRadius: 2,
    alignSelf: 'center',
    marginBottom: SPACING.md,
  },
  headerContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  sheetTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    flex: 1,
  },
  closeButton: {
    padding: SPACING.xs,
  },
  sheetContent: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
  },

  // Survey List Styles
  surveyListContainer: {
    paddingVertical: SPACING.md,
  },
  loadingContainer: {
    padding: SPACING.xl,
    alignItems: 'center',
  },
  loadingText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
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
  surveyCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  surveyCardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.sm,
  },
  surveyTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    flex: 1,
    marginRight: SPACING.md,
  },
  surveyMeta: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  surveyMetaText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
  surveyDescription: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
    marginBottom: SPACING.md,
  },
  surveyFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  assignedByText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    flex: 1,
  },

  // Survey Form Styles
  surveyFormContainer: {
    flex: 1,
    paddingVertical: SPACING.md,
  },
  backButton: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.lg,
    paddingVertical: SPACING.sm,
  },
  backButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    marginLeft: SPACING.sm,
  },
  progressContainer: {
    marginBottom: SPACING.xl,
  },
  progressBar: {
    height: 4,
    backgroundColor: COLORS.border.light,
    borderRadius: 2,
    marginBottom: SPACING.sm,
  },
  progressFill: {
    height: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: 2,
  },
  progressText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  questionContainer: {
    flex: 1,
    marginBottom: SPACING.xl,
  },
  navigationButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingTop: SPACING.lg,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
  },
  navButton: {
    flex: 1,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    borderRadius: RADIUS.md,
    alignItems: 'center',
  },
  previousButton: {
    backgroundColor: COLORS.background.secondary,
    marginRight: SPACING.md,
  },
  nextButton: {
    backgroundColor: COLORS.primary,
  },
  disabledButton: {
    backgroundColor: COLORS.background.disabled,
    opacity: 0.6,
  },
  navButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  nextButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.background.primary,
  },
  disabledButtonText: {
    color: COLORS.text.disabled,
  },
});

export default ActionButtonsPanel;
