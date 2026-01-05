import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { authService } from './authService';
import {
  UserProfile,
  UserStatistics,
  ProfileSettings,
  NotificationPreferences,
  PrivacySettings,
  UserPreferences,
  UpdateProfileFormData,
  ChangePasswordFormData,
  ProfileApiResponse,
  SOSSettings,
  FAQItem,
  SupportTicket,
  TrainingResource
} from '../types/profile';

const STORAGE_KEYS = {
  PROFILE: '@rally_point_profile',
  STATISTICS: '@rally_point_statistics',
  SETTINGS: '@rally_point_settings',
};

export class ProfileService {
  private static getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  static async getUserProfile(userId: string): Promise<UserProfile | null> {
    try {
      // Try to get from API first
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/users/${userId}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (response.ok) {
          const data = await response.json();
          await AsyncStorage.setItem(`${STORAGE_KEYS.PROFILE}_${userId}`, JSON.stringify(data));
          return data;
        }
      }

      // Fallback to local storage
      const stored = await AsyncStorage.getItem(`${STORAGE_KEYS.PROFILE}_${userId}`);
      return stored ? JSON.parse(stored) : null;
    } catch (error) {
      console.error('Error getting user profile:', error);
      const stored = await AsyncStorage.getItem(`${STORAGE_KEYS.PROFILE}_${userId}`);
      return stored ? JSON.parse(stored) : null;
    }
  }

  static async updateUserProfile(userId: string, updates: Partial<UserProfile>): Promise<void> {
    try {
      const current = await this.getUserProfile(userId);
      const updated = { ...current, ...updates, updatedAt: new Date() };
      await AsyncStorage.setItem(`${STORAGE_KEYS.PROFILE}_${userId}`, JSON.stringify(updated));

      // Try to sync to backend
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        await fetch(`${apiBase}/api/users/${userId}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify(updates),
        });
      }
    } catch (error) {
      console.error('Error updating profile:', error);
      throw error;
    }
  }

  static async getUserStatistics(userId: string): Promise<UserStatistics | null> {
    try {
      const stored = await AsyncStorage.getItem(`${STORAGE_KEYS.STATISTICS}_${userId}`);
      return stored ? JSON.parse(stored) : {
        userId,
        totalDeliveries: 0,
        totalSurveys: 0,
        totalDistance: 0,
        totalMinistryHours: 0,
        territoriesCovered: 0,
      };
    } catch (error) {
      console.error('Error getting statistics:', error);
      return null;
    }
  }

  static async getProfileSettings(userId: string): Promise<ProfileSettings | null> {
    try {
      const stored = await AsyncStorage.getItem(`${STORAGE_KEYS.SETTINGS}_${userId}`);
      return stored ? JSON.parse(stored) : {
        userId,
        notifications: {
          pushEnabled: true,
          emailEnabled: true,
          smsEnabled: false,
        },
        privacy: {
          shareLocation: true,
          shareActivity: true,
        },
        preferences: {
          language: 'en',
          theme: 'light',
        },
      };
    } catch (error) {
      console.error('Error getting settings:', error);
      return null;
    }
  }

  static async updateProfileSettings(userId: string, updates: Partial<ProfileSettings>): Promise<void> {
    try {
      const current = await this.getProfileSettings(userId);
      const updated = { ...current, ...updates };
      await AsyncStorage.setItem(`${STORAGE_KEYS.SETTINGS}_${userId}`, JSON.stringify(updated));
    } catch (error) {
      console.error('Error updating settings:', error);
      throw error;
    }
  }

  static async changePassword(data: ChangePasswordFormData): Promise<ProfileApiResponse> {
    // Password changes should go through the backend API
    try {
      const token = await authService.getValidToken();
      if (!token) {
        return { success: false, error: 'Not authenticated' };
      }

      const apiBase = this.getApiBase();
      const response = await fetch(`${apiBase}/api/auth/change-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(data),
      });

      if (response.ok) {
        return { success: true };
      } else {
        const error = await response.json();
        return { success: false, error: error.message || 'Failed to change password' };
      }
    } catch (error) {
      console.error('Error changing password:', error);
      return { success: false, error: 'Failed to change password' };
    }
  }

  static async getFAQItems(): Promise<FAQItem[]> {
    return [
      { id: '1', question: 'How do I track my location?', answer: 'Location tracking starts automatically when you begin a ministry session.', category: 'general' },
      { id: '2', question: 'How do I record a delivery?', answer: 'Use the delivery form on the home screen to record book deliveries.', category: 'deliveries' },
    ];
  }

  static async getTrainingResources(): Promise<TrainingResource[]> {
    return [];
  }

  static async submitSupportTicket(ticket: Omit<SupportTicket, 'id' | 'createdAt' | 'status'>): Promise<string> {
    const id = `ticket_${Date.now()}`;
    console.log('Support ticket submitted:', id, ticket);
    return id;
  }

  static listenToProfile(userId: string, callback: (profile: UserProfile | null) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const profile = await this.getUserProfile(userId);
      callback(profile);
    };

    poll();
    intervalId = setInterval(poll, 30000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }
}

export default ProfileService;
