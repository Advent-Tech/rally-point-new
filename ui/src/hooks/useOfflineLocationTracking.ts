import { useState, useEffect, useCallback } from 'react';
import { Platform } from 'react-native';
import * as Location from 'expo-location';
import { realtimeLocationService } from '../services/RealtimeLocationService';
import OfflineManager, { OfflineLocationData, OfflineTrackingSession } from '../services/OfflineManager';
import { useNetworkStatus } from './useOfflineManager';

export interface LocationTrackingState {
  isTracking: boolean;
  currentLocation: OfflineLocationData | null;
  sessionId: string | null;
  locationCount: number;
  totalDistance: number;
  offlineLocations: OfflineLocationData[];
  pendingSyncCount: number;
  trackingSession: OfflineTrackingSession | null;
}

export interface LocationTrackingActions {
  startTracking: (userId: string, userName: string) => Promise<void>;
  stopTracking: () => Promise<void>;
  syncOfflineData: () => Promise<{ success: number; failed: number }>;
  getOfflineLocationsBySession: (sessionId: string) => Promise<OfflineLocationData[]>;
  clearOfflineData: () => Promise<void>;
}

export const useOfflineLocationTracking = (): [LocationTrackingState, LocationTrackingActions] => {
  const [state, setState] = useState<LocationTrackingState>({
    isTracking: false,
    currentLocation: null,
    sessionId: null,
    locationCount: 0,
    totalDistance: 0,
    offlineLocations: [],
    pendingSyncCount: 0,
    trackingSession: null,
  });

  const networkStatus = useNetworkStatus();
  const offlineManager = OfflineManager.getInstance();

  // Load initial data
  const loadOfflineData = useCallback(async () => {
    try {
      const [offlineLocations, trackingSessions] = await Promise.all([
        offlineManager.getOfflineLocations(),
        offlineManager.getOfflineTrackingSessions()
      ]);

      const pendingLocations = offlineLocations.filter(l => l.syncStatus === 'pending');
      const activeSession = trackingSessions.find(s => s.isActive);

      setState(prev => ({
        ...prev,
        offlineLocations,
        pendingSyncCount: pendingLocations.length,
        trackingSession: activeSession || null,
        sessionId: activeSession?.id || null,
        isTracking: !!activeSession?.isActive,
        locationCount: activeSession?.locationCount || 0,
        totalDistance: activeSession?.totalDistance || 0,
      }));
    } catch (error) {
      console.error('Error loading offline location data:', error);
    }
  }, [offlineManager]);

  // Load data on mount and when network status changes
  useEffect(() => {
    loadOfflineData();
  }, [loadOfflineData, networkStatus.isConnected]);

  // Periodic data refresh
  useEffect(() => {
    const interval = setInterval(loadOfflineData, 5000);
    return () => clearInterval(interval);
  }, [loadOfflineData]);

  // Start location tracking
  const startTracking = useCallback(async (userId: string, userName: string) => {
    try {
      console.log('🚀 Starting offline location tracking for:', userName);

      // Request location permissions
      let hasPermission = false;
      
      if (Platform.OS === 'web') {
        // Web platform
        if (navigator.geolocation) {
          hasPermission = true;
        }
      } else {
        // Mobile platform
        const { status } = await Location.requestForegroundPermissionsAsync();
        hasPermission = status === 'granted';
      }

      if (!hasPermission) {
        throw new Error('Location permission not granted');
      }

      // Start tracking session
      const sessionId = await realtimeLocationService.startTrackingSession(userId, userName);
      
      // Start location updates
      await realtimeLocationService.startLocationTracking(userId, userName);

      setState(prev => ({
        ...prev,
        isTracking: true,
        sessionId,
        locationCount: 0,
        totalDistance: 0,
      }));

      console.log('✅ Location tracking started with session:', sessionId);
    } catch (error) {
      console.error('❌ Error starting location tracking:', error);
      throw error;
    }
  }, []);

  // Stop location tracking
  const stopTracking = useCallback(async () => {
    try {
      console.log('🛑 Stopping location tracking');

      // Stop location updates
      await realtimeLocationService.stopLocationTracking();
      
      // End tracking session
      await realtimeLocationService.endTrackingSession();

      setState(prev => ({
        ...prev,
        isTracking: false,
        sessionId: null,
        currentLocation: null,
      }));

      // Refresh data to get final session stats
      await loadOfflineData();

      console.log('✅ Location tracking stopped');
    } catch (error) {
      console.error('❌ Error stopping location tracking:', error);
      throw error;
    }
  }, [loadOfflineData]);

  // Sync offline data
  const syncOfflineData = useCallback(async () => {
    try {
      console.log('🔄 Syncing offline location data');
      
      const result = await offlineManager.syncOfflineData();
      
      // Refresh data after sync
      await loadOfflineData();
      
      console.log('✅ Offline location data synced:', result);
      return result;
    } catch (error) {
      console.error('❌ Error syncing offline location data:', error);
      return { success: 0, failed: 0 };
    }
  }, [offlineManager, loadOfflineData]);

  // Get offline locations by session
  const getOfflineLocationsBySession = useCallback(async (sessionId: string) => {
    try {
      return await offlineManager.getOfflineLocationsBySession(sessionId);
    } catch (error) {
      console.error('❌ Error getting offline locations by session:', error);
      return [];
    }
  }, [offlineManager]);

  // Clear offline data
  const clearOfflineData = useCallback(async () => {
    try {
      console.log('🧹 Clearing offline location data');
      
      // Clear all offline data
      await offlineManager.clearOfflineData();
      
      // Refresh state
      await loadOfflineData();
      
      console.log('✅ Offline location data cleared');
    } catch (error) {
      console.error('❌ Error clearing offline location data:', error);
      throw error;
    }
  }, [offlineManager, loadOfflineData]);

  const actions: LocationTrackingActions = {
    startTracking,
    stopTracking,
    syncOfflineData,
    getOfflineLocationsBySession,
    clearOfflineData,
  };

  return [state, actions];
};

// Hook for getting offline location statistics
export const useOfflineLocationStats = (userId?: string) => {
  const [stats, setStats] = useState({
    totalLocations: 0,
    pendingSync: 0,
    activeSessions: 0,
    totalDistance: 0,
    lastUpdate: null as Date | null,
  });

  const offlineManager = OfflineManager.getInstance();

  useEffect(() => {
    const loadStats = async () => {
      try {
        const [locations, sessions] = await Promise.all([
          offlineManager.getOfflineLocations(),
          offlineManager.getOfflineTrackingSessions()
        ]);

        const userLocations = userId ? locations.filter(l => l.userId === userId) : locations;
        const userSessions = userId ? sessions.filter(s => s.userId === userId) : sessions;
        
        const pendingLocations = userLocations.filter(l => l.syncStatus === 'pending');
        const activeSessions = userSessions.filter(s => s.isActive);
        const totalDistance = userSessions.reduce((sum, s) => sum + s.totalDistance, 0);
        
        const lastLocation = userLocations
          .sort((a, b) => b.timestamp - a.timestamp)[0];

        setStats({
          totalLocations: userLocations.length,
          pendingSync: pendingLocations.length,
          activeSessions: activeSessions.length,
          totalDistance,
          lastUpdate: lastLocation ? new Date(lastLocation.timestamp) : null,
        });
      } catch (error) {
        console.error('Error loading offline location stats:', error);
      }
    };

    loadStats();
    const interval = setInterval(loadStats, 10000); // Update every 10 seconds
    
    return () => clearInterval(interval);
  }, [userId, offlineManager]);

  return stats;
};

export default useOfflineLocationTracking;
