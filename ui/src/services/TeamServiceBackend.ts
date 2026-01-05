import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from './authService';
import { Platform } from 'react-native';

// API base URL - API Gateway runs on port 8080
// Use 10.0.2.2 for Android emulator to reach host machine's localhost.
const API_BASE_URL = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

export interface Team {
  id: string;
  name: string;
  description?: string;
  leader_id: string;
  photo_url?: string | null;
  worker_count: number;
  created_at: string;
  updated_at: string;
}

class TeamServiceBackend {
  private async getAuthToken(): Promise<string | null> {
    try {
      const token = await AsyncStorage.getItem(STORAGE_KEYS.AUTH_TOKEN);
      return token;
    } catch (error) {
      console.error('Error getting auth token:', error);
      return null;
    }
  }
  /**
   * Leave current team (for workers)
   */
  async leaveTeam(): Promise<{ success: boolean; message?: string }> {
    try {
      const response = await this.makeRequest<{ success: boolean; message?: string }>(`/api/teams/leave`, {
        method: 'POST',
      });
      return response;
    } catch (error) {
      console.error('Leave team error:', error);
      return { success: false, message: 'Failed to leave team' };
    }
  }

  private async makeRequest<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const token = await this.getAuthToken();

    console.log(`🔗 Team API Request: ${options.method || 'GET'} ${url}`);
    console.log(`🔑 Auth token present: ${!!token}`);

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
      console.error(`❌ Team API Error (${response.status}):`, errorText);
      throw new Error(`Team API request failed: ${response.status} - ${errorText}`);
    }

    const data = await response.json();
    console.log(`✅ Team API Response:`, data);
    return data;
  }

  /**
   * Search teams by name
   * Returns matching teams from backend API
   */
  async searchTeams(searchText: string): Promise<Team[]> {
    try {
      if (!searchText || searchText.trim().length === 0) {
        return [];
      }

      const response = await this.makeRequest<{ teams: Team[] }>(`/api/teams/search?q=${encodeURIComponent(searchText.trim())}`);
      return response.teams || [];
    } catch (error) {
      console.error('Team search error:', error);
      return [];
    }
  }

  /**
   * Get all available teams
   */
  async getAllTeams(): Promise<Team[]> {
    try {
      const response = await this.makeRequest<{ teams: Team[] }>('/api/teams/');
      return response.teams || [];
    } catch (error) {
      console.error('Get all teams error:', error);
      return [];
    }
  }

  /**
   * Get team by ID
   */
  async getTeamById(teamId: string): Promise<Team | null> {
    try {
      const response = await this.makeRequest<Team>(`/api/teams/${teamId}`);
      return response; // Return response directly instead of response.team
    } catch (error) {
      console.error('Get team by ID error:', error);
      return null;
    }
  }

  /**
   * Create a new team
   */
  async createTeam(params: { name: string; description?: string }): Promise<{ success: boolean; teamId?: string; error?: string }> {
    try {
      const response = await this.makeRequest<Team>(`/api/teams/`, {
        method: 'POST',
        body: JSON.stringify(params),
      });
      
      return { 
        success: true, 
        teamId: response.id // Use response.id instead of response.team.teamId
      };
    } catch (error) {
      console.error('Create team error:', error);
      return { success: false, error: 'Failed to create team' };
    }
  }

  /**
   * Join a team (for workers)
   */
  async joinTeam(teamId: string): Promise<{ success: boolean; message?: string }> {
    try {
      const response = await this.makeRequest<{ success: boolean; message?: string }>(`/api/teams/join`, {
        method: 'POST',
        body: JSON.stringify({ team_id: teamId }),
      });
      return response;
    } catch (error) {
      console.error('Join team error:', error);
      return { success: false, message: 'Failed to join team' };
    }
  }

  /**
   * Get members for a team (backend-powered)
   */
  async getTeamMembers(teamId: string): Promise<ManagedUser[]> {
    try {
      const response = await this.makeRequest<any>(`/api/teams/${teamId}/workers`);

      // Response may be { members: [...] } or an array directly
      const raw = Array.isArray(response) ? response : (response?.members || []);

      const members: ManagedUser[] = raw
        .filter((m: any) => (m.role || '').toLowerCase() === 'worker')
        .map((m: any) => ({
        uid: m.id || m.uid,
        email: m.email,
        displayName: m.display_name || m.displayName || (m.email ? m.email.split('@')[0] : 'Worker'),
        role: (m.role || 'worker') as any,
        teamId: m.team_id || m.teamId,
        teamName: m.team_name || m.teamName,
        isOnline: !!(m.is_online ?? m.isOnline),
        lastActiveAt: m.last_active_at ? new Date(m.last_active_at) : new Date(),
        createdAt: m.created_at ? new Date(m.created_at) : new Date(),
        updatedAt: m.updated_at ? new Date(m.updated_at) : new Date(),
        status: (m.status || 'active') as any,
        permissions: m.permissions || [],
      }));

      return members;
    } catch (error) {
      console.error('Get team members error:', error);
      return [];
    }
  }

  /**
   * Remove a member from a team
   */
  async removeTeamMember(teamId: string, userId: string): Promise<{ success: boolean; message?: string }> {
    try {
      await this.makeRequest(`/api/teams/${teamId}/members/${userId}`, {
        method: 'DELETE',
      });
      return { success: true };
    } catch (error) {
      console.error('Remove team member error:', error);
      return { success: false, message: 'Failed to remove team member' };
    }
  }
}

export const TeamServiceBackendInstance = new TeamServiceBackend();
export default TeamServiceBackendInstance;
