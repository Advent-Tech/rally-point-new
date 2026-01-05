import React from 'react';
import { View, TextInput, StyleSheet } from 'react-native';
import { TextQuestion as TextQuestionType } from '../../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';

interface TextQuestionProps {
  question: TextQuestionType;
  value: string;
  onChange: (value: string) => void;
  error?: string;
  disabled?: boolean;
}

const TextQuestion: React.FC<TextQuestionProps> = ({
  question,
  value,
  onChange,
  error,
  disabled = false
}) => {
  const getKeyboardType = () => {
    switch (question.type) {
      case 'email':
        return 'email-address';
      case 'phone':
        return 'phone-pad';
      default:
        return 'default';
    }
  };

  const getAutoCompleteType = () => {
    switch (question.type) {
      case 'email':
        return 'email';
      case 'phone':
        return 'tel';
      default:
        return 'off';
    }
  };

  const isMultiline = question.type === 'textarea';
  const maxLength = question.maxLength || (isMultiline ? 1000 : 255);

  return (
    <View style={styles.container}>
      <TextInput
        style={[
          styles.input,
          isMultiline && styles.textareaInput,
          error && styles.errorInput,
          disabled && styles.disabledInput
        ]}
        value={value}
        onChangeText={onChange}
        placeholder={question.placeholder || `Enter ${question.label.toLowerCase()}`}
        placeholderTextColor={COLORS.text.placeholder}
        keyboardType={getKeyboardType()}
        autoCompleteType={getAutoCompleteType()}
        multiline={isMultiline}
        numberOfLines={isMultiline ? 4 : 1}
        maxLength={maxLength}
        editable={!disabled}
        textAlignVertical={isMultiline ? 'top' : 'center'}
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
  textareaInput: {
    minHeight: 100,
    paddingTop: SPACING.sm,
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

export default TextQuestion;
