import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Animated,
  Dimensions,
  StatusBar,
  Platform,
  Modal,
  Alert,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import GeotrackingService from '../services/GeotrackingService';
import DeliveryTrackingService from '../services/DeliveryTrackingService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';
import MapView from '../components/MapView';
import { Polyline, Marker, Circle } from '../components/MapComponents';

const { width, height } = Dimensions.get('window');

interface LocationTrackingScreenProps {
  navigation: any;
}

const LocationTrackingScreen: React.FC<LocationTrackingScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const {
    currentLocation,
    isTracking,
    startTracking,
    stopTracking,
    totalDistance,
    sessionStartTime,
    pathHistory,
    clearHistory,
  } = useLocation();

  // Enhanced geotracking state
  const [currentSession, setCurrentSession] = useState<TrackingSession | null>(null);
  const [liveLocation, setLiveLocation] = useState<LocationPoint | null>(null);
  const [pathPoints, setPathPoints] = useState<LocationPoint[]>([]);
  const [sessionStats, setSessionStats] = useState({
    distance: 0,
    duration: 0,
    speed: 0,
    altitude: 0,
    accuracy: 0,
  });
  const [trackingPurpose, setTrackingPurpose] = useState<TrackingSession['purpose']>('field_work');
  const [showPurposeModal, setShowPurposeModal] = useState(false);
  const [todayStats, setTodayStats] = useState({
    distance: 0,
    duration: 0,
    sessions: 0,
  });
  
  const mapRef = useRef<any>(null);
  const [pulseAnim] = useState(new Animated.Value(1));
  const [slideAnim] = useState(new Animated.Value(0));
  const [sessionDuration, setSessionDuration] = useState(0);

  // Initialize enhanced geotracking
  useEffect(() => {
    initializeGeotracking();
    loadTodayStats();
    
    // Check for active session to resume
    GeotrackingService.resumeTracking().then(hasActiveSession => {
      if (hasActiveSession) {
        Alert.alert(
          'Resume Tracking',
          'You have an active tracking session. Would you like to resume?',
          [
            { text: 'No', style: 'cancel' },
            { text: 'Yes', onPress: resumeActiveSession }
          ]
        );
      }
    });

    return () => {
      // Cleanup location updates
      GeotrackingService.setLocationUpdateCallback(() => {});
    };
  }, []);

  // Set up live location updates
  useEffect(() => {
    GeotrackingService.setLocationUpdateCallback((location: LocationPoint) => {
      setLiveLocation(location);
      updateSessionStats();
      
      // Center map on current location
      if (mapRef.current && location) {
        mapRef.current.animateToRegion({
          latitude: location.latitude,
          longitude: location.longitude,
          latitudeDelta: 0.01,
          longitudeDelta: 0.01,
        }, 1000);
      }
    });
  }, []);

  // Update session stats
  const updateSessionStats = () => {
    const session = GeotrackingService.getCurrentSession();
    if (session) {
      setCurrentSession(session);
      setSessionStats({
        distance: session.totalDistance,
        duration: session.duration,
        speed: session.duration > 0 ? (session.totalDistance / session.duration) * 1000 : 0,
        altitude: session.locations[session.locations.length - 1]?.altitude || 0,
        accuracy: session.locations[session.locations.length - 1]?.accuracy || 0,
      });
    }
  };

  // Initialize geotracking
  const initializeGeotracking = async () => {
    try {
      await GeotrackingService.initializePermissions();
    } catch (error) {
      console.error('Failed to initialize geotracking:', error);
    }
  };

  // Load today's statistics
  const loadTodayStats = async () => {
    try {
      const stats = await GeotrackingService.getStats();
      setTodayStats({
        distance: stats.todayDistance,
        duration: stats.todayDuration,
        sessions: stats.weeklySessions,
      });
    } catch (error) {
      console.error('Failed to load today stats:', error);
    }
  };

  // Resume active session
  const resumeActiveSession = async () => {
    try {
      // Implementation would involve restoring the session
      console.log('Resuming active session...');
    } catch (error) {
      console.error('Failed to resume session:', error);
    }
  };

  // Start enhanced tracking
  const handleStartTracking = async () => {
    try {
      if (trackingPurpose === 'field_work') {
        // Start immediately for field work
        await startEnhancedTracking();
      } else {
        // Show purpose selection for other types
        setShowPurposeModal(true);
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to start tracking. Please check location permissions.');
    }
  };

  // Start tracking with purpose
  const startEnhancedTracking = async (purpose?: TrackingSession['purpose']) => {
    try {
      const sessionId = await GeotrackingService.startTracking(purpose || trackingPurpose);
      setCurrentSession(GeotrackingService.getCurrentSession());
      setShowPurposeModal(false);
      
      // Also update legacy tracking for compatibility
      startTracking();
      
      Alert.alert('Tracking Started', `Session ${sessionId} started successfully`);
    } catch (error) {
      console.error('Failed to start enhanced tracking:', error);
      throw error;
    }
  };

  // Stop tracking
  const handleStopTracking = async () => {
    try {
      const completedSession = await GeotrackingService.stopTracking();
      setCurrentSession(null);
      setLiveLocation(null);
      
      // Also stop legacy tracking
      stopTracking();
      
      // Reload stats
      await loadTodayStats();
      
      Alert.alert(
        'Session Completed',
        `Distance: ${(completedSession.totalDistance / 1000).toFixed(2)} km\\nDuration: ${(completedSession.duration / 1000 / 60).toFixed(1)} min`
      );
    } catch (error) {
      console.error('Failed to stop tracking:', error);
      Alert.alert('Error', 'Failed to stop tracking session');
    }
  };

  // Format duration
  const formatDuration = (ms: number): string => {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) {
      return `${hours}:${(minutes % 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`;
    }
    return `${minutes}:${(seconds % 60).toString().padStart(2, '0')}`;
  };

  // Format distance
  const formatDistance = (meters: number): string => {
    if (meters < 1000) {
      return `${meters.toFixed(0)} m`;
    }
    return `${(meters / 1000).toFixed(2)} km`;
  };

  // Pulse animation for tracking indicator
  useEffect(() => {
    if (isTracking) {
      const pulse = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.2,
            duration: 1000,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 1000,
            useNativeDriver: true,
          }),
        ])
      );
      pulse.start();
      return () => pulse.stop();
    }
  }, [isTracking, pulseAnim]);

  // Slide in animation
  useEffect(() => {
    Animated.timing(slideAnim, {
      toValue: 1,
      duration: 800,
      useNativeDriver: true,
    }).start();
  }, [slideAnim]);

  // Update session duration
  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (isTracking && sessionStartTime) {
      interval = setInterval(() => {
        setSessionDuration(Math.floor((Date.now() - sessionStartTime) / 1000));
      }, 1000);
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [isTracking, sessionStartTime]);

  const handleTrackingToggle = async () => {
    if (isTracking) {
      stopTracking();
    } else {
      await startTracking();
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="transparent" translucent />
      
      {/* Background Gradient */}
      <LinearGradient
        colors={['#0F0C29', '#24243e', '#302B63']}
        style={styles.backgroundGradient}
      />

      {/* Animated Background Orbs */}
      <View style={styles.orbContainer}>
        <Animated.View style={[styles.orb1, { transform: [{ scale: pulseAnim }] }]} />
        <Animated.View style={[styles.orb2, { transform: [{ scale: pulseAnim }] }]} />
      </View>

      {/* Header */}
      <Animated.View 
        style={[
          styles.header,
          {
            transform: [{
              translateY: slideAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [-100, 0],
              }),
            }],
          },
        ]}
      >
        <View style={styles.glassmorphismCard}>
          <Text style={styles.headerTitle}>Field Operations</Text>
          <Text style={styles.headerSubtitle}>Live Tracking • {user?.display_name}</Text>
        </View>
      </Animated.View>

      {/* Main Content */}
      <Animated.View 
        style={[
          styles.mainContent,
          {
            transform: [{
              translateY: slideAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [50, 0],
              }),
            }],
            opacity: slideAnim,
          },
        ]}
      >
        {/* Location Status Card */}
        <View style={styles.statusCard}>
          <LinearGradient
            colors={['rgba(255,255,255,0.1)', 'rgba(255,255,255,0.05)']}
            style={styles.glassmorphismCard}
          >
            <View style={styles.statusHeader}>
              <View style={styles.statusIndicator}>
                <Animated.View 
                  style={[
                    styles.trackingDot,
                    { 
                      backgroundColor: isTracking ? '#00FF88' : '#FF6B6B',
                      transform: [{ scale: pulseAnim }],
                    },
                  ]} 
                />
                <Text style={styles.statusText}>
                  {isTracking ? 'TRACKING ACTIVE' : 'TRACKING INACTIVE'}
                </Text>
              </View>
            </View>

            {currentLocation && (
              <View style={styles.locationInfo}>
                <Text style={styles.coordinatesText}>
                  {currentLocation.latitude.toFixed(6)}, {currentLocation.longitude.toFixed(6)}
                </Text>
                <Text style={styles.accuracyText}>
                  Accuracy: ±{currentLocation.accuracy?.toFixed(0) || 'N/A'}m
                </Text>
              </View>
            )}
          </LinearGradient>
        </View>

        {/* Enhanced Stats Cards */}
        <View style={styles.statsContainer}>
          <View style={styles.statCard}>
            <LinearGradient
              colors={['rgba(0,255,136,0.1)', 'rgba(0,255,136,0.05)']}
              style={styles.glassmorphismCard}
            >
              <Text style={styles.statValue}>{formatDistance(sessionStats.distance)}</Text>
              <Text style={styles.statLabel}>Distance</Text>
              <Text style={styles.statSubLabel}>Speed: {formatDistance(sessionStats.speed)}/s</Text>
            </LinearGradient>
          </View>

          <View style={styles.statCard}>
            <LinearGradient
              colors={['rgba(0,136,255,0.1)', 'rgba(0,136,255,0.05)']}
              style={styles.glassmorphismCard}
            >
              <Text style={styles.statValue}>{formatDuration(sessionStats.duration)}</Text>
              <Text style={styles.statLabel}>Duration</Text>
              <Text style={styles.statSubLabel}>Alt: {sessionStats.altitude.toFixed(0)}m</Text>
            </LinearGradient>
          </View>

          <View style={styles.statCard}>
            <LinearGradient
              colors={['rgba(255,107,107,0.1)', 'rgba(255,107,107,0.05)']}
              style={styles.glassmorphismCard}
            >
              <Text style={styles.statValue}>{currentSession?.locations.length || 0}</Text>
              <Text style={styles.statLabel}>Points</Text>
              <Text style={styles.statSubLabel}>Acc: ±{sessionStats.accuracy.toFixed(0)}m</Text>
            </LinearGradient>
          </View>
        </View>

        {/* Today's Summary */}
        <View style={styles.todaySummary}>
          <Text style={styles.summaryTitle}>Today's Activity</Text>
          <View style={styles.summaryStats}>
            <View style={styles.summaryItem}>
              <MaterialIcons name="directions-run" size={20} color={COLORS.primary} />
              <Text style={styles.summaryValue}>{formatDistance(todayStats.distance)}</Text>
              <Text style={styles.summaryLabel}>Total</Text>
            </View>
            <View style={styles.summaryItem}>
              <MaterialIcons name="schedule" size={20} color={COLORS.primary} />
              <Text style={styles.summaryValue}>{formatDuration(todayStats.duration)}</Text>
              <Text style={styles.summaryLabel}>Time</Text>
            </View>
            <View style={styles.summaryItem}>
              <MaterialIcons name="gps-fixed" size={20} color={COLORS.primary} />
              <Text style={styles.summaryValue}>{todayStats.sessions}</Text>
              <Text style={styles.summaryLabel}>Sessions</Text>
            </View>
          </View>
        </View>

        {/* Live Map */}
        <View style={styles.mapContainer}>
          <Text style={styles.mapTitle}>Live Tracking</Text>
          <MapView
            ref={mapRef}
            style={styles.map}
            initialRegion={{
              latitude: liveLocation?.latitude || currentLocation?.latitude || 37.78825,
              longitude: liveLocation?.longitude || currentLocation?.longitude || -122.4324,
              latitudeDelta: 0.01,
              longitudeDelta: 0.01,
            }}
            showsUserLocation={true}
            showsMyLocationButton={false}
            followsUserLocation={isTracking}
            loadingEnabled={true}
            loadingBackgroundColor={COLORS.background.primary}
            loadingIndicatorColor={COLORS.primary}
          >
            {/* Current Location Marker */}
            {currentLocation && (
              <Marker
                coordinate={{
                  latitude: currentLocation.latitude,
                  longitude: currentLocation.longitude,
                }}
                title="Current Location"
              >
                <View style={styles.currentLocationMarker}>
                  <Animated.View 
                    style={[
                      styles.pulseDot,
                      { 
                        transform: [{ scale: pulseAnim }],
                      },
                    ]} 
                  />
                  <View style={styles.locationDot} />
                </View>
              </Marker>
            )}

            {/* Path Polyline */}
            {pathPoints.length > 1 && (
              <>
                <Polyline
                  coordinates={pathPoints}
                  strokeColor={COLORS.primary}
                  strokeWidth={3}
                  lineCap="round"
                  lineJoin="round"
                />
                <Polyline
                  coordinates={pathPoints}
                  strokeColor="rgba(0, 136, 255, 0.1)"
                  strokeWidth={8}
                  lineCap="round"
                  lineJoin="round"
                />
              </>
            )}
          </MapView>
        </View>

        {/* Enhanced Control Buttons */}
        <View style={styles.controlsContainer}>
          <TouchableOpacity
            style={styles.primaryButton}
            onPress={GeotrackingService.isCurrentlyTracking() ? handleStopTracking : handleStartTracking}
            activeOpacity={0.8}
          >
            <LinearGradient
              colors={GeotrackingService.isCurrentlyTracking() ? ['#FF6B6B', '#FF8E8E'] : ['#00FF88', '#00CC6A']}
              style={styles.buttonGradient}
            >
              <Ionicons 
                name={GeotrackingService.isCurrentlyTracking() ? "stop" : "play"} 
                size={24} 
                color="white" 
                style={styles.buttonIcon} 
              />
              <Text style={styles.buttonText}>
                {GeotrackingService.isCurrentlyTracking() ? 'STOP TRACKING' : 'START TRACKING'}
              </Text>
            </LinearGradient>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.secondaryButton}
            onPress={() => setShowPurposeModal(true)}
            activeOpacity={0.8}
          >
            <LinearGradient
              colors={['rgba(255,255,255,0.1)', 'rgba(255,255,255,0.05)']}
              style={styles.buttonGradient}
            >
              <MaterialIcons name="flag" size={20} color={COLORS.text.primary} />
              <Text style={styles.secondaryButtonText}>
                {trackingPurpose.replace('_', ' ').toUpperCase()}
              </Text>
            </LinearGradient>
          </TouchableOpacity>
        </View>
      </Animated.View>

      {/* Purpose Selection Modal */}
      {showPurposeModal && (
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Select Tracking Purpose</Text>
            <Text style={styles.modalSubtitle}>Choose what you're tracking today</Text>
            
            {[
              { key: 'field_work', label: 'Field Work', icon: 'work' as const, desc: 'General field activities' },
              { key: 'delivery', label: 'Delivery', icon: 'local-shipping' as const, desc: 'Book deliveries' },
              { key: 'survey', label: 'Survey', icon: 'assignment' as const, desc: 'Survey collection' },
              { key: 'general', label: 'General', icon: 'directions-walk' as const, desc: 'Other activities' },
            ].map((purpose) => (
              <TouchableOpacity
                key={purpose.key}
                style={[
                  styles.purposeOption,
                  trackingPurpose === purpose.key && styles.purposeOptionSelected
                ]}
                onPress={() => {
                  setTrackingPurpose(purpose.key as TrackingSession['purpose']);
                  startEnhancedTracking(purpose.key as TrackingSession['purpose']);
                }}
              >
                <MaterialIcons 
                  name={purpose.icon} 
                  size={24} 
                  color={trackingPurpose === purpose.key ? COLORS.primary : COLORS.text.secondary} 
                />
                <View style={styles.purposeText}>
                  <Text style={[
                    styles.purposeLabel,
                    trackingPurpose === purpose.key && styles.purposeLabelSelected
                  ]}>
                    {purpose.label}
                  </Text>
                  <Text style={styles.purposeDesc}>{purpose.desc}</Text>
                </View>
                {trackingPurpose === purpose.key && (
                  <MaterialIcons name="check-circle" size={24} color={COLORS.primary} />
                )}
              </TouchableOpacity>
            ))}
            
            <TouchableOpacity
              style={styles.cancelButton}
              onPress={() => setShowPurposeModal(false)}
            >
              <Text style={styles.cancelButtonText}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}

      {/* Bottom Navigation */}
      <View style={styles.bottomNav}>
        <TouchableOpacity
          style={styles.navButton}
          onPress={() => navigation.navigate('Map')}
        >
          <Text style={styles.navButtonText}>🗺️ MAP</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.navButton}
          onPress={() => navigation.navigate('PathHistory')}
        >
          <Text style={styles.navButtonText}>📊 HISTORY</Text>
        </TouchableOpacity>

        {user?.role === 'admin' && (
          <TouchableOpacity
            style={styles.navButton}
            onPress={() => navigation.navigate('AdminLiveTracking')}
          >
            <Text style={styles.navButtonText}>👥 LIVE</Text>
          </TouchableOpacity>
        )}

        <TouchableOpacity
          style={styles.navButton}
          onPress={() => navigation.goBack()}
        >
          <Text style={styles.navButtonText}>🏠 HOME</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0F0C29',
  },
  backgroundGradient: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
  },
  orbContainer: {
    position: 'absolute',
    width: '100%',
    height: '100%',
  },
  orb1: {
    position: 'absolute',
    width: 200,
    height: 200,
    borderRadius: 100,
    backgroundColor: 'rgba(0,255,136,0.1)',
    top: height * 0.1,
    right: -50,
    shadowColor: '#00FF88',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
  },
  orb2: {
    position: 'absolute',
    width: 150,
    height: 150,
    borderRadius: 75,
    backgroundColor: 'rgba(64,224,255,0.1)',
    bottom: height * 0.2,
    left: -30,
    shadowColor: '#40E0FF',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.3,
    shadowRadius: 15,
  },
  header: {
    paddingTop: Platform.OS === 'ios' ? 60 : 40,
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  glassmorphismCard: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
    elevation: 10,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#FFFFFF',
    textAlign: 'center',
    marginBottom: 5,
  },
  headerSubtitle: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.7)',
    textAlign: 'center',
  },
  mainContent: {
    flex: 1,
    paddingHorizontal: 20,
  },
  statusCard: {
    marginBottom: 20,
  },
  statusHeader: {
    alignItems: 'center',
    marginBottom: 15,
  },
  statusIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  trackingDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 10,
    shadowColor: '#00FF88',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 10,
  },
  statusText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
    letterSpacing: 1,
  },
  locationInfo: {
    alignItems: 'center',
  },
  coordinatesText: {
    fontSize: 18,
    fontWeight: '500',
    color: '#00FF88',
    marginBottom: 5,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  accuracyText: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.6)',
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 30,
  },
  statCard: {
    flex: 1,
    marginHorizontal: 5,
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FFFFFF',
    textAlign: 'center',
    marginBottom: 5,
  },
  statLabel: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.6)',
    textAlign: 'center',
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  controlsContainer: {
    marginBottom: 30,
  },
  primaryButton: {
    marginBottom: 15,
    borderRadius: 25,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 5 },
    shadowOpacity: 0.3,
    shadowRadius: 10,
    elevation: 5,
  },
  secondaryButton: {
    borderRadius: 25,
    overflow: 'hidden',
  },
  buttonGradient: {
    paddingVertical: 18,
    paddingHorizontal: 30,
    alignItems: 'center',
  },
  buttonText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
    letterSpacing: 1,
  },
  secondaryButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
    letterSpacing: 1,
  },
  bottomNav: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: 20,
    paddingHorizontal: 20,
    backgroundColor: 'rgba(0,0,0,0.3)',
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.1)',
  },
  navButton: {
    alignItems: 'center',
    paddingVertical: 10,
    paddingHorizontal: 15,
  },
  statSubLabel: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    marginTop: 4,
  },
  todaySummary: {
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginVertical: SPACING.md,
  },
  summaryTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  summaryStats: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  summaryItem: {
    alignItems: 'center',
    flex: 1,
  },
  summaryValue: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginTop: SPACING.xs,
  },
  summaryLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  mapContainer: {
    height: 250,
    borderRadius: RADIUS.lg,
    overflow: 'hidden',
    marginVertical: SPACING.md,
  },
  mapTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
    paddingHorizontal: SPACING.md,
  },
  map: {
    flex: 1,
    borderRadius: RADIUS.lg,
  },
  currentLocationMarker: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  locationDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: COLORS.primary,
    position: 'absolute',
  },
  pulseRing: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: COLORS.primary,
    backgroundColor: 'transparent',
    position: 'absolute',
  },
  buttonIcon: {
    marginRight: SPACING.sm,
  },
  // Modal styles
  modalOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000,
  },
  modalContent: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.xl,
    width: width * 0.9,
    maxWidth: 400,
  },
  modalTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  modalSubtitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginBottom: SPACING.lg,
    textAlign: 'center',
  },
  purposeOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    marginBottom: SPACING.sm,
  },
  purposeOptionSelected: {
    borderColor: COLORS.primary,
    backgroundColor: 'rgba(0,136,255,0.1)',
  },
  purposeText: {
    flex: 1,
    marginLeft: SPACING.md,
  },
  purposeLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  purposeLabelSelected: {
    color: COLORS.primary,
  },
  purposeDesc: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  cancelButton: {
    alignItems: 'center',
    padding: SPACING.md,
    marginTop: SPACING.md,
  },
  cancelButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  navButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  pulseDot: {
    position: 'absolute',
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: 'rgba(0, 255, 136, 0.3)',
  },
});

export default LocationTrackingScreen;
