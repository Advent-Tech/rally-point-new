import React, { useState } from 'react';
import { View, Text, TouchableOpacity, TextInput, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { RadioQuestion as RadioQuestionType } from '../../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';

interface RadioQuestionProps {
  question: RadioQuestionType;
  value: string;
  onChange: (value: string) => void;
  error?: string;
  disabled?: boolean;
}

const RadioQuestion: React.FC<RadioQuestionProps> = ({
  question,
  value,
  onChange,
  error,
  disabled = false
}) => {
  const [otherValue, setOtherValue] = useState('');
  const [showOtherInput, setShowOtherInput] = useState(false);

  const handleOptionSelect = (option: string) => {
    if (option === 'other') {
      setShowOtherInput(true);
      if (otherValue) {
        onChange(otherValue);
      }
    } else {
      setShowOtherInput(false);
      onChange(option);
    }
  };

  const handleOtherChange = (text: string) => {
    setOtherValue(text);
    onChange(text);
  };

  const isSelected = (option: string) => {
    if (option === 'other') {
      return showOtherInput || (!question.options.includes(value) && value !== '');
    }
    return value === option;
  };

  return (
    <View style={styles.container}>
      {question.options.map((option, index) => (
        <TouchableOpacity
          key={index}
          style={[
            styles.optionContainer,
            isSelected(option) && styles.selectedOption,
            disabled && styles.disabledOption
          ]}
          onPress={() => !disabled && handleOptionSelect(option)}
          activeOpacity={0.7}
        >
          <View style={styles.radioContainer}>
            <View style={[
              styles.radioButton,
              isSelected(option) && styles.radioButtonSelected
            ]}>
              {isSelected(option) && (
                <MaterialIcons 
                  name="radio-button-checked" 
                  size={20} 
                  color={COLORS.primary} 
                />
              )}
              {!isSelected(option) && (
                <MaterialIcons 
                  name="radio-button-unchecked" 
                  size={20} 
                  color={COLORS.text.secondary} 
                />
              )}
            </View>
            <Text style={[
              styles.optionText,
              isSelected(option) && styles.selectedOptionText,
              disabled && styles.disabledText
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
              disabled && styles.disabledOption
            ]}
            onPress={() => !disabled && handleOptionSelect('other')}
            activeOpacity={0.7}
          >
            <View style={styles.radioContainer}>
              <View style={[
                styles.radioButton,
                showOtherInput && styles.radioButtonSelected
              ]}>
                {showOtherInput ? (
                  <MaterialIcons 
                    name="radio-button-checked" 
                    size={20} 
                    color={COLORS.primary} 
                  />
                ) : (
                  <MaterialIcons 
                    name="radio-button-unchecked" 
                    size={20} 
                    color={COLORS.text.secondary} 
                  />
                )}
              </View>
              <Text style={[
                styles.optionText,
                showOtherInput && styles.selectedOptionText,
                disabled && styles.disabledText
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
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    // Container styling handled by parent
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
  radioContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  radioButton: {
    marginRight: SPACING.sm,
  },
  radioButtonSelected: {
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
});

export default RadioQuestion;
