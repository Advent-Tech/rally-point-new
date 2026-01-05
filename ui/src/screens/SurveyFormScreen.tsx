import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  Alert,
  StyleSheet,
  SafeAreaView,
  KeyboardAvoidingView,
  Platform
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { Header } from '../components';
import { SurveyQuestion } from '../components/survey';
import {
  SurveyServiceBackend,
  Survey as BackendSurvey,
  SurveyQuestion as BackendSurveyQuestion,
  SubmitResponseRequest
} from '../services/SurveyServiceBackend';
import { AnyQuestion } from '../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface SurveyFormScreenProps {
  navigation: any;
  route: {
    params: {
      surveyId: string;
    };
  };
}

const SurveyFormScreen: React.FC<SurveyFormScreenProps> = ({ navigation, route }) => {
  const surveyId = route?.params?.surveyId;
  const { user } = useAuth();
  const { currentLocation } = useLocation();

  // Handle missing surveyId
  useEffect(() => {
    if (!surveyId) {
      Alert.alert('Error', 'No survey selected', [
        { text: 'OK', onPress: () => navigation.goBack() }
      ]);
    }
  }, [surveyId, navigation]);

  const [survey, setSurvey] = useState<BackendSurvey | null>(null);
  const [answers, setAnswers] = useState<Record<string, any>>({});
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});
  const [startTime] = useState(new Date());

  const loadSurvey = useCallback(async () => {
    if (!surveyId) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      const surveyData = await SurveyServiceBackend.getSurvey(surveyId);
      if (surveyData) {
        setSurvey(surveyData);
        // Sort questions by order_index
        if (surveyData.questions) {
          surveyData.questions.sort((a, b) => a.order_index - b.order_index);
        }
      } else {
        Alert.alert('Error', 'Survey not found', [
          { text: 'OK', onPress: () => navigation.goBack() }
        ]);
      }
    } catch (error) {
      console.error('Error loading survey:', error);
      Alert.alert('Error', 'Failed to load survey', [
        { text: 'OK', onPress: () => navigation.goBack() }
      ]);
    } finally {
      setLoading(false);
    }
  }, [surveyId, navigation]);

  useEffect(() => {
    if (surveyId) {
      loadSurvey();
    }
  }, [loadSurvey, surveyId]);

  const handleAnswerChange = (questionId: string, value: any) => {
    setAnswers(prev => ({
      ...prev,
      [questionId]: value
    }));

    // Clear validation error for this question
    if (validationErrors[questionId]) {
      setValidationErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[questionId];
        return newErrors;
      });
    }
  };

  const validateCurrentQuestion = (): boolean => {
    if (!survey || !survey.questions) return false;

    const currentQuestion = survey.questions[currentQuestionIndex];
    const questionId = currentQuestion.id || '';
    const answer = answers[questionId];

    if (currentQuestion.is_required) {
      if (answer === undefined || answer === null || answer === '') {
        setValidationErrors(prev => ({
          ...prev,
          [questionId]: 'This question is required'
        }));
        return false;
      }

      // Additional validation for specific question types
      if (currentQuestion.question_type === 'multiple_choice' && Array.isArray(answer)) {
        if (answer.length === 0) {
          setValidationErrors(prev => ({
            ...prev,
            [questionId]: 'Please select at least one option'
          }));
          return false;
        }
      }
    }

    return true;
  };

  const nextQuestion = () => {
    if (!validateCurrentQuestion()) return;

    const questions = survey?.questions || [];
    if (currentQuestionIndex < questions.length - 1) {
      setCurrentQuestionIndex(prev => prev + 1);
    }
  };

  const previousQuestion = () => {
    if (currentQuestionIndex > 0) {
      setCurrentQuestionIndex(prev => prev - 1);
    }
  };

  const submitSurvey = async () => {
    if (!survey || !user) return;

    const questions = survey.questions || [];

    // Validate all required questions
    const errors: Record<string, string> = {};
    questions.forEach(question => {
      const answer = answers[question.id || ''];
      if (question.is_required && (answer === undefined || answer === null || answer === '')) {
        errors[question.id || ''] = 'This question is required';
      }
    });

    if (Object.keys(errors).length > 0) {
      setValidationErrors(errors);
      Alert.alert('Validation Error', 'Please answer all required questions');
      return;
    }

    setSubmitting(true);
    try {
      // Convert answers to backend format
      const formattedAnswers = Object.entries(answers).map(([questionId, answer]) => ({
        question_id: questionId,
        answer: typeof answer === 'string' ? answer : JSON.stringify(answer)
      }));

      const responseRequest: SubmitResponseRequest = {
        survey_id: survey.id,
        latitude: currentLocation?.latitude,
        longitude: currentLocation?.longitude,
        answers: formattedAnswers
      };

      await SurveyServiceBackend.submitResponse(responseRequest);

      Alert.alert(
        'Success',
        'Survey submitted successfully!',
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    } catch (error: any) {
      console.error('Error submitting survey:', error);
      Alert.alert(
        'Submission Failed',
        error.message || 'Failed to submit survey. Please try again.',
        [{ text: 'OK' }]
      );
    } finally {
      setSubmitting(false);
    }
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
          <Text style={styles.loadingText}>Loading survey...</Text>
        </View>
      </SafeAreaView>
    );
  }

  const questions = survey.questions || [];
  const currentQuestion = questions[currentQuestionIndex];
  const questionId = currentQuestion?.id || '';
  const progress = ((currentQuestionIndex + 1) / questions.length) * 100;
  const isLastQuestion = currentQuestionIndex === questions.length - 1;

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title={survey.title}
        showBackButton
        onBackPress={() => {
          Alert.alert(
            'Exit Survey',
            'Are you sure you want to exit? Your progress will be lost.',
            [
              { text: 'Cancel', style: 'cancel' },
              { text: 'Exit', style: 'destructive', onPress: () => navigation.goBack() }
            ]
          );
        }}
      />

      <KeyboardAvoidingView 
        style={styles.content} 
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        {/* Progress Bar */}
        <View style={styles.progressContainer}>
          <View style={styles.progressBar}>
            <View style={[styles.progressFill, { width: `${progress}%` }]} />
          </View>
          <Text style={styles.progressText}>
            Question {currentQuestionIndex + 1} of {questions.length}
          </Text>
        </View>

        {/* Question Content */}
        <ScrollView style={styles.questionContainer} showsVerticalScrollIndicator={false}>
          {currentQuestion && (
            <SurveyQuestion
              question={{
                id: questionId,
                type: currentQuestion.question_type as any,
                label: currentQuestion.question_text,
                required: currentQuestion.is_required,
                order: currentQuestion.order_index,
                options: currentQuestion.options || [],
              }}
              value={answers[questionId] || ''}
              onChange={(value) => handleAnswerChange(questionId, value)}
              error={validationErrors[questionId]}
            />
          )}
        </ScrollView>

        {/* Navigation Buttons */}
        <View style={styles.navigationContainer}>
          <TouchableOpacity
            style={[
              styles.navButton,
              styles.previousButton,
              currentQuestionIndex === 0 && styles.disabledButton
            ]}
            onPress={previousQuestion}
            disabled={currentQuestionIndex === 0}
          >
            <MaterialIcons name="arrow-back" size={20} color={
              currentQuestionIndex === 0 ? COLORS.text.disabled : COLORS.text.primary
            } />
            <Text style={[
              styles.navButtonText,
              currentQuestionIndex === 0 && styles.disabledButtonText
            ]}>
              Previous
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.navButton,
              styles.nextButton,
              isLastQuestion ? styles.submitButton : {}
            ]}
            onPress={isLastQuestion ? submitSurvey : nextQuestion}
            disabled={submitting}
          >
            <Text style={[
              styles.navButtonText,
              styles.nextButtonText,
              submitting && styles.disabledButtonText
            ]}>
              {submitting ? 'Submitting...' : isLastQuestion ? 'Submit' : 'Next'}
            </Text>
            {!isLastQuestion && (
              <MaterialIcons name="arrow-forward" size={20} color={COLORS.background.primary} />
            )}
            {isLastQuestion && (
              <MaterialIcons name="check" size={20} color={COLORS.background.primary} />
            )}
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
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
  progressContainer: {
    padding: SPACING.md,
    backgroundColor: COLORS.background.surface,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  progressBar: {
    height: 4,
    backgroundColor: COLORS.border.default,
    borderRadius: RADIUS.sm,
    marginBottom: SPACING.sm,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.sm,
  },
  progressText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'center',
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  questionContainer: {
    flex: 1,
    padding: SPACING.lg,
  },
  navigationContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: SPACING.md,
    backgroundColor: COLORS.background.surface,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.default,
  },
  navButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    minWidth: 100,
    justifyContent: 'center',
  },
  previousButton: {
    backgroundColor: COLORS.background.secondary,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  nextButton: {
    backgroundColor: COLORS.primary,
  },
  submitButton: {
    backgroundColor: COLORS.success,
  },
  disabledButton: {
    opacity: 0.5,
  },
  navButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  nextButtonText: {
    color: COLORS.background.primary,
  },
  disabledButtonText: {
    color: COLORS.text.disabled,
  },
});

export default SurveyFormScreen;
