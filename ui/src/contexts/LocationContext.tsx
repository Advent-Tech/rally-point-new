import React, { createContext, useContext, useState, useEffect, ReactNode, useCallback } from 'react';
import { Platform, Alert } from 'react-native';
import * as Location from 'expo-location';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useAuth } from './AuthContext';
import { realtimeLocationService } from '../services/RealtimeLocationService';
import { ministrySessionService, MinistrySession, PathPoint } from '../services/MinistrySessionService';
import OfflineManager from '../services/OfflineManager';
import WebOptimizations from '../utils/webOptimizations';
import { WorkerStatsService } from '../services/WorkerStatsService';

// Performance optimization constants - Improved for accurate distance tracking
const LOCATION_UPDATE_THROTTLE = 2000; // 2 seconds (reduced frequency)
const PATH_UPDATE_THROTTLE = 8000; // 8 seconds for path visualization (increased)
const MIN_DISTANCE_THRESHOLD = 5; // 5 meters minimum movement (increased from 1m)
const GPS_ACCURACY_THRESHOLD = 15; // 15 meters GPS accuracy threshold
const MAX_REASONABLE_SPEED_KMH = 50; // 50 km/h maximum reasonable speed

interface LocationData {
  latitude: number;
  longitude: number;
  timestamp: number;
  accuracy?: number;
  speed?: number;
  heading?: number;
}

interface TrackingSession {
  id: string;
  userId: string;
  userName: string;
  userRole: string;
  startTime: number;
  endTime?: number;
  totalDistance: number;
  pathPoints: LocationData[];
  isActive: boolean;
  sessionName?: string;
}

interface ActiveWorker {
  id: string;
  userId: string;
  userName: string;
  userRole: string;
  currentLocation: LocationData;
  isActive: boolean;
  lastUpdate: number;
}

interface LocationContextType {
  currentLocation: LocationData | null;
  isTracking: boolean;
  pathHistory: LocationData[];
  startTracking: (sessionName?: string) => Promise<void>;
  stopTracking: () => Promise<void>;
  clearHistory: () => void;
  locationPermission: boolean;
  requestPermission: () => Promise<boolean>;
  totalDistance: number;
  sessionStartTime: number | null;
  currentSession: TrackingSession | null;
  pastSessions: TrackingSession[];
  activeWorkers: ActiveWorker[];
  loadPastSessions: () => Promise<void>;
  loadActiveWorkers: () => Promise<void>;
  offlineLocationCount: number;
  pendingSyncCount: number;
  syncOfflineData: () => Promise<{ success: number; failed: number }>;
  // New ministry session functionality
  currentMinistrySession: MinistrySession | null;
  ministrySessionId: string | null;
  sessionDuration: number; // in minutes
  getSessionPath: () => PathPoint[];
  getSessionSummary: () => { distance: number; duration: number; points: number } | null;
}

const LocationContext = createContext<LocationContextType | undefined>(undefined);

export const useLocation = () => {
  const context = useContext(LocationContext);
  if (!context) {
    throw new Error('useLocation must be used within a LocationProvider');
  }
  return context;
};

interface LocationProviderProps {
  children: ReactNode;
}

export const LocationProvider: React.FC<LocationProviderProps> = ({ children }) => {
  const { user } = useAuth();
  const [currentLocation, setCurrentLocation] = useState<LocationData | null>(null);
  const [isTracking, setIsTracking] = useState(false);
  const [pathHistory, setPathHistory] = useState<LocationData[]>([]);
  const [locationPermission, setLocationPermission] = useState(false);
  const [totalDistance, setTotalDistance] = useState(0);
  const [sessionStartTime, setSessionStartTime] = useState<number | null>(null);
  const [locationSubscription, setLocationSubscription] = useState<Location.LocationSubscription | null>(null);
  const [currentSession, setCurrentSession] = useState<TrackingSession | null>(null);
  const [pastSessions, setPastSessions] = useState<TrackingSession[]>([]);
  const [activeWorkers, setActiveWorkers] = useState<ActiveWorker[]>([]);
  const [offlineLocationCount, setOfflineLocationCount] = useState(0);
  const [pendingSyncCount, setPendingSyncCount] = useState(0);
  // New ministry session state
  const [currentMinistrySession, setCurrentMinistrySession] = useState<MinistrySession | null>(null);
  const [ministrySessionId, setMinistrySessionId] = useState<string | null>(null);
  const [sessionDuration, setSessionDuration] = useState(0);

  // Performance optimization state
  const [lastLocationUpdate, setLastLocationUpdate] = useState<number>(0);
  const [lastPathUpdate, setLastPathUpdate] = useState<number>(0);
  const [pendingPathPoints, setPendingPathPoints] = useState<PathPoint[]>([]);

  const offlineManager = OfflineManager.getInstance();

  // Calculate distance between two points using Haversine formula
  const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number): number => {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a =
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  };

  // Throttled path update function for performance optimization
  const throttledPathUpdate = useCallback(
    WebOptimizations.throttle(async (pathPoint: PathPoint) => {
      const now = Date.now();

      // Add to pending points
      setPendingPathPoints(prev => [...prev, pathPoint]);

      // Web-optimized throttle timing
      const webThrottleTime = Platform.OS === 'web' ? PATH_UPDATE_THROTTLE * 1.5 : PATH_UPDATE_THROTTLE;
      
      // Check if enough time has passed for batch update
      if (now - lastPathUpdate >= webThrottleTime) {
        setLastPathUpdate(now);

      // Process all pending points
      if (ministrySessionId && pendingPathPoints.length > 0) {
        try {
          // Enhanced Batch Processing with Distance Aggregation
          if (pendingPathPoints.length > 0) {
            console.log(`📦 Processing batch of ${pendingPathPoints.length} path points...`);
            
            // Filter and validate points before processing
            const validPoints = pendingPathPoints.filter(point => {
              // GPS accuracy check
              if (point.accuracy && point.accuracy > GPS_ACCURACY_THRESHOLD) {
                console.log(`📍 Batch: Filtering out low accuracy point: ${point.accuracy.toFixed(1)}m`);
                return false;
              }
              return true;
            });

            // Process valid points efficiently
            let processedCount = 0;
            for (const point of validPoints) {
              try {
                await ministrySessionService.addPathPoint(ministrySessionId, point);
                processedCount++;
              } catch (error) {
                console.warn('⚠️ Failed to process individual path point:', error);
              }
            }

            console.log(`✅ Batch processed: ${processedCount}/${pendingPathPoints.length} path points (${validPoints.length} valid)`);
          }

          // Clear pending points
          setPendingPathPoints([]);
        } catch (error) {
          console.error('❌ Error in batch path update:', error);
        }
      }
    }
    }, Platform.OS === 'web' ? 300 : 200), // Web-specific throttle timing
    [ministrySessionId, pendingPathPoints, lastPathUpdate]
  );

  // Request location permission with comprehensive handling
  const requestPermission = async (): Promise<boolean> => {
    try {
      console.log('🔐 Requesting location permission...');
      console.log('Platform:', Platform.OS);

      if (Platform.OS === 'web') {
        // For web, check if geolocation is available
        if (!navigator.geolocation) {
          console.error('❌ Geolocation not supported on this browser');
          Alert.alert(
            'Location Not Supported',
            'Your browser does not support location services. Please use a modern browser like Chrome, Firefox, or Safari.',
            [{ text: 'OK' }]
          );
          setLocationPermission(false);
          return false;
        }

        // Try to get permission status
        try {
          const permission = await navigator.permissions.query({ name: 'geolocation' });
          console.log('🌐 Web geolocation permission state:', permission.state);

          if (permission.state === 'granted') {
            console.log('✅ Web location permission already granted');
            setLocationPermission(true);
            return true;
          } else if (permission.state === 'prompt') {
            console.log('❓ Web location permission will be prompted');
            // Test with actual location request
            return new Promise((resolve) => {
              navigator.geolocation.getCurrentPosition(
                (position) => {
                  console.log('✅ Web location permission granted via test');
                  setLocationPermission(true);
                  resolve(true);
                },
                (error) => {
                  console.error('❌ Web location permission denied via test:', error);
                  let errorMessage = 'Location access denied. ';
                  switch(error.code) {
                    case 1:
                      errorMessage += 'Please allow location access in your browser settings.';
                      break;
                    case 2:
                      errorMessage += 'Location unavailable. Please check your GPS and internet connection.';
                      break;
                    case 3:
                      errorMessage += 'Location request timed out. Please try again.';
                      break;
                    default:
                      errorMessage += 'Please enable location services and try again.';
                  }
                  Alert.alert('Location Permission Required', errorMessage, [{ text: 'OK' }]);
                  setLocationPermission(false);
                  resolve(false);
                },
                { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
              );
            });
          } else {
            console.error('❌ Web location permission denied');
            Alert.alert(
              'Location Permission Denied',
              'Location access has been denied. Please enable location access in your browser settings and refresh the page.',
              [{ text: 'OK' }]
            );
            setLocationPermission(false);
            return false;
          }
        } catch (error) {
          console.warn('⚠️ Could not check web permissions, testing with location request:', error);
          // Fallback: test with actual location request
          return new Promise((resolve) => {
            navigator.geolocation.getCurrentPosition(
              (position) => {
                console.log('✅ Web location permission granted via fallback test');
                setLocationPermission(true);
                resolve(true);
              },
              (error) => {
                console.error('❌ Web location permission denied via fallback test:', error);
                Alert.alert(
                  'Location Permission Required',
                  'Please allow location access when prompted by your browser.',
                  [{ text: 'OK' }]
                );
                setLocationPermission(false);
                resolve(false);
              },
              { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
            );
          });
        }
      } else {
        // For mobile, use Expo Location with comprehensive permission handling
        console.log('📱 Requesting mobile location permissions...');

        // Check current permission status first
        const currentStatus = await Location.getForegroundPermissionsAsync();
        console.log('📱 Current foreground permission status:', currentStatus.status);

        if (currentStatus.status === 'granted') {
          console.log('✅ Mobile location permission already granted');
          setLocationPermission(true);
          return true;
        }

        // Request foreground permissions
        const { status } = await Location.requestForegroundPermissionsAsync();
        console.log('📱 Mobile foreground permission request result:', status);

        if (status === 'granted') {
          console.log('✅ Mobile location permission granted');

          // Also try to request background permissions for better tracking (optional)
          try {
            const backgroundStatus = await Location.requestBackgroundPermissionsAsync();
            console.log('📱 Background permission status:', backgroundStatus.status);
            if (backgroundStatus.status === 'granted') {
              console.log('✅ Background location permission also granted');
            }
          } catch (bgError) {
            console.log('⚠️ Background permission request failed (this is OK):', bgError);
          }

          setLocationPermission(true);
          return true;
        } else {
          console.error('❌ Mobile location permission denied:', status);
          Alert.alert(
            'Location Permission Required',
            'Rally Point needs location access to track your ministry work. Please enable location permissions in your device settings.',
            [
              { text: 'Cancel', style: 'cancel' },
              { text: 'Open Settings', onPress: () => {
                // On mobile, you might want to open app settings
                console.log('Opening app settings...');
              }}
            ]
          );
          setLocationPermission(false);
          return false;
        }
      }
    } catch (error) {
      console.error('❌ Error requesting location permission:', error);
      Alert.alert(
        'Permission Error',
        'Unable to request location permission. Please check your device settings and try again.',
        [{ text: 'OK' }]
      );
      setLocationPermission(false);
      return false;
    }
  };

  // Start location tracking
  const startTracking = async (sessionName?: string) => {
    try {
      console.log('Starting location tracking...');
      console.log('User available:', !!user);
      console.log('Platform:', Platform.OS);

      if (!user) {
        console.error('User not authenticated');
        throw new Error('User not authenticated. Please log in again.');
      }

      // Set tracking state immediately to show user that something is happening
      setIsTracking(true);
      setSessionStartTime(Date.now());
      setTotalDistance(0);

      console.log('Requesting location permission...');
      const hasPermission = await requestPermission();
      if (!hasPermission) {
        console.error('Location permission denied');
        throw new Error('Location permission is required for ministry tracking');
      }

      console.log('Location permission granted');

      // Start offline tracking session
      try {
        const sessionId = await realtimeLocationService.startTrackingSession(user.email, user.display_name || user.email);
        console.log('✅ Offline tracking session started:', sessionId);
      } catch (error) {
        console.warn('⚠️ Failed to start offline tracking session:', error);
      }

      // Remove duplicate state setting since we already set it above
      console.log('Location tracking state set, proceeding with location acquisition...');

      // Get initial location with platform-specific handling
      console.log('Getting initial location...');
      let locationData: LocationData;

      if (Platform.OS === 'web') {
        // Use web geolocation API with improved error handling
        console.log('Using web geolocation API...');
        const position = await new Promise<GeolocationPosition>((resolve, reject) => {
          if (!navigator.geolocation) {
            reject(new Error('Geolocation is not supported by this browser'));
            return;
          }

          // Try with high accuracy first
          console.log('Attempting high accuracy location...');
          navigator.geolocation.getCurrentPosition(
            (pos) => {
              console.log('✅ High accuracy location obtained');
              resolve(pos);
            },
            (error) => {
              console.warn('⚠️ High accuracy failed, trying low accuracy...', error);

              // Fallback to low accuracy with longer timeout
              navigator.geolocation.getCurrentPosition(
                (pos) => {
                  console.log('✅ Low accuracy location obtained');
                  resolve(pos);
                },
                (fallbackError) => {
                  console.error('❌ Both high and low accuracy failed:', fallbackError);
                  reject(fallbackError);
                },
                {
                  enableHighAccuracy: false,
                  timeout: 30000, // 30 seconds for fallback
                  maximumAge: 60000 // Accept older location data
                }
              );
            },
            {
              enableHighAccuracy: true,
              timeout: 20000, // Increased to 20 seconds
              maximumAge: 10000
            }
          );
        });

        locationData = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          timestamp: Date.now(),
          accuracy: position.coords.accuracy || undefined,
          speed: position.coords.speed || undefined,
          heading: position.coords.heading || undefined,
        };
      } else {
        // Use Expo Location API for mobile
        console.log('Using Expo Location API...');
        const initialLocation = await Location.getCurrentPositionAsync({
          accuracy: Location.Accuracy.High,
          timeout: 15000,
          maximumAge: 10000,
        });

        locationData = {
          latitude: initialLocation.coords.latitude,
          longitude: initialLocation.coords.longitude,
          timestamp: Date.now(),
          accuracy: initialLocation.coords.accuracy || undefined,
          speed: initialLocation.coords.speed || undefined,
          heading: initialLocation.coords.heading || undefined,
        };
      }

      console.log('Initial location acquired:', {
        lat: locationData.latitude,
        lng: locationData.longitude,
        platform: Platform.OS
      });

      setCurrentLocation(locationData);
      setPathHistory([locationData]);

      // Create new session (mock - in production would save to Firestore)
      const currentTime = Date.now();
      const newSession: TrackingSession = {
        id: Math.random().toString(36).substr(2, 9),
        userId: user.email,
        userName: user.display_name || user.email,
        userRole: user.role,
        startTime: sessionStartTime || currentTime,
        totalDistance: 0,
        pathPoints: [locationData],
        isActive: true,
        sessionName: sessionName || `Session ${new Date().toLocaleDateString()}`,
      };

      setCurrentSession(newSession);

      // Start new ministry session with proper backend integration
      try {
        console.log('🚀 Starting ministry session with MinistrySessionService...');
        const sessionId = await ministrySessionService.startSession(
          user.id || user.email,
          user.display_name || user.email,
          user.role || 'worker',
          undefined, // territoryId - can be added later
          undefined, // territoryName - can be added later
          undefined, // teamId - can be added later
          undefined, // teamName - can be added later
          sessionName
        );

        setMinistrySessionId(sessionId);
        console.log('✅ Ministry session started:', sessionId);

        // Add initial path point
        const initialPathPoint: PathPoint = {
          latitude: locationData.latitude,
          longitude: locationData.longitude,
          timestamp: locationData.timestamp,
          accuracy: locationData.accuracy,
          speed: locationData.speed,
          heading: locationData.heading,
        };

        await ministrySessionService.addPathPoint(sessionId, initialPathPoint);

        // Get the created session
        const createdSession = await ministrySessionService.getSession(sessionId);
        setCurrentMinistrySession(createdSession);

        console.log('✅ Initial path point added to ministry session');
      } catch (error) {
        console.error('❌ Error starting ministry session:', error);
        // Continue with local tracking even if ministry session fails
      }

      // Start backend realtime location tracking
      console.log('Starting backend realtime location tracking...');
      try {
        await realtimeLocationService.startLocationTracking(
          user.id || user.email,
          user.display_name || user.email
        );
        console.log('Backend realtime tracking started successfully');
      } catch (trackingError) {
        console.warn('Backend realtime tracking failed, continuing with local tracking:', trackingError);
      }

      // Start watching location with error handling
      console.log('Starting location watch...');

      try {
        let subscription: any = null;

        if (Platform.OS === 'web') {
          // For web, use a simple interval-based approach to avoid crashes
          console.log('Using web-compatible location tracking...');
          const intervalId = setInterval(async () => {
            try {
              if (!navigator.geolocation) return;

              navigator.geolocation.getCurrentPosition(
                (position) => {
                  const newLocationData: LocationData = {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    timestamp: Date.now(),
                    accuracy: position.coords.accuracy || undefined,
                    speed: position.coords.speed || undefined,
                    heading: position.coords.heading || undefined,
                  };

                  setCurrentLocation(newLocationData);
                  setPathHistory(prev => [...prev, newLocationData]);
                },
                (error) => console.warn('Web location update failed:', error),
                { enableHighAccuracy: true, timeout: 10000, maximumAge: 30000 }
              );
            } catch (error) {
              console.warn('Web location interval error:', error);
            }
          }, 15000); // Update every 15 seconds

          subscription = { remove: () => clearInterval(intervalId) };
        } else {
          // For mobile, use Expo Location API
          console.log('Using Expo location tracking...');
          subscription = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.High,
          timeInterval: 10000, // Update every 10 seconds (less frequent to avoid crashes)
          distanceInterval: 20, // Update every 20 meters
        },
        async (location) => {
          const newLocationData: LocationData = {
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
            timestamp: Date.now(),
            accuracy: location.coords.accuracy || undefined,
            speed: location.coords.speed || undefined,
            heading: location.coords.heading || undefined,
          };

          setCurrentLocation(newLocationData);

          setPathHistory(prev => {
            const newHistory = [...prev, newLocationData];

            // Calculate distance if we have a previous location
            let newDistance = 0;
            if (prev.length > 0) {
              const lastLocation = prev[prev.length - 1];
              newDistance = calculateDistance(
                lastLocation.latitude,
                lastLocation.longitude,
                newLocationData.latitude,
                newLocationData.longitude
              );
              setTotalDistance(prevDistance => {
                const updatedDistance = prevDistance + newDistance;

                // Update session in memory (mock - in production would update Firestore)
                if (currentSession) {
                  setCurrentSession(prev => prev ? {
                    ...prev,
                    pathPoints: newHistory,
                    totalDistance: updatedDistance,
                  } : null);
                }

                return updatedDistance;
              });
            }

            // Add path point to ministry session with improved filtering
            if (ministrySessionId && newDistance > MIN_DISTANCE_THRESHOLD / 1000) { // Convert meters to km
              const now = Date.now();

              // GPS Accuracy filtering - Skip poor quality readings
              if (newLocationData.accuracy && newLocationData.accuracy > GPS_ACCURACY_THRESHOLD) {
                console.log(`📍 LocationContext: GPS accuracy too low: ${newLocationData.accuracy.toFixed(1)}m, skipping path update`);
                return;
              }

              // Speed validation - Check for unrealistic movement
              if (pathHistory.length > 0) {
                const lastLocation = pathHistory[pathHistory.length - 1];
                const timeInterval = (now - lastLocation.timestamp) / 1000 / 3600; // hours
                const speedKmh = (newDistance / timeInterval);
                
                if (speedKmh > MAX_REASONABLE_SPEED_KMH) {
                  console.log(`📍 LocationContext: Unrealistic speed detected: ${speedKmh.toFixed(1)} km/h, skipping path update`);
                  return;
                }
              }

              // Throttle location updates for performance
              if (now - lastLocationUpdate >= LOCATION_UPDATE_THROTTLE) {
                setLastLocationUpdate(now);

                const pathPoint: PathPoint = {
                  latitude: newLocationData.latitude,
                  longitude: newLocationData.longitude,
                  timestamp: newLocationData.timestamp,
                  accuracy: newLocationData.accuracy,
                  speed: newLocationData.speed,
                  heading: newLocationData.heading,
                };

                // Use throttled path update for better performance
                throttledPathUpdate(pathPoint)
                  .then(() => {
                    // Update current ministry session state less frequently
                    if (now - lastPathUpdate >= PATH_UPDATE_THROTTLE) {
                      ministrySessionService.getSession(ministrySessionId)
                        .then(updatedSession => {
                          if (updatedSession) {
                            setCurrentMinistrySession(updatedSession);
                          }
                        })
                        .catch(error => console.warn('⚠️ Error updating ministry session state:', error));
                    }
                  })
                  .catch(error => console.warn('⚠️ Error in throttled path update:', error));
              }
            }

            // Save to AsyncStorage
            AsyncStorage.setItem('pathHistory', JSON.stringify(newHistory));

            return newHistory;
          });

          // Update active worker location (mock - in production would save to Firestore)
          try {
            const activeWorkerData: ActiveWorker = {
              id: user.id,
              userId: user.email,
              userName: user.display_name || user.email,
              userRole: user.role,
              currentLocation: newLocationData,
              isActive: true,
              lastUpdate: Date.now(),
            };

            // Update local active workers list
            setActiveWorkers(prev => {
              const filtered = prev.filter(w => w.userId !== user.email);
              return [...filtered, activeWorkerData];
            });

            // Send location update to backend
            WorkerStatsService.updateLocation(
              newLocationData.latitude,
              newLocationData.longitude,
              newLocationData.accuracy,
              newLocationData.speed,
              newLocationData.heading
            ).catch((err: any) => console.warn('Backend location update failed:', err));
          } catch (error) {
            console.error('Error updating active worker location:', error);
          }
        }
      );
        }

        setLocationSubscription(subscription);
        console.log('Location tracking started successfully');
      } catch (locationError) {
        console.error('Error setting up location watch:', locationError);
        // Continue without location watching - at least we have initial location
        console.log('Continuing with initial location only');
      }
    } catch (error) {
      console.error('Error starting location tracking:', error);

      // Reset all tracking state on error
      setIsTracking(false);
      setSessionStartTime(null);
      setCurrentSession(null);

      // Provide specific error messages based on error type
      let errorMessage = 'Unknown error occurred';

      if (error instanceof Error) {
        if (error.message.includes('Timeout expired') || error.message.includes('timeout')) {
          errorMessage = 'Location request timed out. Please ensure GPS is enabled and try again. You may need to allow location access in your browser settings.';
        } else if (error.message.includes('permission') || error.message.includes('denied')) {
          errorMessage = 'Location permission denied. Please allow location access in your browser settings and try again.';
        } else if (error.message.includes('not supported')) {
          errorMessage = 'Location services are not supported on this device or browser.';
        } else if (error.message.includes('unavailable')) {
          errorMessage = 'Location services are currently unavailable. Please check your GPS settings and try again.';
        } else {
          errorMessage = error.message;
        }
      }

      throw new Error(`Failed to start ministry tracking: ${errorMessage}`);
    }
  };

  // Stop location tracking
  const stopTracking = async () => {
    try {
      console.log('🛑 LocationContext: Starting stopTracking process...');
      console.log('🔍 LocationContext: Current state before stop:', {
        isTracking,
        hasLocationSubscription: !!locationSubscription,
        currentSessionActive: currentSession?.isActive,
        userEmail: user?.email
      });

      if (locationSubscription) {
        console.log('🛑 LocationContext: Removing location subscription...');
        locationSubscription.remove();
        setLocationSubscription(null);
        console.log('✅ LocationContext: Location subscription removed');
      }

      console.log('🛑 LocationContext: Setting isTracking to false...');
      setIsTracking(false);
      console.log('✅ LocationContext: isTracking state updated to false');

      // End offline tracking session
      try {
        console.log('🛑 LocationContext: Ending offline tracking session...');
        await realtimeLocationService.endTrackingSession();
        console.log('✅ LocationContext: Offline tracking session ended');
      } catch (error) {
        console.warn('⚠️ LocationContext: Failed to end offline tracking session:', error);
      }

      // Update session (mock - in production would update Firestore)
      if (currentSession) {
        console.log('🛑 LocationContext: Completing current session...');
        const completedSession = {
          ...currentSession,
          endTime: Date.now(),
          isActive: false,
          totalDistance,
          pathPoints: pathHistory,
        };

        // Add to past sessions
        setPastSessions(prev => [completedSession, ...prev]);
        setCurrentSession(null);
        console.log('✅ LocationContext: Current session completed and moved to past sessions');
      }

      // End ministry session
      if (ministrySessionId) {
        try {
          console.log('🛑 Ending ministry session:', ministrySessionId);
          const endedSession = await ministrySessionService.endSession(ministrySessionId);
          if (endedSession) {
            setCurrentMinistrySession(null);
            setMinistrySessionId(null);
            setSessionDuration(0);
            console.log('✅ Ministry session ended successfully');
          }
        } catch (error) {
          console.error('❌ Error ending ministry session:', error);
          // Reset state even if ending fails
          setCurrentMinistrySession(null);
          setMinistrySessionId(null);
          setSessionDuration(0);
        }
      }

      setSessionStartTime(null);
      console.log('✅ LocationContext: Session start time cleared');

      // Remove from active workers
      if (user) {
        console.log('🛑 LocationContext: Removing user from active workers...');
        setActiveWorkers(prev => prev.filter(w => w.userId !== user.email));
        console.log('✅ LocationContext: User removed from active workers');
      }

      // Stop backend realtime location tracking
      console.log('🛑 LocationContext: Stopping backend realtime location tracking...');
      try {
        await realtimeLocationService.stopLocationTracking();
        console.log('✅ LocationContext: Backend realtime tracking stopped successfully');
      } catch (trackingError) {
        console.warn('⚠️ LocationContext: Backend realtime tracking stop failed:', trackingError);
      }

      console.log('🎉 LocationContext: Location tracking stopped successfully!');
      console.log('🔍 LocationContext: Final state after stop:', {
        isTracking: false,
        hasLocationSubscription: false,
        currentSessionActive: false,
        sessionStartTime: null
      });
    } catch (error) {
      console.error('❌ LocationContext: Error stopping tracking session:', error);

      // Ensure tracking is stopped even if there's an error
      setIsTracking(false);
      setSessionStartTime(null);
      setCurrentSession(null);

      if (locationSubscription) {
        try {
          locationSubscription.remove();
        } catch (subError) {
          console.error('Error removing location subscription:', subError);
        }
        setLocationSubscription(null);
      }
    }
  };

  // Clear path history
  const clearHistory = () => {
    setPathHistory([]);
    setTotalDistance(0);
    AsyncStorage.removeItem('pathHistory');
  };

  // Load past sessions (mock - in production would load from Firestore)
  const loadPastSessions = async () => {
    try {
      if (!user) return;

      // Mock data - in production this would query Firestore
      const mockSessions: TrackingSession[] = [
        {
          id: '1',
          userId: user.email,
          userName: user.display_name,
          userRole: user.role,
          startTime: Date.now() - 2 * 60 * 60 * 1000, // 2 hours ago
          endTime: Date.now() - 1 * 60 * 60 * 1000, // 1 hour ago
          totalDistance: 2.5,
          pathPoints: [],
          isActive: false,
          sessionName: 'Morning Territory Work',
        },
        {
          id: '2',
          userId: user.email,
          userName: user.display_name,
          userRole: user.role,
          startTime: Date.now() - 24 * 60 * 60 * 1000, // Yesterday
          endTime: Date.now() - 23 * 60 * 60 * 1000,
          totalDistance: 1.8,
          pathPoints: [],
          isActive: false,
          sessionName: 'Afternoon Visits',
        },
      ];

      setPastSessions(mockSessions);
    } catch (error) {
      console.error('Error loading past sessions:', error);
    }
  };

  // Load active workers (mock - in production would load from Firestore)
  const loadActiveWorkers = async () => {
    try {
      // Mock data for admin view - in production this would query Firestore
      const mockWorkers: ActiveWorker[] = [
        {
          id: '1',
          userId: 'john@example.com',
          userName: 'John Smith',
          userRole: 'worker',
          currentLocation: {
            latitude: 37.7849 + (Math.random() - 0.5) * 0.01,
            longitude: -122.4094 + (Math.random() - 0.5) * 0.01,
            timestamp: Date.now(),
          },
          isActive: true,
          lastUpdate: Date.now() - 2 * 60 * 1000, // 2 minutes ago
        },
        {
          id: '2',
          userId: 'mary@example.com',
          userName: 'Mary Johnson',
          userRole: 'team_leader',
          currentLocation: {
            latitude: 37.7749 + (Math.random() - 0.5) * 0.01,
            longitude: -122.4194 + (Math.random() - 0.5) * 0.01,
            timestamp: Date.now(),
          },
          isActive: true,
          lastUpdate: Date.now() - 5 * 60 * 1000, // 5 minutes ago
        },
      ];

      // Only show mock workers if current user is admin
      if (user?.role === 'admin') {
        setActiveWorkers(mockWorkers);
      }
    } catch (error) {
      console.error('Error loading active workers:', error);
    }
  };

  // Load saved path history on mount
  useEffect(() => {
    const loadSavedHistory = async () => {
      try {
        const savedHistory = await AsyncStorage.getItem('pathHistory');
        if (savedHistory) {
          const history = JSON.parse(savedHistory);
          setPathHistory(history);
          
          // Calculate total distance from saved history
          let distance = 0;
          for (let i = 1; i < history.length; i++) {
            distance += calculateDistance(
              history[i-1].latitude,
              history[i-1].longitude,
              history[i].latitude,
              history[i].longitude
            );
          }
          setTotalDistance(distance);
        }
      } catch (error) {
        console.error('Error loading saved history:', error);
      }
    };

    loadSavedHistory();
    requestPermission();
    loadOfflineData();
  }, []);

  // Load offline data counts
  const loadOfflineData = async () => {
    try {
      const [locations, pendingCount] = await Promise.all([
        offlineManager.getOfflineLocations(),
        offlineManager.getPendingSyncCount()
      ]);

      const userLocations = user ? locations.filter(l => l.userId === user.email) : locations;
      setOfflineLocationCount(userLocations.length);
      setPendingSyncCount(pendingCount);
    } catch (error) {
      console.error('Error loading offline data:', error);
    }
  };

  // Sync offline data
  const syncOfflineData = async (): Promise<{ success: number; failed: number }> => {
    try {
      const result = await offlineManager.syncOfflineData();
      await loadOfflineData(); // Refresh counts after sync
      return result;
    } catch (error) {
      console.error('Error syncing offline data:', error);
      return { success: 0, failed: 0 };
    }
  };

  // Helper functions for ministry session
  const getSessionPath = (): PathPoint[] => {
    if (currentMinistrySession) {
      return currentMinistrySession.pathPoints;
    }
    // Fallback to local path history
    return pathHistory.map(point => ({
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: point.timestamp,
      accuracy: point.accuracy,
      speed: point.speed,
      heading: point.heading,
    }));
  };

  const getSessionSummary = (): { distance: number; duration: number; points: number } | null => {
    if (currentMinistrySession) {
      const duration = currentMinistrySession.endTime
        ? (currentMinistrySession.endTime - currentMinistrySession.startTime) / 60000
        : sessionStartTime
        ? (Date.now() - sessionStartTime) / 60000
        : 0;

      return {
        distance: currentMinistrySession.totalDistance,
        duration,
        points: currentMinistrySession.pathPoints.length
      };
    }

    if (sessionStartTime) {
      return {
        distance: totalDistance,
        duration: (Date.now() - sessionStartTime) / 60000,
        points: pathHistory.length
      };
    }

    return null;
  };

  // Update session duration every second when tracking
  useEffect(() => {
    let interval: NodeJS.Timeout;

    if (isTracking && sessionStartTime) {
      interval = setInterval(() => {
        const duration = (Date.now() - sessionStartTime) / 60000;
        setSessionDuration(duration);
      }, 1000);
    }

    return () => {
      if (interval) {
        clearInterval(interval);
      }
    };
  }, [isTracking, sessionStartTime]);

  // Periodic offline data refresh
  useEffect(() => {
    const interval = setInterval(loadOfflineData, 10000); // Every 10 seconds
    return () => clearInterval(interval);
  }, [user]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (locationSubscription) {
        locationSubscription.remove();
      }
    };
  }, [locationSubscription]);

  const value: LocationContextType = {
    currentLocation,
    isTracking,
    pathHistory,
    startTracking,
    stopTracking,
    clearHistory,
    locationPermission,
    requestPermission,
    totalDistance,
    sessionStartTime,
    currentSession,
    pastSessions,
    activeWorkers,
    loadPastSessions,
    loadActiveWorkers,
    offlineLocationCount,
    pendingSyncCount,
    syncOfflineData,
    // New ministry session functionality
    currentMinistrySession,
    ministrySessionId,
    sessionDuration,
    getSessionPath,
    getSessionSummary,
  };

  return (
    <LocationContext.Provider value={value}>
      {children}
    </LocationContext.Provider>
  );
};
