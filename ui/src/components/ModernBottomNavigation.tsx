import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Platform,
  SafeAreaView,
} from 'react-native';
import { HomeIcon, MapIcon, CommunityIcon, AnalyticsIcon } from './icons/BottomNavIcons';

// Brand Colors
const COLORS = {
  primary: '#002b5b',      // Navy Blue
  secondary: '#d7a638',    // Gold
  white: '#ffffff',
  lightGray: '#f1f5f9',
  darkGray: '#64748b',
  background: '#ffffff',
  shadow: 'rgba(0, 43, 91, 0.1)',
  // New colors for pill design
  pillBackground: '#2d3748', // Dark background
  activeBackground: '#ffffff', // White pill background
  inactiveIcon: '#ffffff', // White icons for inactive
  activeIcon: '#2d3748', // Dark icon for active
  activeText: '#2d3748', // Dark text for active
};

interface TabItem {
  key: string;
  label: string;
  icon: string;
  svgIcon: 'home' | 'map' | 'community' | 'analytics'; // SVG icon type
}

interface ModernBottomNavigationProps {
  activeTab: string;
  onTabPress: (tab: string) => void;
  tabs?: TabItem[];
}

const defaultTabs: TabItem[] = [
  { key: 'home', label: 'Home', icon: 'home', svgIcon: 'home' },
  { key: 'territory', label: 'Territory', icon: 'map', svgIcon: 'map' },
  { key: 'community', label: 'Community', icon: 'people', svgIcon: 'community' },
  { key: 'analytics', label: 'Analytics', icon: 'analytics', svgIcon: 'analytics' },
];

const ModernBottomNavigation: React.FC<ModernBottomNavigationProps> = ({
  activeTab,
  onTabPress,
  tabs = defaultTabs,
}) => {
  const handleTabPress = (tabKey: string) => {
    console.log('ModernBottomNavigation: Tab pressed:', tabKey);
    onTabPress(tabKey);
  };

  const renderSvgIcon = (svgIcon: string, color: string, size: number = 24) => {
    switch (svgIcon) {
      case 'home':
        return <HomeIcon size={size} color={color} />;
      case 'map':
        return <MapIcon size={size} color={color} />;
      case 'community':
        return <CommunityIcon size={size} color={color} />;
      case 'analytics':
        return <AnalyticsIcon size={size} color={color} />;
      default:
        return <HomeIcon size={size} color={color} />;
    }
  };

  const renderTab = (tab: TabItem) => {
    const isActive = activeTab === tab.key;

    if (isActive) {
      // Active tab with pill background
      return (
        <TouchableOpacity
          key={tab.key}
          style={styles.activeTabContainer}
          onPress={() => handleTabPress(tab.key)}
          activeOpacity={0.8}
        >
          {renderSvgIcon(tab.svgIcon, COLORS.activeIcon, 24)}
          <Text style={styles.activeTabLabel}>{tab.label}</Text>
        </TouchableOpacity>
      );
    } else {
      // Inactive tab with circular background
      return (
        <TouchableOpacity
          key={tab.key}
          style={styles.inactiveTabContainer}
          onPress={() => handleTabPress(tab.key)}
          activeOpacity={0.8}
        >
          {renderSvgIcon(tab.svgIcon, COLORS.inactiveIcon, 24)}
        </TouchableOpacity>
      );
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.navigationBar}>
        {tabs.map(renderTab)}
      </View>
      {Platform.OS === 'ios' && <SafeAreaView />}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingBottom: Platform.OS === 'ios' ? 34 : 20,
    paddingHorizontal: 20,
    backgroundColor: 'transparent',
    alignItems: 'center',
  },
  navigationBar: {
    flexDirection: 'row',
    backgroundColor: COLORS.pillBackground, // Dark background
    borderRadius: 50, // Pill shape
    paddingVertical: 12,
    paddingHorizontal: 16,
    alignItems: 'center',
    justifyContent: 'space-between',
    shadowColor: '#000000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
    minHeight: 60,
    gap: 8, // Space between items
  },
  // Active tab with pill background and text
  activeTabContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.activeBackground, // White background
    borderRadius: 25, // Pill shape
    paddingVertical: 12,
    paddingHorizontal: 20,
    gap: 8, // Space between icon and text
    minWidth: 120, // Ensure adequate width for text
  },
  activeTabLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.activeText, // Dark text
  },
  // Inactive tab with circular background
  inactiveTabContainer: {
    width: 48,
    height: 48,
    borderRadius: 24, // Perfect circle
    backgroundColor: '#3B485D', // No background for inactive
    alignItems: 'center',
    justifyContent: 'center',
  },
});

export default ModernBottomNavigation;
