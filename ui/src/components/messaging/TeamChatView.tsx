import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  FlatList,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert
} from 'react-native';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { MessagingService, ChatMessage, Conversation } from '../../services/MessagingService';
import { UserManagementService } from '../../services/UserManagementService';
import { ManagedUser } from '../../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../../constants/Colors';
import MessageBubble from './MessageBubble';
import TypingIndicator from './TypingIndicator';

interface TeamChatViewProps {
  team: any;
  currentUser: any;
  teamMembers: ManagedUser[];
}

const TeamChatView: React.FC<TeamChatViewProps> = ({
  team,
  currentUser,
  teamMembers
}) => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputText, setInputText] = useState('');
  const [sending, setSending] = useState(false);
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [typingUsers, setTypingUsers] = useState<string[]>([]);
  const flatListRef = useRef<FlatList>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout>();

  useEffect(() => {
    initializeTeamConversation();
  }, [team, currentUser]);

  useEffect(() => {
    if (conversationId) {
      // Subscribe to messages
      const unsubscribeMessages = MessagingService.subscribeToMessages(
        conversationId,
        (newMessages) => {
          setMessages(newMessages);
          // Mark messages as read (with error handling)
          MessagingService.markMessagesAsRead(conversationId, currentUser.uid)
            .catch(error => {
              console.warn('Failed to mark messages as read:', error);
            });
        }
      );

      // Subscribe to typing indicators (with error handling)
      let unsubscribeTyping: (() => void) | null = null;
      try {
        unsubscribeTyping = MessagingService.subscribeToTypingIndicators(
          conversationId,
          (indicators) => {
            const typingUserIds = indicators
              .filter(indicator => indicator.userId !== currentUser.uid)
              .map(indicator => indicator.userId);
            setTypingUsers(typingUserIds);
          }
        );
      } catch (error) {
        console.warn('Failed to subscribe to typing indicators:', error);
      }

      return () => {
        unsubscribeMessages();
        if (unsubscribeTyping) {
          unsubscribeTyping();
        }
      };
    }
  }, [conversationId, currentUser.uid]);

  const initializeTeamConversation = async () => {
    try {
      setLoading(true);
      
      // Get or create team conversation
      const teamConversationId = await getOrCreateTeamConversation();
      setConversationId(teamConversationId);
    } catch (error) {
      console.error('Error initializing team conversation:', error);
      Alert.alert('Error', 'Failed to load team chat');
    } finally {
      setLoading(false);
    }
  };

  const getOrCreateTeamConversation = async (): Promise<string> => {
    try {
      // Validate required team data
      if (!team?.id) {
        throw new Error('Team ID is required');
      }
      
      // Check for team name in various possible properties
      const teamName = team?.name || team?.teamName || team?.displayName || 'Unknown Team';
      if (!teamName || teamName === 'Unknown Team') {
        console.warn('Team name not found, using fallback. Team object:', team);
      }
      if (!currentUser?.uid) {
        throw new Error('Current user is required');
      }

      // Check if team conversation already exists
      const existingConversation = await MessagingService.getTeamConversation(team.id);
      
      if (existingConversation) {
        return existingConversation.id;
      }

      // Create new team conversation
      const participantIds = teamMembers.map(member => member.uid).filter(Boolean);
      const participantDetails = teamMembers.map(member => ({
        userId: member.uid,
        name: member.displayName || member.email?.split('@')[0] || 'Unknown',
        role: member.role || 'member',
        isOnline: member.isOnline || false,
        lastSeen: member.lastActiveAt || new Date(),
        joinedAt: new Date(),
      })).filter(detail => detail.userId);

      const conversationId = await MessagingService.createTeamConversation(
        team.id,
        teamName,
        team.leaderId || currentUser.uid,
        team.leaderName || currentUser.displayName || currentUser.email || 'Team Leader',
        participantIds,
        participantDetails,
        `Team chat for ${teamName}`
      );

      return conversationId;
    } catch (error) {
      console.error('Error getting/creating team conversation:', error);
      throw error;
    }
  };

  const handleSendMessage = async () => {
    if (!inputText.trim() || !conversationId || sending) return;

    const messageText = inputText.trim();
    setInputText('');
    setSending(true);

    try {
      await MessagingService.sendMessage(
        conversationId,
        currentUser.uid,
        currentUser.displayName || currentUser.email?.split('@')[0] || 'Unknown',
        'worker', // This should be the actual user role
        messageText,
        'text'
      );

      // Scroll to bottom after sending
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
    } catch (error) {
      console.error('Error sending message:', error);
      Alert.alert('Error', 'Failed to send message');
      setInputText(messageText); // Restore the message
    } finally {
      setSending(false);
    }
  };

  const handleInputChange = (text: string) => {
    setInputText(text);
    
    // Send typing indicator
    if (conversationId && text.length > 0) {
      MessagingService.sendTypingIndicator(
        conversationId,
        currentUser.uid,
        currentUser.displayName || currentUser.email?.split('@')[0] || 'Unknown'
      );
    }

    // Clear typing indicator after 3 seconds of inactivity
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }
    
    typingTimeoutRef.current = setTimeout(() => {
      if (conversationId) {
        MessagingService.clearTypingIndicator(conversationId, currentUser.uid);
      }
    }, 3000);
  };

  const renderMessage = ({ item, index }: { item: ChatMessage; index: number }) => {
    const isOwnMessage = item.senderId === currentUser.uid;
    const showSenderName = !isOwnMessage && (
      index === 0 || 
      messages[index - 1].senderId !== item.senderId
    );

    return (
      <MessageBubble
        message={item}
        isOwnMessage={isOwnMessage}
        showSenderName={showSenderName}
        teamMembers={teamMembers}
      />
    );
  };

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <MaterialIcons name="chat" size={64} color={COLORS.text.secondary} />
      <Text style={styles.emptyStateText}>Welcome to {team.name}!</Text>
      <Text style={styles.emptyStateSubtext}>
        Start the conversation with your team members
      </Text>
    </View>
  );

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.loadingText}>Loading team chat...</Text>
      </View>
    );
  }

  return (
    <KeyboardAvoidingView 
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      keyboardVerticalOffset={Platform.OS === 'ios' ? 90 : 0}
    >
      {/* Messages List */}
      <FlatList
        ref={flatListRef}
        data={messages}
        renderItem={renderMessage}
        keyExtractor={(item) => item.id}
        style={styles.messagesList}
        contentContainerStyle={[
          styles.messagesContent,
          messages.length === 0 && styles.emptyMessagesContent
        ]}
        showsVerticalScrollIndicator={false}
        onContentSizeChange={() => flatListRef.current?.scrollToEnd({ animated: true })}
        ListEmptyComponent={renderEmptyState}
      />

      {/* Typing Indicator */}
      {typingUsers.length > 0 && (
        <TypingIndicator
          typingUsers={typingUsers}
          teamMembers={teamMembers}
        />
      )}

      {/* Message Input */}
      <View style={styles.inputContainer}>
        <View style={styles.inputWrapper}>
          <TextInput
            style={styles.textInput}
            value={inputText}
            onChangeText={handleInputChange}
            placeholder={`Message ${team.name}...`}
            placeholderTextColor={COLORS.text.secondary}
            multiline
            maxLength={1000}
            editable={!sending}
          />
          <TouchableOpacity
            style={[
              styles.sendButton,
              (!inputText.trim() || sending) && styles.sendButtonDisabled
            ]}
            onPress={handleSendMessage}
            disabled={!inputText.trim() || sending}
            activeOpacity={0.7}
          >
            <MaterialIcons 
              name={sending ? "hourglass-empty" : "send"} 
              size={20} 
              color={(!inputText.trim() || sending) ? COLORS.text.secondary : COLORS.background.primary} 
            />
          </TouchableOpacity>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.surface,
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
  messagesList: {
    flex: 1,
  },
  messagesContent: {
    paddingHorizontal: SPACING.md,
    paddingTop: SPACING.md,
  },
  emptyMessagesContent: {
    flexGrow: 1,
    justifyContent: 'center',
  },
  emptyState: {
    alignItems: 'center',
    padding: SPACING.xl,
  },
  emptyStateText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    textAlign: 'center',
  },
  emptyStateSubtext: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
  inputContainer: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: COLORS.background.surface,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    minHeight: 44,
  },
  textInput: {
    flex: 1,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    maxHeight: 100,
    paddingVertical: SPACING.xs,
  },
  sendButton: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.full,
    width: 36,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: SPACING.sm,
  },
  sendButtonDisabled: {
    backgroundColor: COLORS.background.disabled,
  },
});

export default TeamChatView;
