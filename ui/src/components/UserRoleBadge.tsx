import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { UserRole } from '../types/userManagement';

interface UserRoleBadgeProps {
  role: UserRole;
  size?: 'small' | 'medium' | 'large';
  showIcon?: boolean;
}

const UserRoleBadge: React.FC<UserRoleBadgeProps> = ({
  role,
  size = 'medium',
  showIcon = false
}) => {
  const getRoleConfig = (role: UserRole) => {
    switch (role) {
      case 'admin':
        return {
          color: '#dc2626',
          backgroundColor: '#fee2e2',
          label: 'ADMIN',
          icon: 'admin-panel-settings'
        };
      case 'team_leader':
        return {
          color: '#d97706',
          backgroundColor: '#fef3c7',
          label: 'TEAM LEADER',
          icon: 'supervisor-account'
        };
      case 'worker':
        return {
          color: '#059669',
          backgroundColor: '#d1fae5',
          label: 'WORKER',
          icon: 'work'
        };
      default:
        return {
          color: '#6b7280',
          backgroundColor: '#f3f4f6',
          label: 'UNKNOWN',
          icon: 'person'
        };
    }
  };

  const getSizeStyles = (size: 'small' | 'medium' | 'large') => {
    switch (size) {
      case 'small':
        return {
          paddingHorizontal: 6,
          paddingVertical: 2,
          fontSize: 9,
          iconSize: 12,
          borderRadius: 8,
        };
      case 'large':
        return {
          paddingHorizontal: 12,
          paddingVertical: 6,
          fontSize: 12,
          iconSize: 16,
          borderRadius: 16,
        };
      default: // medium
        return {
          paddingHorizontal: 8,
          paddingVertical: 4,
          fontSize: 10,
          iconSize: 14,
          borderRadius: 12,
        };
    }
  };

  const roleConfig = getRoleConfig(role);
  const sizeStyles = getSizeStyles(size);

  return (
    <View
      style={[
        styles.badge,
        {
          backgroundColor: roleConfig.backgroundColor,
          paddingHorizontal: sizeStyles.paddingHorizontal,
          paddingVertical: sizeStyles.paddingVertical,
          borderRadius: sizeStyles.borderRadius,
        }
      ]}
    >
      {showIcon && (
        <MaterialIcons
          name={roleConfig.icon as any}
          size={sizeStyles.iconSize}
          color={roleConfig.color}
          style={styles.icon}
        />
      )}
      <Text
        style={[
          styles.badgeText,
          {
            color: roleConfig.color,
            fontSize: sizeStyles.fontSize,
          }
        ]}
      >
        {roleConfig.label}
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
  },
  icon: {
    marginRight: 4,
  },
  badgeText: {
    fontWeight: '600',
    textAlign: 'center',
  },
});

export default UserRoleBadge;
