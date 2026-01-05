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
  Conversation,
} from '../services/MessagingService';

type GroupChatScreenNavigationProp = StackNavigationProp<MainStackParamList, 'GroupChat'>;
type GroupChatScreenRouteProp = RouteProp<MainStackParamList, 'GroupChat'>;

const GroupChatScreen: React.FC = () => {
  const navigation = useNavigation<GroupChatScreenNavigationProp>();
  const route = useRoute<GroupChatScreenRouteProp>();
  const { user } = useAuth();
  const flatListRef = useRef<FlatList>(null);

  const { groupId, groupName } = route.params;

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [typingUsers, setTypingUsers] = useState<TypingIndicatorType[]>([]);
  const [groupInfo, setGroupInfo] = useState<Conversation | null>(null);

  useEffect(() => {
    if (groupId) {
      subscribeToMessages();
      subscribeToTypingIndicators();
      markMessagesAsRead();
      loadGroupInfo();
    }
  }, [groupId]);

  const subscribeToMessages = () => {
    const unsubscribe = MessagingService.subscribeToMessages(
      groupId,
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
      groupId,
      setTypingUsers
    );

    return unsubscribe;
  };

  const loadGroupInfo = async () => {
    // In a real implementation, you'd fetch group details
    // For now, we'll create a mock group info
    const mockGroupInfo: Conversation = {
      id: groupId,
      type: 'group',
      participants: ['user1', 'user2', 'user3'],
      participantDetails: [
        {
          userId: 'user1',
          name: 'Team Leader Sarah',
          role: 'team_leader',
          isOnline: true,
          lastSeen: new Date(),
          joinedAt: new Date(),
        },
        {
          userId: 'user2',
          name: 'Worker Mike',
          role: 'worker',
          isOnline: false,
          lastSeen: new Date(),
          joinedAt: new Date(),
        },
        {
          userId: 'user3',
          name: 'Worker Lisa',
          role: 'worker',
          isOnline: true,
          lastSeen: new Date(),
          joinedAt: new Date(),
        },
      ],
      groupName,
      groupDescription: 'Team Atlantic Discussion Group',
      adminIds: ['user1'],
      createdBy: 'user1',
      unreadCount: {},
      createdAt: new Date(),
      updatedAt: new Date(),
      lastMessageTime: new Date(),
    };

    setGroupInfo(mockGroupInfo);
  };

  const markMessagesAsRead = async () => {
    if (!user) return;

    try {
      await MessagingService.markMessagesAsRead(groupId, user.uid);
    } catch (error) {
      console.error('Error marking messages as read:', error);
    }
  };

  const handleSendMessage = async (content: string) => {
    if (!user || !content.trim()) return;

    try {
      await MessagingService.sendMessage(
        groupId,
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
          groupId,
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
    Alert.alert('Copied', 'Message copied to clipboard');
  };

  const editMessage = (message: ChatMessage) => {
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

  const handleInfo = () => {
    if (!groupInfo) return;

    const membersList = groupInfo.participantDetails
      .map(p => `${p.name} (${p.role})`)
      .join('\n');

    Alert.alert(
      'Group Info',
      `Group: ${groupName}\nMembers: ${groupInfo.participants.length}\n\n${membersList}`,
      [{ text: 'OK' }]
    );
  };

  const getSubtitle = () => {
    if (!groupInfo) return 'Loading...';
    return `${groupInfo.participants.length} members`;
  };

  const renderMessage = ({ item, index }: { item: ChatMessage; index: number }) => {
    const isCurrentUser = item.senderId === user?.uid;
    
    return (
      <MessageBubble
        message={item}
        isCurrentUser={isCurrentUser}
        showSenderName={!isCurrentUser} // Always show sender name in groups
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
        title={groupName}
        subtitle={getSubtitle()}
        isGroup={true}
        onBackPress={() => navigation.goBack()}
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
        placeholder={`Message ${groupName}...`}
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

export default GroupChatScreen;
