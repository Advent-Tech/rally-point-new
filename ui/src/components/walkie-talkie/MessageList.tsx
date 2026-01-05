/**
 * MessageList Component
 * Displays list of voice messages with playback controls
 */

import React, { useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  Pressable,
  StyleSheet,
  Alert,
} from 'react-native';
import { VoiceMessage } from './types';
import { useWalkieTalkie } from './useWalkieTalkie';

interface MessageListProps {
  style?: any;
  maxHeight?: number;
  showTimestamps?: boolean;
  onMessagePress?: (message: VoiceMessage) => void;
}

interface MessageItemProps {
  message: VoiceMessage;
  isPlaying: boolean;
  showTimestamp: boolean;
  onPress: (message: VoiceMessage) => void;
}

function MessageItem({ 
  message, 
  isPlaying, 
  showTimestamp, 
  onPress 
}: MessageItemProps) {
  const formatDuration = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const formatTime = (date: Date): string => {
    return date.toLocaleTimeString([], { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  };

  return (
    <Pressable
      style={[
        styles.messageItem,
        message.isOwn ? styles.ownMessage : styles.otherMessage,
        isPlaying && styles.playingMessage,
      ]}
      onPress={() => onPress(message)}
    >
      <View style={styles.messageHeader}>
        <Text style={[
          styles.senderName,
          message.isOwn && styles.ownSenderName
        ]}>
          {message.isOwn ? 'You' : message.senderName}
        </Text>
        
        {showTimestamp && (
          <Text style={styles.timestamp}>
            {formatTime(message.timestamp)}
          </Text>
        )}
      </View>
      
      <View style={styles.messageContent}>
        <View style={styles.playButton}>
          <Text style={styles.playIcon}>
            {isPlaying ? '⏸️' : '▶️'}
          </Text>
        </View>
        
        <View style={styles.audioInfo}>
          <Text style={styles.duration}>
            {formatDuration(message.duration)}
          </Text>
          
          {/* Simple waveform representation */}
          <View style={styles.waveform}>
            {Array.from({ length: 20 }, (_, i) => (
              <View
                key={i}
                style={[
                  styles.waveformBar,
                  {
                    height: Math.random() * 20 + 5,
                    backgroundColor: isPlaying 
                      ? '#4CAF50' 
                      : message.isOwn 
                        ? '#E3F2FD' 
                        : '#F5F5F5'
                  }
                ]}
              />
            ))}
          </View>
        </View>
      </View>
    </Pressable>
  );
}

export function MessageList({
  style,
  maxHeight = 300,
  showTimestamps = true,
  onMessagePress,
}: MessageListProps) {
  const { state, playMessage } = useWalkieTalkie();

  const handleMessagePress = useCallback(async (message: VoiceMessage) => {
    try {
      onMessagePress?.(message);
      await playMessage(message.id);
    } catch (error) {
      console.error('Failed to play message:', error);
      Alert.alert(
        'Playback Failed',
        'Failed to play voice message. Please try again.',
        [{ text: 'OK' }]
      );
    }
  }, [playMessage, onMessagePress]);

  const renderMessage = useCallback(({ item }: { item: VoiceMessage }) => (
    <MessageItem
      message={item}
      isPlaying={state.audioState === 'playing'}
      showTimestamp={showTimestamps}
      onPress={handleMessagePress}
    />
  ), [state.audioState, showTimestamps, handleMessagePress]);

  const keyExtractor = useCallback((item: VoiceMessage) => item.id, []);

  if (state.messages.length === 0) {
    return (
      <View style={[styles.container, style, { maxHeight }]}>
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>
            No voice messages yet
          </Text>
          <Text style={styles.emptySubtext}>
            Hold the button to send your first message
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.container, style, { maxHeight }]}>
      <View style={styles.header}>
        <Text style={styles.headerText}>
          Voice Messages ({state.messages.length})
        </Text>
        
        {state.unreadCount > 0 && (
          <View style={styles.unreadBadge}>
            <Text style={styles.unreadText}>
              {state.unreadCount}
            </Text>
          </View>
        )}
      </View>
      
      <FlatList
        data={state.messages}
        renderItem={renderMessage}
        keyExtractor={keyExtractor}
        style={styles.list}
        showsVerticalScrollIndicator={false}
        inverted // Show newest messages at bottom
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FAFAFA',
    borderRadius: 8,
    overflow: 'hidden',
  },
  
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#F5F5F5',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  
  headerText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
  },
  
  unreadBadge: {
    backgroundColor: '#F44336',
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  
  unreadText: {
    color: 'white',
    fontSize: 12,
    fontWeight: 'bold',
  },
  
  list: {
    flex: 1,
  },
  
  messageItem: {
    margin: 8,
    padding: 12,
    borderRadius: 12,
    elevation: 1,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  
  ownMessage: {
    backgroundColor: '#E3F2FD',
    marginLeft: 40,
    alignSelf: 'flex-end',
  },
  
  otherMessage: {
    backgroundColor: 'white',
    marginRight: 40,
    alignSelf: 'flex-start',
  },
  
  playingMessage: {
    borderWidth: 2,
    borderColor: '#4CAF50',
  },
  
  messageHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  
  senderName: {
    fontSize: 12,
    fontWeight: '600',
    color: '#666',
  },
  
  ownSenderName: {
    color: '#1976D2',
  },
  
  timestamp: {
    fontSize: 10,
    color: '#999',
  },
  
  messageContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  
  playButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#4CAF50',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  
  playIcon: {
    fontSize: 16,
  },
  
  audioInfo: {
    flex: 1,
  },
  
  duration: {
    fontSize: 12,
    fontWeight: '500',
    color: '#333',
    marginBottom: 4,
  },
  
  waveform: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    height: 25,
  },
  
  waveformBar: {
    width: 2,
    marginRight: 1,
    borderRadius: 1,
  },
  
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 40,
  },
  
  emptyText: {
    fontSize: 16,
    fontWeight: '500',
    color: '#666',
    marginBottom: 8,
  },
  
  emptySubtext: {
    fontSize: 12,
    color: '#999',
    textAlign: 'center',
  },
});
