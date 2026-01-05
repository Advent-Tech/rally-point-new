import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Platform,
  StatusBar,
  SafeAreaView,
  Animated,
  Dimensions,
  Alert,
  RefreshControl,
  Modal
} from 'react-native';
import { FontAwesome, MaterialIcons, Feather } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { SurveyService } from '../services/SurveyService';
import { UserManagementService } from '../services/UserManagementService';
import { territoryService } from '../services/TerritoryService';
import { DeliveryService } from '../services/DeliveryService';
import { AnalyticsService } from '../services/AnalyticsService';
import { RealtimeLocationService } from '../services/RealtimeLocationService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { resetAppToFreshInstall } from '../utils/appReset';
import LiveLocationMap from '../components/LiveLocationMap';
import Header from '../components/Header';

const { width, height } = Dimensions.get('window');

// Modern Overview Card Component
const OverviewCard: React.FC<OverviewCardProps> = ({
  title,
  value,
  unit,
  subtitle,
  trend,
  trendValue,
  icon,
  color,
  onMenuPress,
}) => {
  const getTrendIcon = () => {
    switch (trend) {
      case 'up': return 'trending-up';
      case 'down': return 'trending-down';
      default: return 'trending-flat';
    }
  };

  const getTrendColor = () => {
    switch (trend) {
      case 'up': return COLORS.success;
      case 'down': return COLORS.error;
      default: return COLORS.text.secondary;
    }
  };

  return (
    <View style={styles.overviewCard}>
      {/* Header with Icon and Menu */}
      <View style={styles.cardHeader}>
        <View style={[styles.cardIconContainer, { backgroundColor: `${color}15` }]}>
          <MaterialIcons name={icon as any} size={24} color={color} />
        </View>
        <TouchableOpacity 
          style={styles.cardMenuButton}
          onPress={onMenuPress}
          activeOpacity={0.7}
        >
          <MaterialIcons name="more-horiz" size={20} color={COLORS.text.secondary} />
        </TouchableOpacity>
      </View>

      {/* Main Content */}
      <View style={styles.cardContent}>
        <Text style={styles.cardTitle}>{title}</Text>
        <View style={styles.cardValueContainer}>
          <Text style={styles.cardValue}>{value}</Text>
          <Text style={styles.cardUnit}>{unit}</Text>
        </View>
        <Text style={styles.cardSubtitle}>{subtitle}</Text>
        
        {/* Trend Indicator */}
        <View style={styles.trendContainer}>
          <MaterialIcons 
            name={getTrendIcon() as any} 
            size={16} 
            color={getTrendColor()} 
          />
          <Text style={[styles.trendText, { color: getTrendColor() }]}>
            {trendValue}
          </Text>
        </View>
      </View>
    </View>
  );
};

interface DashboardStats {
  totalWorkers: number;        // Users with role 'worker'
  activeWorkers: number;       // Workers currently tracking location
  totalUsers: number;
  totalTerritories: number;
  todayDeliveries: number;
  totalDeliveries: number;
  completedSurveys: number;
  onlineUsers: number;
  totalTeams: number;
  recentSignups: number;
  usersByRole: {
    admin: number;
    team_leader: number;
    worker: number;
  };
}

interface OverviewCardProps {
  title: string;
  value: string;
  unit: string;
  subtitle: string;
  trend: 'up' | 'down' | 'neutral';
  trendValue: string;
  icon: string;
  color: string;
  onMenuPress?: () => void;
}

interface AdminDashboardScreenProps {
  navigation: any;
}

const AdminDashboardScreen: React.FC<AdminDashboardScreenProps> = ({ navigation }) => {
  const { user, signOut } = useAuth();
  
  // Debug logging
  console.log('🔴 AdminDashboardScreen rendered');
  console.log('🔴 Current user:', user);
  console.log('🔴 User role:', user?.role);
  
  const [refreshing, setRefreshing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [animationsReady, setAnimationsReady] = useState(false);
  const [showLiveMap, setShowLiveMap] = useState(false);
  const [selectedWorker, setSelectedWorker] = useState<any>(null);
  const [stats, setStats] = useState<DashboardStats>({
    totalWorkers: 0,        // Users with role 'worker'
    activeWorkers: 0,       // Workers currently tracking location
    totalUsers: 0,
    totalTerritories: 0,
    todayDeliveries: 0,
    totalDeliveries: 0,
    completedSurveys: 0,
    onlineUsers: 0,
    totalTeams: 0,
    recentSignups: 0,
    usersByRole: {
      admin: 0,
      team_leader: 0,
      worker: 0,
    }
  });

  // Animation values - use useRef to prevent recreation on re-renders
  const fadeAnim = React.useRef(new Animated.Value(0)).current;
  const slideAnim = React.useRef(new Animated.Value(50)).current;

  useEffect(() => {
    console.log('AdminDashboard: Starting animations...');

    // Set animations ready immediately as fallback
    setAnimationsReady(true);

    // Start animations
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 1000,
        useNativeDriver: true,
      }),
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 800,
        useNativeDriver: true,
      }),
    ]).start(() => {
      console.log('AdminDashboard: Animations completed');
    });

    // Load dashboard data
    loadDashboardData();
  }, []);

  const getTimeOfDay = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  };

  const adminFeatures = [
    {
      id: 'user-management',
      title: 'User Management',
      description: 'Manage workers, teams, and permissions',
      icon: 'people',
      iconType: 'MaterialIcons',
      color: COLORS.primary,
      route: 'AdminUserManagement',
      badge: null,
    },
    {
      id: 'territory-management',
      title: 'Territory Management',
      description: 'Assign and manage territories',
      icon: 'map',
      iconType: 'MaterialIcons',
      color: COLORS.success,
      route: 'TerritoryManagement',
      badge: null,
    },
    {
      id: 'geo-territory-map',
      title: 'Geo Territory Map',
      description: 'View church territories on map',
      icon: 'public',
      iconType: 'MaterialIcons',
      color: '#0891b2',
      route: 'GeoTerritoryMap',
      badge: null,
    },
    {
      id: 'live-tracking',
      title: 'Live Worker Tracking',
      description: 'Monitor active workers in real-time',
      icon: 'location-on',
      iconType: 'MaterialIcons',
      color: COLORS.info,
      route: 'AdminWorkerTracking',
      badge: stats.onlineUsers > 0 ? stats.onlineUsers.toString() : null,
    },
    {
      id: 'delivery-management',
      title: 'Delivery Management',
      description: 'Track and manage book deliveries',
      icon: 'local-shipping',
      iconType: 'MaterialIcons',
      color: COLORS.warning,
      route: 'AdminDeliveryMap',
      badge: null,
    },
    {
      id: 'book-assignment',
      title: 'Book Assignment',
      description: 'Assign books to workers',
      icon: 'library-books',
      iconType: 'MaterialIcons',
      color: '#8b5cf6',
      route: 'AdminBookAssignment',
      badge: null,
    },
    {
      id: 'survey-management',
      title: 'Survey Management',
      description: 'Create and manage surveys',
      icon: 'assignment',
      iconType: 'MaterialIcons',
      color: COLORS.secondary,
      route: 'SurveyManagement',
      badge: null,
    },
    {
      id: 'reports',
      title: 'Reports & Analytics',
      description: 'View detailed reports and analytics',
      icon: 'bar-chart',
      iconType: 'MaterialIcons',
      color: COLORS.error,
      route: 'Reports',
      badge: null,
    },
  ];

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      console.log('📊 Loading dashboard data...');

      // Initialize stats object
      let newStats = {
        totalWorkers: 0,        // Users with role 'worker'
        activeWorkers: 0,       // Workers currently tracking location
        totalUsers: 0,
        totalTerritories: 0,
        todayDeliveries: 0,
        totalDeliveries: 0,
        completedSurveys: 0,
        onlineUsers: 0,
        totalTeams: 0,
        recentSignups: 0,
        usersByRole: {
          admin: 0,
          team_leader: 0,
          worker: 0,
        }
      };

      // Load user management stats
      try {
        console.log('🔍 Loading user management stats...');
        const userStatsResponse = await UserManagementService.getUserManagementStats();
        console.log('📊 User stats response:', userStatsResponse);

        if (userStatsResponse.success && userStatsResponse.data) {
          const userStats = userStatsResponse.data;
          console.log('✅ User stats data:', userStats);

          newStats.totalWorkers = userStats.usersByRole?.worker || 0;  // Total users with role 'worker'
          newStats.totalUsers = userStats.totalUsers || 0;
          newStats.onlineUsers = userStats.onlineUsers || 0;
          newStats.totalTeams = userStats.totalTeams || 0;
          newStats.recentSignups = userStats.recentSignups || 0;
          newStats.usersByRole = userStats.usersByRole || { admin: 0, team_leader: 0, worker: 0 };
        } else {
          console.log('⚠️ User stats response not successful or no data');
        }
      } catch (userError) {
        console.error('❌ Error loading user stats:', userError);
      }

      // Load territories
      try {
        console.log('🔍 Loading territories...');
        const territories = await territoryService.getAllTerritories();
        console.log('📊 Territories loaded:', territories.length);
        newStats.totalTerritories = territories.length;
      } catch (territoryError) {
        console.error('❌ Error loading territories:', territoryError);
      }

      // Load delivery stats
      try {
        console.log('🔍 Loading delivery stats...');
        const deliveryStats = await DeliveryService.getAllDeliveries();
        console.log('📊 Deliveries loaded:', deliveryStats.length);

        const todayDeliveries = deliveryStats.filter(delivery => {
          const deliveryDate = new Date(delivery.deliveryTime?.seconds * 1000 || delivery.deliveryTime);
          const today = new Date();
          return deliveryDate.toDateString() === today.toDateString();
        });

        newStats.totalDeliveries = deliveryStats.length;
        newStats.todayDeliveries = todayDeliveries.length;
        console.log('📊 Today deliveries:', todayDeliveries.length);
      } catch (deliveryError) {
        console.error('❌ Error loading deliveries:', deliveryError);
      }

      // Load survey stats
      try {
        console.log('🔍 Loading survey stats...');
        const surveys = await SurveyService.getSurveys();
        console.log('📊 Surveys loaded:', surveys.length);

        // Get total responses across all surveys
        let totalResponses = 0;
        for (const survey of surveys) {
          try {
            const responses = await SurveyService.getSurveyResponses(survey.id);
            totalResponses += responses.length;
          } catch (responseError) {
            console.log('⚠️ Could not load responses for survey:', survey.id);
          }
        }

        console.log('📊 Total survey responses:', totalResponses);
        newStats.completedSurveys = totalResponses;
      } catch (surveyError) {
        console.error('❌ Error loading surveys:', surveyError);
        // Survey service might not be available, continue without it
      }

      // Load active workers (currently tracking location)
      try {
        console.log('🔍 Loading active workers from realtime tracking...');
        const realtimeLocationService = new RealtimeLocationService();

        // Get a one-time snapshot of active workers
        const unsubscribe = realtimeLocationService.listenToAllWorkers((workers) => {
          const activeTrackingWorkers = workers.filter(w => w.isActive && w.currentLocation);
          newStats.activeWorkers = activeTrackingWorkers.length;
          console.log('📊 Active tracking workers:', activeTrackingWorkers.length);
          console.log('📊 Total workers with role:', newStats.totalWorkers);

          // Update stats with active workers count
          setStats(newStats);
          console.log('✅ Dashboard data loaded successfully:', newStats);

          // Unsubscribe immediately since we only need a snapshot
          unsubscribe();
        });
      } catch (activeWorkersError) {
        console.error('❌ Error loading active workers:', activeWorkersError);
        // Update stats without active workers count
        setStats(newStats);
        console.log('✅ Dashboard data loaded successfully (without active workers):', newStats);
      }

    } catch (error) {
      console.error('❌ Error loading dashboard data:', error);
      // Keep existing stats on error
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadDashboardData();
    setRefreshing(false);
  };

  const handleFeaturePress = (route: string) => {
    const unimplementedRoutes = ['UserManagement', 'Inventory', 'Settings'];

    if (route === 'AdminWorkerTracking') {
      setShowLiveMap(true);
      return;
    }

    if (route === 'Reports') {
      navigation.navigate('SessionReports');
      return;
    }

    if (unimplementedRoutes.includes(route)) {
      Alert.alert(
        'Coming Soon',
        'This feature is currently under development and will be available in the next update.',
        [{ text: 'OK', style: 'default' }]
      );
      return;
    }
    navigation.navigate(route);
  };

  const handleLogout = () => {
    console.log('🔴 LOGOUT BUTTON PRESSED - DEBUG');
    console.log('🔴 About to show logout confirmation...');
    
    try {
      // Check if we're on web platform
      if (Platform.OS === 'web') {
        console.log('🔴 Web platform detected, using window.confirm');
        const confirmed = window.confirm('Are you sure you want to logout?');
        if (confirmed) {
          console.log('🔴 Logout confirmed on web, calling signOut...');
          signOut().then(() => {
            console.log('🔴 SignOut completed successfully on web');
          }).catch((error) => {
            console.error('🔴 Logout error on web:', error);
            alert('Failed to logout. Please try again.');
          });
        } else {
          console.log('🔴 Logout cancelled on web');
        }
        return;
      }

      console.log('🔴 Mobile platform detected, using Alert.alert');
      Alert.alert(
        'Logout',
        'Are you sure you want to logout?',
        [
          { text: 'Cancel', style: 'cancel', onPress: () => console.log('🔴 Logout cancelled') },
          {
            text: 'Logout',
            style: 'destructive',
            onPress: async () => {
              console.log('🔴 Logout confirmed, starting signOut process...');
              try {
                console.log('🔴 Calling signOut function...');
                await signOut();
                console.log('🔴 SignOut completed successfully');
                // No need to manually reset navigation - AuthContext will handle it
              } catch (error) {
                console.error('🔴 Logout error:', error);
                Alert.alert('Error', 'Failed to logout. Please try again.');
              }
            }
          }
        ]
      );
      console.log('🔴 Alert.alert called successfully');
    } catch (error) {
      console.error('🔴 Error in handleLogout:', error);
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />

      {/* Modern Header Component */}
      <Header
        showMenu={true}
        showLogo={true}
        showProfile={true}
        showNotifications={true}
        onProfilePress={() => navigation.navigate('Profile')}
        onNotificationPress={() => navigation.navigate('Notifications')}
      />

      {/* Main Content */}
      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {/* Admin Overview Section */}
        <Animated.View style={[styles.overviewSection, { opacity: animationsReady ? fadeAnim : 1 }]}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Admin Overview</Text>
            {loading && (
              <View style={styles.loadingIndicator}>
                <MaterialIcons name="refresh" size={16} color={COLORS.text.secondary} />
                <Text style={styles.loadingText}>Loading...</Text>
              </View>
            )}
          </View>

          {/* Overview Cards Grid */}
          <View style={styles.overviewGrid}>
            <OverviewCard
              title="Total Users"
              value={stats.totalUsers.toString()}
              unit="users"
              subtitle="All registered users"
              trend="up"
              trendValue={`+${stats.recentSignups} this week`}
              icon="people"
              color={COLORS.primary}
              onMenuPress={() => console.log('Users menu pressed')}
            />

            <OverviewCard
              title="Total Workers"
              value={stats.totalWorkers.toString()}
              unit="workers"
              subtitle="Registered workers"
              trend="up"
              trendValue={`${stats.onlineUsers} online now`}
              icon="people"
              color={COLORS.secondary}
              onMenuPress={() => console.log('Workers menu pressed')}
            />

            <OverviewCard
              title="Active Workers"
              value={stats.activeWorkers.toString()}
              unit="tracking"
              subtitle="Currently tracking location"
              trend={stats.activeWorkers > 0 ? "up" : "neutral"}
              trendValue={stats.activeWorkers > 0 ? "Live tracking" : "No active tracking"}
              icon="location-on"
              color={stats.activeWorkers > 0 ? COLORS.success : COLORS.textSecondary}
              onMenuPress={() => console.log('Active workers menu pressed')}
            />

            <OverviewCard
              title="Territories"
              value={stats.totalTerritories.toString()}
              unit="areas"
              subtitle="Total coverage"
              trend="neutral"
              trendValue="All assigned"
              icon="map"
              color={COLORS.secondary}
              onMenuPress={() => console.log('Territories menu pressed')}
            />

            <OverviewCard
              title="Today's Deliveries"
              value={stats.todayDeliveries.toString()}
              unit="books"
              subtitle="Delivered today"
              trend="up"
              trendValue={`${stats.totalDeliveries} total`}
              icon="local-shipping"
              color={COLORS.info}
              onMenuPress={() => console.log('Deliveries menu pressed')}
            />
          </View>
        </Animated.View>

        {/* Admin Features Section */}
        <Animated.View style={[styles.featuresSection, { opacity: animationsReady ? fadeAnim : 1 }]}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Admin Tools</Text>
            <TouchableOpacity
              style={styles.viewAllButton}
              onPress={() => console.log('View all admin tools')}
            >
              <Text style={styles.viewAllText}>View All</Text>
              <MaterialIcons name="arrow-forward" size={16} color={COLORS.primary} />
            </TouchableOpacity>
          </View>

          <View style={styles.featuresGrid}>
            {adminFeatures.slice(0, 6).map((feature, index) => (
              <TouchableOpacity
                key={feature.id}
                style={styles.modernFeatureCard}
                onPress={() => feature.action ? feature.action() : handleFeaturePress(feature.route)}
                activeOpacity={0.8}
              >
                <View style={styles.featureCardContent}>
                  <View style={[styles.featureIconContainer, { backgroundColor: `${feature.color}15` }]}>
                    <MaterialIcons name={feature.icon as any} size={24} color={feature.color} />
                    {feature.badge && (
                      <View style={styles.featureBadge}>
                        <Text style={styles.featureBadgeText}>{feature.badge}</Text>
                      </View>
                    )}
                  </View>

                  <View style={styles.featureInfo}>
                    <Text style={styles.featureTitle}>{feature.title}</Text>
                    <Text style={styles.featureDescription} numberOfLines={2}>
                      {feature.description}
                    </Text>
                  </View>

                  <MaterialIcons name="arrow-forward-ios" size={16} color={COLORS.text.secondary} />
                </View>
              </TouchableOpacity>
            ))}
          </View>
        </Animated.View>
      </ScrollView>

      {/* Live Map Modal */}
      <Modal
        visible={showLiveMap}
        animationType="slide"
        presentationStyle="fullScreen"
        onRequestClose={() => setShowLiveMap(false)}
      >
        <LiveLocationMap
          onClose={() => setShowLiveMap(false)}
          selectedWorker={selectedWorker}
        />
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F3F4F9',
  },
  content: {
    flex: 1,
    paddingTop: SPACING.md,
  },

  // Overview Section Styles
  overviewSection: {
    backgroundColor: '#f8fafc',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.xl,
    marginBottom: SPACING.md,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  loadingIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
  },
  loadingText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  viewAllButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
  },
  viewAllText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },

  // Overview Cards Grid
  overviewGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    gap: SPACING.md,
  },
  overviewCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    width: '48%',
    ...SHADOWS.sm,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  cardIconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardMenuButton: {
    padding: SPACING.xs,
  },
  cardContent: {
    flex: 1,
  },
  cardTitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  cardValueContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
    marginBottom: SPACING.xs,
  },
  cardValue: {
    fontSize: TYPOGRAPHY.sizes['3xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  cardUnit: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
  cardSubtitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
  },
  trendContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
  },
  trendText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
  },

  // Features Section Styles
  featuresSection: {
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.lg,
    marginBottom: SPACING.md,
  },
  featuresGrid: {
    gap: SPACING.md,
  },
  modernFeatureCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    ...SHADOWS.sm,
    borderWidth: 1,
    borderColor: COLORS.border.light,
  },
  featureCardContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.md,
  },
  featureIconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  featureInfo: {
    flex: 1,
  },
  featureTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  featureDescription: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
  },
  featureBadge: {
    position: 'absolute',
    top: -4,
    right: -4,
    backgroundColor: COLORS.error,
    borderRadius: 10,
    paddingHorizontal: 6,
    paddingVertical: 2,
    minWidth: 20,
  },
  featureBadgeText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.bold,
  },

  // Logout Button
  logoutButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.md,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
  },
});

export default AdminDashboardScreen;
