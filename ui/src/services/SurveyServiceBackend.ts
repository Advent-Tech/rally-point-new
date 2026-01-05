import { authService } from './authService';
import { Platform } from 'react-native';

const API_BASE_URL = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

// Types
export interface SurveyQuestion {
  id?: string;
  survey_id?: string;
  question_text: string;
  question_type: string; // text, multiple_choice, rating, yes_no, date, number
  options?: string[]; // For multiple choice
  is_required: boolean;
  order_index: number;
}

export interface Survey {
  id: string;
  title: string;
  description?: string;
  team_id: string;
  creator_id: string;
  is_active: boolean;
  start_date?: string;
  end_date?: string;
  questions?: SurveyQuestion[];
  created_at: string;
  updated_at: string;
}

export interface SurveyAnswer {
  id?: string;
  response_id?: string;
  question_id: string;
  answer: string;
}

export interface SurveyResponse {
  id: string;
  survey_id: string;
  user_id: string;
  user_name?: string;
  latitude?: number;
  longitude?: number;
  is_complete: boolean;
  answers?: SurveyAnswer[];
  created_at: string;
  updated_at: string;
}

export interface SurveyAssignment {
  id: string;
  survey_id: string;
  user_id: string;
  assigned_by: string;
  due_date?: string;
  is_complete: boolean;
  created_at: string;
  updated_at: string;
}

export interface SurveyStats {
  total_surveys: number;
  active_surveys: number;
  total_responses: number;
  completion_rate: number;
  average_completion: number; // minutes
}

export interface QuestionStats {
  question_id: string;
  question_text: string;
  question_type: string;
  total_answers: number;
  answers: Record<string, number>; // answer -> count
  statistics?: Record<string, number>; // For ratings: average, min, max
}

export interface SurveyAnalytics {
  survey: Survey;
  stats: SurveyStats;
  question_stats: QuestionStats[];
  response_trends: { date: string; responses: number }[];
}

export interface CreateSurveyRequest {
  title: string;
  description?: string;
  team_id: string;
  start_date?: string;
  end_date?: string;
  questions: Omit<SurveyQuestion, 'id' | 'survey_id'>[];
}

export interface SubmitResponseRequest {
  survey_id: string;
  latitude?: number;
  longitude?: number;
  answers: { question_id: string; answer: string }[];
}

class SurveyServiceBackendClass {
  private async getAuthToken(): Promise<string | null> {
    try {
      return await authService.getValidToken();
    } catch (error) {
      console.error('❌ Error getting auth token:', error);
      return null;
    }
  }

  private async makeRequest<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const token = await this.getAuthToken();

    if (!token) {
      throw new Error('Not authenticated');
    }

    console.log(`📋 Survey API: ${options.method || 'GET'} ${url}`);

    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...options.headers,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Survey API Error: ${response.status} - ${errorText}`);

      if (response.status === 401) {
        await authService.clearAuth();
        throw new Error('Authentication required. Please log in again.');
      }

      throw new Error(errorText || `Request failed: ${response.status}`);
    }

    const text = await response.text();
    return text ? JSON.parse(text) : ({} as T);
  }

  // ============ Survey CRUD ============

  async createSurvey(data: CreateSurveyRequest): Promise<Survey> {
    return this.makeRequest<Survey>('/api/surveys/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getSurvey(id: string): Promise<Survey> {
    return this.makeRequest<Survey>(`/api/surveys/${id}`);
  }

  async updateSurvey(id: string, data: Partial<CreateSurveyRequest>): Promise<Survey> {
    return this.makeRequest<Survey>(`/api/surveys/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deleteSurvey(id: string): Promise<void> {
    await this.makeRequest(`/api/surveys/${id}`, { method: 'DELETE' });
  }

  // ============ Team Surveys ============

  async getTeamSurveys(teamId: string): Promise<{ surveys: Survey[]; count: number }> {
    return this.makeRequest(`/api/teams/${teamId}/surveys`);
  }

  async getTeamStats(teamId: string): Promise<SurveyStats> {
    return this.makeRequest<SurveyStats>(`/api/teams/${teamId}/stats`);
  }

  // ============ User Surveys ============

  async getMySurveys(): Promise<{ surveys: Survey[]; count: number }> {
    return this.makeRequest('/api/users/surveys');
  }

  async getMyResponses(limit: number = 50, offset: number = 0): Promise<{ responses: SurveyResponse[]; count: number }> {
    return this.makeRequest(`/api/users/responses?limit=${limit}&offset=${offset}`);
  }

  async getMyAssignments(): Promise<{ assignments: SurveyAssignment[]; count: number }> {
    return this.makeRequest('/api/users/assignments');
  }

  // ============ Responses ============

  async submitResponse(data: SubmitResponseRequest): Promise<SurveyResponse> {
    return this.makeRequest<SurveyResponse>('/api/responses/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getSurveyResponses(
    surveyId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<{ responses: SurveyResponse[]; count: number }> {
    return this.makeRequest(`/api/surveys/${surveyId}/responses?limit=${limit}&offset=${offset}`);
  }

  // ============ Analytics ============

  async getSurveyAnalytics(surveyId: string): Promise<SurveyAnalytics> {
    return this.makeRequest<SurveyAnalytics>(`/api/surveys/${surveyId}/analytics`);
  }

  // ============ Assignments ============

  async assignSurvey(surveyId: string, userIds: string[], dueDate?: string): Promise<{ assignments: SurveyAssignment[] }> {
    return this.makeRequest('/api/assignments/', {
      method: 'POST',
      body: JSON.stringify({
        survey_id: surveyId,
        user_ids: userIds,
        due_date: dueDate,
      }),
    });
  }

  // ============ Helper Methods ============

  async getActiveSurveysForWorker(): Promise<Survey[]> {
    try {
      const { assignments } = await this.getMyAssignments();
      const incompleteSurveyIds = assignments
        .filter(a => !a.is_complete)
        .map(a => a.survey_id);

      const surveys: Survey[] = [];
      for (const surveyId of incompleteSurveyIds) {
        try {
          const survey = await this.getSurvey(surveyId);
          if (survey.is_active) {
            surveys.push(survey);
          }
        } catch (e) {
          console.warn(`Could not fetch survey ${surveyId}:`, e);
        }
      }

      return surveys;
    } catch (error) {
      console.error('Error fetching active surveys:', error);
      return [];
    }
  }

  async getWorkerSurveyStats(): Promise<{
    assigned: number;
    completed: number;
    pending: number;
  }> {
    try {
      const { assignments } = await this.getMyAssignments();
      const completed = assignments.filter(a => a.is_complete).length;
      const pending = assignments.filter(a => !a.is_complete).length;

      return {
        assigned: assignments.length,
        completed,
        pending,
      };
    } catch (error) {
      console.error('Error fetching worker survey stats:', error);
      return { assigned: 0, completed: 0, pending: 0 };
    }
  }
}

export const SurveyServiceBackend = new SurveyServiceBackendClass();
export default SurveyServiceBackend;
