import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  Dimensions,
  Platform,
  Animated,
  Alert,
  Image,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { SurveyService } from '../services/SurveyService';
import Icon from '../components/Icon';
import Header from '../components/Header';
import MinistryOverview from '../components/MinistryOverview';
import MinistryProgress from '../components/MinistryProgress';
import QuickActions from '../components/QuickActions';
import RecentActivity from '../components/RecentActivity';
import NotificationBadge from '../components/NotificationBadge';
import { MaterialIcons } from '@expo/vector-icons';
import {
  ProfessionalActivityCard,
  ModernStatsCard,
  ProgressCard,
  QuickActionCard
} from '../components/ModernCards';

import SlideOutMenu from '../components/SlideOutMenu';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

const { width } = Dimensions.get('window');

interface WorkerDashboardScreenProps {
  navigation: any;
}

const WorkerDashboardScreen: React.FC<WorkerDashboardScreenProps> = ({ navigation }) => {
  const { user, signOut } = useAuth();
  const locationContext = useLocation();
  const { currentLocation, isTracking, startTracking, stopTracking } = locationContext;
  const [menuVisible, setMenuVisible] = useState(false);
  const [surveyCount, setSurveyCount] = useState(0);
  const [isInitialized, setIsInitialized] = useState(false);
  const fadeAnim = new Animated.Value(0);

  useEffect(() => {
    // Ensure content is visible immediately, then animate
    setIsInitialized(true);

    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 800,
      useNativeDriver: true,
    }).start();
  }, []);

  // Ensure screen renders properly when focused
  useFocusEffect(
    useCallback(() => {
      // Force re-render when screen comes into focus
      setIsInitialized(true);

      // Reset and restart animation
      fadeAnim.setValue(0);
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 300, // Faster animation on focus
        useNativeDriver: true,
      }).start();
    }, [fadeAnim])
  );

  // Load survey assignments count
  useEffect(() => {
    const loadSurveyCount = async () => {
      if (!user) return;

      try {
        const assignments = await SurveyService.getAssignmentsForUser(user.id);
        setSurveyCount(assignments.length);
      } catch (error) {
        console.error('Error loading survey count:', error);
      }
    };

    loadSurveyCount();

    // Set up real-time listener for survey assignments
    if (user) {
      const unsubscribe = SurveyService.subscribeToUserAssignments(user.id, (assignments) => {
        setSurveyCount(assignments.length);
      });

      return unsubscribe;
    }
  }, [user]);

  const handleBookDelivery = (type: 'door' | 'person') => {
    // Navigate to book delivery screen
    console.log(`Book delivery: ${type}`);
  };

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  };


  const handleSignOut = async () => {
    try {
      await signOut();
    } catch (error) {
      console.error('Sign out error:', error);
    }
  };

  // Add error boundary for rendering
  if (!user) {
    return (
      <View style={[styles.container, { justifyContent: 'center', alignItems: 'center' }]}>
        <Text style={{ fontSize: 18, color: COLORS.text.primary }}>Loading...</Text>
      </View>
    );
  }

  // Add safety check for location context
  if (!currentLocation && !isTracking && !startTracking) {
    console.warn('LocationContext seems to be unavailable, using fallback');
  }

  try {
    return (
      <View style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />

        {/* Blue Gradient Background - Behind everything */}
        <Image
          source={require('../../assets/top-gradient.png')}
          style={styles.gradientBackground}
          resizeMode="cover"
        />

        {/* Header Container with proper spacing */}
        <View style={styles.headerContainer}>
          <Header
            showMenu={true}
            showLogo={true}
            showProfile={true}
            showNotifications={true}
            onMenuPress={() => setMenuVisible(!menuVisible)}
            onProfilePress={() => navigation.navigate('Profile')}
          />
        </View>

        {/* Location Status Banner - Clickable to start/stop tracking */}
        <Animated.View style={[styles.locationBanner, { opacity: isInitialized ? fadeAnim : 1 }]}>
          <TouchableOpacity
            style={styles.locationBannerTouchable}
            onPress={async () => {
              try {
                if (isTracking) {
                  await stopTracking();
                } else {
                  await startTracking('Ministry Session');
                }
              } catch (error: any) {
                Alert.alert(
                  'Location Error',
                  error?.message || 'Failed to toggle location tracking. Please check your location permissions.'
                );
              }
            }}
            activeOpacity={0.7}
          >
            <View style={styles.locationInfo}>
              <View style={[styles.locationDot, {
                backgroundColor: isTracking ? COLORS.success : COLORS.warning
              }]} />
              <Text style={styles.locationText}>
                {isTracking ? 'Location Active' : 'Location Inactive'}
              </Text>
            </View>
            <Text style={styles.locationHint}>
              {isTracking ? 'Tap to stop tracking' : 'Tap to start tracking'}
            </Text>
          </TouchableOpacity>
        </Animated.View>

        {/* Main Content */}
        <ScrollView
          style={[styles.content, Platform.OS === 'web' && styles.webScrollView]}
          showsVerticalScrollIndicator={Platform.OS !== 'web'}
          contentContainerStyle={[styles.contentContainer, Platform.OS === 'web' && styles.webContentContainer]}
          bounces={Platform.OS !== 'web'}
          scrollEventThrottle={16}
          keyboardShouldPersistTaps="handled"
          removeClippedSubviews={false}
          nestedScrollEnabled={true}
          {...(Platform.OS === 'web' && {
            className: 'scrollable-content',
            dataSet: { testid: 'worker-dashboard-scroll' }
          })}
        >
          {/* Ministry Overview */}
          <Animated.View style={{ opacity: isInitialized ? fadeAnim : 1 }}>
            <MinistryOverview />
          </Animated.View>

          {/* Ministry Progress */}
          <Animated.View style={{ opacity: isInitialized ? fadeAnim : 1 }}>
            <MinistryProgress
              progress={68}
              onMenuPress={() => {
                console.log('Ministry Progress menu pressed');
                // Add menu functionality here
              }}
            />
          </Animated.View>

          {/* Quick Actions */}
          <Animated.View style={{ opacity: isInitialized ? fadeAnim : 1 }}>
            <QuickActions
              onMyTerritoryPress={() => navigation.navigate('MyTerritory')}
              onDeliverBookPress={() => navigation.navigate('DeliveryTracking')}
              onSurveyFormPress={() => navigation.navigate('SurveyForm')}
              onTeamGroupPress={() => navigation.navigate('Messaging')}
              onLocationTrackingPress={() => navigation.navigate('LocationTracking')}
              onGamificationPress={() => navigation.navigate('Gamification')}
            />
          </Animated.View>

          {/* Survey Section */}
          <Animated.View style={[styles.surveySection, { opacity: isInitialized ? fadeAnim : 1 }]}>
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>My Surveys</Text>
              <TouchableOpacity
                onPress={() => navigation.navigate('Surveys')}
                style={styles.viewAllButton}
              >
                <Text style={styles.viewAllText}>View All</Text>
                <MaterialIcons name="arrow-forward" size={16} color={COLORS.primary} />
              </TouchableOpacity>
            </View>

            <TouchableOpacity
              style={styles.surveyCard}
              onPress={() => navigation.navigate('Surveys')}
              activeOpacity={0.7}
            >
              <View style={styles.surveyCardContent}>
                <View style={styles.surveyIcon}>
                  <MaterialIcons name="assignment" size={32} color={COLORS.primary} />
                  {surveyCount > 0 && (
                    <View style={styles.surveyBadge}>
                      <Text style={styles.surveyBadgeText}>{surveyCount}</Text>
                    </View>
                  )}
                </View>
                <View style={styles.surveyInfo}>
                  <Text style={styles.surveyTitle}>
                    {surveyCount > 0 ? `${surveyCount} Survey${surveyCount > 1 ? 's' : ''} Available` : 'No Surveys Available'}
                  </Text>
                  <Text style={styles.surveyDescription}>
                    {surveyCount > 0
                      ? 'You have assigned surveys to complete'
                      : 'Check back later for new survey assignments'
                    }
                  </Text>
                </View>
                <Icon name="chevron-right" size={24} color={COLORS.text.secondary} />
              </View>
            </TouchableOpacity>
          </Animated.View>

          {/* Recent Activity */}
          <Animated.View style={{ opacity: isInitialized ? fadeAnim : 1 }}>
            <RecentActivity />
          </Animated.View>

          {/* Bottom Padding for Navigation */}
          <View style={styles.bottomPadding} />
        </ScrollView>

        {/* Slide Out Menu */}
        <SlideOutMenu
          visible={menuVisible}
          onClose={() => setMenuVisible(false)}
          user={user}
          onSignOut={handleSignOut}
          navigation={navigation}
          isTracking={isTracking}
        />
      </View>
    );
  } catch (error) {
    console.error('Error rendering WorkerDashboardScreen:', error);
    return (
      <View style={[styles.container, { justifyContent: 'center', alignItems: 'center', padding: 20 }]}>
        <MaterialIcons name="error-outline" size={48} color={COLORS.error} />
        <Text style={{ fontSize: 18, color: COLORS.text.primary, textAlign: 'center', marginTop: 16 }}>
          Something went wrong
        </Text>
        <Text style={{ fontSize: 14, color: COLORS.text.secondary, textAlign: 'center', marginTop: 8 }}>
          Please try refreshing the app
        </Text>
        <TouchableOpacity
          style={{
            backgroundColor: COLORS.primary,
            paddingHorizontal: 24,
            paddingVertical: 12,
            borderRadius: 8,
            marginTop: 16
          }}
          onPress={() => {
            // Force refresh by navigating to the same screen
            navigation.replace('WorkerDashboard');
          }}
        >
          <Text style={{ color: COLORS.white, fontSize: 16, fontWeight: '600' }}>
            Refresh
          </Text>
        </TouchableOpacity>
      </View>
    );
  }
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F3F4F9',
  },
  gradientBackground: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    width: Dimensions.get('window').width,
    height: Dimensions.get('window').height * 0.55,
  },
  headerContainer: {
    paddingTop: Platform.OS === 'ios' ? 50 : 25, // Proper spacing for status bar
    paddingBottom: SPACING.sm,
    backgroundColor: 'transparent',
  },
  locationBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.white,
    marginHorizontal: SPACING.lg,
    marginVertical: SPACING.sm,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    ...SHADOWS.sm,
  },
  locationInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  locationDot: {
    width: 8,
    height: 8,
    borderRadius: RADIUS.full,
    marginRight: SPACING.sm,
  },
  locationText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  locationBannerTouchable: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  locationHint: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.normal,
  },
  content: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  contentContainer: {
    paddingHorizontal: SPACING.xl,
    paddingTop: SPACING.md,
    paddingBottom: 200, // Space for bottom navigation
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.lg,
  },
  surveySection: {
    marginBottom: SPACING['2xl'],
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  viewAllButton: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  viewAllText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.semibold,
    marginRight: SPACING.xs,
  },
  surveyCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.md,
  },
  surveyCardContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  surveyIcon: {
    width: 60,
    height: 60,
    borderRadius: RADIUS.lg,
    backgroundColor: COLORS.primary + '20',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
    position: 'relative',
  },
  surveyBadge: {
    position: 'absolute',
    top: -4,
    right: -4,
    backgroundColor: COLORS.error,
    borderRadius: RADIUS.full,
    minWidth: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xs,
  },
  surveyBadgeText: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.sizes.xs,
    fontWeight: TYPOGRAPHY.weights.bold,
    textAlign: 'center',
  },
  surveyInfo: {
    flex: 1,
  },
  surveyTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  surveyDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    lineHeight: 18,
  },
  bottomPadding: {
    height: 120, // Space for bottom navigation
  },
  bottomNavigationContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    zIndex: 100,
    elevation: 10,
  },
  // Web-specific styles for scroll fix
  webScrollView: {
    ...(Platform.OS === 'web' && {
      WebkitOverflowScrolling: 'touch',
      scrollBehavior: 'smooth',
      height: '100%',
      overflow: 'auto',
    } as any),
  },
  webContentContainer: {
    minHeight: 'auto',
    flexGrow: 1,
  },
});

export default WorkerDashboardScreen;