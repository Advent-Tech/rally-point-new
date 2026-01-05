import React, { useState, useEffect, useRef } from 'react';
import { View, StyleSheet, Platform, Dimensions, Text } from 'react-native';
import { WebView } from 'react-native-webview';
import { Territory } from '../services/TerritoryService';
import { BookDelivery } from '../types/ministry';
import { PathPoint } from '../services/MinistrySessionService';

const { width, height } = Dimensions.get('window');

interface TerritoryMapProps {
  territories: Territory[];
  selectedTerritory?: Territory | null;
  currentLocation?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
  } | null;
  onTerritoryPress?: (territory: Territory) => void;
  onToggleActionPanel?: () => void;
  showUserLocation?: boolean;
  isInsideTerritory?: boolean;
  workerName?: string;
  centerOnWorker?: boolean;
  deliveries?: BookDelivery[];
  showDeliveries?: boolean;
  onDeliveryPress?: (delivery: BookDelivery) => void;
  // Path visualization props
  pathPoints?: PathPoint[];
  showPath?: boolean;
  pathColor?: string;
  style?: any;
}

const TerritoryMap: React.FC<TerritoryMapProps> = ({
  territories,
  selectedTerritory,
  currentLocation,
  onTerritoryPress,
  onToggleActionPanel,
  showUserLocation = true,
  isInsideTerritory = true,
  workerName = 'Worker',
  centerOnWorker = false,
  deliveries = [],
  showDeliveries = false,
  onDeliveryPress,
  // Path visualization props
  pathPoints = [],
  showPath = false,
  pathColor = '#002b5b',
  style,
}) => {
  const [mapReady, setMapReady] = useState(false);
  const webViewRef = useRef<WebView>(null);

  // Send territories data to WebView (only when territories change, not location)
  useEffect(() => {
    if (mapReady && webViewRef.current) {
      // Send territories data to map
      const message = JSON.stringify({
        type: 'updateTerritories',
        territories: territories,
        selectedTerritory: selectedTerritory,
        showUserLocation: showUserLocation,
        workerName: workerName,
        deliveries: showDeliveries ? deliveries : [],
        showDeliveries: showDeliveries,
      });

      console.log('📱 Sending territories to mobile map:', territories.length);
      webViewRef.current.postMessage(message);
    }
  }, [territories, selectedTerritory, showUserLocation, workerName, mapReady]);

  // Separate effect for worker location updates (only update marker, not full map)
  useEffect(() => {
    if (mapReady && webViewRef.current && currentLocation) {
      const message = JSON.stringify({
        type: 'updateWorkerLocation',
        currentLocation: currentLocation,
        isInsideTerritory: isInsideTerritory,
        centerOnWorker: centerOnWorker,
      });

      console.log('📍 Updating worker location marker only:', {
        lat: currentLocation.latitude.toFixed(6),
        lng: currentLocation.longitude.toFixed(6)
      });
      webViewRef.current.postMessage(message);
    }
  }, [currentLocation, isInsideTerritory, centerOnWorker, mapReady]);

  // Send path data to WebView when path changes
  useEffect(() => {
    if (mapReady && webViewRef.current && showPath && pathPoints.length > 0) {
      const pathData = pathPoints.map(point => ({
        lat: point.latitude,
        lng: point.longitude,
        timestamp: point.timestamp
      }));

      console.log('🛣️ Updating worker path with', pathData.length, 'points');
      webViewRef.current.postMessage(JSON.stringify({
        type: 'updatePath',
        pathData: pathData,
        pathColor: pathColor,
        showPath: showPath
      }));
    } else if (mapReady && webViewRef.current && !showPath) {
      // Clear path if showPath is false
      webViewRef.current.postMessage(JSON.stringify({
        type: 'clearPath'
      }));
    }
  }, [mapReady, pathPoints, showPath, pathColor]);

  const handleWebViewMessage = (event: any) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      console.log('📱 Received message from mobile map:', data);

      if (data.type === 'mapReady') {
        console.log('🗺️ Mobile territory map is ready');
        setMapReady(true);
      } else if (data.type === 'territoryPressed' && onTerritoryPress) {
        const territory = territories.find(t => t.id === data.territoryId);
        if (territory) {
          console.log('🗺️ Territory pressed:', territory.name);
          onTerritoryPress(territory);
        }
      } else if (data.type === 'toggleActionPanel' && onToggleActionPanel) {
        console.log('🗺️ Mobile map: Toggle action panel requested');
        onToggleActionPanel();
      } else if (data.type === 'deliveryPressed' && onDeliveryPress) {
        const delivery = deliveries.find(d => d.id === data.deliveryId);
        if (delivery) {
          console.log('📦 Delivery pressed:', delivery.bookTitle);
          onDeliveryPress(delivery);
        }
      }
    } catch (error) {
      console.error('Error parsing WebView message:', error);
    }
  };

  const getMapHTML = () => {
    return `
      <!DOCTYPE html>
      <html>
      <head>
          <title>Territory Map</title>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
          <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
          <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
          <style>
              body {
                  margin: 0;
                  padding: 0;
                  font-family: Arial, sans-serif;
                  touch-action: manipulation;
              }
              #map {
                  height: 100vh;
                  width: 100%;
                  touch-action: manipulation;
              }
              .territory-popup {
                  font-family: Arial, sans-serif;
                  text-align: center;
              }
              .territory-popup-name {
                  font-weight: bold;
                  color: #002b5b;
                  margin-bottom: 4px;
                  font-size: 14px;
              }
              .territory-popup-info {
                  color: #64748b;
                  font-size: 12px;
              }
              .worker-popup {
                  font-family: Arial, sans-serif;
                  text-align: center;
              }
              .worker-popup-name {
                  font-weight: bold;
                  color: #d7a638;
                  margin-bottom: 4px;
                  font-size: 14px;
              }
              .worker-popup-status {
                  color: #64748b;
                  font-size: 12px;
              }
              .leaflet-control-zoom {
                  font-size: 18px !important;
              }
              .leaflet-control-zoom a {
                  width: 40px !important;
                  height: 40px !important;
                  line-height: 40px !important;
                  font-size: 20px !important;
              }
          </style>
      </head>
      <body>
          <div id="map"></div>
          <script>
              let map;
              let territories = [];
              let territoryLayers = [];
              let workerMarker = null;
              let accuracyCircle = null;
              let currentData = null;
              let mapCenteredRef = { current: false };
              // Path visualization variables
              let pathPolyline = null;
              let pathPoints = [];
              let pathColor = '#002b5b';

              function initMap() {
                  console.log('🗺️ Initializing mobile territory map');

                  // Initialize map at India center instead of New York
                  // This will be updated with real GPS location when available
                  map = L.map('map', {
                      zoomControl: true,
                      attributionControl: true,
                      scrollWheelZoom: true,
                      doubleClickZoom: true,
                      touchZoom: true,
                      dragging: true,
                      tap: true,
                      tapTolerance: 15
                  }).setView([20.5937, 78.9629], 5); // India center with low zoom

                  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                      attribution: '© OpenStreetMap contributors',
                      maxZoom: 19
                  }).addTo(map);

                  console.log('🗺️ Mobile map initialized, sending ready signal');

                  // Add map click handler for ActionButtonsPanel toggle
                  map.on('click', function(e) {
                      // Only toggle if click is on empty space (not on markers or popups)
                      if (e.originalEvent.target.tagName === 'DIV' &&
                          e.originalEvent.target.className.includes('leaflet-container')) {
                          console.log('🗺️ Mobile: Empty map space clicked - toggling action panel');
                          if (window.ReactNativeWebView) {
                              window.ReactNativeWebView.postMessage(JSON.stringify({
                                  type: 'toggleActionPanel'
                              }));
                          }
                      }
                  });

                  // Notify React Native that map is ready
                  if (window.ReactNativeWebView) {
                      window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'mapReady' }));
                  }
              }

              function updateMap(data) {
                  console.log('🗺️ Updating mobile map with data:', data);
                  currentData = data;

                  // Clear existing territory layers
                  territoryLayers.forEach(layer => {
                      map.removeLayer(layer);
                  });
                  territoryLayers = [];

                  // Clear existing worker marker and accuracy circle
                  if (workerMarker) {
                      map.removeLayer(workerMarker);
                      workerMarker = null;
                  }
                  if (accuracyCircle) {
                      map.removeLayer(accuracyCircle);
                      accuracyCircle = null;
                  }

                  // Add territories
                  if (data.territories && data.territories.length > 0) {
                      let bounds = [];

                      data.territories.forEach(territory => {
                          if (territory.coordinates && territory.coordinates.length > 0) {
                              const coordinates = territory.coordinates.map(coord => [coord.lat, coord.lng]);
                              bounds = bounds.concat(coordinates);

                              const isSelected = data.selectedTerritory && data.selectedTerritory.id === territory.id;

                              const polygon = L.polygon(coordinates, {
                                  color: territory.color || '#3388ff',
                                  weight: isSelected ? 4 : 2,
                                  opacity: 1,
                                  fillOpacity: isSelected ? 0.4 : 0.2,
                                  fillColor: territory.color || '#3388ff'
                              }).addTo(map);

                              // Add popup
                              const popupContent = \`
                                  <div class="territory-popup">
                                      <div class="territory-popup-name">\${territory.name}</div>
                                      <div class="territory-popup-info">
                                          \${territory.assignedWorker ?
                                              '👤 ' + territory.assignedWorker.name :
                                              '⚪ Unassigned'
                                          }
                                      </div>
                                      \${isSelected ?
                                          '<div style="color: #d7a638; font-size: 11px; margin-top: 4px;">📍 Currently selected</div>' :
                                          '<div style="color: #64748b; font-size: 11px; margin-top: 4px;">🗺️ Tap to select</div>'
                                      }
                                  </div>
                              \`;

                              polygon.bindPopup(popupContent);

                              // Handle territory click
                              polygon.on('click', function() {
                                  console.log('🗺️ Territory clicked:', territory.name);
                                  if (window.ReactNativeWebView) {
                                      window.ReactNativeWebView.postMessage(JSON.stringify({
                                          type: 'territoryPressed',
                                          territoryId: territory.id
                                      }));
                                  }
                              });

                              territoryLayers.push(polygon);
                          }
                      });

                      // Fit map to show all territories
                      if (bounds.length > 0) {
                          const latLngBounds = L.latLngBounds(bounds);
                          map.fitBounds(latLngBounds, { padding: [20, 20] });
                      }
                  }

                  // Enhanced worker location marker with accuracy circle
                  if (data.currentLocation && data.showUserLocation) {
                      const location = data.currentLocation;
                      const accuracy = location.accuracy;
                      const isInsideTerritory = data.isInsideTerritory !== false; // Default to true if not specified
                      const workerName = data.workerName || 'Worker';

                      // Add accuracy circle if accuracy data is available
                      if (accuracy && accuracy > 0) {
                          accuracyCircle = L.circle([location.latitude, location.longitude], {
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

                      workerMarker = L.marker([location.latitude, location.longitude], {
                          icon: L.divIcon({
                              className: 'enhanced-worker-marker',
                              html: \`
                                  <div style="
                                      position: relative;
                                      width: 24px;
                                      height: 24px;
                                  ">
                                      <!-- Main marker -->
                                      <div style="
                                          background: linear-gradient(45deg, \${markerColor}, \${markerColor}dd);
                                          width: 24px;
                                          height: 24px;
                                          border-radius: 50%;
                                          border: 3px solid \${borderColor};
                                          box-shadow: 0 3px 12px rgba(0,0,0,0.3);
                                          position: relative;
                                          z-index: 2;
                                      ">
                                          <!-- Person icon -->
                                          <div style="
                                              position: absolute;
                                              top: 50%;
                                              left: 50%;
                                              transform: translate(-50%, -50%);
                                              color: white;
                                              font-size: 12px;
                                              font-weight: bold;
                                          ">👤</div>
                                      </div>

                                      <!-- Pulsing ring -->
                                      <div style="
                                          position: absolute;
                                          top: 50%;
                                          left: 50%;
                                          transform: translate(-50%, -50%);
                                          width: 40px;
                                          height: 40px;
                                          border: 2px solid \${pulseColor};
                                          border-radius: 50%;
                                          opacity: 0.6;
                                          animation: workerPulse 2s infinite;
                                          z-index: 1;
                                      "></div>
                                  </div>

                                  <style>
                                      @keyframes workerPulse {
                                          0% { transform: translate(-50%, -50%) scale(0.8); opacity: 0.8; }
                                          50% { transform: translate(-50%, -50%) scale(1.2); opacity: 0.4; }
                                          100% { transform: translate(-50%, -50%) scale(0.8); opacity: 0.8; }
                                      }
                                  </style>
                              \`,
                              iconSize: [40, 40],
                              iconAnchor: [20, 20]
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
                          <div class="worker-popup">
                              <div class="worker-popup-name">👤 \${workerName}</div>
                              <div style="margin-bottom: 4px;">
                                  \${statusText}
                              </div>
                              <div class="worker-popup-status">Live GPS Position</div>
                              \${accuracyText}
                              <div style="color: #64748b; font-size: 10px; margin-top: 4px;">
                                  \${location.latitude.toFixed(6)}, \${location.longitude.toFixed(6)}
                              </div>
                          </div>
                      \`;

                      workerMarker.bindPopup(popupContent);

                      // Only center map when explicitly requested or on first load
                      if (data.centerOnWorker) {
                          map.setView([location.latitude, location.longitude], 16, {
                              animate: true,
                              duration: 1.0
                          });
                          console.log('🎯 Mobile map centered on worker location (user requested)');
                      } else if (!mapCenteredRef.current) {
                          // Center only on first location load
                          map.setView([location.latitude, location.longitude], 16, {
                              animate: true,
                              duration: 1.0
                          });
                          mapCenteredRef.current = true;
                          console.log('🎯 Mobile map centered on worker location (first load)');
                      }
                  }

                  // Add delivery markers if enabled
                  if (data.showDeliveries && data.deliveries && data.deliveries.length > 0) {
                      console.log('📦 Adding delivery markers:', data.deliveries.length);

                      data.deliveries.forEach(delivery => {
                          const deliveryIcon = L.divIcon({
                              className: 'delivery-marker',
                              html: \`
                                  <div style="
                                      background: \${delivery.deliveryType === 'door' ? '#002b5b' : '#d7a638'};
                                      width: 20px;
                                      height: 20px;
                                      border-radius: 50%;
                                      display: flex;
                                      align-items: center;
                                      justify-content: center;
                                      color: white;
                                      font-size: 10px;
                                      font-weight: bold;
                                      border: 2px solid white;
                                      box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                                  ">
                                      \${delivery.deliveryType === 'door' ? '🏠' : '👤'}
                                  </div>
                              \`,
                              iconSize: [20, 20],
                              iconAnchor: [10, 10]
                          });

                          const deliveryMarker = L.marker([delivery.location.latitude, delivery.location.longitude], {
                              icon: deliveryIcon
                          }).addTo(map);

                          // Add popup with delivery details
                          const deliveryTime = new Date(delivery.deliveryTime).toLocaleString();
                          const methodText = delivery.deliveryType === 'door' ? 'Door-to-door' : 'Person-to-person';

                          const popupContent = \`
                              <div class="delivery-popup">
                                  <div style="font-weight: bold; color: #002b5b; margin-bottom: 4px;">
                                      📦 \${delivery.bookTitle}
                                  </div>
                                  <div style="font-size: 12px; color: #666; margin-bottom: 2px;">
                                      👤 \${delivery.workerName}
                                  </div>
                                  <div style="font-size: 11px; color: #666; margin-bottom: 2px;">
                                      🕒 \${deliveryTime}
                                  </div>
                                  <div style="
                                      display: inline-block;
                                      background: \${delivery.deliveryType === 'door' ? '#002b5b' : '#d7a638'};
                                      color: white;
                                      padding: 2px 6px;
                                      border-radius: 8px;
                                      font-size: 10px;
                                      margin: 4px 0;
                                  ">
                                      \${methodText}
                                  </div>
                                  \${delivery.recipientName ? \`<div style="font-size: 11px; color: #666;">To: \${delivery.recipientName}</div>\` : ''}
                                  \${delivery.notes ? \`<div style="font-size: 10px; color: #888; font-style: italic; margin-top: 4px;">\${delivery.notes}</div>\` : ''}
                              </div>
                          \`;

                          deliveryMarker.bindPopup(popupContent);

                          // Handle delivery marker click
                          deliveryMarker.on('click', function() {
                              console.log('📦 Delivery marker clicked:', delivery.id);
                              if (window.ReactNativeWebView) {
                                  window.ReactNativeWebView.postMessage(JSON.stringify({
                                      type: 'deliveryPressed',
                                      deliveryId: delivery.id
                                  }));
                              }
                          });
                      });
                  }
              }

              // Function to update only worker location marker (no full map refresh)
              function updateWorkerLocationOnly(data) {
                  console.log('📍 Updating worker location marker only (no map refresh)');

                  // Clear existing worker marker and accuracy circle
                  if (workerMarker) {
                      map.removeLayer(workerMarker);
                      workerMarker = null;
                  }
                  if (accuracyCircle) {
                      map.removeLayer(accuracyCircle);
                      accuracyCircle = null;
                  }

                  // Enhanced worker location marker with accuracy circle
                  if (data.currentLocation) {
                      const location = data.currentLocation;
                      const accuracy = location.accuracy;
                      const isInsideTerritory = data.isInsideTerritory !== false; // Default to true if not specified
                      const workerName = 'Worker';

                      // Add accuracy circle if accuracy data is available
                      if (accuracy && accuracy > 0) {
                          accuracyCircle = L.circle([location.latitude, location.longitude], {
                              radius: accuracy,
                              color: isInsideTerritory ? '#10b981' : '#f59e0b',
                              weight: 2,
                              opacity: 0.6,
                              fillOpacity: 0.1,
                          }).addTo(map);
                      }

                      // Enhanced worker marker with status-based styling
                      const markerColor = isInsideTerritory ? '#10b981' : '#f59e0b';
                      const borderColor = isInsideTerritory ? '#065f46' : '#d97706';
                      const pulseColor = isInsideTerritory ? '#10b981' : '#f59e0b';

                      workerMarker = L.marker([location.latitude, location.longitude], {
                          icon: L.divIcon({
                              className: 'professional-worker-marker',
                              html: \`
                                  <div style="
                                      position: relative;
                                      width: 36px;
                                      height: 36px;
                                      background: linear-gradient(135deg, \${markerColor} 0%, \${markerColor}dd 100%);
                                      border: 3px solid \${borderColor};
                                      border-radius: 50%;
                                      box-shadow: 0 4px 12px rgba(0,0,0,0.4), 0 2px 4px rgba(0,0,0,0.2);
                                      display: flex;
                                      align-items: center;
                                      justify-content: center;
                                      font-size: 16px;
                                      color: white;
                                      font-weight: bold;
                                      animation: workerPulse 2s infinite;
                                      transform: translateZ(0);
                                      backdrop-filter: blur(1px);
                                  ">
                                      <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" style="filter: drop-shadow(0 1px 2px rgba(0,0,0,0.3));">
                                          <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                                      </svg>
                                  </div>
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
                                  "></div>
                                  <style>
                                      @keyframes workerPulse {
                                          0% {
                                              box-shadow: 0 4px 12px rgba(0,0,0,0.4), 0 2px 4px rgba(0,0,0,0.2), 0 0 0 0 \${pulseColor}40;
                                              transform: scale(1) translateZ(0);
                                          }
                                          50% {
                                              transform: scale(1.05) translateZ(0);
                                          }
                                          70% {
                                              box-shadow: 0 4px 12px rgba(0,0,0,0.4), 0 2px 4px rgba(0,0,0,0.2), 0 0 0 8px \${pulseColor}00;
                                          }
                                          100% {
                                              box-shadow: 0 4px 12px rgba(0,0,0,0.4), 0 2px 4px rgba(0,0,0,0.2), 0 0 0 0 \${pulseColor}00;
                                              transform: scale(1) translateZ(0);
                                          }
                                      }
                                  </style>
                              \`,
                              iconSize: [40, 40],
                              iconAnchor: [20, 20]
                          })
                      }).addTo(map);

                      // Enhanced popup content
                      const statusText = isInsideTerritory ?
                          '<span style="color: #10b981; font-weight: bold;">✅ Inside Territory</span>' :
                          '<span style="color: #f59e0b; font-weight: bold;">⚠️ Outside Territory</span>';

                      const accuracyText = accuracy ?
                          \`<div style="color: #64748b; font-size: 10px;">📍 Accuracy: ±\${Math.round(accuracy)}m</div>\` : '';

                      const popupContent = \`
                          <div style="text-align: center; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
                              <div style="font-weight: bold; color: #1f2937; margin-bottom: 4px;">
                                  \${workerName}
                              </div>
                              <div class="worker-popup-status">Live GPS Position</div>
                              \${accuracyText}
                              <div style="color: #64748b; font-size: 10px; margin-top: 4px;">
                                  \${location.latitude.toFixed(6)}, \${location.longitude.toFixed(6)}
                              </div>
                          </div>
                      \`;

                      workerMarker.bindPopup(popupContent);

                      // Only center map when explicitly requested or on first load
                      if (data.centerOnWorker) {
                          map.setView([location.latitude, location.longitude], 16, {
                              animate: true,
                              duration: 1.0
                          });
                          console.log('🎯 Mobile map centered on worker location (user requested)');
                      } else if (!mapCenteredRef.current) {
                          // Center only on first location load
                          map.setView([location.latitude, location.longitude], 16, {
                              animate: true,
                              duration: 1.0
                          });
                          mapCenteredRef.current = true;
                          console.log('🎯 Mobile map centered on worker location (first load)');
                      }
                  }
              }

              // Listen for messages from React Native
              document.addEventListener('message', function(event) {
                  try {
                      const data = JSON.parse(event.data);
                      if (data.type === 'updateTerritories') {
                          updateMap(data);
                      } else if (data.type === 'updateWorkerLocation') {
                          updateWorkerLocationOnly(data);
                      }
                  } catch (error) {
                      console.error('Error parsing message:', error);
                  }
              });

              // Path visualization functions
              function updatePath(pathData, color = '#002b5b') {
                  console.log('🛣️ Updating path with', pathData.length, 'points');

                  // Clear existing path
                  clearPath();

                  if (pathData.length < 2) {
                      console.log('⚠️ Not enough points to draw path');
                      return;
                  }

                  // Convert path data to Leaflet LatLng array
                  const latLngs = pathData.map(point => [point.lat, point.lng]);

                  // Create polyline with custom styling
                  pathPolyline = L.polyline(latLngs, {
                      color: color,
                      weight: 4,
                      opacity: 0.8,
                      smoothFactor: 1,
                      lineCap: 'round',
                      lineJoin: 'round'
                  }).addTo(map);

                  // Store path data
                  pathPoints = pathData;
                  pathColor = color;

                  console.log('✅ Path drawn successfully');
              }

              function clearPath() {
                  if (pathPolyline) {
                      map.removeLayer(pathPolyline);
                      pathPolyline = null;
                  }
                  pathPoints = [];
                  console.log('🧹 Path cleared');
              }

              // For Android
              window.addEventListener('message', function(event) {
                  try {
                      const data = JSON.parse(event.data);
                      if (data.type === 'updateTerritories') {
                          updateMap(data);
                      } else if (data.type === 'updateWorkerLocation') {
                          updateWorkerLocationOnly(data);
                      } else if (data.type === 'updatePath') {
                          updatePath(data.pathData, data.pathColor);
                      } else if (data.type === 'clearPath') {
                          clearPath();
                      }
                  } catch (error) {
                      console.error('Error parsing message:', error);
                  }
              });

              // Initialize map when page loads
              document.addEventListener('DOMContentLoaded', initMap);

              // Fallback initialization
              if (document.readyState === 'loading') {
                  document.addEventListener('DOMContentLoaded', initMap);
              } else {
                  initMap();
              }
          </script>
      </body>
      </html>
    `;
  };

  return (
    <View style={[styles.container, style]}>
      {Platform.OS === 'web' ? (
        <iframe
          srcDoc={getMapHTML()}
          style={styles.webMapIframe}
        />
      ) : (
        <WebView
          ref={webViewRef}
          source={{ html: getMapHTML() }}
          style={styles.webView}
          onMessage={handleWebViewMessage}
          javaScriptEnabled={true}
          domStorageEnabled={true}
          startInLoadingState={true}
          scalesPageToFit={true}
          scrollEnabled={false}
          bounces={false}
          originWhitelist={['*']}
          mixedContentMode="always"
          allowUniversalAccessFromFileURLs={true}
          allowFileAccessFromFileURLs={true}
          onLoad={() => console.log('📱 WebView loaded')}
          onError={(error) => console.error('📱 WebView error:', error)}
          renderLoading={() => (
            <View style={styles.loadingContainer}>
              <Text style={styles.loadingText}>Loading Map...</Text>
            </View>
          )}
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  webView: {
    flex: 1,
  },
  webMapIframe: {
    width: '100%',
    height: '100%',
    border: 'none',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
  },
  loadingText: {
    fontSize: 16,
    color: '#64748b',
    fontWeight: '500',
  },
});

export default TerritoryMap;
