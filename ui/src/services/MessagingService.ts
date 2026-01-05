import AsyncStorage from '@react-native-async-storage/async-storage';

// Enhanced Message Types
export interface ChatMessage {
  id: string;
  conversationId: string;
  senderId: string;
  senderName: string;
  senderRole: string;
  content: string;
  timestamp: Date;
  type: 'text' | 'image' | 'audio' | 'location';
  isRead: boolean;
  metadata?: Record<string, any>;
}

export interface Conversation {
  id: string;
  participants: string[];
  participantNames: Record<string, string>;
  lastMessage?: string;
  lastMessageTime?: Date;
  unreadCount: number;
  type: 'direct' | 'group' | 'team';
  name?: string;
  createdAt: Date;
  updatedAt: Date;
}

const MESSAGES_KEY = 'chat_messages';
const CONVERSATIONS_KEY = 'chat_conversations';

export class MessagingService {
  static async createConversation(conversation: Omit<Conversation, 'id' | 'createdAt' | 'updatedAt' | 'unreadCount'>): Promise<string> {
    try {
      const id = `conv_${Date.now()}`;
      const now = new Date();
      const newConv: Conversation = {
        ...conversation,
        id,
        unreadCount: 0,
        createdAt: now,
        updatedAt: now,
      };

      const data = await AsyncStorage.getItem(CONVERSATIONS_KEY);
      const conversations: Conversation[] = data ? JSON.parse(data) : [];
      conversations.push(newConv);
      await AsyncStorage.setItem(CONVERSATIONS_KEY, JSON.stringify(conversations));

      return id;
    } catch (error) {
      console.error('Error creating conversation:', error);
      throw error;
    }
  }

  static async getConversations(userId: string): Promise<Conversation[]> {
    try {
      const data = await AsyncStorage.getItem(CONVERSATIONS_KEY);
      const conversations: Conversation[] = data ? JSON.parse(data) : [];
      return conversations
        .filter(c => c.participants.includes(userId))
        .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
    } catch (error) {
      console.error('Error getting conversations:', error);
      return [];
    }
  }

  static async sendMessage(message: Omit<ChatMessage, 'id' | 'timestamp' | 'isRead'>): Promise<string> {
    try {
      const id = `msg_${Date.now()}`;
      const newMessage: ChatMessage = {
        ...message,
        id,
        timestamp: new Date(),
        isRead: false,
      };

      const data = await AsyncStorage.getItem(MESSAGES_KEY);
      const messages: ChatMessage[] = data ? JSON.parse(data) : [];
      messages.push(newMessage);
      await AsyncStorage.setItem(MESSAGES_KEY, JSON.stringify(messages));

      // Update conversation
      const convData = await AsyncStorage.getItem(CONVERSATIONS_KEY);
      const conversations: Conversation[] = convData ? JSON.parse(convData) : [];
      const convIndex = conversations.findIndex(c => c.id === message.conversationId);
      if (convIndex !== -1) {
        conversations[convIndex].lastMessage = message.content;
        conversations[convIndex].lastMessageTime = new Date();
        conversations[convIndex].updatedAt = new Date();
        await AsyncStorage.setItem(CONVERSATIONS_KEY, JSON.stringify(conversations));
      }

      return id;
    } catch (error) {
      console.error('Error sending message:', error);
      throw error;
    }
  }

  static async getMessages(conversationId: string): Promise<ChatMessage[]> {
    try {
      const data = await AsyncStorage.getItem(MESSAGES_KEY);
      const messages: ChatMessage[] = data ? JSON.parse(data) : [];
      return messages
        .filter(m => m.conversationId === conversationId)
        .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
    } catch (error) {
      console.error('Error getting messages:', error);
      return [];
    }
  }

  static async markAsRead(conversationId: string, userId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(MESSAGES_KEY);
      const messages: ChatMessage[] = data ? JSON.parse(data) : [];

      let updated = false;
      messages.forEach(m => {
        if (m.conversationId === conversationId && m.senderId !== userId && !m.isRead) {
          m.isRead = true;
          updated = true;
        }
      });

      if (updated) {
        await AsyncStorage.setItem(MESSAGES_KEY, JSON.stringify(messages));
      }
    } catch (error) {
      console.error('Error marking as read:', error);
    }
  }

  static async deleteMessage(messageId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(MESSAGES_KEY);
      const messages: ChatMessage[] = data ? JSON.parse(data) : [];
      const filtered = messages.filter(m => m.id !== messageId);
      await AsyncStorage.setItem(MESSAGES_KEY, JSON.stringify(filtered));
    } catch (error) {
      console.error('Error deleting message:', error);
      throw error;
    }
  }

  static listenToMessages(conversationId: string, callback: (messages: ChatMessage[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const messages = await this.getMessages(conversationId);
      callback(messages);
    };

    poll();
    intervalId = setInterval(poll, 2000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  static listenToConversations(userId: string, callback: (conversations: Conversation[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const conversations = await this.getConversations(userId);
      callback(conversations);
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  // Alias for listenToConversations - used by some screens
  static subscribeToUserConversations(userId: string, callback: (conversations: Conversation[]) => void): () => void {
    return this.listenToConversations(userId, callback);
  }

  // Get team members for group chat
  static async getTeamMembers(teamId: string): Promise<{ id: string; name: string; role: string }[]> {
    try {
      // For now return empty array - this would need backend integration
      // In a real implementation, this would fetch from the user-service
      return [];
    } catch (error) {
      console.error('Error getting team members:', error);
      return [];
    }
  }
}

export default MessagingService;
