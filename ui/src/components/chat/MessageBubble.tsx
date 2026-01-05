import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { ChatMessage } from '../../services/MessagingService';

interface MessageBubbleProps {
  message: ChatMessage;
  isCurrentUser: boolean;
  showSenderName?: boolean;
  onLongPress?: (message: ChatMessage) => void;
  onPress?: (message: ChatMessage) => void;
}

const MessageBubble: React.FC<MessageBubbleProps> = ({
  message,
  isCurrentUser,
  showSenderName = false,
  onLongPress,
  onPress,
}) => {
  const formatTime = (date: Date) => {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const getStatusIcon = () => {
    switch (message.status) {
      case 'sending':
        return '⏳';
      case 'sent':
        return '✓';
      case 'delivered':
        return '✓✓';
      case 'read':
        return '✓✓';
      default:
        return '';
    }
  };

  return (
    <View style={[
      styles.messageContainer,
      isCurrentUser ? styles.currentUserContainer : styles.otherUserContainer
    ]}>
      {showSenderName && !isCurrentUser && (
        <Text style={styles.senderName}>{message.senderName}</Text>
      )}
      
      <TouchableOpacity
        style={[
          styles.messageBubble,
          isCurrentUser ? styles.currentUserBubble : styles.otherUserBubble
        ]}
        onPress={() => onPress?.(message)}
        onLongPress={() => onLongPress?.(message)}
        activeOpacity={0.7}
      >
        <Text style={[
          styles.messageText,
          isCurrentUser ? styles.currentUserText : styles.otherUserText
        ]}>
          {message.content}
        </Text>
        
        <View style={styles.messageFooter}>
          <Text style={[
            styles.timeText,
            isCurrentUser ? styles.currentUserTimeText : styles.otherUserTimeText
          ]}>
            {formatTime(message.timestamp)}
            {message.editedAt && ' (edited)'}
          </Text>
          
          {isCurrentUser && (
            <Text style={[
              styles.statusText,
              message.status === 'read' ? styles.readStatus : styles.unreadStatus
            ]}>
              {getStatusIcon()}
            </Text>
          )}
        </View>
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  messageContainer: {
    marginVertical: 2,
    paddingHorizontal: 16,
  },
  currentUserContainer: {
    alignItems: 'flex-end',
  },
  otherUserContainer: {
    alignItems: 'flex-start',
  },
  senderName: {
    fontSize: 12,
    color: '#666',
    marginBottom: 4,
    marginLeft: 12,
    fontWeight: '500',
  },
  messageBubble: {
    maxWidth: '80%',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    elevation: 1,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  currentUserBubble: {
    backgroundColor: '#007AFF',
    borderBottomRightRadius: 6,
  },
  otherUserBubble: {
    backgroundColor: '#F0F0F0',
    borderBottomLeftRadius: 6,
  },
  messageText: {
    fontSize: 16,
    lineHeight: 20,
  },
  currentUserText: {
    color: '#FFFFFF',
  },
  otherUserText: {
    color: '#000000',
  },
  messageFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    marginTop: 4,
  },
  timeText: {
    fontSize: 11,
    marginRight: 4,
  },
  currentUserTimeText: {
    color: 'rgba(255, 255, 255, 0.7)',
  },
  otherUserTimeText: {
    color: '#666',
  },
  statusText: {
    fontSize: 12,
    fontWeight: 'bold',
  },
  readStatus: {
    color: 'rgba(255, 255, 255, 0.8)',
  },
  unreadStatus: {
    color: 'rgba(255, 255, 255, 0.6)',
  },
});

export default MessageBubble;
