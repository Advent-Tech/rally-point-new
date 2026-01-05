import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { authService } from './authService';

export interface Team {
  teamId: string;
  teamName: string;
  teamPhoto: string | null;
  leaderId: string;
  leaderName: string;
  leaderEmail: string;
  createdAt: number;
  updatedAt: number;
  workerCount: number;
}

export interface CreateTeamParams {
  leaderId: string;
  leaderName: string;
  leaderEmail: string;
  teamName: string;
  teamPhoto?: string | null;
}

const TEAMS_KEY = 'teams';
const USERS_KEY = 'users';

export class TeamService {
  private static getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  static async createTeam(params: CreateTeamParams): Promise<{ success: boolean; teamId?: string; error?: string }> {
    try {
      const teamId = `team_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const now = Date.now();

      const teamData: Team = {
        teamId,
        teamName: params.teamName,
        teamPhoto: params.teamPhoto || null,
        leaderId: params.leaderId,
        leaderName: params.leaderName,
        leaderEmail: params.leaderEmail,
        createdAt: now,
        updatedAt: now,
        workerCount: 0,
      };

      const teamsData = await AsyncStorage.getItem(TEAMS_KEY);
      const teams: Team[] = teamsData ? JSON.parse(teamsData) : [];
      teams.push(teamData);
      await AsyncStorage.setItem(TEAMS_KEY, JSON.stringify(teams));

      console.log('Team created successfully:', teamId);
      return { success: true, teamId };
    } catch (error) {
      console.error('Error creating team:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to create team' };
    }
  }

  static async getTeamById(teamId: string): Promise<{ success: boolean; team?: Team; error?: string }> {
    try {
      const teamsData = await AsyncStorage.getItem(TEAMS_KEY);
      const teams: Team[] = teamsData ? JSON.parse(teamsData) : [];
      const team = teams.find(t => t.teamId === teamId);

      if (!team) {
        return { success: false, error: 'Team not found' };
      }

      return { success: true, team };
    } catch (error) {
      console.error('Error getting team:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to get team' };
    }
  }

  static async updateTeam(teamId: string, updates: Partial<Team>): Promise<{ success: boolean; error?: string }> {
    try {
      const teamsData = await AsyncStorage.getItem(TEAMS_KEY);
      const teams: Team[] = teamsData ? JSON.parse(teamsData) : [];
      const index = teams.findIndex(t => t.teamId === teamId);

      if (index !== -1) {
        teams[index] = { ...teams[index], ...updates, updatedAt: Date.now() };
        await AsyncStorage.setItem(TEAMS_KEY, JSON.stringify(teams));
      }

      console.log('Team updated successfully:', teamId);
      return { success: true };
    } catch (error) {
      console.error('Error updating team:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to update team' };
    }
  }

  static async deleteTeam(teamId: string): Promise<{ success: boolean; error?: string }> {
    try {
      const teamsData = await AsyncStorage.getItem(TEAMS_KEY);
      const teams: Team[] = teamsData ? JSON.parse(teamsData) : [];
      const filtered = teams.filter(t => t.teamId !== teamId);
      await AsyncStorage.setItem(TEAMS_KEY, JSON.stringify(filtered));

      console.log('Team deleted successfully:', teamId);
      return { success: true };
    } catch (error) {
      console.error('Error deleting team:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to delete team' };
    }
  }

  static async getTeamsByLeaderId(leaderId: string): Promise<{ success: boolean; teams?: Team[]; error?: string }> {
    try {
      const teamsData = await AsyncStorage.getItem(TEAMS_KEY);
      const teams: Team[] = teamsData ? JSON.parse(teamsData) : [];
      const filtered = teams.filter(t => t.leaderId === leaderId);

      return { success: true, teams: filtered };
    } catch (error) {
      console.error('Error getting teams by leader:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to get teams' };
    }
  }

  static async getAllTeams(): Promise<{ success: boolean; teams?: Team[]; error?: string }> {
    try {
      const teamsData = await AsyncStorage.getItem(TEAMS_KEY);
      const teams: Team[] = teamsData ? JSON.parse(teamsData) : [];

      return { success: true, teams };
    } catch (error) {
      console.error('Error getting all teams:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to get teams' };
    }
  }

  static async addWorkerToTeam(workerId: string, teamId: string, teamName: string): Promise<{ success: boolean; error?: string }> {
    try {
      const result = await this.getTeamById(teamId);
      if (result.team) {
        await this.updateTeam(teamId, { workerCount: (result.team.workerCount || 0) + 1 });
      }

      console.log('Worker added to team successfully');
      return { success: true };
    } catch (error) {
      console.error('Error adding worker to team:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to add worker to team' };
    }
  }

  static async removeWorkerFromTeam(workerId: string, teamId: string): Promise<{ success: boolean; error?: string }> {
    try {
      const result = await this.getTeamById(teamId);
      if (result.team) {
        await this.updateTeam(teamId, { workerCount: Math.max(0, (result.team.workerCount || 0) - 1) });
      }

      console.log('Worker removed from team successfully');
      return { success: true };
    } catch (error) {
      console.error('Error removing worker from team:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to remove worker from team' };
    }
  }

  static async getTeamWorkers(teamId: string): Promise<{ success: boolean; workers?: any[]; error?: string }> {
    try {
      // Return empty array - workers are managed via backend
      return { success: true, workers: [] };
    } catch (error) {
      console.error('Error getting team workers:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to get team workers' };
    }
  }

  static generateInviteLink(teamId: string, teamName: string): string {
    let origin = 'http://localhost:19006';

    try {
      if (typeof window !== 'undefined' && window.location && window.location.origin) {
        origin = window.location.origin;
      }
    } catch (error) {
      console.warn('Error accessing window.location.origin:', error);
    }

    return `${origin}/join-team?teamId=${encodeURIComponent(teamId)}&teamName=${encodeURIComponent(teamName)}`;
  }

  static parseInviteLink(url: string): { teamId: string; teamName: string } | null {
    try {
      let urlObj: URL;

      if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('rallypoint://')) {
        urlObj = new URL(url);
      } else if (url.includes('?')) {
        urlObj = new URL(`http://dummy.com${url.startsWith('/') ? '' : '/'}${url}`);
      } else {
        return null;
      }

      const teamId = urlObj.searchParams.get('teamId');
      const teamName = urlObj.searchParams.get('teamName');

      if (!teamId || !teamName) {
        return null;
      }

      return { teamId, teamName };
    } catch (error) {
      console.error('Error parsing invite link:', error);
      return null;
    }
  }

  static getTeamInfoFromURL(): { teamId: string; teamName: string } | null {
    if (typeof window === 'undefined') return null;

    try {
      if (!window.location || !window.location.search) {
        return null;
      }

      const urlParams = new URLSearchParams(window.location.search);
      const teamId = urlParams.get('teamId');
      const teamName = urlParams.get('teamName');

      if (teamId && teamName) {
        return { teamId, teamName };
      }
      return null;
    } catch (error) {
      console.error('Error extracting team info from URL:', error);
      return null;
    }
  }

  static async getTeamWithWorkers(teamId: string): Promise<{ success: boolean; team?: any; workers?: any[]; error?: string }> {
    try {
      const teamResult = await this.getTeamById(teamId);
      if (!teamResult.success || !teamResult.team) {
        return { success: false, error: 'Team not found' };
      }

      const workersResult = await this.getTeamWorkers(teamId);

      return {
        success: true,
        team: teamResult.team,
        workers: workersResult.workers || []
      };
    } catch (error) {
      console.error('Error getting team with workers:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to get team details' };
    }
  }

  static async getAllTeamsWithWorkers(): Promise<{ success: boolean; teams?: any[]; error?: string }> {
    try {
      const teamsResult = await this.getAllTeams();
      if (!teamsResult.success || !teamsResult.teams) {
        return { success: false, error: 'Failed to get teams' };
      }

      const teamsWithWorkers = await Promise.all(
        teamsResult.teams.map(async (team) => {
          const workersResult = await this.getTeamWorkers(team.teamId);
          return {
            ...team,
            workers: workersResult.workers || []
          };
        })
      );

      return { success: true, teams: teamsWithWorkers };
    } catch (error) {
      console.error('Error getting all teams with workers:', error);
      return { success: false, error: error instanceof Error ? error.message : 'Failed to get teams' };
    }
  }
}
