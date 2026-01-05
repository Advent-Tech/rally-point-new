import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { ChatMessage } from '../../services/MessagingService';
import { ManagedUser } from '../../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';
import UserRoleBadge from '../UserRoleBadge';

interface MessageBubbleProps {
  message: ChatMessage;
  isOwnMessage: boolean;
  showSenderName: boolean;
  teamMembers: ManagedUser[];
}

const MessageBubble: React.FC<MessageBubbleProps> = ({
  message,
  isOwnMessage,
  showSenderName,
  teamMembers
}) => {
  const formatTime = (date: Date) => {
    return date.toLocaleTimeString([], { 
      hour: '2-digit', 
      minute: '2-digit',
      hour12: true 
    });
  };

  const getSenderInfo = () => {
    if (isOwnMessage) {
      return { name: 'You', role: message.senderRole };
    }
    
    const sender = teamMembers.find(member => member.uid === message.senderId);
    return {
      name: sender?.displayName || message.senderName || 'Unknown',
      role: sender?.role || message.senderRole || 'worker'
    };
  };

  const getStatusIcon = () => {
    switch (message.status) {
      case 'sending':
        return <MaterialIcons name="schedule" size={12} color={COLORS.text.secondary} />;
      case 'sent':
        return <MaterialIcons name="check" size={12} color={COLORS.text.secondary} />;
      case 'delivered':
        return <MaterialIcons name="done-all" size={12} color={COLORS.text.secondary} />;
      case 'read':
        return <MaterialIcons name="done-all" size={12} color={COLORS.primary} />;
      default:
        return null;
    }
  };

  const senderInfo = getSenderInfo();

  return (
    <View style={[
      styles.messageContainer,
      isOwnMessage ? styles.ownMessageContainer : styles.otherMessageContainer
    ]}>
      {/* Sender Name (for group chats) */}
      {showSenderName && !isOwnMessage && (
        <View style={styles.senderHeader}>
          <Text style={styles.senderName}>{senderInfo.name}</Text>
          <UserRoleBadge role={senderInfo.role as any} size="small" />
        </View>
      )}

      {/* Message Bubble */}
      <View style={[
        styles.messageBubble,
        isOwnMessage ? styles.ownMessageBubble : styles.otherMessageBubble
      ]}>
        {/* Message Content */}
        <Text style={[
          styles.messageText,
          isOwnMessage ? styles.ownMessageText : styles.otherMessageText
        ]}>
          {message.content}
        </Text>

        {/* Message Footer */}
        <View style={styles.messageFooter}>
          <Text style={[
            styles.timeText,
            isOwnMessage ? styles.ownTimeText : styles.otherTimeText
          ]}>
            {formatTime(message.timestamp)}
          </Text>
          
          {/* Status Icon (only for own messages) */}
          {isOwnMessage && (
            <View style={styles.statusIcon}>
              {getStatusIcon()}
            </View>
          )}
        </View>

        {/* Read By Indicator (for group messages) */}
        {!isOwnMessage && message.readBy && message.readBy.length > 1 && (
          <View style={styles.readByContainer}>
            <MaterialIcons name="visibility" size={10} color={COLORS.text.secondary} />
            <Text style={styles.readByText}>
              Read by {message.readBy.length - 1} {message.readBy.length === 2 ? 'person' : 'people'}
            </Text>
          </View>
        )}
      </View>

      {/* Message Reactions (placeholder for future feature) */}
      {(message as any).reactions && (message as any).reactions.length > 0 && (
        <View style={styles.reactionsContainer}>
          {/* Reactions implementation can be added here */}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  messageContainer: {
    marginVertical: SPACING.xs,
    paddingHorizontal: SPACING.sm,
  },
  ownMessageContainer: {
    alignItems: 'flex-end',
  },
  otherMessageContainer: {
    alignItems: 'flex-start',
  },
  senderHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
    paddingHorizontal: SPACING.sm,
  },
  senderName: {
    fontSize: TYPOGRAPHY.sizes.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.secondary,
    marginRight: SPACING.xs,
  },
  messageBubble: {
    maxWidth: '80%',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.lg,
    position: 'relative',
  },
  ownMessageBubble: {
    backgroundColor: COLORS.primary,
    borderBottomRightRadius: RADIUS.sm,
  },
  otherMessageBubble: {
    backgroundColor: COLORS.background.secondary,
    borderBottomLeftRadius: RADIUS.sm,
    borderWidth: 1,
    borderColor: COLORS.border.light,
  },
  messageText: {
    fontSize: TYPOGRAPHY.sizes.md,
    lineHeight: 20,
    marginBottom: SPACING.xs,
  },
  ownMessageText: {
    color: COLORS.background.primary,
  },
  otherMessageText: {
    color: COLORS.text.primary,
  },
  messageFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
  },
  timeText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  ownTimeText: {
    color: COLORS.background.primary + 'CC', // 80% opacity
  },
  otherTimeText: {
    color: COLORS.text.secondary,
  },
  statusIcon: {
    marginLeft: SPACING.xs,
  },
  readByContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: SPACING.xs,
    paddingTop: SPACING.xs,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light + '50', // 30% opacity
  },
  readByText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
  reactionsContainer: {
    flexDirection: 'row',
    marginTop: SPACING.xs,
    paddingHorizontal: SPACING.sm,
  },
});

export default MessageBubble;
