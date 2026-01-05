/**
 * Enhanced Walkie-Talkie Panel
 * Full-featured interface with:
 * - Push to talk button
 * - Message history display
 * - Current speaker indicator
 * - Notification sounds
 * - Connection status
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
  FlatList,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Audio } from 'expo-av';
import { useWalkieTalkie } from './useWalkieTalkie';
import { WalkieTalkieConfig, VoiceMessage } from './types';
import { VoicePitchIndicator } from './VoicePitchIndicator';

interface EnhancedWalkieTalkiePanelProps {
  teamId: string;
  userId: string;
  userName: string;
  teamName?: string;
  onClose: () => void;
}

const { width, height } = Dimensions.get('window');

// Notification sound for incoming messages
let notificationSound: Audio.Sound | null = null;

export function EnhancedWalkieTalkiePanel({
  teamId,
  userId,
  userName,
  teamName,
  onClose,
}: EnhancedWalkieTalkiePanelProps) {
  const {
    state,
    initialize,
    startRecording,
    stopRecording,
    playMessage,
    clearError,
    hasError,
    isReady,
    isConnected,
  } = useWalkieTalkie();

  const [isPressed, setIsPressed] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);
  const [shortPressWarning, setShortPressWarning] = useState(false);
  const [showHistory, setShowHistory] = useState(true);

  // Track previous message count for notification
  const prevMessageCount = useRef(0);

  // Track press start time for minimum duration check
  const pressStartTime = useRef<number | null>(null);
  const MIN_PRESS_DURATION_MS = 1000;

  // Animation for listening/recording feedback
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const speakerOpacity = useRef(new Animated.Value(0)).current;

  // Load notification sound
  useEffect(() => {
    loadNotificationSound();
    return () => {
      if (notificationSound) {
        notificationSound.unloadAsync();
      }
    };
  }, []);

  const loadNotificationSound = async () => {
    // Notification sound is optional - use vibration as fallback
    // To add a custom sound, place walkie-beep.mp3 in src/assets/sounds/
    // and uncomment the code below:
    /*
    try {
      const { sound } = await Audio.Sound.createAsync(
        require('../../assets/sounds/walkie-beep.mp3'),
        { shouldPlay: false, volume: 0.5 }
      );
      notificationSound = sound;
    } catch (error) {
      console.log('Could not load notification sound:', error);
    }
    */
  };

  const playNotificationSound = async () => {
    try {
      if (notificationSound) {
        await notificationSound.replayAsync();
      } else {
        // Fallback: vibration
        Vibration.vibrate([0, 100, 50, 100]);
      }
    } catch (error) {
      console.log('Could not play notification:', error);
      Vibration.vibrate(100);
    }
  };

  // Play notification when new message arrives from others
  useEffect(() => {
    const currentCount = state.messages.length;
    if (currentCount > prevMessageCount.current && isInitialized) {
      const latestMessage = state.messages[currentCount - 1];
      if (latestMessage && !latestMessage.isOwn) {
        playNotificationSound();
      }
    }
    prevMessageCount.current = currentCount;
  }, [state.messages.length, isInitialized]);

  // Initialize on mount
  useEffect(() => {
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

    initialize(config)
      .then(() => {
        setIsInitialized(true);
      })
      .catch(error => {
        console.error('Initialization failed:', error);
        setIsInitialized(true); // Allow usage anyway
      });
  }, [teamId, userId, userName, initialize]);

  // Animate speaker indicator when playing message
  useEffect(() => {
    if (state.isPlayingMessage) {
      // Pulse animation for speaker
      const animation = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, { toValue: 1.15, duration: 500, useNativeDriver: true }),
          Animated.timing(pulseAnim, { toValue: 1, duration: 500, useNativeDriver: true }),
        ])
      );
      Animated.timing(speakerOpacity, { toValue: 1, duration: 300, useNativeDriver: true }).start();
      animation.start();
      return () => animation.stop();
    } else {
      pulseAnim.setValue(1);
      Animated.timing(speakerOpacity, { toValue: 0, duration: 200, useNativeDriver: true }).start();
    }
  }, [state.isPlayingMessage]);

  const handlePressIn = useCallback(() => {
    if (!isInitialized || state.isPlayingMessage) return;
    if (hasError) clearError();
    setShortPressWarning(false);
    pressStartTime.current = Date.now();
    setIsPressed(true);
    Vibration.vibrate(50);
    startRecording();
  }, [isInitialized, state.isPlayingMessage, hasError, clearError, startRecording]);

  const handlePressOut = useCallback(() => {
    if (!isPressed) return;
    setIsPressed(false);

    const pressDuration = pressStartTime.current ? Date.now() - pressStartTime.current : 0;
    pressStartTime.current = null;

    if (pressDuration < MIN_PRESS_DURATION_MS) {
      Vibration.vibrate([0, 100, 50, 100]);
      setShortPressWarning(true);
      setTimeout(() => setShortPressWarning(false), 2000);
      stopRecording();
      return;
    }

    Vibration.vibrate(100);
    stopRecording();
  }, [isPressed, stopRecording]);

  const getStatusText = (): string => {
    if (!isInitialized) return 'Initializing...';
    if (shortPressWarning) return 'Hold longer (1 sec min)';
    if (hasError) return 'Tap to retry';
    if (state.isPlayingMessage) return `Listening to ${state.currentPlayingSender || 'teammate'}...`;
    if (state.isRecording) return 'Recording...';
    if (state.isProcessing) return 'Sending...';
    if (isReady) return 'Ready';
    return 'Connecting...';
  };

  const getStatusColor = (): string => {
    if (shortPressWarning) return '#FFA500';
    if (hasError) return '#FF6B6B';
    if (state.isPlayingMessage) return '#9B59B6';
    if (state.isRecording) return '#FF6B6B';
    if (state.isProcessing) return '#FFE66D';
    if (isReady) return '#4ECDC4';
    return '#A8A8A8';
  };

  const getButtonColor = (): string => {
    if (hasError) return '#FF6B6B';
    if (state.isPlayingMessage) return '#9B59B6';
    if (isPressed || state.isRecording) return '#FF6B6B';
    if (!isReady) return '#A8A8A8';
    return '#4ECDC4';
  };

  const formatTime = (date: Date): string => {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const formatDuration = (seconds: number): string => {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const renderMessageItem = ({ item }: { item: VoiceMessage }) => (
    <Pressable
      style={[
        styles.messageItem,
        item.isOwn ? styles.ownMessage : styles.otherMessage,
      ]}
      onPress={() => playMessage(item.id)}
    >
      <View style={styles.messageHeader}>
        <View style={styles.senderInfo}>
          <Ionicons
            name={item.isOwn ? 'mic' : 'volume-high'}
            size={14}
            color={item.isOwn ? '#4ECDC4' : '#9B59B6'}
          />
          <Text style={[styles.senderName, item.isOwn && styles.ownSenderName]}>
            {item.isOwn ? 'You' : item.senderName}
          </Text>
        </View>
        <Text style={styles.messageTime}>{formatTime(new Date(item.timestamp))}</Text>
      </View>
      <View style={styles.messageContent}>
        <Ionicons name="play-circle" size={24} color={item.isOwn ? '#4ECDC4' : '#9B59B6'} />
        <Text style={styles.messageDuration}>{formatDuration(item.duration || 0)}</Text>
      </View>
    </Pressable>
  );

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.titleContainer}>
          <Text style={styles.title}>Walkie-Talkie</Text>
          <View style={styles.connectionBadge}>
            <View style={[styles.connectionDot, { backgroundColor: isConnected ? '#4ECDC4' : '#FF6B6B' }]} />
            <Text style={styles.teamName}>{teamName || (isConnected ? 'Connected' : 'Offline')}</Text>
          </View>
        </View>
        <View style={styles.headerActions}>
          <Pressable
            onPress={() => setShowHistory(!showHistory)}
            style={styles.historyToggle}
          >
            <Ionicons
              name={showHistory ? 'chatbubbles' : 'chatbubbles-outline'}
              size={22}
              color="#666"
            />
          </Pressable>
          <Pressable onPress={onClose} style={styles.closeButton}>
            <Ionicons name="close" size={24} color="#666" />
          </Pressable>
        </View>
      </View>

      {/* Current Speaker Banner (when someone is speaking) */}
      <Animated.View
        style={[
          styles.speakerBanner,
          { opacity: speakerOpacity, transform: [{ scale: pulseAnim }] },
        ]}
        pointerEvents={state.isPlayingMessage ? 'auto' : 'none'}
      >
        <Ionicons name="volume-high" size={24} color="white" />
        <Text style={styles.speakerBannerText}>
          {state.currentPlayingSender || 'Teammate'} is speaking...
        </Text>
      </Animated.View>

      {/* Message History */}
      {showHistory && (
        <View style={styles.historyContainer}>
          {state.messages.length === 0 ? (
            <View style={styles.emptyHistory}>
              <Ionicons name="chatbubble-ellipses-outline" size={40} color="#CCC" />
              <Text style={styles.emptyHistoryText}>No messages yet</Text>
              <Text style={styles.emptyHistorySubtext}>Hold the button to send a voice message</Text>
            </View>
          ) : (
            <FlatList
              data={[...state.messages].reverse().slice(0, 10)}
              renderItem={renderMessageItem}
              keyExtractor={(item) => item.id}
              showsVerticalScrollIndicator={false}
              contentContainerStyle={styles.messageList}
            />
          )}
        </View>
      )}

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
          barCount={9}
          height={30}
          color={state.isPlayingMessage ? '#9B59B6' : state.isRecording ? '#FF6B6B' : '#4ECDC4'}
        />
      </View>

      {/* Push to Talk Button */}
      <View style={styles.buttonContainer}>
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
            name={state.isPlayingMessage ? 'volume-high' : 'mic'}
            size={50}
            color="white"
          />
          <Text style={styles.buttonText}>
            {state.isPlayingMessage
              ? 'Listening...'
              : isPressed
              ? 'Recording...'
              : 'Hold to Talk'}
          </Text>
        </Pressable>
      </View>

      {/* Stats Footer */}
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          Sent: {state.totalMessagesSent} | Received: {state.totalMessagesReceived}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: 'white',
    paddingHorizontal: 16,
    paddingVertical: 12,
    height: height * 0.65, // Taller for history
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingBottom: 10,
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
  connectionBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
  connectionDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 6,
  },
  teamName: {
    fontSize: 12,
    color: '#666',
  },
  headerActions: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  historyToggle: {
    padding: 6,
    marginRight: 8,
  },
  closeButton: {
    padding: 5,
  },
  speakerBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#9B59B6',
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 10,
    marginTop: 10,
  },
  speakerBannerText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 10,
  },
  historyContainer: {
    flex: 1,
    marginTop: 10,
    maxHeight: height * 0.25,
  },
  emptyHistory: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 20,
  },
  emptyHistoryText: {
    fontSize: 14,
    color: '#999',
    marginTop: 8,
  },
  emptyHistorySubtext: {
    fontSize: 12,
    color: '#BBB',
    marginTop: 4,
  },
  messageList: {
    paddingVertical: 5,
  },
  messageItem: {
    padding: 10,
    borderRadius: 12,
    marginBottom: 8,
  },
  ownMessage: {
    backgroundColor: '#E8F8F5',
    marginLeft: 40,
  },
  otherMessage: {
    backgroundColor: '#F5E8F8',
    marginRight: 40,
  },
  messageHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  senderInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  senderName: {
    fontSize: 12,
    fontWeight: '600',
    color: '#9B59B6',
    marginLeft: 4,
  },
  ownSenderName: {
    color: '#4ECDC4',
  },
  messageTime: {
    fontSize: 10,
    color: '#999',
  },
  messageContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  messageDuration: {
    fontSize: 12,
    color: '#666',
    marginLeft: 8,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 10,
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 8,
  },
  statusText: {
    fontSize: 14,
    color: '#666',
    fontWeight: '500',
  },
  pitchIndicatorContainer: {
    alignItems: 'center',
    marginVertical: 8,
  },
  buttonContainer: {
    alignItems: 'center',
    marginVertical: 10,
  },
  talkButton: {
    width: 110,
    height: 110,
    borderRadius: 55,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 5,
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
    fontSize: 11,
    fontWeight: 'bold',
    marginTop: 4,
    textAlign: 'center',
  },
  footer: {
    alignItems: 'center',
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#F0F0F0',
  },
  footerText: {
    fontSize: 11,
    color: '#AAA',
  },
});

export default EnhancedWalkieTalkiePanel;
