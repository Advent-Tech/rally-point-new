import { useState, useEffect, useCallback } from 'react';
import { AppState, AppStateStatus } from 'react-native';
import { NotificationService } from '../services/NotificationService';
import { SurveyNotification } from '../types/survey';
import { useAuth } from '../contexts/AuthContext';

export interface NotificationState {
  notifications: SurveyNotification[];
  unreadCount: number;
  loading: boolean;
  pushToken: string | null;
}

export interface NotificationActions {
  refreshNotifications: () => Promise<void>;
  markAsRead: (notificationId: string) => Promise<void>;
  markAllAsRead: () => Promise<void>;
  sendTestNotification: () => Promise<void>;
}

export const useNotifications = (): [NotificationState, NotificationActions] => {
  const { user } = useAuth();
  const [state, setState] = useState<NotificationState>({
    notifications: [],
    unreadCount: 0,
    loading: true,
    pushToken: null
  });

  const notificationService = NotificationService.getInstance();

  // Initialize notifications when user is available
  useEffect(() => {
    if (user) {
      initializeNotifications();
    }
  }, [user]);

  // Handle app state changes
  useEffect(() => {
    const handleAppStateChange = (nextAppState: AppStateStatus) => {
      if (nextAppState === 'active' && user) {
        // Refresh notifications when app becomes active
        refreshNotifications();
      }
    };

    const subscription = AppState.addEventListener('change', handleAppStateChange);
    return () => subscription?.remove();
  }, [user]);

  const initializeNotifications = async () => {
    if (!user) return;

    try {
      // Initialize push notifications
      await notificationService.initialize(user.uid);
      
      // Get push token
      const token = notificationService.getPushToken();
      
      // Load notifications
      await refreshNotifications();
      
      setState(prev => ({
        ...prev,
        pushToken: token,
        loading: false
      }));
    } catch (error) {
      console.error('Error initializing notifications:', error);
      setState(prev => ({ ...prev, loading: false }));
    }
  };

  const refreshNotifications = useCallback(async () => {
    if (!user) return;

    try {
      setState(prev => ({ ...prev, loading: true }));
      
      const notifications = await notificationService.getNotifications(user.uid);
      const unreadCount = notifications.filter(n => !n.readAt).length;
      
      setState(prev => ({
        ...prev,
        notifications,
        unreadCount,
        loading: false
      }));
    } catch (error) {
      console.error('Error refreshing notifications:', error);
      setState(prev => ({ ...prev, loading: false }));
    }
  }, [user, notificationService]);

  const markAsRead = useCallback(async (notificationId: string) => {
    try {
      await notificationService.markNotificationAsRead(notificationId);
      
      // Update local state
      setState(prev => ({
        ...prev,
        notifications: prev.notifications.map(n => 
          n.id === notificationId 
            ? { ...n, readAt: new Date() }
            : n
        ),
        unreadCount: Math.max(0, prev.unreadCount - 1)
      }));
    } catch (error) {
      console.error('Error marking notification as read:', error);
    }
  }, [notificationService]);

  const markAllAsRead = useCallback(async () => {
    try {
      const unreadNotifications = state.notifications.filter(n => !n.readAt);
      
      // Mark all unread notifications as read
      await Promise.all(
        unreadNotifications.map(n => notificationService.markNotificationAsRead(n.id))
      );
      
      // Update local state
      setState(prev => ({
        ...prev,
        notifications: prev.notifications.map(n => ({
          ...n,
          readAt: n.readAt || new Date()
        })),
        unreadCount: 0
      }));
    } catch (error) {
      console.error('Error marking all notifications as read:', error);
    }
  }, [state.notifications, notificationService]);

  const sendTestNotification = useCallback(async () => {
    try {
      await notificationService.sendLocalNotification(
        'Test Notification',
        'This is a test notification from Rally Point',
        { type: 'test' }
      );
    } catch (error) {
      console.error('Error sending test notification:', error);
    }
  }, [notificationService]);

  const actions: NotificationActions = {
    refreshNotifications,
    markAsRead,
    markAllAsRead,
    sendTestNotification
  };

  return [state, actions];
};

// Hook for notification badge count only
export const useNotificationBadge = (): number => {
  const [unreadCount, setUnreadCount] = useState(0);
  const { user } = useAuth();

  useEffect(() => {
    if (!user) {
      setUnreadCount(0);
      return;
    }

    const loadUnreadCount = async () => {
      try {
        const notificationService = NotificationService.getInstance();
        const notifications = await notificationService.getNotifications(user.uid);
        const count = notifications.filter(n => !n.readAt).length;
        setUnreadCount(count);
      } catch (error) {
        console.error('Error loading unread count:', error);
      }
    };

    loadUnreadCount();

    // Refresh count periodically
    const interval = setInterval(loadUnreadCount, 30000); // Every 30 seconds

    return () => clearInterval(interval);
  }, [user]);

  return unreadCount;
};

// Hook for survey-specific notifications
export const useSurveyNotifications = () => {
  const notificationService = NotificationService.getInstance();

  const notifyAssignment = useCallback(async (
    userIds: string[],
    surveyTitle: string,
    surveyId: string,
    assignedBy: string
  ) => {
    await notificationService.notifySurveyAssignment(
      userIds,
      surveyTitle,
      surveyId,
      assignedBy
    );
  }, [notificationService]);

  const notifyReminder = useCallback(async (
    userIds: string[],
    surveyTitle: string,
    surveyId: string,
    dueDate?: Date
  ) => {
    await notificationService.notifySurveyReminder(
      userIds,
      surveyTitle,
      surveyId,
      dueDate
    );
  }, [notificationService]);

  const notifyCompletion = useCallback(async (
    adminUserIds: string[],
    workerName: string,
    surveyTitle: string,
    surveyId: string
  ) => {
    await notificationService.notifySurveyCompletion(
      adminUserIds,
      workerName,
      surveyTitle,
      surveyId
    );
  }, [notificationService]);

  const scheduleReminder = useCallback(async (
    surveyTitle: string,
    surveyId: string,
    reminderDate: Date
  ) => {
    return await notificationService.scheduleReminderNotification(
      surveyTitle,
      surveyId,
      reminderDate
    );
  }, [notificationService]);

  return {
    notifyAssignment,
    notifyReminder,
    notifyCompletion,
    scheduleReminder
  };
};

export default useNotifications;
