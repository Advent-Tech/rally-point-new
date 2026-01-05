import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { useAuth } from '../contexts/AuthContext';
import AdminDashboardScreen from '../screens/AdminDashboardScreen';
import TeamLeaderDashboardScreen from '../screens/TeamLeaderDashboardScreen';
import WorkerTabNavigator from './WorkerTabNavigator';
import TestScrollScreen from '../screens/TestScrollScreen';
import DeliveryTrackingScreen from '../screens/DeliveryTrackingScreen';
import LocationTrackingScreen from '../screens/LocationTrackingScreen';
import GamificationScreen from '../screens/GamificationScreen';
import BookDeliveryScreen from '../screens/BookDeliveryScreen';
import AdminDeliveryMapScreen from '../screens/AdminDeliveryMapScreen';
import AdminWorkerTrackingScreen from '../screens/AdminWorkerTrackingScreen';
import AdminLiveMapScreen from '../screens/AdminLiveMapScreen';
import TerritoryManagementScreen from '../screens/TerritoryManagementScreen';
import GeoTerritoryMapScreen from '../screens/GeoTerritoryMapScreen';
import TeamLeaderTerritoryAssignmentScreen from '../screens/TeamLeaderTerritoryAssignmentScreen';
import PathHistoryScreen from '../screens/PathHistoryScreen';
import WorkerAnalyticsScreen from '../screens/WorkerAnalyticsScreen';
import SurveyBuilderScreen from '../screens/SurveyBuilderScreen';
import SurveyManagementScreen from '../screens/SurveyManagementScreen';
import SurveyAssignmentScreen from '../screens/SurveyAssignmentScreen';
import SurveysScreen from '../screens/SurveysScreen';
import SurveyFormScreen from '../screens/SurveyFormScreen';
import SurveyResponsesScreen from '../screens/SurveyResponsesScreen';
import NotificationsScreen from '../screens/NotificationsScreen';
import MinistryContactScreen from '../screens/MinistryContactScreen';
import MinistryContactListScreen from '../screens/MinistryContactListScreen';
import HeaderDemoScreen from '../screens/HeaderDemoScreen';
import UIShowcaseScreen from '../screens/UIShowcaseScreen';
import UserProfileHeaderDemo from '../screens/UserProfileHeaderDemo';
import MessagingScreen from '../screens/MessagingScreen';
import ChatScreen from '../screens/ChatScreen';
import GroupChatScreen from '../screens/GroupChatScreen';
import EditProfileScreen from '../screens/EditProfileScreen';
import ChangePasswordScreen from '../screens/ChangePasswordScreen';
import NotificationSettingsScreen from '../screens/NotificationSettingsScreen';
import HelpSupportScreen from '../screens/HelpSupportScreen';
import AdminUserManagementScreen from '../screens/AdminUserManagementScreen';
import AdminBookAssignmentScreen from '../screens/AdminBookAssignmentScreen';
import SessionReportsScreen from '../screens/SessionReportsScreen';
import SessionDetailsScreen from '../screens/SessionDetailsScreen';
// Team Leader Screens
import TeamLeaderWorkerTrackingScreen from '../screens/TeamLeaderWorkerTrackingScreen';
import TeamLeaderSurveyManagementScreen from '../screens/TeamLeaderSurveyManagementScreen';
import TeamLeaderWorkerManagementScreen from '../screens/TeamLeaderWorkerManagementScreen';
import TeamLeaderDeliveryManagementScreen from '../screens/TeamLeaderDeliveryManagementScreen';
// Team Management Screens
import JoinTeamScreen from '../screens/JoinTeamScreen';
import AdminTeamManagementScreen from '../screens/AdminTeamManagementScreen';
// Worker Detail Screens
import WorkerDetailScreen from '../screens/WorkerDetailScreen';
import WorkerPathMapScreen from '../screens/WorkerPathMapScreen';
import { MainStackParamList } from '../types';

const Stack = createStackNavigator<MainStackParamList>();

const MainNavigator: React.FC = () => {
  const { user } = useAuth();

  // Debug logging to identify the routing issue
  console.log('🔍 MainNavigator - Current user object:', JSON.stringify(user, null, 2));
  console.log('🔍 MainNavigator - User role:', user?.role, 'Type:', typeof user?.role);

  // If no user, return a fallback (this shouldn't happen, but just in case)
  if (!user) {
    console.log('❌ MainNavigator - No user found, showing WorkerTabs fallback');
    return (
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        <Stack.Screen name="WorkerTabs" component={WorkerTabNavigator} />
      </Stack.Navigator>
    );
  }

  // Normalize role check (handle potential case sensitivity or undefined)
  const userRole = user.role?.toLowerCase?.() || 'worker';
  const initialRoute = userRole === 'admin' ? 'AdminDashboard' :
                      userRole === 'team_leader' ? 'TeamLeaderDashboard' :
                      'WorkerTabs';

  console.log('🎯 MainNavigator - Routing to:', initialRoute, 'based on normalized role:', userRole);

  // Use key to force remount when user role changes (fixes navigation caching issue)
  const navigatorKey = `main-nav-${user.id || 'unknown'}-${userRole}`;

  return (
    <Stack.Navigator
      key={navigatorKey}
      screenOptions={{
        headerShown: false,
      }}
      initialRouteName={initialRoute}
    >
      {/* Admin Screens */}
      <Stack.Screen name="AdminDashboard" component={AdminDashboardScreen} />
      <Stack.Screen name="AdminDeliveryMap" component={AdminDeliveryMapScreen} />
      <Stack.Screen name="AdminWorkerTracking" component={AdminWorkerTrackingScreen} />
      <Stack.Screen name="AdminLiveMap" component={AdminLiveMapScreen} />
      <Stack.Screen name="AdminUserManagement" component={AdminUserManagementScreen} />
      <Stack.Screen name="AdminBookAssignment" component={AdminBookAssignmentScreen} />
      <Stack.Screen name="AdminTeamManagement" component={AdminTeamManagementScreen} />

      {/* Team Leader Screens */}
      <Stack.Screen name="TeamLeaderDashboard" component={TeamLeaderDashboardScreen} />
      <Stack.Screen name="TeamLeaderWorkerTracking" component={TeamLeaderWorkerTrackingScreen} />
      <Stack.Screen name="TeamLeaderSurveyManagement" component={TeamLeaderSurveyManagementScreen} />
      <Stack.Screen name="TeamLeaderWorkerManagement" component={TeamLeaderWorkerManagementScreen} />
      <Stack.Screen name="TeamLeaderDeliveryManagement" component={TeamLeaderDeliveryManagementScreen} />
      <Stack.Screen name="TeamLeaderTerritoryAssignment" component={TeamLeaderTerritoryAssignmentScreen} />

      {/* Worker Detail Screens */}
      <Stack.Screen name="WorkerDetail" component={WorkerDetailScreen} />
      <Stack.Screen name="WorkerPathMap" component={WorkerPathMapScreen} />

      {/* Worker Tab Navigator */}
      <Stack.Screen name="WorkerTabs" component={WorkerTabNavigator} />

      {/* Worker Sub-screens (opened from tabs) */}
      <Stack.Screen name="DeliveryTracking" component={DeliveryTrackingScreen} />
      <Stack.Screen name="LocationTracking" component={LocationTrackingScreen} />
      <Stack.Screen name="Gamification" component={GamificationScreen} />
      <Stack.Screen name="BookDelivery" component={BookDeliveryScreen} />
      <Stack.Screen name="PathHistory" component={PathHistoryScreen} />
      <Stack.Screen name="WorkerAnalytics" component={WorkerAnalyticsScreen} />
      <Stack.Screen name="JoinTeam" component={JoinTeamScreen} />

      {/* Shared Screens */}
      <Stack.Screen name="TerritoryManagement" component={TerritoryManagementScreen} />
      <Stack.Screen name="GeoTerritoryMap" component={GeoTerritoryMapScreen} />
      {/* Survey Screens */}
      <Stack.Screen name="SurveyBuilder" component={SurveyBuilderScreen} />
      <Stack.Screen name="SurveyManagement" component={SurveyManagementScreen} />
      <Stack.Screen name="SurveyAssignment" component={SurveyAssignmentScreen} />
      <Stack.Screen name="Surveys" component={SurveysScreen} />
      <Stack.Screen name="SurveyForm" component={SurveyFormScreen} />
      <Stack.Screen name="SurveyResponses" component={SurveyResponsesScreen} />
      <Stack.Screen name="Notifications" component={NotificationsScreen} />
      {/* Ministry Contact Screens */}
      <Stack.Screen name="MinistryContact" component={MinistryContactScreen} />
      <Stack.Screen name="MinistryContactList" component={MinistryContactListScreen} />
      {/* Messaging Screens */}
      <Stack.Screen name="Messaging" component={MessagingScreen} />
      <Stack.Screen name="Chat" component={ChatScreen} />
      <Stack.Screen name="GroupChat" component={GroupChatScreen} />
      {/* Profile Sub-screens */}
      <Stack.Screen name="EditProfile" component={EditProfileScreen} />
      <Stack.Screen name="ChangePassword" component={ChangePasswordScreen} />
      <Stack.Screen name="NotificationSettings" component={NotificationSettingsScreen} />
      <Stack.Screen name="HelpSupport" component={HelpSupportScreen} />
      {/* Session Reports Screens */}
      <Stack.Screen name="SessionReports" component={SessionReportsScreen} />
      <Stack.Screen name="SessionDetails" component={SessionDetailsScreen} />
      {/* Demo Screens */}
      <Stack.Screen name="HeaderDemo" component={HeaderDemoScreen} />
      <Stack.Screen name="UIShowcase" component={UIShowcaseScreen} />
    </Stack.Navigator>
  );
};

export default MainNavigator;
