import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  FlatList,
  StyleSheet,
  StatusBar,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { MainStackParamList } from '../types';
import { useAuth } from '../contexts/AuthContext';
import ChatHeader from '../components/chat/ChatHeader';
import MessageBubble from '../components/chat/MessageBubble';
import ChatInput from '../components/chat/ChatInput';
import TypingIndicator from '../components/chat/TypingIndicator';
import {
  MessagingService,
  ChatMessage,
  TypingIndicator as TypingIndicatorType,
} from '../services/MessagingService';

type ChatScreenNavigationProp = StackNavigationProp<MainStackParamList, 'Chat'>;
type ChatScreenRouteProp = RouteProp<MainStackParamList, 'Chat'>;

const ChatScreen: React.FC = () => {
  const navigation = useNavigation<ChatScreenNavigationProp>();
  const route = useRoute<ChatScreenRouteProp>();
  const { user } = useAuth();
  const flatListRef = useRef<FlatList>(null);

  const {
    conversationId,
    recipientId,
    recipientName,
    recipientRole,
    isGroup = false,
  } = route.params;

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [typingUsers, setTypingUsers] = useState<TypingIndicatorType[]>([]);
  const [isRecipientOnline, setIsRecipientOnline] = useState(false);

  useEffect(() => {
    if (conversationId) {
      subscribeToMessages();
      subscribeToTypingIndicators();
      markMessagesAsRead();
      
      if (!isGroup) {
        subscribeToRecipientPresence();
      }
    }
  }, [conversationId]);

  const subscribeToMessages = () => {
    const unsubscribe = MessagingService.subscribeToMessages(
      conversationId,
      (updatedMessages) => {
        setMessages(updatedMessages);
        setLoading(false);
        
        // Auto-scroll to bottom when new messages arrive
        setTimeout(() => {
          flatListRef.current?.scrollToEnd({ animated: true });
        }, 100);
      }
    );

    return unsubscribe;
  };

  const subscribeToTypingIndicators = () => {
    const unsubscribe = MessagingService.subscribeToTypingIndicators(
      conversationId,
      setTypingUsers
    );

    return unsubscribe;
  };

  const subscribeToRecipientPresence = () => {
    const unsubscribe = MessagingService.subscribeToUserPresence(
      [recipientId],
      (presence) => {
        const recipientPresence = presence.find(p => p.userId === recipientId);
        setIsRecipientOnline(recipientPresence?.isOnline || false);
      }
    );

    return unsubscribe;
  };

  const markMessagesAsRead = async () => {
    if (!user) return;

    try {
      await MessagingService.markMessagesAsRead(conversationId, user.uid);
    } catch (error) {
      console.error('Error marking messages as read:', error);
    }
  };

  const handleSendMessage = async (content: string) => {
    if (!user || !content.trim()) return;

    try {
      await MessagingService.sendMessage(
        conversationId,
        user.uid,
        user.displayName || user.email.split('@')[0],
        user.role,
        content.trim()
      );
    } catch (error) {
      console.error('Error sending message:', error);
      Alert.alert('Error', 'Failed to send message. Please try again.');
    }
  };

  const handleTyping = async (isTyping: boolean) => {
    if (!user) return;

    if (isTyping) {
      try {
        await MessagingService.sendTypingIndicator(
          conversationId,
          user.uid,
          user.displayName || user.email.split('@')[0]
        );
      } catch (error) {
        console.error('Error sending typing indicator:', error);
      }
    }
  };

  const handleMessageLongPress = (message: ChatMessage) => {
    const isCurrentUserMessage = message.senderId === user?.uid;
    
    const options = [
      { text: 'Copy', onPress: () => copyMessage(message.content) },
    ];

    if (isCurrentUserMessage) {
      options.push(
        { text: 'Edit', onPress: () => editMessage(message) },
        { text: 'Delete', onPress: () => deleteMessage(message), style: 'destructive' }
      );
    }

    options.push({ text: 'Cancel', style: 'cancel' });

    Alert.alert('Message Options', '', options);
  };

  const copyMessage = (content: string) => {
    // In a real app, you'd use Clipboard API
    Alert.alert('Copied', 'Message copied to clipboard');
  };

  const editMessage = (message: ChatMessage) => {
    // In a real app, you'd show an edit input
    Alert.alert('Edit Message', 'Message editing will be implemented in the next update.');
  };

  const deleteMessage = (message: ChatMessage) => {
    Alert.alert(
      'Delete Message',
      'Are you sure you want to delete this message?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await MessagingService.deleteMessage(message.id);
            } catch (error) {
              Alert.alert('Error', 'Failed to delete message.');
            }
          },
        },
      ]
    );
  };

  const handleCall = () => {
    Alert.alert(
      'Voice Call',
      `Call ${recipientName}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Call', onPress: () => console.log('Starting call...') },
      ]
    );
  };

  const handleInfo = () => {
    Alert.alert(
      'Contact Info',
      `Name: ${recipientName}\nRole: ${recipientRole}\nStatus: ${isRecipientOnline ? 'Online' : 'Offline'}`,
      [{ text: 'OK' }]
    );
  };

  const getSubtitle = () => {
    if (isGroup) {
      return 'Group Chat';
    }
    return isRecipientOnline ? 'Online' : `Last seen ${getLastSeenText()}`;
  };

  const getLastSeenText = () => {
    // This would typically come from the recipient's presence data
    return 'recently';
  };

  const renderMessage = ({ item, index }: { item: ChatMessage; index: number }) => {
    const isCurrentUser = item.senderId === user?.uid;
    const showSenderName = isGroup && !isCurrentUser;
    
    return (
      <MessageBubble
        message={item}
        isCurrentUser={isCurrentUser}
        showSenderName={showSenderName}
        onLongPress={handleMessageLongPress}
      />
    );
  };

  const renderTypingIndicator = () => {
    if (typingUsers.length === 0) return null;
    
    return (
      <TypingIndicator
        typingUsers={typingUsers}
        currentUserId={user?.uid || ''}
      />
    );
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 20}
    >
      <StatusBar barStyle="dark-content" backgroundColor="#FFFFFF" />
      
      <ChatHeader
        title={recipientName}
        subtitle={getSubtitle()}
        isOnline={isRecipientOnline}
        isGroup={isGroup}
        onBackPress={() => navigation.goBack()}
        onCallPress={!isGroup ? handleCall : undefined}
        onInfoPress={handleInfo}
      />

      <FlatList
        ref={flatListRef}
        data={messages}
        renderItem={renderMessage}
        keyExtractor={(item) => item.id}
        style={styles.messagesList}
        contentContainerStyle={styles.messagesContainer}
        showsVerticalScrollIndicator={false}
        onContentSizeChange={() => {
          flatListRef.current?.scrollToEnd({ animated: false });
        }}
        ListFooterComponent={renderTypingIndicator}
      />

      <ChatInput
        onSendMessage={handleSendMessage}
        onTyping={handleTyping}
        placeholder={`Message ${recipientName}...`}
      />
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  messagesList: {
    flex: 1,
  },
  messagesContainer: {
    paddingVertical: 8,
  },
});

export default ChatScreen;
