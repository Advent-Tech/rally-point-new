import React from 'react';
import { TouchableOpacity, Text, ActivityIndicator, StyleSheet } from 'react-native';
import { ButtonProps } from '../types';

const Button: React.FC<ButtonProps> = ({
  title,
  onPress,
  variant = 'primary',
  size = 'medium',
  disabled = false,
  loading = false,
}) => {
  const getButtonStyle = () => {
    const baseStyle = [styles.button];

    if (variant === 'primary') {
      baseStyle.push(styles.primaryButton);
    } else if (variant === 'secondary') {
      baseStyle.push(styles.secondaryButton);
    } else if (variant === 'outline') {
      baseStyle.push(styles.outlineButton);
    }

    if (size === 'small') {
      baseStyle.push(styles.smallButton);
    } else if (size === 'large') {
      baseStyle.push(styles.largeButton);
    }

    if (disabled) {
      baseStyle.push(styles.disabledButton);
    }

    return baseStyle;
  };

  const getTextStyle = () => {
    const baseStyle = [styles.text];

    if (variant === 'primary' || variant === 'secondary') {
      baseStyle.push(styles.whiteText);
    } else if (variant === 'outline') {
      baseStyle.push(styles.primaryText);
    }

    if (size === 'small') {
      baseStyle.push(styles.smallText);
    } else if (size === 'large') {
      baseStyle.push(styles.largeText);
    }

    return baseStyle;
  };

  return (
    <TouchableOpacity
      style={getButtonStyle()}
      onPress={onPress}
      disabled={disabled || loading}
      activeOpacity={0.8}
    >
      {loading ? (
        <ActivityIndicator
          color={variant === 'outline' ? '#2563eb' : '#ffffff'}
          size="small"
        />
      ) : (
        <Text style={getTextStyle()}>
          {title}
        </Text>
      )}
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  button: {
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderWidth: 1,
  },
  primaryButton: {
    backgroundColor: '#2563eb',
    borderColor: '#2563eb',
  },
  secondaryButton: {
    backgroundColor: '#475569',
    borderColor: '#475569',
  },
  outlineButton: {
    backgroundColor: 'transparent',
    borderColor: '#2563eb',
  },
  smallButton: {
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  largeButton: {
    paddingHorizontal: 24,
    paddingVertical: 16,
  },
  disabledButton: {
    opacity: 0.5,
  },
  text: {
    fontWeight: '600',
    fontSize: 16,
  },
  whiteText: {
    color: '#ffffff',
  },
  primaryText: {
    color: '#2563eb',
  },
  smallText: {
    fontSize: 14,
  },
  largeText: {
    fontSize: 18,
  },
});

export default Button;
