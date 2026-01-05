import React, { useState } from 'react';
import { View, Text, TouchableOpacity, Modal, ScrollView, StyleSheet, Platform } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { DropdownQuestion as DropdownQuestionType } from '../../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../../constants/Colors';

// Conditional import for Picker
let Picker: any;
if (Platform.OS !== 'web') {
  try {
    Picker = require('@react-native-picker/picker').Picker;
  } catch (error) {
    console.warn('Picker not available, using custom dropdown');
  }
}

interface DropdownQuestionProps {
  question: DropdownQuestionType;
  value: string;
  onChange: (value: string) => void;
  error?: string;
  disabled?: boolean;
}

const DropdownQuestion: React.FC<DropdownQuestionProps> = ({
  question,
  value,
  onChange,
  error,
  disabled = false
}) => {
  const [isOpen, setIsOpen] = useState(false);

  const handleSelect = (option: string) => {
    onChange(option);
    setIsOpen(false);
  };

  const getDisplayValue = () => {
    return value || question.placeholder || 'Select an option';
  };

  // Use native picker on mobile if available
  if (Platform.OS !== 'web' && Picker) {
    return (
      <View style={styles.container}>
        <View style={[
          styles.pickerContainer,
          error && styles.errorContainer,
          disabled && styles.disabledContainer
        ]}>
          <Picker
            selectedValue={value}
            onValueChange={onChange}
            enabled={!disabled}
            style={styles.picker}
          >
            <Picker.Item 
              label={question.placeholder || 'Select an option'} 
              value="" 
              color={COLORS.text.placeholder}
            />
            {question.options.map((option, index) => (
              <Picker.Item 
                key={index} 
                label={option} 
                value={option}
                color={COLORS.text.primary}
              />
            ))}
          </Picker>
        </View>
      </View>
    );
  }

  // Custom dropdown for web and fallback
  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={[
          styles.dropdown,
          error && styles.errorDropdown,
          disabled && styles.disabledDropdown,
          isOpen && styles.openDropdown
        ]}
        onPress={() => !disabled && setIsOpen(true)}
        activeOpacity={0.7}
      >
        <Text style={[
          styles.dropdownText,
          !value && styles.placeholderText,
          disabled && styles.disabledText
        ]}>
          {getDisplayValue()}
        </Text>
        <MaterialIcons 
          name={isOpen ? "keyboard-arrow-up" : "keyboard-arrow-down"} 
          size={24} 
          color={disabled ? COLORS.text.disabled : COLORS.text.secondary} 
        />
      </TouchableOpacity>

      {/* Custom Modal Dropdown */}
      <Modal
        visible={isOpen}
        transparent
        animationType="fade"
        onRequestClose={() => setIsOpen(false)}
      >
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setIsOpen(false)}
        >
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>{question.label}</Text>
              <TouchableOpacity
                onPress={() => setIsOpen(false)}
                style={styles.closeButton}
              >
                <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
            </View>
            
            <ScrollView style={styles.optionsList}>
              {question.options.map((option, index) => (
                <TouchableOpacity
                  key={index}
                  style={[
                    styles.option,
                    value === option && styles.selectedOption
                  ]}
                  onPress={() => handleSelect(option)}
                >
                  <Text style={[
                    styles.optionText,
                    value === option && styles.selectedOptionText
                  ]}>
                    {option}
                  </Text>
                  {value === option && (
                    <MaterialIcons 
                      name="check" 
                      size={20} 
                      color={COLORS.primary} 
                    />
                  )}
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    // Container styling handled by parent
  },
  // Native Picker Styles
  pickerContainer: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.surface,
    overflow: 'hidden',
  },
  picker: {
    height: 48,
    color: COLORS.text.primary,
  },
  // Custom Dropdown Styles
  dropdown: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: COLORS.background.surface,
    minHeight: 48,
  },
  openDropdown: {
    borderColor: COLORS.primary,
  },
  errorContainer: {
    borderColor: COLORS.error,
    backgroundColor: COLORS.error + '08',
  },
  errorDropdown: {
    borderColor: COLORS.error,
    backgroundColor: COLORS.error + '08',
  },
  disabledContainer: {
    backgroundColor: COLORS.background.disabled,
    opacity: 0.6,
  },
  disabledDropdown: {
    backgroundColor: COLORS.background.disabled,
    opacity: 0.6,
  },
  dropdownText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    flex: 1,
  },
  placeholderText: {
    color: COLORS.text.placeholder,
  },
  disabledText: {
    color: COLORS.text.disabled,
  },
  // Modal Styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.lg,
  },
  modalContent: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    maxHeight: '70%',
    width: '100%',
    maxWidth: 400,
    ...SHADOWS.medium,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  modalTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    flex: 1,
  },
  closeButton: {
    padding: SPACING.xs,
  },
  optionsList: {
    maxHeight: 300,
  },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  selectedOption: {
    backgroundColor: COLORS.primary + '08',
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
});

export default DropdownQuestion;
