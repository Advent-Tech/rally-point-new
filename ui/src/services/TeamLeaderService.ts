import { DeliveryService } from './DeliveryService';
import { SurveyService } from './SurveyService';
import { territoryService } from './TerritoryService';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { authService } from './authService';
import TeamServiceBackendInstance from './TeamServiceBackend';
import { WorkerData } from './RealtimeLocationService';
import { BookDelivery } from '../types/ministry';
import { Survey, SurveyResponse } from '../types/survey';
import { Territory } from './TerritoryService';
import { ManagedUser } from '../types/userManagement';

// Helper function to safely convert timestamps to Date
const safeConvertToDate = (timestamp: any): Date => {
  if (!timestamp) return new Date();
  if (timestamp instanceof Date) return timestamp;
  if (timestamp && typeof timestamp.toDate === 'function') return timestamp.toDate();
  if (typeof timestamp === 'string' || typeof timestamp === 'number') return new Date(timestamp);
  if (timestamp.seconds) return new Date(timestamp.seconds * 1000);
  return new Date();
};

export interface TeamLeaderStats {
  totalWorkers: number;
  activeWorkers: number;
  totalTerritories: number;
  todayDeliveries: number;
  totalDeliveries: number;
  completedSurveys: number;
  onlineWorkers: number;
}

/**
 * TeamLeaderService - Provides team-scoped data access for Team Leaders
 * All methods filter data by the team leader's assigned teamId
 */
export class TeamLeaderService {
  private static getApiBase(): string {
    if (__DEV__) {
      return Platform.OS === 'android' ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
    }
    return 'https://api.rallypoint.app';
  }

  /**
   * Get all workers assigned to a specific team
   */
  static async getTeamWorkers(teamId: string): Promise<ManagedUser[]> {
    try {
      console.log('🔍 Fetching workers for team (backend):', teamId);
      const workers = await TeamServiceBackendInstance.getTeamMembers(teamId);
      console.log('✅ Found team workers (backend):', {
        teamId,
        workersCount: workers.length,
        workers: workers.map(w => ({ uid: w.uid, email: w.email, displayName: w.displayName, role: w.role }))
      });
      return workers;
    } catch (error) {
      console.error('❌ Error fetching team workers (backend):', error);
      throw error;
    }
  }

  /**
   * Get deliveries made by workers in a specific team
   */
  static async getTeamDeliveries(teamId: string): Promise<BookDelivery[]> {
    try {
      console.log('🔍 Fetching deliveries for team:', teamId);

      // First, get all workers in the team
      const teamWorkers = await this.getTeamWorkers(teamId);
      const workerIds = teamWorkers.map(w => w.uid);

      if (workerIds.length === 0) {
        console.log('⚠️ No workers found in team:', teamId);
        return [];
      }

      // Get all deliveries
      const allDeliveries = await DeliveryService.getAllDeliveries();

      // Filter deliveries by team workers
      const teamDeliveries = allDeliveries.filter(delivery =>
        workerIds.includes(delivery.workerId)
      );

      console.log('✅ Found', teamDeliveries.length, 'deliveries for team:', teamId);
      return teamDeliveries;
    } catch (error) {
      console.error('❌ Error fetching team deliveries:', error);
      throw error;
    }
  }

  /**
   * Get today's deliveries for a team
   */
  static async getTodayTeamDeliveries(teamId: string): Promise<BookDelivery[]> {
    try {
      const teamDeliveries = await this.getTeamDeliveries(teamId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      return teamDeliveries.filter(delivery => {
        const deliveryDate = new Date(delivery.deliveryTime);
        deliveryDate.setHours(0, 0, 0, 0);
        return deliveryDate.getTime() === today.getTime();
      });
    } catch (error) {
      console.error('❌ Error fetching today\'s team deliveries:', error);
      throw error;
    }
  }

  /**
   * Get territories assigned to team workers
   */
  static async getTeamTerritories(teamId: string): Promise<Territory[]> {
    try {
      console.log('🔍 Fetching territories for team:', teamId);

      // Get all workers in the team
      const teamWorkers = await this.getTeamWorkers(teamId);
      const workerIds = teamWorkers.map(w => w.uid);

      if (workerIds.length === 0) {
        console.log('⚠️ No workers found in team:', teamId);
        return [];
      }

      // Get all territories
      const allTerritories = await territoryService.getAllTerritories();

      // Filter territories assigned to team workers
      const teamTerritories = allTerritories.filter(territory =>
        territory.assignedWorker && workerIds.includes(territory.assignedWorker.id)
      );

      console.log('✅ Found', teamTerritories.length, 'territories for team:', teamId);
      return teamTerritories;
    } catch (error) {
      console.error('❌ Error fetching team territories:', error);
      throw error;
    }
  }

  /**
   * Get surveys created by or assigned to team members
   */
  static async getTeamSurveys(teamId: string): Promise<Survey[]> {
    try {
      console.log('🔍 Fetching surveys for team:', teamId);

      // Get all surveys
      const allSurveys = await SurveyService.getAllSurveys();

      // Get team workers
      const teamWorkers = await this.getTeamWorkers(teamId);
      const workerIds = teamWorkers.map(w => w.uid);

      // Filter surveys created by team members or assigned to team members
      const teamSurveys = allSurveys.filter(survey =>
        workerIds.includes(survey.createdBy?.uid) ||
        (survey.assignedTo && survey.assignedTo.some(user => workerIds.includes(user.uid)))
      );

      console.log('✅ Found', teamSurveys.length, 'surveys for team:', teamId);
      return teamSurveys;
    } catch (error) {
      console.error('❌ Error fetching team surveys:', error);
      throw error;
    }
  }

  /**
   * Get survey responses from team members
   */
  static async getTeamSurveyResponses(teamId: string, surveyId?: string): Promise<SurveyResponse[]> {
    try {
      console.log('🔍 Fetching survey responses for team:', teamId);

      // Get team workers
      const teamWorkers = await this.getTeamWorkers(teamId);
      const workerIds = teamWorkers.map(w => w.uid);

      if (workerIds.length === 0) {
        return [];
      }

      let allResponses: SurveyResponse[] = [];

      if (surveyId) {
        // Get responses for specific survey
        allResponses = await SurveyService.getSurveyResponses(surveyId);
      } else {
        // Get all surveys and their responses
        const teamSurveys = await this.getTeamSurveys(teamId);
        for (const survey of teamSurveys) {
          const responses = await SurveyService.getSurveyResponses(survey.id);
          allResponses.push(...responses);
        }
      }

      // Filter responses by team workers
      const teamResponses = allResponses.filter(response =>
        workerIds.includes(response.workerId)
      );

      console.log('✅ Found', teamResponses.length, 'survey responses for team:', teamId);
      return teamResponses;
    } catch (error) {
      console.error('❌ Error fetching team survey responses:', error);
      throw error;
    }
  }

  /**
   * Listen to active workers in real-time (team-scoped) - polling-based
   */
  static listenToTeamActiveWorkers(
    teamId: string,
    callback: (workers: WorkerData[]) => void
  ): () => void {
    console.log('🔄 Backend polling for team active workers:', teamId);
    let isCancelled = false;

    const fetchActive = async () => {
      try {
        const token = await authService.getValidToken();
        const apiBase = this.getApiBase();
        const resp = await fetch(`${apiBase}/api/workers/active`, {
          headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          }
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        const workers = Array.isArray(data) ? data : (data.workers || []);

        const teamMembers = await this.getTeamWorkers(teamId);
        const teamIds = new Set(teamMembers.map(m => m.uid));

        const mapped: WorkerData[] = workers
          .map((w: any) => ({
            id: w.user_id || w.userId || w.id,
            name: w.user_name || w.userName || 'Worker',
            email: w.email || '',
            isActive: !!(w.is_active ?? w.isActive),
            currentLocation: (w.latitude && w.longitude) ? {
              latitude: Number(w.latitude),
              longitude: Number(w.longitude),
              timestamp: w.last_seen ? (new Date(w.last_seen).valueOf()) : Date.now(),
              accuracy: w.accuracy ? Number(w.accuracy) : undefined,
              speed: w.speed ? Number(w.speed) : undefined,
              heading: w.heading ? Number(w.heading) : undefined,
            } : undefined,
            lastSeen: w.last_seen ? (new Date(w.last_seen).valueOf()) : Date.now(),
          }))
          .filter((wd: WorkerData) => teamIds.has(wd.id));

        callback(mapped);
      } catch (e) {
        callback([]);
      }
    };

    // initial fetch and interval polling
    fetchActive();
    const interval = setInterval(() => {
      if (!isCancelled) fetchActive();
    }, 5000);

    return () => {
      isCancelled = true;
      clearInterval(interval);
    };
  }

  /**
   * Get comprehensive team statistics
   */
  static async getTeamStats(teamId: string): Promise<TeamLeaderStats> {
    try {
      console.log('📊 Loading team statistics for:', teamId);

      const [
        teamWorkers,
        teamDeliveries,
        todayDeliveries,
        teamTerritories,
        teamSurveyResponses
      ] = await Promise.all([
        this.getTeamWorkers(teamId),
        this.getTeamDeliveries(teamId),
        this.getTodayTeamDeliveries(teamId),
        this.getTeamTerritories(teamId),
        this.getTeamSurveyResponses(teamId)
      ]);

      const onlineWorkers = teamWorkers.filter(w => w.isOnline).length;

      const stats: TeamLeaderStats = {
        totalWorkers: teamWorkers.length,
        activeWorkers: 0, // Will be updated by real-time listener
        totalTerritories: teamTerritories.length,
        todayDeliveries: todayDeliveries.length,
        totalDeliveries: teamDeliveries.length,
        completedSurveys: teamSurveyResponses.filter(r => r.isComplete).length,
        onlineWorkers
      };

      console.log('✅ Team statistics loaded:', stats);
      return stats;
    } catch (error) {
      console.error('❌ Error loading team statistics:', error);
      throw error;
    }
  }
}
