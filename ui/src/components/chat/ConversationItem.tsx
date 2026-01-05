import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Image } from 'react-native';
import { Conversation } from '../../services/MessagingService';

interface ConversationItemProps {
  conversation: Conversation;
  currentUserId: string;
  onPress: (conversation: Conversation) => void;
}

const ConversationItem: React.FC<ConversationItemProps> = ({
  conversation,
  currentUserId,
  onPress,
}) => {
  const getConversationTitle = () => {
    if (conversation.type === 'team') {
      return conversation.teamName ? `${conversation.teamName} Team` : 'Team Chat';
    } else if (conversation.type === 'group') {
      return conversation.groupName || 'Group Chat';
    } else {
      // For direct conversations, show the other participant's name
      const otherParticipant = conversation.participantDetails.find(
        p => p.userId !== currentUserId
      );
      return otherParticipant?.name || 'Unknown User';
    }
  };

  const getConversationSubtitle = () => {
    if (conversation.type === 'team') {
      return `${conversation.participants.length} team members`;
    } else if (conversation.type === 'group') {
      return `${conversation.participants.length} members`;
    } else {
      const otherParticipant = conversation.participantDetails.find(
        p => p.userId !== currentUserId
      );
      return otherParticipant?.role || '';
    }
  };

  const getLastMessagePreview = () => {
    if (!conversation.lastMessage) {
      return 'No messages yet';
    }

    const { content, senderId, senderName } = conversation.lastMessage;
    const isCurrentUserMessage = senderId === currentUserId;
    
    if ((conversation.type === 'group' || conversation.type === 'team') && !isCurrentUserMessage) {
      return `${senderName}: ${content}`;
    }
    
    return isCurrentUserMessage ? `You: ${content}` : content;
  };

  const formatTime = (date: Date) => {
    const now = new Date();
    const diffInHours = (now.getTime() - date.getTime()) / (1000 * 60 * 60);
    
    if (diffInHours < 24) {
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } else if (diffInHours < 168) { // 7 days
      return date.toLocaleDateString([], { weekday: 'short' });
    } else {
      return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
    }
  };

  const unreadCount = conversation.unreadCount[currentUserId] || 0;
  const hasUnread = unreadCount > 0;

  const getAvatarContent = () => {
    if (conversation.type === 'team') {
      return '🏢'; // Team building icon
    } else if (conversation.type === 'group') {
      return '👥';
    } else {
      const otherParticipant = conversation.participantDetails.find(
        p => p.userId !== currentUserId
      );
      return otherParticipant?.name?.charAt(0).toUpperCase() || '?';
    }
  };

  const isOnline = () => {
    if (conversation.type === 'group' || conversation.type === 'team') {
      return false; // Don't show online status for groups and teams
    }
    const otherParticipant = conversation.participantDetails.find(
      p => p.userId !== currentUserId
    );
    return otherParticipant?.isOnline || false;
  };

  return (
    <TouchableOpacity
      style={[styles.container, hasUnread && styles.unreadContainer]}
      onPress={() => onPress(conversation)}
      activeOpacity={0.7}
    >
      <View style={styles.avatarContainer}>
        <View style={[
          styles.avatar,
          conversation.type === 'group' || conversation.type === 'team' ? styles.groupAvatar : styles.directAvatar
        ]}>
          {conversation.type === 'direct' && (() => {
            const otherParticipant = conversation.participantDetails.find(
              p => p.userId !== currentUserId
            );
            return otherParticipant?.avatar ? (
              <Image
                source={{ uri: otherParticipant.avatar }}
                style={styles.avatarImage}
                resizeMode="cover"
              />
            ) : (
              <View style={styles.defaultDirectAvatar}>
                <MaterialIcons
                  name="person"
                  size={24}
                  color="#007AFF"
                />
              </View>
            );
          })()}
          {(conversation.type === 'group' || conversation.type === 'team') && (
            <Text style={styles.avatarText}>
              {getAvatarContent()}
            </Text>
          )}
        </View>
        
        {conversation.type === 'direct' && isOnline() && (
          <View style={styles.onlineIndicator} />
        )}
      </View>
      
      <View style={styles.contentContainer}>
        <View style={styles.headerRow}>
          <Text style={[styles.title, hasUnread && styles.unreadTitle]} numberOfLines={1}>
            {getConversationTitle()}
          </Text>
          <Text style={[styles.time, hasUnread && styles.unreadTime]}>
            {formatTime(conversation.lastMessageTime)}
          </Text>
        </View>
        
        <View style={styles.subtitleRow}>
          <Text style={styles.subtitle} numberOfLines={1}>
            {getConversationSubtitle()}
          </Text>
        </View>
        
        <View style={styles.messageRow}>
          <Text
            style={[styles.lastMessage, hasUnread && styles.unreadMessage]}
            numberOfLines={1}
          >
            {getLastMessagePreview()}
          </Text>
          
          {hasUnread && (
            <View style={styles.unreadBadge}>
              <Text style={styles.unreadBadgeText}>
                {unreadCount > 99 ? '99+' : unreadCount.toString()}
              </Text>
            </View>
          )}
        </View>
      </View>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  unreadContainer: {
    backgroundColor: '#F8F9FA',
  },
  avatarContainer: {
    position: 'relative',
    marginRight: 12,
  },
  avatar: {
    width: 50,
    height: 50,
    borderRadius: 25,
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden', // Ensure image stays within circular bounds
  },
  avatarImage: {
    width: 50,
    height: 50,
    borderRadius: 25,
  },
  directAvatar: {
    backgroundColor: '#007AFF',
  },
  defaultDirectAvatar: {
    backgroundColor: '#FFFFFF',
    width: 50,
    height: 50,
    borderRadius: 25,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  groupAvatar: {
    backgroundColor: '#34C759',
  },
  avatarText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
  onlineIndicator: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 14,
    height: 14,
    borderRadius: 7,
    backgroundColor: '#34C759',
    borderWidth: 2,
    borderColor: '#FFFFFF',
  },
  contentContainer: {
    flex: 1,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 2,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    color: '#000',
    flex: 1,
    marginRight: 8,
  },
  unreadTitle: {
    fontWeight: '700',
  },
  time: {
    fontSize: 12,
    color: '#666',
  },
  unreadTime: {
    color: '#007AFF',
    fontWeight: '600',
  },
  subtitleRow: {
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 12,
    color: '#666',
    textTransform: 'capitalize',
  },
  messageRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  lastMessage: {
    fontSize: 14,
    color: '#666',
    flex: 1,
    marginRight: 8,
  },
  unreadMessage: {
    color: '#000',
    fontWeight: '500',
  },
  unreadBadge: {
    backgroundColor: '#007AFF',
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 6,
  },
  unreadBadgeText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: 'bold',
  },
});

export default ConversationItem;
