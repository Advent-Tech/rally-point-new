import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Modal,
  ScrollView,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { WebView } from 'react-native-webview';
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { DeliveryService } from '../services/DeliveryService';
import { BookDelivery } from '../types/ministry';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface AdminDeliveryMapViewProps {
  visible: boolean;
  onClose: () => void;
}


interface DeliveryMapData {
  deliveries: okDelivery[];
  filters: {
    dateRange: 'week' | 'month' | 'all';
    deliveryMethod: 'all' | 'door' | 'person';
    worker: string;
  };
}

const AdminDeliveryMapView: React.FC<AdminDeliveryMapViewProps> = ({
  visible,
  onClose,
}) => {
  const [mapData, setMapData] = useState<DeliveryMapData>({
    deliveries: [],
    filters: {
      dateRange: 'week',
      deliveryMethod: 'all',
      worker: 'all',
    },
  });
  const [loading, setLoading] = useState(false);
  const [selectedDelivery, setSelectedDelivery] = useState<BookDelivery | null>(null);
  const [showDeliveryDetails, setShowDeliveryDetails] = useState(false);
  const [workers, setWorkers] = useState<Array<{ id: string; name: string }>>([]);

  useEffect(() => {
    if (visible) {
      loadDeliveries();
    }
  }, [visible, mapData.filters]);

  const loadDeliveries = async () => {
    try {
      setLoading(true);
      
      // Calculate date range
      const now = new Date();
      let startDate: Date;
      
      switch (mapData.filters.dateRange) {
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
          break;
        default:
          startDate = new Date(0); // All time
      }

      // Get all deliveries
      const allDeliveries = await DeliveryService.getAllDeliveries();
      
      // Apply filters
      let filteredDeliveries = allDeliveries.filter(
        delivery => delivery.deliveryTime >= startDate
      );

      if (mapData.filters.deliveryMethod !== 'all') {
        filteredDeliveries = filteredDeliveries.filter(
          delivery => delivery.deliveryType === mapData.filters.deliveryMethod
        );
      }

      if (mapData.filters.worker !== 'all') {
        filteredDeliveries = filteredDeliveries.filter(
          delivery => delivery.workerId === mapData.filters.worker
        );
      }

      // Extract unique workers
      const uniqueWorkers = Array.from(
        new Map(
          allDeliveries.map(delivery => [delivery.workerId, { id: delivery.workerId, name: delivery.workerName }])
        ).values()
      );

      setWorkers(uniqueWorkers);
      setMapData(prev => ({ ...prev, deliveries: filteredDeliveries }));
    } catch (error) {
      console.error('Error loading deliveries:', error);
      Alert.alert('Error', 'Failed to load delivery data');
    } finally {
      setLoading(false);
    }
  };

  const updateFilter = (key: keyof DeliveryMapData['filters'], value: string) => {
    setMapData(prev => ({
      ...prev,
      filters: { ...prev.filters, [key]: value },
    }));
  };

  const generateMapHTML = (): string => {
    const deliveryMarkers = mapData.deliveries.map(delivery => ({
      id: delivery.id,
      lat: delivery.location.latitude,
      lng: delivery.location.longitude,
      title: delivery.bookTitle,
      worker: delivery.workerName,
      method: delivery.deliveryType,
      time: delivery.deliveryTime.toISOString(),
      recipient: delivery.recipientName || 'Unknown',
      notes: delivery.notes || '',
    }));

    return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <style>
            body { margin: 0; padding: 0; }
            #map { height: 100vh; width: 100vw; }
            .delivery-popup {
                max-width: 250px;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            }
            .popup-title { font-weight: 600; color: #002b5b; margin-bottom: 8px; }
            .popup-detail { margin: 4px 0; font-size: 12px; color: #666; }
            .popup-method { 
                display: inline-block; 
                padding: 2px 8px; 
                border-radius: 12px; 
                font-size: 10px; 
                font-weight: 500;
                color: white;
                margin: 4px 0;
            }
            .method-door { background-color: #002b5b; }
            .method-person { background-color: #d7a638; }
        </style>
    </head>
    <body>
        <div id="map"></div>
        <script>
            // Initialize map
            const map = L.map('map').setView([40.7128, -74.0060], 10);
            
            // Add tile layer
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors'
            }).addTo(map);

            // Delivery markers data
            const deliveries = ${JSON.stringify(deliveryMarkers)};
            
            // Create custom icons
            const doorIcon = L.divIcon({
                html: '<div style="background-color: #002b5b; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: white; font-size: 12px; font-weight: bold;">🏠</div>',
                className: 'custom-div-icon',
                iconSize: [24, 24],
                iconAnchor: [12, 12]
            });
            
            const personIcon = L.divIcon({
                html: '<div style="background-color: #d7a638; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: white; font-size: 12px; font-weight: bold;">👤</div>',
                className: 'custom-div-icon',
                iconSize: [24, 24],
                iconAnchor: [12, 12]
            });

            // Add delivery markers
            const markers = [];
            deliveries.forEach(delivery => {
                const icon = delivery.method === 'door' ? doorIcon : personIcon;
                const methodClass = delivery.method === 'door' ? 'method-door' : 'method-person';
                const methodText = delivery.method === 'door' ? 'Door-to-door' : 'Person-to-person';
                
                const popupContent = \`
                    <div class="delivery-popup">
                        <div class="popup-title">\${delivery.title}</div>
                        <div class="popup-detail"><strong>Worker:</strong> \${delivery.worker}</div>
                        <div class="popup-detail"><strong>Recipient:</strong> \${delivery.recipient}</div>
                        <div class="popup-method \${methodClass}">\${methodText}</div>
                        <div class="popup-detail"><strong>Time:</strong> \${new Date(delivery.time).toLocaleString()}</div>
                        \${delivery.notes ? \`<div class="popup-detail"><strong>Notes:</strong> \${delivery.notes}</div>\` : ''}
                    </div>
                \`;
                
                const marker = L.marker([delivery.lat, delivery.lng], { icon })
                    .addTo(map)
                    .bindPopup(popupContent);
                    
                marker.on('click', function() {
                    if (window.ReactNativeWebView) {
                        window.ReactNativeWebView.postMessage(JSON.stringify({
                            type: 'deliverySelected',
                            deliveryId: delivery.id
                        }));
                    }
                });
                
                markers.push(marker);
            });

            // Fit map to show all markers
            if (markers.length > 0) {
                const group = new L.featureGroup(markers);
                map.fitBounds(group.getBounds().pad(0.1));
            }

            // Handle map clicks
            map.on('click', function(e) {
                if (window.ReactNativeWebView) {
                    window.ReactNativeWebView.postMessage(JSON.stringify({
                        type: 'mapClicked',
                        lat: e.latlng.lat,
                        lng: e.latlng.lng
                    }));
                }
            });
        </script>
    </body>
    </html>
    `;
  };

  const handleWebViewMessage = (event: any) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      
      if (data.type === 'deliverySelected') {
        const delivery = mapData.deliveries.find(d => d.id === data.deliveryId);
        if (delivery) {
          setSelectedDelivery(delivery);
          setShowDeliveryDetails(true);
        }
      }
    } catch (error) {
      console.error('Error handling WebView message:', error);
    }
  };

  const formatDate = (date: Date): string => {
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getDeliveryMethodColor = (type: string): string => {
    return type === 'door' ? COLORS.primary.main : COLORS.secondary.main;
  };

  if (!visible) return null;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="fullScreen"
      onRequestClose={onClose}
    >
      <View style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose}>
            <Ionicons name="close" size={24} color={COLORS.text.primary} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Delivery Map</Text>
          <TouchableOpacity onPress={loadDeliveries}>
            <Ionicons name="refresh" size={24} color={COLORS.primary.main} />
          </TouchableOpacity>
        </View>

        {/* Filters */}
        <View style={styles.filtersContainer}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            {/* Date Range Filter */}
            <View style={styles.filterGroup}>
              <Text style={styles.filterLabel}>Time:</Text>
              {(['week', 'month', 'all'] as const).map((range) => (
                <TouchableOpacity
                  key={range}
                  style={[
                    styles.filterButton,
                    mapData.filters.dateRange === range && styles.activeFilterButton
                  ]}
                  onPress={() => updateFilter('dateRange', range)}
                >
                  <Text style={[
                    styles.filterButtonText,
                    mapData.filters.dateRange === range && styles.activeFilterButtonText
                  ]}>
                    {range === 'week' ? 'Week' : range === 'month' ? 'Month' : 'All'}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Delivery Method Filter */}
            <View style={styles.filterGroup}>
              <Text style={styles.filterLabel}>Method:</Text>
              {(['all', 'door', 'person'] as const).map((method) => (
                <TouchableOpacity
                  key={method}
                  style={[
                    styles.filterButton,
                    mapData.filters.deliveryMethod === method && styles.activeFilterButton
                  ]}
                  onPress={() => updateFilter('deliveryMethod', method)}
                >
                  <Text style={[
                    styles.filterButtonText,
                    mapData.filters.deliveryMethod === method && styles.activeFilterButtonText
                  ]}>
                    {method === 'all' ? 'All' : method === 'door' ? 'Door' : 'Person'}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </ScrollView>
        </View>

        {/* Map */}
        <View style={styles.mapContainer}>
          {loading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={COLORS.primary.main} />
              <Text style={styles.loadingText}>Loading deliveries...</Text>
            </View>
          ) : (
            <WebView
              source={{ html: generateMapHTML() }}
              style={styles.webView}
              onMessage={handleWebViewMessage}
              javaScriptEnabled={true}
              domStorageEnabled={true}
              startInLoadingState={true}
              renderLoading={() => (
                <View style={styles.loadingContainer}>
                  <ActivityIndicator size="large" color={COLORS.primary.main} />
                </View>
              )}
            />
          )}
        </View>

        {/* Stats Bar */}
        <View style={styles.statsBar}>
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>{mapData.deliveries.length}</Text>
            <Text style={styles.statLabel}>Total</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>
              {mapData.deliveries.filter(d => d.deliveryType === 'door').length}
            </Text>
            <Text style={styles.statLabel}>Door</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>
              {mapData.deliveries.filter(d => d.deliveryType === 'person').length}
            </Text>
            <Text style={styles.statLabel}>Person</Text>
          </View>
        </View>
      </View>

      {/* Delivery Details Modal */}
      <Modal
        visible={showDeliveryDetails}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowDeliveryDetails(false)}
      >
        {selectedDelivery && (
          <View style={styles.detailsModal}>
            <View style={styles.detailsHeader}>
              <TouchableOpacity onPress={() => setShowDeliveryDetails(false)}>
                <Ionicons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
              <Text style={styles.detailsTitle}>Delivery Details</Text>
              <View style={{ width: 24 }} />
            </View>

            <ScrollView style={styles.detailsContent}>
              <View style={styles.detailsCard}>
                <View style={styles.detailsRow}>
                  <Text style={styles.detailsLabel}>Book:</Text>
                  <Text style={styles.detailsValue}>{selectedDelivery.bookTitle}</Text>
                </View>

                <View style={styles.detailsRow}>
                  <Text style={styles.detailsLabel}>Worker:</Text>
                  <Text style={styles.detailsValue}>{selectedDelivery.workerName}</Text>
                </View>

                <View style={styles.detailsRow}>
                  <Text style={styles.detailsLabel}>Method:</Text>
                  <View style={[
                    styles.methodBadge,
                    { backgroundColor: getDeliveryMethodColor(selectedDelivery.deliveryType) }
                  ]}>
                    <Text style={styles.methodBadgeText}>
                      {selectedDelivery.deliveryType === 'door' ? 'Door-to-door' : 'Person-to-person'}
                    </Text>
                  </View>
                </View>

                <View style={styles.detailsRow}>
                  <Text style={styles.detailsLabel}>Time:</Text>
                  <Text style={styles.detailsValue}>{formatDate(selectedDelivery.deliveryTime)}</Text>
                </View>

                {selectedDelivery.recipientName && (
                  <View style={styles.detailsRow}>
                    <Text style={styles.detailsLabel}>Recipient:</Text>
                    <Text style={styles.detailsValue}>{selectedDelivery.recipientName}</Text>
                  </View>
                )}

                {selectedDelivery.recipientPhone && (
                  <View style={styles.detailsRow}>
                    <Text style={styles.detailsLabel}>Phone:</Text>
                    <Text style={styles.detailsValue}>{selectedDelivery.recipientPhone}</Text>
                  </View>
                )}

                <View style={styles.detailsRow}>
                  <Text style={styles.detailsLabel}>Location:</Text>
                  <Text style={styles.detailsValue}>
                    {selectedDelivery.location.latitude.toFixed(6)}, {selectedDelivery.location.longitude.toFixed(6)}
                  </Text>
                </View>

                {selectedDelivery.notes && (
                  <View style={styles.detailsRow}>
                    <Text style={styles.detailsLabel}>Notes:</Text>
                    <Text style={styles.detailsValue}>{selectedDelivery.notes}</Text>
                  </View>
                )}
              </View>
            </ScrollView>
          </View>
        )}
      </Modal>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  headerTitle: {
    ...TYPOGRAPHY.h2,
    fontWeight: '700',
    color: COLORS.text.primary,
  },
  filtersContainer: {
    backgroundColor: '#FFFFFF',
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  filterGroup: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    gap: SPACING.xs,
  },
  filterLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '500',
    marginRight: SPACING.xs,
  },
  filterButton: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: RADIUS.sm,
    backgroundColor: COLORS.background.secondary,
  },
  activeFilterButton: {
    backgroundColor: COLORS.primary.main,
  },
  filterButtonText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '500',
  },
  activeFilterButtonText: {
    color: '#FFFFFF',
  },
  mapContainer: {
    flex: 1,
  },
  webView: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.background.primary,
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  statsBar: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    paddingVertical: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
  },
  statNumber: {
    ...TYPOGRAPHY.h3,
    fontWeight: '700',
    color: COLORS.primary.main,
  },
  statLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
  detailsModal: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  detailsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  detailsTitle: {
    ...TYPOGRAPHY.h3,
    fontWeight: '600',
    color: COLORS.text.primary,
  },
  detailsContent: {
    flex: 1,
    padding: SPACING.lg,
  },
  detailsCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: RADIUS.md,
    padding: SPACING.lg,
    ...SHADOWS.medium,
  },
  detailsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  detailsLabel: {
    ...TYPOGRAPHY.body,
    fontWeight: '500',
    color: COLORS.text.secondary,
    width: 80,
  },
  detailsValue: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    flex: 1,
  },
  methodBadge: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: RADIUS.sm,
  },
  methodBadgeText: {
    ...TYPOGRAPHY.caption,
    color: '#FFFFFF',
    fontWeight: '500',
  },
});

export default AdminDeliveryMapView;
