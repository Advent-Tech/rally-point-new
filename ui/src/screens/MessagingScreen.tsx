import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  StatusBar,
  RefreshControl,
  Alert,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { MainStackParamList } from '../types';
import { useAuth } from '../contexts/AuthContext';
import Header from '../components/Header';
import Icon from '../components/Icon';
import ConversationItem from '../components/chat/ConversationItem';
import {
  MessagingService,
  Conversation,
  ConversationParticipant,
} from '../services/MessagingService';

type MessagingScreenNavigationProp = StackNavigationProp<MainStackParamList, 'Messaging'>;

const MessagingScreen: React.FC = () => {
  const navigation = useNavigation<MessagingScreenNavigationProp>();
  const { user } = useAuth();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [teamMembers, setTeamMembers] = useState<ConversationParticipant[]>([]);

  useEffect(() => {
    if (user) {
      loadConversations();
      loadTeamMembers();
    }
  }, [user]);

  const loadConversations = async () => {
    if (!user) return;

    try {
      setLoading(true);
      
      // Subscribe to real-time conversations
      const unsubscribe = MessagingService.subscribeToUserConversations(
        user.uid,
        (updatedConversations) => {
          setConversations(updatedConversations);
          setLoading(false);
        }
      );

      // Return cleanup function
      return unsubscribe;
    } catch (error) {
      console.error('Error loading conversations:', error);
      setLoading(false);
    }
  };

  const loadTeamMembers = async () => {
    if (!user) return;

    try {
      const members = await MessagingService.getTeamMembers(user.uid);
      setTeamMembers(members);
    } catch (error) {
      console.error('Error loading team members:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadConversations();
    await loadTeamMembers();
    setRefreshing(false);
  };

  const handleConversationPress = (conversation: Conversation) => {
    if (conversation.type === 'group') {
      navigation.navigate('GroupChat', {
        groupId: conversation.id,
        groupName: conversation.groupName || 'Group Chat',
      });
    } else {
      // Find the other participant
      const otherParticipant = conversation.participantDetails.find(
        p => p.userId !== user?.uid
      );
      
      if (otherParticipant) {
        navigation.navigate('Chat', {
          conversationId: conversation.id,
          recipientId: otherParticipant.userId,
          recipientName: otherParticipant.name,
          recipientRole: otherParticipant.role,
          isGroup: false,
        });
      }
    }
  };

  const handleNewMessage = () => {
    Alert.alert(
      'New Message',
      'Choose an option:',
      [
        {
          text: 'Team Chat',
          onPress: createTeamChat,
        },
        {
          text: 'Direct Message',
          onPress: showTeamMembersList,
        },
        {
          text: 'Group Message',
          onPress: createGroupChat,
        },
        {
          text: 'Cancel',
          style: 'cancel',
        },
      ]
    );
  };

  const showTeamMembersList = () => {
    Alert.alert(
      'Select Team Member',
      'Choose someone to message:',
      [
        ...teamMembers.map(member => ({
          text: `${member.name} (${member.role})`,
          onPress: () => startDirectConversation(member),
        })),
        {
          text: 'Cancel',
          style: 'cancel',
        },
      ]
    );
  };

  const startDirectConversation = async (member: ConversationParticipant) => {
    if (!user) return;

    try {
      const conversationId = await MessagingService.getOrCreateDirectConversation(
        user.uid,
        user.displayName || user.email.split('@')[0],
        user.role,
        member.userId,
        member.name,
        member.role
      );

      navigation.navigate('Chat', {
        conversationId,
        recipientId: member.userId,
        recipientName: member.name,
        recipientRole: member.role,
        isGroup: false,
      });
    } catch (error) {
      console.error('Error starting conversation:', error);
      Alert.alert('Error', 'Failed to start conversation. Please try again.');
    }
  };

  const createTeamChat = async () => {
    if (!user) return;

    try {
      // Get user's team information from UserManagementService
      const userResponse = await import('../services/UserManagementService').then(
        module => module.UserManagementService.getUser(user.uid)
      );

      if (!userResponse.success || !userResponse.data?.teamId || !userResponse.data?.teamName) {
        Alert.alert(
          'No Team Assigned',
          'You need to be assigned to a team to use team chat. Please contact your administrator.'
        );
        return;
      }

      const userData = userResponse.data;

      // Create or get team conversation
      const conversationId = await MessagingService.createTeamConversation(
        user.uid,
        userData.teamId,
        userData.teamName
      );

      // Navigate to team chat
      navigation.navigate('GroupChat', {
        groupId: conversationId,
        groupName: `${userData.teamName} Team Chat`,
      });
    } catch (error) {
      console.error('Error creating team chat:', error);
      Alert.alert('Error', 'Failed to create team chat. Please try again.');
    }
  };

  const createGroupChat = () => {
    // For now, show a simple alert. In a full implementation, 
    // you'd show a screen to select multiple team members
    Alert.alert(
      'Create Group',
      'Group chat creation will be implemented in the next update.',
      [{ text: 'OK' }]
    );
  };

  const renderConversationItem = ({ item }: { item: Conversation }) => (
    <ConversationItem
      conversation={item}
      currentUserId={user?.uid || ''}
      onPress={handleConversationPress}
    />
  );

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <Icon name="message" size={64} color="#CCC" />
      <Text style={styles.emptyStateTitle}>No Messages Yet</Text>
      <Text style={styles.emptyStateSubtitle}>
        Start a conversation with your team members
      </Text>
      <TouchableOpacity style={styles.startChatButton} onPress={handleNewMessage}>
        <Text style={styles.startChatButtonText}>Start New Chat</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#FFFFFF" />
      
      <Header
        title="Messages"
        showBackButton={true}
        onBackPress={() => navigation.goBack()}
        rightComponent={
          <TouchableOpacity onPress={handleNewMessage} style={styles.newMessageButton}>
            <Icon name="edit" size={24} color="#007AFF" />
          </TouchableOpacity>
        }
      />

      <FlatList
        data={conversations}
        renderItem={renderConversationItem}
        keyExtractor={(item) => item.id}
        style={styles.conversationsList}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        ListEmptyComponent={!loading ? renderEmptyState : null}
        showsVerticalScrollIndicator={false}
      />

      {/* Floating Action Button */}
      <TouchableOpacity style={styles.fab} onPress={handleNewMessage}>
        <Icon name="edit" size={24} color="#FFFFFF" />
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  newMessageButton: {
    padding: 8,
  },
  conversationsList: {
    flex: 1,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 32,
    paddingTop: 100,
  },
  emptyStateTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: '#333',
    marginTop: 16,
    marginBottom: 8,
  },
  emptyStateSubtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 32,
  },
  startChatButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 25,
  },
  startChatButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  fab: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
  },
});

export default MessagingScreen;
