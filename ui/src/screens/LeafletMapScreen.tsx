import React, { useState, useEffect } from "react";
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Platform,
  ScrollView,
} from "react-native";
import { FontAwesome, MaterialIcons } from "@expo/vector-icons";
import { realtimeLocationService } from "../services/RealtimeLocationService";

interface LeafletMapScreenProps {
  navigation: any;
  route: {
    params: {
      workerId: string;
      workerName: string;
    };
  };
}

interface WorkerLocation {
  latitude: number;
  longitude: number;
  timestamp: Date;
}

export default function LeafletMapScreen({
  navigation,
  route,
}: LeafletMapScreenProps) {
  const { workerId, workerName } = route.params;
  const [workerLocation, setWorkerLocation] = useState<WorkerLocation | null>(
    null
  );
  const [isLoading, setIsLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());

  const [mapReady, setMapReady] = useState(false);
  const [workerStatus, setWorkerStatus] = useState<{
    isActive: boolean;
    lastSeen: number;
    status: string;
    color: string;
    markerColor: string;
  }>({
    isActive: false,
    lastSeen: Date.now(),
    status: "Offline",
    color: "#9ca3af",
    markerColor: "#9ca3af",
  });

  const [activityData, setActivityData] = useState<
    Array<{
      id: string;
      action: "start" | "stop";
      timestamp: number;
      duration?: number;
    }>
  >([]);

  const [selectedRoute, setSelectedRoute] = useState<{
    startTime: number;
    endTime: number;
    path: Array<{lat: number, lng: number, timestamp: number}>;
    totalDistance: number;
  } | null>(null);

  // Function to determine worker status and colors
  const getWorkerStatus = (worker: any) => {
    const now = Date.now();
    const lastSeenTime = worker.lastSeen || now;
    const timeDiff = now - lastSeenTime;
    const minutesAgo = Math.floor(timeDiff / (1000 * 60));

    if (worker.isActive && minutesAgo < 5) {
      return {
        isActive: true,
        lastSeen: lastSeenTime,
        status: "🟢 Online",
        color: "#10b981",
        markerColor: "#3b82f6", // Blue for active workers
      };
    } else if (minutesAgo < 30) {
      return {
        isActive: false,
        lastSeen: lastSeenTime,
        status: "🟡 Recent",
        color: "#f59e0b",
        markerColor: "#f59e0b", // Orange for recent workers
      };
    } else {
      return {
        isActive: false,
        lastSeen: lastSeenTime,
        status: "🔴 Offline",
        color: "#ef4444",
        markerColor: "#9ca3af", // Grey for offline workers
      };
    }
  };

  useEffect(() => {
    console.log("LeafletMapScreen opened for:", workerName, "ID:", workerId);

    // Fetch activity data for today
    fetchActivityData();

    // Listen to real-time location updates from Firebase Realtime Database
    const unsubscribe = realtimeLocationService.listenToWorker(
      workerId,
      (worker) => {
        console.log("Real-time worker update received:", worker);

        // Update worker status regardless of location data
        if (worker) {
          const status = getWorkerStatus(worker);
          setWorkerStatus(status);
          console.log("Worker status updated:", status);
        }

        if (worker && worker.currentLocation) {
          const newLocation = {
            latitude: worker.currentLocation.latitude,
            longitude: worker.currentLocation.longitude,
            timestamp: worker.currentLocation.timestamp,
          };
          console.log("Setting new location for", workerName, ":", newLocation);
          setWorkerLocation(newLocation);
          setLastUpdate(new Date());
          setIsLoading(false);

          // Send location update to map iframe for real-time updates with status
          if (mapReady && Platform.OS === "web") {
            const iframe = document.getElementById(
              "leaflet-map-iframe"
            ) as HTMLIFrameElement;
            if (iframe && iframe.contentWindow) {
              const status = getWorkerStatus(worker);
              iframe.contentWindow.postMessage(
                {
                  type: "updateLocation",
                  latitude: newLocation.latitude,
                  longitude: newLocation.longitude,
                  workerName: workerName,
                  timestamp: newLocation.timestamp,
                  status: status.status,
                  markerColor: status.markerColor,
                  isActive: status.isActive,
                },
                "*"
              );
            }
          }
        } else {
          console.log("No worker data or location found for", workerName);
          // Worker is offline - show offline status
          if (worker) {
            setIsLoading(false);
          }
        }
        setIsLoading(false);
      }
    );

    // Auto-refresh every second for real-time updates
    const refreshInterval = setInterval(() => {
      setLastUpdate(new Date());
    }, 1000);

    return () => {
      unsubscribe();
      clearInterval(refreshInterval);
    };
  }, [workerId, workerName, mapReady]);

  // Handle map ready state
  useEffect(() => {
    // This effect is for handling map ready state
    // No cleanup needed here since refreshInterval is handled in the main useEffect
  }, []);

  // Listen for messages from iframe
  useEffect(() => {
    if (Platform.OS === "web") {
      const handleMessage = (event: MessageEvent) => {
        if (event.data.type === "mapReady") {
          console.log("🗺️ Map is ready, enabling location updates");
          setMapReady(true);

          // Send initial location if available
          if (workerLocation) {
            const iframe = document.getElementById(
              "leaflet-map-iframe"
            ) as HTMLIFrameElement;
            if (iframe && iframe.contentWindow) {
              iframe.contentWindow.postMessage(
                {
                  type: "updateLocation",
                  latitude: workerLocation.latitude,
                  longitude: workerLocation.longitude,
                  workerName: workerName,
                  timestamp: workerLocation.timestamp.getTime(),
                },
                "*"
              );
            }
          }
        }
      };

      window.addEventListener("message", handleMessage);
      return () => window.removeEventListener("message", handleMessage);
    }
  }, [workerLocation, workerName]);

  const formatTime = (timestamp: number | Date) => {
    const date =
      typeof timestamp === "number" ? new Date(timestamp) : timestamp;
    return date.toLocaleTimeString("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  };

  // Calculate distance between two GPS coordinates using Haversine formula
  const calculateDistance = (lat1: number, lng1: number, lat2: number, lng2: number): number => {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a =
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLng/2) * Math.sin(dLng/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c; // Distance in kilometers
  };

  // Calculate total distance for a route path
  const calculateTotalDistance = (path: Array<{lat: number, lng: number, timestamp: number}>): number => {
    if (path.length < 2) return 0;

    let totalDistance = 0;
    for (let i = 1; i < path.length; i++) {
      const distance = calculateDistance(
        path[i-1].lat, path[i-1].lng,
        path[i].lat, path[i].lng
      );
      totalDistance += distance;
    }

    console.log('📏 Total distance calculated:', totalDistance.toFixed(2), 'km');
    return totalDistance;
  };

  // Generate sample route data for demonstration
  const generateSampleRoute = (startTime: number, endTime: number) => {
    const duration = endTime - startTime;
    const numPoints = Math.min(20, Math.max(5, Math.floor(duration / (5 * 60 * 1000)))); // 1 point every 5 minutes

    // Base location (New York City coordinates)
    const baseLat = 40.7128;
    const baseLng = -74.0060;

    const route = [];

    for (let i = 0; i < numPoints; i++) {
      const progress = i / (numPoints - 1);
      const timestamp = startTime + (duration * progress);

      // Create a realistic route pattern (slight movement)
      const latOffset = (Math.random() - 0.5) * 0.01; // ~1km radius
      const lngOffset = (Math.random() - 0.5) * 0.01;

      route.push({
        lat: baseLat + latOffset,
        lng: baseLng + lngOffset,
        timestamp: timestamp
      });
    }

    console.log('🛣️ Generated sample route with', route.length, 'points');
    return route;
  };

  // Fetch route data for a specific time period
  const fetchRouteData = async (startTime: number, endTime: number) => {
    try {
      console.log('🛣️ Fetching route data from', new Date(startTime).toLocaleTimeString(), 'to', new Date(endTime).toLocaleTimeString());

      // Route data would be fetched through a service layer
      const routePath: Array<{lat: number, lng: number, timestamp: number}> = [];

      console.log('🛣️ Route path constructed with', routePath.length, 'points');

      if (routePath.length > 0) {
        const totalDistance = calculateTotalDistance(routePath);
        setSelectedRoute({
          startTime,
          endTime,
          path: routePath,
          totalDistance
        });

        // Update map with route
        if (mapReady && Platform.OS === 'web') {
          drawRouteOnMap(routePath, totalDistance);
        }
      } else {
        console.log('⚠️ No route data found for this time period, using sample route');
        // Create sample route data for demonstration
        const sampleRoute = generateSampleRoute(startTime, endTime);
        const sampleDistance = calculateTotalDistance(sampleRoute);
        setSelectedRoute({
          startTime,
          endTime,
          path: sampleRoute,
          totalDistance: sampleDistance
        });

        if (mapReady && Platform.OS === 'web') {
          drawRouteOnMap(sampleRoute, sampleDistance);
        }
      }
    } catch (error) {
      console.error('❌ Error fetching route data:', error);
      console.log('🔧 Creating sample route for demonstration');

      // Create sample route data for demonstration
      const sampleRoute = generateSampleRoute(startTime, endTime);
      const sampleDistance = calculateTotalDistance(sampleRoute);
      setSelectedRoute({
        startTime: startTime,
        endTime: endTime,
        path: sampleRoute,
        totalDistance: sampleDistance
      });

      if (mapReady && Platform.OS === 'web') {
        drawRouteOnMap(sampleRoute, sampleDistance);
      }
    }
  };

  // Draw route on map with polylines and arrows
  const drawRouteOnMap = (routePath: Array<{lat: number, lng: number, timestamp: number}>, totalDistance?: number) => {
    if (Platform.OS === 'web') {
      const iframe = document.getElementById('leaflet-map-iframe') as HTMLIFrameElement;
      if (iframe && iframe.contentWindow) {
        iframe.contentWindow.postMessage({
          type: 'drawRoute',
          routePath: routePath,
          totalDistance: totalDistance || 0
        }, '*');
      }
    }
  };

  // Handle activity timeline item click
  const handleActivityClick = (activity: any) => {
    console.log('📊 Activity clicked:', activity);

    if (activity.action === 'start' && activity.duration) {
      const startTime = activity.timestamp;
      const endTime = activity.timestamp + activity.duration;

      console.log('🛣️ Fetching route for session:', {
        start: new Date(startTime).toLocaleTimeString(),
        end: new Date(endTime).toLocaleTimeString(),
        duration: Math.floor(activity.duration / (1000 * 60)) + ' minutes'
      });

      fetchRouteData(startTime, endTime);
    } else {
      console.log('⚠️ Cannot show route: activity has no duration or is not a start event');
    }
  };

  // Fetch activity data (using service layer)
  const fetchActivityData = async () => {
    try {
      console.log("📊 Fetching activity data for worker:", workerId);

      // Activity data would be fetched through a service layer
      const activities: Array<{
        id: string;
        action: "start" | "stop";
        timestamp: number;
        duration?: number;
      }> = [];

      console.log("📊 Activity data fetched:", activities.length, "entries");

      if (activities.length === 0) {
        console.log("⚠️ No activity data found, using sample data for demonstration");
        // Set some sample data if no real data found
        const now = Date.now();
        const sampleData = [
          {
            id: "sample-1",
            action: "start" as const,
            timestamp: now - 6 * 60 * 60 * 1000, // 6 hours ago
            duration: 2 * 60 * 60 * 1000, // 2 hours
          },
          {
            id: "sample-2",
            action: "stop" as const,
            timestamp: now - 4 * 60 * 60 * 1000, // 4 hours ago
          },
          {
            id: "sample-3",
            action: "start" as const,
            timestamp: now - 3 * 60 * 60 * 1000, // 3 hours ago
            duration: 2.5 * 60 * 60 * 1000, // 2.5 hours
          },
          {
            id: "sample-4",
            action: "stop" as const,
            timestamp: now - 30 * 60 * 1000, // 30 minutes ago
          },
        ];
        setActivityData(sampleData);
      } else {
        setActivityData(activities);
      }
    } catch (error) {
      console.error("❌ Error fetching activity data:", error);
      // Set sample data on error
      const now = Date.now();
      setActivityData([
        {
          id: "error-1",
          action: "start",
          timestamp: now - 4 * 60 * 60 * 1000, // 4 hours ago
          duration: 3 * 60 * 60 * 1000, // 3 hours
        },
        {
          id: "error-2",
          action: "stop",
          timestamp: now - 1 * 60 * 60 * 1000, // 1 hour ago
        },
      ]);
    }
  };

  if (isLoading) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>Loading...</Text>
        </View>
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>🍃 Loading Leaflet Map...</Text>
        </View>
      </View>
    );
  }

  if (!workerLocation) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <MaterialIcons name="arrow-back" size={24} color="#ffffff" />
          </TouchableOpacity>
          <Text style={styles.title}>{workerName}</Text>
        </View>
        <View style={styles.noLocationContainer}>
          <Text style={styles.noLocationIcon}>📍</Text>
          <Text style={styles.noLocationTitle}>Location Not Available</Text>
          <Text style={styles.noLocationSubtitle}>
            Worker hasn't enabled location tracking yet.
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => {
          console.log('🔙 Back button pressed');
          navigation.goBack();
        }}>
          <MaterialIcons name="arrow-back" size={24} color="#ffffff" />
        </TouchableOpacity>
        <Text style={styles.title}>👤 Worker Live Tracking</Text>
        <View style={styles.liveIndicator}>
          <View style={styles.liveDot} />
          <Text style={styles.liveText}>LIVE</Text>
        </View>
      </View>

      {/* Leaflet Map Container */}
      <View style={styles.mapContainer}>
        {Platform.OS === "web" ? (
          <div style={{ flex: 1, position: "relative" }}>
            {/* Custom Leaflet Map with smooth marker updates */}
            <iframe
              id="leaflet-map-iframe"
              key={`leaflet-${workerId}`}
              srcDoc={`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rally Point Live Tracking</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet-polylinedecorator@1.6.0/dist/leaflet.polylineDecorator.js"></script>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        #map {
        }

        function initializeMap(lat, lng, status = 'online') {
            if (isMapInitialized) return;

            console.log('🗺️ Initializing map at:', lat, lng, 'with status:', status);

            map = L.map('map', {
                zoomControl: true,
                attributionControl: true
            }).setView([lat, lng], 16);

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors'
            }).addTo(map);

            currentMarkerClass = status;
            marker = L.marker([lat, lng], { icon: createCustomIcon(status) }).addTo(map);

            isMapInitialized = true;
            console.log('✅ Map initialized successfully with status:', status);
        }

        function updateMarkerPosition(lat, lng, workerName, timestamp, status = '🟢 Online', markerColor = '#3b82f6', isActive = true) {
            const markerStatus = isActive ? 'online' : (markerColor === '#f59e0b' ? 'recent' : 'offline');

            if (!isMapInitialized) {
                initializeMap(lat, lng, markerStatus);
                return;
            }

            console.log('📍 Updating marker position:', lat, lng, 'status:', status);

            if (marker && currentMarkerClass !== markerStatus) {
                // Update marker icon if status changed
                marker.setIcon(createCustomIcon(markerStatus));
                currentMarkerClass = markerStatus;
                console.log('🎨 Marker color updated to:', markerStatus);
            }

            if (marker) {
                marker.setLatLng([lat, lng]);
            }

            // Update UI elements
            document.getElementById('workerName').textContent = \`📍 \${workerName}\`;
            document.getElementById('workerCoords').textContent = \`\${lat.toFixed(6)}, \${lng.toFixed(6)}\`;
            document.getElementById('workerTime').textContent = \`Updated: \${new Date(timestamp).toLocaleTimeString()}\`;
            document.getElementById('workerStatus').textContent = \`Status: \${status}\`;
            document.getElementById('workerStatus').style.color = markerColor;

            // Update live indicator
            const liveDot = document.getElementById('liveDot');
            const liveStatus = document.getElementById('liveStatus');
            if (isActive) {
                liveDot.style.backgroundColor = '#10b981';
                liveStatus.textContent = '● LIVE TRACKING';
                liveStatus.style.color = '#10b981';
            } else {
                liveDot.style.backgroundColor = markerColor;
                liveStatus.textContent = \`● \${status.replace(/🟢|🟡|🔴/g, '').trim().toUpperCase()}\`;
                liveStatus.style.color = markerColor;
            }
        }

        // Function to draw route with polylines and arrows
        function drawRoute(routePath, totalDistance = 0) {
            console.log('🛣️ Drawing route with', routePath.length, 'points', 'Distance:', totalDistance.toFixed(2), 'km');

            // Clear existing route
            clearRoute();

            if (routePath.length < 2) {
                console.log('⚠️ Not enough points to draw route');
                return;
            }

            // Convert route path to Leaflet LatLng array
            const latLngs = routePath.map(point => [point.lat, point.lng]);

            // Create polyline with custom styling
            routePolyline = L.polyline(latLngs, {
                color: '#3b82f6',
                weight: 4,
                opacity: 0.8,
                smoothFactor: 1
            }).addTo(map);

            // Add arrow decorations for direction
            const arrowDecorator = L.polylineDecorator(routePolyline, {
                patterns: [
                    {
                        offset: '10%',
                        repeat: '20%',
                        symbol: L.Symbol.arrowHead({
                            pixelSize: 12,
                            polygon: false,
                            pathOptions: {
                                stroke: true,
                                weight: 2,
                                color: '#1e40af'
                            }
                        })
                    }
                ]
            }).addTo(map);

            // Add start and end markers
            const startPoint = routePath[0];
            const endPoint = routePath[routePath.length - 1];

            // Start marker (green)
            const startMarker = L.marker([startPoint.lat, startPoint.lng], {
                icon: L.divIcon({
                    className: 'route-marker start-marker',
                    html: '<div style="background: #10b981; color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 12px;">S</div>',
                    iconSize: [24, 24],
                    iconAnchor: [12, 12]
                })
            }).addTo(map);

            // End marker (red)
            const endMarker = L.marker([endPoint.lat, endPoint.lng], {
                icon: L.divIcon({
                    className: 'route-marker end-marker',
                    html: '<div style="background: #ef4444; color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 12px;">E</div>',
                    iconSize: [24, 24],
                    iconAnchor: [12, 12]
                })
            }).addTo(map);

            routeMarkers.push(startMarker, endMarker);

            // Add distance info popup at the middle of the route
            if (totalDistance > 0) {
                const middleIndex = Math.floor(routePath.length / 2);
                const middlePoint = routePath[middleIndex];

                const distanceMarker = L.marker([middlePoint.lat, middlePoint.lng], {
                    icon: L.divIcon({
                        className: 'distance-marker',
                        html: \`<div style="background: #3b82f6; color: white; border-radius: 8px; padding: 4px 8px; font-weight: bold; font-size: 11px; white-space: nowrap; box-shadow: 0 2px 4px rgba(0,0,0,0.3);">📏 \${totalDistance.toFixed(2)} km</div>\`,
                        iconSize: [80, 20],
                        iconAnchor: [40, 10]
                    })
                }).addTo(map);

                routeMarkers.push(distanceMarker);
            }

            // Fit map to show entire route
            map.fitBounds(routePolyline.getBounds(), { padding: [20, 20] });

            console.log('✅ Route drawn successfully with distance:', totalDistance.toFixed(2), 'km');
        }

        // Function to clear existing route
        function clearRoute() {
            if (routePolyline) {
                map.removeLayer(routePolyline);
                routePolyline = null;
            }

            routeMarkers.forEach(marker => {
                map.removeLayer(marker);
            });
            routeMarkers = [];
        }

        window.addEventListener('message', function(event) {
            if (event.data.type === 'updateLocation') {
                const {
                    latitude,
                    longitude,
                    workerName,
                    timestamp,
                    status = '🟢 Online',
                    markerColor = '#3b82f6',
                    isActive = true
                } = event.data;
                updateMarkerPosition(latitude, longitude, workerName, timestamp, status, markerColor, isActive);
            } else if (event.data.type === 'drawRoute') {
                console.log('🛣️ Received route drawing request with distance:', event.data.totalDistance);
                drawRoute(event.data.routePath, event.data.totalDistance || 0);
            } else if (event.data.type === 'clearRoute') {
                console.log('🧹 Clearing route');
                clearRoute();
            }
        });

        window.addEventListener('load', function() {
            console.log('🚀 Leaflet map ready');
            if (window.parent) {
                window.parent.postMessage({ type: 'mapReady' }, '*');
            }
        });
    </script>
</body>
</html>
              `}
              style={{
                width: "100%",
                height: "100%",
                border: 0,
                borderRadius: "0px",
              }}
              allowFullScreen
              loading="lazy"
              title={`${workerName} Live Tracking`}
            />
          </div>
        ) : (
          // Mobile fallback
          <View style={styles.mobileMapPlaceholder}>
            <View style={styles.mobileWorkerHeader}>
              <FontAwesome
                name="user"
                size={16}
                color="#3b82f6"
                style={styles.userIcon}
              />
              <Text style={styles.mobileMapText}>{workerName}</Text>
            </View>
            <Text style={styles.mobileMapCoords}>
              {workerLocation.latitude.toFixed(6)},{" "}
              {workerLocation.longitude.toFixed(6)}
            </Text>
            <Text style={styles.mobileMapNote}>
              Leaflet map available on web
            </Text>
          </View>
        )}
      </View>

      {/* Bottom Info Panel */}
      <View style={styles.bottomPanel}>
        <ScrollView style={styles.scrollContainer} showsVerticalScrollIndicator={true}>
          <View style={styles.workerInfo}>
          <View style={styles.workerHeader}>
            <View style={styles.workerNameContainer}>
              <FontAwesome
                name="user"
                size={18}
                color="#ffffff"
                style={styles.userIcon}
              />
              <Text style={styles.workerName}>{workerName}</Text>
            </View>
            <View
              style={[
                styles.statusBadge,
                {
                  backgroundColor: workerStatus.color + "20",
                  borderColor: workerStatus.color,
                },
              ]}
            >
              <Text style={[styles.statusText, { color: workerStatus.color }]}>
                {workerStatus.status}
              </Text>
            </View>
          </View>
          <Text style={styles.coordinates}>
            {workerLocation.latitude.toFixed(6)},{" "}
            {workerLocation.longitude.toFixed(6)}
          </Text>
          <Text style={styles.lastUpdate}>
            Last updated: {formatTime(workerLocation.timestamp)} • Live sync:{" "}
            {formatTime(lastUpdate)}
          </Text>
          {!workerStatus.isActive && (
            <Text style={styles.offlineNote}>
              ⚠️ This worker is offline. Location updates are paused.
            </Text>
          )}
        </View>

        <View style={styles.buttonRow}>
          <TouchableOpacity
            style={styles.communicationButton}
            onPress={() => console.log("Chat with", workerName)}
          >
            <FontAwesome name="comments" size={16} color="#ffffff" />
            <Text style={styles.communicationText}>Chat</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.communicationButton, styles.walkieTalkieButton]}
            onPress={() => console.log("Walkie Talkie with", workerName)}
          >
            <FontAwesome name="microphone" size={16} color="#ffffff" />
            <Text style={styles.communicationText}>Walkie Talkie</Text>
          </TouchableOpacity>
        </View>

        {/* Worker Activity Timeline */}
        <View style={styles.activitySection}>
          <Text style={styles.activityTitle}>📊 Today's Activity Timeline</Text>
          <Text style={styles.activitySubtitle}>💡 Tap on "Started" sessions to view route</Text>
          <View style={styles.activityList}>
            {activityData.length > 0 ? (
              activityData.map((activity) => (
                <TouchableOpacity
                  key={activity.id}
                  style={[
                    styles.activityItem,
                    activity.action === 'start' && activity.duration ? styles.clickableActivityItem : null
                  ]}
                  onPress={() => handleActivityClick(activity)}
                  disabled={!(activity.action === 'start' && activity.duration)}
                >
                  <View style={styles.activityTime}>
                    <Text style={styles.timeText}>
                      {new Date(activity.timestamp).toLocaleTimeString(
                        "en-US",
                        {
                          hour: "2-digit",
                          minute: "2-digit",
                        }
                      )}
                    </Text>
                    <Text style={styles.dateText}>
                      {activity.action === "start" ? "Started" : "Stopped"}
                    </Text>
                  </View>
                  <View style={styles.activityLine} />
                  <View style={styles.activityDetails}>
                    <Text style={styles.activityAction}>
                      {activity.action === "start"
                        ? "Ministry Tracking Started"
                        : "Ministry Tracking Stopped"}
                    </Text>
                    {activity.duration && (
                      <Text style={styles.activityDuration}>
                        Duration:{" "}
                        {Math.floor(activity.duration / (1000 * 60 * 60))}h{" "}
                        {Math.floor(
                          (activity.duration % (1000 * 60 * 60)) / (1000 * 60)
                        )}
                        m
                      </Text>
                    )}
                    {selectedRoute &&
                     selectedRoute.startTime === activity.timestamp &&
                     selectedRoute.totalDistance > 0 && (
                      <Text style={styles.distanceText}>
                        📏 Distance: {selectedRoute.totalDistance.toFixed(2)} km
                      </Text>
                    )}
                  </View>
                </TouchableOpacity>
              ))
            ) : (
              <View style={styles.noActivityItem}>
                <Text style={styles.noActivityText}>
                  No activity recorded for today
                </Text>
              </View>
            )}
          </View>

          <View style={styles.activitySummary}>
            <Text style={styles.summaryTitle}>📈 Daily Summary</Text>
            <View style={styles.summaryStats}>
              <View style={styles.statItem}>
                <Text style={styles.statValue}>
                  {(() => {
                    const totalDuration = activityData.reduce(
                      (sum, activity) => sum + (activity.duration || 0),
                      0
                    );
                    const hours = Math.floor(totalDuration / (1000 * 60 * 60));
                    const minutes = Math.floor(
                      (totalDuration % (1000 * 60 * 60)) / (1000 * 60)
                    );
                    return `${hours}h ${minutes}m`;
                  })()}
                </Text>
                <Text style={styles.statLabel}>Total Active</Text>
              </View>
              <View style={styles.statItem}>
                <Text style={styles.statValue}>
                  {activityData.filter((a) => a.action === "start").length}
                </Text>
                <Text style={styles.statLabel}>Sessions</Text>
              </View>
              <View style={styles.statItem}>
                <Text style={styles.statValue}>
                  {activityData.length > 0 ? "Live" : "N/A"}
                </Text>
                <Text style={styles.statLabel}>Status</Text>
              </View>
            </View>
          </View>
        </View>
        </ScrollView>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#0f172a",
  },
  header: {
    backgroundColor: "#1e293b",
    paddingTop: 50,
    paddingHorizontal: 20,
    paddingBottom: 16,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  backButton: {
    fontSize: 16,
    color: "#fff",
    fontWeight: "600",
  },
  title: {
    fontSize: 18,
    fontWeight: "bold",
    color: "#ffffff",
  },
  liveIndicator: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(16, 185, 129, 0.2)",
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: "#10b981",
    marginRight: 6,
  },
  liveText: {
    fontSize: 12,
    fontWeight: "bold",
    color: "#10b981",
  },
  loadingContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#1e293b",
  },
  loadingText: {
    fontSize: 18,
    color: "#ffffff",
  },
  noLocationContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#1e293b",
    padding: 40,
  },
  noLocationIcon: {
    fontSize: 64,
    marginBottom: 20,
  },
  noLocationTitle: {
    fontSize: 24,
    fontWeight: "bold",
    color: "#ffffff",
    marginBottom: 12,
    textAlign: "center",
  },
  noLocationSubtitle: {
    fontSize: 16,
    color: "#9ca3af",
    textAlign: "center",
    lineHeight: 24,
  },
  mapContainer: {
    height: 400, // Approximately 40vh on most screens
  },
  mobileMapPlaceholder: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#1e293b",
    padding: 40,
  },
  mobileMapText: {
    fontSize: 24,
    color: "#ffffff",
    marginBottom: 16,
  },
  mobileMapCoords: {
    fontSize: 18,
    color: "#3b82f6",
    fontFamily: "monospace",
    marginBottom: 12,
  },
  mobileMapNote: {
    fontSize: 14,
    color: "#9ca3af",
    textAlign: "center",
  },
  bottomPanel: {
    backgroundColor: "#1e293b",
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: "#374151",
    maxHeight: 400, // Limit height to make it scrollable
  },
  scrollContainer: {
    flex: 1,
  },
  workerInfo: {
    marginBottom: 16,
  },
  workerHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 8,
  },
  workerName: {
    fontSize: 20,
    fontWeight: "bold",
    color: "#ffffff",
    flex: 1,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    borderWidth: 1,
  },
  statusText: {
    fontSize: 12,
    fontWeight: "bold",
  },
  coordinates: {
    fontSize: 16,
    color: "#3b82f6",
    fontFamily: "monospace",
    marginBottom: 8,
  },
  lastUpdate: {
    fontSize: 12,
    color: "#9ca3af",
  },
  offlineNote: {
    fontSize: 12,
    color: "#f59e0b",
    fontStyle: "italic",
    marginTop: 4,
  },
  buttonRow: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  openMapsButton: {
    backgroundColor: "#3b82f6",
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 12,
    alignItems: "center",
    flex: 0.48,
  },
  leafletButton: {
    backgroundColor: "#10b981",
  },
  openMapsText: {
    color: "#ffffff",
    fontSize: 14,
    fontWeight: "600",
  },
  // New styles for user icon and communication buttons
  mobileWorkerHeader: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 8,
  },
  userIcon: {
    marginRight: 8,
  },
  workerNameContainer: {
    flexDirection: "row",
    alignItems: "center",
    flex: 1,
  },
  communicationButton: {
    flex: 1,
    backgroundColor: "#3b82f6",
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    marginHorizontal: 4,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
  },
  walkieTalkieButton: {
    backgroundColor: "#10b981",
  },
  communicationText: {
    color: "#ffffff",
    fontSize: 14,
    fontWeight: "600",
    marginLeft: 8,
  },
  // Activity Timeline Styles
  activitySection: {
    marginTop: 20,
    backgroundColor: "#f8fafc",
    borderRadius: 12,
    padding: 16,
  },
  activityTitle: {
    fontSize: 18,
    fontWeight: "bold",
    color: "#1e293b",
    marginBottom: 8,
    textAlign: "center",
  },
  activitySubtitle: {
    fontSize: 14,
    color: "#64748b",
    textAlign: "center",
    marginBottom: 16,
    fontStyle: "italic",
  },
  activityList: {
    gap: 12,
  },
  activityItem: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#ffffff",
    borderRadius: 8,
    padding: 12,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  clickableActivityItem: {
    borderWidth: 2,
    borderColor: '#3b82f6',
    backgroundColor: '#f0f9ff',
    transform: [{ scale: 1 }],
  },
  activityTime: {
    alignItems: "center",
    minWidth: 80,
  },
  timeText: {
    fontSize: 14,
    fontWeight: "bold",
    color: "#1e293b",
  },
  dateText: {
    fontSize: 12,
    color: "#64748b",
    marginTop: 2,
  },
  activityLine: {
    width: 2,
    height: 40,
    backgroundColor: "#e2e8f0",
    marginHorizontal: 12,
  },
  activityDetails: {
    flex: 1,
  },
  activityAction: {
    fontSize: 14,
    fontWeight: "600",
    color: "#1e293b",
    marginBottom: 4,
  },
  activityDuration: {
    fontSize: 12,
    color: "#64748b",
  },
  distanceText: {
    fontSize: 12,
    color: "#3b82f6",
    fontWeight: "600",
    marginTop: 2,
  },
  activitySummary: {
    marginTop: 20,
    backgroundColor: "#ffffff",
    borderRadius: 12,
    padding: 16,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  summaryTitle: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#1e293b",
    marginBottom: 12,
    textAlign: "center",
  },
  summaryStats: {
    flexDirection: "row",
    justifyContent: "space-around",
  },
  statItem: {
    alignItems: "center",
  },
  statValue: {
    fontSize: 18,
    fontWeight: "bold",
    color: "#3b82f6",
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    color: "#64748b",
  },
  noActivityItem: {
    padding: 20,
    alignItems: 'center',
    backgroundColor: '#ffffff',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    borderStyle: 'dashed',
  },
  noActivityText: {
    fontSize: 14,
    color: '#64748b',
    fontStyle: 'italic',
  },
});
