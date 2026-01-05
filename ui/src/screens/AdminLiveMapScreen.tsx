import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Platform,
  Alert,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { realtimeLocationService } from '../services/RealtimeLocationService';
import { Territory } from '../services/TerritoryService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants/Colors';
import TerritoryMap from '../components/TerritoryMap';

interface AdminLiveMapScreenProps {
  navigation: any;
  route: {
    params: {
      workerId: string;
      workerName: string;
      assignedTerritories: Territory[];
      currentLocation?: {
        latitude: number;
        longitude: number;
        timestamp: number;
      };
    };
  };
}

const AdminLiveMapScreen: React.FC<AdminLiveMapScreenProps> = ({ navigation, route }) => {
  const { workerId, workerName, assignedTerritories, currentLocation: initialLocation } = route.params;
  
  const [workerLocation, setWorkerLocation] = useState(initialLocation);
  const [mapReady, setMapReady] = useState(false);
  const [isTracking, setIsTracking] = useState(false);
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null);

  useEffect(() => {
    console.log('AdminLiveMapScreen opened for:', workerName, 'with', assignedTerritories.length, 'territories');

    // Listen to real-time location updates from Firebase Realtime Database
    const unsubscribe = realtimeLocationService.listenToWorker(workerId, (workerData) => {
      console.log('Real-time location update received for worker:', workerName, workerData);

      if (workerData && workerData.currentLocation) {
        const newLocation = {
          latitude: workerData.currentLocation.latitude,
          longitude: workerData.currentLocation.longitude,
          timestamp: workerData.currentLocation.timestamp,
        };

        console.log('New location from Realtime DB:', newLocation);
        setWorkerLocation(newLocation);
        setLastUpdate(new Date());
        setIsTracking(workerData.isActive);

        // Update map if ready
        if (mapReady) {
          updateWorkerLocationOnMap(newLocation);
        }
      } else {
        console.log('No location data for worker:', workerName);
        setIsTracking(false);
      }
    });

    return () => unsubscribe();
  }, [workerId, workerName]);

  useEffect(() => {
    // Listen for messages from iframe
    const handleMessage = (event: MessageEvent) => {
      if (event.data.type === 'mapReady') {
        handleMapReady();
      }
    };

    if (Platform.OS === 'web') {
      window.addEventListener('message', handleMessage);
      return () => {
        window.removeEventListener('message', handleMessage);
      };
    }
  }, [assignedTerritories, workerLocation]);

  const handleMapReady = () => {
    console.log('🗺️ Admin live map is ready');
    setMapReady(true);
    
    // Draw all assigned territories
    assignedTerritories.forEach(territory => {
      drawTerritoryOnMap(territory, true); // true for highlight
    });
    
    // Show worker location if available
    if (workerLocation) {
      updateWorkerLocationOnMap(workerLocation);
    }
  };

  const drawTerritoryOnMap = (territory: Territory, highlight: boolean = false) => {
    if (Platform.OS === 'web' && mapReady) {
      const iframe = document.getElementById('admin-live-map-iframe') as HTMLIFrameElement;
      if (iframe && iframe.contentWindow) {
        iframe.contentWindow.postMessage({
          type: 'drawTerritory',
          territory: territory,
          highlight: highlight,
          workerName: workerName
        }, '*');
      }
    }
  };

  const updateWorkerLocationOnMap = (location: { latitude: number; longitude: number; timestamp: number }) => {
    if (Platform.OS === 'web' && mapReady) {
      const iframe = document.getElementById('admin-live-map-iframe') as HTMLIFrameElement;
      if (iframe && iframe.contentWindow) {
        iframe.contentWindow.postMessage({
          type: 'updateWorkerLocation',
          location: {
            lat: location.latitude,
            lng: location.longitude
          },
          workerName: workerName,
          timestamp: location.timestamp
        }, '*');
      }
    }
  };

  const isWorkerInsideAnyTerritory = (): boolean => {
    if (!workerLocation || assignedTerritories.length === 0) return false;
    
    return assignedTerritories.some(territory => 
      isPointInPolygon(
        { lat: workerLocation.latitude, lng: workerLocation.longitude },
        territory.coordinates
      )
    );
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

  const getMapHTML = () => `
    <!DOCTYPE html>
    <html>
    <head>
        <title>Admin Live Worker Tracking</title>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <style>
            body { margin: 0; padding: 0; }

                console.log('🗺️ Admin live map initialized');
                
                // Notify React Native that map is ready
                if (window.parent) {
                    window.parent.postMessage({ type: 'mapReady' }, '*');
                }
            }

            function drawTerritory(territory, highlight = false, workerName = '') {
                console.log('🗺️ Drawing territory:', territory.name, 'highlight:', highlight);

                const coordinates = territory.coordinates.map(coord => [coord.lat, coord.lng]);

                const style = highlight ? {
                    color: '#d7a638',
                    weight: 4,
                    opacity: 1,
                    fillOpacity: 0.4,
                    fillColor: territory.color,
                    dashArray: '10, 5'
                } : {
                    color: territory.color,
                    weight: 2,
                    opacity: 0.8,
                    fillOpacity: 0.2,
                    fillColor: territory.color
                };

                const polygon = L.polygon(coordinates, style).addTo(map);

                // Add popup with territory info
                const popupContent = \`
                    <div class="territory-popup">
                        <div class="territory-popup-name">\${territory.name}</div>
                        <div class="territory-popup-worker">
                            \${highlight ? 
                                '👤 Assigned to: ' + workerName :
                                (territory.assignedWorker ? '👤 ' + territory.assignedWorker.name : '⚪ Unassigned')
                            }
                        </div>
                        \${highlight ? '<div style="color: #d7a638; font-size: 11px; margin-top: 4px;">📍 Currently tracking</div>' : ''}
                    </div>
                \`;

                polygon.bindPopup(popupContent);

                territories.push({
                    id: territory.id,
                    polygon: polygon,
                    data: territory
                });

                // Fit map to show all territories
                if (territories.length === 1) {
                    map.fitBounds(polygon.getBounds(), { padding: [20, 20] });
                }
            }

            function updateWorkerLocation(location, workerName, timestamp) {
                console.log('📍 Updating worker location:', location, workerName);

                // Remove existing worker marker
                if (workerMarker) {
                    map.removeLayer(workerMarker);
                }

                // Add new worker marker with enhanced styling
                workerMarker = L.marker([location.lat, location.lng], {
                    icon: L.divIcon({
                        className: 'worker-marker',
                        html: \`
                            <div style="
                                background: linear-gradient(45deg, #d7a638, #f59e0b);
                                width: 24px; 
                                height: 24px; 
                                border-radius: 50%; 
                                border: 3px solid #002b5b; 
                                box-shadow: 0 4px 12px rgba(0,43,91,0.4);
                                position: relative;
                            ">
                                <div style="
                                    position: absolute;
                                    top: -8px;
                                    right: -8px;
                                    width: 12px;
                                    height: 12px;
                                    background: #10b981;
                                    border-radius: 50%;
                                    border: 2px solid white;
                                    animation: pulse 2s infinite;
                                "></div>
                            </div>
                            <style>
                                @keyframes pulse {
                                    0% { transform: scale(1); opacity: 1; }
                                    50% { transform: scale(1.2); opacity: 0.7; }
                                    100% { transform: scale(1); opacity: 1; }
                                }
                            </style>
                        \`,
                        iconSize: [30, 30],
                        iconAnchor: [15, 15]
                    })
                }).addTo(map);

                // Add popup with worker info
                const lastUpdateTime = new Date(timestamp).toLocaleTimeString();
                const popupContent = \`
                    <div class="worker-popup">
                        <div class="worker-popup-name">👤 \${workerName}</div>
                        <div class="worker-popup-status">📍 Live Location</div>
                        <div style="color: #64748b; font-size: 11px; margin-top: 4px;">
                            Last update: \${lastUpdateTime}
                        </div>
                        <div style="color: #64748b; font-size: 10px; margin-top: 2px;">
                            \${location.lat.toFixed(6)}, \${location.lng.toFixed(6)}
                        </div>
                    </div>
                \`;

                workerMarker.bindPopup(popupContent);

                // Center map on worker location
                map.setView([location.lat, location.lng], Math.max(map.getZoom(), 15));
            }

            // Listen for messages from React Native
            window.addEventListener('message', function(event) {
                if (event.data.type === 'drawTerritory') {
                    drawTerritory(event.data.territory, event.data.highlight, event.data.workerName);
                } else if (event.data.type === 'updateWorkerLocation') {
                    updateWorkerLocation(event.data.location, event.data.workerName, event.data.timestamp);
                }
            });

            // Initialize map when page loads
            document.addEventListener('DOMContentLoaded', initMap);
        </script>
    </body>
    </html>
  `;

  const insideTerritory = isWorkerInsideAnyTerritory();

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.textInverse} />
        </TouchableOpacity>
        <View style={styles.headerCenter}>
          <Text style={styles.title}>📍 Live Tracking</Text>
          <Text style={styles.subtitle}>{workerName}</Text>
        </View>
        <View style={styles.headerRight}>
          {isTracking && (
            <View style={styles.liveIndicator}>
              <View style={styles.liveDot} />
              <Text style={styles.liveText}>LIVE</Text>
            </View>
          )}
        </View>
      </View>

      {/* Status Bar */}
      <View style={styles.statusBar}>
        <View style={styles.statusItem}>
          <MaterialIcons name="map" size={20} color={COLORS.secondary} />
          <Text style={styles.statusText}>{assignedTerritories.length} Territories</Text>
        </View>
        
        <View style={styles.statusItem}>
          <MaterialIcons 
            name="location-on" 
            size={20} 
            color={insideTerritory ? COLORS.success : COLORS.error} 
          />
          <Text style={[styles.statusText, { color: insideTerritory ? COLORS.success : COLORS.error }]}>
            {insideTerritory ? 'Inside Territory' : 'Outside Territory'}
          </Text>
        </View>
        
        {lastUpdate && (
          <View style={styles.statusItem}>
            <MaterialIcons name="access-time" size={20} color={COLORS.textSecondary} />
            <Text style={styles.statusText}>
              {lastUpdate.toLocaleTimeString()}
            </Text>
          </View>
        )}
      </View>

      {/* Map Container */}
      <View style={styles.mapContainer}>
        {Platform.OS === 'web' ? (
          <iframe
            id="admin-live-map-iframe"
            srcDoc={getMapHTML()}
            style={styles.mapIframe}
          />
        ) : (
          <TerritoryMap
            territories={assignedTerritories}
            selectedTerritory={null}
            currentLocation={workerLocation ? {
              latitude: workerLocation.latitude,
              longitude: workerLocation.longitude,
            } : null}
            showUserLocation={true}
            style={styles.mobileMap}
          />
        )}
      </View>

      {/* Territory List */}
      <View style={styles.territoryList}>
        <Text style={styles.territoryListTitle}>Assigned Territories:</Text>
        {assignedTerritories.map((territory) => (
          <View key={territory.id} style={styles.territoryItem}>
            <View style={[styles.territoryColor, { backgroundColor: territory.color }]} />
            <Text style={styles.territoryName}>{territory.name}</Text>
          </View>
        ))}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  header: {
    backgroundColor: COLORS.primary,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingTop: Platform.OS === 'ios' ? 50 : 30,
    paddingBottom: SPACING.lg,
  },
  headerCenter: {
    flex: 1,
    alignItems: 'center',
  },
  title: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.textInverse,
  },
  subtitle: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.secondary,
    marginTop: 2,
  },
  headerRight: {
    width: 60,
    alignItems: 'flex-end',
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(215, 166, 56, 0.2)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.secondary,
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.secondary,
    marginRight: 6,
  },
  liveText: {
    color: COLORS.secondary,
    fontSize: 10,
    fontWeight: '600',
  },
  statusBar: {
    backgroundColor: COLORS.cardBackground,
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderLight,
  },
  statusItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
  mapContainer: {
    flex: 1,
    backgroundColor: COLORS.cardBackground,
  },
  mapIframe: {
    width: '100%',
    height: '100%',
    border: 'none',
  },
  mobileMap: {
    flex: 1,
  },
  territoryList: {
    backgroundColor: COLORS.cardBackground,
    padding: SPACING.lg,
    borderTopWidth: 1,
    borderTopColor: COLORS.borderLight,
  },
  territoryListTitle: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginBottom: SPACING.sm,
  },
  territoryItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  territoryColor: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: SPACING.sm,
  },
  territoryName: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
});

export default AdminLiveMapScreen;
