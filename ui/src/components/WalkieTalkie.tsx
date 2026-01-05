import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Platform,
  Animated,
  PanResponder,
  Vibration,
} from 'react-native';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { Audio } from 'expo-av';
import { useAuth } from '../contexts/AuthContext';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface WalkieTalkieProps {
  teamId?: string;
  onMessageSent?: (audioUri: string, duration: number) => void;
  onMessageReceived?: (message: any) => void;
  style?: any;
}

interface AudioMessage {
  id: string;
  senderId: string;
  senderName: string;
  audioUri: string;
  duration: number;
  timestamp: number;
  teamId: string;
}

const WalkieTalkie: React.FC<WalkieTalkieProps> = ({
  teamId,
  onMessageSent,
  onMessageReceived,
  style,
}) => {
  const { user } = useAuth();
  const [isRecording, setIsRecording] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [sound, setSound] = useState<Audio.Sound | null>(null);
  const [recordingDuration, setRecordingDuration] = useState(0);
  const [isConnected, setIsConnected] = useState(true);
  const [lastMessage, setLastMessage] = useState<AudioMessage | null>(null);
  
  // Animation values
  const scaleAnim = useRef(new Animated.Value(1)).current;
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const recordingTimer = useRef<NodeJS.Timeout | null>(null);

  // Initialize audio
  useEffect(() => {
    initializeAudio();
    return () => {
      cleanup();
    };
  }, []);

  const initializeAudio = async () => {
    try {
      await Audio.requestPermissionsAsync();
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
        playThroughEarpieceAndroid: false,
        staysActiveInBackground: false,
      });
    } catch (error) {
      console.error('Failed to initialize audio:', error);
    }
  };

  const cleanup = async () => {
    if (recording) {
      await recording.stopAndUnloadAsync();
    }
    if (sound) {
      await sound.unloadAsync();
    }
    if (recordingTimer.current) {
      clearInterval(recordingTimer.current);
    }
  };

  // Pan responder for push-to-talk functionality
  const panResponder = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: () => false,
    
    onPanResponderGrant: () => {
      startRecording();
    },
    
    onPanResponderRelease: () => {
      stopRecording();
    },
    
    onPanResponderTerminate: () => {
      stopRecording();
    },
  });

  const startRecording = async () => {
    try {
      if (recording) return;

      console.log('🎤 Starting walkie talkie recording...');
      setIsRecording(true);
      setRecordingDuration(0);

      // Haptic feedback
      if (Platform.OS !== 'web') {
        Vibration.vibrate(50);
      }

      // Start pulse animation
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.2,
            duration: 500,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 500,
            useNativeDriver: true,
          }),
        ])
      ).start();

      // Scale animation
      Animated.spring(scaleAnim, {
        toValue: 1.1,
        useNativeDriver: true,
      }).start();

      const { recording: newRecording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );
      
      setRecording(newRecording);

      // Start duration timer
      recordingTimer.current = setInterval(() => {
        setRecordingDuration(prev => prev + 0.1);
      }, 100);

    } catch (error) {
      console.error('Failed to start recording:', error);
      Alert.alert('Recording Error', 'Failed to start recording. Please check microphone permissions.');
      setIsRecording(false);
    }
  };

  const stopRecording = async () => {
    try {
      if (!recording) return;

      console.log('🛑 Stopping walkie talkie recording...');
      setIsRecording(false);

      // Stop animations
      pulseAnim.stopAnimation();
      Animated.spring(scaleAnim, {
        toValue: 1,
        useNativeDriver: true,
      }).start();

      // Clear timer
      if (recordingTimer.current) {
        clearInterval(recordingTimer.current);
        recordingTimer.current = null;
      }

      // Stop recording
      await recording.stopAndUnloadAsync();
      const uri = recording.getURI();
      setRecording(null);

      if (uri && recordingDuration > 0.5) {
        // Only send if recording is longer than 0.5 seconds
        const audioMessage: AudioMessage = {
          id: Date.now().toString(),
          senderId: user?.uid || user?.email || 'unknown',
          senderName: user?.displayName || user?.email || 'Worker',
          audioUri: uri,
          duration: recordingDuration,
          timestamp: Date.now(),
          teamId: teamId || 'default',
        };

        setLastMessage(audioMessage);
        onMessageSent?.(uri, recordingDuration);

        // Haptic feedback for successful send
        if (Platform.OS !== 'web') {
          Vibration.vibrate([50, 100, 50]);
        }

        console.log('📡 Walkie talkie message sent:', {
          duration: recordingDuration.toFixed(1),
          sender: audioMessage.senderName,
        });
      } else {
        console.log('⚠️ Recording too short, not sending');
      }

      setRecordingDuration(0);
    } catch (error) {
      console.error('Failed to stop recording:', error);
      setIsRecording(false);
      setRecordingDuration(0);
    }
  };

  const playLastMessage = async () => {
    if (!lastMessage || isPlaying) return;

    try {
      setIsPlaying(true);
      console.log('🔊 Playing walkie talkie message...');

      const { sound: newSound } = await Audio.Sound.createAsync(
        { uri: lastMessage.audioUri },
        { shouldPlay: true }
      );

      setSound(newSound);

      newSound.setOnPlaybackStatusUpdate((status) => {
        if (status.isLoaded && status.didJustFinish) {
          setIsPlaying(false);
          newSound.unloadAsync();
          setSound(null);
        }
      });
    } catch (error) {
      console.error('Failed to play message:', error);
      setIsPlaying(false);
    }
  };

  const formatDuration = (duration: number): string => {
    return `${duration.toFixed(1)}s`;
  };

  return (
    <View style={[styles.container, style]}>
      {/* Connection Status */}
      <View style={styles.statusBar}>
        <View style={[styles.statusIndicator, { backgroundColor: isConnected ? COLORS.success : COLORS.error }]} />
        <Text style={styles.statusText}>
          {isConnected ? 'Walkie Talkie Ready' : 'Disconnected'}
        </Text>
        {isRecording && (
          <Text style={styles.recordingDuration}>
            {formatDuration(recordingDuration)}
          </Text>
        )}
      </View>

      {/* Main Walkie Talkie Button */}
      <View style={styles.buttonContainer}>
        <Animated.View
          style={[
            styles.walkieTalkieButton,
            {
              transform: [
                { scale: scaleAnim },
                { scale: isRecording ? pulseAnim : 1 },
              ],
            },
          ]}
          {...panResponder.panHandlers}
        >
          <TouchableOpacity
            style={[
              styles.pushToTalkButton,
              {
                backgroundColor: isRecording ? COLORS.error : COLORS.primary,
                borderColor: isRecording ? COLORS.error : COLORS.primary,
              },
            ]}
            activeOpacity={0.8}
            disabled={!isConnected}
          >
            <MaterialIcons
              name={isRecording ? 'mic' : 'mic-none'}
              size={32}
              color={COLORS.white}
            />
            
            {isRecording && (
              <View style={styles.recordingIndicator}>
                <View style={styles.recordingDot} />
              </View>
            )}
          </TouchableOpacity>
        </Animated.View>

        {/* Instruction Text */}
        <Text style={styles.instructionText}>
          {isRecording ? 'Release to Send' : 'Hold to Talk'}
        </Text>
      </View>

      {/* Last Message Playback */}
      {lastMessage && (
        <View style={styles.lastMessageContainer}>
          <TouchableOpacity
            style={styles.playButton}
            onPress={playLastMessage}
            disabled={isPlaying}
          >
            <Ionicons
              name={isPlaying ? 'volume-high' : 'play'}
              size={16}
              color={COLORS.primary}
            />
            <Text style={styles.playButtonText}>
              {isPlaying ? 'Playing...' : `Last: ${formatDuration(lastMessage.duration)}`}
            </Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Channel Info */}
      <View style={styles.channelInfo}>
        <Ionicons name="radio" size={14} color={COLORS.textSecondary} />
        <Text style={styles.channelText}>
          Channel: {teamId || 'Team'}
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    ...SHADOWS.md,
    minHeight: 160,
  },
  statusBar: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  statusIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: SPACING.xs,
  },
  statusText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textPrimary,
    fontWeight: TYPOGRAPHY.medium,
    flex: 1,
  },
  recordingDuration: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.error,
    fontWeight: TYPOGRAPHY.bold,
    backgroundColor: `${COLORS.error}20`,
    paddingHorizontal: SPACING.xs,
    paddingVertical: 2,
    borderRadius: RADIUS.sm,
  },
  buttonContainer: {
    alignItems: 'center',
    marginVertical: SPACING.md,
  },
  walkieTalkieButton: {
    marginBottom: SPACING.sm,
  },
  pushToTalkButton: {
    width: 80,
    height: 80,
    borderRadius: 40,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
    ...SHADOWS.lg,
    position: 'relative',
  },
  recordingIndicator: {
    position: 'absolute',
    top: -5,
    right: -5,
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: COLORS.error,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: COLORS.white,
  },
  recordingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.white,
  },
  instructionText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    fontWeight: TYPOGRAPHY.medium,
    textAlign: 'center',
  },
  lastMessageContainer: {
    marginTop: SPACING.sm,
    alignItems: 'center',
  },
  playButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: `${COLORS.primary}10`,
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: `${COLORS.primary}30`,
  },
  playButtonText: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.primary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.medium,
  },
  channelInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: SPACING.sm,
    paddingTop: SPACING.sm,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
  },
  channelText: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
});

export default WalkieTalkie;
