import AsyncStorage from '@react-native-async-storage/async-storage';
import GeotrackingService from './GeotrackingService';
import DeliveryTrackingService from './DeliveryTrackingService';

export interface Badge {
  id: string;
  name: string;
  description: string;
  icon: string;
  color: string;
  unlocked: boolean;
  unlockedAt?: number;
  progress: number; // 0-100
  maxProgress: number;
  category: 'tracking' | 'delivery' | 'survey' | 'social' | 'achievement';
}

export interface Achievement {
  id: string;
  title: string;
  description: string;
  points: number;
  type: 'milestone' | 'streak' | 'special';
  unlockedAt?: number;
  icon: string;
}

export interface UserStats {
  totalPoints: number;
  level: number;
  currentLevelPoints: number;
  nextLevelPoints: number;
  streak: number;
  longestStreak: number;
  badges: Badge[];
  achievements: Achievement[];
  weeklyRank?: number;
  monthlyRank?: number;
}

export interface ActivityPoints {
  tracking: {
    perKm: number;
    perHour: number;
    perSession: number;
  };
  delivery: {
    perDelivery: number;
    perDonation: number;
    perPerson: number;
  };
  survey: {
    perSurvey: number;
    perComplete: number;
  };
  streak: {
    dailyBonus: number;
    weeklyBonus: number;
    monthlyBonus: number;
  };
}

class GamificationService {
  private static instance: GamificationService;
  private userStats: UserStats | null = null;
  private activityCallbacks: ((stats: UserStats) => void)[] = [];

  private readonly STORAGE_KEYS = {
    USER_STATS: 'gamification_user_stats',
    BADGES: 'gamification_badges',
    ACHIEVEMENTS: 'gamification_achievements',
    ACTIVITY_LOG: 'gamification_activity_log',
  };

  // Points configuration
  private readonly POINTS_CONFIG: ActivityPoints = {
    tracking: {
      perKm: 10,
      perHour: 5,
      perSession: 20,
    },
    delivery: {
      perDelivery: 15,
      perDonation: 25,
      perPerson: 20,
    },
    survey: {
      perSurvey: 10,
      perComplete: 15,
    },
    streak: {
      dailyBonus: 50,
      weeklyBonus: 200,
      monthlyBonus: 500,
    },
  };

  // Badge definitions
  private readonly BADGE_DEFINITIONS: Omit<Badge, 'unlocked' | 'unlockedAt' | 'progress'>[] = [
    {
      id: 'first_delivery',
      name: 'First Delivery',
      description: 'Complete your first book delivery',
      icon: '📚',
      color: '#10B981',
      maxProgress: 1,
      category: 'delivery',
    },
    {
      id: 'delivery_master',
      name: 'Delivery Master',
      description: 'Complete 100 deliveries',
      icon: '🌟',
      color: '#F59E0B',
      maxProgress: 100,
      category: 'delivery',
    },
    {
      id: 'distance_walker',
      name: 'Distance Walker',
      description: 'Walk 50km in field work',
      icon: '🚶',
      color: '#3B82F6',
      maxProgress: 50,
      category: 'tracking',
    },
    {
      id: 'early_bird',
      name: 'Early Bird',
      description: 'Start tracking before 8am for 7 days',
      icon: '🌅',
      color: '#F59E0B',
      maxProgress: 7,
      category: 'achievement',
    },
    {
      id: 'consistent_worker',
      name: 'Consistent Worker',
      description: 'Field work for 30 days straight',
      icon: '📅',
      color: '#8B5CF6',
      maxProgress: 30,
      category: 'achievement',
    },
    {
      id: 'survey_champion',
      name: 'Survey Champion',
      description: 'Complete 50 surveys',
      icon: '📋',
      color: '#10B981',
      maxProgress: 50,
      category: 'survey',
    },
    {
      id: 'donation_collector',
      name: 'Donation Collector',
      description: 'Collect 10 donations',
      icon: '💰',
      color: '#EF4444',
      maxProgress: 10,
      category: 'delivery',
    },
    {
      id: 'social_butterfly',
      name: 'Social Butterfly',
      description: 'Share 5 achievements',
      icon: '🦋',
      color: '#EC4899',
      maxProgress: 5,
      category: 'social',
    },
  ];

  // Achievement definitions
  private readonly ACHIEVEMENT_DEFINITIONS: Omit<Achievement, 'unlockedAt'>[] = [
    {
      id: 'first_step',
      title: 'First Step',
      description: 'Start your first tracking session',
      points: 10,
      type: 'milestone',
      icon: '👟',
    },
    {
      id: 'daily_warrior',
      title: 'Daily Warrior',
      description: 'Complete field work for 7 consecutive days',
      points: 100,
      type: 'streak',
      icon: '⚔️',
    },
    {
      id: 'marathon_runner',
      title: 'Marathon Runner',
      description: 'Walk 42.195km in total',
      points: 200,
      type: 'milestone',
      icon: '🏃',
    },
    {
      id: 'generous_heart',
      title: 'Generous Heart',
      description: 'Collect $100 in donations',
      points: 150,
      type: 'special',
      icon: '❤️',
    },
    {
      id: 'team_player',
      title: 'Team Player',
      description: 'Participate in team activities for 30 days',
      points: 300,
      type: 'milestone',
      icon: '🤝',
    },
  ];

  static getInstance(): GamificationService {
    if (!GamificationService.instance) {
      GamificationService.instance = new GamificationService();
    }
    return GamificationService.instance;
  }

  // Initialize gamification service
  async initialize(): Promise<void> {
    try {
      await this.loadUserStats();
      await this.checkDailyStreak();
      await this.updateBadgeProgress();
    } catch (error) {
      console.error('Error initializing gamification:', error);
    }
  }

  // Load user statistics
  private async loadUserStats(): Promise<void> {
    try {
      const statsJson = await AsyncStorage.getItem(this.STORAGE_KEYS.USER_STATS);
      if (statsJson) {
        this.userStats = JSON.parse(statsJson);
      } else {
        // Initialize new user stats
        this.userStats = {
          totalPoints: 0,
          level: 1,
          currentLevelPoints: 0,
          nextLevelPoints: 100,
          streak: 0,
          longestStreak: 0,
          badges: this.initializeBadges(),
          achievements: [],
        };
        await this.saveUserStats();
      }
    } catch (error) {
      console.error('Error loading user stats:', error);
      throw error;
    }
  }

  // Initialize badges
  private initializeBadges(): Badge[] {
    return this.BADGE_DEFINITIONS.map(def => ({
      ...def,
      unlocked: false,
      progress: 0,
    }));
  }

  // Save user statistics
  private async saveUserStats(): Promise<void> {
    if (this.userStats) {
      try {
        await AsyncStorage.setItem(this.STORAGE_KEYS.USER_STATS, JSON.stringify(this.userStats));
        this.notifyActivityCallbacks();
      } catch (error) {
        console.error('Error saving user stats:', error);
      }
    }
  }

  // Award points for activity
  async awardPoints(activity: keyof ActivityPoints, subActivity: string, quantity: number = 1): Promise<void> {
    if (!this.userStats) return;

    try {
      let pointsEarned = 0;
      const config = this.POINTS_CONFIG[activity];
      
      if (subActivity in config) {
        pointsEarned = (config as any)[subActivity] * quantity;
      }

      if (pointsEarned > 0) {
        this.userStats.totalPoints += pointsEarned;
        this.userStats.currentLevelPoints += pointsEarned;
        
        // Check for level up
        while (this.userStats.currentLevelPoints >= this.userStats.nextLevelPoints) {
          this.userStats.currentLevelPoints -= this.userStats.nextLevelPoints;
          this.userStats.level += 1;
          this.userStats.nextLevelPoints = this.calculateNextLevelPoints(this.userStats.level);
          
          console.log(`🎉 Level up! Now level ${this.userStats.level}`);
        }

        await this.saveUserStats();
        await this.checkAchievements();
        await this.updateBadgeProgress();
        
        console.log(`🏆 Awarded ${pointsEarned} points for ${activity}.${subActivity}`);
      }
    } catch (error) {
      console.error('Error awarding points:', error);
    }
  }

  // Calculate next level points requirement
  private calculateNextLevelPoints(level: number): number {
    return Math.floor(100 * Math.pow(1.5, level - 1));
  }

  // Check and update daily streak
  private async checkDailyStreak(): Promise<void> {
    if (!this.userStats) return;

    try {
      const today = new Date().toDateString();
      const lastActivity = await AsyncStorage.getItem('last_activity_date');
      
      if (lastActivity !== today) {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        
        if (lastActivity === yesterday.toDateString()) {
          // Continue streak
          this.userStats.streak += 1;
          this.userStats.longestStreak = Math.max(this.userStats.longestStreak, this.userStats.streak);
          
          // Award streak bonus
          if (this.userStats.streak >= 7) {
            await this.awardPoints('streak', 'weeklyBonus', 1);
          }
        } else {
          // Reset streak
          this.userStats.streak = 1;
        }
        
        await AsyncStorage.setItem('last_activity_date', today);
        await this.saveUserStats();
      }
    } catch (error) {
      console.error('Error checking daily streak:', error);
    }
  }

  // Update badge progress
  private async updateBadgeProgress(): Promise<void> {
    if (!this.userStats) return;

    try {
      const deliveryStats = await DeliveryTrackingService.getStats();
      const trackingStats = await GeotrackingService.getStats();

      for (const badge of this.userStats.badges) {
        if (badge.unlocked) continue;

        switch (badge.id) {
          case 'first_delivery':
            badge.progress = Math.min(badge.maxProgress, deliveryStats.totalDeliveries);
            break;
          case 'delivery_master':
            badge.progress = Math.min(badge.maxProgress, deliveryStats.totalDeliveries);
            break;
          case 'distance_walker':
            badge.progress = Math.min(badge.maxProgress, trackingStats.weeklyDistance / 1000);
            break;
          case 'survey_champion':
            // Would need survey stats
            badge.progress = 0;
            break;
          case 'donation_collector':
            // Would need donation stats
            badge.progress = 0;
            break;
        }

        // Check if badge should be unlocked
        if (badge.progress >= badge.maxProgress && !badge.unlocked) {
          badge.unlocked = true;
          badge.unlockedAt = Date.now();
          console.log(`🎖️ Badge unlocked: ${badge.name}`);
        }
      }

      await this.saveUserStats();
    } catch (error) {
      console.error('Error updating badge progress:', error);
    }
  }

  // Check for new achievements
  private async checkAchievements(): Promise<void> {
    if (!this.userStats) return;

    try {
      const trackingStats = await GeotrackingService.getStats();
      const deliveryStats = await DeliveryTrackingService.getStats();

      for (const achievementDef of this.ACHIEVEMENT_DEFINITIONS) {
        // Skip if already unlocked
        if (this.userStats.achievements.some(a => a.id === achievementDef.id)) {
          continue;
        }

        let shouldUnlock = false;

        switch (achievementDef.id) {
          case 'first_step':
            shouldUnlock = trackingStats.totalSessions > 0;
            break;
          case 'daily_warrior':
            shouldUnlock = this.userStats.streak >= 7;
            break;
          case 'marathon_runner':
            shouldUnlock = trackingStats.weeklyDistance >= 42195; // 42.195km in meters
            break;
          case 'generous_heart':
            // Would need donation stats
            shouldUnlock = false;
            break;
          case 'team_player':
            // Would need team participation stats
            shouldUnlock = false;
            break;
        }

        if (shouldUnlock) {
          const achievement: Achievement = {
            ...achievementDef,
            unlockedAt: Date.now(),
          };
          
          this.userStats.achievements.push(achievement);
          console.log(`🏆 Achievement unlocked: ${achievement.title}`);
        }
      }

      await this.saveUserStats();
    } catch (error) {
      console.error('Error checking achievements:', error);
    }
  }

  // Get user statistics
  getUserStats(): UserStats | null {
    return this.userStats;
  }

  // Get level progress percentage
  getLevelProgress(): number {
    if (!this.userStats) return 0;
    return (this.userStats.currentLevelPoints / this.userStats.nextLevelPoints) * 100;
  }

  // Get points to next level
  getPointsToNextLevel(): number {
    if (!this.userStats) return 0;
    return this.userStats.nextLevelPoints - this.userStats.currentLevelPoints;
  }

  // Get leaderboard (mock implementation)
  async getLeaderboard(period: 'weekly' | 'monthly'): Promise<Array<{ userId: string; name: string; points: number; rank: number }>> {
    // This would integrate with your backend API
    return [
      { userId: '1', name: 'John Doe', points: 2500, rank: 1 },
      { userId: '2', name: 'Jane Smith', points: 2300, rank: 2 },
      { userId: '3', name: 'Bob Johnson', points: 2100, rank: 3 },
    ];
  }

  // Register activity callback
  onActivityUpdate(callback: (stats: UserStats) => void): void {
    this.activityCallbacks.push(callback);
  }

  // Remove activity callback
  removeActivityCallback(callback: (stats: UserStats) => void): void {
    const index = this.activityCallbacks.indexOf(callback);
    if (index > -1) {
      this.activityCallbacks.splice(index, 1);
    }
  }

  // Notify all activity callbacks
  private notifyActivityCallbacks(): void {
    if (this.userStats) {
      this.activityCallbacks.forEach(callback => callback(this.userStats!));
    }
  }

  // Log activity for analytics
  async logActivity(activity: string, metadata?: any): Promise<void> {
    try {
      const activityLog = await AsyncStorage.getItem(this.STORAGE_KEYS.ACTIVITY_LOG);
      const logs = activityLog ? JSON.parse(activityLog) : [];
      
      logs.push({
        activity,
        timestamp: Date.now(),
        metadata,
      });
      
      // Keep only last 1000 activities
      if (logs.length > 1000) {
        logs.splice(0, logs.length - 1000);
      }
      
      await AsyncStorage.setItem(this.STORAGE_KEYS.ACTIVITY_LOG, JSON.stringify(logs));
    } catch (error) {
      console.error('Error logging activity:', error);
    }
  }

  // Get activity history
  async getActivityHistory(days: number = 7): Promise<Array<{ activity: string; timestamp: number; metadata?: any }>> {
    try {
      const activityLog = await AsyncStorage.getItem(this.STORAGE_KEYS.ACTIVITY_LOG);
      const logs = activityLog ? JSON.parse(activityLog) : [];
      
      const cutoffDate = Date.now() - (days * 24 * 60 * 60 * 1000);
      return logs.filter((log: any) => log.timestamp >= cutoffDate);
    } catch (error) {
      console.error('Error getting activity history:', error);
      return [];
    }
  }

  // Reset all data (for testing)
  async resetAllData(): Promise<void> {
    try {
      await AsyncStorage.multiRemove([
        this.STORAGE_KEYS.USER_STATS,
        this.STORAGE_KEYS.BADGES,
        this.STORAGE_KEYS.ACHIEVEMENTS,
        this.STORAGE_KEYS.ACTIVITY_LOG,
        'last_activity_date',
      ]);
      
      this.userStats = null;
      console.log('🔄 Gamification data reset');
    } catch (error) {
      console.error('Error resetting gamification data:', error);
    }
  }

  // Get available badges (locked and unlocked)
  getAvailableBadges(): Badge[] {
    return this.userStats?.badges || [];
  }

  // Get unlocked achievements
  getUnlockedAchievements(): Achievement[] {
    return this.userStats?.achievements || [];
  }

  // Get badge progress percentage
  getBadgeProgress(badgeId: string): number {
    const badge = this.userStats?.badges.find(b => b.id === badgeId);
    return badge ? (badge.progress / badge.maxProgress) * 100 : 0;
  }
}

export default GamificationService.getInstance();
