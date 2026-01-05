import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Platform } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { realtimeLocationService } from '../services/RealtimeLocationService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface Worker {
  id: string;
  name: string;
  email: string;
  currentLocation?: {
    latitude: number;
    longitude: number;
    timestamp: number;
  };
  isActive: boolean;
  lastSeen: number;
}

export default function AdminLiveMap() {
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [mapReady, setMapReady] = useState(false);

  // Function to determine worker status and colors
  const getWorkerStatus = (worker: Worker) => {
    const now = Date.now();
    const lastSeenTime = worker.lastSeen || now;
    const timeDiff = now - lastSeenTime;
    const minutesAgo = Math.floor(timeDiff / (1000 * 60));

    if (worker.isActive && minutesAgo < 5) {
      return {
        status: 'online',
        color: '#3b82f6',
        label: '🟢 Online'
      };
    } else if (minutesAgo < 30) {
      return {
        status: 'recent',
        color: '#f59e0b',
        label: '🟡 Recent'
      };
    } else {
      return {
        status: 'offline',
        color: '#9ca3af',
        label: '🔴 Offline'
      };
    }
  };

  useEffect(() => {
    console.log('🗺️ AdminLiveMap: Starting to listen for all workers...');

    // Listen to all workers in real-time
    const unsubscribe = realtimeLocationService.listenToAllWorkers((workersData) => {
      console.log('📊 AdminLiveMap: Received workers data:', workersData.length, 'workers');
      
      const processedWorkers: Worker[] = workersData.map(workerData => ({
        id: workerData.id,
        name: workerData.name,
        email: workerData.email || `${workerData.name.toLowerCase().replace(' ', '.')}@example.com`,
        currentLocation: workerData.currentLocation ? {
          latitude: workerData.currentLocation.latitude,
          longitude: workerData.currentLocation.longitude,
          timestamp: workerData.currentLocation.timestamp,
        } : undefined,
        isActive: workerData.isActive,
        lastSeen: workerData.lastSeen || Date.now(),
      }));

      setWorkers(processedWorkers);

      // Update map with all workers if map is ready
      if (mapReady && Platform.OS === 'web') {
        updateMapWithAllWorkers(processedWorkers);
      }
    });

    return () => {
      unsubscribe();
    };
  }, [mapReady]);

  const updateMapWithAllWorkers = (workersData: Worker[]) => {
    const iframe = document.getElementById('admin-live-map-iframe') as HTMLIFrameElement;
    if (iframe && iframe.contentWindow) {
      const workersWithLocation = workersData.filter(worker => worker.currentLocation);
      
      console.log('🗺️ Updating admin map with', workersWithLocation.length, 'workers');
      
      iframe.contentWindow.postMessage({
        type: 'updateAllWorkers',
        workers: workersWithLocation.map(worker => {
          const status = getWorkerStatus(worker);
          return {
            id: worker.id,
            name: worker.name,
            latitude: worker.currentLocation!.latitude,
            longitude: worker.currentLocation!.longitude,
            timestamp: worker.currentLocation!.timestamp,
            status: status.status,
            color: status.color,
            label: status.label,
            isActive: worker.isActive
          };
        })
      }, '*');
    }
  };

  const handleMapReady = () => {
    console.log('🗺️ AdminLiveMap: Map is ready');
    setMapReady(true);
  };

  useEffect(() => {
    // Listen for map ready message from iframe
    const handleMessage = (event: MessageEvent) => {
      if (event.data.type === 'mapReady') {
        handleMapReady();
      }
    };

    window.addEventListener('message', handleMessage);
    return () => {
      window.removeEventListener('message', handleMessage);
    };
  }, []);

  if (Platform.OS !== 'web') {
    return (
      <View style={styles.modernMobileContainer}>
        <View style={styles.mobileHeader}>
          <MaterialIcons name="map" size={32} color={COLORS.primary} />
          <Text style={styles.modernMobileTitle}>Live Workers Map</Text>
        </View>
        <Text style={styles.modernMobileText}>
          Interactive map available on web version
        </Text>
        <View style={styles.modernWorkersList}>
          {workers.filter(w => w.currentLocation).map(worker => {
            const status = getWorkerStatus(worker);
            return (
              <View key={worker.id} style={styles.modernWorkerItem}>
                <View style={styles.workerItemHeader}>
                  <View style={[styles.statusDot, { backgroundColor: status.color }]} />
                  <Text style={styles.modernWorkerName}>{worker.name}</Text>
                </View>
                <Text style={[styles.modernWorkerStatus, { color: status.color }]}>
                  {status.label}
                </Text>
              </View>
            );
          })}
        </View>
      </View>
    );
  }

  return (
    <View style={styles.modernContainer}>
      <View style={styles.modernHeader}>
        <View style={styles.headerContent}>
          <MaterialIcons name="map" size={24} color={COLORS.primary} />
          <Text style={styles.modernTitle}>Live Workers Map</Text>
        </View>
        <Text style={styles.modernSubtitle}>
          {workers.filter(w => w.isActive).length} active • {workers.filter(w => w.currentLocation).length} total workers
        </Text>
      </View>

      <View style={styles.mapContainer}>
        <iframe
          id="admin-live-map-iframe"
          srcDoc={`
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Live Workers Map</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        #map {
            height: 100vh;
            width: 100%;
        }
        .worker-marker {
            border: 3px solid #ffffff;
            border-radius: 50%;
            width: 16px;
            height: 16px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
            transition: all 0.3s ease;
        }
        .worker-marker.online {
            background: #3b82f6;
            box-shadow: 0 2px 12px rgba(59, 130, 246, 0.5);
        }
        .worker-marker.recent {
            background: #f59e0b;
            box-shadow: 0 2px 12px rgba(245, 158, 11, 0.5);
        }
        .worker-marker.offline {
            background: #9ca3af;
            box-shadow: 0 2px 8px rgba(156, 163, 175, 0.4);
        }
        .worker-popup {
            min-width: 200px;
        }
        .worker-popup-name {
            font-size: 16px;
            font-weight: bold;
            color: #1e293b;
            margin-bottom: 6px;
        }
        .worker-popup-status {
            font-size: 12px;
            font-weight: bold;
            margin-bottom: 4px;
        }
        .worker-popup-coords {
            font-size: 11px;
            color: #64748b;
            font-family: monospace;
            margin-bottom: 4px;
        }
        .worker-popup-time {
            font-size: 10px;
            color: #64748b;
        }
        .legend {
            position: absolute;
            top: 10px;
            right: 10px;
            background: rgba(255, 255, 255, 0.95);
            padding: 12px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            z-index: 1000;
            font-size: 12px;
        }
        .legend-item {
            display: flex;
            align-items: center;
            margin-bottom: 4px;
        }
        .legend-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
            border: 2px solid white;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    
    <div class="legend">
        <div style="font-weight: bold; margin-bottom: 8px;">Workers Status</div>
        <div class="legend-item">
            <div class="legend-dot" style="background: #3b82f6;"></div>
            <span>Online</span>
        </div>
        <div class="legend-item">
            <div class="legend-dot" style="background: #f59e0b;"></div>
            <span>Recent</span>
        </div>
        <div class="legend-item">
            <div class="legend-dot" style="background: #9ca3af;"></div>
            <span>Offline</span>
        </div>
    </div>

    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script>
        let map = null;
        let markers = {};
        let isMapInitialized = false;

        function createWorkerIcon(status) {
            return L.divIcon({
                className: \`worker-marker \${status}\`,
                iconSize: [16, 16],
                iconAnchor: [8, 8]
            });
        }

        function initializeMap() {
            if (isMapInitialized) return;

            // Default center (New York City)
            map = L.map('map', {
                zoomControl: true,
                attributionControl: true
            }).setView([40.7128, -74.0060], 11);

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors'
            }).addTo(map);

            isMapInitialized = true;
            console.log('✅ Admin live map initialized');
            
            // Notify parent that map is ready
            window.parent.postMessage({ type: 'mapReady' }, '*');
        }

        function updateAllWorkers(workers) {
            console.log('📍 Updating admin map with', workers.length, 'workers');

            // Remove markers for workers not in current list
            Object.keys(markers).forEach(workerId => {
                if (!workers.find(w => w.id === workerId)) {
                    map.removeLayer(markers[workerId]);
                    delete markers[workerId];
                }
            });

            // Add or update markers for current workers
            workers.forEach(worker => {
                const icon = createWorkerIcon(worker.status);
                
                if (markers[worker.id]) {
                    // Update existing marker
                    markers[worker.id].setLatLng([worker.latitude, worker.longitude]);
                    markers[worker.id].setIcon(icon);
                } else {
                    // Create new marker
                    markers[worker.id] = L.marker([worker.latitude, worker.longitude], { 
                        icon: icon 
                    }).addTo(map);
                }

                // Update popup content
                const popupContent = \`
                    <div class="worker-popup">
                        <div class="worker-popup-name">👤 \${worker.name}</div>
                        <div class="worker-popup-status" style="color: \${worker.color};">\${worker.label}</div>
                        <div class="worker-popup-coords">\${worker.latitude.toFixed(6)}, \${worker.longitude.toFixed(6)}</div>
                        <div class="worker-popup-time">Updated: \${new Date(worker.timestamp).toLocaleTimeString()}</div>
                    </div>
                \`;
                
                markers[worker.id].bindPopup(popupContent);
            });

            // Auto-fit map to show all workers
            if (workers.length > 0) {
                const group = new L.featureGroup(Object.values(markers));
                map.fitBounds(group.getBounds().pad(0.1));
            }
        }

        window.addEventListener('message', function(event) {
            if (event.data.type === 'updateAllWorkers') {
                updateAllWorkers(event.data.workers);
            }
        });

        // Initialize map when page loads
        window.addEventListener('load', function() {
            initializeMap();
        });
    </script>
</body>
</html>
          `}
          style={{
            width: '100%',
            height: '100%',
            border: 'none',
            borderRadius: '12px',
          }}
          onLoad={handleMapReady}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  // Modern Web Container
  modernContainer: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    margin: SPACING.lg,
    ...SHADOWS.md,
    overflow: 'hidden',
  },
  modernHeader: {
    backgroundColor: COLORS.primary,
    padding: SPACING.lg,
    alignItems: 'center',
  },
  headerContent: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  modernTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.textInverse,
    marginLeft: SPACING.sm,
  },
  modernSubtitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.textInverse,
    opacity: 0.8,
  },
  mapContainer: {
    height: 300,
  },

  // Modern Mobile Container
  modernMobileContainer: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    margin: SPACING.lg,
    padding: SPACING.xl,
    ...SHADOWS.lg,
  },
  mobileHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: SPACING.md,
  },
  modernMobileTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginLeft: SPACING.sm,
  },
  modernMobileText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginBottom: SPACING.lg,
  },
  modernWorkersList: {
    gap: SPACING.md,
  },
  modernWorkerItem: {
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    ...SHADOWS.sm,
  },
  workerItemHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: RADIUS.full,
    marginRight: SPACING.sm,
  },
  modernWorkerName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  modernWorkerStatus: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
});
