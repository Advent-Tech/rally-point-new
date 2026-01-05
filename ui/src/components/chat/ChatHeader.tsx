import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import Icon from '../Icon';

interface ChatHeaderProps {
  title: string;
  subtitle?: string;
  isOnline?: boolean;
  isGroup?: boolean;
  onBackPress: () => void;
  onInfoPress?: () => void;
  onCallPress?: () => void;
}

const ChatHeader: React.FC<ChatHeaderProps> = ({
  title,
  subtitle,
  isOnline = false,
  isGroup = false,
  onBackPress,
  onInfoPress,
  onCallPress,
}) => {
  return (
    <View style={styles.container}>
      <View style={styles.leftSection}>
        <TouchableOpacity
          style={styles.backButton}
          onPress={onBackPress}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
        >
          <Icon name="arrow-left" size={24} color="#007AFF" />
        </TouchableOpacity>
        
        <View style={styles.avatarContainer}>
          <View style={[styles.avatar, isGroup && styles.groupAvatar]}>
            <Text style={styles.avatarText}>
              {isGroup ? '👥' : title.charAt(0).toUpperCase()}
            </Text>
          </View>
          
          {!isGroup && isOnline && <View style={styles.onlineIndicator} />}
        </View>
        
        <View style={styles.titleContainer}>
          <Text style={styles.title} numberOfLines={1}>
            {title}
          </Text>
          {subtitle && (
            <Text style={styles.subtitle} numberOfLines={1}>
              {subtitle}
            </Text>
          )}
        </View>
      </View>
      
      <View style={styles.rightSection}>
        {onCallPress && (
          <TouchableOpacity
            style={styles.actionButton}
            onPress={onCallPress}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Icon name="phone" size={20} color="#007AFF" />
          </TouchableOpacity>
        )}
        
        {onInfoPress && (
          <TouchableOpacity
            style={styles.actionButton}
            onPress={onInfoPress}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Icon name="info" size={20} color="#007AFF" />
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5E5',
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  leftSection: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  backButton: {
    marginRight: 12,
  },
  avatarContainer: {
    position: 'relative',
    marginRight: 12,
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  groupAvatar: {
    backgroundColor: '#34C759',
  },
  avatarText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  onlineIndicator: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#34C759',
    borderWidth: 2,
    borderColor: '#FFFFFF',
  },
  titleContainer: {
    flex: 1,
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    color: '#000',
    marginBottom: 2,
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
  },
  rightSection: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  actionButton: {
    marginLeft: 16,
    padding: 4,
  },
});

export default ChatHeader;
