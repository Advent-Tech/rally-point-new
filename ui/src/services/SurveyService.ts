import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { OfflineManager } from './OfflineManager';
import {
  Survey,
  SurveyAssignment,
  SurveyResponse,
  SurveyAnalytics,
  SurveyFilters,
} from '../types/survey';

const OFFLINE_KEYS = {
  SURVEYS: '@rally_point_offline_surveys',
  ASSIGNMENTS: '@rally_point_offline_assignments',
  RESPONSES: '@rally_point_offline_responses',
  LAST_SYNC: '@rally_point_last_sync'
};

export class SurveyService {
  static async createSurvey(survey: Omit<Survey, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    try {
      const id = `survey_${Date.now()}`;
      const now = new Date();
      const newSurvey: Survey = {
        ...survey,
        id,
        createdAt: now,
        updatedAt: now,
      };

      const data = await AsyncStorage.getItem(OFFLINE_KEYS.SURVEYS);
      const surveys: Survey[] = data ? JSON.parse(data) : [];
      surveys.push(newSurvey);
      await AsyncStorage.setItem(OFFLINE_KEYS.SURVEYS, JSON.stringify(surveys));

      return id;
    } catch (error) {
      console.error('Error creating survey:', error);
      throw error;
    }
  }

  static async getAllSurveys(): Promise<Survey[]> {
    try {
      const data = await AsyncStorage.getItem(OFFLINE_KEYS.SURVEYS);
      return data ? JSON.parse(data) : [];
    } catch (error) {
      console.error('Error getting surveys:', error);
      return [];
    }
  }

  static async getSurveyById(surveyId: string): Promise<Survey | null> {
    try {
      const surveys = await this.getAllSurveys();
      return surveys.find(s => s.id === surveyId) || null;
    } catch (error) {
      console.error('Error getting survey:', error);
      return null;
    }
  }

  static async updateSurvey(surveyId: string, updates: Partial<Survey>): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(OFFLINE_KEYS.SURVEYS);
      const surveys: Survey[] = data ? JSON.parse(data) : [];
      const index = surveys.findIndex(s => s.id === surveyId);

      if (index !== -1) {
        surveys[index] = { ...surveys[index], ...updates, updatedAt: new Date() };
        await AsyncStorage.setItem(OFFLINE_KEYS.SURVEYS, JSON.stringify(surveys));
      }
    } catch (error) {
      console.error('Error updating survey:', error);
      throw error;
    }
  }

  static async deleteSurvey(surveyId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(OFFLINE_KEYS.SURVEYS);
      const surveys: Survey[] = data ? JSON.parse(data) : [];
      const filtered = surveys.filter(s => s.id !== surveyId);
      await AsyncStorage.setItem(OFFLINE_KEYS.SURVEYS, JSON.stringify(filtered));
    } catch (error) {
      console.error('Error deleting survey:', error);
      throw error;
    }
  }

  static async createAssignment(assignment: Omit<SurveyAssignment, 'id' | 'assignedAt'>): Promise<string> {
    try {
      const id = `assignment_${Date.now()}`;
      const newAssignment: SurveyAssignment = {
        ...assignment,
        id,
        assignedAt: new Date(),
      };

      const data = await AsyncStorage.getItem(OFFLINE_KEYS.ASSIGNMENTS);
      const assignments: SurveyAssignment[] = data ? JSON.parse(data) : [];
      assignments.push(newAssignment);
      await AsyncStorage.setItem(OFFLINE_KEYS.ASSIGNMENTS, JSON.stringify(assignments));

      return id;
    } catch (error) {
      console.error('Error creating assignment:', error);
      throw error;
    }
  }

  static async getWorkerAssignments(workerId: string): Promise<SurveyAssignment[]> {
    try {
      const data = await AsyncStorage.getItem(OFFLINE_KEYS.ASSIGNMENTS);
      const assignments: SurveyAssignment[] = data ? JSON.parse(data) : [];
      return assignments.filter(a => a.workerId === workerId);
    } catch (error) {
      console.error('Error getting worker assignments:', error);
      return [];
    }
  }

  // Alias for getWorkerAssignments - used by WorkerStatsService
  static async getAssignmentsForUser(userId: string): Promise<SurveyAssignment[]> {
    return this.getWorkerAssignments(userId);
  }

  // Subscribe to user assignments - used by WorkerDashboardScreen
  static subscribeToUserAssignments(userId: string, callback: (assignments: SurveyAssignment[]) => void): () => void {
    return this.listenToWorkerAssignments(userId, callback);
  }

  static async submitResponse(response: Omit<SurveyResponse, 'id' | 'submittedAt'>): Promise<string> {
    try {
      const id = `response_${Date.now()}`;
      const newResponse: SurveyResponse = {
        ...response,
        id,
        submittedAt: new Date(),
      };

      const data = await AsyncStorage.getItem(OFFLINE_KEYS.RESPONSES);
      const responses: SurveyResponse[] = data ? JSON.parse(data) : [];
      responses.push(newResponse);
      await AsyncStorage.setItem(OFFLINE_KEYS.RESPONSES, JSON.stringify(responses));

      return id;
    } catch (error) {
      console.error('Error submitting response:', error);
      throw error;
    }
  }

  static async getSurveyResponses(surveyId: string): Promise<SurveyResponse[]> {
    try {
      const data = await AsyncStorage.getItem(OFFLINE_KEYS.RESPONSES);
      const responses: SurveyResponse[] = data ? JSON.parse(data) : [];
      return responses.filter(r => r.surveyId === surveyId);
    } catch (error) {
      console.error('Error getting survey responses:', error);
      return [];
    }
  }

  static async getWorkerResponses(workerId: string): Promise<SurveyResponse[]> {
    try {
      const data = await AsyncStorage.getItem(OFFLINE_KEYS.RESPONSES);
      const responses: SurveyResponse[] = data ? JSON.parse(data) : [];
      return responses.filter(r => r.workerId === workerId);
    } catch (error) {
      console.error('Error getting worker responses:', error);
      return [];
    }
  }

  static listenToSurveys(callback: (surveys: Survey[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const surveys = await this.getAllSurveys();
      callback(surveys);
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  static listenToWorkerAssignments(workerId: string, callback: (assignments: SurveyAssignment[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const assignments = await this.getWorkerAssignments(workerId);
      callback(assignments);
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  static async getSurveyAnalytics(surveyId: string): Promise<SurveyAnalytics | null> {
    try {
      const responses = await this.getSurveyResponses(surveyId);
      return {
        surveyId,
        totalResponses: responses.length,
        completionRate: 0,
        averageCompletionTime: 0,
        responsesByDate: [],
      };
    } catch (error) {
      console.error('Error getting survey analytics:', error);
      return null;
    }
  }

  static async syncOfflineData(): Promise<{ success: number; failed: number }> {
    return { success: 0, failed: 0 };
  }
}

export default SurveyService;
