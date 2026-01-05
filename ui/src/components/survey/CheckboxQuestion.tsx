import React, { useState } from 'react';
import { View, Text, TouchableOpacity, TextInput, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { CheckboxQuestion as CheckboxQuestionType } from '../../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';

interface CheckboxQuestionProps {
  question: CheckboxQuestionType;
  value: string[];
  onChange: (value: string[]) => void;
  error?: string;
  disabled?: boolean;
}

const CheckboxQuestion: React.FC<CheckboxQuestionProps> = ({
  question,
  value = [],
  onChange,
  error,
  disabled = false
}) => {
  const [otherValue, setOtherValue] = useState('');
  const [showOtherInput, setShowOtherInput] = useState(false);

  const handleOptionToggle = (option: string) => {
    if (option === 'other') {
      if (showOtherInput) {
        // Remove other value
        const newValue = value.filter(v => !isOtherValue(v));
        setShowOtherInput(false);
        setOtherValue('');
        onChange(newValue);
      } else {
        // Show other input
        setShowOtherInput(true);
        if (otherValue) {
          onChange([...value, otherValue]);
        }
      }
    } else {
      // Toggle regular option
      const isSelected = value.includes(option);
      if (isSelected) {
        onChange(value.filter(v => v !== option));
      } else {
        // Check max selections constraint
        if (question.maxSelections && value.length >= question.maxSelections) {
          return; // Don't add if max reached
        }
        onChange([...value, option]);
      }
    }
  };

  const handleOtherChange = (text: string) => {
    setOtherValue(text);
    // Remove previous other value and add new one
    const newValue = value.filter(v => !isOtherValue(v));
    if (text.trim()) {
      onChange([...newValue, text]);
    } else {
      onChange(newValue);
    }
  };

  const isOtherValue = (val: string) => {
    return !question.options.includes(val);
  };

  const isSelected = (option: string) => {
    if (option === 'other') {
      return showOtherInput || value.some(v => isOtherValue(v));
    }
    return value.includes(option);
  };

  const canSelectMore = () => {
    return !question.maxSelections || value.length < question.maxSelections;
  };

  return (
    <View style={styles.container}>
      {/* Selection constraints info */}
      {(question.minSelections || question.maxSelections) && (
        <Text style={styles.constraintText}>
          {question.minSelections && question.maxSelections
            ? `Select ${question.minSelections}-${question.maxSelections} options`
            : question.minSelections
            ? `Select at least ${question.minSelections} options`
            : `Select up to ${question.maxSelections} options`
          }
        </Text>
      )}

      {question.options.map((option, index) => (
        <TouchableOpacity
          key={index}
          style={[
            styles.optionContainer,
            isSelected(option) && styles.selectedOption,
            disabled && styles.disabledOption,
            !canSelectMore() && !isSelected(option) && styles.disabledOption
          ]}
          onPress={() => !disabled && (canSelectMore() || isSelected(option)) && handleOptionToggle(option)}
          activeOpacity={0.7}
        >
          <View style={styles.checkboxContainer}>
            <View style={[
              styles.checkbox,
              isSelected(option) && styles.checkboxSelected
            ]}>
              {isSelected(option) ? (
                <MaterialIcons 
                  name="check-box" 
                  size={20} 
                  color={COLORS.primary} 
                />
              ) : (
                <MaterialIcons 
                  name="check-box-outline-blank" 
                  size={20} 
                  color={COLORS.text.secondary} 
                />
              )}
            </View>
            <Text style={[
              styles.optionText,
              isSelected(option) && styles.selectedOptionText,
              disabled && styles.disabledText,
              !canSelectMore() && !isSelected(option) && styles.disabledText
            ]}>
              {option}
            </Text>
          </View>
        </TouchableOpacity>
      ))}

      {/* Other option */}
      {question.allowOther && (
        <View>
          <TouchableOpacity
            style={[
              styles.optionContainer,
              showOtherInput && styles.selectedOption,
              disabled && styles.disabledOption,
              !canSelectMore() && !showOtherInput && styles.disabledOption
            ]}
            onPress={() => !disabled && (canSelectMore() || showOtherInput) && handleOptionToggle('other')}
            activeOpacity={0.7}
          >
            <View style={styles.checkboxContainer}>
              <View style={[
                styles.checkbox,
                showOtherInput && styles.checkboxSelected
              ]}>
                {showOtherInput ? (
                  <MaterialIcons 
                    name="check-box" 
                    size={20} 
                    color={COLORS.primary} 
                  />
                ) : (
                  <MaterialIcons 
                    name="check-box-outline-blank" 
                    size={20} 
                    color={COLORS.text.secondary} 
                  />
                )}
              </View>
              <Text style={[
                styles.optionText,
                showOtherInput && styles.selectedOptionText,
                disabled && styles.disabledText,
                !canSelectMore() && !showOtherInput && styles.disabledText
              ]}>
                Other
              </Text>
            </View>
          </TouchableOpacity>

          {showOtherInput && (
            <TextInput
              style={[
                styles.otherInput,
                error && styles.errorInput,
                disabled && styles.disabledInput
              ]}
              value={otherValue}
              onChangeText={handleOtherChange}
              placeholder="Please specify..."
              placeholderTextColor={COLORS.text.placeholder}
              editable={!disabled}
            />
          )}
        </View>
      )}

      {/* Current selection count */}
      {question.maxSelections && (
        <Text style={styles.countText}>
          {value.length} of {question.maxSelections} selected
        </Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    // Container styling handled by parent
  },
  constraintText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
    fontStyle: 'italic',
  },
  optionContainer: {
    marginBottom: SPACING.sm,
    padding: SPACING.sm,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    backgroundColor: COLORS.background.surface,
  },
  selectedOption: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.primary + '08', // 8% opacity
  },
  disabledOption: {
    backgroundColor: COLORS.background.disabled,
    opacity: 0.6,
  },
  checkboxContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    marginRight: SPACING.sm,
  },
  checkboxSelected: {
    // Selected styling handled by icon color
  },
  optionText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    flex: 1,
  },
  selectedOptionText: {
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  disabledText: {
    color: COLORS.text.disabled,
  },
  otherInput: {
    marginTop: SPACING.sm,
    marginLeft: SPACING.xl,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.surface,
    minHeight: 40,
  },
  errorInput: {
    borderColor: COLORS.error,
    backgroundColor: COLORS.error + '08',
  },
  disabledInput: {
    backgroundColor: COLORS.background.disabled,
    color: COLORS.text.disabled,
  },
  countText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'right',
    marginTop: SPACING.xs,
  },
});

export default CheckboxQuestion;
