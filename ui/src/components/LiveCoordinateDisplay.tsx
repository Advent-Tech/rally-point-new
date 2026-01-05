import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Platform } from 'react-native';
import * as Location from 'expo-location';
import { realtimeLocationService } from '../services/RealtimeLocationService';

interface LiveCoordinateDisplayProps {
  userId: string;
  userName: string;
  isMinistryTrackingActive: boolean; // New prop to control tracking
}

interface LocationData {
  latitude: number;
  longitude: number;
  accuracy: number;
  speed: number | null;
  heading: number | null;
  timestamp: number;
}

export default function LiveCoordinateDisplay({ userId, userName, isMinistryTrackingActive }: LiveCoordinateDisplayProps) {
  const [currentLocation, setCurrentLocation] = useState<LocationData | null>(null);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());
  const [isTracking, setIsTracking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [backendSync, setBackendSync] = useState(false);
  const [backendLocation, setBackendLocation] = useState<LocationData | null>(null);

  useEffect(() => {
    console.log('🎯 LiveCoordinateDisplay ministry tracking state changed:', isMinistryTrackingActive);

    if (isMinistryTrackingActive) {
      console.log('🚀 Starting location tracking for:', userName);

      // Start the main location tracking service
      startMainLocationService();

      // Also start local display tracking
      startLocationTracking();
    } else {
      console.log('🛑 Stopping location tracking for:', userName);

      // Stop all tracking
      stopMainLocationService();
      stopLocationTracking();

      // Clear location data
      setCurrentLocation(null);
      setBackendLocation(null);
      setBackendSync(false);
      setIsTracking(false);
    }

    return () => {
      stopLocationTracking();
      stopMainLocationService();
    };
  }, [userId, userName, isMinistryTrackingActive]);

  useEffect(() => {
    // Listen to Firebase updates to confirm sync (only when tracking is active)
    if (isMinistryTrackingActive) {
      const unsubscribe = realtimeLocationService.listenToWorker(userId, (workerData) => {
        if (workerData && workerData.currentLocation) {
          setFirebaseLocation({
            latitude: workerData.currentLocation.latitude,
            longitude: workerData.currentLocation.longitude,
            accuracy: workerData.currentLocation.accuracy,
            speed: workerData.currentLocation.speed,
            heading: workerData.currentLocation.heading,
            timestamp: workerData.currentLocation.timestamp,
          });
          console.log('🔄 Firebase location confirmed:', workerData.currentLocation);
        } else {
          // Worker is offline or no location data
          setFirebaseLocation(null);
        }
      });

      return () => {
        unsubscribe();
      };
    }
  }, [userId, isMinistryTrackingActive]);

  const startMainLocationService = async () => {
    try {
      console.log('🚀 Starting main location service for Firebase sync...');
      await realtimeLocationService.startLocationTracking(userId, userName);
      setFirebaseSync(true);
      console.log('✅ Main location service started successfully - Firebase sync active');
    } catch (error) {
      console.error('❌ Failed to start main location service:', error);
      setFirebaseSync(false);
    }
  };

  const stopMainLocationService = () => {
    try {
      console.log('🛑 Stopping main location service for Firebase sync...');
      realtimeLocationService.stopLocationTracking();
      setFirebaseSync(false);
      console.log('✅ Main location service stopped - Firebase sync inactive');
    } catch (error) {
      console.error('❌ Failed to stop main location service:', error);
    }
  };

  const startLocationTracking = async () => {
    try {
      console.log('📍 Starting live coordinate display for worker:', userName);
      setIsTracking(true);
      setError(null);

      if (Platform.OS === 'web') {
        // Web geolocation with real-time updates
        if (!navigator.geolocation) {
          throw new Error('Geolocation not supported');
        }

        // Check permissions
        try {
          const permission = await navigator.permissions.query({ name: 'geolocation' });
          console.log('🔐 GPS Permission status:', permission.state);
          if (permission.state === 'denied') {
            throw new Error('Location permission denied. Please allow location access.');
          }
        } catch (permError) {
          console.warn('⚠️ Could not check permissions:', permError);
        }

        // Start watching position with high frequency updates
        const watchId = navigator.geolocation.watchPosition(
          (position) => {
            const locationData: LocationData = {
              latitude: position.coords.latitude,
              longitude: position.coords.longitude,
              accuracy: position.coords.accuracy || 0,
              speed: position.coords.speed,
              heading: position.coords.heading,
              timestamp: Date.now(),
            };

            console.log('📍 Live GPS coordinates for', userName, ':', {
              lat: locationData.latitude.toFixed(8),
              lng: locationData.longitude.toFixed(8),
              accuracy: locationData.accuracy.toFixed(1) + 'm',
              time: new Date().toLocaleTimeString()
            });

            // Update local state for display
            setCurrentLocation(locationData);
            setLastUpdate(new Date());
          },
          (error) => {
            console.error('❌ GPS error for', userName, ':', error);
            setError(`GPS Error: ${error.message}`);
          },
          {
            enableHighAccuracy: true,
            timeout: 8000,
            maximumAge: 0, // Always get fresh location data
          }
        );

        // Store watch ID for cleanup
        (window as any).liveCoordinateWatchId = watchId;

      } else {
        // Mobile location using Expo with high accuracy
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
          throw new Error('Location permission denied. Please allow location access.');
        }

        console.log('📱 Starting mobile GPS tracking for:', userName);

        const subscription = await Location.watchPositionAsync(
          {
            accuracy: Location.Accuracy.BestForNavigation, // Highest accuracy
            timeInterval: 1000, // Update every second
            distanceInterval: 0.1, // Update every 10cm for maximum sensitivity
          },
          (location) => {
            const locationData: LocationData = {
              latitude: location.coords.latitude,
              longitude: location.coords.longitude,
              accuracy: location.coords.accuracy || 0,
              speed: location.coords.speed,
              heading: location.coords.heading,
              timestamp: Date.now(),
            };

            console.log('📱 Live GPS coordinates for', userName, ':', {
              lat: locationData.latitude.toFixed(8),
              lng: locationData.longitude.toFixed(8),
              accuracy: locationData.accuracy.toFixed(1) + 'm',
              time: new Date().toLocaleTimeString()
            });

            // Update local state for display
            setCurrentLocation(locationData);
            setLastUpdate(new Date());
          }
        );

        // Store subscription for cleanup
        (window as any).liveCoordinateSubscription = subscription;
      }

    } catch (error: any) {
      console.error('❌ Failed to start location tracking:', error);
      setError(error.message);
      setIsTracking(false);
    }
  };

  const stopLocationTracking = () => {
    console.log('🛑 Stopping live coordinate tracking...');
    setIsTracking(false);

    // Clean up web watch
    if ((window as any).liveCoordinateWatchId) {
      navigator.geolocation.clearWatch((window as any).liveCoordinateWatchId);
      (window as any).liveCoordinateWatchId = null;
    }

    // Clean up mobile subscription
    if ((window as any).liveCoordinateSubscription) {
      (window as any).liveCoordinateSubscription.remove();
      (window as any).liveCoordinateSubscription = null;
    }
  };

  const formatTime = (timestamp: number) => {
    return new Date(timestamp).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  const getAccuracyColor = (accuracy: number) => {
    if (accuracy <= 10) return '#10B981'; // Green - Excellent
    if (accuracy <= 50) return '#F59E0B'; // Yellow - Good
    return '#EF4444'; // Red - Poor
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>📍 Real-time GPS Location</Text>
        <Text style={styles.subtitle}>{userName}</Text>
      </View>

      {!isMinistryTrackingActive ? (
        <View style={styles.offlineContainer}>
          <Text style={styles.offlineTitle}>📴 Ministry Tracking Offline</Text>
          <Text style={styles.offlineText}>
            Click "Start Ministry Tracking" to begin real-time location tracking and Firebase sync.
          </Text>
        </View>
      ) : error ? (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>❌ {error}</Text>
        </View>
      ) : currentLocation ? (
        <View style={styles.locationContainer}>
          <View style={styles.coordinateRow}>
            <Text style={styles.label}>Latitude:</Text>
            <Text style={styles.coordinate}>{currentLocation.latitude.toFixed(8)}</Text>
          </View>
          
          <View style={styles.coordinateRow}>
            <Text style={styles.label}>Longitude:</Text>
            <Text style={styles.coordinate}>{currentLocation.longitude.toFixed(8)}</Text>
          </View>
          
          <View style={styles.coordinateRow}>
            <Text style={styles.label}>Accuracy:</Text>
            <Text style={[styles.accuracy, { color: getAccuracyColor(currentLocation.accuracy) }]}>
              ±{currentLocation.accuracy.toFixed(1)}m
            </Text>
          </View>
          
          <View style={styles.coordinateRow}>
            <Text style={styles.label}>Speed:</Text>
            <Text style={styles.value}>
              {currentLocation.speed ? `${(currentLocation.speed * 3.6).toFixed(1)} km/h` : 'N/A'}
            </Text>
          </View>
          
          <View style={styles.coordinateRow}>
            <Text style={styles.label}>Last Update:</Text>
            <Text style={styles.timestamp}>{formatTime(currentLocation.timestamp)}</Text>
          </View>
          
          <View style={styles.statusContainer}>
            <View style={[styles.statusDot, { backgroundColor: (isMinistryTrackingActive && isTracking) ? '#10B981' : '#EF4444' }]} />
            <Text style={styles.statusText}>
              {isMinistryTrackingActive ?
                (isTracking ? '🟢 Live Tracking Active' : '🟡 Starting GPS...') :
                '🔴 Ministry Tracking Offline'
              }
            </Text>
          </View>

          <View style={styles.statusContainer}>
            <View style={[styles.statusDot, { backgroundColor: (isMinistryTrackingActive && backendSync) ? '#3B82F6' : '#6B7280' }]} />
            <Text style={styles.statusText}>
              {isMinistryTrackingActive ?
                (backendSync ? '🔄 Backend Sync Active' : '⚠️ Backend Sync Pending') :
                '⚫ Backend Sync Offline'
              }
            </Text>
          </View>

          {isMinistryTrackingActive && backendLocation && (
            <View style={styles.backendSection}>
              <Text style={styles.backendTitle}>📡 Backend Stored Location:</Text>
              <View style={styles.coordinateRow}>
                <Text style={styles.label}>Backend Lat:</Text>
                <Text style={styles.coordinate}>{backendLocation.latitude.toFixed(8)}</Text>
              </View>
              <View style={styles.coordinateRow}>
                <Text style={styles.label}>Backend Lng:</Text>
                <Text style={styles.coordinate}>{backendLocation.longitude.toFixed(8)}</Text>
              </View>
              <View style={styles.coordinateRow}>
                <Text style={styles.label}>Last Sync:</Text>
                <Text style={styles.timestamp}>{formatTime(backendLocation.timestamp)}</Text>
              </View>
            </View>
          )}

          {!isMinistryTrackingActive && (
            <View style={styles.offlineFirebaseSection}>
              <Text style={styles.offlineFirebaseTitle}>🔥 Firebase Status: Offline</Text>
              <Text style={styles.offlineFirebaseText}>
                Location data is not being saved to Firebase while ministry tracking is offline.
              </Text>
            </View>
          )}
        </View>
      ) : (
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>📡 Getting GPS coordinates...</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    margin: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  header: {
    marginBottom: 16,
    alignItems: 'center',
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1F2937',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: '#6B7280',
  },
  locationContainer: {
    gap: 12,
  },
  coordinateRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#F3F4F6',
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#374151',
  },
  coordinate: {
    fontSize: 14,
    fontFamily: 'monospace',
    color: '#1F2937',
    fontWeight: 'bold',
  },
  accuracy: {
    fontSize: 14,
    fontWeight: 'bold',
  },
  value: {
    fontSize: 14,
    color: '#1F2937',
  },
  timestamp: {
    fontSize: 14,
    color: '#6B7280',
    fontFamily: 'monospace',
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#F3F4F6',
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 8,
  },
  statusText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#374151',
  },
  errorContainer: {
    padding: 16,
    backgroundColor: '#FEF2F2',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#FECACA',
  },
  errorText: {
    color: '#DC2626',
    fontSize: 14,
    textAlign: 'center',
  },
  loadingContainer: {
    padding: 24,
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 16,
    color: '#6B7280',
  },
  backendSection: {
    marginTop: 16,
    paddingTop: 16,
    borderTopWidth: 2,
    borderTopColor: '#3B82F6',
    backgroundColor: '#EFF6FF',
    borderRadius: 8,
    padding: 12,
  },
  backendTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1E40AF',
    marginBottom: 8,
    textAlign: 'center',
  },
  offlineContainer: {
    padding: 24,
    backgroundColor: '#F3F4F6',
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#D1D5DB',
    borderStyle: 'dashed',
  },
  offlineTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#6B7280',
    marginBottom: 8,
    textAlign: 'center',
  },
  offlineText: {
    fontSize: 14,
    color: '#9CA3AF',
    textAlign: 'center',
    lineHeight: 20,
  },
  offlineFirebaseSection: {
    marginTop: 16,
    paddingTop: 16,
    borderTopWidth: 2,
    borderTopColor: '#6B7280',
    backgroundColor: '#F9FAFB',
    borderRadius: 8,
    padding: 12,
  },
  offlineFirebaseTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#6B7280',
    marginBottom: 8,
    textAlign: 'center',
  },
  offlineFirebaseText: {
    fontSize: 14,
    color: '#9CA3AF',
    textAlign: 'center',
    lineHeight: 18,
  },
});
