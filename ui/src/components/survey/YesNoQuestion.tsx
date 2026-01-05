import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { YesNoQuestion as YesNoQuestionType } from '../../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';

interface YesNoQuestionProps {
  question: YesNoQuestionType;
  value: boolean | null;
  onChange: (value: boolean) => void;
  error?: string;
  disabled?: boolean;
}

const YesNoQuestion: React.FC<YesNoQuestionProps> = ({
  question,
  value,
  onChange,
  error,
  disabled = false
}) => {
  const yesLabel = question.yesLabel || 'Yes';
  const noLabel = question.noLabel || 'No';

  const handleOptionPress = (option: boolean) => {
    if (!disabled) {
      onChange(option);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.optionsContainer}>
        {/* Yes Option */}
        <TouchableOpacity
          style={[
            styles.optionButton,
            value === true && styles.selectedOption,
            value === true && styles.selectedYes,
            disabled && styles.disabledOption
          ]}
          onPress={() => handleOptionPress(true)}
          activeOpacity={0.7}
          disabled={disabled}
        >
          <View style={styles.optionContent}>
            <MaterialIcons
              name={value === true ? "check-circle" : "radio-button-unchecked"}
              size={24}
              color={
                disabled 
                  ? COLORS.text.disabled 
                  : value === true 
                    ? COLORS.background.surface 
                    : COLORS.text.secondary
              }
            />
            <Text style={[
              styles.optionText,
              value === true && styles.selectedOptionText,
              value === true && styles.selectedYesText,
              disabled && styles.disabledText
            ]}>
              {yesLabel}
            </Text>
          </View>
        </TouchableOpacity>

        {/* No Option */}
        <TouchableOpacity
          style={[
            styles.optionButton,
            value === false && styles.selectedOption,
            value === false && styles.selectedNo,
            disabled && styles.disabledOption
          ]}
          onPress={() => handleOptionPress(false)}
          activeOpacity={0.7}
          disabled={disabled}
        >
          <View style={styles.optionContent}>
            <MaterialIcons
              name={value === false ? "cancel" : "radio-button-unchecked"}
              size={24}
              color={
                disabled 
                  ? COLORS.text.disabled 
                  : value === false 
                    ? COLORS.background.surface 
                    : COLORS.text.secondary
              }
            />
            <Text style={[
              styles.optionText,
              value === false && styles.selectedOptionText,
              value === false && styles.selectedNoText,
              disabled && styles.disabledText
            ]}>
              {noLabel}
            </Text>
          </View>
        </TouchableOpacity>
      </View>

      {/* Current Selection Display */}
      <View style={styles.selectionDisplay}>
        <Text style={[
          styles.selectionText,
          disabled && styles.disabledText
        ]}>
          {value === null 
            ? 'No selection made' 
            : `Selected: ${value ? yesLabel : noLabel}`
          }
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    // Container styling handled by parent
  },
  optionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.md,
  },
  optionButton: {
    flex: 1,
    marginHorizontal: SPACING.xs,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 2,
    borderColor: COLORS.border.default,
    backgroundColor: COLORS.background.surface,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 60,
  },
  selectedOption: {
    borderColor: COLORS.primary,
  },
  selectedYes: {
    backgroundColor: COLORS.success,
    borderColor: COLORS.success,
  },
  selectedNo: {
    backgroundColor: COLORS.error,
    borderColor: COLORS.error,
  },
  disabledOption: {
    backgroundColor: COLORS.background.disabled,
    opacity: 0.6,
  },
  optionContent: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  optionText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
  selectedOptionText: {
    color: COLORS.background.surface,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
  selectedYesText: {
    color: COLORS.background.surface,
  },
  selectedNoText: {
    color: COLORS.background.surface,
  },
  disabledText: {
    color: COLORS.text.disabled,
  },
  selectionDisplay: {
    alignItems: 'center',
    padding: SPACING.sm,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
  },
  selectionText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
});

export default YesNoQuestion;
