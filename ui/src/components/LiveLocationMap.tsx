import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Platform, Alert, TouchableOpacity, ScrollView, StatusBar } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { realtimeLocationService } from '../services/RealtimeLocationService';
import { territoryService, Territory } from '../services/TerritoryService';
import { COLORS, SPACING, TYPOGRAPHY, RADIUS, SHADOWS } from '../constants/Colors';
import Header from './Header';

interface WorkerLocation {
  latitude: number;
  longitude: number;
  timestamp: number;
  accuracy?: number;
  speed?: number;
  heading?: number;
}

interface WorkerData {
  id: string;
  name: string;
  email: string;
  isActive: boolean;
  currentLocation?: WorkerLocation;
  lastSeen?: number;
}

interface LiveLocationMapProps {
  showControls?: boolean;
  height?: number;
  onWorkerSelect?: (worker: WorkerData) => void;
  selectedWorkerId?: string;
  onClose?: () => void;
  selectedWorker?: any;
}

const LiveLocationMap: React.FC<LiveLocationMapProps> = ({
  showControls = true,
  height = 400,
  onWorkerSelect,
  selectedWorkerId,
  onClose,
  selectedWorker
}) => {
  const [workers, setWorkers] = useState<WorkerData[]>([]);
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [mapReady, setMapReady] = useState(false);
  const [showTerritories, setShowTerritories] = useState(true);
  const mapRef = useRef<any>(null);
  const unsubscribeRef = useRef<(() => void) | null>(null);

  // Track previous worker states for incremental updates
  const previousWorkersRef = useRef<Map<string, WorkerData>>(new Map());
  const mapCenteredRef = useRef<boolean>(false);

  // Progressive status thresholds with grace periods
  const ACTIVE_THRESHOLD_MINUTES = 1; // 0-1 minutes: "Active" (blue pulsing)
  const RECENTLY_ACTIVE_THRESHOLD_MINUTES = 3; // 1-3 minutes: "Recently Active" (blue static)
  const OFFLINE_THRESHOLD_MINUTES = 10; // 3-10 minutes: "Offline" (grey)
  const HIDE_THRESHOLD_MINUTES = 30; // 10+ minutes: Hide completely
  const DEBUG_FILTERING = false; // Disable debug logging for production

  // Helper function to get location age in minutes
  const getLocationAgeMinutes = (worker: WorkerData): number => {
    if (!worker.currentLocation?.timestamp) return Infinity;

    const now = Date.now();
    const locationTime = worker.currentLocation.timestamp;
    return (now - locationTime) / (1000 * 60);
  };

  // Progressive worker status determination with grace periods
  const getWorkerProgressiveStatus = (worker: WorkerData): 'active' | 'recently-active' | 'offline' | 'hidden' => {
    if (!worker.currentLocation?.timestamp) {
      if (DEBUG_FILTERING) {
        console.log(`🚫 ${worker.name}: No location data → hidden`);
      }
      return 'hidden';
    }

    const ageMinutes = getLocationAgeMinutes(worker);
    const hasActiveFlag = worker.isActive;

    let status: 'active' | 'recently-active' | 'offline' | 'hidden';

    if (ageMinutes <= ACTIVE_THRESHOLD_MINUTES && hasActiveFlag) {
      status = 'active'; // Blue pulsing - live tracking
    } else if (ageMinutes <= RECENTLY_ACTIVE_THRESHOLD_MINUTES) {
      status = 'recently-active'; // Blue static - recently seen
    } else if (ageMinutes <= OFFLINE_THRESHOLD_MINUTES) {
      status = 'offline'; // Grey - offline but still visible
    } else if (ageMinutes <= HIDE_THRESHOLD_MINUTES) {
      status = 'offline'; // Still show as offline for grace period
    } else {
      status = 'hidden'; // Hide after extended period
    }

    if (DEBUG_FILTERING) {
      console.log(`📊 ${worker.name}: Age ${ageMinutes.toFixed(1)}min, isActive=${hasActiveFlag} → ${status}`);
    }

    return status;
  };

  // Helper function to check if worker location data is recent (legacy compatibility)
  const isLocationRecent = (worker: WorkerData, thresholdMinutes: number): boolean => {
    const ageMinutes = getLocationAgeMinutes(worker);
    return ageMinutes <= thresholdMinutes;
  };

  // Helper functions using progressive status system
  const isTrulyActive = (worker: WorkerData): boolean => {
    const status = getWorkerProgressiveStatus(worker);
    return status === 'active';
  };

  const isRecentlyActive = (worker: WorkerData): boolean => {
    const status = getWorkerProgressiveStatus(worker);
    return status === 'recently-active';
  };

  const isOffline = (worker: WorkerData): boolean => {
    const status = getWorkerProgressiveStatus(worker);
    return status === 'offline';
  };

  const shouldShowWorker = (worker: WorkerData): boolean => {
    const status = getWorkerProgressiveStatus(worker);
    return status !== 'hidden';
  };

  // Legacy compatibility function
  const getWorkerDisplayStatus = (worker: WorkerData): 'active' | 'inactive' | 'hidden' => {
    const progressiveStatus = getWorkerProgressiveStatus(worker);

    switch (progressiveStatus) {
      case 'active':
        return 'active';
      case 'recently-active':
      case 'offline':
        return 'inactive';
      case 'hidden':
      default:
        return 'hidden';
    }
  };

  useEffect(() => {
    console.log('LiveLocationMap: Initializing...');
    loadActiveWorkers();
    loadTerritories();

    return () => {
      if (unsubscribeRef.current) {
        console.log('LiveLocationMap: Cleaning up listeners...');
        unsubscribeRef.current();
      }
    };
  }, []);

  const loadTerritories = async () => {
    try {
      console.log('LiveLocationMap: Loading territories...');
      const allTerritories = await territoryService.getAllTerritoriesCached();
      console.log(`LiveLocationMap: Loaded ${allTerritories.length} territories`);
      setTerritories(allTerritories);

      // Update map with territories if ready
      if (mapReady && mapRef.current) {
        updateMapTerritories(allTerritories);
      }
    } catch (error) {
      console.error('LiveLocationMap: Error loading territories:', error);
      // Don't set error state for territories - just log and continue
    }
  };

  const loadActiveWorkers = async () => {
    try {
      setIsLoading(true);
      setError(null);
      
      console.log('LiveLocationMap: Loading active workers...');
      
      // Listen to all workers for real-time updates (every 1-2 seconds)
      const unsubscribe = realtimeLocationService.listenToAllWorkers((updatedWorkers) => {
        const updateTime = new Date().toLocaleTimeString();
        console.log('🗺️ LiveLocationMap: Real-time update received at:', updateTime);
        console.log('📊 Total workers:', updatedWorkers.length);

        // Add detailed debugging for flickering issue
        console.log(`\n🔄 === WORKER PROCESSING CYCLE START ===`);
        console.log(`📊 Total workers received: ${updatedWorkers.length}`);

        if (DEBUG_FILTERING && updatedWorkers.length > 0) {
          console.log(`📋 All workers data:`, updatedWorkers.map(w => ({
            name: w.name,
            isActive: w.isActive,
            hasLocation: !!w.currentLocation,
            timestamp: w.currentLocation?.timestamp,
            ageMinutes: w.currentLocation?.timestamp ? ((Date.now() - w.currentLocation.timestamp) / (1000 * 60)).toFixed(1) : 'N/A'
          })));
        }

        // Filter workers using progressive status system
        const activeWorkers = updatedWorkers.filter(w => isTrulyActive(w));
        const recentlyActiveWorkers = updatedWorkers.filter(w => isRecentlyActive(w));
        const offlineWorkers = updatedWorkers.filter(w => isOffline(w));
        const visibleWorkers = updatedWorkers.filter(w => shouldShowWorker(w));
        const hiddenWorkers = updatedWorkers.filter(w => !shouldShowWorker(w));

        console.log(`🟢 Active workers (live tracking): ${activeWorkers.length}`);
        console.log(`🔵 Recently active workers (grace period): ${recentlyActiveWorkers.length}`);
        console.log(`⚫ Offline workers (visible): ${offlineWorkers.length}`);
        console.log(`👁️ Total visible workers: ${visibleWorkers.length}`);
        console.log(`🚫 Hidden workers: ${hiddenWorkers.length}`);

        if (activeWorkers.length > 0) {
          console.log('📍 Active worker locations (live tracking):');
          activeWorkers.forEach((worker, index) => {
            const ageMinutes = getLocationAgeMinutes(worker);
            console.log(`  ${index + 1}. ${worker.name}: ${worker.currentLocation!.latitude.toFixed(6)}, ${worker.currentLocation!.longitude.toFixed(6)} (${ageMinutes.toFixed(1)}min ago) - LIVE`);
          });
        }

        if (recentlyActiveWorkers.length > 0) {
          console.log('🔵 Recently active workers (grace period):');
          recentlyActiveWorkers.forEach((worker, index) => {
            const ageMinutes = getLocationAgeMinutes(worker);
            console.log(`  ${index + 1}. ${worker.name}: ${worker.currentLocation!.latitude.toFixed(6)}, ${worker.currentLocation!.longitude.toFixed(6)} (${ageMinutes.toFixed(1)}min ago) - RECENT`);
          });
        }

        if (offlineWorkers.length > 0) {
          console.log('⚫ Offline workers (still visible):');
          offlineWorkers.forEach((worker, index) => {
            const ageMinutes = getLocationAgeMinutes(worker);
            console.log(`  ${index + 1}. ${worker.name}: ${worker.currentLocation!.latitude.toFixed(6)}, ${worker.currentLocation!.longitude.toFixed(6)} (${ageMinutes.toFixed(1)}min ago) - OFFLINE`);
          });
        }

        if (hiddenWorkers.length > 0) {
          console.log('🚫 Hidden workers (too old):');
          hiddenWorkers.forEach((worker, index) => {
            const ageMinutes = worker.currentLocation ? getLocationAgeMinutes(worker) : Infinity;
            const ageDisplay = ageMinutes === Infinity ? 'No location' : `${ageMinutes.toFixed(1)}min ago`;
            console.log(`  ${index + 1}. ${worker.name}: ${ageDisplay} - HIDDEN`);
          });
        }

        // Only store visible workers for the map
        console.log(`💾 Setting ${visibleWorkers.length} visible workers to state`);
        setWorkers(visibleWorkers);
        setIsLoading(false);

        // Immediate map update for real-time tracking (only visible workers)
        if (mapReady && mapRef.current) {
          console.log('🔄 Updating live map markers in real-time...');
          console.log(`📊 Sending ${visibleWorkers.length} visible workers to map:`);
          console.log(`  - ${activeWorkers.length} active (blue pulsing)`);
          console.log(`  - ${recentlyActiveWorkers.length} recently active (blue static)`);
          console.log(`  - ${offlineWorkers.length} offline (grey)`);

          if (visibleWorkers.length === 0) {
            console.log(`⚠️ WARNING: No visible workers to display - this will show "No active workers found"`);
          } else {
            console.log(`✅ Visible workers:`, visibleWorkers.map(w => {
              const status = getWorkerProgressiveStatus(w);
              return `${w.name}(${status})`;
            }));
          }

          updateMapMarkers(visibleWorkers);
        } else {
          console.log('⏳ Map not ready yet, will update when loaded');
        }

        console.log(`🔄 === WORKER PROCESSING CYCLE END ===\n`);
      });
      
      unsubscribeRef.current = unsubscribe;
      
    } catch (error) {
      console.error('LiveLocationMap: Error loading workers:', error);
      setError('Failed to load worker locations');
      setIsLoading(false);
    }
  };

  const updateMapTerritories = (territoriesData: Territory[]) => {
    if (!mapRef.current) {
      console.log('LiveLocationMap: Map ref not available for territory update');
      return;
    }

    console.log(`🗺️ LiveLocationMap: Updating ${territoriesData.length} territories on map`);

    try {
      mapRef.current.contentWindow?.postMessage({
        type: 'updateTerritories',
        territories: territoriesData.map(territory => ({
          id: territory.id,
          name: territory.name,
          coordinates: territory.coordinates,
          color: territory.color,
          assignedWorker: territory.assignedWorker,
          visible: showTerritories
        }))
      }, '*');
    } catch (error) {
      console.error('LiveLocationMap: Error updating territories:', error);
    }
  };

  const updateMapMarkers = (workersData: WorkerData[]) => {
    if (!mapRef.current || !mapRef.current.contentWindow) {
      console.log('❌ LiveLocationMap: Map not ready for incremental updates');
      return;
    }

    console.log('🔄 LiveLocationMap: Performing incremental marker updates for', workersData.length, 'workers');

    const currentWorkers = new Map<string, WorkerData>();
    const previousWorkers = previousWorkersRef.current;

    // Build current workers map
    workersData.forEach(worker => {
      currentWorkers.set(worker.id, worker);
    });

    // Process incremental updates
    processIncrementalUpdates(currentWorkers, previousWorkers);

    // Update previous workers reference
    previousWorkersRef.current = currentWorkers;
  };

  const processIncrementalUpdates = (currentWorkers: Map<string, WorkerData>, previousWorkers: Map<string, WorkerData>) => {
    const updates: Array<{type: string, data: any}> = [];
    let activeWorkersCount = 0;
    let firstActiveWorker: WorkerData | null = null;

    // Check each current worker for updates
    currentWorkers.forEach((worker, workerId) => {
      const previousWorker = previousWorkers.get(workerId);
      const hasLocation = worker.currentLocation !== undefined;
      const progressiveStatus = getWorkerProgressiveStatus(worker);

      // Skip workers that should be hidden (too old)
      if (progressiveStatus === 'hidden') {
        if (DEBUG_FILTERING) {
          console.log(`🚫 Hiding worker: ${worker.name} (beyond grace period)`);
        }
        return;
      }

      const isLiveActive = progressiveStatus === 'active';
      const isRecentlyActive = progressiveStatus === 'recently-active';
      const isOffline = progressiveStatus === 'offline';

      if (isLiveActive) {
        activeWorkersCount++;
        if (!firstActiveWorker) {
          firstActiveWorker = worker;
        }
      }

      // Determine if this worker needs an update
      const needsUpdate = shouldUpdateWorker(worker, previousWorker);

      if (needsUpdate) {
        // Progressive color coding
        let markerColor: string;
        let isActiveMarker: boolean;

        if (worker.id === selectedWorkerId) {
          markerColor = '#ff0000'; // Red for selected
          isActiveMarker = isLiveActive;
        } else if (isLiveActive) {
          markerColor = '#0066cc'; // Blue pulsing for live active
          isActiveMarker = true;
        } else if (isRecentlyActive) {
          markerColor = '#0066cc'; // Blue static for recently active
          isActiveMarker = false;
        } else if (isOffline) {
          markerColor = '#999999'; // Grey for offline
          isActiveMarker = false;
        } else {
          markerColor = '#999999'; // Default grey
          isActiveMarker = false;
        }

        const ageMinutes = hasLocation ? getLocationAgeMinutes(worker) : 0;

        const markerData = {
          id: worker.id,
          name: worker.name,
          latitude: hasLocation ? worker.currentLocation!.latitude : 0,
          longitude: hasLocation ? worker.currentLocation!.longitude : 0,
          color: markerColor,
          isActive: isActiveMarker,
          lastSeen: worker.lastSeen,
          accuracy: hasLocation ? worker.currentLocation!.accuracy : 0,
          speed: hasLocation ? worker.currentLocation!.speed : 0,
          hasLocation: hasLocation,
          locationAge: Math.round(ageMinutes),
          progressiveStatus: progressiveStatus
        };

        if (DEBUG_FILTERING) {
          console.log(`🔄 Incremental update for ${worker.name}:`, {
            reason: getUpdateReason(worker, previousWorker),
            coordinates: hasLocation ? `${markerData.latitude.toFixed(6)}, ${markerData.longitude.toFixed(6)}` : 'No location',
            progressiveStatus: progressiveStatus,
            color: markerColor,
            ageMinutes: ageMinutes.toFixed(1),
            isActiveMarker: isActiveMarker
          });
        }

        updates.push({
          type: 'updateWorkerMarker',
          data: markerData
        });
      }
    });

    // Check for workers that were removed
    previousWorkers.forEach((previousWorker, workerId) => {
      if (!currentWorkers.has(workerId)) {
        console.log(`🗑️ Removing marker for ${previousWorker.name}`);
        updates.push({
          type: 'removeWorkerMarker',
          data: { id: workerId }
        });
      }
    });

    // Send all updates in batch
    if (updates.length > 0) {
      console.log(`📡 Sending ${updates.length} incremental updates to map`);
      mapRef.current!.contentWindow!.postMessage({
        type: 'batchUpdateMarkers',
        data: { updates, activeCount: activeWorkersCount }
      }, '*');
    }

    // Center map on first active worker (only once or when no previous center)
    if (firstActiveWorker && !mapCenteredRef.current) {
      console.log(`🎯 Centering map on first active worker: ${firstActiveWorker.name}`);
      mapRef.current!.contentWindow!.postMessage({
        type: 'centerOnWorker',
        latitude: firstActiveWorker.currentLocation!.latitude,
        longitude: firstActiveWorker.currentLocation!.longitude
      }, '*');
      mapCenteredRef.current = true;
    }
  };

  const shouldUpdateWorker = (current: WorkerData, previous?: WorkerData): boolean => {
    if (!previous) return true; // New worker

    // Check if progressive status changed
    const currentProgressiveStatus = getWorkerProgressiveStatus(current);
    const previousProgressiveStatus = getWorkerProgressiveStatus(previous);
    if (currentProgressiveStatus !== previousProgressiveStatus) return true;

    // Check if active status changed
    if (current.isActive !== previous.isActive) return true;

    // Check if location availability changed
    const currentHasLocation = !!current.currentLocation;
    const previousHasLocation = !!previous.currentLocation;
    if (currentHasLocation !== previousHasLocation) return true;

    // If both have locations, check if coordinates changed significantly
    if (currentHasLocation && previousHasLocation) {
      const latDiff = Math.abs(current.currentLocation!.latitude - previous.currentLocation!.latitude);
      const lngDiff = Math.abs(current.currentLocation!.longitude - previous.currentLocation!.longitude);
      const threshold = 0.000001; // ~0.1 meter precision

      if (latDiff > threshold || lngDiff > threshold) return true;

      // Check if timestamp changed (new location update)
      if (current.currentLocation!.timestamp !== previous.currentLocation!.timestamp) return true;
    }

    // Check if selected status changed
    if ((current.id === selectedWorkerId) !== (previous.id === selectedWorkerId)) return true;

    return false; // No significant changes
  };

  const getUpdateReason = (current: WorkerData, previous?: WorkerData): string => {
    if (!previous) return 'New worker';

    // Check progressive status changes first
    const currentProgressiveStatus = getWorkerProgressiveStatus(current);
    const previousProgressiveStatus = getWorkerProgressiveStatus(previous);
    if (currentProgressiveStatus !== previousProgressiveStatus) {
      return `Status: ${previousProgressiveStatus} → ${currentProgressiveStatus}`;
    }

    if (current.isActive !== previous.isActive) return current.isActive ? 'Became active' : 'Became inactive';
    if (!!current.currentLocation !== !!previous.currentLocation) return current.currentLocation ? 'Got location' : 'Lost location';

    if (current.currentLocation && previous.currentLocation) {
      // Check timestamp changes
      if (current.currentLocation.timestamp !== previous.currentLocation.timestamp) {
        return 'Location updated';
      }

      const latDiff = Math.abs(current.currentLocation.latitude - previous.currentLocation.latitude);
      const lngDiff = Math.abs(current.currentLocation.longitude - previous.currentLocation.longitude);
      if (latDiff > 0.000001 || lngDiff > 0.000001) return 'Position changed';
    }

    return 'Status update';
  };

  const handleWorkerPress = (worker: WorkerData) => {
    console.log('LiveLocationMap: Worker selected:', worker.name);
    if (onWorkerSelect) {
      onWorkerSelect(worker);
    }
    
    // Center map on worker location
    if (worker.currentLocation && mapRef.current && mapRef.current.centerOnLocation) {
      mapRef.current.centerOnLocation(
        worker.currentLocation.latitude,
        worker.currentLocation.longitude
      );
    }
  };

  const refreshWorkers = () => {
    console.log('LiveLocationMap: Manual refresh requested');
    loadActiveWorkers();
  };

  const formatLastSeen = (timestamp?: number): string => {
    if (!timestamp) return 'Never';
    
    const now = Date.now();
    const diff = now - timestamp;
    const minutes = Math.floor(diff / (1000 * 60));
    
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;
    
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    
    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  };

  const renderWorkersList = () => {
    if (isLoading) {
      return (
        <View style={styles.centerContainer}>
          <MaterialIcons name="location-searching" size={32} color={COLORS.text.secondary} />
          <Text style={styles.statusText}>Loading worker locations...</Text>
        </View>
      );
    }

    if (error) {
      return (
        <View style={styles.centerContainer}>
          <MaterialIcons name="error-outline" size={32} color={COLORS.error} />
          <Text style={[styles.statusText, { color: COLORS.error }]}>{error}</Text>
          <TouchableOpacity style={styles.retryButton} onPress={refreshWorkers}>
            <Text style={styles.retryButtonText}>Retry</Text>
          </TouchableOpacity>
        </View>
      );
    }

    // Use progressive status system for rendering
    const activeWorkers = workers.filter(w => isTrulyActive(w));
    const recentlyActiveWorkers = workers.filter(w => isRecentlyActive(w));
    const offlineWorkers = workers.filter(w => isOffline(w));
    const totalVisibleWorkers = activeWorkers.length + recentlyActiveWorkers.length + offlineWorkers.length;

    console.log(`🎨 Render: ${totalVisibleWorkers} total visible (${activeWorkers.length} active, ${recentlyActiveWorkers.length} recent, ${offlineWorkers.length} offline)`);

    if (totalVisibleWorkers === 0) {
      console.log(`🎨 Render: Showing "No active workers found" message`);
      return (
        <View style={styles.centerContainer}>
          <MaterialIcons name="location-off" size={32} color={COLORS.text.secondary} />
          <Text style={styles.statusText}>No active workers found</Text>
          <Text style={styles.subText}>Workers will appear here when they start ministry tracking</Text>
        </View>
      );
    }

    return (
      <View style={styles.modernWorkersList}>
        {/* Active Workers */}
        {activeWorkers.map(worker => (
          <TouchableOpacity
            key={worker.id}
            style={styles.modernWorkerCard}
            onPress={() => handleWorkerPress(worker)}
            activeOpacity={0.8}
          >
            <View style={styles.workerCardHeader}>
              <View style={styles.workerAvatarContainer}>
                <View style={[styles.workerAvatar, { backgroundColor: `${COLORS.success}15` }]}>
                  <MaterialIcons name="person" size={24} color={COLORS.success} />
                </View>
                <View style={[styles.statusIndicator, { backgroundColor: COLORS.success }]} />
              </View>
              <View style={styles.workerMainInfo}>
                <Text style={styles.modernWorkerName}>{worker.name}</Text>
                <Text style={styles.modernWorkerEmail}>{worker.email}</Text>
                <Text style={[styles.modernWorkerStatus, { color: COLORS.success }]}>
                  🟢 Active Now
                </Text>
              </View>
            </View>

            {worker.currentLocation && (
              <View style={styles.modernLocationInfo}>
                <View style={styles.locationHeader}>
                  <MaterialIcons name="location-on" size={16} color={COLORS.success} />
                  <Text style={styles.locationLabel}>Current Location</Text>
                </View>
                <Text style={styles.modernLocationText}>
                  {worker.currentLocation.latitude.toFixed(6)}, {worker.currentLocation.longitude.toFixed(6)}
                </Text>
                <Text style={styles.modernLocationTime}>
                  Updated {formatLastSeen(worker.currentLocation.timestamp)}
                </Text>
              </View>
            )}
          </TouchableOpacity>
        ))}

        {/* Recently Active Workers */}
        {recentlyActiveWorkers.map(worker => (
          <TouchableOpacity
            key={worker.id}
            style={styles.modernWorkerCard}
            onPress={() => handleWorkerPress(worker)}
            activeOpacity={0.8}
          >
            <View style={styles.workerCardHeader}>
              <View style={styles.workerAvatarContainer}>
                <View style={[styles.workerAvatar, { backgroundColor: `${COLORS.warning}15` }]}>
                  <MaterialIcons name="person" size={24} color={COLORS.warning} />
                </View>
                <View style={[styles.statusIndicator, { backgroundColor: COLORS.warning }]} />
              </View>
              <View style={styles.workerMainInfo}>
                <Text style={styles.modernWorkerName}>{worker.name}</Text>
                <Text style={styles.modernWorkerEmail}>{worker.email}</Text>
                <Text style={[styles.modernWorkerStatus, { color: COLORS.warning }]}>
                  🟡 Recently Active
                </Text>
              </View>
            </View>

            {worker.currentLocation && (
              <View style={styles.modernLocationInfo}>
                <View style={styles.locationHeader}>
                  <MaterialIcons name="location-on" size={16} color={COLORS.warning} />
                  <Text style={styles.locationLabel}>Last Location</Text>
                </View>
                <Text style={styles.modernLocationText}>
                  {worker.currentLocation.latitude.toFixed(6)}, {worker.currentLocation.longitude.toFixed(6)}
                </Text>
                <Text style={styles.modernLocationTime}>
                  Updated {formatLastSeen(worker.currentLocation.timestamp)}
                </Text>
              </View>
            )}
          </TouchableOpacity>
        ))}

        {/* Offline Workers */}
        {offlineWorkers.map(worker => (
          <TouchableOpacity
            key={worker.id}
            style={[styles.modernWorkerCard, styles.workerCardOffline]}
            onPress={() => handleWorkerPress(worker)}
            activeOpacity={0.8}
          >
            <View style={styles.workerCardHeader}>
              <View style={styles.workerAvatarContainer}>
                <View style={[styles.workerAvatar, { backgroundColor: `${COLORS.textSecondary}15` }]}>
                  <MaterialIcons name="person" size={24} color={COLORS.textSecondary} />
                </View>
                <View style={[styles.statusIndicator, { backgroundColor: COLORS.textSecondary }]} />
              </View>
              <View style={styles.workerMainInfo}>
                <Text style={[styles.modernWorkerName, { color: COLORS.text.secondary }]}>{worker.name}</Text>
                <Text style={styles.modernWorkerEmail}>{worker.email}</Text>
                <Text style={[styles.modernWorkerStatus, { color: COLORS.textSecondary }]}>
                  🔴 Offline
                </Text>
              </View>
            </View>

            <View style={styles.modernOfflineInfo}>
              <View style={styles.offlineHeader}>
                <MaterialIcons name="access-time" size={16} color={COLORS.textSecondary} />
                <Text style={styles.offlineLabel}>Last Seen</Text>
              </View>
              <Text style={styles.modernOfflineText}>
                {worker.lastSeen ? formatLastSeen(worker.lastSeen) : 'Unknown'}
              </Text>
            </View>
          </TouchableOpacity>
        ))}
      </View>
    );
  };

  return (
    <View style={styles.modernContainer}>
      <StatusBar barStyle="light-content" backgroundColor={COLORS.primary} />

      {/* Modern Header */}
      <Header
        title="Live Worker Tracking"
        showBackButton={true}
        onBackPress={onClose}
        rightComponent={
          <TouchableOpacity style={styles.modernRefreshButton} onPress={refreshWorkers}>
            <MaterialIcons name="refresh" size={24} color={COLORS.textInverse} />
          </TouchableOpacity>
        }
      />

      <ScrollView style={styles.modernContent} showsVerticalScrollIndicator={false}>
        {/* Modern Stats Overview */}
        <View style={styles.modernStatsContainer}>
          <View style={styles.modernStatCard}>
            <View style={[styles.statIconContainer, { backgroundColor: `${COLORS.success}15` }]}>
              <MaterialIcons name="location-on" size={24} color={COLORS.success} />
            </View>
            <View style={styles.statContent}>
              <Text style={styles.statNumber}>{workers.filter(w => getWorkerProgressiveStatus(w) === 'active').length}</Text>
              <Text style={styles.statLabel}>Active Now</Text>
              <Text style={styles.statSubtitle}>Currently tracking</Text>
            </View>
          </View>

          <View style={styles.modernStatCard}>
            <View style={[styles.statIconContainer, { backgroundColor: `${COLORS.info}15` }]}>
              <MaterialIcons name="people" size={24} color={COLORS.info} />
            </View>
            <View style={styles.statContent}>
              <Text style={styles.statNumber}>{workers.length}</Text>
              <Text style={styles.statLabel}>Total Workers</Text>
              <Text style={styles.statSubtitle}>In system</Text>
            </View>
          </View>

          <View style={styles.modernStatCard}>
            <View style={[styles.statIconContainer, { backgroundColor: `${COLORS.warning}15` }]}>
              <MaterialIcons name="access-time" size={24} color={COLORS.warning} />
            </View>
            <View style={styles.statContent}>
              <Text style={styles.statNumber}>{workers.filter(w => getWorkerProgressiveStatus(w) === 'recently-active').length}</Text>
              <Text style={styles.statLabel}>Recent</Text>
              <Text style={styles.statSubtitle}>Last 5 minutes</Text>
            </View>
          </View>
        </View>

        {/* Modern Map Section */}
        <View style={styles.modernMapSection}>
          <View style={styles.sectionHeader}>
            <View style={styles.sectionHeaderLeft}>
              <MaterialIcons name="map" size={20} color={COLORS.primary} />
              <Text style={styles.sectionTitle}>Live Location Map</Text>
            </View>
            <TouchableOpacity
              style={[styles.territoryToggle, showTerritories && styles.territoryToggleActive]}
              onPress={() => {
                const newShowTerritories = !showTerritories;
                setShowTerritories(newShowTerritories);
                if (mapReady && territories.length > 0) {
                  updateMapTerritories(territories);
                }
              }}
            >
              <MaterialIcons
                name="layers"
                size={16}
                color={showTerritories ? COLORS.white : COLORS.text.secondary}
              />
              <Text style={[styles.territoryToggleText, showTerritories && styles.territoryToggleTextActive]}>
                Territories
              </Text>
            </TouchableOpacity>
          </View>

          {Platform.OS === 'web' ? (
            <View style={styles.modernWebMapContainer}>
              <iframe
                ref={mapRef}
                src="/leaflet-map.html"
                style={styles.modernWebMap}
                onLoad={() => {
                  console.log('LiveLocationMap: Web map loaded');
                  setMapReady(true);
                  if (territories.length > 0) {
                    updateMapTerritories(territories);
                  }
                  if (workers.length > 0) {
                    updateMapMarkers(workers);
                  }
                }}
              />
            </View>
          ) : (
            <View style={styles.modernMobileMapPlaceholder}>
              <MaterialIcons name="map" size={48} color={COLORS.text.secondary} />
              <Text style={styles.modernPlaceholderText}>Interactive map available on web version</Text>
            </View>
          )}
        </View>

        {/* Modern Workers List */}
        <View style={styles.modernWorkersSection}>
          <View style={styles.sectionHeader}>
            <MaterialIcons name="people" size={20} color={COLORS.primary} />
            <Text style={styles.sectionTitle}>Worker Status</Text>
            <Text style={styles.sectionSubtitle}>Real-time location tracking</Text>
          </View>

          {renderWorkersList()}
        </View>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  // Modern Container
  modernContainer: {
    flex: 1,
    backgroundColor: COLORS.background.secondary,
  },
  modernContent: {
    flex: 1,
  },

  // Modern Header Refresh Button
  modernRefreshButton: {
    padding: SPACING.xs,
  },

  // Modern Stats Container
  modernStatsContainer: {
    flexDirection: 'row',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    gap: SPACING.sm,
  },
  modernStatCard: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    flexDirection: 'row',
    alignItems: 'center',
    ...SHADOWS.sm,
  },
  statIconContainer: {
    width: 40,
    height: 40,
    borderRadius: RADIUS.md,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.sm,
  },
  statContent: {
    flex: 1,
  },
  statNumber: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  statSubtitle: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },

  // Modern Section Headers
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
  },
  sectionHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  sectionSubtitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: 'auto',
  },

  // Territory Toggle
  territoryToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    backgroundColor: COLORS.background.secondary,
    borderWidth: 1,
    borderColor: COLORS.border.primary,
    gap: SPACING.xs,
  },
  territoryToggleActive: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  territoryToggleText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  territoryToggleTextActive: {
    color: COLORS.white,
  },

  // Modern Map Section
  modernMapSection: {
    marginHorizontal: SPACING.lg,
    marginBottom: SPACING.lg,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    overflow: 'hidden',
    ...SHADOWS.sm,
  },
  modernWebMapContainer: {
    height: 300,
    backgroundColor: COLORS.background.secondary,
  },
  modernWebMap: {
    width: '100%',
    height: '100%',
    border: 'none',
  },
  modernMobileMapPlaceholder: {
    height: 200,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
  },
  modernPlaceholderText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginTop: SPACING.sm,
  },

  // Modern Workers Section
  modernWorkersSection: {
    marginBottom: SPACING.lg,
  },

  // Modern Workers List
  modernWorkersList: {
    paddingHorizontal: SPACING.lg,
    gap: SPACING.md,
  },
  modernWorkerCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    ...SHADOWS.sm,
  },
  workerCardOffline: {
    opacity: 0.7,
    borderLeftWidth: 4,
    borderLeftColor: COLORS.textSecondary,
  },
  workerCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  workerAvatarContainer: {
    position: 'relative',
    marginRight: SPACING.md,
  },
  workerAvatar: {
    width: 48,
    height: 48,
    borderRadius: RADIUS.full,
    justifyContent: 'center',
    alignItems: 'center',
  },
  statusIndicator: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 14,
    height: 14,
    borderRadius: RADIUS.full,
    borderWidth: 2,
    borderColor: COLORS.background.primary,
  },
  workerMainInfo: {
    flex: 1,
  },
  modernWorkerName: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  modernWorkerEmail: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  modernWorkerStatus: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
  },

  // Modern Location Info
  modernLocationInfo: {
    backgroundColor: `${COLORS.success}10`,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginTop: SPACING.sm,
    borderLeftWidth: 3,
    borderLeftColor: COLORS.success,
  },
  locationHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  locationLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.success,
    marginLeft: SPACING.xs,
  },
  modernLocationText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
    marginBottom: SPACING.xs,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  modernLocationTime: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },

  // Modern Offline Info
  modernOfflineInfo: {
    backgroundColor: `${COLORS.textSecondary}10`,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginTop: SPACING.sm,
    borderLeftWidth: 3,
    borderLeftColor: COLORS.textSecondary,
  },
  offlineHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  offlineLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
  modernOfflineText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },

  // Center Container for Loading/Error States
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.lg,
  },
  statusText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
    textAlign: 'center',
  },
  subText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
    opacity: 0.7,
  },
  retryButton: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    marginTop: SPACING.md,
  },
  retryButtonText: {
    color: COLORS.textInverse,
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
});

export default LiveLocationMap;
