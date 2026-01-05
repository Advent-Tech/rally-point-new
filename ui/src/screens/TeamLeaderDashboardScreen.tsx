import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  StatusBar,
  Platform,
  RefreshControl,
  Alert,
  Modal,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { TeamLeaderService, TeamLeaderStats } from '../services/TeamLeaderService';
import LiveLocationMap from '../components/LiveLocationMap';
import Header from '../components/Header';

interface TeamLeaderDashboardScreenProps {
  navigation: any;
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

const TeamLeaderDashboardScreen: React.FC<TeamLeaderDashboardScreenProps> = ({ navigation }) => {
  const { user, signOut } = useAuth();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [showLiveMap, setShowLiveMap] = useState(false);
  const [activeTab, setActiveTab] = useState('home');
  const [menuVisible, setMenuVisible] = useState(false);
  const [stats, setStats] = useState<TeamLeaderStats>({
    totalWorkers: 0,
    activeWorkers: 0,
    totalTerritories: 0,
    todayDeliveries: 0,
    totalDeliveries: 0,
    completedSurveys: 0,
    onlineWorkers: 0,
  });

  useEffect(() => {
    // Load team data
    loadTeamData();

    // Set up real-time listener for active workers
    let unsubscribe: (() => void) | null = null;
    if (user?.team_id) {
      unsubscribe = TeamLeaderService.listenToTeamActiveWorkers(
        user.team_id,
        (activeWorkers) => {
          setStats(prev => ({
            ...prev,
            activeWorkers: activeWorkers.length
          }));
        }
      );
    }

    return () => {
      if (unsubscribe) {
        unsubscribe();
      }
    };
  }, [user?.team_id]);

  const loadTeamData = async () => {
    try {
      setLoading(true);
      console.log('📊 Loading team leader dashboard data...');
      console.log('👤 User object:', user);

      if (!user?.team_id) {
        console.warn('⚠️ Team leader has no team_id assigned - showing empty dashboard');
        // Just set empty stats and continue - user can create team later
        setStats({
          totalWorkers: 0,
          activeWorkers: 0,
          totalTerritories: 0,
          todayDeliveries: 0,
          totalDeliveries: 0,
          completedSurveys: 0,
          onlineWorkers: 0,
        });
        setLoading(false);
        return;
      }

      if (user?.team_id) {
        console.log('🔍 User has team_id:', user.team_id);
        const teamStats = await TeamLeaderService.getTeamStats(user.team_id);
        setStats(teamStats);

        console.log('✅ Team dashboard data loaded successfully:', teamStats);
      }
    } catch (error) {
      console.error('❌ Error loading team dashboard data:', error);
      // Don't show alert - just set empty stats
      setStats({
        totalWorkers: 0,
        activeWorkers: 0,
        totalTerritories: 0,
        todayDeliveries: 0,
        totalDeliveries: 0,
        completedSurveys: 0,
        onlineWorkers: 0,
      });
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadTeamData();
    setRefreshing(false);
  };

  const handleTabPress = (tab: string) => {
    setActiveTab(tab);

    switch (tab) {
      case 'home':
        // Already on home screen
        break;
      case 'territory':
        navigation.navigate('MyTerritory');
        break;
      case 'activity':
        navigation.navigate('PathHistory');
        break;
      case 'profile':
        setMenuVisible(true);
        break;
      default:
        break;
    }
  };

  const handleFeaturePress = (route: string) => {
    if (route === 'TeamLeaderWorkerTracking') {
      navigation.navigate('TeamLeaderWorkerTracking');
      return;
    }

    if (route === 'TeamLeaderWorkerManagement') {
      navigation.navigate('TeamLeaderWorkerManagement');
      return;
    }

    if (route === 'TeamLeaderSurveyManagement') {
      navigation.navigate('TeamLeaderSurveyManagement');
      return;
    }

    if (route === 'TeamLeaderDeliveryManagement') {
      navigation.navigate('TeamLeaderDeliveryManagement');
      return;
    }

    if (route === 'TeamLeaderTerritoryAssignment') {
      navigation.navigate('TeamLeaderTerritoryAssignment');
      return;
    }

    // For unimplemented routes
    Alert.alert(
      'Coming Soon',
      'This feature is currently under development and will be available in the next update.',
      [{ text: 'OK', style: 'default' }]
    );
  };

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch (error) {
      console.error('Sign out error:', error);
    }
  };

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  };

  const teamFeatures = [
    {
      id: 'worker-tracking',
      title: 'Live Worker Tracking',
      description: 'Monitor your team in real-time',
      icon: 'location-on',
      color: COLORS.info,
      route: 'TeamLeaderWorkerTracking',
      badge: stats.activeWorkers > 0 ? stats.activeWorkers.toString() : null,
    },
    {
      id: 'worker-management',
      title: 'Worker Management',
      description: 'View and manage team members',
      icon: 'people',
      color: COLORS.primary,
      route: 'TeamLeaderWorkerManagement',
      badge: null,
    },
    {
      id: 'survey-management',
      title: 'Survey Management',
      description: 'Create and manage surveys',
      icon: 'assignment',
      color: COLORS.secondary,
      route: 'TeamLeaderSurveyManagement',
      badge: null,
    },
    {
      id: 'delivery-management',
      title: 'Delivery Management',
      description: 'Track team deliveries',
      icon: 'local-shipping',
      color: COLORS.warning,
      route: 'TeamLeaderDeliveryManagement',
      badge: null,
    },
    {
      id: 'territory-assignment',
      title: 'Territory Assignment',
      description: 'Assign territories to workers',
      icon: 'map',
      color: COLORS.success,
      route: 'TeamLeaderTerritoryAssignment',
      badge: null,
    },
    {
      id: 'team-reports',
      title: 'Team Reports',
      description: 'View team analytics',
      icon: 'bar-chart',
      color: COLORS.error,
      route: 'TeamReports',
      badge: null,
    },
  ];

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />

      {/* Modern Header Component */}
      <Header
        showMenu={true}
        showLogo={true}
        showProfile={true}
        onProfilePress={() => navigation.navigate('Profile')}
      />

      {/* Main Content */}
      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {/* Team Overview Section */}
        <View style={styles.overviewSection}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Team Overview</Text>
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
              title="Total Workers"
              value={stats.totalWorkers.toString()}
              unit="workers"
              subtitle="Team members"
              trend="neutral"
              trendValue={`${stats.onlineWorkers} online now`}
              icon="people"
              color={COLORS.primary}
              onMenuPress={() => {
                try {
                  navigation.navigate('TeamLeaderWorkerManagement');
                } catch (error) {
                  Alert.alert('Navigation Error', 'Unable to open Worker Management');
                }
              }}
            />

            <OverviewCard
              title="Active Workers"
              value={stats.activeWorkers.toString()}
              unit="tracking"
              subtitle="Currently in field"
              trend={stats.activeWorkers > 0 ? "up" : "neutral"}
              trendValue={stats.activeWorkers > 0 ? "Live tracking" : "No active tracking"}
              icon="location-on"
              color={stats.activeWorkers > 0 ? COLORS.success : COLORS.text.secondary}
              onMenuPress={() => {
                try {
                  navigation.navigate('TeamLeaderWorkerTracking');
                } catch (error) {
                  Alert.alert('Navigation Error', 'Unable to open Live Worker Tracking');
                }
              }}
            />

            <OverviewCard
              title="Territories"
              value={stats.totalTerritories.toString()}
              unit="areas"
              subtitle="Assigned to team"
              trend="neutral"
              trendValue="All assigned"
              icon="map"
              color={COLORS.secondary}
              onMenuPress={() => {
                console.log('🗺️ Territories menu pressed - navigating to MyTerritory');
                try {
                  navigation.navigate('MyTerritory');
                } catch (error) {
                  console.error('❌ Navigation error:', error);
                  Alert.alert('Navigation Error', 'Unable to open territories. The service may be unavailable.');
                }
              }}
            />

            <OverviewCard
              title="Today's Deliveries"
              value={stats.todayDeliveries.toString()}
              unit="books"
              subtitle="Delivered today"
              trend="up"
              trendValue={`${stats.totalDeliveries} total`}
              icon="local-shipping"
              color={COLORS.warning}
              onMenuPress={() => {
                try {
                  navigation.navigate('TeamLeaderDeliveryManagement');
                } catch (error) {
                  Alert.alert('Navigation Error', 'Unable to open Delivery Management');
                }
              }}
            />

            <OverviewCard
              title="Completed Surveys"
              value={stats.completedSurveys.toString()}
              unit="responses"
              subtitle="Survey responses"
              trend="up"
              trendValue="This month"
              icon="assignment"
              color={COLORS.info}
              onMenuPress={() => {
                try {
                  navigation.navigate('TeamLeaderSurveyManagement');
                } catch (error) {
                  Alert.alert('Navigation Error', 'Unable to open Survey Management');
                }
              }}
            />
          </View>
        </View>

        {/* Management Actions */}
        <View style={styles.featuresSection}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Team Management</Text>
          </View>
          <View style={styles.featuresGrid}>
            {teamFeatures.map((feature) => (
              <TouchableOpacity
                key={feature.id}
                style={styles.modernFeatureCard}
                onPress={() => handleFeaturePress(feature.route)}
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
                  <View style={styles.featureTextContainer}>
                    <Text style={styles.featureTitle}>{feature.title}</Text>
                    <Text style={styles.featureDescription}>{feature.description}</Text>
                  </View>
                  <MaterialIcons name="chevron-right" size={20} color={COLORS.text.secondary} />
                </View>
              </TouchableOpacity>
            ))}
          </View>
        </View>

      </ScrollView>
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
  loadingIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
  },
  loadingText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
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
  // Features Section
  featuresSection: {
    backgroundColor: '#f8fafc',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.xl,
    marginBottom: SPACING.md,
  },
  featuresGrid: {
    gap: SPACING.md,
  },
  modernFeatureCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
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
    position: 'relative',
  },
  featureBadge: {
    position: 'absolute',
    top: -4,
    right: -4,
    backgroundColor: COLORS.error,
    borderRadius: RADIUS.full,
    minWidth: 20,
    height: 20,
    paddingHorizontal: SPACING.xs,
    justifyContent: 'center',
    alignItems: 'center',
  },
  featureBadgeText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.white,
  },
  featureTextContainer: {
    flex: 1,
  },
  featureTitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  featureDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
});

export default TeamLeaderDashboardScreen;
