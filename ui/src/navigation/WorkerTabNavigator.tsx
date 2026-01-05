import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Dimensions } from 'react-native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

// Import screens
import WorkerDashboardScreen from '../screens/WorkerDashboardScreen';
import CommunityScreen from '../screens/CommunityScreen';
import MyTerritoryScreen from '../screens/MyTerritoryScreenBackend';
import ProfileScreen from '../screens/ProfileScreen';

const Tab = createBottomTabNavigator();
const { width } = Dimensions.get('window');

// Custom Tab Bar matching ModernBottomNavigation design
const CustomTabBar = ({ state, descriptors, navigation }: any) => {
  const insets = useSafeAreaInsets();

  const tabs = [
    { name: 'Home', icon: 'home', activeIcon: 'home' },
    { name: 'Community', icon: 'people-outline', activeIcon: 'people' },
    { name: 'Territory', icon: 'map-outline', activeIcon: 'map' },
    { name: 'Profile', icon: 'person-outline', activeIcon: 'person' },
  ];

  return (
    <View style={[styles.tabBarContainer, { paddingBottom: insets.bottom }]}>
      <View style={styles.tabBarInner}>
        {state.routes.map((route: any, index: number) => {
          const isFocused = state.index === index;
          const tab = tabs[index];

          const onPress = () => {
            const event = navigation.emit({
              type: 'tabPress',
              target: route.key,
              canPreventDefault: true,
            });

            if (!isFocused && !event.defaultPrevented) {
              navigation.navigate(route.name);
            }
          };

          return (
            <TouchableOpacity
              key={route.key}
              onPress={onPress}
              style={[styles.tabButton, isFocused && styles.tabButtonActive]}
              activeOpacity={0.7}
            >
              <View style={[styles.tabIconContainer, isFocused && styles.tabIconContainerActive]}>
                <Ionicons
                  name={isFocused ? tab.activeIcon as any : tab.icon as any}
                  size={22}
                  color={isFocused ? '#FFFFFF' : 'rgba(255,255,255,0.6)'}
                />
              </View>
              <Text style={[styles.tabLabel, isFocused && styles.tabLabelActive]}>
                {tab.name}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
};

const WorkerTabNavigator: React.FC = () => {
  return (
    <Tab.Navigator
      tabBar={(props) => <CustomTabBar {...props} />}
      screenOptions={{
        headerShown: false,
      }}
    >
      <Tab.Screen name="Home" component={WorkerDashboardScreen} />
      <Tab.Screen name="Community" component={CommunityScreen} />
      <Tab.Screen name="Territory" component={MyTerritoryScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
};

const styles = StyleSheet.create({
  tabBarContainer: {
    backgroundColor: '#1a1a2e',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 20,
  },
  tabBarInner: {
    flexDirection: 'row',
    paddingHorizontal: SPACING.md,
    paddingTop: SPACING.md,
    paddingBottom: SPACING.sm,
  },
  tabButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: SPACING.xs,
  },
  tabButtonActive: {},
  tabIconContainer: {
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: 'center',
    alignItems: 'center',
  },
  tabIconContainerActive: {
    backgroundColor: COLORS.primary,
  },
  tabLabel: {
    fontSize: 11,
    fontWeight: '500',
    color: 'rgba(255,255,255,0.6)',
    marginTop: 4,
  },
  tabLabelActive: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
});

export default WorkerTabNavigator;
