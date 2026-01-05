import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Modal,
  Animated,
  Dimensions,
  SafeAreaView,
  ScrollView,
} from 'react-native';
import Icon from './Icon';

const { width, height } = Dimensions.get('window');

interface SlideOutMenuProps {
  visible: boolean;
  onClose: () => void;
  user: any;
  onSignOut: () => void;
  navigation: any;
  isTracking?: boolean;
}

interface MenuItem {
  id: string;
  title: string;
  subtitle?: string;
  icon: string;
  action: string;
  badge?: string;
  divider?: boolean;
}

const SlideOutMenu: React.FC<SlideOutMenuProps> = ({
  visible,
  onClose,
  user,
  onSignOut,
  navigation,
  isTracking = false,
}) => {
  const slideAnim = React.useRef(new Animated.Value(-width)).current;

  React.useEffect(() => {
    if (visible) {
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    } else {
      Animated.timing(slideAnim, {
        toValue: -width,
        duration: 250,
        useNativeDriver: true,
      }).start();
    }
  }, [visible]);

  const menuItems: MenuItem[] = [
    {
      id: 'profile',
      title: 'My Profile',
      subtitle: 'View and edit profile',
      icon: 'user',
      action: 'profile',
    },
    {
      id: 'territory',
      title: 'My Territory',
      subtitle: 'View assigned areas',
      icon: 'map',
      action: 'territory',
    },
    {
      id: 'history',
      title: 'Activity History',
      subtitle: 'View past activities',
      icon: 'history',
      action: 'history',
    },
    {
      id: 'reports',
      title: 'My Reports',
      subtitle: 'View ministry reports',
      icon: 'chart',
      action: 'reports',
    },
    {
      id: 'divider1',
      title: '',
      icon: '',
      action: '',
      divider: true,
    },
    {
      id: 'settings',
      title: 'Settings',
      subtitle: 'App preferences',
      icon: 'settings',
      action: 'settings',
    },
    {
      id: 'help',
      title: 'Help & Support',
      subtitle: 'Get assistance',
      icon: 'help',
      action: 'help',
    },
    {
      id: 'feedback',
      title: 'Send Feedback',
      subtitle: 'Share your thoughts',
      icon: 'feedback',
      action: 'feedback',
    },
    {
      id: 'divider2',
      title: '',
      icon: '',
      action: '',
      divider: true,
    },
    {
      id: 'signout',
      title: 'Sign Out',
      subtitle: 'Logout from app',
      icon: 'logout',
      action: 'signout',
    },
  ];

  const handleMenuItemPress = (action: string) => {
    onClose();
    
    switch (action) {
      case 'profile':
        // Navigate to profile screen
        break;
      case 'territory':
        navigation.navigate('MyTerritory');
        break;
      case 'history':
        navigation.navigate('PathHistory');
        break;
      case 'reports':
        // Navigate to reports screen
        break;
      case 'settings':
        // Navigate to settings screen
        break;
      case 'help':
        // Navigate to help screen
        break;
      case 'feedback':
        // Navigate to feedback screen
        break;
      case 'signout':
        onSignOut();
        break;
      default:
        break;
    }
  };

  if (!visible) return null;

  return (
    <Modal
      transparent
      visible={visible}
      animationType="none"
      onRequestClose={onClose}
    >
      <View style={styles.overlay}>
        <Animated.View
          style={[
            styles.menuContainer,
            {
              transform: [{ translateX: slideAnim }],
            },
          ]}
        >
          <SafeAreaView style={styles.safeArea}>
            {/* Header */}
            <View style={styles.header}>
              <View style={styles.userInfo}>
                <View style={styles.avatar}>
                  <Text style={styles.avatarText}>
                    {user?.displayName?.charAt(0) || 'U'}
                  </Text>
                  <View style={[
                    styles.statusDot,
                    { backgroundColor: isTracking ? '#10b981' : '#ef4444' }
                  ]} />
                </View>
                
                <View style={styles.userDetails}>
                  <Text style={styles.userName}>
                    {user?.displayName || user?.email?.split('@')[0] || 'Ministry Worker'}
                  </Text>
                  <Text style={styles.userRole}>
                    {user?.role === 'worker' ? 'Ministry Worker' :
                     user?.role === 'team_leader' ? 'Team Leader' : 'Administrator'}
                  </Text>
                  <View style={styles.statusContainer}>
                    <View style={[
                      styles.statusIndicator,
                      { backgroundColor: isTracking ? '#10b981' : '#ef4444' }
                    ]} />
                    <Text style={[
                      styles.statusText,
                      { color: isTracking ? '#10b981' : '#ef4444' }
                    ]}>
                      {isTracking ? 'Ministry Active' : 'Offline'}
                    </Text>
                  </View>
                </View>
              </View>
              
              <TouchableOpacity style={styles.closeButton} onPress={onClose}>
                <Icon name="close" size={24} color="#64748b" />
              </TouchableOpacity>
            </View>

            {/* Menu Items */}
            <ScrollView style={styles.menuContent} showsVerticalScrollIndicator={false}>
              {menuItems.map((item) => {
                if (item.divider) {
                  return <View key={item.id} style={styles.divider} />;
                }

                return (
                  <TouchableOpacity
                    key={item.id}
                    style={[
                      styles.menuItem,
                      item.action === 'signout' && styles.signOutItem
                    ]}
                    onPress={() => handleMenuItemPress(item.action)}
                    activeOpacity={0.7}
                  >
                    <View style={[
                      styles.menuIcon,
                      item.action === 'signout' && styles.signOutIcon
                    ]}>
                      <Icon
                        name={item.icon}
                        size={20}
                        color={item.action === 'signout' ? '#ef4444' : '#64748b'}
                      />
                    </View>
                    
                    <View style={styles.menuText}>
                      <Text style={[
                        styles.menuTitle,
                        item.action === 'signout' && styles.signOutTitle
                      ]}>
                        {item.title}
                      </Text>
                      {item.subtitle && (
                        <Text style={styles.menuSubtitle}>{item.subtitle}</Text>
                      )}
                    </View>
                    
                    {item.badge && (
                      <View style={styles.badge}>
                        <Text style={styles.badgeText}>{item.badge}</Text>
                      </View>
                    )}
                    
                    <Icon name="chevron-right" size={16} color="#cbd5e1" />
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
          </SafeAreaView>
        </Animated.View>

        <TouchableOpacity
          style={styles.backdrop}
          activeOpacity={1}
          onPress={onClose}
        />
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    position: 'relative',
  },
  backdrop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'transparent',
  },
  menuContainer: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: width * 0.85,
    maxWidth: 320,
    backgroundColor: '#ffffff',
    shadowColor: '#000',
    shadowOffset: { width: 2, height: 0 },
    shadowOpacity: 0.25,
    shadowRadius: 12,
    elevation: 16,
  },
  safeArea: {
    flex: 1,
  },
  header: {
    backgroundColor: '#1e293b',
    paddingHorizontal: 20,
    paddingVertical: 24,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  userInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  avatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#3b82f6',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
    position: 'relative',
  },
  avatarText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#ffffff',
  },
  statusDot: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 14,
    height: 14,
    borderRadius: 7,
    borderWidth: 2,
    borderColor: '#1e293b',
  },
  userDetails: {
    flex: 1,
  },
  userName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#ffffff',
    marginBottom: 4,
  },
  userRole: {
    fontSize: 14,
    color: '#94a3b8',
    marginBottom: 6,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusIndicator: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginRight: 6,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
  },
  closeButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  menuContent: {
    flex: 1,
    paddingTop: 8,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  signOutItem: {
    borderBottomWidth: 0,
    marginTop: 8,
  },
  menuIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#f8fafc',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  signOutIcon: {
    backgroundColor: '#fef2f2',
  },
  menuText: {
    flex: 1,
  },
  menuTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1e293b',
    marginBottom: 2,
  },
  signOutTitle: {
    color: '#ef4444',
  },
  menuSubtitle: {
    fontSize: 14,
    color: '#64748b',
  },
  badge: {
    backgroundColor: '#ef4444',
    borderRadius: 10,
    paddingHorizontal: 8,
    paddingVertical: 2,
    marginRight: 8,
  },
  badgeText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#ffffff',
  },
  divider: {
    height: 1,
    backgroundColor: '#e2e8f0',
    marginVertical: 8,
    marginHorizontal: 20,
  },
});

export default SlideOutMenu;
