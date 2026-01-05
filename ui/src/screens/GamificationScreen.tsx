import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Animated,
  Dimensions,
  StatusBar,
  Platform,
  RefreshControl,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import GamificationService, { UserStats, Badge, Achievement } from '../services/GamificationService';
import GeotrackingService from '../services/GeotrackingService';
import DeliveryTrackingService from '../services/DeliveryTrackingService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants';

const { width } = Dimensions.get('window');

interface GamificationScreenProps {
  navigation: any;
}

const GamificationScreen: React.FC<GamificationScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [userStats, setUserStats] = useState<UserStats | null>(null);
  const [selectedTab, setSelectedTab] = useState<'overview' | 'badges' | 'achievements' | 'leaderboard'>('overview');
  const [refreshing, setRefreshing] = useState(false);
  const [levelAnim] = useState(new Animated.Value(0));
  const [pointsAnim] = useState(new Animated.Value(0));

  useEffect(() => {
    initializeGamification();
    setupActivityListener();
    
    return () => {
      // Cleanup
    };
  }, []);

  // Initialize gamification
  const initializeGamification = async () => {
    try {
      await GamificationService.initialize();
      const stats = GamificationService.getUserStats();
      setUserStats(stats);
      
      // Animate values
      animateValues();
    } catch (error) {
      console.error('Error initializing gamification:', error);
    }
  };

  // Setup activity listener
  const setupActivityListener = () => {
    GamificationService.onActivityUpdate((stats) => {
      setUserStats(stats);
      animateValues();
    });
  };

  // Animate values
  const animateValues = () => {
    const stats = GamificationService.getUserStats();
    if (stats) {
      Animated.timing(levelAnim, {
        toValue: stats.level,
        duration: 1000,
        useNativeDriver: false,
      }).start();

      Animated.timing(pointsAnim, {
        toValue: stats.totalPoints,
        duration: 1500,
        useNativeDriver: false,
      }).start();
    }
  };

  // Refresh data
  const onRefresh = async () => {
    setRefreshing(true);
    try {
      await GamificationService.initialize();
      const stats = GamificationService.getUserStats();
      setUserStats(stats);
    } catch (error) {
      console.error('Error refreshing gamification:', error);
    } finally {
      setRefreshing(false);
    }
  };

  // Render overview tab
  const renderOverview = () => {
    if (!userStats) return null;

    return (
      <View style={styles.overviewContainer}>
        {/* Level Card */}
        <View style={styles.levelCard}>
          <LinearGradient
            colors={['rgba(59,130,246,0.1)', 'rgba(59,130,246,0.05)']}
            style={styles.glassmorphismCard}
          >
            <View style={styles.levelHeader}>
              <Text style={styles.levelLabel}>LEVEL</Text>
              <Animated.Text style={styles.levelValue}>
                {levelAnim.interpolate({
                  inputRange: [0, 100],
                  outputRange: ['1', userStats.level.toString()],
                })}
              </Animated.Text>
            </View>
            
            <View style={styles.progressContainer}>
              <View style={styles.progressBar}>
                <View 
                  style={[
                    styles.progressFill,
                    { width: `${GamificationService.getLevelProgress()}%` }
                  ]}
                />
              </View>
              <Text style={styles.progressText}>
                {userStats.currentLevelPoints} / {userStats.nextLevelPoints} XP
              </Text>
            </View>
          </LinearGradient>
        </View>

        {/* Stats Grid */}
        <View style={styles.statsGrid}>
          <View style={styles.statCard}>
            <LinearGradient
              colors={['rgba(16,185,129,0.1)', 'rgba(16,185,129,0.05)']}
              style={styles.glassmorphismCard}
            >
              <MaterialIcons name="stars" size={24} color={COLORS.accent} />
              <Animated.Text style={styles.statValue}>
                {pointsAnim.interpolate({
                  inputRange: [0, 10000],
                  outputRange: ['0', userStats.totalPoints.toString()],
                })}
              </Animated.Text>
              <Text style={styles.statLabel}>Total Points</Text>
            </LinearGradient>
          </View>

          <View style={styles.statCard}>
            <LinearGradient
              colors={['rgba(245,158,11,0.1)', 'rgba(245,158,11,0.05)']}
              style={styles.glassmorphismCard}
            >
              <MaterialIcons name="local-fire-department" size={24} color={COLORS.warning} />
              <Text style={styles.statValue}>{userStats.streak}</Text>
              <Text style={styles.statLabel}>Day Streak</Text>
            </LinearGradient>
          </View>

          <View style={styles.statCard}>
            <LinearGradient
              colors={['rgba(139,92,246,0.1)', 'rgba(139,92,246,0.05)']}
              style={styles.glassmorphismCard}
            >
              <MaterialIcons name="emoji-events" size={24} color={COLORS.primary} />
              <Text style={styles.statValue}>{userStats.achievements.length}</Text>
              <Text style={styles.statLabel}>Achievements</Text>
            </LinearGradient>
          </View>

          <View style={styles.statCard}>
            <LinearGradient
              colors={['rgba(236,72,153,0.1)', 'rgba(236,72,153,0.05)']}
              style={styles.glassmorphismCard}
            >
              <MaterialIcons name="military-tech" size={24} color={COLORS.accent} />
              <Text style={styles.statValue}>
                {userStats.badges.filter(b => b.unlocked).length}/{userStats.badges.length}
              </Text>
              <Text style={styles.statLabel}>Badges</Text>
            </LinearGradient>
          </View>
        </View>

        {/* Recent Activity */}
        <View style={styles.recentActivity}>
          <Text style={styles.sectionTitle}>Recent Activity</Text>
          <View style={styles.activityList}>
            <View style={styles.activityItem}>
              <View style={styles.activityIcon}>
                <MaterialIcons name="directions-walk" size={20} color={COLORS.primary} />
              </View>
              <View style={styles.activityContent}>
                <Text style={styles.activityTitle}>Field Work Session</Text>
                <Text style={styles.activitySubtitle}>+20 points</Text>
              </View>
              <Text style={styles.activityTime}>2h ago</Text>
            </View>
            
            <View style={styles.activityItem}>
              <View style={styles.activityIcon}>
                <MaterialIcons name="book" size={20} color={COLORS.accent} />
              </View>
              <View style={styles.activityContent}>
                <Text style={styles.activityTitle}>Book Delivery</Text>
                <Text style={styles.activitySubtitle}>+15 points</Text>
              </View>
              <Text style={styles.activityTime}>3h ago</Text>
            </View>
          </View>
        </View>
      </View>
    );
  };

  // Render badges tab
  const renderBadges = () => {
    const badges = GamificationService.getAvailableBadges();
    const unlockedBadges = badges.filter(b => b.unlocked);
    const lockedBadges = badges.filter(b => !b.unlocked);

    return (
      <ScrollView style={styles.badgesContainer}>
        <Text style={styles.sectionTitle}>Unlocked Badges ({unlockedBadges.length})</Text>
        <View style={styles.badgesGrid}>
          {unlockedBadges.map((badge) => (
            <View key={badge.id} style={styles.badgeCard}>
              <LinearGradient
                colors={['rgba(16,185,129,0.1)', 'rgba(16,185,129,0.05)']}
                style={styles.glassmorphismCard}
              >
                <Text style={styles.badgeIcon}>{badge.icon}</Text>
                <Text style={styles.badgeName}>{badge.name}</Text>
                <Text style={styles.badgeDescription}>{badge.description}</Text>
                <Text style={styles.badgeUnlocked}>✓ Unlocked</Text>
              </LinearGradient>
            </View>
          ))}
        </View>

        <Text style={styles.sectionTitle}>Locked Badges ({lockedBadges.length})</Text>
        <View style={styles.badgesGrid}>
          {lockedBadges.map((badge) => (
            <View key={badge.id} style={[styles.badgeCard, styles.badgeLocked]}>
              <LinearGradient
                colors={['rgba(107,114,128,0.1)', 'rgba(107,114,128,0.05)']}
                style={styles.glassmorphismCard}
              >
                <Text style={[styles.badgeIcon, styles.badgeIconLocked]}>{badge.icon}</Text>
                <Text style={styles.badgeName}>{badge.name}</Text>
                <Text style={styles.badgeDescription}>{badge.description}</Text>
                <View style={styles.badgeProgress}>
                  <View style={styles.badgeProgressBar}>
                    <View 
                      style={[
                        styles.badgeProgressFill,
                        { width: `${(badge.progress / badge.maxProgress) * 100}%` }
                      ]}
                    />
                  </View>
                  <Text style={styles.badgeProgressText}>
                    {badge.progress}/{badge.maxProgress}
                  </Text>
                </View>
              </LinearGradient>
            </View>
          ))}
        </View>
      </ScrollView>
    );
  };

  // Render achievements tab
  const renderAchievements = () => {
    const achievements = GamificationService.getUnlockedAchievements();

    return (
      <ScrollView style={styles.achievementsContainer}>
        <Text style={styles.sectionTitle}>Unlocked Achievements ({achievements.length})</Text>
        <View style={styles.achievementsList}>
          {achievements.map((achievement) => (
            <View key={achievement.id} style={styles.achievementCard}>
              <LinearGradient
                colors={['rgba(245,158,11,0.1)', 'rgba(245,158,11,0.05)']}
                style={styles.glassmorphismCard}
              >
                <View style={styles.achievementHeader}>
                  <Text style={styles.achievementIcon}>{achievement.icon}</Text>
                  <View style={styles.achievementInfo}>
                    <Text style={styles.achievementTitle}>{achievement.title}</Text>
                    <Text style={styles.achievementDescription}>{achievement.description}</Text>
                  </View>
                  <View style={styles.achievementPoints}>
                    <Text style={styles.achievementPointsValue}>+{achievement.points}</Text>
                    <Text style={styles.achievementPointsLabel}>points</Text>
                  </View>
                </View>
              </LinearGradient>
            </View>
          ))}
        </View>
      </ScrollView>
    );
  };

  // Render leaderboard tab
  const renderLeaderboard = () => {
    return (
      <View style={styles.leaderboardContainer}>
        <Text style={styles.sectionTitle}>Weekly Leaderboard</Text>
        <View style={styles.leaderboardList}>
          {[
            { rank: 1, name: 'John Doe', points: 2500, badge: '🥇' },
            { rank: 2, name: 'Jane Smith', points: 2300, badge: '🥈' },
            { rank: 3, name: 'Bob Johnson', points: 2100, badge: '🥉' },
            { rank: 4, name: 'You', points: userStats?.totalPoints || 0, badge: '👤' },
          ].map((entry) => (
            <View key={entry.rank} style={[
              styles.leaderboardItem,
              entry.name === 'You' && styles.leaderboardYou
            ]}>
              <LinearGradient
                colors={entry.name === 'You' ? ['rgba(59,130,246,0.1)', 'rgba(59,130,246,0.05)'] : ['rgba(255,255,255,0.05)', 'rgba(255,255,255,0.02)']}
                style={styles.glassmorphismCard}
              >
                <Text style={styles.leaderboardRank}>{entry.badge}</Text>
                <View style={styles.leaderboardInfo}>
                  <Text style={styles.leaderboardName}>{entry.name}</Text>
                  <Text style={styles.leaderboardPoints}>{entry.points} points</Text>
                </View>
                <Text style={styles.leaderboardPosition}>#{entry.rank}</Text>
              </LinearGradient>
            </View>
          ))}
        </View>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Gamification</Text>
        <Text style={styles.headerSubtitle}>Track your progress and achievements</Text>
      </View>

      {/* Tab Navigation */}
      <View style={styles.tabContainer}>
        {[
          { key: 'overview', label: 'Overview', icon: 'dashboard' },
          { key: 'badges', label: 'Badges', icon: 'military-tech' },
          { key: 'achievements', label: 'Achievements', icon: 'emoji-events' },
          { key: 'leaderboard', label: 'Leaderboard', icon: 'leaderboard' },
        ].map((tab) => (
          <TouchableOpacity
            key={tab.key}
            style={[
              styles.tabButton,
              selectedTab === tab.key && styles.tabButtonActive
            ]}
            onPress={() => setSelectedTab(tab.key as any)}
          >
            <MaterialIcons 
              name={tab.icon as React.ComponentProps<typeof MaterialIcons>['name']} 
              size={20} 
              color={selectedTab === tab.key ? COLORS.primary : COLORS.text.secondary} 
            />
            <Text style={[
              styles.tabLabel,
              selectedTab === tab.key && styles.tabLabelActive
            ]}>
              {tab.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Content */}
      <ScrollView
        style={styles.content}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {selectedTab === 'overview' && renderOverview()}
        {selectedTab === 'badges' && renderBadges()}
        {selectedTab === 'achievements' && renderAchievements()}
        {selectedTab === 'leaderboard' && renderLeaderboard()}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  header: {
    paddingTop: Platform.OS === 'ios' ? 60 : 40,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.lg,
  },
  headerTitle: {
    fontSize: TYPOGRAPHY.sizes.xxl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  headerSubtitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  tabContainer: {
    flexDirection: 'row',
    paddingHorizontal: SPACING.md,
    marginBottom: SPACING.md,
  },
  tabButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
  },
  tabButtonActive: {
    backgroundColor: 'rgba(59,130,246,0.1)',
  },
  tabLabel: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    marginTop: 4,
  },
  tabLabelActive: {
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  content: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
  },
  glassmorphismCard: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
    elevation: 10,
  },
  overviewContainer: {
    gap: SPACING.lg,
  },
  levelCard: {
    marginBottom: SPACING.lg,
  },
  levelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  levelLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  levelValue: {
    fontSize: TYPOGRAPHY.sizes.xxl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.primary,
  },
  progressContainer: {
    gap: SPACING.sm,
  },
  progressBar: {
    height: 8,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: 4,
  },
  progressText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.md,
    marginBottom: SPACING.lg,
  },
  statCard: {
    width: (width - SPACING.lg * 3 - SPACING.md) / 2,
    alignItems: 'center',
  },
  statValue: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginTop: SPACING.sm,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  recentActivity: {
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  activityList: {
    gap: SPACING.sm,
  },
  activityItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: RADIUS.md,
    padding: SPACING.md,
  },
  activityIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  activityContent: {
    flex: 1,
  },
  activityTitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  activitySubtitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.accent,
  },
  activityTime: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },
  badgesContainer: {
    flex: 1,
  },
  badgesGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.md,
    marginBottom: SPACING.xl,
  },
  badgeCard: {
    width: (width - SPACING.lg * 3 - SPACING.md) / 2,
  },
  badgeLocked: {
    opacity: 0.6,
  },
  badgeIcon: {
    fontSize: 40,
    textAlign: 'center',
    marginBottom: SPACING.sm,
  },
  badgeIconLocked: {
    opacity: 0.5,
  },
  badgeName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    textAlign: 'center',
    marginBottom: SPACING.xs,
  },
  badgeDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginBottom: SPACING.sm,
  },
  badgeUnlocked: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.accent,
    fontWeight: TYPOGRAPHY.weights.medium,
    textAlign: 'center',
  },
  badgeProgress: {
    marginTop: SPACING.sm,
  },
  badgeProgressBar: {
    height: 4,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 2,
    overflow: 'hidden',
    marginBottom: SPACING.xs,
  },
  badgeProgressFill: {
    height: '100%',
    backgroundColor: COLORS.primary,
  },
  badgeProgressText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  achievementsContainer: {
    flex: 1,
  },
  achievementsList: {
    gap: SPACING.md,
  },
  achievementCard: {
    marginBottom: SPACING.md,
  },
  achievementHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  achievementIcon: {
    fontSize: 32,
    marginRight: SPACING.md,
  },
  achievementInfo: {
    flex: 1,
  },
  achievementTitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  achievementDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  achievementPoints: {
    alignItems: 'center',
  },
  achievementPointsValue: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.warning,
  },
  achievementPointsLabel: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },
  leaderboardContainer: {
    flex: 1,
  },
  leaderboardList: {
    gap: SPACING.sm,
  },
  leaderboardItem: {
    marginBottom: SPACING.sm,
  },
  leaderboardYou: {
    borderWidth: 2,
    borderColor: COLORS.primary,
  },
  leaderboardRank: {
    fontSize: 24,
    marginRight: SPACING.md,
  },
  leaderboardInfo: {
    flex: 1,
  },
  leaderboardName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  leaderboardPoints: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  leaderboardPosition: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.primary,
  },
});

export default GamificationScreen;
