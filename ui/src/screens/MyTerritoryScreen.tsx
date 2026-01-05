import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Platform,
  Alert,
  Animated,
} from 'react-native';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { territoryService, Territory as TerritoryType } from '../services/TerritoryService';
import { realtimeLocationService } from '../services/RealtimeLocationService';
import { DeliveryService } from '../services/DeliveryService';
import { BookDelivery } from '../types/ministry';
import { ProfileService } from '../services/ProfileService';
import TerritoryMap from '../components/TerritoryMap';
import MinistryTrackingButton from '../components/MinistryTrackingButton';
import UserProfileHeader from '../components/UserProfileHeader';
import ActionButtonsPanel from '../components/ActionButtonsPanel';
import ModernBottomNavigation from '../components/ModernBottomNavigation';
import { WalkieTalkiePanel } from '../components/walkie-talkie';

// Use Territory type from TerritoryService
type Territory = TerritoryType;

interface MyTerritoryScreenProps {
  navigation: any;
}

export default function MyTerritoryScreen({ navigation }: MyTerritoryScreenProps) {
  const { user } = useAuth();
  const location = useLocation();
  const {
    isTracking: contextIsTracking,
    startTracking,
    stopTracking,
    requestPermission,
    currentLocation: locationContextLocation,
    locationPermission,
    getSessionPath
  } = location;
  const [myTerritory, setMyTerritory] = useState<Territory | null>(null);
  const [assignedTerritories, setAssignedTerritories] = useState<Territory[]>([]);
  const [selectedTerritoryId, setSelectedTerritoryId] = useState<string | null>(null);
  const [currentLocation, setCurrentLocation] = useState<{lat: number, lng: number} | null>(null);
  const [isInsideTerritory, setIsInsideTerritory] = useState<boolean>(true);
  const [mapReady, setMapReady] = useState(false);
  const [territoryStatus, setTerritoryStatus] = useState<any>(null);
  const [isTracking, setIsTracking] = useState(false);
  const [loading, setLoading] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const [locationAccuracy, setLocationAccuracy] = useState<number | null>(null);
  const [shouldCenterOnWorker, setShouldCenterOnWorker] = useState(false);

  // ActionButtonsPanel visibility state and animation
  const [isActionPanelVisible, setIsActionPanelVisible] = useState(true);
  const actionPanelAnim = useState(new Animated.Value(0))[0]; // 0 = visible, 1 = hidden

  // Delivery state
  const [deliveries, setDeliveries] = useState<BookDelivery[]>([]);
  const [showDeliveries, setShowDeliveries] = useState(true);
  const [selectedDelivery, setSelectedDelivery] = useState<BookDelivery | null>(null);

  // Use LocationContext tracking state as the source of truth for ministry tracking
  const isMinistryTracking = contextIsTracking;
  const [bottomNavActiveTab, setBottomNavActiveTab] = useState('territory');

  // Profile photo state
  const [profilePhotoUrl, setProfilePhotoUrl] = useState<string | null>(null);

  // Load user's profile photo
  const loadProfilePhoto = async () => {
    if (!user?.uid) return;

    try {
      const profileData = await ProfileService.getUserProfile(user.uid);
      if (profileData?.profilePhotoUrl) {
        setProfilePhotoUrl(profileData.profilePhotoUrl);
      }
    } catch (error) {
      console.log('Error loading profile photo:', error);
    }
  };

  // Load worker's delivery history
  const loadWorkerDeliveries = async () => {
    if (!user) return;

    try {
      const workerDeliveries = await DeliveryService.getWorkerDeliveries(user.uid);
      setDeliveries(workerDeliveries);
      console.log('📦 Loaded worker deliveries:', workerDeliveries.length);
    } catch (error) {
      console.error('Error loading worker deliveries:', error);
    }
  };

  useEffect(() => {
    if (!user) return;

    // Set loading state
    setLoading(true);

    // Load data efficiently - critical first, then parallel secondary
    const loadData = async () => {
      try {
        // Load critical territory data first (this shows the map)
        await fetchMyTerritory();
        
        // Turn off loading immediately after critical data loads
        setLoading(false);
        
        // Load secondary data in parallel (non-blocking)
        loadWorkerDeliveries().catch(err => console.warn('Deliveries load failed:', err));
        loadProfilePhoto().catch(err => console.warn('Profile photo load failed:', err));
        
        // Start location tracking (may not return promise)
        try {
          startLocationTracking();
        } catch (err) {
          console.warn('Location tracking failed:', err);
        }
        
      } catch (error) {
        console.error('Error loading critical territory data:', error);
        setLoading(false);
      }
    };

    loadData();

    // Listen to real-time territory status
    const unsubscribe = territoryService.listenToWorkerTerritoryStatus(
      user.uid,
      (status) => {
        setTerritoryStatus(status);
        if (status) {
          setIsInsideTerritory(status.isInside);
        }
      }
    );

    return () => unsubscribe();
  }, [user?.uid]); // Only depend on user.uid, not entire user object

  // Profile photo is now loaded in the main useEffect above

  useEffect(() => {
    // Listen for messages from iframe
    const handleMessage = (event: MessageEvent) => {
      if (event.data.type === 'mapReady') {
        handleMapReady();
      } else if (event.data.type === 'locationUpdate') {
        setCurrentLocation(event.data.location);
        checkTerritoryBounds(event.data.location);
      } else if (event.data.type === 'toggleActionPanel') {
        toggleActionPanel();
      }
    };

    if (Platform.OS === 'web') {
      window.addEventListener('message', handleMessage);
      return () => {
        window.removeEventListener('message', handleMessage);
      };
    }
  }, [myTerritory]);

  // Draw territory on map when territory data or map readiness changes
  useEffect(() => {
    if (mapReady && myTerritory) {
      console.log('🗺️ Drawing territory on map:', myTerritory.name);
      setTimeout(() => {
        drawTerritoryOnMap(myTerritory);
      }, 100); // Small delay to ensure iframe is ready
    }
  }, [mapReady, myTerritory]);

  // REMOVED: Duplicate location update effect
  // Location updates are now handled directly in the Firebase listener above
  // This prevents conflicts and ensures single source of truth

  // Add focus listener to refresh data when screen comes into focus
  useEffect(() => {
    const unsubscribe = navigation.addListener('focus', () => {
      console.log('🔍 MyTerritory screen focused - refreshing data');
      if (user) {
        fetchMyTerritory();
      }
    });

    return unsubscribe;
  }, [navigation, user]);

  // PRIMARY LOCATION SOURCE: Use LocationContext for real GPS data
  // This ensures we get actual device GPS coordinates, not mock/default data
  useEffect(() => {
    if (locationContextLocation) {
      const realGPSLocation = {
        lat: locationContextLocation.latitude,
        lng: locationContextLocation.longitude,
      };

      console.log('📍 REAL GPS LOCATION from LocationContext:', {
        source: 'Device GPS (LocationContext)',
        coordinates: `${realGPSLocation.lat.toFixed(6)}, ${realGPSLocation.lng.toFixed(6)}`,
        accuracy: locationContextLocation.accuracy,
        timestamp: new Date(locationContextLocation.timestamp).toLocaleTimeString(),
        isIndia: realGPSLocation.lat > 6 && realGPSLocation.lat < 38 && realGPSLocation.lng > 68 && realGPSLocation.lng < 98
      });

      // Update worker's map location with REAL GPS data
      setCurrentLocation(realGPSLocation);
      setLocationAccuracy(locationContextLocation.accuracy || null);

      // Update territory bounds check
      checkTerritoryBounds(realGPSLocation);

      // Update map if ready
      if (mapReady) {
        updateWorkerLocationOnMap(realGPSLocation, locationContextLocation.accuracy);
      }
    } else {
      console.log('⚠️ No real GPS location from LocationContext');
    }
  }, [locationContextLocation, mapReady]);

  // SEPARATE EFFECT: Handle centering only when explicitly requested
  useEffect(() => {
    if (shouldCenterOnWorker && currentLocation && mapReady) {
      centerMapOnWorker(currentLocation);
      setShouldCenterOnWorker(false);
      console.log('🎯 Map centered on worker location (user requested)');
    }
  }, [shouldCenterOnWorker, currentLocation, mapReady]);

  // SECONDARY: Firebase listener for admin dashboard sync (but prioritize real GPS)
  useEffect(() => {
    if (user) {
      console.log('🔄 Setting up Firebase location listener for admin sync:', user.uid);

      const unsubscribe = realtimeLocationService.listenToWorker(user.uid, (workerData) => {
        if (workerData && workerData.currentLocation) {
          console.log('📡 Firebase location data (for admin sync):', {
            coordinates: `${workerData.currentLocation.latitude.toFixed(6)}, ${workerData.currentLocation.longitude.toFixed(6)}`,
            timestamp: new Date(workerData.currentLocation.timestamp).toLocaleTimeString()
          });

          // Only use backend data if we don't have real GPS data from LocationContext
          if (!locationContextLocation) {
            console.log('📡 Using backend location as fallback');
            const backendLocation = {
              lat: workerData.currentLocation.latitude,
              lng: workerData.currentLocation.longitude,
            };
            setCurrentLocation(backendLocation);
            setLocationAccuracy(workerData.currentLocation.accuracy || null);
          }
        }
      });

      return () => unsubscribe();
    }
  }, [user, locationContextLocation]);

  const handleBottomNavPress = (tab: string) => {
    setBottomNavActiveTab(tab);

    // Navigate to different screens based on tab
    switch (tab) {
      case 'home':
        navigation.navigate('WorkerDashboard');
        break;
      case 'territory':
        // Already on territory screen
        break;
      case 'community':
        navigation.navigate('Community');
        break;
      case 'analytics':
        navigation.navigate('WorkerAnalytics');
        break;
      default:
        break;
    }
  };

  const handleStartMinistry = async () => {
    try {
      console.log('🚀 Starting ministry tracking...');
      setIsLoading(true);

      // Request location permission first
      const hasPermission = await requestPermission();
      if (!hasPermission) {
        setIsLoading(false);
        Alert.alert(
          'Location Permission Required',
          'Please allow location access to start ministry tracking.',
          [{ text: 'OK' }]
        );
        return;
      }

      // Start location tracking (non-blocking)
      startTracking()
        .then(() => {
          console.log('✅ Ministry tracking started successfully');
          // Optional: Show subtle success feedback instead of alert
        })
        .catch((error) => {
          console.error('❌ Ministry tracking start error:', error);
          Alert.alert(
            'Error Starting Ministry',
            error.message || 'Failed to start ministry tracking. Please try again.',
            [{ text: 'OK' }]
          );
        });

      // Set loading to false immediately for responsive UI
      setIsLoading(false);

    } catch (error: any) {
      console.error('❌ Ministry tracking start error:', error);
      setIsLoading(false);
      Alert.alert(
        'Error Starting Ministry',
        error.message || 'Failed to start ministry tracking. Please try again.',
        [{ text: 'OK' }]
      );
    }
  };

  const handleStopMinistry = async () => {
    try {
      console.log('🛑 STOP MINISTRY BUTTON CLICKED - Starting stop process...');
      console.log('🔍 Current tracking state before stop:', {
        contextIsTracking,
        isMinistryTracking,
        isLoading
      });
      setIsLoading(true);

      // Stop location tracking (non-blocking)
      stopTracking()
        .then(() => {
          console.log('✅ Ministry tracking stopped successfully');
          // Optional: Show subtle success feedback instead of alert
        })
        .catch((error) => {
          console.error('❌ Ministry tracking stop error:', error);
          Alert.alert(
            'Error Stopping Ministry',
            error.message || 'Failed to stop ministry tracking. Please try again.',
            [{ text: 'OK' }]
          );
        });

      // Set loading to false immediately for responsive UI
      setIsLoading(false);

    } catch (error: any) {
      console.error('❌ Ministry tracking stop error:', error);
      setIsLoading(false);
      Alert.alert(
        'Error Stopping Ministry',
        error.message || 'Failed to stop ministry tracking. Please try again.',
        [{ text: 'OK' }]
      );
    }
  };

  const handleTeamMessage = async () => {
    try {
      console.log('💬 Team Message pressed');

      if (!user) {
        Alert.alert('Error', 'Please log in to access team messaging.');
        return;
      }

      // Navigate to team-scoped messaging screen
      navigation.navigate('Messaging');
    } catch (error) {
      console.error('❌ Error opening team messages:', error);
      Alert.alert(
        'Error',
        'Failed to open team messages. Please try again.',
        [{ text: 'OK' }]
      );
    }
  };

  const fetchMyTerritory = async () => {
    if (!user) return;

    try {
      setLoading(true);
      console.log('🔍 Loading territories for worker:', user.email);

      // Try to get territory by user ID first, then by email
      let territory = null;

      try {
        // First try with user UID
        territory = await territoryService.getWorkerTerritory(user.uid);
      } catch (error) {
        console.log('⚠️ No territory found by UID, trying email...');
      }

      // If no territory found by UID, try to get territories by email (much faster)
      if (!territory) {
        const territoriesByEmail = await territoryService.getWorkerTerritoriesByEmail(user.email);

        if (territoriesByEmail.length > 0) {
          territory = territoriesByEmail[0];
          setAssignedTerritories(territoriesByEmail);
        }
      }

      if (territory) {
        console.log(`✅ Found assigned territory: ${territory.name}`);
        setMyTerritory(territory);
        setSelectedTerritoryId(territory.id);
        // Only set assigned territories if not already set
        if (assignedTerritories.length === 0) {
          setAssignedTerritories([territory]);
        }
      } else {
        console.log('⚠️ No territories assigned to worker:', user.email);
        setMyTerritory(null);
        setAssignedTerritories([]);
      }
    } catch (error) {
      console.error('❌ Error fetching territories:', error);
      setMyTerritory(null);
      setAssignedTerritories([]);
    } finally {
      setLoading(false);
    }
  };

  // REMOVED: Manual GPS tracking to prevent conflicts with Firebase location source
  // Location tracking is now handled by LocationContext and RealtimeLocationService
  // This ensures the worker's map shows the exact same coordinates as the admin dashboard
  const startLocationTracking = () => {
    if (!user) return;

    console.log('📍 Location tracking delegated to LocationContext and Firebase');
    console.log('📍 Worker map will use same location source as admin dashboard');

    // The actual location tracking is handled by:
    // 1. LocationContext - for GPS data collection
    // 2. RealtimeLocationService - for Firebase storage and real-time updates
    // 3. Firebase listener above - for displaying location on worker's map

    setIsTracking(true);
  };

  const checkTerritoryBounds = (location: {lat: number, lng: number}) => {
    if (!myTerritory) return;

    const isInside = isPointInPolygon(location, myTerritory.coordinates);
    
    if (isInside !== isInsideTerritory) {
      setIsInsideTerritory(isInside);
      
      if (!isInside) {
        Alert.alert(
          '⚠️ Territory Boundary',
          'You have moved outside your assigned territory area.',
          [{ text: 'OK' }]
        );
        
        // Optionally notify admin
        console.log('🚨 Worker outside territory:', user?.displayName);
      }
    }
  };

  const isPointInPolygon = (point: {lat: number, lng: number}, polygon: Array<{lat: number, lng: number}>): boolean => {
    const x = point.lat;
    const y = point.lng;
    let inside = false;

    for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      const xi = polygon[i].lat;
      const yi = polygon[i].lng;
      const xj = polygon[j].lat;
      const yj = polygon[j].lng;

      if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }

    return inside;
  };

  const handleMapReady = () => {
    console.log('🗺️ Worker territory map is ready');
    setMapReady(true);

    // Load territory on map with a small delay to ensure iframe is fully ready
    setTimeout(() => {
      if (myTerritory) {
        console.log('🗺️ Drawing territory after map ready:', myTerritory.name);
        drawTerritoryOnMap(myTerritory);
      }

      // Show current location if available
      if (currentLocation) {
        console.log('📍 Updating location after map ready');
        updateWorkerLocationOnMap(currentLocation);
      }
    }, 200);
  };

  const drawTerritoryOnMap = (territory: Territory) => {
    if (Platform.OS === 'web' && mapReady) {
      const iframe = document.getElementById('territory-worker-map-iframe') as HTMLIFrameElement;
      if (iframe && iframe.contentWindow) {
        iframe.contentWindow.postMessage({
          type: 'drawTerritory',
          territory: territory
        }, '*');
      }
    }
  };

  const updateWorkerLocationOnMap = (location: {lat: number, lng: number}, accuracy?: number) => {
    if (Platform.OS === 'web' && mapReady) {
      const iframe = document.getElementById('territory-worker-map-iframe') as HTMLIFrameElement;
      if (iframe && iframe.contentWindow) {
        iframe.contentWindow.postMessage({
          type: 'updateWorkerLocation',
          location: location,
          accuracy: accuracy,
          isInsideTerritory: isInsideTerritory,
          workerName: user?.displayName || user?.email || 'Worker'
        }, '*');
      }
    }
  };

  const centerMapOnWorker = (location: {lat: number, lng: number}) => {
    if (Platform.OS === 'web' && mapReady) {
      const iframe = document.getElementById('territory-worker-map-iframe') as HTMLIFrameElement;
      if (iframe && iframe.contentWindow) {
        iframe.contentWindow.postMessage({
          type: 'centerOnWorker',
          location: location
        }, '*');
      }
    }
  };

  // Toggle ActionButtonsPanel visibility
  const toggleActionPanel = () => {
    const toValue = isActionPanelVisible ? 1 : 0; // 1 = hidden, 0 = visible
    setIsActionPanelVisible(!isActionPanelVisible);

    Animated.spring(actionPanelAnim, {
      toValue,
      useNativeDriver: true,
      tension: 100,
      friction: 8,
    }).start();

    console.log(`🎛️ Action panel ${isActionPanelVisible ? 'hidden' : 'shown'}`);
  };

  // Handle delivery marker press
  const handleDeliveryPress = (delivery: BookDelivery) => {
    setSelectedDelivery(delivery);
    Alert.alert(
      'Delivery Details',
      `Book: ${delivery.bookTitle}\nTime: ${delivery.deliveryTime.toLocaleString()}\nMethod: ${delivery.deliveryType === 'door' ? 'Door-to-door' : 'Person-to-person'}${delivery.recipientName ? `\nRecipient: ${delivery.recipientName}` : ''}${delivery.notes ? `\nNotes: ${delivery.notes}` : ''}`,
      [{ text: 'OK' }]
    );
  };

  // Handle delivery logged from ActionButtonsPanel
  const handleDeliveryLogged = (delivery: BookDelivery) => {
    setDeliveries(prev => [delivery, ...prev]);
    loadWorkerDeliveries(); // Refresh deliveries from server
    console.log('📦 New delivery logged:', delivery.bookTitle);
  };

  const getMapHTML = () => ` 
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>My Territory Map</title>
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <style>
            body { margin: 0; padding: 0; }

                // Add tile layer
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '© OpenStreetMap contributors'
                }).addTo(map);

                console.log('✅ Worker territory map initialized');

                // Add map click handler for ActionButtonsPanel toggle
                map.on('click', function(e) {
                    // Only toggle if click is on empty space (not on markers or popups)
                    if (e.originalEvent.target.tagName === 'DIV' &&
                        e.originalEvent.target.className.includes('leaflet-container')) {
                        console.log('🗺️ Empty map space clicked - toggling action panel');
                        window.parent.postMessage({
                            type: 'toggleActionPanel'
                        }, '*');
                    }
                });

                // Notify parent that map is ready
                window.parent.postMessage({
                    type: 'mapReady'
                }, '*');
            }

            // Draw territory on map
            function drawTerritory(territory) {
                console.log('🗺️ Drawing territory:', territory.name);
                
                const coordinates = territory.coordinates.map(coord => [coord.lat, coord.lng]);
                
                territoryPolygon = L.polygon(coordinates, {
                    color: '#002b5b',
                    weight: 3,
                    opacity: 0.9,
                    fillOpacity: 0.15,
                    fillColor: '#d7a638'
                }).addTo(map);

                // Add popup with territory info
                const popupContent = \`
                    <div class="territory-popup">
                        <div class="territory-popup-name">📍 \${territory.name}</div>
                        <div style="font-size: 12px; color: #64748b;">Your assigned territory</div>
                    </div>
                \`;
                
                territoryPolygon.bindPopup(popupContent);
                
                // Fit map to territory bounds
                map.fitBounds(territoryPolygon.getBounds(), { padding: [20, 20] });
            }

            // Enhanced worker location update with accuracy circle
            function updateWorkerLocation(data) {
                const location = data.location;
                const accuracy = data.accuracy;
                const isInsideTerritory = data.isInsideTerritory;
                const workerName = data.workerName || 'Worker';

                // DEBUGGING: Log coordinates received by web map
                console.log('🗺️ Web map received location update:', {
                    coordinates: \`\${location.lat.toFixed(6)}, \${location.lng.toFixed(6)}\`,
                    accuracy: accuracy,
                    isInsideTerritory: isInsideTerritory,
                    workerName: workerName,
                    source: 'Worker Territory Map Web View'
                });

                // Remove existing marker and accuracy circle
                if (workerMarker) {
                    map.removeLayer(workerMarker);
                }
                if (accuracyCircle) {
                    map.removeLayer(accuracyCircle);
                }

                // Add accuracy circle if accuracy data is available
                if (accuracy && accuracy > 0) {
                    accuracyCircle = L.circle([location.lat, location.lng], {
                        radius: accuracy,
                        color: isInsideTerritory ? '#10b981' : '#f59e0b',
                        weight: 2,
                        opacity: 0.6,
                        fillOpacity: 0.1,
                        fillColor: isInsideTerritory ? '#10b981' : '#f59e0b'
                    }).addTo(map);
                }

                // Enhanced worker marker with status-based styling
                const markerColor = isInsideTerritory ? '#10b981' : '#f59e0b';
                const borderColor = isInsideTerritory ? '#065f46' : '#d97706';
                const pulseColor = isInsideTerritory ? '#10b981' : '#f59e0b';

                workerMarker = L.marker([location.lat, location.lng], {
                    icon: L.divIcon({
                        className: 'professional-worker-marker',
                        html: \`
                            <div style="
                                position: relative;
                                width: 36px;
                                height: 36px;
                            ">
                                <!-- Main marker -->
                                <div style="
                                    background: linear-gradient(135deg, \${markerColor} 0%, \${markerColor}dd 100%);
                                    width: 36px;
                                    height: 36px;
                                    border-radius: 50%;
                                    border: 3px solid \${borderColor};
                                    box-shadow: 0 4px 12px rgba(0,0,0,0.4), 0 2px 4px rgba(0,0,0,0.2);
                                    position: relative;
                                    z-index: 2;
                                    display: flex;
                                    align-items: center;
                                    justify-content: center;
                                    backdrop-filter: blur(1px);
                                ">
                                    <!-- Professional person SVG icon -->
                                    <svg width="18" height="18" viewBox="0 0 24 24" fill="white" style="filter: drop-shadow(0 1px 2px rgba(0,0,0,0.3));">
                                        <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                                    </svg>
                                </div>

                                <!-- Status indicator -->
                                <div style="
                                    position: absolute;
                                    top: -2px;
                                    right: -2px;
                                    width: 12px;
                                    height: 12px;
                                    background: \${isInsideTerritory ? '#10b981' : '#f59e0b'};
                                    border: 2px solid white;
                                    border-radius: 50%;
                                    box-shadow: 0 1px 3px rgba(0,0,0,0.3);
                                    z-index: 3;
                                "></div>

                                <!-- Enhanced pulsing ring -->
                                <div style="
                                    position: absolute;
                                    top: 50%;
                                    left: 50%;
                                    transform: translate(-50%, -50%);
                                    width: 50px;
                                    height: 50px;
                                    border: 2px solid \${pulseColor};
                                    border-radius: 50%;
                                    opacity: 0.6;
                                    animation: workerPulse 2s infinite;
                                    z-index: 1;
                                "></div>
                            </div>

                            <style>
                                @keyframes workerPulse {
                                    0% {
                                        transform: translate(-50%, -50%) scale(0.8);
                                        opacity: 0.8;
                                        border-width: 2px;
                                    }
                                    50% {
                                        transform: translate(-50%, -50%) scale(1.3);
                                        opacity: 0.3;
                                        border-width: 1px;
                                    }
                                    100% {
                                        transform: translate(-50%, -50%) scale(0.8);
                                        opacity: 0.8;
                                        border-width: 2px;
                                    }
                                }
                            </style>
                        \`,
                        iconSize: [44, 44],
                        iconAnchor: [22, 22]
                    })
                }).addTo(map);

                // Enhanced popup with detailed information
                const statusText = isInsideTerritory ?
                    '<span style="color: #10b981; font-weight: bold;">✅ Inside Territory</span>' :
                    '<span style="color: #f59e0b; font-weight: bold;">⚠️ Outside Territory</span>';

                const accuracyText = accuracy ?
                    \`<div style="font-size: 11px; color: #64748b; margin-top: 4px;">📍 Accuracy: ±\${Math.round(accuracy)}m</div>\` :
                    '';

                const popupContent = \`
                    <div style="text-align: center; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
                        <div style="font-weight: bold; color: #002b5b; margin-bottom: 6px; font-size: 14px;">
                            👤 \${workerName}
                        </div>
                        <div style="margin-bottom: 4px;">
                            \${statusText}
                        </div>
                        <div style="font-size: 11px; color: #64748b;">
                            📍 Live GPS Position
                        </div>
                        \${accuracyText}
                        <div style="font-size: 10px; color: #94a3b8; margin-top: 4px;">
                            \${location.lat.toFixed(6)}, \${location.lng.toFixed(6)}
                        </div>
                    </div>
                \`;

                workerMarker.bindPopup(popupContent);
            }

            // Center map on worker location
            function centerOnWorker(data) {
                const location = data.location;
                map.setView([location.lat, location.lng], 16, {
                    animate: true,
                    duration: 1.0
                });
            }

            // Listen for messages from React Native
            window.addEventListener('message', function(event) {
                if (event.data.type === 'drawTerritory') {
                    drawTerritory(event.data.territory);
                } else if (event.data.type === 'updateWorkerLocation') {
                    updateWorkerLocation(event.data);
                } else if (event.data.type === 'centerOnWorker') {
                    centerOnWorker(event.data);
                }
            });

            // Initialize map when page loads
            document.addEventListener('DOMContentLoaded', initMap);
        </script>
    </body>
    </html>
  `;

  // Show loading screen while data is loading
  if (loading) {
    return (
      <View style={[styles.container, styles.loadingContainer]}>
        <View style={styles.loadingContent}>
          <MaterialIcons name="location-on" size={48} color="#002b5b" />
          <Text style={styles.loadingText}>Loading Territory...</Text>
          <Text style={styles.loadingSubtext}>Please wait while we load your ministry data</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Full Screen Map Container */}
      <View style={styles.mapContainer}>
        {Platform.OS === 'web' ? (
          <iframe
            id="territory-worker-map-iframe"
            srcDoc={getMapHTML()}
            style={styles.mapIframe}
          />
        ) : (
          <TerritoryMap
            territories={assignedTerritories}
            selectedTerritory={myTerritory}
            currentLocation={currentLocation ? {
              latitude: currentLocation.lat,
              longitude: currentLocation.lng,
              accuracy: locationAccuracy || undefined,
            } : null}
            onTerritoryPress={(territory) => {
              setSelectedTerritoryId(territory.id);
              setMyTerritory(territory);
            }}
            onToggleActionPanel={toggleActionPanel}
            showUserLocation={isMinistryTracking}
            isInsideTerritory={isInsideTerritory}
            workerName={user?.displayName || user?.email || 'Worker'}
            centerOnWorker={shouldCenterOnWorker}
            deliveries={deliveries}
            showDeliveries={showDeliveries}
            onDeliveryPress={handleDeliveryPress}
            // Path visualization
            pathPoints={isMinistryTracking ? getSessionPath() : []}
            showPath={isMinistryTracking}
            pathColor="#002b5b"
            style={styles.mobileMap}
          />
        )}
      </View>

      {/* Fixed User Profile Header - Top 3% */}
      <UserProfileHeader
        userImage={profilePhotoUrl || undefined}
        userName={user?.displayName || user?.email?.split('@')[0] || 'Ministry Worker'}
        territoryName={myTerritory?.name || 'No Territory Assigned'}
        teamName={user?.teamName}
        isActive={isMinistryTracking}
        style={styles.fixedProfileHeader}
      />



      {/* Enhanced Center on Me Button */}
      {currentLocation && (
        <TouchableOpacity
          style={styles.centerLocationButton}
          onPress={() => {
            setShouldCenterOnWorker(true);
            if (Platform.OS === 'web' && mapReady) {
              centerMapOnWorker(currentLocation);
            }
            // Provide haptic feedback
            if (Platform.OS !== 'web') {
              // Add haptic feedback for mobile
              console.log('🎯 Centering map on worker location');
            }
          }}
          activeOpacity={0.7}
        >
          <View style={styles.centerButtonContent}>
            <Ionicons name="locate" size={20} color="#ffffff" />
            <Text style={styles.centerButtonText}>Me</Text>
          </View>
        </TouchableOpacity>
      )}

      {/* Action Buttons Panel - Above Bottom Navigation with slide animation */}
      <Animated.View
        style={[
          styles.actionButtonsPanel,
          {
            transform: [
              {
                translateY: actionPanelAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [0, 200], // Slide down 200px when hidden
                }),
              },
            ],
          },
        ]}
      >
        <ActionButtonsPanel
          // onBookDelivery handled internally by ComprehensiveDeliveryModal
          // onSurvey prop removed to enable internal bottom sheet functionality
          onStartMinistry={handleStartMinistry}
          onStopMinistry={handleStopMinistry}
          onTeamMessage={handleTeamMessage}
          isMinistryActive={isMinistryTracking}
          isLoading={isLoading}
          // hideMic removed to enable walkie talkie functionality
        />
      </Animated.View>

      {/* Walkie-Talkie Voice Listener - Placeholder */}
      {user && (
        <View style={{ position: 'absolute', bottom: 100, right: 20 }}>
          {/* New walkie-talkie system will be integrated here */}
        </View>
      )}

      {/* Bottom Navigation */}
      <View style={styles.bottomNavigationContainer}>
        <ModernBottomNavigation
          activeTab={bottomNavActiveTab}
          onTabPress={handleBottomNavPress}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },

  // Fixed Profile Header at top 3%
  fixedProfileHeader: {
    position: 'absolute',
    top: '3%',
    left: 16,
    right: 16,
    zIndex: 1000,
    elevation: 10,
  },

  // Full Screen Map
  mapContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    flex: 1,
  },

  mapIframe: {
    width: '100%',
    height: '100%',
    border: 'none',
  },

  mobileMap: {
    flex: 1,
  },

  // Fixed Ministry Tracking Button at bottom
  fixedTrackingButton: {
    position: 'absolute',
    bottom: 100,
    right: 20,
    zIndex: 1000,
    elevation: 10,
  },
  fixedProfileHeader: {
    position: 'absolute',
    top: '3%',
    left: 16,
    right: 16,
    zIndex: 1000,
    elevation: 10,
  },

  // Action Buttons Panel - Above Bottom Navigation
  actionButtonsPanel: {
    position: 'absolute',
    bottom: 140, // Above bottom navigation (increased to accommodate bottom nav)
    left: 0,
    right: 0,
    zIndex: 999,
    elevation: 9,
  },

  // Bottom Navigation Container
  bottomNavigationContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    zIndex: 998,
    elevation: 8,
    backgroundColor: 'transparent',
  },
  mapIframe: {
    width: '100%',
    height: '100%',
    border: 'none',
  },
  mobileMapPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f1f5f9',
  },
  mobileMapText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 8,
  },
  mobileMapSubtext: {
    fontSize: 14,
    color: '#64748b',
    textAlign: 'center',
  },

  // Center Location Button
  centerLocationButton: {
    position: 'absolute',
    top: 100,
    right: 16,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#002b5b',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    elevation: 8,
    borderWidth: 2,
    borderColor: '#ffffff',
    zIndex: 1000,
  },
  centerButtonContent: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  centerButtonText: {
    color: '#ffffff',
    fontSize: 10,
    fontWeight: '600',
    marginTop: 2,
    textAlign: 'center',
  },

  // Loading screen styles
  loadingContainer: {
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
  },
  loadingContent: {
    alignItems: 'center',
    padding: 32,
  },
  loadingText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#002b5b',
    marginTop: 16,
    marginBottom: 8,
  },
  loadingSubtext: {
    fontSize: 14,
    color: '#64748b',
    textAlign: 'center',
    lineHeight: 20,
  },
});
