/**
 * Google Authentication Service
 * Uses backend API for authentication - No Firebase dependency
 */

import { Platform } from 'react-native';
import { GoogleSignin } from '@react-native-google-signin/google-signin';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { authService } from './authService';

// Google Client IDs (from Google Cloud Console)
const WEB_CLIENT_ID = '503617293297-rvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv.apps.googleusercontent.com';
const IOS_CLIENT_ID = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

const STORAGE_KEYS = {
  GOOGLE_USER: '@rally_point_google_user',
  USER_DATA: '@rally_point_user_data',
};

export interface GoogleUserInfo {
  uid: string;
  email: string;
  displayName: string;
  photoURL?: string;
  idToken: string;
}

class GoogleAuthService {
  private initialized = false;
  private currentUser: GoogleUserInfo | null = null;

  private getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  /**
   * Initialize Google Sign-In
   * Must be called before using any other methods
   */
  async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      if (Platform.OS !== 'web') {
        // Configure Google Sign-In for mobile (Android/iOS)
        await GoogleSignin.configure({
          webClientId: WEB_CLIENT_ID,
          iosClientId: IOS_CLIENT_ID,
          offlineAccess: true,
          forceCodeForRefreshToken: true,
        });
        console.log('✅ Google Sign-In configured for mobile');
      } else {
        console.log('✅ Google Sign-In will use OAuth for web');
      }
      this.initialized = true;
    } catch (error) {
      console.error('❌ Google Sign-In initialization error:', error);
      throw new Error('Failed to initialize Google Sign-In');
    }
  }

  /**
   * Sign in with Google - Shows native account picker
   * Returns user info if successful
   */
  async signIn(): Promise<GoogleUserInfo> {
    try {
      await this.initialize();

      if (Platform.OS === 'web') {
        return await this.signInWeb();
      } else {
        return await this.signInMobile();
      }
    } catch (error: any) {
      console.error('❌ Google Sign-In error:', error);

      if (error.code === 'SIGN_IN_CANCELLED') {
        throw new Error('Sign in was cancelled');
      } else if (error.code === 'IN_PROGRESS') {
        throw new Error('Sign in is already in progress');
      } else if (error.code === 'PLAY_SERVICES_NOT_AVAILABLE') {
        throw new Error('Google Play Services not available');
      }

      throw new Error('Failed to sign in with Google');
    }
  }

  /**
   * Sign in with Google on Web platform
   * Uses OAuth redirect flow
   */
  private async signInWeb(): Promise<GoogleUserInfo> {
    // For web, we'll use a popup-based OAuth flow or redirect to backend
    // This is a simplified implementation - in production, you'd use a proper OAuth library
    throw new Error('Web Google Sign-In not implemented - use email/password login');
  }

  /**
   * Sign in with Google on Mobile platforms (Android/iOS)
   * Uses native Google Sign-In SDK
   */
  private async signInMobile(): Promise<GoogleUserInfo> {
    try {
      // Check if device supports Google Play Services (Android)
      await GoogleSignin.hasPlayServices();

      // Show native Google account picker
      const userInfo = await GoogleSignin.signIn();

      if (!userInfo.data) {
        throw new Error('No user data received from Google');
      }

      // Get the ID token
      const { idToken, user } = userInfo.data;

      if (!idToken) {
        throw new Error('No ID token received from Google');
      }

      // Exchange Google token with our backend for a JWT
      const apiBase = this.getApiBase();
      const response = await fetch(`${apiBase}/api/auth/google`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          idToken,
          email: user.email,
          name: user.name,
          photo: user.photo,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to authenticate with backend');
      }

      const authData = await response.json();

      const googleUser: GoogleUserInfo = {
        uid: authData.user?.uid || user.id,
        email: user.email,
        displayName: user.name || user.email.split('@')[0],
        photoURL: user.photo || undefined,
        idToken: authData.token || idToken,
      };

      // Store user info
      this.currentUser = googleUser;
      await AsyncStorage.setItem(STORAGE_KEYS.GOOGLE_USER, JSON.stringify(googleUser));

      return googleUser;
    } catch (error: any) {
      console.error('❌ Mobile Google Sign-In error:', error);
      throw error;
    }
  }

  /**
   * Sign out from Google
   */
  async signOut(): Promise<void> {
    try {
      if (Platform.OS !== 'web') {
        await GoogleSignin.signOut();
      }

      // Clear stored user data
      this.currentUser = null;
      await AsyncStorage.removeItem(STORAGE_KEYS.GOOGLE_USER);
      await AsyncStorage.removeItem(STORAGE_KEYS.USER_DATA);

      console.log('✅ Signed out from Google');
    } catch (error) {
      console.error('❌ Google Sign-Out error:', error);
      throw new Error('Failed to sign out from Google');
    }
  }

  /**
   * Check if user is currently signed in
   */
  async isSignedIn(): Promise<boolean> {
    try {
      if (Platform.OS !== 'web') {
        return await GoogleSignin.isSignedIn();
      }

      // Check local storage for web
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.GOOGLE_USER);
      return stored !== null;
    } catch (error) {
      console.error('❌ Error checking sign-in status:', error);
      return false;
    }
  }

  /**
   * Get current signed-in user info
   */
  async getCurrentUser(): Promise<GoogleUserInfo | null> {
    try {
      if (this.currentUser) {
        return this.currentUser;
      }

      const stored = await AsyncStorage.getItem(STORAGE_KEYS.GOOGLE_USER);
      if (stored) {
        this.currentUser = JSON.parse(stored);
        return this.currentUser;
      }

      return null;
    } catch (error) {
      console.error('❌ Error getting current user:', error);
      return null;
    }
  }

  /**
   * Check if user exists in backend
   */
  async checkUserExists(uid: string): Promise<boolean> {
    try {
      const token = await authService.getValidToken();
      if (!token) return false;

      const apiBase = this.getApiBase();
      const response = await fetch(`${apiBase}/api/users/${uid}`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      return response.ok;
    } catch (error) {
      console.error('❌ Error checking user existence:', error);
      return false;
    }
  }

  /**
   * Get user data from backend
   */
  async getUserData(uid: string): Promise<any | null> {
    try {
      const token = await authService.getValidToken();
      if (!token) return null;

      const apiBase = this.getApiBase();
      const response = await fetch(`${apiBase}/api/users/${uid}`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        await AsyncStorage.setItem(`${STORAGE_KEYS.USER_DATA}_${uid}`, JSON.stringify(data));
        return data;
      }

      // Fallback to local storage
      const stored = await AsyncStorage.getItem(`${STORAGE_KEYS.USER_DATA}_${uid}`);
      return stored ? JSON.parse(stored) : null;
    } catch (error) {
      console.error('❌ Error getting user data:', error);
      return null;
    }
  }

  /**
   * Save user data to backend
   */
  async saveUserData(uid: string, userData: any): Promise<void> {
    try {
      const token = await authService.getValidToken();

      // Save locally first
      const dataToSave = {
        ...userData,
        updatedAt: new Date().toISOString(),
      };
      await AsyncStorage.setItem(`${STORAGE_KEYS.USER_DATA}_${uid}`, JSON.stringify(dataToSave));

      // Try to sync to backend
      if (token) {
        const apiBase = this.getApiBase();
        await fetch(`${apiBase}/api/users/${uid}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify(dataToSave),
        });
      }

      console.log('✅ User data saved');
    } catch (error) {
      console.error('❌ Error saving user data:', error);
      throw new Error('Failed to save user data');
    }
  }
}

// Export singleton instance
export default new GoogleAuthService();
