import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useNotificationBadge } from '../hooks/useNotifications';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';

interface NotificationBadgeProps {
  onPress: () => void;
  size?: 'small' | 'medium' | 'large';
  color?: string;
  style?: any;
}

const NotificationBadge: React.FC<NotificationBadgeProps> = ({
  onPress,
  size = 'medium',
  color = COLORS.text.primary,
  style
}) => {
  const unreadCount = useNotificationBadge();

  const getIconSize = () => {
    switch (size) {
      case 'small':
        return 20;
      case 'large':
        return 28;
      default:
        return 24;
    }
  };

  const getBadgeSize = () => {
    switch (size) {
      case 'small':
        return { width: 16, height: 16, borderRadius: 8 };
      case 'large':
        return { width: 24, height: 24, borderRadius: 12 };
      default:
        return { width: 20, height: 20, borderRadius: 10 };
    }
  };

  const getTextSize = () => {
    switch (size) {
      case 'small':
        return TYPOGRAPHY.sizes.xs;
      case 'large':
        return TYPOGRAPHY.sizes.sm;
      default:
        return TYPOGRAPHY.sizes.xs;
    }
  };

  return (
    <TouchableOpacity
      style={[styles.container, style]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <MaterialIcons
        name={unreadCount > 0 ? "notifications-active" : "notifications"}
        size={getIconSize()}
        color={color}
      />
      
      {unreadCount > 0 && (
        <View style={[styles.badge, getBadgeSize()]}>
          <Text style={[styles.badgeText, { fontSize: getTextSize() }]}>
            {unreadCount > 99 ? '99+' : unreadCount.toString()}
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'relative',
    padding: SPACING.sm,
  },
  badge: {
    position: 'absolute',
    top: 2,
    right: 2,
    backgroundColor: COLORS.error,
    justifyContent: 'center',
    alignItems: 'center',
    minWidth: 20,
    minHeight: 20,
  },
  badgeText: {
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.bold,
    textAlign: 'center',
  },
});

export default NotificationBadge;
