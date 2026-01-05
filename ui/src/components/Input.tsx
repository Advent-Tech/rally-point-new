import React from 'react';
import { View, Text, TextInput, StyleSheet, TouchableOpacity } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { InputProps } from '../types';

const Input: React.FC<InputProps> = ({
  label,
  placeholder,
  value,
  onChangeText,
  secureTextEntry = false,
  error,
  disabled = false,
  rightIcon,
  onRightIconPress,
}) => {
  const getInputStyle = () => {
    const baseStyle = [styles.input];

    if (error) {
      baseStyle.push(styles.errorInput);
    }

    if (disabled) {
      baseStyle.push(styles.disabledInput);
    }

    return baseStyle;
  };

  return (
    <View style={styles.container}>
      {label && (
        <Text style={styles.label}>
          {label}
        </Text>
      )}
      <View style={styles.inputContainer}>
        <TextInput
          style={[getInputStyle(), rightIcon && styles.inputWithIcon]}
          placeholder={placeholder}
          placeholderTextColor="#94a3b8"
          value={value}
          onChangeText={onChangeText}
          secureTextEntry={secureTextEntry}
          editable={!disabled}
          autoCapitalize="none"
          autoCorrect={false}
        />
        {rightIcon && (
          <TouchableOpacity
            style={styles.rightIconContainer}
            onPress={onRightIconPress}
            disabled={!onRightIconPress}
          >
            <MaterialIcons
              name={rightIcon === 'eye' ? 'visibility' : rightIcon === 'eye-off' ? 'visibility-off' : 'help'}
              size={20}
              color="#64748b"
            />
          </TouchableOpacity>
        )}
      </View>
      {error && (
        <Text style={styles.errorText}>
          {error}
        </Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: 16,
  },
  label: {
    color: '#334155',
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 8,
  },
  inputContainer: {
    position: 'relative',
    flexDirection: 'row',
    alignItems: 'center',
  },
  input: {
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    backgroundColor: '#ffffff',
    color: '#0f172a',
    flex: 1,
  },
  inputWithIcon: {
    paddingRight: 50,
  },
  rightIconContainer: {
    position: 'absolute',
    right: 16,
    padding: 4,
  },
  errorInput: {
    borderColor: '#ef4444',
  },
  disabledInput: {
    backgroundColor: '#f1f5f9',
    color: '#94a3b8',
  },
  errorText: {
    color: '#ef4444',
    fontSize: 14,
    marginTop: 4,
  },
});

export default Input;
