import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  Alert
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { MessagingService, Conversation } from '../../services/MessagingService';
import { ManagedUser } from '../../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../../constants/Colors';
import UserRoleBadge from '../UserRoleBadge';
import UserStatusIndicator from '../UserStatusIndicator';
import DirectChatView from './DirectChatView';

interface DirectMessagesViewProps {
  currentUser: any;
  teamMembers: ManagedUser[];
}

const DirectMessagesView: React.FC<DirectMessagesViewProps> = ({
  currentUser,
  teamMembers
}) => {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedConversation, setSelectedConversation] = useState<Conversation | null>(null);
  const [selectedMember, setSelectedMember] = useState<ManagedUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let unsubscribe: (() => void) | null = null;

    const loadDirectConversations = async () => {
      if (!currentUser?.uid) {
        console.warn('No current user available for loading conversations');
        setLoading(false);
        return;
      }

      try {
        setLoading(true);

        // Subscribe to user's direct conversations (team-scoped)
        unsubscribe = MessagingService.subscribeToUserConversations(
          currentUser.uid,
          (userConversations) => {
            try {
              // Filter for direct conversations only
              const directConversations = userConversations.filter(
                conv => conv.type === 'direct'
              );
              setConversations(directConversations);
              setLoading(false);
            } catch (filterError) {
              console.error('Error filtering conversations:', filterError);
              setConversations([]);
              setLoading(false);
            }
          }
        );
      } catch (error) {
        console.error('Error loading direct conversations:', error);
        Alert.alert('Error', 'Failed to load conversations');
        setLoading(false);
      }
    };

    if (currentUser) {
      loadDirectConversations();
    }

    // Cleanup function
    return () => {
      if (unsubscribe) {
        unsubscribe();
      }
    };
  }, [currentUser]);

  const startDirectMessage = async (member: ManagedUser) => {
    if (!currentUser?.uid || !member?.uid) {
      console.error('Invalid user data for starting direct message');
      Alert.alert('Error', 'Unable to start conversation - invalid user data');
      return;
    }

    if (currentUser.uid === member.uid) {
      Alert.alert('Error', 'You cannot start a conversation with yourself');
      return;
    }

    try {
      // Get or create direct conversation
      const conversationId = await MessagingService.getOrCreateDirectConversation(
        currentUser.uid,
        currentUser.displayName || currentUser.email?.split('@')[0] || 'Unknown',
        'worker', // This should be the actual user role
        member.uid,
        member.displayName || member.email?.split('@')[0] || 'Unknown User',
        member.role || 'worker'
      );

      if (!conversationId) {
        throw new Error('Failed to create or get conversation ID');
      }

      // Find the conversation object
      const conversation = conversations.find(conv => conv.id === conversationId) || {
        id: conversationId,
        type: 'direct' as const,
        participants: [currentUser.uid, member.uid],
        participantDetails: [
          {
            userId: currentUser.uid,
            name: currentUser.displayName || currentUser.email?.split('@')[0] || 'You',
            role: 'worker',
            isOnline: true,
            lastSeen: new Date(),
            joinedAt: new Date(),
          },
          {
            userId: member.uid,
            name: member.displayName || member.email?.split('@')[0] || 'Unknown User',
            role: member.role || 'worker',
            isOnline: member.isOnline || false,
            lastSeen: member.lastActiveAt || new Date(),
            joinedAt: new Date(),
          }
        ],
        unreadCount: {
          [currentUser.uid]: 0,
          [member.uid]: 0
        },
        createdAt: new Date(),
        updatedAt: new Date(),
        lastMessageTime: new Date(),
      };

      setSelectedConversation(conversation);
      setSelectedMember(member);
    } catch (error) {
      console.error('Error starting direct message:', error);
      Alert.alert('Error', 'Failed to start conversation. Please try again.');
    }
  };

  const getOtherParticipant = (conversation: Conversation) => {
    const otherParticipantDetail = conversation.participantDetails.find(
      p => p.userId !== currentUser.uid
    );
    
    if (otherParticipantDetail) {
      return {
        name: otherParticipantDetail.name,
        role: otherParticipantDetail.role,
        isOnline: otherParticipantDetail.isOnline,
        lastSeen: otherParticipantDetail.lastSeen,
      };
    }
    
    return {
      name: 'Unknown User',
      role: 'worker',
      isOnline: false,
      lastSeen: new Date(),
    };
  };

  const formatLastMessageTime = (date: Date | string | number | null | undefined) => {
    if (!date) return 'Unknown';

    try {
      // Convert various date formats to Date object
      let dateObj: Date;

      if (date instanceof Date) {
        dateObj = date;
      } else if (typeof date === 'string') {
        dateObj = new Date(date);
      } else if (typeof date === 'number') {
        dateObj = new Date(date);
      } else if (date && typeof date === 'object' && 'toDate' in date) {
        // Handle Firestore Timestamp
        dateObj = (date as any).toDate();
      } else {
        console.warn('Invalid date format in formatLastMessageTime:', date);
        return 'Unknown';
      }

      // Validate the date object
      if (isNaN(dateObj.getTime())) {
        console.warn('Invalid date object in formatLastMessageTime:', date);
        return 'Unknown';
      }

      const now = new Date();
      const diff = now.getTime() - dateObj.getTime();
      const minutes = Math.floor(diff / 60000);
      const hours = Math.floor(diff / 3600000);
      const days = Math.floor(diff / 86400000);

      if (minutes < 1) return 'Just now';
      if (minutes < 60) return `${minutes}m ago`;
      if (hours < 24) return `${hours}h ago`;
      if (days < 7) return `${days}d ago`;
      return dateObj.toLocaleDateString();
    } catch (error) {
      console.error('Error formatting last message time:', error, 'Date:', date);
      return 'Unknown';
    }
  };

  const renderConversationItem = ({ item }: { item: Conversation }) => {
    if (!item || !currentUser?.uid) {
      return null;
    }

    try {
      const otherParticipant = getOtherParticipant(item);
      const unreadCount = item.unreadCount?.[currentUser.uid] || 0;

      return (
        <TouchableOpacity
          style={styles.conversationItem}
          onPress={() => {
            try {
              setSelectedConversation(item);
              const member = teamMembers.find(m =>
                item.participants.includes(m.uid) && m.uid !== currentUser.uid
              );
              setSelectedMember(member || null);
            } catch (error) {
              console.error('Error selecting conversation:', error);
              Alert.alert('Error', 'Failed to open conversation');
            }
          }}
          activeOpacity={0.7}
        >
          <View style={styles.conversationContent}>
            <View style={styles.conversationHeader}>
              <View style={styles.participantInfo}>
                <Text style={styles.participantName}>{otherParticipant.name}</Text>
                <UserRoleBadge role={otherParticipant.role as any} size="small" />
              </View>
              <View style={styles.conversationMeta}>
                <UserStatusIndicator
                  isOnline={otherParticipant.isOnline}
                  lastActiveAt={otherParticipant.lastSeen}
                  size="small"
                />
                {item.lastMessageTime && (
                  <Text style={styles.timeText}>
                    {formatLastMessageTime(item.lastMessageTime)}
                  </Text>
                )}
              </View>
            </View>

            {item.lastMessage && (
              <Text style={styles.lastMessageText} numberOfLines={1}>
                {item.lastMessage.senderId === currentUser.uid ? 'You: ' : ''}
                {item.lastMessage.content}
              </Text>
            )}

            {unreadCount > 0 && (
              <View style={styles.unreadBadge}>
                <Text style={styles.unreadBadgeText}>{unreadCount}</Text>
              </View>
            )}
          </View>
        </TouchableOpacity>
      );
    } catch (error) {
      console.error('Error rendering conversation item:', error);
      return null;
    }
  };

  const renderTeamMemberItem = ({ item }: { item: ManagedUser }) => {
    if (!item || !item.uid) {
      return null;
    }

    try {
      return (
        <TouchableOpacity
          style={styles.memberItem}
          onPress={() => startDirectMessage(item)}
          activeOpacity={0.7}
        >
          <View style={styles.memberContent}>
            <View style={styles.memberInfo}>
              <Text style={styles.memberName}>
                {item.displayName || item.email?.split('@')[0] || 'Unknown User'}
              </Text>
              <UserRoleBadge role={item.role || 'worker'} size="small" />
            </View>
            <UserStatusIndicator
              isOnline={item.isOnline || false}
              lastActiveAt={item.lastActiveAt}
              size="small"
            />
          </View>
        </TouchableOpacity>
      );
    } catch (error) {
      console.error('Error rendering team member item:', error);
      return null;
    }
  };

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <MaterialIcons name="chat-bubble-outline" size={64} color={COLORS.text.secondary} />
      <Text style={styles.emptyStateText}>No Direct Messages</Text>
      <Text style={styles.emptyStateSubtext}>
        Start a conversation with your team members
      </Text>
    </View>
  );

  // Show chat view if conversation is selected
  if (selectedConversation && selectedMember) {
    return (
      <DirectChatView
        conversation={selectedConversation}
        otherUser={selectedMember}
        currentUser={currentUser}
        onBack={() => {
          setSelectedConversation(null);
          setSelectedMember(null);
        }}
      />
    );
  }

  // Show loading state
  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.loadingText}>Loading conversations...</Text>
      </View>
    );
  }

  // Show error state if no current user
  if (!currentUser) {
    return (
      <View style={styles.errorContainer}>
        <MaterialIcons name="error-outline" size={64} color={COLORS.text.secondary} />
        <Text style={styles.errorText}>Authentication Error</Text>
        <Text style={styles.errorSubtext}>Please log in again to access messaging</Text>
      </View>
    );
  }

  // Main view with conversations and team members
  return (
    <View style={styles.container}>
      <FlatList
        data={[]}
        ListHeaderComponent={() => (
          <View>
            {/* Existing Conversations */}
            {conversations.length > 0 && (
              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Recent Conversations</Text>
                {conversations.map((item) => (
                  <View key={item.id}>
                    {renderConversationItem({ item })}
                  </View>
                ))}
              </View>
            )}

            {/* Team Members */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>
                Team Members ({teamMembers.length})
              </Text>
              {teamMembers.length > 0 ? (
                teamMembers.map((item) => (
                  <View key={item.uid}>
                    {renderTeamMemberItem({ item })}
                  </View>
                ))
              ) : (
                renderEmptyState()
              )}
            </View>
          </View>
        )}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.surface,
  },
  listContent: {
    paddingBottom: SPACING.lg,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  loadingText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  errorText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    textAlign: 'center',
  },
  errorSubtext: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
    textAlign: 'center',
  },
  section: {
    flex: 1,
    paddingHorizontal: SPACING.md,
    paddingTop: SPACING.md,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  conversationItem: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  conversationContent: {
    position: 'relative',
  },
  conversationHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.xs,
  },
  participantInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  participantName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginRight: SPACING.sm,
  },
  conversationMeta: {
    alignItems: 'flex-end',
  },
  timeText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  lastMessageText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  unreadBadge: {
    position: 'absolute',
    top: -8,
    right: -8,
    backgroundColor: COLORS.error,
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  unreadBadgeText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.bold,
  },
  memberItem: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  memberContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  memberInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  memberName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginRight: SPACING.sm,
  },
  emptyState: {
    alignItems: 'center',
    padding: SPACING.xl,
    marginTop: SPACING.xl,
  },
  emptyStateText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  emptyStateSubtext: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
});

export default DirectMessagesView;
