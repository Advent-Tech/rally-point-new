import { authService } from './authService';
import { Platform } from 'react-native';

// API base URL - API Gateway runs on port 8080
const API_BASE_URL = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

export interface WorkerStats {
  // Location stats
  totalDistance: number;      // km
  totalTimeSeconds: number;   // seconds active
  averageSpeed: number;       // km/h
  maxSpeed: number;           // km/h
  locationCount: number;
  sessionCount: number;
  lastLocationTime: string | null;

  // Delivery stats
  totalDeliveries: number;
  todayDeliveries: number;

  // Donation stats
  totalDonations: number;

  // Survey stats
  totalSurveys: number;

  // Computed
  totalHours: number;         // hours active (computed from totalTimeSeconds)
  territoriesCovered: number;
}

export interface LocationStats {
  total_distance: number;
  total_time_seconds: number;
  average_speed: number;
  max_speed: number;
  location_count: number;
  session_count: number;
  last_location_time: string | null;
}

// Worker-specific stats interfaces (for team leaders/admins)
export interface WorkerLocationStats {
  worker_id: string;
  total_distance_km: number;
  total_time_seconds: number;
  total_hours: number;
  average_speed_kmh: number;
  max_speed_kmh: number;
  location_count: number;
  session_count: number;
  last_location_time: string | null;
  days: number;
}

export interface PathPoint {
  latitude: number;
  longitude: number;
  timestamp: number;
  tracked_at: string;
  accuracy?: number;
  speed?: number;
  session_id?: string;
}

export interface WorkerPathHistory {
  worker_id: string;
  path_points: PathPoint[];
  count: number;
}

export interface LocationSession {
  id: string;
  user_id: string;
  start_time: string;
  end_time: string | null;
  total_distance: number;
  location_count: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface WorkerSessions {
  worker_id: string;
  sessions: LocationSession[];
  count: number;
}

export interface WorkerSurveyStats {
  worker_id: string;
  assigned_count: number;
  completed_count: number;
  pending_count: number;
  overdue_count: number;
  completion_rate: number;
  today_completed: number;
  week_completed: number;
  month_completed: number;
}

class WorkerStatsServiceClass {
  private async getAuthToken(): Promise<string | null> {
    try {
      return await authService.getValidToken();
    } catch (error) {
      console.error('❌ Error getting auth token:', error);
      return null;
    }
  }

  private async makeRequest<T>(endpoint: string): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const token = await this.getAuthToken();

    if (!token) {
      throw new Error('Not authenticated');
    }

    console.log(`📊 Stats API Request: GET ${url}`);

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Stats API Error: ${response.status} - ${errorText}`);

      if (response.status === 401) {
        await authService.clearAuth();
        throw new Error('Authentication required. Please log in again.');
      }

      throw new Error(errorText || `Request failed: ${response.status}`);
    }

    const responseText = await response.text();
    return responseText ? JSON.parse(responseText) : ({} as T);
  }

  /**
   * Get location statistics from backend
   */
  async getLocationStats(days: number = 30): Promise<LocationStats> {
    try {
      const stats = await this.makeRequest<LocationStats>(`/api/location/stats?days=${days}`);
      return stats;
    } catch (error) {
      console.error('❌ Error fetching location stats:', error);
      // Return default values on error
      return {
        total_distance: 0,
        total_time_seconds: 0,
        average_speed: 0,
        max_speed: 0,
        location_count: 0,
        session_count: 0,
        last_location_time: null,
      };
    }
  }

  /**
   * Get combined worker statistics
   */
  async getWorkerStats(days: number = 30): Promise<WorkerStats> {
    try {
      // Get location stats from backend
      const locationStats = await this.getLocationStats(days);

      // TODO: Add delivery stats endpoint when available
      // const deliveryStats = await this.getDeliveryStats();

      // TODO: Add survey stats endpoint when available
      // const surveyStats = await this.getSurveyStats();

      // Combine all stats
      const stats: WorkerStats = {
        // Location stats
        totalDistance: locationStats.total_distance || 0,
        totalTimeSeconds: locationStats.total_time_seconds || 0,
        averageSpeed: locationStats.average_speed || 0,
        maxSpeed: locationStats.max_speed || 0,
        locationCount: locationStats.location_count || 0,
        sessionCount: locationStats.session_count || 0,
        lastLocationTime: locationStats.last_location_time,

        // Delivery stats (placeholder - implement when endpoint available)
        totalDeliveries: 0,
        todayDeliveries: 0,

        // Donation stats (placeholder)
        totalDonations: 0,

        // Survey stats (placeholder)
        totalSurveys: 0,

        // Computed values
        totalHours: (locationStats.total_time_seconds || 0) / 3600,
        territoriesCovered: 0, // TODO: Add territory tracking
      };

      console.log('📊 Worker stats loaded:', stats);
      return stats;
    } catch (error) {
      console.error('❌ Error fetching worker stats:', error);
      // Return default values on error
      return {
        totalDistance: 0,
        totalTimeSeconds: 0,
        averageSpeed: 0,
        maxSpeed: 0,
        locationCount: 0,
        sessionCount: 0,
        lastLocationTime: null,
        totalDeliveries: 0,
        todayDeliveries: 0,
        totalDonations: 0,
        totalSurveys: 0,
        totalHours: 0,
        territoriesCovered: 0,
      };
    }
  }

  /**
   * Start a location tracking session via backend
   */
  async startLocationSession(): Promise<{ id: string } | null> {
    try {
      const url = `${API_BASE_URL}/api/location/sessions/start`;
      const token = await this.getAuthToken();

      if (!token) {
        throw new Error('Not authenticated');
      }

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`❌ Start session error: ${response.status} - ${errorText}`);
        return null;
      }

      const result = await response.json();
      console.log('✅ Location session started:', result);
      return result;
    } catch (error) {
      console.error('❌ Error starting location session:', error);
      return null;
    }
  }

  /**
   * Update location to backend
   */
  async updateLocation(latitude: number, longitude: number, accuracy?: number, speed?: number, heading?: number): Promise<boolean> {
    try {
      const url = `${API_BASE_URL}/api/location/update`;
      const token = await this.getAuthToken();

      if (!token) {
        return false;
      }

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          latitude,
          longitude,
          accuracy,
          speed,
          heading,
        }),
      });

      if (!response.ok) {
        console.error(`❌ Location update error: ${response.status}`);
        return false;
      }

      return true;
    } catch (error) {
      console.error('❌ Error updating location:', error);
      return false;
    }
  }

  // ============ Worker-Specific Stats (for team leaders/admins) ============

  /**
   * Get location statistics for a specific worker
   * Requires team_leader or admin role
   */
  async getWorkerLocationStats(workerId: string, days: number = 30): Promise<WorkerLocationStats> {
    try {
      const stats = await this.makeRequest<WorkerLocationStats>(
        `/api/workers/${workerId}/location-stats?days=${days}`
      );
      console.log(`📊 Worker ${workerId} location stats:`, stats);
      return stats;
    } catch (error) {
      console.error(`❌ Error fetching worker ${workerId} location stats:`, error);
      return {
        worker_id: workerId,
        total_distance_km: 0,
        total_time_seconds: 0,
        total_hours: 0,
        average_speed_kmh: 0,
        max_speed_kmh: 0,
        location_count: 0,
        session_count: 0,
        last_location_time: null,
        days: days,
      };
    }
  }

  /**
   * Get path history for a specific worker
   * Requires team_leader or admin role
   */
  async getWorkerPathHistory(
    workerId: string,
    startTime?: string,
    endTime?: string,
    limit: number = 500
  ): Promise<WorkerPathHistory> {
    try {
      let endpoint = `/api/workers/${workerId}/path-history?limit=${limit}`;
      if (startTime && endTime) {
        endpoint += `&start_time=${encodeURIComponent(startTime)}&end_time=${encodeURIComponent(endTime)}`;
      }
      const history = await this.makeRequest<WorkerPathHistory>(endpoint);
      console.log(`📊 Worker ${workerId} path history: ${history.count} points`);
      return history;
    } catch (error) {
      console.error(`❌ Error fetching worker ${workerId} path history:`, error);
      return {
        worker_id: workerId,
        path_points: [],
        count: 0,
      };
    }
  }

  /**
   * Get sessions for a specific worker
   * Requires team_leader or admin role
   */
  async getWorkerSessions(
    workerId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<WorkerSessions> {
    try {
      const sessions = await this.makeRequest<WorkerSessions>(
        `/api/workers/${workerId}/sessions?limit=${limit}&offset=${offset}`
      );
      console.log(`📊 Worker ${workerId} sessions: ${sessions.count}`);
      return sessions;
    } catch (error) {
      console.error(`❌ Error fetching worker ${workerId} sessions:`, error);
      return {
        worker_id: workerId,
        sessions: [],
        count: 0,
      };
    }
  }

  /**
   * Get survey statistics for a specific worker
   * Requires team_leader or admin role
   */
  async getWorkerSurveyStats(workerId: string): Promise<WorkerSurveyStats> {
    try {
      const stats = await this.makeRequest<WorkerSurveyStats>(
        `/api/workers/${workerId}/survey-stats`
      );
      console.log(`📊 Worker ${workerId} survey stats:`, stats);
      return stats;
    } catch (error) {
      console.error(`❌ Error fetching worker ${workerId} survey stats:`, error);
      return {
        worker_id: workerId,
        assigned_count: 0,
        completed_count: 0,
        pending_count: 0,
        overdue_count: 0,
        completion_rate: 0,
        today_completed: 0,
        week_completed: 0,
        month_completed: 0,
      };
    }
  }

  /**
   * Get comprehensive stats for a specific worker (combines all stats)
   * Requires team_leader or admin role
   */
  async getComprehensiveWorkerStats(workerId: string, days: number = 30): Promise<{
    location: WorkerLocationStats;
    surveys: WorkerSurveyStats;
    pathHistory: WorkerPathHistory;
  }> {
    try {
      // Fetch all stats in parallel
      const [location, surveys, pathHistory] = await Promise.all([
        this.getWorkerLocationStats(workerId, days),
        this.getWorkerSurveyStats(workerId),
        this.getWorkerPathHistory(workerId),
      ]);

      return {
        location,
        surveys,
        pathHistory,
      };
    } catch (error) {
      console.error(`❌ Error fetching comprehensive stats for worker ${workerId}:`, error);
      return {
        location: {
          worker_id: workerId,
          total_distance_km: 0,
          total_time_seconds: 0,
          total_hours: 0,
          average_speed_kmh: 0,
          max_speed_kmh: 0,
          location_count: 0,
          session_count: 0,
          last_location_time: null,
          days: days,
        },
        surveys: {
          worker_id: workerId,
          assigned_count: 0,
          completed_count: 0,
          pending_count: 0,
          overdue_count: 0,
          completion_rate: 0,
          today_completed: 0,
          week_completed: 0,
          month_completed: 0,
        },
        pathHistory: {
          worker_id: workerId,
          path_points: [],
          count: 0,
        },
      };
    }
  }
}

export const WorkerStatsService = new WorkerStatsServiceClass();
export default WorkerStatsService;
