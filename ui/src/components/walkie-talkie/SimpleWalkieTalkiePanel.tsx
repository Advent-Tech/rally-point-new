/**
 * Simple Walkie-Talkie Panel
 * Compact interface with just essential features:
 * - Push to talk button
 * - Simple status display
 * - Background processing
 */

import React, { useState, useCallback, useEffect, useRef } from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  Vibration,
  Dimensions,
  Animated,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useWalkieTalkie } from './useWalkieTalkie';
import { WalkieTalkieConfig } from './types';
import { VoicePitchIndicator } from './VoicePitchIndicator';

interface SimpleWalkieTalkirTalkiePanelProps {
  teamId: string;
  userId: string;
  userName: string;
  teamName?: string;
  onClose: () => void;
}

const { width } = Dimensions.get('window');

export function SimpleWalkieTalkiePanel({
  teamId,
  userId,
  userName,
  teamName,
  onClose,
}: SimpleWalkieTalkirTalkiePanelProps) {
  console.log('🎯 🚀 SimpleWalkieTalkiePanel MOUNTED with props:', {
    teamId,
    userId, 
    userName,
    teamName
  });

  const {
    state,
    initialize,
    startRecording,
    stopRecording,
    clearError,
    hasError,
    isReady,
  } = useWalkieTalkie();

  const [isPressed, setIsPressed] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);
  const [shortPressWarning, setShortPressWarning] = useState(false);

  // Track press start time for minimum duration check
  const pressStartTime = useRef<number | null>(null);
  const MIN_PRESS_DURATION_MS = 1000; // 1 second minimum

  // Animation for listening feedback
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const rotateAnim = useRef(new Animated.Value(0)).current;

  // Initialize on mount
  useEffect(() => {
    console.log('🎯 📋 SimpleWalkieTalkiePanel useEffect triggered - preparing to initialize...');
    
    const config: WalkieTalkieConfig = {
      teamId,
      userId,
      userName,
      recording: {
        maxDuration: 60,
        quality: 'medium',
        format: 'm4a',
        sampleRate: 44100,
        bitRate: 128000,
      },
      autoPlay: true,
      speakerMode: true,
      uploadTimeout: 30000,
      retryAttempts: 3,
      vibrationEnabled: true,
      soundEnabled: true,
    };

    console.log('🎯 📋 About to call initialize() with config:', config);

    initialize(config)
      .then(() => {
        setIsInitialized(true);
        console.log('✅ Simple walkie-talkie initialized');
      })
      .catch(error => {
        console.error('❌ Simple walkie-talkie initialization failed:', error);
        // Continue anyway - user can still try
        setIsInitialized(true);
      });
  }, [teamId, userId, userName, initialize]);

  // Handle playback animations
  useEffect(() => {
    if (state.isPlayingMessage) {
      // Start pulsing animation
      const pulseAnimation = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.2,
            duration: 800,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 800,
            useNativeDriver: true,
          }),
        ])
      );

      // Start rotating animation
      const rotateAnimation = Animated.loop(
        Animated.timing(rotateAnim, {
          toValue: 1,
          duration: 2000,
          useNativeDriver: true,
        })
      );

      pulseAnimation.start();
      rotateAnimation.start();

      return () => {
        pulseAnimation.stop();
        rotateAnimation.stop();
        pulseAnim.setValue(1);
        rotateAnim.setValue(0);
      };
    } else {
      // Reset animations
      pulseAnim.setValue(1);
      rotateAnim.setValue(0);
    }
  }, [state.isPlayingMessage, pulseAnim, rotateAnim]);

  /**
   * Handle press in (start recording) - NON-BLOCKING
   */
  const handlePressIn = useCallback(() => {
    if (!isInitialized) return;

    // Clear any previous errors or warnings
    if (hasError) {
      clearError();
    }
    setShortPressWarning(false);

    // Record the press start time
    pressStartTime.current = Date.now();

    setIsPressed(true);
    Vibration.vibrate(50);

    // Start recording (non-blocking)
    startRecording();
    console.log('🎤 Recording started (non-blocking)');
  }, [isInitialized, hasError, clearError, startRecording]);

  /**
   * Handle press out (stop recording) - NON-BLOCKING
   * Cancels recording if held for less than 1 second
   */
  const handlePressOut = useCallback(() => {
    if (!isPressed) return;

    setIsPressed(false);

    // Check if held for minimum duration
    const pressDuration = pressStartTime.current ? Date.now() - pressStartTime.current : 0;
    pressStartTime.current = null;

    if (pressDuration < MIN_PRESS_DURATION_MS) {
      // Too short - cancel the recording
      console.log(`⚠️ Press too short (${pressDuration}ms < ${MIN_PRESS_DURATION_MS}ms) - canceling recording`);
      Vibration.vibrate([0, 100, 50, 100]); // Double vibration to indicate cancellation
      setShortPressWarning(true);

      // Clear warning after 2 seconds
      setTimeout(() => setShortPressWarning(false), 2000);

      // Stop recording but don't upload (it will be discarded due to short duration)
      stopRecording();
      return;
    }

    Vibration.vibrate(100);

    // Stop recording (non-blocking)
    stopRecording();
    console.log(`🛑 Recording stopped after ${pressDuration}ms (non-blocking)`);
  }, [isPressed, stopRecording]);

  /**
   * Get simple status text
   */
  const getStatusText = (): string => {
    if (!isInitialized) return 'Initializing...';
    if (shortPressWarning) return 'Hold longer (1 sec min)';
    if (hasError) return 'Tap to retry';
    if (state.isPlayingMessage) return `Listening to ${state.currentPlayingSender || 'teammate'}...`;
    if (state.isRecording) return 'Recording...';
    if (state.isProcessing) return 'Processing...';
    // Don't show uploading status - it's background only
    if (isReady) return 'Ready';
    return 'Connecting...';
  };

  /**
   * Get status color
   */
  const getStatusColor = (): string => {
    if (shortPressWarning) return '#FFA500'; // Orange for warning
    if (hasError) return '#FF6B6B';
    if (state.isPlayingMessage) return '#9B59B6'; // Purple for listening
    if (state.isRecording) return '#4ECDC4';
    if (state.isProcessing) return '#FFE66D';
    if (isReady) return '#95E1D3';
    return '#A8A8A8';
  };

  /**
   * Get button color
   */
  const getButtonColor = (): string => {
    if (hasError) return '#FF6B6B';
    if (state.isPlayingMessage) return '#9B59B6'; // Purple when listening - disabled
    if (isPressed || state.isRecording) return '#FF6B6B';
    if (!isReady) return '#A8A8A8';
    return '#4ECDC4';
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.titleContainer}>
          <Text style={styles.title}>Walkie-Talkie</Text>
          <Text style={styles.teamName}>{teamName || ''}</Text>
        </View>
        <Pressable onPress={onClose} style={styles.closeButton}>
          <Ionicons name="close" size={24} color="#666" />
        </Pressable>
      </View>

      {/* Status */}
      <View style={styles.statusContainer}>
        <View style={[styles.statusDot, { backgroundColor: getStatusColor() }]} />
        <Text style={styles.statusText}>{getStatusText()}</Text>
      </View>

      {/* Voice Pitch Indicator */}
      <View style={styles.pitchIndicatorContainer}>
        <VoicePitchIndicator 
          isActive={state.isPlayingMessage || state.isRecording}
          audioLevel={state.audioLevel}
          barCount={7}
          height={25}
          color={state.isPlayingMessage ? '#9B59B6' : state.isRecording ? '#FF6B6B' : '#4ECDC4'}
        />
      </View>

      {/* Message Count */}
      <View style={styles.messageCountContainer}>
        <Text style={styles.messageCountText}>
          Messages: {state.messages.length} | Sent: {state.totalMessagesSent} | Received: {state.totalMessagesReceived}
        </Text>
      </View>

      {/* Push to Talk Button */}
      <View style={styles.buttonContainer}>
        <Animated.View
          style={[
            styles.animationContainer,
            {
              transform: [
                { scale: pulseAnim },
                {
                  rotate: rotateAnim.interpolate({
                    inputRange: [0, 1],
                    outputRange: ['0deg', '360deg'],
                  }),
                },
              ],
            },
          ]}
        >
          <Pressable
            onPressIn={handlePressIn}
            onPressOut={handlePressOut}
            style={[
              styles.talkButton,
              { backgroundColor: getButtonColor() },
              isPressed && styles.talkButtonPressed,
              state.isPlayingMessage && styles.talkButtonDisabled,
            ]}
            disabled={!isInitialized || state.isPlayingMessage}
          >
            <Ionicons 
              name={state.isPlayingMessage ? "volume-high" : "mic"} 
              size={60} 
              color="white" 
            />
            <Text style={styles.buttonText}>
              {state.isPlayingMessage 
                ? 'Listening...' 
                : isPressed 
                ? 'Recording...' 
                : 'Hold to Talk'
              }
            </Text>
          </Pressable>
        </Animated.View>
      </View>

      {/* Simple Instructions */}
      <Text style={styles.instructions}>
        Hold the button for at least 1 second to record
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: 'white',
    paddingHorizontal: 20,
    paddingVertical: 10,
    height: 300, // Compact height
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
    paddingBottom: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  titleContainer: {
    flex: 1,
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  teamName: {
    fontSize: 12,
    color: '#666',
    marginTop: 2,
  },
  closeButton: {
    padding: 5,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  pitchIndicatorContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
    paddingVertical: 2,
  },
  statusDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 8,
  },
  statusText: {
    fontSize: 16,
    color: '#666',
    fontWeight: '500',
  },
  messageCountContainer: {
    alignItems: 'center',
    marginBottom: 8,
    paddingHorizontal: 10,
  },
  messageCountText: {
    fontSize: 11,
    color: '#888',
    textAlign: 'center',
  },
  buttonContainer: {
    alignItems: 'center',
    marginBottom: 10,
  },
  animationContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  talkButton: {
    width: 120,
    height: 120,
    borderRadius: 60,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 4.65,
    elevation: 8,
  },
  talkButtonPressed: {
    transform: [{ scale: 0.95 }],
    shadowOpacity: 0.1,
    elevation: 4,
  },
  talkButtonDisabled: {
    opacity: 0.8,
  },
  buttonText: {
    color: 'white',
    fontSize: 12,
    fontWeight: 'bold',
    marginTop: 5,
    textAlign: 'center',
  },
  instructions: {
    textAlign: 'center',
    fontSize: 14,
    color: '#888',
    fontStyle: 'italic',
  },
});
