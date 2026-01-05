import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Platform-specific imports
let NetInfo: any;
if (Platform.OS !== 'web') {
  try {
    NetInfo = require('@react-native-community/netinfo');
  } catch (error) {
    console.warn('NetInfo not available:', error);
  }
}
import { SurveyService } from './SurveyService';
import {
  Survey,
  SurveyResponse,
  SurveyAssignment,
  OfflineSurveyData
} from '../types/survey';
import { MinistrySession, PathPoint } from './MinistrySessionService';

// Storage keys for offline data
const STORAGE_KEYS = {
  OFFLINE_RESPONSES: '@rally_point_offline_responses',
  OFFLINE_SURVEYS: '@rally_point_offline_surveys',
  OFFLINE_ASSIGNMENTS: '@rally_point_offline_assignments',
  OFFLINE_LOCATIONS: '@rally_point_offline_locations',
  OFFLINE_DELIVERIES: '@rally_point_offline_deliveries',
  OFFLINE_TRACKING_SESSIONS: '@rally_point_offline_tracking_sessions',
  OFFLINE_MINISTRY_SESSIONS: '@rally_point_offline_ministry_sessions',
  OFFLINE_PATH_POINTS: '@rally_point_offline_path_points',
  SYNC_QUEUE: '@rally_point_sync_queue',
  LAST_SYNC: '@rally_point_last_sync',
  NETWORK_STATUS: '@rally_point_network_status'
};

export interface SyncQueueItem {
  id: string;
  type: 'survey_response' | 'survey_update' | 'assignment_update' | 'location_update' | 'delivery_record' | 'tracking_session' | 'ministry_session' | 'path_point';
  data: any;
  timestamp: number;
  retryCount: number;
  maxRetries: number;
}

export interface OfflineLocationData {
  id: string;
  userId: string;
  userName: string;
  latitude: number;
  longitude: number;
  timestamp: number;
  accuracy?: number;
  speed?: number;
  heading?: number;
  sessionId?: string;
  syncStatus: 'pending' | 'synced' | 'failed';
}

export interface OfflineDeliveryData {
  id: string;
  workerId: string;
  workerName: string;
  bookTitle: string;
  deliveryType: 'door' | 'person';
  location: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  timestamp: number;
  status: 'delivered_to_person' | 'delivered_to_door' | 'not_home' | 'refused' | 'follow_up' | 'interested';
  notes?: string;
  sessionId?: string;
  syncStatus: 'pending' | 'synced' | 'failed';
}

export interface OfflineTrackingSession {
  id: string;
  userId: string;
  userName: string;
  startTime: number;
  endTime?: number;
  totalDistance: number;
  locationCount: number;
  deliveryCount: number;
  isActive: boolean;
  syncStatus: 'pending' | 'synced' | 'failed';
}

export interface OfflineMinistrySession {
  id: string;
  userId: string;
  userName: string;
  userRole: string;
  teamId?: string;
  territoryId?: string;
  sessionName: string;
  startTime: number;
  endTime?: number;
  totalDistance: number;
  pathPoints: PathPoint[];
  isActive: boolean;
  syncStatus: 'pending' | 'synced' | 'failed';
  createdAt: number;
  updatedAt: number;
}

export interface OfflinePathPoint {
  sessionId: string;
  latitude: number;
  longitude: number;
  timestamp: number;
  accuracy?: number;
  syncStatus: 'pending' | 'synced' | 'failed';
}

export interface NetworkStatus {
  isConnected: boolean;
  type: string | null;
  isInternetReachable: boolean | null;
}

export class OfflineManager {
  private static instance: OfflineManager;
  private networkStatus: NetworkStatus = {
    isConnected: false,
    type: null,
    isInternetReachable: null
  };
  private syncInProgress = false;
  private listeners: Array<(status: NetworkStatus) => void> = [];

  private constructor() {
    this.initializeNetworkListener();
  }

  static getInstance(): OfflineManager {
    if (!OfflineManager.instance) {
      OfflineManager.instance = new OfflineManager();
    }
    return OfflineManager.instance;
  }

  // Network Status Management
  private initializeNetworkListener() {
    if (Platform.OS === 'web' || !NetInfo) {
      // For web, assume always connected
      this.networkStatus = {
        isConnected: true,
        type: 'wifi',
        isInternetReachable: true
      };
      return;
    }

    NetInfo.addEventListener(state => {
      const newStatus: NetworkStatus = {
        isConnected: state.isConnected || false,
        type: state.type,
        isInternetReachable: state.isInternetReachable
      };

      const wasOffline = !this.networkStatus.isConnected;
      const isNowOnline = newStatus.isConnected;

      this.networkStatus = newStatus;
      this.storeNetworkStatus(newStatus);

      // Notify listeners
      this.listeners.forEach(listener => listener(newStatus));

      // Auto-sync when coming back online
      if (wasOffline && isNowOnline) {
        console.log('📶 Network restored, starting auto-sync...');
        this.syncOfflineData();
      }
    });
  }

  addNetworkListener(listener: (status: NetworkStatus) => void) {
    this.listeners.push(listener);
    // Immediately call with current status
    listener(this.networkStatus);
  }

  removeNetworkListener(listener: (status: NetworkStatus) => void) {
    this.listeners = this.listeners.filter(l => l !== listener);
  }

  getNetworkStatus(): NetworkStatus {
    return this.networkStatus;
  }

  private async storeNetworkStatus(status: NetworkStatus) {
    try {
      await AsyncStorage.setItem(STORAGE_KEYS.NETWORK_STATUS, JSON.stringify(status));
    } catch (error) {
      console.error('Error storing network status:', error);
    }
  }

  // Offline Data Storage
  async storeOfflineResponse(response: SurveyResponse): Promise<void> {
    try {
      const existingResponses = await this.getOfflineResponses();
      const updatedResponses = [...existingResponses, response];
      
      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_RESPONSES, 
        JSON.stringify(updatedResponses)
      );

      // Add to sync queue
      await this.addToSyncQueue({
        id: response.id,
        type: 'survey_response',
        data: response,
        timestamp: Date.now(),
        retryCount: 0,
        maxRetries: 3
      });

      console.log('✅ Response stored offline:', response.id);
    } catch (error) {
      console.error('❌ Error storing offline response:', error);
      throw error;
    }
  }

  async getOfflineResponses(): Promise<SurveyResponse[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.OFFLINE_RESPONSES);
      if (!stored) return [];

      const responses = JSON.parse(stored);
      // Convert date strings back to Date objects
      return responses.map((response: any) => ({
        ...response,
        submittedAt: new Date(response.submittedAt)
      }));
    } catch (error) {
      console.error('❌ Error getting offline responses:', error);
      return [];
    }
  }

  async removeOfflineResponse(responseId: string): Promise<void> {
    try {
      const responses = await this.getOfflineResponses();
      const filteredResponses = responses.filter(r => r.id !== responseId);

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_RESPONSES,
        JSON.stringify(filteredResponses)
      );
    } catch (error) {
      console.error('❌ Error removing offline response:', error);
    }
  }

  // Offline Location Data Management
  async storeOfflineLocation(locationData: OfflineLocationData): Promise<void> {
    try {
      const existingLocations = await this.getOfflineLocations();
      const updatedLocations = [...existingLocations, locationData];

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_LOCATIONS,
        JSON.stringify(updatedLocations)
      );

      // Add to sync queue
      await this.addToSyncQueue({
        id: locationData.id,
        type: 'location_update',
        data: locationData,
        timestamp: Date.now(),
        retryCount: 0,
        maxRetries: 5 // More retries for location data
      });

      console.log('✅ Location stored offline:', locationData.id);
    } catch (error) {
      console.error('❌ Error storing offline location:', error);
      throw error;
    }
  }

  async getOfflineLocations(): Promise<OfflineLocationData[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.OFFLINE_LOCATIONS);
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.error('❌ Error getting offline locations:', error);
      return [];
    }
  }

  async removeOfflineLocation(locationId: string): Promise<void> {
    try {
      const locations = await this.getOfflineLocations();
      const filteredLocations = locations.filter(l => l.id !== locationId);

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_LOCATIONS,
        JSON.stringify(filteredLocations)
      );
    } catch (error) {
      console.error('❌ Error removing offline location:', error);
    }
  }

  async getOfflineLocationsBySession(sessionId: string): Promise<OfflineLocationData[]> {
    try {
      const allLocations = await this.getOfflineLocations();
      return allLocations.filter(l => l.sessionId === sessionId);
    } catch (error) {
      console.error('❌ Error getting locations by session:', error);
      return [];
    }
  }

  // Offline Delivery Data Management
  async storeOfflineDelivery(deliveryData: OfflineDeliveryData): Promise<void> {
    try {
      const existingDeliveries = await this.getOfflineDeliveries();
      const updatedDeliveries = [...existingDeliveries, deliveryData];

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_DELIVERIES,
        JSON.stringify(updatedDeliveries)
      );

      // Add to sync queue
      await this.addToSyncQueue({
        id: deliveryData.id,
        type: 'delivery_record',
        data: deliveryData,
        timestamp: Date.now(),
        retryCount: 0,
        maxRetries: 3
      });

      console.log('✅ Delivery stored offline:', deliveryData.id);
    } catch (error) {
      console.error('❌ Error storing offline delivery:', error);
      throw error;
    }
  }

  async getOfflineDeliveries(): Promise<OfflineDeliveryData[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.OFFLINE_DELIVERIES);
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.error('❌ Error getting offline deliveries:', error);
      return [];
    }
  }

  async removeOfflineDelivery(deliveryId: string): Promise<void> {
    try {
      const deliveries = await this.getOfflineDeliveries();
      const filteredDeliveries = deliveries.filter(d => d.id !== deliveryId);

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_DELIVERIES,
        JSON.stringify(filteredDeliveries)
      );
    } catch (error) {
      console.error('❌ Error removing offline delivery:', error);
    }
  }

  async getOfflineDeliveriesBySession(sessionId: string): Promise<OfflineDeliveryData[]> {
    try {
      const allDeliveries = await this.getOfflineDeliveries();
      return allDeliveries.filter(d => d.sessionId === sessionId);
    } catch (error) {
      console.error('❌ Error getting deliveries by session:', error);
      return [];
    }
  }

  // Offline Tracking Session Management
  async storeOfflineTrackingSession(sessionData: OfflineTrackingSession): Promise<void> {
    try {
      const existingSessions = await this.getOfflineTrackingSessions();
      const existingIndex = existingSessions.findIndex(s => s.id === sessionData.id);

      if (existingIndex >= 0) {
        existingSessions[existingIndex] = sessionData;
      } else {
        existingSessions.push(sessionData);
      }

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_TRACKING_SESSIONS,
        JSON.stringify(existingSessions)
      );

      // Add to sync queue
      await this.addToSyncQueue({
        id: sessionData.id,
        type: 'tracking_session',
        data: sessionData,
        timestamp: Date.now(),
        retryCount: 0,
        maxRetries: 3
      });

      console.log('✅ Tracking session stored offline:', sessionData.id);
    } catch (error) {
      console.error('❌ Error storing offline tracking session:', error);
      throw error;
    }
  }

  async getOfflineTrackingSessions(): Promise<OfflineTrackingSession[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.OFFLINE_TRACKING_SESSIONS);
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.error('❌ Error getting offline tracking sessions:', error);
      return [];
    }
  }

  async removeOfflineTrackingSession(sessionId: string): Promise<void> {
    try {
      const sessions = await this.getOfflineTrackingSessions();
      const filteredSessions = sessions.filter(s => s.id !== sessionId);

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_TRACKING_SESSIONS,
        JSON.stringify(filteredSessions)
      );
    } catch (error) {
      console.error('❌ Error removing offline tracking session:', error);
    }
  }

  async getActiveOfflineTrackingSession(userId: string): Promise<OfflineTrackingSession | null> {
    try {
      const sessions = await this.getOfflineTrackingSessions();
      return sessions.find(s => s.userId === userId && s.isActive) || null;
    } catch (error) {
      console.error('❌ Error getting active tracking session:', error);
      return null;
    }
  }

  // Offline Ministry Session Management
  async storeOfflineMinistrySession(sessionData: OfflineMinistrySession): Promise<void> {
    try {
      const existingSessions = await this.getOfflineMinistrySessions();
      const existingIndex = existingSessions.findIndex(s => s.id === sessionData.id);

      if (existingIndex >= 0) {
        existingSessions[existingIndex] = sessionData;
      } else {
        existingSessions.push(sessionData);
      }

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_MINISTRY_SESSIONS,
        JSON.stringify(existingSessions)
      );

      // Add to sync queue if not already synced
      if (sessionData.syncStatus === 'pending') {
        await this.addToSyncQueue({
          id: sessionData.id,
          type: 'ministry_session',
          data: sessionData,
          timestamp: Date.now(),
          retryCount: 0,
          maxRetries: 3
        });
      }

      console.log('✅ Stored offline ministry session:', sessionData.id);
    } catch (error) {
      console.error('❌ Error storing offline ministry session:', error);
      throw error;
    }
  }

  async getOfflineMinistrySessions(): Promise<OfflineMinistrySession[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.OFFLINE_MINISTRY_SESSIONS);
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.error('❌ Error getting offline ministry sessions:', error);
      return [];
    }
  }

  async removeOfflineMinistrySession(sessionId: string): Promise<void> {
    try {
      const sessions = await this.getOfflineMinistrySessions();
      const filteredSessions = sessions.filter(s => s.id !== sessionId);

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_MINISTRY_SESSIONS,
        JSON.stringify(filteredSessions)
      );
    } catch (error) {
      console.error('❌ Error removing offline ministry session:', error);
    }
  }

  async getActiveOfflineMinistrySession(userId: string): Promise<OfflineMinistrySession | null> {
    try {
      const sessions = await this.getOfflineMinistrySessions();
      return sessions.find(s => s.userId === userId && s.isActive) || null;
    } catch (error) {
      console.error('❌ Error getting active ministry session:', error);
      return null;
    }
  }

  // Offline Path Point Management
  async storeOfflinePathPoint(pathPoint: OfflinePathPoint): Promise<void> {
    try {
      const existingPoints = await this.getOfflinePathPoints();
      existingPoints.push(pathPoint);

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_PATH_POINTS,
        JSON.stringify(existingPoints)
      );

      // Add to sync queue if not already synced
      if (pathPoint.syncStatus === 'pending') {
        await this.addToSyncQueue({
          id: `${pathPoint.sessionId}_${pathPoint.timestamp}`,
          type: 'path_point',
          data: pathPoint,
          timestamp: Date.now(),
          retryCount: 0,
          maxRetries: 3
        });
      }

      console.log('✅ Stored offline path point for session:', pathPoint.sessionId);
    } catch (error) {
      console.error('❌ Error storing offline path point:', error);
      throw error;
    }
  }

  async getOfflinePathPoints(sessionId?: string): Promise<OfflinePathPoint[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.OFFLINE_PATH_POINTS);
      const allPoints = stored ? JSON.parse(stored) : [];

      if (sessionId) {
        return allPoints.filter((point: OfflinePathPoint) => point.sessionId === sessionId);
      }

      return allPoints;
    } catch (error) {
      console.error('❌ Error getting offline path points:', error);
      return [];
    }
  }

  async removeOfflinePathPoints(sessionId: string): Promise<void> {
    try {
      const allPoints = await this.getOfflinePathPoints();
      const filteredPoints = allPoints.filter(p => p.sessionId !== sessionId);

      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_PATH_POINTS,
        JSON.stringify(filteredPoints)
      );
    } catch (error) {
      console.error('❌ Error removing offline path points:', error);
    }
  }

  // Sync Queue Management
  private async addToSyncQueue(item: SyncQueueItem): Promise<void> {
    try {
      const queue = await this.getSyncQueue();
      queue.push(item);
      await AsyncStorage.setItem(STORAGE_KEYS.SYNC_QUEUE, JSON.stringify(queue));
    } catch (error) {
      console.error('❌ Error adding to sync queue:', error);
    }
  }

  private async getSyncQueue(): Promise<SyncQueueItem[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.SYNC_QUEUE);
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.error('❌ Error getting sync queue:', error);
      return [];
    }
  }

  private async updateSyncQueue(queue: SyncQueueItem[]): Promise<void> {
    try {
      await AsyncStorage.setItem(STORAGE_KEYS.SYNC_QUEUE, JSON.stringify(queue));
    } catch (error) {
      console.error('❌ Error updating sync queue:', error);
    }
  }

  // Sync Operations
  async syncOfflineData(): Promise<{ success: number; failed: number }> {
    if (this.syncInProgress) {
      console.log('⏳ Sync already in progress, skipping...');
      return { success: 0, failed: 0 };
    }

    if (!this.networkStatus.isConnected) {
      console.log('📵 No network connection, skipping sync');
      return { success: 0, failed: 0 };
    }

    this.syncInProgress = true;
    let successCount = 0;
    let failedCount = 0;

    try {
      console.log('🔄 Starting offline data sync...');
      
      const queue = await this.getSyncQueue();
      const updatedQueue: SyncQueueItem[] = [];

      for (const item of queue) {
        try {
          await this.syncQueueItem(item);
          successCount++;
          console.log(`✅ Synced item: ${item.id}`);
          
          // Remove from offline storage based on type
          if (item.type === 'survey_response') {
            await this.removeOfflineResponse(item.id);
          } else if (item.type === 'location_update') {
            await this.removeOfflineLocation(item.id);
          } else if (item.type === 'delivery_record') {
            await this.removeOfflineDelivery(item.id);
          } else if (item.type === 'tracking_session') {
            await this.removeOfflineTrackingSession(item.id);
          }
        } catch (error) {
          console.error(`❌ Failed to sync item ${item.id}:`, error);
          
          // Increment retry count
          item.retryCount++;
          
          // Keep in queue if under max retries
          if (item.retryCount < item.maxRetries) {
            updatedQueue.push(item);
          } else {
            console.error(`🚫 Max retries exceeded for item: ${item.id}`);
          }
          
          failedCount++;
        }
      }

      // Update sync queue with failed items
      await this.updateSyncQueue(updatedQueue);
      
      // Update last sync timestamp
      await AsyncStorage.setItem(STORAGE_KEYS.LAST_SYNC, Date.now().toString());
      
      console.log(`🎉 Sync completed: ${successCount} success, ${failedCount} failed`);
      
    } catch (error) {
      console.error('❌ Sync operation failed:', error);
    } finally {
      this.syncInProgress = false;
    }

    return { success: successCount, failed: failedCount };
  }

  private async syncQueueItem(item: SyncQueueItem): Promise<void> {
    switch (item.type) {
      case 'survey_response':
        await SurveyService.submitResponse(item.data);
        break;
      case 'survey_update':
        await SurveyService.updateSurvey(item.data.id, item.data.updates);
        break;
      case 'assignment_update':
        // Handle assignment updates if needed
        break;
      case 'location_update':
        await this.syncLocationData(item.data);
        break;
      case 'delivery_record':
        await this.syncDeliveryData(item.data);
        break;
      case 'tracking_session':
        await this.syncTrackingSession(item.data);
        break;
      case 'ministry_session':
        await this.syncMinistrySession(item.data);
        break;
      case 'path_point':
        await this.syncPathPoint(item.data);
        break;
      default:
        throw new Error(`Unknown sync item type: ${item.type}`);
    }
  }

  // Offline Survey Data Management
  async cacheSurvey(survey: Survey): Promise<void> {
    try {
      const cachedSurveys = await this.getCachedSurveys();
      const existingIndex = cachedSurveys.findIndex(s => s.id === survey.id);
      
      if (existingIndex >= 0) {
        cachedSurveys[existingIndex] = survey;
      } else {
        cachedSurveys.push(survey);
      }
      
      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_SURVEYS, 
        JSON.stringify(cachedSurveys)
      );
    } catch (error) {
      console.error('❌ Error caching survey:', error);
    }
  }

  async getCachedSurveys(): Promise<Survey[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.OFFLINE_SURVEYS);
      if (!stored) return [];

      const surveys = JSON.parse(stored);
      return surveys.map((survey: any) => ({
        ...survey,
        createdAt: new Date(survey.createdAt),
        updatedAt: new Date(survey.updatedAt)
      }));
    } catch (error) {
      console.error('❌ Error getting cached surveys:', error);
      return [];
    }
  }

  async cacheAssignments(assignments: SurveyAssignment[]): Promise<void> {
    try {
      await AsyncStorage.setItem(
        STORAGE_KEYS.OFFLINE_ASSIGNMENTS, 
        JSON.stringify(assignments)
      );
    } catch (error) {
      console.error('❌ Error caching assignments:', error);
    }
  }

  async getCachedAssignments(): Promise<SurveyAssignment[]> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.OFFLINE_ASSIGNMENTS);
      if (!stored) return [];

      const assignments = JSON.parse(stored);
      return assignments.map((assignment: any) => ({
        ...assignment,
        assignedAt: new Date(assignment.assignedAt),
        dueDate: assignment.dueDate ? new Date(assignment.dueDate) : undefined
      }));
    } catch (error) {
      console.error('❌ Error getting cached assignments:', error);
      return [];
    }
  }

  // Utility Methods
  async getLastSyncTime(): Promise<Date | null> {
    try {
      const timestamp = await AsyncStorage.getItem(STORAGE_KEYS.LAST_SYNC);
      return timestamp ? new Date(parseInt(timestamp)) : null;
    } catch (error) {
      console.error('❌ Error getting last sync time:', error);
      return null;
    }
  }

  async getPendingSyncCount(): Promise<number> {
    try {
      const [
        queue,
        offlineResponses,
        offlineLocations,
        offlineDeliveries,
        offlineTrackingSessions
      ] = await Promise.all([
        this.getSyncQueue(),
        this.getOfflineResponses(),
        this.getOfflineLocations(),
        this.getOfflineDeliveries(),
        this.getOfflineTrackingSessions()
      ]);

      const pendingLocations = offlineLocations.filter(l => l.syncStatus === 'pending').length;
      const pendingDeliveries = offlineDeliveries.filter(d => d.syncStatus === 'pending').length;
      const pendingSessions = offlineTrackingSessions.filter(s => s.syncStatus === 'pending').length;

      return queue.length + offlineResponses.length + pendingLocations + pendingDeliveries + pendingSessions;
    } catch (error) {
      console.error('❌ Error getting pending sync count:', error);
      return 0;
    }
  }

  // Sync methods for new data types
  private async syncLocationData(locationData: OfflineLocationData): Promise<void> {
    try {
      // Import RealtimeLocationService dynamically to avoid circular dependency
      const { realtimeLocationService } = await import('./RealtimeLocationService');

      // Convert to the format expected by RealtimeLocationService
      const workerLocation = {
        latitude: locationData.latitude,
        longitude: locationData.longitude,
        timestamp: locationData.timestamp,
        accuracy: locationData.accuracy,
        speed: locationData.speed,
        heading: locationData.heading,
      };

      // Update worker location in Firebase
      await realtimeLocationService.updateWorkerLocation(
        locationData.userId,
        locationData.userName,
        workerLocation,
        true
      );

      console.log('✅ Location data synced:', locationData.id);
    } catch (error) {
      console.error('❌ Error syncing location data:', error);
      throw error;
    }
  }

  private async syncDeliveryData(deliveryData: OfflineDeliveryData): Promise<void> {
    try {
      // Import DeliveryService dynamically to avoid circular dependency
      const { DeliveryService } = await import('./DeliveryService');

      // Convert to the format expected by DeliveryService
      const deliveryRecord = {
        workerId: deliveryData.workerId,
        workerName: deliveryData.workerName,
        bookTitle: deliveryData.bookTitle,
        deliveryType: deliveryData.deliveryType,
        location: deliveryData.location,
        deliveryTime: new Date(deliveryData.timestamp),
        status: deliveryData.status,
        notes: deliveryData.notes,
        sessionId: deliveryData.sessionId,
      };

      // Create delivery record in Firebase
      await DeliveryService.createDelivery(deliveryRecord);

      console.log('✅ Delivery data synced:', deliveryData.id);
    } catch (error) {
      console.error('❌ Error syncing delivery data:', error);
      throw error;
    }
  }

  private async syncTrackingSession(sessionData: OfflineTrackingSession): Promise<void> {
    try {
      // Import DeliveryService dynamically to avoid circular dependency
      const { DeliveryService } = await import('./DeliveryService');

      // Convert to the format expected by DeliveryService
      const sessionRecord = {
        userId: sessionData.userId,
        userName: sessionData.userName,
        startTime: new Date(sessionData.startTime),
        endTime: sessionData.endTime ? new Date(sessionData.endTime) : undefined,
        totalDistance: sessionData.totalDistance,
        locationCount: sessionData.locationCount,
        deliveryCount: sessionData.deliveryCount,
        isActive: sessionData.isActive,
      };

      // Create session record in Firebase
      await DeliveryService.createSession(sessionRecord);

      console.log('✅ Tracking session synced:', sessionData.id);
    } catch (error) {
      console.error('❌ Error syncing tracking session:', error);
      throw error;
    }
  }

  async clearOfflineData(): Promise<void> {
    try {
      await AsyncStorage.multiRemove([
        STORAGE_KEYS.OFFLINE_RESPONSES,
        STORAGE_KEYS.OFFLINE_SURVEYS,
        STORAGE_KEYS.OFFLINE_ASSIGNMENTS,
        STORAGE_KEYS.OFFLINE_LOCATIONS,
        STORAGE_KEYS.OFFLINE_DELIVERIES,
        STORAGE_KEYS.OFFLINE_TRACKING_SESSIONS,
        STORAGE_KEYS.SYNC_QUEUE
      ]);
      console.log('🧹 Offline data cleared');
    } catch (error) {
      console.error('❌ Error clearing offline data:', error);
    }
  }

  private async syncMinistrySession(sessionData: OfflineMinistrySession): Promise<void> {
    try {
      // Import MinistrySessionService dynamically to avoid circular dependency
      const MinistrySessionServiceModule = await import('./MinistrySessionService');
      const MinistrySessionService = MinistrySessionServiceModule.default;
      
      // Get the service instance
      const ministryService = MinistrySessionService.getInstance();
      
      if (!ministryService) {
        throw new Error('MinistrySessionService instance is undefined');
      }

      // Convert offline session to MinistrySession format
      const ministrySession: MinistrySession = {
        id: sessionData.id,
        userId: sessionData.userId,
        userName: sessionData.userName,
        userRole: sessionData.userRole,
        teamId: sessionData.teamId,
        territoryId: sessionData.territoryId,
        sessionName: sessionData.sessionName,
        startTime: sessionData.startTime,
        endTime: sessionData.endTime,
        totalDistance: sessionData.totalDistance,
        pathPoints: sessionData.pathPoints,
        isActive: sessionData.isActive,
        createdAt: sessionData.createdAt,
        updatedAt: sessionData.updatedAt,
        syncStatus: 'synced'
      };

      // Save to Firebase using the service instance
      if (sessionData.isActive) {
        await ministryService.updateSession(sessionData.id, {
          totalDistance: sessionData.totalDistance,
          pathPoints: sessionData.pathPoints,
          updatedAt: Date.now(),
          syncStatus: 'synced'
        });
      } else {
        // For inactive sessions, we need to create them if they don't exist
        // First check if session exists
        const existingSession = await ministryService.getSession(sessionData.id);
        if (!existingSession) {
          // Create new session by calling startSession with the stored data
          await ministryService.startSession(
            sessionData.userId,
            sessionData.userName,
            sessionData.userRole,
            sessionData.territoryId,
            undefined, // territoryName not available in OfflineMinistrySession
            sessionData.teamId,
            undefined, // teamName not available in OfflineMinistrySession
            sessionData.sessionName
          );
        }
        
        // Then update it with the final data
        await ministryService.updateSession(sessionData.id, {
          endTime: sessionData.endTime,
          totalDistance: sessionData.totalDistance,
          pathPoints: sessionData.pathPoints,
          isActive: false,
          updatedAt: Date.now(),
          syncStatus: 'synced'
        });
      }

      console.log('✅ Synced ministry session:', sessionData.id);
    } catch (error) {
      console.error('❌ Error syncing ministry session:', error);
      throw error;
    }
  }

  private async syncPathPoint(pathPointData: OfflinePathPoint): Promise<void> {
    try {
      // Import MinistrySessionService dynamically to avoid circular dependency
      const MinistrySessionServiceModule = await import('./MinistrySessionService');
      const MinistrySessionService = MinistrySessionServiceModule.default;
      
      // Get the service instance
      const ministryService = MinistrySessionService.getInstance();

      // Add path point to existing session
      const pathPoint: PathPoint = {
        latitude: pathPointData.latitude,
        longitude: pathPointData.longitude,
        timestamp: pathPointData.timestamp,
        accuracy: pathPointData.accuracy
      };

      await ministryService.addPathPoint(pathPointData.sessionId, pathPoint);

      console.log('✅ Synced path point for session:', pathPointData.sessionId);
    } catch (error) {
      console.error('❌ Error syncing path point:', error);
      throw error;
    }
  }

  isSyncInProgress(): boolean {
    return this.syncInProgress;
  }
}

export default OfflineManager;
