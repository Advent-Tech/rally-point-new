import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from './authService';
import { Platform } from 'react-native';
import type { ManagedUser } from '../types/userManagement';

// API base URL - API Gateway runs on port 8080
// Use 10.0.2.2 for Android emulator to reach host machine's localhost.
const API_BASE_URL = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

export interface Territory {
  id: string;
  name: string;
  description?: string;
  assigned_worker_id?: string;
  team_id: string;
  created_at: string;
  updated_at: string;
  coordinates?: any;
  boundary?: any; // GeoJSON boundary data
  color?: string; // Territory display color
  is_active?: boolean;
}

export interface TerritoryStats {
  total_territories: number;
  assigned_territories: number;
  unassigned_territories: number;
  total_workers: number;
}

class TerritoryServiceBackend {
  private async getAuthToken(): Promise<string | null> {
    try {
      const { authService } = await import('./authService');
      // Use getValidToken() which auto-refreshes expired tokens
      const token = await authService.getValidToken();

      if (!token) {
        console.log('⚠️ No auth token found. User may need to log in.');
        return null;
      }

      return token;
    } catch (error) {
      console.error('❌ Error getting auth token:', error);
      return null;
    }
  }

  private async makeRequest<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const token = await this.getAuthToken();

    console.log(`🔗 Territory API Request: ${options.method || 'GET'} ${url}`);
    console.log(`🔑 Auth token present: ${!!token}`);
    console.log(`🔑 Auth token preview: ${token ? `${token.substring(0, 20)}...` : 'none'}`);

    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
        ...options.headers,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Territory API Error: ${response.status} - ${errorText}`);
      
      // Handle 401 Unauthorized - token is invalid
      if (response.status === 401) {
        console.log('🔄 Token invalid, clearing auth and redirecting to login...');
        const { authService } = await import('./authService');
        await authService.clearAuth();
        // Note: In a real app, you'd navigate to login screen here
        throw new Error('Authentication required. Please log in again.');
      }
      
      throw new Error(errorText || `Request failed: ${response.status}`);
    }

    const responseText = await response.text();
    return responseText ? JSON.parse(responseText) : {} as T;
  }

  async getCurrentUserId(): Promise<string | null> {
    try {
      const response = await this.makeRequest<any>('/api/users/me');
      return response?.id || null;
    } catch (e) {
      return null;
    }
  }

  async getCurrentTeamId(): Promise<string | null> {
    try {
      const response = await this.makeRequest<any>('/api/users/me');
      if (response?.team_id) return response.team_id;
      // Fallback to stored user if /me doesn't include team
      try {
        const { authService } = await import('./authService');
        const storedUser = await authService.getStoredUser();
        return storedUser?.team_id || null;
      } catch {
        return null;
      }
    } catch (error) {
      console.error('❌ Error retrieving current team id:', error);
      // Fallback to stored user on error
      try {
        const { authService } = await import('./authService');
        const storedUser = await authService.getStoredUser();
        return storedUser?.team_id || null;
      } catch {
        return null;
      }
    }
  }

  async getTeamTerritories(): Promise<{ territories: Territory[]; count: number }> {
    try {
      const teamId = await this.getCurrentTeamId();
      if (!teamId) {
        console.warn('⚠️ No teamId available for current user');
        return { territories: [], count: 0 };
      }

      const response = await this.makeRequest<any>(
        `/api/territories/team/${teamId}`
      );
      const territories: Territory[] = Array.isArray(response)
        ? response
        : (response?.territories || []);
      const count: number = Array.isArray(response)
        ? territories.length
        : (response?.count ?? territories.length);
      return { territories, count };
    } catch (error) {
      console.error('❌ Error loading team territories:', error);
      throw error;
    }
  }

  async getWorkerTerritories(workerId: string): Promise<{ territories: Territory[]; count: number }> {
    const id = workerId || (await this.getCurrentUserId());
    if (!id) {
      return { territories: [], count: 0 };
    }
    try {
      const response = await this.makeRequest<any>(
        `/api/workers/${id}/territories`
      );
      const territories: Territory[] = Array.isArray(response)
        ? response
        : (response?.territories || []);
      const count: number = Array.isArray(response)
        ? territories.length
        : (response?.count ?? territories.length);
      return { territories, count };
    } catch (error) {
      // If backend returns 404 (e.g., route missing or no territories endpoint), return empty result
      const message = String((error as any)?.message || '').toLowerCase();
      if (message.includes('404')) {
        console.warn('⚠️ Worker territories endpoint returned 404; returning empty list.');
        return { territories: [], count: 0 };
      }
      console.error('❌ Error loading worker territories:', error);
      throw error;
    }
  }

  async createTerritory(territoryData: {
    name: string;
    description?: string;
    team_id: string;
    coordinates?: any;
  }): Promise<Territory> {
    try {
      // Use trailing slash to avoid 307 redirect that can trip CORS
      const response = await this.makeRequest<Territory>('/api/territories/', {
        method: 'POST',
        body: JSON.stringify(territoryData),
      });
      return response;
    } catch (error) {
      console.error('❌ Error creating territory:', error);
      throw error;
    }
  }

  async updateTerritory(territoryId: string, updates: {
    name?: string;
    description?: string;
    assigned_worker_id?: string;
    coordinates?: any;
  }): Promise<Territory> {
    try {
      const response = await this.makeRequest<Territory>(`/api/territories/${territoryId}`, {
        method: 'PUT',
        body: JSON.stringify(updates),
      });
      return response;
    } catch (error) {
      console.error('❌ Error updating territory:', error);
      throw error;
    }
  }

  async deleteTerritory(territoryId: string): Promise<void> {
    try {
      await this.makeRequest(`/api/territories/${territoryId}`, {
        method: 'DELETE',
      });
    } catch (error) {
      console.error('❌ Error deleting territory:', error);
      throw error;
    }
  }

  async assignTerritory(territoryId: string, workerId: string): Promise<void> {
    try {
      // Use the standard update endpoint to set assigned_worker_id
      await this.makeRequest(`/api/territories/${territoryId}`, {
        method: 'PUT',
        body: JSON.stringify({ assigned_worker_id: workerId })
      });
    } catch (error) {
      console.error('❌ Error assigning territory:', error);
      throw error;
    }
  }

  async getTeamStats(): Promise<{
    total_territories: number;
    assigned_territories: number;
    unassigned_territories: number;
    total_workers: number;
  }> {
    try {
      // No dedicated stats endpoint exposed in gateway; compute from territories
      const { territories } = await this.getTeamTerritories();
      const total_territories = territories.length;
      const assigned_territories = territories.filter(t => !!t.assigned_worker_id).length;
      const unassigned_territories = total_territories - assigned_territories;
      // If you have a workers endpoint, you can replace this with real team workers count
      const total_workers = 0;
      return { total_territories, assigned_territories, unassigned_territories, total_workers };
    } catch (error) {
      console.error('❌ Error loading team stats:', error);
      throw error;
    }
  }
}

export const TerritoryServiceBackendInstance = new TerritoryServiceBackend();
export default TerritoryServiceBackendInstance;
