import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS } from '../constants/Colors';

interface UserStatusIndicatorProps {
  isOnline: boolean;
  lastActiveAt: Date | string | number | null | undefined;
  size?: 'small' | 'medium' | 'large';
  showText?: boolean;
  showIcon?: boolean;
}

const UserStatusIndicator: React.FC<UserStatusIndicatorProps> = ({
  isOnline,
  lastActiveAt,
  size = 'medium',
  showText = true,
  showIcon = true
}) => {
  const getTimeAgo = (date: Date | string | number | null | undefined): string => {
    if (!date) return 'Unknown';

    try {
      // Convert various date formats to Date object
      let dateObj: Date;

      if (date instanceof Date) {
        dateObj = date;
      } else if (typeof date === 'string') {
        dateObj = new Date(date);
      } else if (typeof date === 'number') {
        dateObj = new Date(date);
      } else if (date && typeof date === 'object' && 'toDate' in date) {
        // Handle Firestore Timestamp
        dateObj = (date as any).toDate();
      } else {
        console.warn('Invalid date format:', date);
        return 'Unknown';
      }

      // Validate the date object
      if (isNaN(dateObj.getTime())) {
        console.warn('Invalid date object:', date);
        return 'Unknown';
      }

      const now = new Date();
      const diffInMinutes = Math.floor((now.getTime() - dateObj.getTime()) / (1000 * 60));

      if (diffInMinutes < 1) return 'Just now';
      if (diffInMinutes < 60) return `${diffInMinutes}m ago`;

      const diffInHours = Math.floor(diffInMinutes / 60);
      if (diffInHours < 24) return `${diffInHours}h ago`;

      const diffInDays = Math.floor(diffInHours / 24);
      if (diffInDays < 7) return `${diffInDays}d ago`;

      return dateObj.toLocaleDateString();
    } catch (error) {
      console.error('Error calculating time ago:', error, 'Date:', date);
      return 'Unknown';
    }
  };

  const getSizeStyles = () => {
    switch (size) {
      case 'small':
        return {
          indicatorSize: 6,
          fontSize: 10,
          iconSize: 12,
          padding: 2,
        };
      case 'large':
        return {
          indicatorSize: 12,
          fontSize: 14,
          iconSize: 18,
          padding: 6,
        };
      default: // medium
        return {
          indicatorSize: 8,
          fontSize: 12,
          iconSize: 14,
          padding: 4,
        };
    }
  };

  const sizeStyles = getSizeStyles();
  const statusColor = isOnline ? '#10b981' : '#6b7280';
  const statusText = isOnline ? 'Online' : `Last seen ${getTimeAgo(lastActiveAt)}`;

  return (
    <View style={[styles.container, { padding: sizeStyles.padding }]}>
      {showIcon && (
        <View style={styles.iconContainer}>
          <MaterialIcons
            name={isOnline ? 'circle' : 'radio-button-unchecked'}
            size={sizeStyles.iconSize}
            color={statusColor}
          />
        </View>
      )}
      
      <View
        style={[
          styles.indicator,
          {
            width: sizeStyles.indicatorSize,
            height: sizeStyles.indicatorSize,
            backgroundColor: statusColor,
          }
        ]}
      />
      
      {showText && (
        <Text
          style={[
            styles.statusText,
            {
              fontSize: sizeStyles.fontSize,
              color: statusColor,
            }
          ]}
        >
          {statusText}
        </Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  iconContainer: {
    marginRight: 2,
  },
  indicator: {
    borderRadius: 50,
  },
  statusText: {
    fontWeight: '500',
    marginLeft: 4,
  },
});

export default UserStatusIndicator;
