import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { authService } from './authService';

export interface MinistryStats {
  totalHours: number;
  totalDistance: number;
  totalDeliveries: number;
  totalSurveys: number;
  territoriesCovered: number;
  donationsCollected: number;
  lastActivityDate: Date | null;
}

export interface RecentActivity {
  id: string;
  type: 'delivery' | 'survey' | 'session' | 'contact';
  title: string;
  subtitle: string;
  timestamp: Date;
  status: 'completed' | 'pending' | 'active';
  icon: string;
}

export interface DailyGoal {
  id: string;
  userId: string;
  date: string;
  targetDeliveries: number;
  targetHours: number;
  actualDeliveries: number;
  actualHours: number;
  isComplete: boolean;
}

const STATS_KEY = 'ministry_stats';
const ACTIVITIES_KEY = 'recent_activities';
const GOALS_KEY = 'daily_goals';

export class MinistryDataService {
  private static getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  static async getWorkerStats(userId: string): Promise<MinistryStats> {
    try {
      // Try backend first
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/stats/worker/${userId}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (response.ok) {
          const data = await response.json();
          await AsyncStorage.setItem(`${STATS_KEY}_${userId}`, JSON.stringify(data));
          return data;
        }
      }

      // Fallback to local storage
      const stored = await AsyncStorage.getItem(`${STATS_KEY}_${userId}`);
      if (stored) {
        return JSON.parse(stored);
      }

      return {
        totalHours: 0,
        totalDistance: 0,
        totalDeliveries: 0,
        totalSurveys: 0,
        territoriesCovered: 0,
        donationsCollected: 0,
        lastActivityDate: null,
      };
    } catch (error) {
      console.error('Error getting worker stats:', error);
      return {
        totalHours: 0,
        totalDistance: 0,
        totalDeliveries: 0,
        totalSurveys: 0,
        territoriesCovered: 0,
        donationsCollected: 0,
        lastActivityDate: null,
      };
    }
  }

  static async getRecentActivities(userId: string, limitCount: number = 10): Promise<RecentActivity[]> {
    try {
      const stored = await AsyncStorage.getItem(`${ACTIVITIES_KEY}_${userId}`);
      const activities: RecentActivity[] = stored ? JSON.parse(stored) : [];
      return activities
        .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
        .slice(0, limitCount);
    } catch (error) {
      console.error('Error getting recent activities:', error);
      return [];
    }
  }

  static async logActivity(userId: string, activity: Omit<RecentActivity, 'id' | 'timestamp'>): Promise<void> {
    try {
      const id = `activity_${Date.now()}`;
      const newActivity: RecentActivity = {
        ...activity,
        id,
        timestamp: new Date(),
      };

      const stored = await AsyncStorage.getItem(`${ACTIVITIES_KEY}_${userId}`);
      const activities: RecentActivity[] = stored ? JSON.parse(stored) : [];
      activities.push(newActivity);

      // Keep only last 100 activities
      if (activities.length > 100) {
        activities.splice(0, activities.length - 100);
      }

      await AsyncStorage.setItem(`${ACTIVITIES_KEY}_${userId}`, JSON.stringify(activities));
    } catch (error) {
      console.error('Error logging activity:', error);
    }
  }

  static async getDailyGoal(userId: string, date: string): Promise<DailyGoal | null> {
    try {
      const stored = await AsyncStorage.getItem(`${GOALS_KEY}_${userId}`);
      const goals: DailyGoal[] = stored ? JSON.parse(stored) : [];
      return goals.find(g => g.date === date) || null;
    } catch (error) {
      console.error('Error getting daily goal:', error);
      return null;
    }
  }

  static async setDailyGoal(goal: Omit<DailyGoal, 'id' | 'isComplete'>): Promise<void> {
    try {
      const stored = await AsyncStorage.getItem(`${GOALS_KEY}_${goal.userId}`);
      const goals: DailyGoal[] = stored ? JSON.parse(stored) : [];

      const existingIndex = goals.findIndex(g => g.date === goal.date);
      const newGoal: DailyGoal = {
        ...goal,
        id: `goal_${Date.now()}`,
        isComplete: goal.actualDeliveries >= goal.targetDeliveries && goal.actualHours >= goal.targetHours,
      };

      if (existingIndex !== -1) {
        goals[existingIndex] = newGoal;
      } else {
        goals.push(newGoal);
      }

      await AsyncStorage.setItem(`${GOALS_KEY}_${goal.userId}`, JSON.stringify(goals));
    } catch (error) {
      console.error('Error setting daily goal:', error);
    }
  }

  static async updateStats(userId: string, updates: Partial<MinistryStats>): Promise<void> {
    try {
      const current = await this.getWorkerStats(userId);
      const updated = { ...current, ...updates };
      await AsyncStorage.setItem(`${STATS_KEY}_${userId}`, JSON.stringify(updated));
    } catch (error) {
      console.error('Error updating stats:', error);
    }
  }

  static listenToStats(userId: string, callback: (stats: MinistryStats) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const stats = await this.getWorkerStats(userId);
      callback(stats);
    };

    poll();
    intervalId = setInterval(poll, 30000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  static listenToActivities(userId: string, callback: (activities: RecentActivity[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const activities = await this.getRecentActivities(userId);
      callback(activities);
    };

    poll();
    intervalId = setInterval(poll, 10000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }
}

export default MinistryDataService;
