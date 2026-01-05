import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  Platform,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface UserProfileHeaderProps {
  userImage?: string;
  userName: string;
  territoryName: string;
  teamName?: string;
  isActive: boolean;
  style?: any;
}

const UserProfileHeader: React.FC<UserProfileHeaderProps> = ({
  userImage,
  userName,
  territoryName,
  teamName,
  isActive,
  style,
}) => {
  return (
    <View style={[styles.container, style]}>
      {/* Left Side - User Profile Section */}
      <View style={styles.userSection}>
        {/* Circular Avatar */}
        <View style={styles.avatarContainer}>
          {userImage ? (
            <Image
              source={{ uri: userImage }}
              style={styles.avatarImage}
              resizeMode="cover"
            />
          ) : (
            <View style={styles.avatarPlaceholder}>
              <Text style={styles.avatarInitial}>
                {userName?.charAt(0)?.toUpperCase() || 'U'}
              </Text>
            </View>
          )}
        </View>
        
        {/* User Info */}
        <View style={styles.userInfo}>
          <Text style={styles.userName}>{userName}</Text>
          <Text style={styles.territoryName}>{territoryName}</Text>
          <Text style={styles.teamName}>{teamName || 'No Team Assigned'}</Text>
        </View>
      </View>
      
      {/* Right Side - Status Section */}
      <View style={styles.statusSection}>
        <View style={[
          styles.statusIndicator,
          { backgroundColor: isActive ? '#10b981' : '#6b7280' }
        ]} />
        <Text style={[
          styles.statusText,
          { color: isActive ? '#10b981' : '#6b7280' }
        ]}>
          {isActive ? 'Active' : 'Offline'}
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 12,
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
    borderRadius: 16,
    ...SHADOWS.lg,
    ...(Platform.OS === 'web' && {
      backdropFilter: 'blur(10px)',
    }),
  },
  
  // Left Side - User Profile Section
  userSection: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  
  avatarContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    marginRight: 12,
    overflow: 'hidden',
    backgroundColor: '#f3f4f6',
  },
  
  avatarImage: {
    width: '100%',
    height: '100%',
  },

  avatarPlaceholder: {
    width: '100%',
    height: '100%',
    backgroundColor: COLORS.white,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.lightGray,
  },

  avatarInitial: {
    color: COLORS.primary,
    fontSize: 18,
    fontWeight: TYPOGRAPHY.weights.bold,
  },

  userInfo: {
    justifyContent: 'center',
    flex: 1,
  },
  
  userName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#000',
    marginBottom: 2,
  },
  
  territoryName: {
    fontSize: 12,
    color: '#666',
    fontWeight: '400',
    marginBottom: 1,
  },

  teamName: {
    fontSize: 11,
    color: COLORS.secondary, // Gold color for team name
    fontWeight: '500',
    fontStyle: 'italic',
  },
  
  // Right Side - Status Section
  statusSection: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  
  statusIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 6,
  },
  
  statusText: {
    fontSize: 14,
    fontWeight: '500',
  },
});

export default UserProfileHeader;
