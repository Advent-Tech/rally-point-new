import React, { Component, ErrorInfo, ReactNode } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { AuthProvider } from './src/contexts/AuthContext';
import { LocationProvider } from './src/contexts/LocationContext';
import RootNavigator from './src/navigation/RootNavigator';
import WebScrollFix from './src/components/WebScrollFix';

// Error Boundary Component
interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
  errorInfo: ErrorInfo | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
    };
  }

  static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('🔴 App Error Boundary caught an error:', error, errorInfo);
    this.setState({
      error,
      errorInfo,
    });
  }

  handleReset = () => {
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null,
    });
  };

  render() {
    if (this.state.hasError) {
      return (
        <View style={styles.errorContainer}>
          <ScrollView contentContainerStyle={styles.errorContent}>
            <Text style={styles.errorTitle}>⚠️ Something went wrong</Text>
            <Text style={styles.errorMessage}>
              {this.state.error?.toString() || 'Unknown error occurred'}
            </Text>
            {this.state.errorInfo && (
              <View style={styles.errorDetailsContainer}>
                <Text style={styles.errorDetailsTitle}>Error Details:</Text>
                <Text style={styles.errorDetails}>
                  {this.state.errorInfo.componentStack}
                </Text>
              </View>
            )}
            <TouchableOpacity style={styles.resetButton} onPress={this.handleReset}>
              <Text style={styles.resetButtonText}>Try Again</Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      );
    }

    return this.props.children;
  }
}

// Main App Component with Auth Context and Error Boundary
export default function App() {
  console.log('🚀 App component rendering...');

  try {
    return (
      <ErrorBoundary>
        <AuthProvider>
          <LocationProvider>
            <WebScrollFix />
            <RootNavigator />
          </LocationProvider>
        </AuthProvider>
      </ErrorBoundary>
    );
  } catch (error) {
    console.error('❌ App component error:', error);
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorTitle}>App Failed to Load</Text>
        <Text style={styles.errorMessage}>{String(error)}</Text>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  errorContainer: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  errorContent: {
    padding: 20,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: '100%',
  },
  errorTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#dc2626',
    marginBottom: 16,
    textAlign: 'center',
  },
  errorMessage: {
    fontSize: 16,
    color: '#374151',
    marginBottom: 20,
    textAlign: 'center',
    paddingHorizontal: 20,
  },
  errorDetailsContainer: {
    backgroundColor: '#ffffff',
    padding: 16,
    borderRadius: 8,
    marginBottom: 20,
    width: '100%',
    maxWidth: 500,
    borderWidth: 1,
    borderColor: '#e5e7eb',
  },
  errorDetailsTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#6b7280',
    marginBottom: 8,
  },
  errorDetails: {
    fontSize: 12,
    color: '#9ca3af',
    fontFamily: 'monospace',
  },
  resetButton: {
    backgroundColor: '#002b5b',
    paddingHorizontal: 32,
    paddingVertical: 12,
    borderRadius: 8,
    marginTop: 10,
  },
  resetButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
});