import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '../contexts/AuthContext';
import {
  MessagingService,
  Conversation,
  ChatMessage,
  TypingIndicator,
  UserPresence,
} from '../services/MessagingService';
import { NotificationService } from '../services/NotificationService';

export interface MessagingState {
  conversations: Conversation[];
  activeConversation: string | null;
  messages: { [conversationId: string]: ChatMessage[] };
  typingIndicators: { [conversationId: string]: TypingIndicator[] };
  userPresence: { [userId: string]: UserPresence };
  unreadCount: number;
  loading: boolean;
  error: string | null;
}

export const useMessaging = () => {
  const { user } = useAuth();
  const [state, setState] = useState<MessagingState>({
    conversations: [],
    activeConversation: null,
    messages: {},
    typingIndicators: {},
    userPresence: {},
    unreadCount: 0,
    loading: true,
    error: null,
  });

  // Initialize messaging when user is available
  useEffect(() => {
    if (user) {
      initializeMessaging();
      updateUserPresence(true);
    }

    return () => {
      if (user) {
        updateUserPresence(false);
      }
    };
  }, [user]);

  // Update user presence when app state changes
  useEffect(() => {
    const handleAppStateChange = (nextAppState: string) => {
      if (user) {
        updateUserPresence(nextAppState === 'active');
      }
    };

    // In a real app, you'd listen to AppState changes
    // AppState.addEventListener('change', handleAppStateChange);
    
    return () => {
      // AppState.removeEventListener('change', handleAppStateChange);
    };
  }, [user]);

  const initializeMessaging = useCallback(async () => {
    if (!user) return;

    try {
      setState(prev => ({ ...prev, loading: true, error: null }));

      // Subscribe to conversations
      const unsubscribeConversations = MessagingService.subscribeToUserConversations(
        user.uid,
        (conversations) => {
          setState(prev => ({
            ...prev,
            conversations,
            unreadCount: calculateTotalUnreadCount(conversations, user.uid),
            loading: false,
          }));

          // Send notifications for new messages
          handleNewMessageNotifications(conversations);
        }
      );

      return unsubscribeConversations;
    } catch (error) {
      console.error('Error initializing messaging:', error);
      setState(prev => ({
        ...prev,
        error: 'Failed to initialize messaging',
        loading: false,
      }));
    }
  }, [user]);

  const calculateTotalUnreadCount = (conversations: Conversation[], userId: string): number => {
    return conversations.reduce((total, conv) => {
      return total + (conv.unreadCount[userId] || 0);
    }, 0);
  };

  const handleNewMessageNotifications = async (conversations: Conversation[]) => {
    if (!user) return;

    // Check for new unread messages and send notifications
    for (const conversation of conversations) {
      const unreadCount = conversation.unreadCount[user.uid] || 0;
      if (unreadCount > 0 && conversation.lastMessage) {
        const { lastMessage } = conversation;
        
        // Don't notify for own messages
        if (lastMessage.senderId === user.uid) continue;

        // Send local notification
        try {
          await NotificationService.getInstance().sendLocalNotification(
            conversation.type === 'group' 
              ? `${conversation.groupName || 'Group Chat'}`
              : lastMessage.senderName,
            lastMessage.content,
            {
              type: 'message',
              conversationId: conversation.id,
              senderId: lastMessage.senderId,
            }
          );
        } catch (error) {
          console.error('Error sending message notification:', error);
        }
      }
    }
  };

  const updateUserPresence = async (isOnline: boolean) => {
    if (!user) return;

    try {
      await MessagingService.updateUserPresence(user.uid, isOnline);
    } catch (error) {
      console.error('Error updating user presence:', error);
    }
  };

  const subscribeToMessages = useCallback((conversationId: string) => {
    const unsubscribe = MessagingService.subscribeToMessages(
      conversationId,
      (messages) => {
        setState(prev => ({
          ...prev,
          messages: {
            ...prev.messages,
            [conversationId]: messages,
          },
        }));
      }
    );

    return unsubscribe;
  }, []);

  const subscribeToTypingIndicators = useCallback((conversationId: string) => {
    const unsubscribe = MessagingService.subscribeToTypingIndicators(
      conversationId,
      (typingUsers) => {
        setState(prev => ({
          ...prev,
          typingIndicators: {
            ...prev.typingIndicators,
            [conversationId]: typingUsers,
          },
        }));
      }
    );

    return unsubscribe;
  }, []);

  const subscribeToUserPresence = useCallback((userIds: string[]) => {
    const unsubscribe = MessagingService.subscribeToUserPresence(
      userIds,
      (presenceList) => {
        const presenceMap: { [userId: string]: UserPresence } = {};
        presenceList.forEach(presence => {
          presenceMap[presence.userId] = presence;
        });

        setState(prev => ({
          ...prev,
          userPresence: {
            ...prev.userPresence,
            ...presenceMap,
          },
        }));
      }
    );

    return unsubscribe;
  }, []);

  const sendMessage = async (
    conversationId: string,
    content: string,
    messageType: 'text' | 'image' | 'location' | 'file' = 'text'
  ) => {
    if (!user || !content.trim()) return;

    try {
      await MessagingService.sendMessage(
        conversationId,
        user.uid,
        user.displayName || user.email.split('@')[0],
        user.role,
        content.trim(),
        messageType
      );
    } catch (error) {
      console.error('Error sending message:', error);
      throw error;
    }
  };

  const markMessagesAsRead = async (conversationId: string) => {
    if (!user) return;

    try {
      await MessagingService.markMessagesAsRead(conversationId, user.uid);
    } catch (error) {
      console.error('Error marking messages as read:', error);
    }
  };

  const sendTypingIndicator = async (conversationId: string) => {
    if (!user) return;

    try {
      await MessagingService.sendTypingIndicator(
        conversationId,
        user.uid,
        user.displayName || user.email.split('@')[0]
      );
    } catch (error) {
      console.error('Error sending typing indicator:', error);
    }
  };

  const createDirectConversation = async (
    recipientId: string,
    recipientName: string,
    recipientRole: string
  ) => {
    if (!user) return null;

    try {
      const conversationId = await MessagingService.getOrCreateDirectConversation(
        user.uid,
        user.displayName || user.email.split('@')[0],
        user.role,
        recipientId,
        recipientName,
        recipientRole
      );

      return conversationId;
    } catch (error) {
      console.error('Error creating direct conversation:', error);
      throw error;
    }
  };

  const setActiveConversation = (conversationId: string | null) => {
    setState(prev => ({
      ...prev,
      activeConversation: conversationId,
    }));
  };

  return {
    ...state,
    subscribeToMessages,
    subscribeToTypingIndicators,
    subscribeToUserPresence,
    sendMessage,
    markMessagesAsRead,
    sendTypingIndicator,
    createDirectConversation,
    setActiveConversation,
    updateUserPresence,
  };
};
