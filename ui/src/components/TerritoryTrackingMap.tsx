import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Platform, TouchableOpacity, ScrollView } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { realtimeLocationService } from '../services/RealtimeLocationService';
import { COLORS, SPACING, TYPOGRAPHY, RADIUS } from '../constants/Colors';

interface Territory {
  id: string;
  name: string;
  coordinates: Array<{lat: number, lng: number}>;
  assignedWorker?: {
    id: string;
    name: string;
    email: string;
  };
  color: string;
}

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

interface TerritoryTrackingMapProps {
  territories: Territory[];
  height?: number;
  onWorkerSelect?: (worker: WorkerData, territory?: Territory) => void;
}

const TerritoryTrackingMap: React.FC<TerritoryTrackingMapProps> = ({
  territories,
  height = 400,
  onWorkerSelect
}) => {
  const [workers, setWorkers] = useState<WorkerData[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [mapReady, setMapReady] = useState(false);
  const [lastUpdateTime, setLastUpdateTime] = useState<Date>(new Date());
  const mapRef = useRef<any>(null);
  const unsubscribeRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    console.log('TerritoryTrackingMap: Initializing...');
    loadActiveWorkers();

    // Set up periodic refresh to ensure map stays updated
    const refreshInterval = setInterval(() => {
      if (mapReady && workers.length > 0) {
        console.log('🔄 Periodic map refresh with current workers...');
        updateMapWithWorkersAndTerritories(workers);
      }
    }, 5000); // Refresh every 5 seconds

    return () => {
      if (unsubscribeRef.current) {
        console.log('TerritoryTrackingMap: Cleaning up listeners...');
        unsubscribeRef.current();
      }
      clearInterval(refreshInterval);
    };
  }, []);

  const loadActiveWorkers = async () => {
    try {
      setIsLoading(true);
      console.log('TerritoryTrackingMap: Loading active workers...');
      
      // Listen to all workers for real-time updates
      const unsubscribe = realtimeLocationService.listenToAllWorkers((updatedWorkers) => {
        console.log('🗺️ TerritoryTrackingMap: Received worker updates:', updatedWorkers.length);

        // Log each worker's details for debugging
        updatedWorkers.forEach(worker => {
          if (worker.isActive && worker.currentLocation) {
            console.log(`📍 Active Worker: ${worker.name} at ${worker.currentLocation.latitude.toFixed(6)}, ${worker.currentLocation.longitude.toFixed(6)}`);
          }
        });

        setWorkers(updatedWorkers);
        setIsLoading(false);
        setLastUpdateTime(new Date());

        // Update map if ready - force update even if workers array is the same
        if (mapReady && mapRef.current) {
          console.log('🔄 Updating map with latest worker positions...');
          updateMapWithWorkersAndTerritories(updatedWorkers);
        }
      });
      
      unsubscribeRef.current = unsubscribe;
      
    } catch (error) {
      console.error('TerritoryTrackingMap: Error loading workers:', error);
      setIsLoading(false);
    }
  };

  const updateMapWithWorkersAndTerritories = (workersData: WorkerData[]) => {
    if (!mapRef.current || Platform.OS !== 'web') return;

    console.log('🗺️ TerritoryTrackingMap: Updating map with', territories.length, 'territories and', workersData.length, 'workers');

    // Clear existing content for fresh update
    if (mapRef.current.contentWindow) {
      mapRef.current.contentWindow.postMessage({
        type: 'clearAll'
      }, '*');

      // Draw territories first
      territories.forEach(territory => {
        mapRef.current.contentWindow.postMessage({
          type: 'drawTerritory',
          territory: territory
        }, '*');
      });

      // Then add worker markers with enhanced logging
      const activeWorkers = workersData.filter(worker => worker.isActive && worker.currentLocation);
      console.log(`📍 Adding ${activeWorkers.length} active workers to map`);

      activeWorkers.forEach(worker => {
        console.log(`📌 Adding marker for ${worker.name} at ${worker.currentLocation!.latitude.toFixed(6)}, ${worker.currentLocation!.longitude.toFixed(6)}`);

        // Find assigned territory for this worker
        const assignedTerritory = territories.find(t =>
          t.assignedWorker && t.assignedWorker.id === worker.id
        );

        const markerData = {
          id: worker.id,
          name: worker.name,
          email: worker.email,
          latitude: worker.currentLocation!.latitude,
          longitude: worker.currentLocation!.longitude,
          isActive: worker.isActive,
          lastSeen: worker.lastSeen || Date.now(),
          accuracy: worker.currentLocation!.accuracy || 0,
          speed: worker.currentLocation!.speed || 0,
          color: assignedTerritory ? assignedTerritory.color : '#10b981',
          territoryName: assignedTerritory ? assignedTerritory.name : 'Unassigned'
        };

        console.log(`📍 Sending marker data for ${worker.name}:`, markerData);

        mapRef.current.contentWindow.postMessage({
          type: 'addWorkerMarker',
          data: markerData
        }, '*');
      });

      console.log(`✅ TerritoryTrackingMap: Finished sending ${activeWorkers.length} worker markers to map`);
    }
  };

  const getWorkersInTerritories = () => {
    return workers.filter(worker => {
      if (!worker.isActive || !worker.currentLocation) return false;
      
      const assignedTerritory = territories.find(t => 
        t.assignedWorker && t.assignedWorker.id === worker.id
      );
      
      return !!assignedTerritory;
    });
  };

  const getMapHTML = () => `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Territory Tracking Map</title>
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <style>
            body { margin: 0; padding: 0; }
            #map { height: 100vh; width: 100%; }
            .worker-popup {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                padding: 12px;
                border-radius: 8px;
                background: white;
                box-shadow: 0 2px 8px rgba(0,0,0,0.15);
                min-width: 200px;
            }
            .worker-popup-name {
                font-weight: bold;
                font-size: 16px;
                color: #1e293b;
                margin-bottom: 6px;
            }
            .worker-popup-territory {
                font-size: 14px;
                color: #3b82f6;
                margin-bottom: 4px;
            }
            .worker-popup-location {
                font-size: 12px;
                color: #64748b;
                font-family: monospace;
                margin-bottom: 4px;
            }
            .worker-popup-status {
                font-size: 11px;
                color: #10b981;
                font-weight: 600;
            }
        </style>
    </head>
    <body>
        <div id="map"></div>
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <script>
            let map = null;
            let territories = [];
            let workers = [];

            // Initialize map
            function initMap() {
                map = L.map('map', {
                    zoomControl: true,
                    attributionControl: true
                }).setView([40.7128, -74.0060], 12);

                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '© OpenStreetMap contributors'
                }).addTo(map);

                console.log('Territory tracking map initialized');
                
                // Notify parent that map is ready
                window.parent.postMessage({
                    type: 'mapReady'
                }, '*');
            }

            // Clear all content
            function clearAll() {
                territories.forEach(t => {
                    if (t.polygon) {
                        map.removeLayer(t.polygon);
                    }
                });
                workers.forEach(w => {
                    if (w.marker) {
                        map.removeLayer(w.marker);
                    }
                });
                territories = [];
                workers = [];
            }

            // Draw territory
            function drawTerritory(territory) {
                const coordinates = territory.coordinates.map(coord => [coord.lat, coord.lng]);
                
                const polygon = L.polygon(coordinates, {
                    color: territory.color,
                    weight: 2,
                    opacity: 0.8,
                    fillOpacity: 0.2,
                    fillColor: territory.color
                }).addTo(map);

                const popupContent = \`
                    <div class="worker-popup">
                        <div class="worker-popup-name">\${territory.name}</div>
                        <div class="worker-popup-territory">
                            \${territory.assignedWorker ? 
                                '👤 ' + territory.assignedWorker.name : 
                                '⚪ Unassigned'
                            }
                        </div>
                    </div>
                \`;

                polygon.bindPopup(popupContent);
                
                territories.push({
                    id: territory.id,
                    polygon: polygon,
                    data: territory
                });
            }

            // Add worker marker
            function addWorkerMarker(marker) {
                console.log('MARKER: Adding worker marker for', marker.name, 'at', marker.latitude, marker.longitude);

                if (!marker.latitude || !marker.longitude) {
                    console.error('ERROR: Invalid coordinates for', marker.name);
                    return;
                }

                if (!map) {
                    console.error('ERROR: Map not initialized');
                    return;
                }

                // Use default color if not provided
                const markerColor = marker.color || '#10b981';
                const territoryName = marker.territoryName || 'Unassigned';

                console.log('Creating marker with color:', markerColor);

                // Create simple marker first
                const workerMarker = L.marker([marker.latitude, marker.longitude]);

                // Add to map
                workerMarker.addTo(map);

                console.log('SUCCESS: Marker added to map for', marker.name);

                // Center map on first worker if this is the first marker
                if (workers.length === 0) {
                    map.setView([marker.latitude, marker.longitude], 15);
                    console.log('Map centered on', marker.name);
                }

                // Create popup content
                const popupContent = '<div class="worker-popup">' +
                    '<div class="worker-popup-name">' + marker.name + '</div>' +
                    '<div class="worker-popup-territory">📍 ' + territoryName + '</div>' +
                    '<div class="worker-popup-location">' +
                        marker.latitude.toFixed(6) + ', ' + marker.longitude.toFixed(6) +
                    '</div>' +
                    '<div class="worker-popup-status">🟢 LIVE TRACKING</div>' +
                '</div>';

                workerMarker.bindPopup(popupContent);

                workers.push({
                    id: marker.id,
                    marker: workerMarker,
                    data: marker
                });

                // Marker added successfully
                console.log('SUCCESS: Added marker for ' + marker.name);
                console.log('INFO: Total workers: ' + workers.length);
            }

            // Listen for messages from React Native
            window.addEventListener('message', function(event) {
                console.log('MESSAGE: TerritoryTrackingMap HTML: Received message:', event.data);

                if (event.data.type === 'clearAll') {
                    console.log('CLEAR: Clearing all map content');
                    clearAll();
                } else if (event.data.type === 'drawTerritory') {
                    console.log('TERRITORY: Drawing territory:', event.data.territory && event.data.territory.name);
                    drawTerritory(event.data.territory);
                } else if (event.data.type === 'addWorkerMarker') {
                    console.log('MARKER: Adding worker marker:', (event.data.data && event.data.data.name) || (event.data.marker && event.data.marker.name));
                    // Handle both data structures for compatibility
                    const markerData = event.data.data || event.data.marker;
                    if (markerData) {
                        addWorkerMarker(markerData);
                    } else {
                        console.error('❌ No marker data found in message');
                    }
                }
            });

            // Initialize map when page loads
            document.addEventListener('DOMContentLoaded', initMap);
        </script>
    </body>
    </html>
  `;

  const workersInTerritories = getWorkersInTerritories();

  return (
    <View style={[styles.container, { height }]}>
      {Platform.OS === 'web' ? (
        <View style={styles.webMapContainer}>
          <iframe
            ref={mapRef}
            srcDoc={getMapHTML()}
            style={styles.webMap}
            onLoad={() => {
              console.log('TerritoryTrackingMap: Web map loaded');
              setMapReady(true);
              if (workers.length > 0) {
                updateMapWithWorkersAndTerritories(workers);
              }
            }}
          />
        </View>
      ) : (
        <View style={styles.mobileMapPlaceholder}>
          <MaterialIcons name="map" size={64} color={COLORS.text.secondary} />
          <Text style={styles.placeholderText}>Territory tracking map for mobile coming soon</Text>
        </View>
      )}
      
      {/* Workers Summary */}
      <View style={styles.workersSummary}>
        <View style={styles.summaryHeader}>
          <Text style={styles.summaryTitle}>
            Active Workers in Territories ({workersInTerritories.length})
          </Text>
          <View style={styles.realTimeIndicator}>
            <View style={styles.liveDot} />
            <Text style={styles.liveText}>LIVE</Text>
            <Text style={styles.lastUpdateText}>
              Updated: {lastUpdateTime.toLocaleTimeString()}
            </Text>
          </View>
        </View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.workersScroll}>
          {workersInTerritories.map(worker => {
            const territory = territories.find(t => 
              t.assignedWorker && t.assignedWorker.id === worker.id
            );
            
            return (
              <TouchableOpacity
                key={worker.id}
                style={[styles.workerChip, { borderColor: territory?.color || COLORS.primary }]}
                onPress={() => onWorkerSelect && onWorkerSelect(worker, territory)}
              >
                <View style={[styles.workerChipDot, { backgroundColor: territory?.color || COLORS.primary }]} />
                <Text style={styles.workerChipName}>{worker.name}</Text>
                <Text style={styles.workerChipTerritory}>{territory?.name || 'Unknown'}</Text>
              </TouchableOpacity>
            );
          })}
        </ScrollView>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  webMapContainer: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  webMap: {
    width: '100%',
    height: '100%',
    border: 'none',
  },
  mobileMapPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.backgroundSecondary,
  },
  placeholderText: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
    textAlign: 'center',
  },
  workersSummary: {
    backgroundColor: COLORS.background,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
    padding: SPACING.md,
  },
  summaryTitle: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  workersScroll: {
    flexDirection: 'row',
  },
  workerChip: {
    backgroundColor: COLORS.backgroundSecondary,
    borderRadius: RADIUS.md,
    padding: SPACING.sm,
    marginRight: SPACING.sm,
    borderWidth: 2,
    minWidth: 120,
    alignItems: 'center',
  },
  workerChipDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginBottom: SPACING.xs,
  },
  workerChipName: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
    textAlign: 'center',
    marginBottom: 2,
  },
  workerChipTerritory: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  summaryHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  realTimeIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#10b981',
    marginRight: SPACING.xs,
  },
  liveText: {
    fontSize: TYPOGRAPHY.xs,
    fontWeight: TYPOGRAPHY.semibold,
    color: '#10b981',
    marginRight: SPACING.sm,
  },
  lastUpdateText: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.text.secondary,
  },
});

export default TerritoryTrackingMap;
