/**
 * WalkieTalkiePanel Component
 * Complete walkie-talkie interface with button and message list
 */

import React, { useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
} from 'react-native';
import { WalkieTalkieButton } from './WalkieTalkieButton';
import { MessageList } from './MessageList';
import { WalkieTalkieConfig, VoiceMessage } from './types';
import { useWalkieTalkie } from './useWalkieTalkie';

interface WalkieTalkirPanelProps {
  teamId: string;
  userId: string;
  userName: string;
  style?: any;
  buttonSize?: 'small' | 'medium' | 'large';
  showMessages?: boolean;
  maxMessagesHeight?: number;
  autoPlay?: boolean;
  speakerMode?: boolean;
  onRecordingStart?: () => void;
  onRecordingStop?: () => void;
  onMessageReceived?: (message: VoiceMessage) => void;
  onError?: (error: any) => void;
}

export function WalkieTalkiePanel({
  teamId,
  userId,
  userName,
  style,
  buttonSize = 'large',
  showMessages = true,
  maxMessagesHeight = 300,
  autoPlay = true,
  speakerMode = true,
  onRecordingStart,
  onRecordingStop,
  onMessageReceived,
  onError,
}: WalkieTalkirPanelProps) {
  const { state } = useWalkieTalkie();

  // Create configuration object
  const config: WalkieTalkieConfig = useMemo(() => ({
    teamId,
    userId,
    userName,
    recording: {
      maxDuration: 60, // 60 seconds max
      quality: 'high',
      format: 'm4a',
      sampleRate: 44100,
      bitRate: 128000,
    },
    autoPlay,
    speakerMode,
    uploadTimeout: 30000, // 30 seconds
    retryAttempts: 3,
    vibrationEnabled: true,
    soundEnabled: true,
  }), [teamId, userId, userName, autoPlay, speakerMode]);

  // Statistics
  const stats = useMemo(() => ({
    totalMessages: state.messages.length,
    sentMessages: state.totalMessagesSent,
    receivedMessages: state.totalMessagesReceived,
    unreadMessages: state.unreadCount,
  }), [
    state.messages.length,
    state.totalMessagesSent,
    state.totalMessagesReceived,
    state.unreadCount,
  ]);

  return (
    <ScrollView 
      style={[styles.container, style]}
      contentContainerStyle={styles.contentContainer}
      showsVerticalScrollIndicator={false}
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Walkie-Talkie</Text>
        <Text style={styles.subtitle}>Team: {teamId}</Text>
      </View>

      {/* Statistics */}
      <View style={styles.statsContainer}>
        <View style={styles.statItem}>
          <Text style={styles.statValue}>{stats.totalMessages}</Text>
          <Text style={styles.statLabel}>Total</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statValue}>{stats.sentMessages}</Text>
          <Text style={styles.statLabel}>Sent</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statValue}>{stats.receivedMessages}</Text>
          <Text style={styles.statLabel}>Received</Text>
        </View>
        {stats.unreadMessages > 0 && (
          <View style={styles.statItem}>
            <Text style={[styles.statValue, styles.unreadValue]}>
              {stats.unreadMessages}
            </Text>
            <Text style={styles.statLabel}>Unread</Text>
          </View>
        )}
      </View>

      {/* Main Button */}
      <View style={styles.buttonContainer}>
        <WalkieTalkieButton
          config={config}
          size={buttonSize}
          onRecordingStart={onRecordingStart}
          onRecordingStop={onRecordingStop}
          onError={onError}
        />
      </View>

      {/* Instructions */}
      <View style={styles.instructionsContainer}>
        <Text style={styles.instructionsText}>
          Hold the button to record your voice message
        </Text>
        <Text style={styles.instructionsSubtext}>
          Release to send • Tap messages to play
        </Text>
      </View>

      {/* Messages List */}
      {showMessages && (
        <View style={styles.messagesContainer}>
          <MessageList
            maxHeight={maxMessagesHeight}
            onMessagePress={onMessageReceived}
          />
        </View>
      )}

      {/* Status Information */}
      <View style={styles.statusContainer}>
        <View style={styles.statusRow}>
          <Text style={styles.statusLabel}>Status:</Text>
          <Text style={[
            styles.statusValue,
            state.connectionState === 'connected' ? styles.connected : styles.disconnected
          ]}>
            {state.connectionState === 'connected' ? 'Connected' : 'Disconnected'}
          </Text>
        </View>
        
        <View style={styles.statusRow}>
          <Text style={styles.statusLabel}>State:</Text>
          <Text style={styles.statusValue}>
            {state.state.charAt(0).toUpperCase() + state.state.slice(1)}
          </Text>
        </View>
        
        {state.isUploading && (
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Upload:</Text>
            <Text style={styles.statusValue}>
              {state.uploadProgress}%
            </Text>
          </View>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8F9FA',
  },
  
  contentContainer: {
    padding: 20,
  },
  
  header: {
    alignItems: 'center',
    marginBottom: 20,
  },
  
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  
  subtitle: {
    fontSize: 14,
    color: '#666',
  },
  
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  
  statItem: {
    alignItems: 'center',
  },
  
  statValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  
  unreadValue: {
    color: '#F44336',
  },
  
  statLabel: {
    fontSize: 12,
    color: '#666',
    textTransform: 'uppercase',
  },
  
  buttonContainer: {
    alignItems: 'center',
    marginBottom: 20,
  },
  
  instructionsContainer: {
    alignItems: 'center',
    marginBottom: 24,
  },
  
  instructionsText: {
    fontSize: 16,
    color: '#333',
    textAlign: 'center',
    marginBottom: 4,
  },
  
  instructionsSubtext: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
  },
  
  messagesContainer: {
    marginBottom: 20,
  },
  
  statusContainer: {
    backgroundColor: 'white',
    borderRadius: 8,
    padding: 16,
    elevation: 1,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 1,
  },
  
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  
  statusLabel: {
    fontSize: 12,
    color: '#666',
    fontWeight: '500',
  },
  
  statusValue: {
    fontSize: 12,
    color: '#333',
    fontWeight: '600',
  },
  
  connected: {
    color: '#4CAF50',
  },
  
  disconnected: {
    color: '#F44336',
  },
});
