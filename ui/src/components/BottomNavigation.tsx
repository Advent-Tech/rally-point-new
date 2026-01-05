import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Platform,
  Dimensions,
} from 'react-native';
import Icon from './Icon';

const { width } = Dimensions.get('window');

// Brand Colors
const COLORS = {
  primary: '#002b5b', // Navy Blue
  secondary: '#d7a638', // Gold
  white: '#ffffff',
  gray: '#64748b',
  lightGray: '#f1f5f9',
  background: '#f8fafc',
};

interface BottomNavigationProps {
  activeTab: string;
  onTabPress: (tab: string) => void;
  isTracking?: boolean;
}

interface TabItem {
  id: string;
  label: string;
  icon: string;
  activeIcon?: string;
}

const tabs: TabItem[] = [
  {
    id: 'home',
    label: 'Home',
    icon: 'home',
    activeIcon: 'home',
  },
  {
    id: 'map',
    label: 'Territory',
    icon: 'map',
    activeIcon: 'map',
  },
  {
    id: 'activity',
    label: 'Activity',
    icon: 'activity',
    activeIcon: 'activity',
  },
  {
    id: 'profile',
    label: 'Profile',
    icon: 'user',
    activeIcon: 'user',
  },
];

const BottomNavigation: React.FC<BottomNavigationProps> = ({
  activeTab,
  onTabPress,
  isTracking = false,
}) => {
  return (
    <View style={styles.wrapper}>
      <View style={styles.container}>
        {/* Tracking Status Indicator */}
        {isTracking && (
          <View style={styles.trackingIndicator}>
            <View style={styles.trackingDot} />
            <Text style={styles.trackingText}>Ministry Active</Text>
          </View>
        )}

        <View style={styles.tabContainer}>
          {tabs.map((tab) => {
            const isActive = activeTab === tab.id;

            return (
              <TouchableOpacity
                key={tab.id}
                style={styles.tab}
                onPress={() => onTabPress(tab.id)}
                activeOpacity={0.8}
              >
                <View style={[
                  styles.iconContainer,
                  isActive && styles.activeIconContainer
                ]}>
                  <Icon
                    name={isActive ? (tab.activeIcon || tab.icon) : tab.icon}
                    size={22}
                    color={isActive ? COLORS.white : COLORS.gray}
                  />
                </View>

                <Text style={[
                  styles.label,
                  isActive && styles.activeLabel
                ]}>
                  {tab.label}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: '#ffffff',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.1,
    shadowRadius: 12,
    elevation: 12,
    paddingBottom: Platform.OS === 'ios' ? 34 : 20,
  },
  trackingIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    backgroundColor: '#10b981',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  trackingDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: '#ffffff',
    marginRight: 6,
  },
  trackingText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#ffffff',
  },
  tabContainer: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingTop: 16,
  },
  tab: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 8,
    position: 'relative',
  },
  activeTab: {
    // Active tab styling handled by individual elements
  },
  iconContainer: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 4,
  },
  activeIconContainer: {
    backgroundColor: '#f1f5f9',
  },
  label: {
    fontSize: 12,
    fontWeight: '500',
    color: '#64748b',
  },
  activeLabel: {
    color: '#3b82f6',
    fontWeight: '600',
  },
  activeIndicator: {
    position: 'absolute',
    top: 0,
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#3b82f6',
  },
});

export default BottomNavigation;
