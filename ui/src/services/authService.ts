import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { User } from '../types';

// Storage keys
export const STORAGE_KEYS = {
  AUTH_USER: '@rally_point_auth_user',
  AUTH_TOKEN: '@rally_point_auth_token',
  REFRESH_TOKEN: '@rally_point_refresh_token',
  TOKEN_EXPIRY: '@rally_point_token_expiry',
};

// API base URL - API Gateway runs on port 8080
// Use 10.0.2.2 for Android emulator to reach host machine's localhost.
const API_BASE_URL = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

// Auth response from backend
interface AuthResponse {
  user: User;
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

// Login request matching backend exactly
interface LoginRequest {
  email: string;
  password: string;
}

// Register request matching backend exactly
interface RegisterRequest {
  email: string;
  password: string;
  display_name: string;
  role?: string;
  phone?: string;
  team_name?: string;
  team_id?: string;
  skills?: string;
  self_description?: string;
}

// Refresh token request matching backend
interface RefreshTokenRequest {
  refresh_token: string;
}

class AuthService {
  private isRefreshing = false;
  private refreshPromise: Promise<AuthResponse> | null = null;

  // Buffer time before expiry to refresh (2 minutes)
  private readonly REFRESH_BUFFER_MS = 2 * 60 * 1000;

  /**
   * Check if token is expired or about to expire
   */
  private async isTokenExpired(): Promise<boolean> {
    try {
      const expiryStr = await AsyncStorage.getItem(STORAGE_KEYS.TOKEN_EXPIRY);
      if (!expiryStr) {
        console.log('⚠️ No token expiry found');
        return true;
      }

      const expiryTime = parseInt(expiryStr, 10);
      const now = Date.now();
      const isExpired = now >= expiryTime - this.REFRESH_BUFFER_MS;

      if (isExpired) {
        console.log(`🕐 Token expired or expiring soon (expiry: ${new Date(expiryTime).toISOString()}, now: ${new Date(now).toISOString()})`);
      }

      return isExpired;
    } catch (error) {
      console.error('Error checking token expiry:', error);
      return true;
    }
  }

  /**
   * Ensure we have a valid token before making requests
   * Auto-refreshes if token is expired or about to expire
   */
  private async ensureValidToken(): Promise<string | null> {
    const token = await AsyncStorage.getItem(STORAGE_KEYS.AUTH_TOKEN);
    const refreshToken = await AsyncStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN);

    // No tokens at all
    if (!token || !refreshToken) {
      return null;
    }

    // Check if token needs refresh
    const needsRefresh = await this.isTokenExpired();

    if (!needsRefresh) {
      return token;
    }

    // Token needs refresh
    console.log('🔄 Token needs refresh, attempting auto-refresh...');

    try {
      // Prevent multiple simultaneous refresh attempts
      if (this.isRefreshing && this.refreshPromise) {
        console.log('🔄 Refresh already in progress, waiting...');
        const result = await this.refreshPromise;
        return result.access_token;
      }

      this.isRefreshing = true;
      this.refreshPromise = this.performTokenRefresh();

      const result = await this.refreshPromise;
      return result.access_token;
    } catch (error) {
      console.error('❌ Auto-refresh failed:', error);
      // Clear auth on refresh failure - user needs to log in again
      await this.clearAuth();
      return null;
    } finally {
      this.isRefreshing = false;
      this.refreshPromise = null;
    }
  }

  /**
   * Perform the actual token refresh
   */
  private async performTokenRefresh(): Promise<AuthResponse> {
    const refreshToken = await AsyncStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN);
    if (!refreshToken) {
      throw new Error('No refresh token available');
    }

    console.log('🔄 Refreshing token...');

    const url = `${API_BASE_URL}/api/auth/refresh`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });

    const responseText = await response.text();

    if (!response.ok) {
      let error;
      try {
        error = JSON.parse(responseText);
      } catch {
        error = { error: responseText || `Refresh failed: ${response.status}` };
      }
      throw new Error(error.error || error.message || 'Token refresh failed');
    }

    const authResponse: AuthResponse = JSON.parse(responseText);
    await this.saveAuth(authResponse);

    console.log('✅ Token refreshed successfully');
    return authResponse;
  }

  private async request<T>(endpoint: string, options: RequestInit = {}, skipAuth: boolean = false): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;

    // For auth endpoints (login, register, refresh), don't try to add auth header
    let token: string | null = null;
    if (!skipAuth) {
      token = await this.ensureValidToken();
    }

    console.log(`🔗 API Request: ${options.method || 'GET'} ${url}`);

    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
        ...options.headers,
      },
      ...options,
    });

    // Handle non-JSON responses for health checks
    if (endpoint === '/health' || endpoint.includes('/health')) {
      if (!response.ok) {
        throw new Error(`Health check failed: ${response.status}`);
      }
      return {} as T;
    }

    const responseText = await response.text();
    console.log(`📦 API Response (${response.status}):`, responseText.substring(0, 200));

    // If we get 401, try refreshing once and retry
    if (response.status === 401 && !skipAuth) {
      console.log('🔄 Got 401, attempting token refresh and retry...');
      try {
        await this.performTokenRefresh();
        // Retry the request with new token
        return this.request<T>(endpoint, options, true);
      } catch (refreshError) {
        console.error('❌ Refresh on 401 failed:', refreshError);
        await this.clearAuth();
        throw new Error('Session expired. Please log in again.');
      }
    }

    if (!response.ok) {
      let error;
      try {
        error = JSON.parse(responseText);
      } catch {
        error = { error: responseText || `Request failed: ${response.status}` };
      }
      throw new Error(error.error || error.message || `Request failed: ${response.status}`);
    }

    if (responseText) {
      return JSON.parse(responseText);
    }
    return {} as T;
  }

  async login(email: string, password: string): Promise<AuthResponse> {
    console.log('🔐 Logging in:', email);
    // Skip auth check for login endpoint
    return this.request<AuthResponse>('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password } as LoginRequest),
    }, true);
  }

  async register(email: string, password: string, displayName: string, role?: string, additionalData?: any): Promise<AuthResponse> {
    console.log('📝 Registering:', email, 'with role:', role);

    const requestData: RegisterRequest = {
      email,
      password,
      display_name: displayName,
      role
    };

    // Add team-related data if provided
    if (additionalData) {
      if (additionalData.teamName) requestData.team_name = additionalData.teamName;
      if (additionalData.teamId) requestData.team_id = additionalData.teamId;
      if (additionalData.skills) requestData.skills = additionalData.skills;
      if (additionalData.selfDescription) requestData.self_description = additionalData.selfDescription;
    }

    // Skip auth check for register endpoint
    return this.request<AuthResponse>('/api/auth/register', {
      method: 'POST',
      body: JSON.stringify(requestData),
    }, true);
  }

  async refreshToken(): Promise<AuthResponse> {
    return this.performTokenRefresh();
  }

  async logout(): Promise<void> {
    try {
      await this.request('/api/auth/logout', { method: 'POST' });
    } catch (error) {
      console.warn('Logout request failed:', error);
    } finally {
      // Clear local storage regardless of API success
      await this.clearAuth();
    }
  }

  async getProfile(): Promise<User> {
    return this.request<User>('/api/users/me');
  }

  async saveAuth(authResponse: AuthResponse): Promise<void> {
    // Calculate token expiry time (expires_in is in seconds)
    // Default to 15 minutes if not provided (matching backend default)
    const expiresInMs = (authResponse.expires_in || 900) * 1000;
    const expiryTime = Date.now() + expiresInMs;

    await AsyncStorage.multiSet([
      [STORAGE_KEYS.AUTH_USER, JSON.stringify(authResponse.user)],
      [STORAGE_KEYS.AUTH_TOKEN, authResponse.access_token],
      [STORAGE_KEYS.REFRESH_TOKEN, authResponse.refresh_token],
      [STORAGE_KEYS.TOKEN_EXPIRY, expiryTime.toString()],
    ]);

    console.log(`💾 Auth data saved (token expires at ${new Date(expiryTime).toISOString()})`);
  }

  async getStoredUser(): Promise<User | null> {
    const userStr = await AsyncStorage.getItem(STORAGE_KEYS.AUTH_USER);
    return userStr ? JSON.parse(userStr) : null;
  }

  async getStoredToken(): Promise<string | null> {
    return await AsyncStorage.getItem(STORAGE_KEYS.AUTH_TOKEN);
  }

  /**
   * Get a valid token, auto-refreshing if expired
   * Use this for API calls that need authentication
   */
  async getValidToken(): Promise<string | null> {
    return this.ensureValidToken();
  }

  async clearAuth(): Promise<void> {
    await AsyncStorage.multiRemove([
      STORAGE_KEYS.AUTH_USER,
      STORAGE_KEYS.AUTH_TOKEN,
      STORAGE_KEYS.REFRESH_TOKEN,
      STORAGE_KEYS.TOKEN_EXPIRY,
    ]);
    console.log('🗑️ Auth data cleared');
  }

  // Health check to test API connectivity
  async healthCheck(): Promise<boolean> {
    try {
      await this.request('/health');
      return true;
    } catch (error) {
      console.error('Health check failed:', error);
      return false;
    }
  }
}

export const authService = new AuthService();
