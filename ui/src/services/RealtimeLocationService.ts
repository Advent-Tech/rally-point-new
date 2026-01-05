import { Platform } from 'react-native';
import * as Location from 'expo-location';
import OfflineManager from './OfflineManager';
import ErrorHandlingService from './ErrorHandlingService';
import { authService } from './authService';

export interface WorkerLocation {
  latitude: number;
  longitude: number;
  timestamp: number;
  accuracy?: number;
  speed?: number;
  heading?: number;
}

export interface WorkerData {
  id: string;
  name: string;
  email: string;
  isActive: boolean;
  currentLocation?: WorkerLocation;
  lastSeen?: number;
}

class RealtimeLocationService {
  private locationWatchId: number | null = null;
  private updateInterval: NodeJS.Timeout | null = null;
  private currentUserId: string | null = null;
  private offlineManager: OfflineManager;
  private currentSessionId: string | null = null;
  private errorHandler: ErrorHandlingService;
  private pollingInterval: NodeJS.Timeout | null = null;
  private workersCallback: ((workers: WorkerData[]) => void) | null = null;

  constructor() {
    this.offlineManager = OfflineManager.getInstance();
    this.errorHandler = ErrorHandlingService.getInstance();
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
   * Start real-time location tracking for a worker
   * Updates location to backend API
   */
  startLocationTracking(userId: string, userName: string): Promise<void> {
    return new Promise(async (resolve, reject) => {
      console.log('Starting real-time location tracking for:', userName);
      console.log('Platform:', Platform.OS);
      console.log('User ID:', userId);

      this.currentUserId = userId;

      try {
        if (Platform.OS !== 'web' && Location) {
          await this.startMobileLocationTracking(userId, userName, resolve, reject);
        } else if (typeof navigator !== 'undefined' && navigator.geolocation) {
          this.startWebLocationTracking(userId, userName, resolve, reject);
        } else {
          const errorInfo = this.errorHandler.logError(
            'LOCATION_UNAVAILABLE',
            new Error('Location services not available'),
            'startLocationTracking'
          );
          reject(new Error(errorInfo.message));
        }
      } catch (error: any) {
        console.error('Location tracking failed:', error.message);
        reject(error);
      }
    });
  }

  /**
   * Start location tracking for web using navigator.geolocation
   */
  private async startWebLocationTracking(
    userId: string,
    userName: string,
    resolve: () => void,
    reject: (error: Error) => void
  ) {
    console.log('Starting web location tracking...');

    if (!navigator.geolocation) {
      reject(new Error('Geolocation is not supported on this browser.'));
      return;
    }

    try {
      const permission = await navigator.permissions.query({ name: 'geolocation' });
      if (permission.state === 'denied') {
        const errorInfo = this.errorHandler.logError(
          'LOCATION_PERMISSION_DENIED',
          new Error('Geolocation permission denied'),
          'startWebLocationTracking'
        );
        reject(new Error(errorInfo.message));
        return;
      }
    } catch (permError) {
      console.warn('Could not check geolocation permissions:', permError);
    }

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const location: WorkerLocation = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          timestamp: Date.now(),
          accuracy: position.coords.accuracy || 0,
          speed: position.coords.speed || 0,
          heading: position.coords.heading || 0,
        };

        await this.updateWorkerLocation(userId, userName, location, true);
        console.log('Web initial location saved:', location);

        this.startContinuousWebTracking(userId, userName);
        resolve();
      },
      (error) => {
        console.error('Error getting web initial location:', error);
        let errorMessage = 'Unable to get location. ';
        switch (error.code) {
          case 1:
            errorMessage += 'Location access denied.';
            break;
          case 2:
            errorMessage += 'Location unavailable.';
            break;
          case 3:
            errorMessage += 'Location request timed out.';
            break;
          default:
            errorMessage += 'Please enable location services.';
        }
        reject(new Error(errorMessage));
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 2000 }
    );
  }

  /**
   * Start location tracking for mobile using Expo Location
   */
  private async startMobileLocationTracking(
    userId: string,
    userName: string,
    resolve: () => void,
    _reject: (error: Error) => void
  ): Promise<void> {
    console.log('Starting mobile location tracking...');

    if (!Location) {
      throw new Error('Expo Location not available');
    }

    let { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== 'granted') {
      throw new Error('Location permission denied');
    }

    console.log('Mobile location permission granted');

    const location = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.High,
      timeInterval: 1000,
      distanceInterval: 1,
    });

    const workerLocation: WorkerLocation = {
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      timestamp: Date.now(),
      accuracy: location.coords.accuracy || 0,
      speed: location.coords.speed || 0,
      heading: location.coords.heading || 0,
    };

    await this.updateWorkerLocation(userId, userName, workerLocation, true);
    console.log('Mobile initial location saved:', workerLocation);

    this.startContinuousMobileTracking(userId, userName);
    resolve();
  }

  /**
   * Start continuous web location tracking
   */
  private startContinuousWebTracking(userId: string, userName: string) {
    console.log('🚀 Starting continuous web location tracking for:', userName);

    this.updateInterval = setInterval(async () => {
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          const location: WorkerLocation = {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            timestamp: Date.now(),
            accuracy: position.coords.accuracy || 0,
            speed: position.coords.speed || 0,
            heading: position.coords.heading || 0,
          };

          console.log('📡 Real-time GPS update:', {
            worker: userName,
            latitude: position.coords.latitude.toFixed(6),
            longitude: position.coords.longitude.toFixed(6),
            accuracy: Math.round(position.coords.accuracy || 0) + 'm',
            timestamp: new Date().toLocaleTimeString()
          });

          await this.updateWorkerLocation(userId, userName, location, true);
        },
        (error) => {
          if (error.code !== 3) {
            console.warn('⚠️ Web location update error:', error.message);
          }
        },
        { enableHighAccuracy: true, timeout: 5000, maximumAge: 0 }
      );
    }, 3000); // Update every 3 seconds

    console.log('✅ Continuous web tracking started for:', userName);
  }

  /**
   * Start continuous mobile location tracking using Expo Location
   */
  private startContinuousMobileTracking(userId: string, userName: string) {
    console.log('Starting continuous mobile location tracking...');

    Location.watchPositionAsync(
      {
        accuracy: Location.Accuracy.BestForNavigation,
        timeInterval: 3000,
        distanceInterval: 5,
      },
      async (location) => {
        const GPS_ACCURACY_THRESHOLD = 15;
        if (location.coords.accuracy && location.coords.accuracy > GPS_ACCURACY_THRESHOLD) {
          return;
        }

        const workerLocation: WorkerLocation = {
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          timestamp: Date.now(),
          accuracy: location.coords.accuracy || 0,
          speed: location.coords.speed || 0,
          heading: location.coords.heading || 0,
        };

        await this.updateWorkerLocation(userId, userName, workerLocation, true);
        console.log('📍 High-quality GPS update:', userName, `accuracy: ${workerLocation.accuracy?.toFixed(1)}m`);
      }
    ).then((subscription) => {
      (this as any).mobileLocationSubscription = subscription;
    }).catch((error) => {
      console.error('Error starting mobile location watch:', error);
    });

    console.log('✅ Continuous mobile tracking started for:', userName);
  }

  /**
   * Stop location tracking
   */
  stopLocationTracking() {
    console.log('🛑 Stopping location tracking...');

    if (Platform.OS === 'web') {
      if (this.locationWatchId !== null) {
        navigator.geolocation.clearWatch(this.locationWatchId);
        this.locationWatchId = null;
      }
    } else {
      if ((this as any).mobileLocationSubscription) {
        (this as any).mobileLocationSubscription.remove();
        (this as any).mobileLocationSubscription = null;
      }
    }

    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }

    if (this.currentUserId) {
      this.markWorkerInactive(this.currentUserId);
      this.currentUserId = null;
    }

    console.log('✅ Location tracking stopped');
  }

  /**
   * Update worker location to backend API
   */
  private async updateWorkerLocation(
    userId: string,
    userName: string,
    location: WorkerLocation,
    isActive: boolean = true
  ) {
    try {
      console.log('🔄 Real-time location update:', {
        worker: userName,
        coordinates: `${location.latitude.toFixed(6)}, ${location.longitude.toFixed(6)}`,
        accuracy: Math.round(location.accuracy || 0) + 'm',
        active: isActive
      });

      const token = await authService.getValidToken();
      if (!token) {
        console.warn('⚠️ No auth token available');
        await this.storeLocationOffline(userId, userName, location);
        return;
      }

      const apiBase = this.getApiBase();
      const response = await fetch(`${apiBase}/api/location/update`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy ?? undefined,
          speed: location.speed ?? undefined,
          heading: location.heading ?? undefined,
        }),
      });

      if (!response.ok) {
        console.error('❌ Location update error:', response.status);
        await this.storeLocationOffline(userId, userName, location);
      } else {
        console.log('✅ Location updated to backend for:', userName);
      }
    } catch (error: any) {
      console.warn('⚠️ Backend location update failed, storing offline:', error.message);
      await this.storeLocationOffline(userId, userName, location);
    }
  }

  private async storeLocationOffline(userId: string, userName: string, location: WorkerLocation) {
    const offlineLocationData = {
      id: `location_${userId}_${Date.now()}`,
      userId,
      userName,
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: location.timestamp,
      accuracy: location.accuracy,
      speed: location.speed,
      heading: location.heading,
      sessionId: this.currentSessionId,
      syncStatus: 'pending' as const
    };

    await this.offlineManager.storeOfflineLocation(offlineLocationData);
    console.log('✅ Location stored offline');
  }

  /**
   * Start a new tracking session
   */
  async startTrackingSession(userId: string, userName: string): Promise<string> {
    const sessionId = `session_${userId}_${Date.now()}`;
    this.currentSessionId = sessionId;

    const sessionData = {
      id: sessionId,
      userId,
      userName,
      startTime: Date.now(),
      totalDistance: 0,
      locationCount: 0,
      deliveryCount: 0,
      isActive: true,
      syncStatus: 'pending' as const
    };

    await this.offlineManager.storeOfflineTrackingSession(sessionData);
    console.log('✅ Tracking session started:', sessionId);

    return sessionId;
  }

  /**
   * End the current tracking session
   */
  async endTrackingSession(): Promise<void> {
    if (!this.currentSessionId) {
      return;
    }

    const sessions = await this.offlineManager.getOfflineTrackingSessions();
    const currentSession = sessions.find(s => s.id === this.currentSessionId);

    if (currentSession) {
      const updatedSession = {
        ...currentSession,
        endTime: Date.now(),
        isActive: false,
        syncStatus: 'pending' as const
      };

      await this.offlineManager.storeOfflineTrackingSession(updatedSession);
      console.log('✅ Tracking session ended:', this.currentSessionId);
    }

    this.currentSessionId = null;
  }

  /**
   * Mark worker as inactive
   */
  private async markWorkerInactive(userId: string) {
    try {
      const token = await authService.getValidToken();
      if (!token) return;

      const apiBase = this.getApiBase();
      await fetch(`${apiBase}/api/location/status`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ isActive: false }),
      });
      console.log('✅ Worker marked as inactive:', userId);
    } catch (error) {
      console.error('❌ Error marking worker inactive:', error);
    }
  }

  /**
   * Listen to all workers by polling the backend API
   */
  listenToAllWorkers(callback: (workers: WorkerData[]) => void): () => void {
    console.log('🔄 Setting up worker location polling...');
    this.workersCallback = callback;

    const pollWorkers = async () => {
      try {
        const token = await authService.getValidToken();
        if (!token) {
          callback([]);
          return;
        }

        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/location/workers`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });

        if (response.ok) {
          const data = await response.json();
          const workers: WorkerData[] = (data.workers || []).map((w: any) => ({
            id: w.id || w.user_id,
            name: w.name || w.display_name || 'Unknown',
            email: w.email || '',
            isActive: w.is_active || w.isActive || false,
            currentLocation: w.current_location || w.currentLocation ? {
              latitude: w.current_location?.latitude || w.currentLocation?.latitude || 0,
              longitude: w.current_location?.longitude || w.currentLocation?.longitude || 0,
              timestamp: w.current_location?.timestamp || w.currentLocation?.timestamp || Date.now(),
              accuracy: w.current_location?.accuracy || w.currentLocation?.accuracy || 0,
              speed: w.current_location?.speed || w.currentLocation?.speed || 0,
              heading: w.current_location?.heading || w.currentLocation?.heading || 0,
            } : undefined,
            lastSeen: w.last_seen || w.lastSeen,
          }));

          callback(workers);
        } else {
          console.error('❌ Failed to fetch workers:', response.status);
          callback([]);
        }
      } catch (error) {
        console.error('❌ Error polling workers:', error);
        callback([]);
      }
    };

    // Initial fetch
    pollWorkers();

    // Poll every 3 seconds
    this.pollingInterval = setInterval(pollWorkers, 3000);

    return () => {
      console.log('🔌 Stopping worker polling');
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval);
        this.pollingInterval = null;
      }
      this.workersCallback = null;
    };
  }

  /**
   * Listen to specific worker
   */
  listenToWorker(userId: string, callback: (worker: WorkerData | null) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const pollWorker = async () => {
      try {
        const token = await authService.getValidToken();
        if (!token) {
          callback(null);
          return;
        }

        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/location/workers/${userId}`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });

        if (response.ok) {
          const data = await response.json();
          const worker: WorkerData = {
            id: data.id || data.user_id,
            name: data.name || data.display_name || 'Unknown',
            email: data.email || '',
            isActive: data.is_active || data.isActive || false,
            currentLocation: data.current_location || data.currentLocation ? {
              latitude: data.current_location?.latitude || data.currentLocation?.latitude || 0,
              longitude: data.current_location?.longitude || data.currentLocation?.longitude || 0,
              timestamp: data.current_location?.timestamp || data.currentLocation?.timestamp || Date.now(),
              accuracy: data.current_location?.accuracy || data.currentLocation?.accuracy || 0,
              speed: data.current_location?.speed || data.currentLocation?.speed || 0,
              heading: data.current_location?.heading || data.currentLocation?.heading || 0,
            } : undefined,
            lastSeen: data.last_seen || data.lastSeen,
          };
          callback(worker);
        } else {
          callback(null);
        }
      } catch (error) {
        console.error('❌ Error polling worker:', error);
        callback(null);
      }
    };

    pollWorker();
    intervalId = setInterval(pollWorker, 3000);

    return () => {
      if (intervalId) {
        clearInterval(intervalId);
      }
    };
  }
}

export const realtimeLocationService = new RealtimeLocationService();

if (typeof window !== 'undefined') {
  (window as any).realtimeLocationService = realtimeLocationService;
}
