/**
 * WalkieTalkieButton Component
 * Main push-to-talk button with proper state handling
 */

import React, { useState, useCallback } from 'react';
import { 
  View, 
  Text, 
  Pressable, 
  StyleSheet, 
  Vibration,
  Alert 
} from 'react-native';
import { useWalkieTalkie } from './useWalkieTalkie';
import { WalkieTalkieConfig } from './types';

interface WalkieTalkieButtonProps {
  config: WalkieTalkieConfig;
  style?: any;
  size?: 'small' | 'medium' | 'large';
  disabled?: boolean;
  onRecordingStart?: () => void;
  onRecordingStop?: () => void;
  onError?: (error: any) => void;
}

export function WalkieTalkieButton({
  config,
  style,
  size = 'medium',
  disabled = false,
  onRecordingStart,
  onRecordingStop,
  onError,
}: WalkieTalkieButtonProps) {
  const {
    state,
    initialize,
    startRecording,
    stopRecording,
    clearError,
    retry,
    isReady,
    canStartRecording,
    hasError,
    isConnected,
  } = useWalkieTalkie();

  const [isPressed, setIsPressed] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);

  /**
   * Initialize service if needed
   */
  const initializeIfNeeded = useCallback(async () => {
    if (!isInitialized && !state.isInitialized) {
      try {
        await initialize(config);
        setIsInitialized(true);
      } catch (error) {
        console.error('Initialization failed:', error);
        onError?.(error);
        Alert.alert(
          'Initialization Failed',
          'Failed to initialize walkie-talkie. Please check your permissions and try again.',
          [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Retry', onPress: () => initializeIfNeeded() },
          ]
        );
      }
    }
  }, [isInitialized, state.isInitialized, initialize, config, onError]);

  /**
   * Handle press in (start recording) - NON-BLOCKING
   */
  const handlePressIn = useCallback(() => {
    if (disabled) return;

    // Clear error if user is trying again
    if (hasError) {
      clearError();
    }

    // Initialize if needed (non-blocking)
    if (!isInitialized && !state.isInitialized) {
      initializeIfNeeded().catch(error => {
        console.error('Initialization failed:', error);
        onError?.(error);
      });
    }

    // Allow recording even with microphone errors (let user try)
    const canTryRecording = !state.isRecording && !state.isProcessing;
    
    if (!canTryRecording) {
      console.warn('Cannot start recording:', {
        isRecording: state.isRecording,
        isProcessing: state.isProcessing,
      });
      return;
    }

    setIsPressed(true);
    Vibration.vibrate(50); // Short vibration feedback
    
    // Start recording (non-blocking) - even if there were previous errors
    startRecording();
    onRecordingStart?.();

  }, [
    disabled,
    hasError,
    clearError,
    initializeIfNeeded,
    isInitialized,
    state.isInitialized,
    state.isRecording,
    state.isProcessing,
    startRecording,
    onRecordingStart,
    onError,
  ]);

  /**
   * Handle press out (stop recording) - NON-BLOCKING
   */
  const handlePressOut = useCallback(() => {
    if (disabled || !isPressed) return;

    setIsPressed(false);
    Vibration.vibrate(100); // Longer vibration for stop
    
    // Stop recording (non-blocking)
    stopRecording();
    onRecordingStop?.();

  }, [disabled, isPressed, stopRecording, onRecordingStop]);

  /**
   * Get button text based on state
   */
  const getButtonText = (): string => {
    if (hasError) {
      // Show specific error messages for microphone issues
      if (state.error?.code === 'MICROPHONE_UNAVAILABLE') {
        return 'Mic Issue - Try Anyway';
      }
      if (state.error?.code === 'RECORDING_FAILED') {
        return 'Audio Issue - Try Anyway';
      }
      return 'Error - Tap to Retry';
    }
    if (state.state === 'initializing') return 'Initializing...';
    if (!isConnected) return 'Connecting...';
    if (state.isUploading) return `Sending... ${state.uploadProgress}%`;
    if (state.isProcessing) return 'Processing...';
    if (state.isRecording) return `Recording... ${state.recordingDuration}s`;
    if (!isReady) return 'Not Ready';
    return 'Hold to Talk';
  };

  /**
   * Get button style based on state
   */
  const getButtonStyle = () => {
    const baseStyle = [styles.button, styles[size]];
    
    if (disabled) return [...baseStyle, styles.disabled];
    if (hasError) return [...baseStyle, styles.error];
    if (state.isRecording || isPressed) return [...baseStyle, styles.recording];
    if (state.isProcessing || state.isUploading) return [...baseStyle, styles.processing];
    if (!isReady) return [...baseStyle, styles.notReady];
    
    return [...baseStyle, styles.ready];
  };

  /**
   * Handle error retry
   */
  const handleErrorRetry = useCallback(async () => {
    if (hasError) {
      clearError();
      await retry();
    }
  }, [hasError, clearError, retry]);

  return (
    <View style={[styles.container, style]}>
      <Pressable
        style={getButtonStyle()}
        onPressIn={hasError ? handleErrorRetry : handlePressIn}
        onPressOut={hasError ? undefined : handlePressOut}
        disabled={disabled}
      >
        <Text style={styles.buttonText}>
          {getButtonText()}
        </Text>
        
        {state.isRecording && (
          <View style={styles.recordingIndicator}>
            <View style={styles.recordingDot} />
          </View>
        )}
      </Pressable>
      
      {/* Connection Status */}
      <View style={styles.statusContainer}>
        <View style={[
          styles.statusDot,
          isConnected ? styles.connected : styles.disconnected
        ]} />
        <Text style={styles.statusText}>
          {isConnected ? 'Connected' : 'Disconnected'}
        </Text>
      </View>
      
      {/* Error Display */}
      {hasError && state.error && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>
            {state.error.message}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  
  button: {
    borderRadius: 50,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
  },
  
  // Button sizes
  small: {
    width: 60,
    height: 60,
  },
  medium: {
    width: 80,
    height: 80,
  },
  large: {
    width: 100,
    height: 100,
  },
  
  // Button states
  ready: {
    backgroundColor: '#4CAF50',
  },
  recording: {
    backgroundColor: '#F44336',
    transform: [{ scale: 1.1 }],
  },
  processing: {
    backgroundColor: '#FF9800',
  },
  notReady: {
    backgroundColor: '#9E9E9E',
  },
  error: {
    backgroundColor: '#F44336',
  },
  disabled: {
    backgroundColor: '#BDBDBD',
    opacity: 0.6,
  },
  
  buttonText: {
    color: 'white',
    fontSize: 12,
    fontWeight: 'bold',
    textAlign: 'center',
    paddingHorizontal: 8,
  },
  
  recordingIndicator: {
    position: 'absolute',
    top: 8,
    right: 8,
  },
  
  recordingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: 'white',
    opacity: 0.8,
  },
  
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  
  statusDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginRight: 4,
  },
  
  connected: {
    backgroundColor: '#4CAF50',
  },
  
  disconnected: {
    backgroundColor: '#F44336',
  },
  
  statusText: {
    fontSize: 10,
    color: '#666',
  },
  
  errorContainer: {
    marginTop: 8,
    paddingHorizontal: 16,
    paddingVertical: 4,
    backgroundColor: '#FFEBEE',
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#FFCDD2',
  },
  
  errorText: {
    fontSize: 10,
    color: '#D32F2F',
    textAlign: 'center',
  },
});
