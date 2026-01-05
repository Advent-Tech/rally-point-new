import React, { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AppState, AppStateStatus } from 'react-native';
import { authService, STORAGE_KEYS as AUTH_STORAGE_KEYS } from '../services/authService';
import TeamServiceBackendInstance from '../services/TeamServiceBackend';
import { User, GoogleAccount } from '../types';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  isFirstInstall: boolean;
  signIn: (email: string, password: string, rememberMe?: boolean) => Promise<void>;
  signInWithGoogle: (account: GoogleAccount, role?: 'worker' | 'team_leader') => Promise<{ isNewUser: boolean; user?: User }>;
  signUp: (userData: any) => Promise<void>;
  signOut: () => Promise<void>;
  checkUserExists: (email: string) => Promise<boolean>;
  refreshUserData: () => Promise<void>;
}

// Storage keys for persistence (local keys for AuthContext-specific data)
const LOCAL_STORAGE_KEYS = {
  LAST_ACTIVITY: '@rally_point_last_activity',
};

// Legacy key
const LAST_ACTIVITY_KEY = LOCAL_STORAGE_KEYS.LAST_ACTIVITY;

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: React.ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true); // Start with true to check stored auth
  const [isInitialized, setIsInitialized] = useState(false);
  const [isFirstInstall, setIsFirstInstall] = useState(false);

  // Token refresh interval ref
  const refreshIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const appStateRef = useRef<AppStateStatus>(AppState.currentState);

  // Token refresh interval (check every 5 minutes)
  const TOKEN_REFRESH_CHECK_INTERVAL = 5 * 60 * 1000;
  // Refresh buffer (refresh 2 minutes before expiry)
  const REFRESH_BUFFER_MS = 2 * 60 * 1000;

  /**
   * Check if token needs refresh and refresh if necessary
   */
  const checkAndRefreshToken = useCallback(async () => {
    if (!user) return;

    try {
      const expiryStr = await AsyncStorage.getItem(AUTH_STORAGE_KEYS.TOKEN_EXPIRY);
      if (!expiryStr) {
        console.log('⚠️ No token expiry found during background check');
        return;
      }

      const expiryTime = parseInt(expiryStr, 10);
      const now = Date.now();
      const timeUntilExpiry = expiryTime - now;

      console.log(`🕐 Token check: expires in ${Math.round(timeUntilExpiry / 1000 / 60)} minutes`);

      // If token expires within the buffer time, refresh it
      if (timeUntilExpiry <= REFRESH_BUFFER_MS) {
        console.log('🔄 Token expiring soon, refreshing proactively...');
        try {
          const authResponse = await authService.refreshToken();
          console.log('🔄 Refresh response user:', JSON.stringify(authResponse.user, null, 2));
          console.log('🔄 Refresh response user role:', authResponse.user?.role);
          if (authResponse.user && authResponse.user.role) {
            setUser(authResponse.user);
            console.log('✅ Background token refresh successful, role:', authResponse.user.role);
          } else {
            console.warn('⚠️ Refresh response missing user or role, not updating user state');
          }
        } catch (refreshError) {
          console.error('❌ Background token refresh failed:', refreshError);
          // Don't log out immediately - let the next API call handle it
        }
      }
    } catch (error) {
      console.error('❌ Error in background token check:', error);
    }
  }, [user]);

  /**
   * Start background token refresh
   */
  const startTokenRefreshInterval = useCallback(() => {
    // Clear any existing interval
    if (refreshIntervalRef.current) {
      clearInterval(refreshIntervalRef.current);
    }

    // Start new interval
    refreshIntervalRef.current = setInterval(checkAndRefreshToken, TOKEN_REFRESH_CHECK_INTERVAL);
    console.log('🔄 Background token refresh started');

    // Also do an immediate check
    checkAndRefreshToken();
  }, [checkAndRefreshToken]);

  /**
   * Stop background token refresh
   */
  const stopTokenRefreshInterval = useCallback(() => {
    if (refreshIntervalRef.current) {
      clearInterval(refreshIntervalRef.current);
      refreshIntervalRef.current = null;
      console.log('🛑 Background token refresh stopped');
    }
  }, []);

  // Load stored authentication on app start
  useEffect(() => {
    checkAppInstallAndLoadAuth();
  }, []);

  // Handle app state changes (background/foreground)
  useEffect(() => {
    const handleAppStateChange = (nextAppState: AppStateStatus) => {
      if (appStateRef.current.match(/inactive|background/) && nextAppState === 'active') {
        // App came to foreground - check token immediately
        console.log('📱 App came to foreground, checking token...');
        if (user) {
          checkAndRefreshToken();
        }
      }
      appStateRef.current = nextAppState;
    };

    const subscription = AppState.addEventListener('change', handleAppStateChange);
    return () => subscription?.remove();
  }, [user, checkAndRefreshToken]);

  // Start/stop background refresh based on user state
  useEffect(() => {
    if (user) {
      startTokenRefreshInterval();
    } else {
      stopTokenRefreshInterval();
    }

    return () => stopTokenRefreshInterval();
  }, [user, startTokenRefreshInterval, stopTokenRefreshInterval]);

  // Update activity when user is active
  useEffect(() => {
    if (user) {
      const updateActivity = async () => {
        try {
          await AsyncStorage.setItem(LAST_ACTIVITY_KEY, Date.now().toString());
        } catch (error) {
          console.error('❌ Error updating activity:', error);
        }
      };

      // Update activity every 5 minutes when user is active
      const activityInterval = setInterval(updateActivity, 5 * 60 * 1000);

      return () => clearInterval(activityInterval);
    }
  }, [user]);

  // Generate unique device ID
  const generateDeviceId = () => {
    return `device_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  };

  // Generate unique app install ID
  const generateAppInstallId = () => {
    return `install_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  };

  const clearAllAuthData = async () => {
    try {
      await authService.clearAuth();
      console.log('✅ All authentication data cleared successfully');
    } catch (error) {
      console.error('❌ Error clearing all auth data:', error);
    }
  };

  // Check if this is a new app installation
  const checkAppInstallAndLoadAuth = async () => {
    try {
      console.log('🔍 Loading stored authentication...');

      // Load stored user and token
      const storedUser = await authService.getStoredUser();
      const storedToken = await authService.getStoredToken();

      console.log('🔍 Stored user data:', JSON.stringify(storedUser, null, 2));
      console.log('🔍 Has token:', !!storedToken);

      if (storedUser && storedToken) {
        console.log('✅ Found stored auth, user role:', storedUser.role);
        setUser(storedUser);
      } else {
        console.log('📝 No stored auth found');
        setUser(null);
      }

      setIsFirstInstall(false);
    } catch (error) {
      console.error('❌ Error loading auth:', error);
      setUser(null);
    } finally {
      setLoading(false);
      setIsInitialized(true);
    }
  };

  const refreshUserData = async () => {
    try {
      if (!user) {
        console.warn('⚠️ refreshUserData: No user to refresh');
        return;
      }

      console.log('🔄 Refreshing user data...');
      
      // Fetch latest user data from backend
      const updatedUser = await authService.getProfile();
      setUser(updatedUser);
      
      console.log('✅ User data refreshed');
    } catch (error) {
      console.error('❌ Failed to refresh user data:', error);
    }
  };

  const checkUserExists = async (email: string): Promise<boolean> => {
    try {
      // For now, return false to always allow registration
      // In production, you might want to check with the backend
      return false;
    } catch (error) {
      console.error('Error checking user existence:', error);
      return false;
    }
  };

  const signIn = async (email: string, password: string, rememberMe: boolean = true) => {
    try {
      setLoading(true);
      console.log('🔐 Attempting sign in for:', email);

      // Use backend API for authentication
      const authResponse = await authService.login(email, password);
      console.log('🔍 Full auth response:', JSON.stringify(authResponse, null, 2));
      console.log('🔍 User from response:', JSON.stringify(authResponse.user, null, 2));
      console.log('🔍 User role from response:', authResponse.user?.role);

      // Save tokens and user data
      await authService.saveAuth(authResponse);

      // Update state
      setUser(authResponse.user);

      console.log('✅ Sign in successful, role:', authResponse.user?.role);
    } catch (error: any) {
      console.error('❌ Sign in failed:', error);
      throw new Error(error.message || 'Invalid email or password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const signUp = async (userData: any) => {
    try {
      setLoading(true);
      console.log('📝 Attempting sign up for:', userData);

      // Validate input
      if (!userData.email || !userData.password || !userData.role) {
        throw new Error('Invalid registration data. All fields are required.');
      }

      // Use backend API for registration
      const authResponse = await authService.register(
        userData.email, 
        userData.password, 
        userData.displayName || userData.email.split('@')[0], 
        userData.role,
        userData
      );
      
      // Save tokens and user data
      await authService.saveAuth(authResponse);
      
      setUser(authResponse.user);
      if ((userData.role === 'worker') && (userData.teamId || userData.team_id)) {
        const teamId = userData.teamId || userData.team_id;
        try {
          const joinRes = await TeamServiceBackendInstance.joinTeam(teamId);
          if ((joinRes as any)?.success === false) {
            console.warn('Join team failed:', (joinRes as any)?.message);
          }
          const refreshed = await authService.refreshToken();
          await authService.saveAuth(refreshed);
          setUser(refreshed.user);
          console.log('✅ Worker joined team and tokens refreshed');
        } catch (joinErr) {
          console.error('❌ Post-signup joinTeam failed:', joinErr);
          try {
            const updatedUser = await authService.getProfile();
            await AsyncStorage.setItem(AUTH_STORAGE_KEYS.AUTH_USER, JSON.stringify(updatedUser));
            setUser(updatedUser);
            console.log('✅ Worker joined team and profile updated without refresh');
          } catch (profileErr) {
            console.error('❌ Failed to update profile after joinTeam:', profileErr);
          }
        }
      }
      
      console.log('✅ Sign up successful');
    } catch (error: any) {
      console.error('❌ Sign up failed:', error);
      throw new Error(error.message || 'Registration failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const signOut = async () => {
    try {
      console.log('🚪 Signing out user');

      // Use backend API for logout
      await authService.logout();
      
      // Clear user state
      setUser(null);

      console.log('✅ Sign out successful');
    } catch (error) {
      console.error('❌ Sign out error:', error);
      // Always clear local state even if API call fails
      setUser(null);
      await authService.clearAuth();
    }
  };

  const signInWithGoogle = async (
    account: GoogleAccount,
    role?: 'worker' | 'team_leader'
  ): Promise<{ isNewUser: boolean; user?: User }> => {
    // Google sign in not implemented with backend yet
    throw new Error('Google sign in not yet available');
  };

  const value: AuthContextType = {
    user,
    loading,
    isFirstInstall,
    signIn,
    signInWithGoogle,
    signUp,
    signOut,
    checkUserExists,
    refreshUserData,
  };

  // Don't render children until auth state is initialized
  if (!isInitialized) {
    return null; // Or a loading spinner component
  }

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
