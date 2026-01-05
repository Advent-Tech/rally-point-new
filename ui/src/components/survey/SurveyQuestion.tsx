import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { AnyQuestion } from '../../types/survey';
import { COLORS, TYPOGRAPHY, SPACING } from '../../constants/Colors';
import TextQuestion from './TextQuestion';
import RadioQuestion from './RadioQuestion';
import CheckboxQuestion from './CheckboxQuestion';
import DropdownQuestion from './DropdownQuestion';
import RatingQuestion from './RatingQuestion';
import YesNoQuestion from './YesNoQuestion';
import NumberQuestion from './NumberQuestion';

interface SurveyQuestionProps {
  question: AnyQuestion;
  value: any;
  onChange: (value: any) => void;
  error?: string;
  disabled?: boolean;
}

const SurveyQuestion: React.FC<SurveyQuestionProps> = ({
  question,
  value,
  onChange,
  error,
  disabled = false
}) => {
  const renderQuestionComponent = () => {
    const commonProps = {
      question,
      value,
      onChange,
      error,
      disabled
    };

    switch (question.type) {
      case 'text':
      case 'textarea':
      case 'email':
      case 'phone':
        return <TextQuestion {...commonProps} />;
      
      case 'number':
        return <NumberQuestion {...commonProps} />;
      
      case 'radio':
        return <RadioQuestion {...commonProps} />;
      
      case 'checkbox':
        return <CheckboxQuestion {...commonProps} />;
      
      case 'dropdown':
        return <DropdownQuestion {...commonProps} />;
      
      case 'rating':
        return <RatingQuestion {...commonProps} />;
      
      case 'yes_no':
        return <YesNoQuestion {...commonProps} />;
      
      default:
        return (
          <Text style={styles.errorText}>
            Unsupported question type: {question.type}
          </Text>
        );
    }
  };

  return (
    <View style={styles.container}>
      {/* Question Header */}
      <View style={styles.header}>
        <Text style={styles.label}>
          {question.label}
          {question.required && <Text style={styles.required}> *</Text>}
        </Text>
        {question.description && (
          <Text style={styles.description}>{question.description}</Text>
        )}
      </View>

      {/* Question Component */}
      <View style={styles.questionContainer}>
        {renderQuestionComponent()}
      </View>

      {/* Error Message */}
      {error && (
        <Text style={styles.errorText}>{error}</Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: SPACING.lg,
  },
  header: {
    marginBottom: SPACING.sm,
  },
  label: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    lineHeight: 22,
  },
  required: {
    color: COLORS.error,
  },
  description: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    lineHeight: 18,
  },
  questionContainer: {
    // Individual question components will handle their own styling
  },
  errorText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.error,
    marginTop: SPACING.xs,
  },
});

export default SurveyQuestion;
