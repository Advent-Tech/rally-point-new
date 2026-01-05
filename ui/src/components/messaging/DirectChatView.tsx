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
import { MaterialIcons } from '@expo/vector-icons';
import { MessagingService, ChatMessage, Conversation } from '../../services/MessagingService';
import { ManagedUser } from '../../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';
import MessageBubble from './MessageBubble';
import TypingIndicator from './TypingIndicator';
import UserRoleBadge from '../UserRoleBadge';
import UserStatusIndicator from '../UserStatusIndicator';

interface DirectChatViewProps {
  conversation: Conversation;
  otherUser: ManagedUser;
  currentUser: any;
  onBack: () => void;
}

const DirectChatView: React.FC<DirectChatViewProps> = ({
  conversation,
  otherUser,
  currentUser,
  onBack
}) => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputText, setInputText] = useState('');
  const [sending, setSending] = useState(false);
  const [typingUsers, setTypingUsers] = useState<string[]>([]);
  const flatListRef = useRef<FlatList>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout>();

  useEffect(() => {
    if (!conversation?.id || !currentUser?.uid) {
      console.warn('Missing conversation or user data for DirectChatView');
      return;
    }

    let unsubscribeMessages: (() => void) | null = null;
    let unsubscribeTyping: (() => void) | null = null;

    try {
      // Subscribe to messages
      unsubscribeMessages = MessagingService.subscribeToMessages(
        conversation.id,
        (newMessages) => {
          try {
            setMessages(newMessages || []);
            // Mark messages as read (with error handling)
            MessagingService.markMessagesAsRead(conversation.id, currentUser.uid)
              .catch(error => {
                console.warn('Failed to mark messages as read:', error);
              });
          } catch (error) {
            console.error('Error processing new messages:', error);
            setMessages([]);
          }
        }
      );

      // Subscribe to typing indicators (with error handling)
      try {
        unsubscribeTyping = MessagingService.subscribeToTypingIndicators(
          conversation.id,
          (indicators) => {
            try {
              const typingUserIds = (indicators || [])
                .filter(indicator => indicator?.userId && indicator.userId !== currentUser.uid)
                .map(indicator => indicator.userId);
              setTypingUsers(typingUserIds);
            } catch (error) {
              console.error('Error processing typing indicators:', error);
              setTypingUsers([]);
            }
          }
        );
      } catch (error) {
        console.warn('Failed to subscribe to typing indicators:', error);
      }
    } catch (error) {
      console.error('Error setting up DirectChatView subscriptions:', error);
    }

    return () => {
      try {
        if (unsubscribeMessages) {
          unsubscribeMessages();
        }
        if (unsubscribeTyping) {
          unsubscribeTyping();
        }
      } catch (error) {
        console.error('Error cleaning up DirectChatView subscriptions:', error);
      }
    };
  }, [conversation?.id, currentUser?.uid]);

  const handleSendMessage = async () => {
    if (!inputText.trim() || sending) return;

    const messageText = inputText.trim();
    setInputText('');
    setSending(true);

    try {
      await MessagingService.sendMessage(
        conversation.id,
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
    if (text.length > 0) {
      MessagingService.sendTypingIndicator(
        conversation.id,
        currentUser.uid,
        currentUser.displayName || currentUser.email?.split('@')[0] || 'Unknown'
      );
    }

    // Clear typing indicator after 3 seconds of inactivity
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }
    
    typingTimeoutRef.current = setTimeout(() => {
      MessagingService.clearTypingIndicator(conversation.id, currentUser.uid);
    }, 3000);
  };

  const renderMessage = ({ item, index }: { item: ChatMessage; index: number }) => {
    const isOwnMessage = item.senderId === currentUser.uid;
    
    return (
      <MessageBubble
        message={item}
        isOwnMessage={isOwnMessage}
        showSenderName={false} // Don't show sender names in direct messages
        teamMembers={[otherUser]}
      />
    );
  };

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <MaterialIcons name="chat-bubble-outline" size={64} color={COLORS.text.secondary} />
      <Text style={styles.emptyStateText}>
        Start a conversation with {otherUser.displayName || otherUser.email.split('@')[0]}
      </Text>
      <Text style={styles.emptyStateSubtext}>
        Send a message to begin your direct conversation
      </Text>
    </View>
  );

  return (
    <KeyboardAvoidingView 
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      keyboardVerticalOffset={Platform.OS === 'ios' ? 90 : 0}
    >
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onBack} style={styles.backButton}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        
        <View style={styles.headerInfo}>
          <Text style={styles.headerTitle}>
            {otherUser.displayName || otherUser.email.split('@')[0]}
          </Text>
          <View style={styles.headerMeta}>
            <UserRoleBadge role={otherUser.role} size="small" />
            <UserStatusIndicator 
              isOnline={otherUser.isOnline || false}
              lastActiveAt={otherUser.lastActiveAt}
              size="small"
            />
          </View>
        </View>
      </View>

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
          teamMembers={[otherUser]}
        />
      )}

      {/* Message Input */}
      <View style={styles.inputContainer}>
        <View style={styles.inputWrapper}>
          <TextInput
            style={styles.textInput}
            value={inputText}
            onChangeText={handleInputChange}
            placeholder={`Message ${otherUser.displayName || otherUser.email.split('@')[0]}...`}
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
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
    backgroundColor: COLORS.background.surface,
  },
  backButton: {
    padding: SPACING.xs,
    marginRight: SPACING.sm,
  },
  headerInfo: {
    flex: 1,
  },
  headerTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  headerMeta: {
    flexDirection: 'row',
    alignItems: 'center',
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

export default DirectChatView;
