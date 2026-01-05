import React, { Component, ErrorInfo, ReactNode } from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING } from '../constants/Colors';

interface Props {
  children: ReactNode;
  fallbackComponent?: ReactNode;
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error?: Error;
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): State {
    // Update state so the next render will show the fallback UI
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('🔴 ErrorBoundary caught an error:', error);
    console.error('🔴 Error info:', errorInfo);
    
    if (this.props.onError) {
      this.props.onError(error, errorInfo);
    }
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallbackComponent) {
        return this.props.fallbackComponent;
      }

      return (
        <View style={styles.container}>
          <View style={styles.content}>
            <Text style={styles.title}>⚠️ Something went wrong</Text>
            <Text style={styles.message}>
              There was an error loading this screen. This might be a navigation issue.
            </Text>
            <Text style={styles.errorDetails}>
              Error: {this.state.error?.message || 'Unknown error'}
            </Text>
            <TouchableOpacity
              style={styles.button}
              onPress={() => this.setState({ hasError: false, error: undefined })}
            >
              <Text style={styles.buttonText}>Try Again</Text>
            </TouchableOpacity>
          </View>
        </View>
      );
    }

    return this.props.children;
  }
}

const styles = {
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
    justifyContent: 'center' as const,
    alignItems: 'center' as const,
    padding: SPACING.xl,
  },
  content: {
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.xl,
    borderRadius: 12,
    alignItems: 'center' as const,
    maxWidth: 300,
  },
  title: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold as any,
    color: COLORS.error,
    marginBottom: SPACING.md,
    textAlign: 'center' as const,
  },
  message: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    textAlign: 'center' as const,
    marginBottom: SPACING.md,
    lineHeight: 20,
  },
  errorDetails: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'center' as const,
    marginBottom: SPACING.lg,
    fontFamily: 'monospace',
  },
  button: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: 8,
  },
  buttonText: {
    color: COLORS.textInverse,
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium as any,
  },
};

export default ErrorBoundary;
