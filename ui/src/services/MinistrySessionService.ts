import { calculateDistance } from '../utils/territoryUtils';
import AsyncStorage from '@react-native-async-storage/async-storage';
import OfflineManager from './OfflineManager';
import { Platform } from 'react-native';
import { authService } from './authService';

export interface PathPoint {
  latitude: number;
  longitude: number;
  timestamp: number;
  accuracy?: number;
  speed?: number;
  heading?: number;
}

export interface MinistrySession {
  id: string;
  userId: string;
  userName: string;
  userRole: string;
  startTime: number;
  endTime?: number;
  totalDistance: number;
  pathPoints: PathPoint[];
  territoryId?: string;
  territoryName?: string;
  teamId?: string;
  teamName?: string;
  isActive: boolean;
  sessionName: string;
  deliveryCount?: number;
  surveyCount?: number;
  contactCount?: number;
  createdAt: number;
  updatedAt: number;
  syncStatus: 'synced' | 'pending' | 'failed';
}

export interface SessionSummary {
  id: string;
  userId: string;
  userName: string;
  date: string;
  startTime: number;
  endTime?: number;
  duration: number;
  totalDistance: number;
  territoryName?: string;
  deliveryCount?: number;
  surveyCount?: number;
  contactCount?: number;
}

export interface SessionFilters {
  userId?: string;
  teamId?: string;
  territoryId?: string;
  startDate?: Date;
  endDate?: Date;
  minDistance?: number;
  maxDistance?: number;
  minDuration?: number;
  maxDuration?: number;
}

export interface SessionAnalytics {
  totalSessions: number;
  totalDistance: number;
  totalDuration: number;
  averageDistance: number;
  averageDuration: number;
  topWorkers: Array<{
    userId: string;
    userName: string;
    sessionCount: number;
    totalDistance: number;
    totalDuration: number;
  }>;
  dailyStats: Array<{
    date: string;
    sessionCount: number;
    totalDistance: number;
    totalDuration: number;
  }>;
}

class MinistrySessionService {
  private static instance: MinistrySessionService;
  private readonly STORAGE_KEY = 'offlineMinistrySession';
  private readonly SESSIONS_INDEX_KEY = 'ministrySessions_index';

  static getInstance(): MinistrySessionService {
    if (!MinistrySessionService.instance) {
      MinistrySessionService.instance = new MinistrySessionService();
    }
    return MinistrySessionService.instance;
  }

  private getApiBase(): string {
    if (Platform.OS === 'android') {
      return 'http://10.0.2.2:8080';
    }
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  /**
   * Start a new ministry session
   */
  async startSession(
    userId: string,
    userName: string,
    userRole: string,
    territoryId?: string,
    territoryName?: string,
    teamId?: string,
    teamName?: string,
    sessionName?: string
  ): Promise<string> {
    try {
      this.validateSessionData(userId, userName, userRole);
      const now = Date.now();
      const sessionId = `session_${userId}_${now}`;

      const session: MinistrySession = {
        id: sessionId,
        userId,
        userName,
        userRole,
        startTime: now,
        totalDistance: 0,
        pathPoints: [],
        territoryId,
        territoryName,
        teamId,
        teamName,
        isActive: true,
        sessionName: sessionName || `Session ${new Date(now).toLocaleDateString()}`,
        deliveryCount: 0,
        surveyCount: 0,
        contactCount: 0,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending'
      };

      // Store locally
      await this.storeOfflineSession(session);

      // Try to sync to backend
      try {
        const token = await authService.getValidToken();
        if (token) {
          const apiBase = this.getApiBase();
          const response = await fetch(`${apiBase}/api/sessions`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify(session),
          });

          if (response.ok) {
            const data = await response.json();
            if (data.id && data.id !== sessionId) {
              // Update with server-generated ID
              const updatedSession = { ...session, id: data.id, syncStatus: 'synced' as const };
              await this.storeOfflineSession(updatedSession);
              return data.id;
            }
            session.syncStatus = 'synced';
            await this.storeOfflineSession(session);
          }
        }
      } catch (error) {
        console.warn('⚠️ Failed to sync session to backend:', error);
      }

      console.log('✅ Ministry session started:', sessionId);
      return sessionId;
    } catch (error) {
      console.error('❌ Error starting ministry session:', error);
      throw error;
    }
  }

  /**
   * Add a path point to the current session
   */
  async addPathPoint(sessionId: string, pathPoint: PathPoint): Promise<void> {
    try {
      this.validatePathPoint(pathPoint);

      const session = await this.getSession(sessionId);
      if (!session || !session.isActive) {
        console.warn('⚠️ Cannot add path point to inactive session:', sessionId);
        return;
      }

      let additionalDistance = 0;
      if (session.pathPoints.length > 0) {
        const lastPoint = session.pathPoints[session.pathPoints.length - 1];
        additionalDistance = calculateDistance(
          lastPoint.latitude,
          lastPoint.longitude,
          pathPoint.latitude,
          pathPoint.longitude
        );

        const timeInterval = (pathPoint.timestamp - lastPoint.timestamp) / 1000 / 3600;
        const MAX_REASONABLE_SPEED_KMH = 60;
        const MIN_TIME_INTERVAL = 0.0005;

        if (timeInterval > MIN_TIME_INTERVAL) {
          const speedKmh = additionalDistance / timeInterval;
          if (speedKmh > MAX_REASONABLE_SPEED_KMH) {
            console.warn(`🚨 Unrealistic speed: ${speedKmh.toFixed(1)} km/h - SKIPPING`);
            return;
          }
        }

        const MIN_MEANINGFUL_DISTANCE = 0.003;
        if (additionalDistance < MIN_MEANINGFUL_DISTANCE) {
          return;
        }
      }

      const updatedPathPoints = [...session.pathPoints, pathPoint];
      const updatedDistance = session.totalDistance + additionalDistance;

      await this.updateSession(sessionId, {
        pathPoints: updatedPathPoints,
        totalDistance: updatedDistance,
        updatedAt: Date.now()
      });

      console.log(`✅ Path point added. Distance: +${additionalDistance.toFixed(3)}km, Total: ${updatedDistance.toFixed(2)}km`);
    } catch (error) {
      console.error('❌ Error adding path point:', error);
      throw error;
    }
  }

  /**
   * End a ministry session
   */
  async endSession(sessionId: string): Promise<MinistrySession | null> {
    try {
      const now = Date.now();
      const session = await this.getSession(sessionId);

      if (!session) {
        console.warn('⚠️ Session not found:', sessionId);
        return null;
      }

      if (!session.isActive) {
        console.warn('⚠️ Session already ended:', sessionId);
        return session;
      }

      const updatedSession = await this.updateSession(sessionId, {
        endTime: now,
        isActive: false,
        updatedAt: now
      });

      console.log(`✅ Session ended. Duration: ${((now - session.startTime) / 60000).toFixed(1)} min, Distance: ${session.totalDistance.toFixed(2)}km`);

      return updatedSession;
    } catch (error) {
      console.error('❌ Error ending session:', error);
      throw error;
    }
  }

  /**
   * Get a specific session by ID
   */
  async getSession(sessionId: string): Promise<MinistrySession | null> {
    try {
      const sessionData = await AsyncStorage.getItem(`${this.STORAGE_KEY}_${sessionId}`);
      if (sessionData) {
        return JSON.parse(sessionData);
      }
      return null;
    } catch (error) {
      console.error('❌ Error getting session:', error);
      return null;
    }
  }

  /**
   * Update a session
   */
  async updateSession(sessionId: string, updates: Partial<MinistrySession>): Promise<MinistrySession | null> {
    try {
      const session = await this.getSession(sessionId);
      if (!session) {
        console.warn('⚠️ Session not found:', sessionId);
        return null;
      }

      const updatedSession = { ...session, ...updates, updatedAt: Date.now(), syncStatus: 'pending' as const };
      await this.storeOfflineSession(updatedSession);

      return updatedSession;
    } catch (error) {
      console.error('❌ Error updating session:', error);
      throw error;
    }
  }

  /**
   * Store session offline
   */
  private async storeOfflineSession(session: MinistrySession): Promise<void> {
    try {
      await AsyncStorage.setItem(`${this.STORAGE_KEY}_${session.id}`, JSON.stringify(session));

      // Update sessions index
      const indexData = await AsyncStorage.getItem(this.SESSIONS_INDEX_KEY);
      const sessionIds: string[] = indexData ? JSON.parse(indexData) : [];
      if (!sessionIds.includes(session.id)) {
        sessionIds.push(session.id);
        await AsyncStorage.setItem(this.SESSIONS_INDEX_KEY, JSON.stringify(sessionIds));
      }

      // Also store in OfflineManager
      const offlineManager = OfflineManager.getInstance();
      await offlineManager.storeOfflineMinistrySession({
        id: session.id,
        userId: session.userId,
        userName: session.userName,
        userRole: session.userRole,
        teamId: session.teamId,
        territoryId: session.territoryId,
        sessionName: session.sessionName,
        startTime: session.startTime,
        endTime: session.endTime,
        totalDistance: session.totalDistance,
        pathPoints: session.pathPoints,
        isActive: session.isActive,
        syncStatus: session.syncStatus,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
      });

      console.log('✅ Session stored:', session.id);
    } catch (error) {
      console.error('❌ Error storing session:', error);
    }
  }

  /**
   * Get sessions with filters
   */
  async getSessions(filters: SessionFilters = {}): Promise<MinistrySession[]> {
    try {
      const indexData = await AsyncStorage.getItem(this.SESSIONS_INDEX_KEY);
      const sessionIds: string[] = indexData ? JSON.parse(indexData) : [];

      const sessions: MinistrySession[] = [];

      for (const sessionId of sessionIds) {
        const session = await this.getSession(sessionId);
        if (!session) continue;

        // Apply filters
        if (filters.userId && session.userId !== filters.userId) continue;
        if (filters.teamId && session.teamId !== filters.teamId) continue;
        if (filters.territoryId && session.territoryId !== filters.territoryId) continue;
        if (filters.startDate && session.startTime < filters.startDate.getTime()) continue;
        if (filters.endDate && session.startTime > filters.endDate.getTime()) continue;
        if (filters.minDistance && session.totalDistance < filters.minDistance) continue;
        if (filters.maxDistance && session.totalDistance > filters.maxDistance) continue;

        if (filters.minDuration || filters.maxDuration) {
          const duration = session.endTime ? (session.endTime - session.startTime) / 60000 : 0;
          if (filters.minDuration && duration < filters.minDuration) continue;
          if (filters.maxDuration && duration > filters.maxDuration) continue;
        }

        sessions.push(session);
      }

      // Sort by start time (most recent first)
      sessions.sort((a, b) => b.startTime - a.startTime);

      return sessions;
    } catch (error) {
      console.error('❌ Error getting sessions:', error);
      return [];
    }
  }

  /**
   * Get session summaries for display
   */
  async getSessionSummaries(filters: SessionFilters = {}): Promise<SessionSummary[]> {
    try {
      const sessions = await this.getSessions(filters);

      return sessions.map(session => ({
        id: session.id,
        userId: session.userId,
        userName: session.userName,
        date: new Date(session.startTime).toLocaleDateString(),
        startTime: session.startTime,
        endTime: session.endTime,
        duration: session.endTime ? (session.endTime - session.startTime) / 60000 : 0,
        totalDistance: session.totalDistance,
        territoryName: session.territoryName,
        deliveryCount: session.deliveryCount,
        surveyCount: session.surveyCount,
        contactCount: session.contactCount,
      }));
    } catch (error) {
      console.error('❌ Error getting summaries:', error);
      return [];
    }
  }

  /**
   * Get analytics for sessions
   */
  async getSessionAnalytics(filters: SessionFilters = {}): Promise<SessionAnalytics> {
    try {
      const sessions = await this.getSessions(filters);

      if (sessions.length === 0) {
        return {
          totalSessions: 0,
          totalDistance: 0,
          totalDuration: 0,
          averageDistance: 0,
          averageDuration: 0,
          topWorkers: [],
          dailyStats: []
        };
      }

      const totalSessions = sessions.length;
      const totalDistance = sessions.reduce((sum, s) => sum + s.totalDistance, 0);
      const totalDuration = sessions.reduce((sum, s) => {
        return sum + (s.endTime ? (s.endTime - s.startTime) / 60000 : 0);
      }, 0);

      const workerStats = new Map<string, {
        userId: string;
        userName: string;
        sessionCount: number;
        totalDistance: number;
        totalDuration: number;
      }>();

      sessions.forEach(session => {
        const existing = workerStats.get(session.userId) || {
          userId: session.userId,
          userName: session.userName,
          sessionCount: 0,
          totalDistance: 0,
          totalDuration: 0
        };

        existing.sessionCount++;
        existing.totalDistance += session.totalDistance;
        existing.totalDuration += session.endTime ? (session.endTime - session.startTime) / 60000 : 0;

        workerStats.set(session.userId, existing);
      });

      const topWorkers = Array.from(workerStats.values())
        .sort((a, b) => b.totalDistance - a.totalDistance)
        .slice(0, 10);

      const dailyStatsMap = new Map<string, {
        date: string;
        sessionCount: number;
        totalDistance: number;
        totalDuration: number;
      }>();

      sessions.forEach(session => {
        const date = new Date(session.startTime).toLocaleDateString();
        const existing = dailyStatsMap.get(date) || {
          date,
          sessionCount: 0,
          totalDistance: 0,
          totalDuration: 0
        };

        existing.sessionCount++;
        existing.totalDistance += session.totalDistance;
        existing.totalDuration += session.endTime ? (session.endTime - session.startTime) / 60000 : 0;

        dailyStatsMap.set(date, existing);
      });

      const dailyStats = Array.from(dailyStatsMap.values())
        .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

      return {
        totalSessions,
        totalDistance,
        totalDuration,
        averageDistance: totalDistance / totalSessions,
        averageDuration: totalDuration / totalSessions,
        topWorkers,
        dailyStats
      };
    } catch (error) {
      console.error('❌ Error getting analytics:', error);
      throw error;
    }
  }

  /**
   * Listen to real-time session updates (polling-based)
   */
  listenToSessions(
    filters: SessionFilters,
    callback: (sessions: MinistrySession[]) => void
  ): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const sessions = await this.getSessions(filters);
      callback(sessions);
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) {
        clearInterval(intervalId);
      }
    };
  }

  /**
   * Delete a session
   */
  async deleteSession(sessionId: string): Promise<void> {
    try {
      await AsyncStorage.removeItem(`${this.STORAGE_KEY}_${sessionId}`);

      // Update index
      const indexData = await AsyncStorage.getItem(this.SESSIONS_INDEX_KEY);
      const sessionIds: string[] = indexData ? JSON.parse(indexData) : [];
      const updatedIds = sessionIds.filter(id => id !== sessionId);
      await AsyncStorage.setItem(this.SESSIONS_INDEX_KEY, JSON.stringify(updatedIds));

      console.log('✅ Session deleted:', sessionId);
    } catch (error) {
      console.error('❌ Error deleting session:', error);
      throw error;
    }
  }

  /**
   * Sync offline sessions to backend
   */
  async syncOfflineSessions(): Promise<{ success: number; failed: number }> {
    try {
      const sessions = await this.getSessions({});
      const pendingSessions = sessions.filter(s => s.syncStatus === 'pending');

      let success = 0;
      let failed = 0;

      const token = await authService.getValidToken();
      if (!token) {
        console.warn('⚠️ No auth token for sync');
        return { success: 0, failed: pendingSessions.length };
      }

      const apiBase = this.getApiBase();

      for (const session of pendingSessions) {
        try {
          const response = await fetch(`${apiBase}/api/sessions`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify(session),
          });

          if (response.ok) {
            session.syncStatus = 'synced';
            await this.storeOfflineSession(session);
            success++;
          } else {
            failed++;
          }
        } catch (error) {
          console.error('❌ Error syncing session:', error);
          failed++;
        }
      }

      console.log(`✅ Sync complete: ${success} success, ${failed} failed`);
      return { success, failed };
    } catch (error) {
      console.error('❌ Error syncing sessions:', error);
      return { success: 0, failed: 0 };
    }
  }

  private validateSessionData(userId: string, userName: string, userRole: string): void {
    if (!userId || userId.trim() === '') {
      throw new Error('User ID is required');
    }
    if (!userName || userName.trim() === '') {
      throw new Error('User name is required');
    }
    if (!userRole || userRole.trim() === '') {
      throw new Error('User role is required');
    }
  }

  private validatePathPoint(pathPoint: PathPoint): void {
    if (!pathPoint) {
      throw new Error('Path point is required');
    }

    if (typeof pathPoint.latitude !== 'number' ||
        pathPoint.latitude < -90 ||
        pathPoint.latitude > 90) {
      throw new Error('Invalid latitude');
    }

    if (typeof pathPoint.longitude !== 'number' ||
        pathPoint.longitude < -180 ||
        pathPoint.longitude > 180) {
      throw new Error('Invalid longitude');
    }

    if (typeof pathPoint.timestamp !== 'number' ||
        pathPoint.timestamp <= 0 ||
        pathPoint.timestamp > Date.now() + 60000) {
      throw new Error('Invalid timestamp');
    }
  }
}

export const ministrySessionService = MinistrySessionService.getInstance();
export default MinistrySessionService;
