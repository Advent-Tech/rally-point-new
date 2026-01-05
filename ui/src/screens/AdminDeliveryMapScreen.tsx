import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
  ScrollView,
  Modal,
  Image,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import Icon from '../components/Icon';
import { MaterialIcons } from '@expo/vector-icons';
import { ModernCard } from '../components/ModernCard';
import { BookDelivery, DeliveryStatus } from '../types/ministry';
import DeliveryService from '../services/DeliveryService';

interface AdminDeliveryMapScreenProps {
  navigation: any;
}

const AdminDeliveryMapScreen: React.FC<AdminDeliveryMapScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [deliveries, setDeliveries] = useState<BookDelivery[]>([]);
  const [selectedDelivery, setSelectedDelivery] = useState<BookDelivery | null>(null);
  const [showDeliveryModal, setShowDeliveryModal] = useState(false);
  const [filterStatus, setFilterStatus] = useState<DeliveryStatus | 'all'>('all');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadDeliveries();
  }, []);

  const loadDeliveries = async () => {
    try {
      setIsLoading(true);
      // In production, this would load all deliveries for admin view
      // For now, we'll simulate with mock data
      const mockDeliveries: BookDelivery[] = [
        {
          id: '1',
          workerId: 'worker1',
          workerName: 'John Smith',
          territoryId: 'territory_1',
          deliveryType: 'door',
          bookTitle: 'The Great Hope',
          bookType: 'bible',
          quantity: 1,
          recipientAddress: '123 Main St, Anytown',
          location: {
            latitude: 40.7128,
            longitude: -74.0060,
            accuracy: 5,
          },
          deliveryTime: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
          status: 'delivered',
          followUpRequired: false,
          syncStatus: 'synced',
        },
        {
          id: '2',
          workerId: 'worker2',
          workerName: 'Mary Johnson',
          territoryId: 'territory_2',
          deliveryType: 'person',
          bookTitle: 'Steps to Christ',
          bookType: 'study_guide',
          quantity: 2,
          recipientName: 'Sarah Wilson',
          recipientAddress: '456 Oak Ave, Somewhere',
          location: {
            latitude: 40.7589,
            longitude: -73.9851,
            accuracy: 3,
          },
          deliveryTime: new Date(Date.now() - 1 * 60 * 60 * 1000), // 1 hour ago
          status: 'interested',
          followUpRequired: true,
          syncStatus: 'synced',
        },
        {
          id: '3',
          workerId: 'worker1',
          workerName: 'John Smith',
          territoryId: 'territory_1',
          deliveryType: 'door',
          bookTitle: 'Amazing Facts',
          bookType: 'tract',
          quantity: 5,
          recipientAddress: '789 Pine St, Elsewhere',
          location: {
            latitude: 40.7505,
            longitude: -73.9934,
            accuracy: 8,
          },
          deliveryTime: new Date(Date.now() - 30 * 60 * 1000), // 30 minutes ago
          status: 'not_home',
          followUpRequired: false,
          syncStatus: 'synced',
        },
      ];
      setDeliveries(mockDeliveries);
    } catch (error) {
      console.error('Error loading deliveries:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const getStatusColor = (status: DeliveryStatus) => {
    const colors = {
      delivered: '#10b981',
      not_home: '#f59e0b',
      refused: '#ef4444',
      interested: '#3b82f6',
      follow_up: '#8b5cf6',
      pending: '#64748b',
    };
    return colors[status] || '#64748b';
  };

  const getStatusIcon = (status: DeliveryStatus) => {
    const icons = {
      delivered: 'check',
      not_home: 'house',
      refused: 'close',
      interested: 'star',
      follow_up: 'follow',
      pending: 'clock',
    };
    return icons[status] || 'info';
  };

  const filteredDeliveries = filterStatus === 'all' 
    ? deliveries 
    : deliveries.filter(d => d.status === filterStatus);

  const openInGoogleMaps = (delivery: BookDelivery) => {
    const { latitude, longitude } = delivery.location;
    const url = `https://www.google.com/maps?q=${latitude},${longitude}`;
    window.open(url, '_blank');
  };

  const handleDeliveryPress = (delivery: BookDelivery) => {
    setSelectedDelivery(delivery);
    setShowDeliveryModal(true);
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#1e293b" />
      
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity 
          style={styles.backButton}
          onPress={() => navigation.goBack()}
        >
          <MaterialIcons name="arrow-back" size={24} color="#ffffff" />
        </TouchableOpacity>
        
        <View style={styles.headerCenter}>
          <Text style={styles.headerTitle}>Delivery Map</Text>
          <Text style={styles.headerSubtitle}>All Worker Deliveries</Text>
        </View>
        
        <TouchableOpacity style={styles.mapViewButton}>
          <Icon name="map" size={24} color="#ffffff" />
        </TouchableOpacity>
      </View>

      {/* Filter Tabs */}
      <View style={styles.filterContainer}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          {[
            { key: 'all', label: 'All', count: deliveries.length },
            { key: 'delivered', label: 'Delivered', count: deliveries.filter(d => d.status === 'delivered').length },
            { key: 'interested', label: 'Interested', count: deliveries.filter(d => d.status === 'interested').length },
            { key: 'not_home', label: 'Not Home', count: deliveries.filter(d => d.status === 'not_home').length },
            { key: 'follow_up', label: 'Follow Up', count: deliveries.filter(d => d.status === 'follow_up').length },
          ].map((filter) => (
            <TouchableOpacity
              key={filter.key}
              style={[
                styles.filterTab,
                filterStatus === filter.key && styles.filterTabActive
              ]}
              onPress={() => setFilterStatus(filter.key as any)}
            >
              <Text style={[
                styles.filterTabText,
                filterStatus === filter.key && styles.filterTabTextActive
              ]}>
                {filter.label}
              </Text>
              <View style={[
                styles.filterBadge,
                filterStatus === filter.key && styles.filterBadgeActive
              ]}>
                <Text style={[
                  styles.filterBadgeText,
                  filterStatus === filter.key && styles.filterBadgeTextActive
                ]}>
                  {filter.count}
                </Text>
              </View>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {/* Deliveries List */}
      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>
            Recent Deliveries ({filteredDeliveries.length})
          </Text>
          
          {filteredDeliveries.map((delivery) => (
            <TouchableOpacity
              key={delivery.id}
              style={styles.deliveryCard}
              onPress={() => handleDeliveryPress(delivery)}
            >
              <View style={styles.deliveryHeader}>
                <View style={styles.deliveryInfo}>
                  <Text style={styles.deliveryTitle}>{delivery.bookTitle}</Text>
                  <Text style={styles.deliveryWorker}>by {delivery.workerName}</Text>
                </View>
                
                <View style={styles.deliveryStatus}>
                  <View style={[
                    styles.statusIndicator,
                    { backgroundColor: getStatusColor(delivery.status) }
                  ]} />
                  <Text style={[
                    styles.statusText,
                    { color: getStatusColor(delivery.status) }
                  ]}>
                    {delivery.status.replace('_', ' ').toUpperCase()}
                  </Text>
                </View>
              </View>

              <View style={styles.deliveryDetails}>
                <View style={styles.deliveryMeta}>
                  <Icon 
                    name={delivery.deliveryType === 'door' ? 'house' : 'handshake'} 
                    size={16} 
                    color="#64748b" 
                  />
                  <Text style={styles.deliveryMetaText}>
                    {delivery.deliveryType === 'door' ? 'Door-to-door' : 'Person-to-person'}
                  </Text>
                </View>
                
                <View style={styles.deliveryMeta}>
                  <Icon name="location" size={16} color="#64748b" />
                  <Text style={styles.deliveryMetaText}>
                    {delivery.recipientAddress}
                  </Text>
                </View>
                
                <View style={styles.deliveryMeta}>
                  <Icon name="clock" size={16} color="#64748b" />
                  <Text style={styles.deliveryMetaText}>
                    {delivery.deliveryTime.toLocaleTimeString()}
                  </Text>
                </View>
              </View>

              <View style={styles.deliveryActions}>
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => openInGoogleMaps(delivery)}
                >
                  <Icon name="map" size={16} color="#3b82f6" />
                  <Text style={styles.actionButtonText}>View on Map</Text>
                </TouchableOpacity>
                
                {delivery.followUpRequired && (
                  <View style={styles.followUpBadge}>
                    <Icon name="star" size={12} color="#f59e0b" />
                    <Text style={styles.followUpText}>Follow Up</Text>
                  </View>
                )}
              </View>
            </TouchableOpacity>
          ))}
        </View>
      </ScrollView>

      {/* Delivery Detail Modal */}
      <Modal
        visible={showDeliveryModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowDeliveryModal(false)}
      >
        {selectedDelivery && (
          <SafeAreaView style={styles.modalContainer}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowDeliveryModal(false)}>
                <Icon name="close" size={24} color="#64748b" />
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Delivery Details</Text>
              <View style={styles.modalHeaderRight} />
            </View>

            <ScrollView style={styles.modalContent}>
              <View style={styles.modalSection}>
                <Text style={styles.modalSectionTitle}>Literature Information</Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>Title: </Text>
                  {selectedDelivery.bookTitle}
                </Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>Type: </Text>
                  {selectedDelivery.bookType.replace('_', ' ').toUpperCase()}
                </Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>Quantity: </Text>
                  {selectedDelivery.quantity}
                </Text>
              </View>

              <View style={styles.modalSection}>
                <Text style={styles.modalSectionTitle}>Delivery Information</Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>Worker: </Text>
                  {selectedDelivery.workerName}
                </Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>Type: </Text>
                  {selectedDelivery.deliveryType === 'door' ? 'Door-to-door' : 'Person-to-person'}
                </Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>Status: </Text>
                  {selectedDelivery.status.replace('_', ' ').toUpperCase()}
                </Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>Time: </Text>
                  {selectedDelivery.deliveryTime.toLocaleString()}
                </Text>
              </View>

              <View style={styles.modalSection}>
                <Text style={styles.modalSectionTitle}>Location</Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>Address: </Text>
                  {selectedDelivery.recipientAddress}
                </Text>
                <Text style={styles.modalText}>
                  <Text style={styles.modalLabel}>GPS: </Text>
                  {selectedDelivery.location.latitude.toFixed(6)}, {selectedDelivery.location.longitude.toFixed(6)}
                </Text>
                
                <TouchableOpacity
                  style={styles.mapButton}
                  onPress={() => openInGoogleMaps(selectedDelivery)}
                >
                  <Icon name="map" size={20} color="#ffffff" />
                  <Text style={styles.mapButtonText}>Open in Google Maps</Text>
                </TouchableOpacity>
              </View>

              {selectedDelivery.notes && (
                <View style={styles.modalSection}>
                  <Text style={styles.modalSectionTitle}>Notes</Text>
                  <Text style={styles.modalText}>{selectedDelivery.notes}</Text>
                </View>
              )}
            </ScrollView>
          </SafeAreaView>
        )}
      </Modal>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  header: {
    backgroundColor: '#1e293b',
    paddingHorizontal: 20,
    paddingVertical: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerCenter: {
    flex: 1,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#ffffff',
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#94a3b8',
    marginTop: 2,
  },
  mapViewButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  filterContainer: {
    backgroundColor: '#ffffff',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  filterTab: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#f1f5f9',
    marginRight: 12,
  },
  filterTabActive: {
    backgroundColor: '#3b82f6',
  },
  filterTabText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#64748b',
    marginRight: 6,
  },
  filterTabTextActive: {
    color: '#ffffff',
  },
  filterBadge: {
    backgroundColor: '#e2e8f0',
    borderRadius: 10,
    paddingHorizontal: 6,
    paddingVertical: 2,
    minWidth: 20,
    alignItems: 'center',
  },
  filterBadgeActive: {
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
  },
  filterBadgeText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#64748b',
  },
  filterBadgeTextActive: {
    color: '#ffffff',
  },
  content: {
    flex: 1,
  },
  section: {
    paddingHorizontal: 20,
    paddingVertical: 16,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 16,
  },
  deliveryCard: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  deliveryHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  deliveryInfo: {
    flex: 1,
  },
  deliveryTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1e293b',
    marginBottom: 4,
  },
  deliveryWorker: {
    fontSize: 14,
    color: '#64748b',
  },
  deliveryStatus: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 6,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
  },
  deliveryDetails: {
    marginBottom: 12,
  },
  deliveryMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
  },
  deliveryMetaText: {
    fontSize: 14,
    color: '#64748b',
    marginLeft: 8,
    flex: 1,
  },
  deliveryActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
    backgroundColor: '#f1f5f9',
  },
  actionButtonText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#3b82f6',
    marginLeft: 6,
  },
  followUpBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    backgroundColor: '#fef3c7',
  },
  followUpText: {
    fontSize: 10,
    fontWeight: '600',
    color: '#f59e0b',
    marginLeft: 4,
  },
  modalContainer: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  modalHeaderRight: {
    width: 24,
  },
  modalContent: {
    flex: 1,
    paddingHorizontal: 20,
  },
  modalSection: {
    marginVertical: 16,
  },
  modalSectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 12,
  },
  modalText: {
    fontSize: 14,
    color: '#64748b',
    marginBottom: 8,
    lineHeight: 20,
  },
  modalLabel: {
    fontWeight: '600',
    color: '#1e293b',
  },
  mapButton: {
    backgroundColor: '#3b82f6',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 8,
    marginTop: 12,
  },
  mapButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#ffffff',
    marginLeft: 8,
  },
});

export default AdminDeliveryMapScreen;
