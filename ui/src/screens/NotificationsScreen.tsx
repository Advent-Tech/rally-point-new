import React, { useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  RefreshControl,
  Alert,
  Platform
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { Header } from '../components';
import { useNotifications } from '../hooks/useNotifications';
import { SurveyNotification } from '../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface NotificationsScreenProps {
  navigation: any;
}

const NotificationsScreen: React.FC<NotificationsScreenProps> = ({ navigation }) => {
  const [notificationState, notificationActions] = useNotifications();

  useEffect(() => {
    // Mark all notifications as read when screen is opened
    const unsubscribe = navigation.addListener('focus', () => {
      if (notificationState.unreadCount > 0) {
        setTimeout(() => {
          notificationActions.markAllAsRead();
        }, 1000); // Delay to let user see the notifications first
      }
    });

    return unsubscribe;
  }, [navigation, notificationState.unreadCount, notificationActions]);

  const getNotificationIcon = (type: string): string => {
    switch (type) {
      case 'assignment':
        return 'assignment';
      case 'reminder':
        return 'schedule';
      case 'completion':
        return 'check-circle';
      default:
        return 'notifications';
    }
  };

  const getNotificationColor = (type: string): string => {
    switch (type) {
      case 'assignment':
        return COLORS.primary;
      case 'reminder':
        return COLORS.warning;
      case 'completion':
        return COLORS.success;
      default:
        return COLORS.text.secondary;
    }
  };

  const handleNotificationPress = (notification: SurveyNotification) => {
    // Mark as read if not already
    if (!notification.readAt) {
      notificationActions.markAsRead(notification.id);
    }

    // Navigate based on notification type
    switch (notification.type) {
      case 'assignment':
      case 'reminder':
        navigation.navigate('SurveyForm', { surveyId: notification.surveyId });
        break;
      case 'completion':
        navigation.navigate('SurveyResponses', { surveyId: notification.surveyId });
        break;
      default:
        break;
    }
  };

  const formatTimeAgo = (date: Date): string => {
    const now = new Date();
    const diffInMinutes = Math.floor((now.getTime() - date.getTime()) / (1000 * 60));

    if (diffInMinutes < 1) return 'Just now';
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    
    const diffInHours = Math.floor(diffInMinutes / 60);
    if (diffInHours < 24) return `${diffInHours}h ago`;
    
    const diffInDays = Math.floor(diffInHours / 24);
    if (diffInDays < 7) return `${diffInDays}d ago`;
    
    return date.toLocaleDateString();
  };

  const renderNotificationItem = ({ item: notification }: { item: SurveyNotification }) => {
    const isUnread = !notification.readAt;
    const iconName = getNotificationIcon(notification.type);
    const iconColor = getNotificationColor(notification.type);

    return (
      <TouchableOpacity
        style={[
          styles.notificationItem,
          isUnread && styles.unreadNotification
        ]}
        onPress={() => handleNotificationPress(notification)}
        activeOpacity={0.7}
      >
        <View style={styles.notificationIcon}>
          <MaterialIcons name={iconName as any} size={24} color={iconColor} />
          {isUnread && <View style={styles.unreadDot} />}
        </View>

        <View style={styles.notificationContent}>
          <Text style={[
            styles.notificationMessage,
            isUnread && styles.unreadText
          ]}>
            {notification.message}
          </Text>
          
          <View style={styles.notificationMeta}>
            <Text style={styles.notificationTime}>
              {formatTimeAgo(notification.sentAt)}
            </Text>
            
            {notification.surveyTitle && (
              <Text style={styles.surveyTitle} numberOfLines={1}>
                • {notification.surveyTitle}
              </Text>
            )}
          </View>
        </View>

        <MaterialIcons 
          name="chevron-right" 
          size={20} 
          color={COLORS.text.secondary} 
        />
      </TouchableOpacity>
    );
  };

  const handleClearAll = () => {
    Alert.alert(
      'Clear All Notifications',
      'Are you sure you want to mark all notifications as read?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear All',
          onPress: () => notificationActions.markAllAsRead()
        }
      ]
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title="Notifications"
        showBackButton
        onBackPress={() => navigation.goBack()}
        rightComponent={
          notificationState.unreadCount > 0 ? (
            <TouchableOpacity onPress={handleClearAll} style={styles.clearButton}>
              <Text style={styles.clearButtonText}>Clear All</Text>
            </TouchableOpacity>
          ) : null
        }
      />

      <View style={styles.content}>
        {/* Unread Count Header */}
        {notificationState.unreadCount > 0 && (
          <View style={styles.unreadHeader}>
            <MaterialIcons name="notifications-active" size={20} color={COLORS.primary} />
            <Text style={styles.unreadHeaderText}>
              {notificationState.unreadCount} unread notification{notificationState.unreadCount > 1 ? 's' : ''}
            </Text>
          </View>
        )}

        {/* Notifications List */}
        <FlatList
          data={notificationState.notifications}
          keyExtractor={(item) => item.id}
          renderItem={renderNotificationItem}
          refreshControl={
            <RefreshControl
              refreshing={notificationState.loading}
              onRefresh={notificationActions.refreshNotifications}
            />
          }
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.notificationsList}
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <MaterialIcons name="notifications-none" size={64} color={COLORS.text.secondary} />
              <Text style={styles.emptyStateText}>No notifications</Text>
              <Text style={styles.emptyStateSubtext}>
                You'll see survey assignments and updates here
              </Text>
              
              {/* Test Notification Button (for development) */}
              {__DEV__ && Platform.OS !== 'web' && (
                <TouchableOpacity
                  style={styles.testButton}
                  onPress={notificationActions.sendTestNotification}
                >
                  <Text style={styles.testButtonText}>Send Test Notification</Text>
                </TouchableOpacity>
              )}
            </View>
          }
        />
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  content: {
    flex: 1,
  },
  clearButton: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
  },
  clearButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  unreadHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.primary + '10',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  unreadHeaderText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.primary,
    marginLeft: SPACING.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  notificationsList: {
    paddingBottom: SPACING.xl,
  },
  notificationItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.surface,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  unreadNotification: {
    backgroundColor: COLORS.primary + '05',
    borderLeftWidth: 4,
    borderLeftColor: COLORS.primary,
  },
  notificationIcon: {
    position: 'relative',
    marginRight: SPACING.md,
  },
  unreadDot: {
    position: 'absolute',
    top: -2,
    right: -2,
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.error,
  },
  notificationContent: {
    flex: 1,
  },
  notificationMessage: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    lineHeight: 20,
    marginBottom: SPACING.xs,
  },
  unreadText: {
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  notificationMeta: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  notificationTime: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  surveyTitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.sm,
    flex: 1,
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
  testButton: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    marginTop: SPACING.lg,
  },
  testButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
});

export default NotificationsScreen;
