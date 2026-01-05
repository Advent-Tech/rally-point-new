import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Platform-specific imports
let Notifications: any;
let Device: any;

if (Platform.OS !== 'web') {
  try {
    Notifications = require('expo-notifications');
    Device = require('expo-device');
  } catch (error) {
    console.warn('Expo notifications not available:', error);
  }
}

// Configure notification behavior (only on mobile platforms)
if (Platform.OS !== 'web' && Notifications) {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldPlaySound: true,
      shouldSetBadge: true,
    }),
  });
}

export interface AppNotification {
  id: string;
  userId: string;
  title: string;
  body: string;
  type: 'survey' | 'delivery' | 'team' | 'system' | 'message';
  data?: Record<string, any>;
  isRead: boolean;
  createdAt: Date;
}

const NOTIFICATIONS_KEY = 'app_notifications';
const PUSH_TOKEN_KEY = 'push_token';

export class NotificationService {
  static async registerForPushNotifications(): Promise<string | null> {
    if (Platform.OS === 'web') {
      console.log('Push notifications not supported on web');
      return null;
    }

    if (!Device || !Notifications) {
      console.log('Expo notifications not available');
      return null;
    }

    try {
      if (!Device.isDevice) {
        console.log('Push notifications require a physical device');
        return null;
      }

      const { status: existingStatus } = await Notifications.getPermissionsAsync();
      let finalStatus = existingStatus;

      if (existingStatus !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        finalStatus = status;
      }

      if (finalStatus !== 'granted') {
        console.log('Push notification permission not granted');
        return null;
      }

      const token = (await Notifications.getExpoPushTokenAsync()).data;
      await AsyncStorage.setItem(PUSH_TOKEN_KEY, token);
      console.log('Push token:', token);
      return token;
    } catch (error) {
      console.error('Error registering for push notifications:', error);
      return null;
    }
  }

  static async createNotification(notification: Omit<AppNotification, 'id' | 'createdAt' | 'isRead'>): Promise<string> {
    try {
      const id = `notif_${Date.now()}`;
      const newNotification: AppNotification = {
        ...notification,
        id,
        isRead: false,
        createdAt: new Date(),
      };

      const data = await AsyncStorage.getItem(NOTIFICATIONS_KEY);
      const notifications: AppNotification[] = data ? JSON.parse(data) : [];
      notifications.push(newNotification);
      await AsyncStorage.setItem(NOTIFICATIONS_KEY, JSON.stringify(notifications));

      // Show local notification if on mobile
      if (Platform.OS !== 'web' && Notifications) {
        await Notifications.scheduleNotificationAsync({
          content: {
            title: notification.title,
            body: notification.body,
            data: notification.data,
          },
          trigger: null, // Show immediately
        });
      }

      return id;
    } catch (error) {
      console.error('Error creating notification:', error);
      throw error;
    }
  }

  static async getNotifications(userId: string): Promise<AppNotification[]> {
    try {
      const data = await AsyncStorage.getItem(NOTIFICATIONS_KEY);
      const notifications: AppNotification[] = data ? JSON.parse(data) : [];
      return notifications
        .filter(n => n.userId === userId)
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    } catch (error) {
      console.error('Error getting notifications:', error);
      return [];
    }
  }

  static async getUnreadCount(userId: string): Promise<number> {
    try {
      const notifications = await this.getNotifications(userId);
      return notifications.filter(n => !n.isRead).length;
    } catch (error) {
      console.error('Error getting unread count:', error);
      return 0;
    }
  }

  static async markAsRead(notificationId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(NOTIFICATIONS_KEY);
      const notifications: AppNotification[] = data ? JSON.parse(data) : [];
      const index = notifications.findIndex(n => n.id === notificationId);

      if (index !== -1) {
        notifications[index].isRead = true;
        await AsyncStorage.setItem(NOTIFICATIONS_KEY, JSON.stringify(notifications));
      }
    } catch (error) {
      console.error('Error marking notification as read:', error);
    }
  }

  static async markAllAsRead(userId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(NOTIFICATIONS_KEY);
      const notifications: AppNotification[] = data ? JSON.parse(data) : [];

      notifications.forEach(n => {
        if (n.userId === userId) {
          n.isRead = true;
        }
      });

      await AsyncStorage.setItem(NOTIFICATIONS_KEY, JSON.stringify(notifications));
    } catch (error) {
      console.error('Error marking all as read:', error);
    }
  }

  static async deleteNotification(notificationId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(NOTIFICATIONS_KEY);
      const notifications: AppNotification[] = data ? JSON.parse(data) : [];
      const filtered = notifications.filter(n => n.id !== notificationId);
      await AsyncStorage.setItem(NOTIFICATIONS_KEY, JSON.stringify(filtered));
    } catch (error) {
      console.error('Error deleting notification:', error);
    }
  }

  static listenToNotifications(userId: string, callback: (notifications: AppNotification[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const notifications = await this.getNotifications(userId);
      callback(notifications);
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }
}

export default NotificationService;
