import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform, Alert } from 'react-native';
import * as Location from 'expo-location';

export interface LocationPoint {
  latitude: number;
  longitude: number;
  altitude: number | null;
  accuracy: number;
  timestamp: number;
  speed: number | null;
}

export interface TrackingSession {
  id: string;
  startTime: number;
  endTime: number | null;
  locations: LocationPoint[];
  totalDistance: number;
  duration: number;
  isActive: boolean;
  purpose: 'field_work' | 'delivery' | 'survey' | 'general';
}

export interface GeotrackingStats {
  todayDistance: number;
  todayDuration: number;
  weeklyDistance: number;
  weeklySessions: number;
  totalSessions: number;
  averageSpeed: number;
}

class GeotrackingService {
  private static instance: GeotrackingService;
  private currentSession: TrackingSession | null = null;
  private locationSubscription: Location.LocationSubscription | null = null;
  private isTracking = false;
  private locationUpdateCallback: ((location: LocationPoint) => void) | null = null;

  private readonly STORAGE_KEYS = {
    SESSIONS: 'geotracking_sessions',
    CURRENT_SESSION: 'geotracking_current_session',
    STATS: 'geotracking_stats',
  };

  static getInstance(): GeotrackingService {
    if (!GeotrackingService.instance) {
      GeotrackingService.instance = new GeotrackingService();
    }
    return GeotrackingService.instance;
  }

  // Initialize location permissions
  async initializePermissions(): Promise<boolean> {
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      
      if (status !== 'granted') {
        Alert.alert(
          'Location Permission Required',
          'This app needs location permission to track your field work. Please enable location access in settings.',
          [{ text: 'OK' }]
        );
        return false;
      }

      // Request background location for Android
      if (Platform.OS === 'android') {
        const { status: bgStatus } = await Location.requestBackgroundPermissionsAsync();
        if (bgStatus !== 'granted') {
          console.warn('Background location permission not granted');
        }
      }

      return true;
    } catch (error) {
      console.error('Error requesting location permissions:', error);
      return false;
    }
  }

  // Start tracking a new session
  async startTracking(purpose: TrackingSession['purpose'] = 'field_work'): Promise<string> {
    try {
      if (this.isTracking) {
        throw new Error('Tracking already active');
      }

      const hasPermission = await this.initializePermissions();
      if (!hasPermission) {
        throw new Error('Location permission denied');
      }

      // Get current location
      const currentLocation = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.BestForNavigation,
      });

      // Create new session
      const sessionId = `session_${Date.now()}`;
      const startLocation: LocationPoint = {
        latitude: currentLocation.coords.latitude,
        longitude: currentLocation.coords.longitude,
        altitude: currentLocation.coords.altitude,
        accuracy: currentLocation.coords.accuracy,
        timestamp: Date.now(),
        speed: currentLocation.coords.speed,
      };

      this.currentSession = {
        id: sessionId,
        startTime: Date.now(),
        endTime: null,
        locations: [startLocation],
        totalDistance: 0,
        duration: 0,
        isActive: true,
        purpose,
      };

      // Start location updates
      this.locationSubscription = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.BestForNavigation,
          timeInterval: 1000, // Update every second
          distanceInterval: 2, // Minimum 2 meters between updates
        },
        (location) => this.handleLocationUpdate(location)
      );

      this.isTracking = true;
      await this.saveCurrentSession();

      console.log(`📍 Started tracking session: ${sessionId}`);
      return sessionId;
    } catch (error) {
      console.error('Error starting tracking:', error);
      throw error;
    }
  }

  // Stop current tracking session
  async stopTracking(): Promise<TrackingSession> {
    try {
      if (!this.isTracking || !this.currentSession) {
        throw new Error('No active tracking session');
      }

      // Stop location subscription
      if (this.locationSubscription) {
        this.locationSubscription.remove();
        this.locationSubscription = null;
      }

      // Final location update
      const finalLocation = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.BestForNavigation,
      });

      const finalLocationPoint: LocationPoint = {
        latitude: finalLocation.coords.latitude,
        longitude: finalLocation.coords.longitude,
        altitude: finalLocation.coords.altitude,
        accuracy: finalLocation.coords.accuracy,
        timestamp: Date.now(),
        speed: finalLocation.coords.speed,
      };

      this.currentSession.locations.push(finalLocationPoint);
      this.currentSession.endTime = Date.now();
      this.currentSession.isActive = false;
      this.currentSession.duration = this.currentSession.endTime - this.currentSession.startTime;

      // Calculate final distance
      this.currentSession.totalDistance = this.calculateTotalDistance(this.currentSession.locations);

      // Save completed session
      await this.saveSession(this.currentSession);
      await this.clearCurrentSession();
      await this.updateStats();

      const completedSession = this.currentSession;
      this.currentSession = null;
      this.isTracking = false;

      console.log(`📍 Stopped tracking session: ${completedSession.id}`);
      console.log(`📊 Distance: ${completedSession.totalDistance.toFixed(2)}m, Duration: ${(completedSession.duration / 1000 / 60).toFixed(1)}min`);

      return completedSession;
    } catch (error) {
      console.error('Error stopping tracking:', error);
      throw error;
    }
  }

  // Handle real-time location updates
  private handleLocationUpdate(location: Location.LocationObject) {
    if (!this.currentSession) return;

    const locationPoint: LocationPoint = {
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      altitude: location.coords.altitude,
      accuracy: location.coords.accuracy,
      timestamp: Date.now(),
      speed: location.coords.speed,
    };

    // Add location to current session
    this.currentSession.locations.push(locationPoint);
    
    // Update distance
    this.currentSession.totalDistance = this.calculateTotalDistance(this.currentSession.locations);
    this.currentSession.duration = Date.now() - this.currentSession.startTime;

    // Notify callback
    if (this.locationUpdateCallback) {
      this.locationUpdateCallback(locationPoint);
    }

    // Save current session periodically
    if (this.currentSession.locations.length % 10 === 0) {
      this.saveCurrentSession();
    }
  }

  // Calculate total distance from location points
  private calculateTotalDistance(locations: LocationPoint[]): number {
    if (locations.length < 2) return 0;

    let totalDistance = 0;
    for (let i = 1; i < locations.length; i++) {
      totalDistance += this.calculateDistance(
        locations[i - 1],
        locations[i]
      );
    }
    return totalDistance;
  }

  // Calculate distance between two points using Haversine formula
  private calculateDistance(point1: LocationPoint, point2: LocationPoint): number {
    const R = 6371000; // Earth's radius in meters
    const lat1Rad = (point1.latitude * Math.PI) / 180;
    const lat2Rad = (point2.latitude * Math.PI) / 180;
    const deltaLatRad = ((point2.latitude - point1.latitude) * Math.PI) / 180;
    const deltaLonRad = ((point2.longitude - point1.longitude) * Math.PI) / 180;

    const a =
      Math.sin(deltaLatRad / 2) * Math.sin(deltaLatRad / 2) +
      Math.cos(lat1Rad) * Math.cos(lat2Rad) *
      Math.sin(deltaLonRad / 2) * Math.sin(deltaLonRad / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  // Get current tracking status
  getCurrentSession(): TrackingSession | null {
    return this.currentSession;
  }

  // Check if currently tracking
  isCurrentlyTracking(): boolean {
    return this.isTracking;
  }

  // Set location update callback
  setLocationUpdateCallback(callback: (location: LocationPoint) => void) {
    this.locationUpdateCallback = callback;
  }

  // Get all saved sessions
  async getSessions(): Promise<TrackingSession[]> {
    try {
      const sessionsJson = await AsyncStorage.getItem(this.STORAGE_KEYS.SESSIONS);
      return sessionsJson ? JSON.parse(sessionsJson) : [];
    } catch (error) {
      console.error('Error getting sessions:', error);
      return [];
    }
  }

  // Get sessions for specific date range
  async getSessionsByDateRange(startDate: Date, endDate: Date): Promise<TrackingSession[]> {
    const allSessions = await this.getSessions();
    return allSessions.filter(session => {
      const sessionDate = new Date(session.startTime);
      return sessionDate >= startDate && sessionDate <= endDate;
    });
  }

  // Get today's sessions
  async getTodaySessions(): Promise<TrackingSession[]> {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    return this.getSessionsByDateRange(today, tomorrow);
  }

  // Get tracking statistics
  async getStats(): Promise<GeotrackingStats> {
    try {
      const statsJson = await AsyncStorage.getItem(this.STORAGE_KEYS.STATS);
      if (statsJson) {
        return JSON.parse(statsJson);
      }
    } catch (error) {
      console.error('Error getting stats:', error);
    }

    // Calculate stats if not cached
    return this.calculateStats();
  }

  // Calculate statistics from sessions
  private async calculateStats(): Promise<GeotrackingStats> {
    const sessions = await this.getSessions();
    const now = Date.now();
    const weekAgo = now - (7 * 24 * 60 * 60 * 1000);
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const todaySessions = sessions.filter(s => s.startTime >= todayStart.getTime());
    const weeklySessions = sessions.filter(s => s.startTime >= weekAgo);

    const stats: GeotrackingStats = {
      todayDistance: todaySessions.reduce((sum, s) => sum + s.totalDistance, 0),
      todayDuration: todaySessions.reduce((sum, s) => sum + s.duration, 0),
      weeklyDistance: weeklySessions.reduce((sum, s) => sum + s.totalDistance, 0),
      weeklySessions: weeklySessions.length,
      totalSessions: sessions.length,
      averageSpeed: this.calculateAverageSpeed(sessions),
    };

    await this.saveStats(stats);
    return stats;
  }

  // Calculate average speed from sessions
  private calculateAverageSpeed(sessions: TrackingSession[]): number {
    if (sessions.length === 0) return 0;

    const totalDistance = sessions.reduce((sum, s) => sum + s.totalDistance, 0);
    const totalDuration = sessions.reduce((sum, s) => sum + s.duration, 0);

    return totalDuration > 0 ? (totalDistance / totalDuration) * 1000 : 0; // m/s
  }

  // Save session to storage
  private async saveSession(session: TrackingSession): Promise<void> {
    try {
      const sessions = await this.getSessions();
      sessions.push(session);
      await AsyncStorage.setItem(this.STORAGE_KEYS.SESSIONS, JSON.stringify(sessions));
    } catch (error) {
      console.error('Error saving session:', error);
    }
  }

  // Save current session
  private async saveCurrentSession(): Promise<void> {
    try {
      if (this.currentSession) {
        await AsyncStorage.setItem(
          this.STORAGE_KEYS.CURRENT_SESSION,
          JSON.stringify(this.currentSession)
        );
      }
    } catch (error) {
      console.error('Error saving current session:', error);
    }
  }

  // Clear current session
  private async clearCurrentSession(): Promise<void> {
    try {
      await AsyncStorage.removeItem(this.STORAGE_KEYS.CURRENT_SESSION);
    } catch (error) {
      console.error('Error clearing current session:', error);
    }
  }

  // Save statistics
  private async saveStats(stats: GeotrackingStats): Promise<void> {
    try {
      await AsyncStorage.setItem(this.STORAGE_KEYS.STATS, JSON.stringify(stats));
    } catch (error) {
      console.error('Error saving stats:', error);
    }
  }

  // Update statistics
  private async updateStats(): Promise<void> {
    await this.calculateStats();
  }

  // Delete session
  async deleteSession(sessionId: string): Promise<void> {
    try {
      const sessions = await this.getSessions();
      const filteredSessions = sessions.filter(s => s.id !== sessionId);
      await AsyncStorage.setItem(this.STORAGE_KEYS.SESSIONS, JSON.stringify(filteredSessions));
      await this.updateStats();
    } catch (error) {
      console.error('Error deleting session:', error);
    }
  }

  // Clear all data
  async clearAllData(): Promise<void> {
    try {
      await AsyncStorage.multiRemove([
        this.STORAGE_KEYS.SESSIONS,
        this.STORAGE_KEYS.CURRENT_SESSION,
        this.STORAGE_KEYS.STATS,
      ]);
    } catch (error) {
      console.error('Error clearing all data:', error);
    }
  }

  // Resume tracking if session was active
  async resumeTracking(): Promise<boolean> {
    try {
      const sessionJson = await AsyncStorage.getItem(this.STORAGE_KEYS.CURRENT_SESSION);
      if (sessionJson) {
        const session: TrackingSession = JSON.parse(sessionJson);
        if (session.isActive) {
          // Don't automatically resume, let user decide
          console.log('Found active session, user can choose to resume');
          return true;
        }
      }
      return false;
    } catch (error) {
      console.error('Error checking resume tracking:', error);
      return false;
    }
  }
}

export default GeotrackingService.getInstance();
