/**
 * Team Search Service
 * Team search with backend API and local storage
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { authService } from './authService';

const STORAGE_KEY = '@rally_point_teams_search';

export interface Team {
  teamId: string;
  teamName: string;
  leaderId?: string;
  leaderName?: string;
  memberCount?: number;
  createdAt: string;
  description?: string;
}

class TeamSearchService {
  private getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  /**
   * Search teams by name (case-insensitive)
   */
  async searchTeams(searchText: string): Promise<Team[]> {
    try {
      if (!searchText || searchText.trim().length === 0) {
        return [];
      }

      const allTeams = await this.getAllTeams();
      const searchLower = searchText.toLowerCase();

      return allTeams.filter(team =>
        (team.teamName || '').toLowerCase().includes(searchLower)
      );
    } catch (error) {
      console.error('❌ Error searching teams:', error);
      throw new Error('Failed to search teams');
    }
  }

  /**
   * Get all teams (for dropdown/autocomplete)
   */
  async getAllTeams(): Promise<Team[]> {
    try {
      // Try API first
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/teams`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (response.ok) {
          const data = await response.json();
          const teams: Team[] = (data || []).map((t: any) => ({
            teamId: t.id || t.teamId,
            teamName: t.name || t.teamName,
            leaderId: t.leaderId,
            leaderName: t.leaderName,
            memberCount: t.memberCount || 0,
            createdAt: t.createdAt,
            description: t.description,
          }));
          await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(teams));
          return teams.sort((a, b) => a.teamName.localeCompare(b.teamName));
        }
      }

      // Fallback to local storage
      const stored = await AsyncStorage.getItem(STORAGE_KEY);
      const teams: Team[] = stored ? JSON.parse(stored) : [];
      return teams.sort((a, b) => a.teamName.localeCompare(b.teamName));
    } catch (error) {
      console.error('❌ Error getting all teams:', error);
      throw new Error('Failed to get teams');
    }
  }

  /**
   * Get team by ID
   */
  async getTeamById(teamId: string): Promise<Team | null> {
    try {
      const teams = await this.getAllTeams();
      return teams.find(t => t.teamId === teamId) || null;
    } catch (error) {
      console.error('❌ Error getting team by ID:', error);
      return null;
    }
  }

  /**
   * Create a new team (for Team Leaders)
   */
  async createTeam(teamData: {
    teamName: string;
    leaderId: string;
    leaderName: string;
    description?: string;
  }): Promise<string> {
    try {
      const teamId = `team_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      const newTeam: Team = {
        teamId,
        teamName: teamData.teamName,
        leaderId: teamData.leaderId,
        leaderName: teamData.leaderName,
        description: teamData.description || '',
        memberCount: 1,
        createdAt: new Date().toISOString(),
      };

      // Store locally
      const stored = await AsyncStorage.getItem(STORAGE_KEY);
      const teams: Team[] = stored ? JSON.parse(stored) : [];
      teams.push(newTeam);
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(teams));

      // Try to sync to backend
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        await fetch(`${apiBase}/api/teams`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify(newTeam),
        }).catch(() => {});
      }

      console.log('✅ Team created successfully:', teamId);
      return teamId;
    } catch (error) {
      console.error('❌ Error creating team:', error);
      throw new Error('Failed to create team');
    }
  }

  /**
   * Update team member count
   */
  async updateTeamMemberCount(teamId: string, increment: number): Promise<void> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEY);
      const teams: Team[] = stored ? JSON.parse(stored) : [];
      const index = teams.findIndex(t => t.teamId === teamId);

      if (index === -1) {
        throw new Error('Team not found');
      }

      const currentCount = teams[index].memberCount || 0;
      teams[index].memberCount = Math.max(0, currentCount + increment);
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(teams));

      console.log('✅ Team member count updated');
    } catch (error) {
      console.error('❌ Error updating team member count:', error);
      throw new Error('Failed to update team member count');
    }
  }
}

// Export singleton instance
export default new TeamSearchService();
