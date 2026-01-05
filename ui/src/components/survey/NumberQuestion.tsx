import React from 'react';
import { View, TextInput, StyleSheet } from 'react-native';
import { NumberQuestion as NumberQuestionType } from '../../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';

interface NumberQuestionProps {
  question: NumberQuestionType;
  value: number | string;
  onChange: (value: number | string) => void;
  error?: string;
  disabled?: boolean;
}

const NumberQuestion: React.FC<NumberQuestionProps> = ({
  question,
  value,
  onChange,
  error,
  disabled = false
}) => {
  const handleChange = (text: string) => {
    // Allow empty string for clearing
    if (text === '') {
      onChange('');
      return;
    }

    // Parse number and validate range
    const numValue = parseFloat(text);
    if (!isNaN(numValue)) {
      // Check min/max constraints
      if (question.min !== undefined && numValue < question.min) {
        return; // Don't update if below minimum
      }
      if (question.max !== undefined && numValue > question.max) {
        return; // Don't update if above maximum
      }
      onChange(numValue);
    }
  };

  const getPlaceholder = () => {
    if (question.placeholder) return question.placeholder;
    
    let placeholder = `Enter ${question.label.toLowerCase()}`;
    if (question.min !== undefined && question.max !== undefined) {
      placeholder += ` (${question.min}-${question.max})`;
    } else if (question.min !== undefined) {
      placeholder += ` (min: ${question.min})`;
    } else if (question.max !== undefined) {
      placeholder += ` (max: ${question.max})`;
    }
    
    return placeholder;
  };

  return (
    <View style={styles.container}>
      <TextInput
        style={[
          styles.input,
          error && styles.errorInput,
          disabled && styles.disabledInput
        ]}
        value={value.toString()}
        onChangeText={handleChange}
        placeholder={getPlaceholder()}
        placeholderTextColor={COLORS.text.placeholder}
        keyboardType="numeric"
        editable={!disabled}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    // Container styling handled by parent
  },
  input: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.surface,
    minHeight: 48,
  },
  errorInput: {
    borderColor: COLORS.error,
    backgroundColor: COLORS.error + '08', // 8% opacity
  },
  disabledInput: {
    backgroundColor: COLORS.background.disabled,
    color: COLORS.text.disabled,
  },
});

export default NumberQuestion;
