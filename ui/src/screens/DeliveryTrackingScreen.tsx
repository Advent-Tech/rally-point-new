import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  Alert,
  TextInput,
  Modal,
  ActivityIndicator,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import Icon from '../components/Icon';
import LocationPickerModal from '../components/LocationPickerModal';
import TerritoryPickerModal from '../components/TerritoryPickerModal';
import { ProfessionalActivityCard, StatusCard } from '../components/ModernCards';
import { GeoTerritory } from '../services/GeoTerritoryService';
import { DeliveryType, DeliveryStatus, DeliverySession } from '../types/ministry';
import { DeliveryServiceBackend, Delivery, CreateDeliveryRequest } from '../services/DeliveryServiceBackend';

const SESSION_STORAGE_KEY = 'delivery_session';

interface DeliveryTrackingScreenProps {
  navigation: any;
}

const DeliveryTrackingScreen: React.FC<DeliveryTrackingScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const { currentLocation } = useLocation();
  const [currentSession, setCurrentSession] = useState<DeliverySession | null>(null);
  const [deliveries, setDeliveries] = useState<Delivery[]>([]);
  const [loading, setLoading] = useState(false);
  const [showDeliveryModal, setShowDeliveryModal] = useState(false);
  const [showLocationPicker, setShowLocationPicker] = useState(false);
  const [showTerritoryPicker, setShowTerritoryPicker] = useState(false);
  const [selectedTerritory, setSelectedTerritory] = useState<GeoTerritory | null>(null);
  const [selectedDeliveryType, setSelectedDeliveryType] = useState<DeliveryType>('door');
  const [deliveryForm, setDeliveryForm] = useState({
    bookTitle: '',
    bookType: 'tract' as 'bible' | 'tract' | 'magazine' | 'study_guide',
    quantity: 1,
    recipientName: '',
    recipientAddress: '',
    latitude: 0,
    longitude: 0,
    notes: '',
    status: 'delivered' as DeliveryStatus,
  });

  // Initialize empty deliveriesByStatus with all required keys
  const createEmptyDeliveriesByStatus = (): Record<DeliveryStatus, number> => ({
    pending: 0,
    delivered: 0,
    delivered_to_person: 0,
    delivered_to_door: 0,
    rejected: 0,
    not_home: 0,
    refused: 0,
    follow_up: 0,
    interested: 0,
    in_progress: 0,
    failed: 0,
    cancelled: 0,
  });

  // Load session from storage on mount
  useEffect(() => {
    loadSavedSession();
  }, []);

  // Load deliveries when user changes
  useEffect(() => {
    if (user?.id) {
      loadDeliveries();
    }
  }, [user?.id]);

  const loadSavedSession = async () => {
    try {
      const savedSession = await AsyncStorage.getItem(SESSION_STORAGE_KEY);
      if (savedSession) {
        const session = JSON.parse(savedSession);
        // Check if session is still active and from today
        const sessionDate = new Date(session.startTime).toDateString();
        const today = new Date().toDateString();

        if (session.isActive && sessionDate === today) {
          // Restore session with proper date objects
          setCurrentSession({
            ...session,
            startTime: new Date(session.startTime),
            endTime: session.endTime ? new Date(session.endTime) : undefined,
            deliveriesByStatus: {
              ...createEmptyDeliveriesByStatus(),
              ...session.deliveriesByStatus,
            },
          });
        } else {
          // Clear old session
          await AsyncStorage.removeItem(SESSION_STORAGE_KEY);
        }
      }
    } catch (error) {
      console.error('Error loading saved session:', error);
    }
  };

  const saveSession = async (session: DeliverySession | null) => {
    try {
      if (session) {
        await AsyncStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
      } else {
        await AsyncStorage.removeItem(SESSION_STORAGE_KEY);
      }
    } catch (error) {
      console.error('Error saving session:', error);
    }
  };

  const loadDeliveries = useCallback(async () => {
    if (!user?.id) return;

    try {
      setLoading(true);
      const result = await DeliveryServiceBackend.getMyDeliveries(20);
      setDeliveries(result?.deliveries || []);
    } catch (error) {
      console.error('Error loading deliveries:', error);
      setDeliveries([]);
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  const startDeliverySession = () => {
    if (!currentLocation) {
      Alert.alert('Location Required', 'Please enable location services to start delivery tracking.');
      return;
    }

    const newSession: DeliverySession = {
      id: `session_${Date.now()}`,
      workerId: user?.id || '',
      workerName: user?.display_name || 'Worker',
      startTime: new Date(),
      territoryId: selectedTerritory?.id,
      territoryName: selectedTerritory?.entity_name,
      totalDeliveries: 0,
      deliveriesByStatus: createEmptyDeliveriesByStatus(),
      totalDistance: 0,
      isActive: true,
      syncStatus: 'pending',
    };

    setCurrentSession(newSession);
    saveSession(newSession);
    Alert.alert('Session Started', 'Delivery tracking session has been started successfully!');
  };

  const endDeliverySession = () => {
    if (!currentSession) return;

    Alert.alert(
      'End Session',
      'Are you sure you want to end the current delivery session?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'End Session',
          style: 'destructive',
          onPress: () => {
            const endedSession = {
              ...currentSession,
              endTime: new Date(),
              isActive: false,
            };
            setCurrentSession(endedSession);
            saveSession(null); // Clear from storage
            Alert.alert('Session Ended', `Your delivery session has been completed.\n\nTotal Deliveries: ${currentSession.totalDeliveries}`);
          },
        },
      ]
    );
  };

  const handleDeliveryTypeSelect = (type: DeliveryType) => {
    setSelectedDeliveryType(type);
    // Set initial location from current location
    if (currentLocation) {
      setDeliveryForm(prev => ({
        ...prev,
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
      }));
    }
    setShowDeliveryModal(true);
  };

  const handleLocationSelected = (location: { latitude: number; longitude: number; address: string }) => {
    setDeliveryForm(prev => ({
      ...prev,
      latitude: location.latitude,
      longitude: location.longitude,
      recipientAddress: location.address,
    }));
  };

  const handleTerritorySelected = (territory: GeoTerritory) => {
    setSelectedTerritory(territory);
    // Update session with territory info if session is active
    if (currentSession) {
      const updatedSession = {
        ...currentSession,
        territoryId: territory.id,
        territoryName: territory.entity_name,
      };
      setCurrentSession(updatedSession);
      saveSession(updatedSession);
    }
  };

  const saveDelivery = async () => {
    if (!user) {
      Alert.alert('Error', 'User information is missing.');
      return;
    }

    if (!deliveryForm.bookTitle.trim()) {
      Alert.alert('Error', 'Please enter the book title.');
      return;
    }

    if (!user.team_id) {
      Alert.alert('Error', 'You must be part of a team to record deliveries.');
      return;
    }

    // Use form location if set, otherwise use current location
    const lat = deliveryForm.latitude || currentLocation?.latitude;
    const lng = deliveryForm.longitude || currentLocation?.longitude;

    if (!lat || !lng) {
      Alert.alert('Error', 'Location is required. Please select a location on the map.');
      return;
    }

    try {
      setLoading(true);

      const deliveryRequest: CreateDeliveryRequest = {
        team_id: user.team_id,
        recipient_name: deliveryForm.recipientName || 'Unknown',
        address: deliveryForm.recipientAddress || 'Current Location',
        latitude: lat,
        longitude: lng,
        delivery_type: selectedDeliveryType === 'door' ? 'literature' : 'visit',
        priority: 'medium',
        notes: `${deliveryForm.bookTitle} (${deliveryForm.bookType}) x${deliveryForm.quantity}${deliveryForm.notes ? '\n' + deliveryForm.notes : ''}`,
        items: [{
          item_type: deliveryForm.bookType,
          item_name: deliveryForm.bookTitle,
          quantity: deliveryForm.quantity,
        }],
      };

      const newDelivery = await DeliveryServiceBackend.createDelivery(deliveryRequest);

      // If status is delivered, mark it as complete
      if (deliveryForm.status === 'delivered' || deliveryForm.status === 'delivered_to_person' || deliveryForm.status === 'delivered_to_door') {
        await DeliveryServiceBackend.completeDelivery(
          newDelivery.id,
          deliveryForm.notes,
          lat,
          lng
        );
      }

      // Refresh deliveries list
      await loadDeliveries();

      // Update session stats
      if (currentSession) {
        const updatedStats = { ...currentSession.deliveriesByStatus };
        const statusKey = deliveryForm.status as DeliveryStatus;
        if (statusKey in updatedStats) {
          updatedStats[statusKey] = (updatedStats[statusKey] || 0) + 1;
        }

        const updatedSession = {
          ...currentSession,
          totalDeliveries: currentSession.totalDeliveries + 1,
          deliveriesByStatus: updatedStats,
        };
        setCurrentSession(updatedSession);
        saveSession(updatedSession);
      }

      // Reset form
      setDeliveryForm({
        bookTitle: '',
        bookType: 'tract',
        quantity: 1,
        recipientName: '',
        recipientAddress: '',
        latitude: 0,
        longitude: 0,
        notes: '',
        status: 'delivered',
      });

      setShowDeliveryModal(false);
      Alert.alert('Success', 'Delivery recorded successfully!');
    } catch (error: any) {
      console.error('Error saving delivery:', error);
      Alert.alert('Error', error.message || 'Failed to save delivery. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const getSessionDuration = () => {
    if (!currentSession) return '0m';
    const start = new Date(currentSession.startTime);
    const end = currentSession.endTime ? new Date(currentSession.endTime) : new Date();
    const diffMs = end.getTime() - start.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 60) return `${diffMins}m`;
    const hours = Math.floor(diffMins / 60);
    const mins = diffMins % 60;
    return `${hours}h ${mins}m`;
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
          <Icon name="back" size={24} color="#ffffff" />
        </TouchableOpacity>

        <View style={styles.headerCenter}>
          <Text style={styles.headerTitle}>Delivery Tracking</Text>
          <Text style={styles.headerSubtitle}>Door-to-door & Personal Ministry</Text>
        </View>

        <View style={styles.headerRight} />
      </View>

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Session Status Card */}
        <View style={styles.section}>
          {currentSession ? (
            <>
              <StatusCard
                title={currentSession.isActive ? "Session Active" : "Session Ended"}
                subtitle={`Started: ${formatTime(new Date(currentSession.startTime))} • Duration: ${getSessionDuration()}${currentSession.territoryName ? `\n📍 ${currentSession.territoryName}` : ''}`}
                icon="activity"
                status={currentSession.isActive ? 'active' : 'completed'}
                style={styles.sessionCard}
              />

              {/* Territory Selector for Active Session */}
              {currentSession.isActive && (
                <TouchableOpacity
                  style={[styles.territorySelector, styles.territorySelectorActive]}
                  onPress={() => setShowTerritoryPicker(true)}
                >
                  <Icon name="pin" size={20} color={selectedTerritory || currentSession.territoryId ? '#10b981' : '#3b82f6'} />
                  <View style={styles.territorySelectorContent}>
                    <Text style={styles.territorySelectorLabel}>
                      {selectedTerritory || currentSession.territoryName ? 'Working Territory' : 'Set Territory'}
                    </Text>
                    <Text style={styles.territorySelectorValue} numberOfLines={1}>
                      {selectedTerritory?.entity_name || currentSession.territoryName || 'Tap to select a territory'}
                    </Text>
                  </View>
                  <Icon name="forward" size={16} color="#94a3b8" />
                </TouchableOpacity>
              )}

              {currentSession.isActive ? (
                <TouchableOpacity style={styles.endButton} onPress={endDeliverySession}>
                  <Icon name="stop" size={20} color="#ffffff" />
                  <Text style={styles.endButtonText}>End Session</Text>
                </TouchableOpacity>
              ) : (
                <TouchableOpacity style={styles.startButton} onPress={startDeliverySession}>
                  <Icon name="play" size={20} color="#ffffff" />
                  <Text style={styles.startButtonText}>Start New Session</Text>
                </TouchableOpacity>
              )}
            </>
          ) : (
            <>
              <StatusCard
                title="No Active Session"
                subtitle="Start a session to begin tracking deliveries"
                icon="activity"
                status="pending"
                style={styles.sessionCard}
              />

              {/* Territory Selector */}
              <TouchableOpacity
                style={styles.territorySelector}
                onPress={() => setShowTerritoryPicker(true)}
              >
                <Icon name="pin" size={20} color={selectedTerritory ? '#10b981' : '#3b82f6'} />
                <View style={styles.territorySelectorContent}>
                  <Text style={styles.territorySelectorLabel}>
                    {selectedTerritory ? 'Selected Territory' : 'Select Territory (Optional)'}
                  </Text>
                  <Text style={styles.territorySelectorValue} numberOfLines={1}>
                    {selectedTerritory ? selectedTerritory.entity_name : 'Tap to choose a territory from the map'}
                  </Text>
                </View>
                <Icon name="forward" size={16} color="#94a3b8" />
              </TouchableOpacity>

              <TouchableOpacity style={styles.startButton} onPress={startDeliverySession}>
                <Icon name="play" size={20} color="#ffffff" />
                <Text style={styles.startButtonText}>Start Delivery Session</Text>
              </TouchableOpacity>
            </>
          )}
        </View>

        {/* Delivery Type Selection - Only show when session is active */}
        {currentSession?.isActive && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Record New Delivery</Text>

            <View style={styles.deliveryTypeGrid}>
              <TouchableOpacity
                style={styles.deliveryTypeCard}
                onPress={() => handleDeliveryTypeSelect('door')}
              >
                <View style={styles.deliveryTypeIcon}>
                  <Icon name="house" size={32} color="#3b82f6" />
                </View>
                <Text style={styles.deliveryTypeTitle}>Door-to-Door</Text>
                <Text style={styles.deliveryTypeSubtitle}>House visits & literature placement</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.deliveryTypeCard}
                onPress={() => handleDeliveryTypeSelect('person')}
              >
                <View style={styles.deliveryTypeIcon}>
                  <Icon name="handshake" size={32} color="#3b82f6" />
                </View>
                <Text style={styles.deliveryTypeTitle}>Person-to-Person</Text>
                <Text style={styles.deliveryTypeSubtitle}>Direct personal contacts</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}

        {/* Session Statistics */}
        {currentSession && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Session Progress</Text>

            <View style={styles.statsGrid}>
              <View style={styles.statCard}>
                <Text style={styles.statNumber}>{currentSession.totalDeliveries}</Text>
                <Text style={styles.statLabel}>Total</Text>
              </View>

              <View style={styles.statCard}>
                <Text style={[styles.statNumber, { color: '#10b981' }]}>
                  {currentSession.deliveriesByStatus.delivered || 0}
                </Text>
                <Text style={styles.statLabel}>Delivered</Text>
              </View>

              <View style={styles.statCard}>
                <Text style={[styles.statNumber, { color: '#f59e0b' }]}>
                  {currentSession.deliveriesByStatus.not_home || 0}
                </Text>
                <Text style={styles.statLabel}>Not Home</Text>
              </View>

              <View style={styles.statCard}>
                <Text style={[styles.statNumber, { color: '#8b5cf6' }]}>
                  {currentSession.deliveriesByStatus.follow_up || 0}
                </Text>
                <Text style={styles.statLabel}>Follow-up</Text>
              </View>
            </View>
          </View>
        )}

        {/* Recent Deliveries */}
        {loading ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color="#3b82f6" />
            <Text style={styles.loadingText}>Loading deliveries...</Text>
          </View>
        ) : deliveries.length > 0 ? (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Recent Deliveries</Text>

            {deliveries.slice(0, 5).map((delivery) => (
              <ProfessionalActivityCard
                key={delivery.id}
                title={delivery.recipient_name || 'Unknown'}
                subtitle={`${delivery.delivery_type === 'literature' ? 'Door-to-door' : 'Person-to-person'} • ${delivery.status}`}
                icon="literature"
                status={delivery.status === 'delivered' ? 'completed' : delivery.status === 'pending' ? 'pending' : 'active'}
                style={styles.deliveryCard}
              />
            ))}
          </View>
        ) : (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Recent Deliveries</Text>
            <Text style={styles.emptyText}>
              {currentSession?.isActive
                ? 'No deliveries recorded yet. Tap above to record your first delivery!'
                : 'Start a session to begin recording deliveries.'}
            </Text>
          </View>
        )}
      </ScrollView>

      {/* Delivery Form Modal */}
      <Modal
        visible={showDeliveryModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowDeliveryModal(false)}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <TouchableOpacity onPress={() => setShowDeliveryModal(false)}>
              <Icon name="close" size={24} color="#64748b" />
            </TouchableOpacity>
            <Text style={styles.modalTitle}>
              {selectedDeliveryType === 'door' ? 'Door-to-Door' : 'Person-to-Person'} Delivery
            </Text>
            <TouchableOpacity onPress={saveDelivery} disabled={loading}>
              {loading ? (
                <ActivityIndicator size="small" color="#3b82f6" />
              ) : (
                <Text style={styles.saveButton}>Save</Text>
              )}
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.modalContent}>
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Book/Literature Title *</Text>
              <TextInput
                style={styles.formInput}
                value={deliveryForm.bookTitle}
                onChangeText={(text) => setDeliveryForm({...deliveryForm, bookTitle: text})}
                placeholder="Enter book or literature title"
              />
            </View>

            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Type</Text>
              <View style={styles.typeSelector}>
                {['tract', 'magazine', 'bible', 'study_guide'].map((type) => (
                  <TouchableOpacity
                    key={type}
                    style={[
                      styles.typeOption,
                      deliveryForm.bookType === type && styles.typeOptionSelected
                    ]}
                    onPress={() => setDeliveryForm({...deliveryForm, bookType: type as any})}
                  >
                    <Text style={[
                      styles.typeOptionText,
                      deliveryForm.bookType === type && styles.typeOptionTextSelected
                    ]}>
                      {type.replace('_', ' ').toUpperCase()}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>

            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Quantity</Text>
              <View style={styles.quantitySelector}>
                <TouchableOpacity
                  style={styles.quantityButton}
                  onPress={() => setDeliveryForm({
                    ...deliveryForm,
                    quantity: Math.max(1, deliveryForm.quantity - 1)
                  })}
                >
                  <Icon name="remove" size={20} color="#64748b" />
                </TouchableOpacity>
                <Text style={styles.quantityText}>{deliveryForm.quantity}</Text>
                <TouchableOpacity
                  style={styles.quantityButton}
                  onPress={() => setDeliveryForm({
                    ...deliveryForm,
                    quantity: deliveryForm.quantity + 1
                  })}
                >
                  <Icon name="add" size={20} color="#64748b" />
                </TouchableOpacity>
              </View>
            </View>

            {selectedDeliveryType === 'person' && (
              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Recipient Name</Text>
                <TextInput
                  style={styles.formInput}
                  value={deliveryForm.recipientName}
                  onChangeText={(text) => setDeliveryForm({...deliveryForm, recipientName: text})}
                  placeholder="Enter recipient's name"
                />
              </View>
            )}

            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Location *</Text>
              <TouchableOpacity
                style={styles.locationPickerButton}
                onPress={() => setShowLocationPicker(true)}
              >
                <Icon name="pin" size={20} color="#3b82f6" />
                <Text style={styles.locationPickerText} numberOfLines={2}>
                  {deliveryForm.recipientAddress || 'Tap to select location on map'}
                </Text>
                <Icon name="forward" size={16} color="#94a3b8" />
              </TouchableOpacity>
              {deliveryForm.latitude !== 0 && (
                <Text style={styles.coordsText}>
                  {deliveryForm.latitude.toFixed(6)}, {deliveryForm.longitude.toFixed(6)}
                </Text>
              )}
            </View>

            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Delivery Status</Text>
              <View style={styles.statusSelector}>
                {[
                  { key: 'delivered', label: 'Delivered', color: '#10b981' },
                  { key: 'not_home', label: 'Not Home', color: '#f59e0b' },
                  { key: 'refused', label: 'Refused', color: '#ef4444' },
                  { key: 'interested', label: 'Interested', color: '#3b82f6' },
                  { key: 'follow_up', label: 'Follow Up', color: '#8b5cf6' },
                ].map((status) => (
                  <TouchableOpacity
                    key={status.key}
                    style={[
                      styles.statusOption,
                      deliveryForm.status === status.key && { backgroundColor: status.color }
                    ]}
                    onPress={() => setDeliveryForm({...deliveryForm, status: status.key as DeliveryStatus})}
                  >
                    <Text style={[
                      styles.statusOptionText,
                      deliveryForm.status === status.key && styles.statusOptionTextSelected
                    ]}>
                      {status.label}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>

            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Notes (Optional)</Text>
              <TextInput
                style={[styles.formInput, styles.notesInput]}
                value={deliveryForm.notes}
                onChangeText={(text) => setDeliveryForm({...deliveryForm, notes: text})}
                placeholder="Add any additional notes..."
                multiline
                numberOfLines={3}
              />
            </View>
          </ScrollView>
        </SafeAreaView>
      </Modal>

      {/* Location Picker Modal */}
      <LocationPickerModal
        visible={showLocationPicker}
        onClose={() => setShowLocationPicker(false)}
        onLocationSelected={handleLocationSelected}
        initialLocation={
          deliveryForm.latitude !== 0
            ? { latitude: deliveryForm.latitude, longitude: deliveryForm.longitude }
            : currentLocation
              ? { latitude: currentLocation.latitude, longitude: currentLocation.longitude }
              : undefined
        }
        initialAddress={deliveryForm.recipientAddress}
      />

      {/* Territory Picker Modal */}
      <TerritoryPickerModal
        visible={showTerritoryPicker}
        onClose={() => setShowTerritoryPicker(false)}
        onTerritorySelected={handleTerritorySelected}
        selectedTerritoryId={selectedTerritory?.id}
        title="Select Delivery Territory"
      />
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
  headerRight: {
    width: 40,
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
  sessionCard: {
    marginBottom: 16,
  },
  territorySelector: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  territorySelectorContent: {
    flex: 1,
    marginLeft: 12,
    marginRight: 8,
  },
  territorySelectorLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1e293b',
    marginBottom: 4,
  },
  territorySelectorValue: {
    fontSize: 13,
    color: '#64748b',
  },
  territorySelectorActive: {
    borderColor: '#10b981',
    borderWidth: 1,
  },
  startButton: {
    backgroundColor: '#10b981',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 6,
  },
  startButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#ffffff',
    marginLeft: 8,
  },
  endButton: {
    backgroundColor: '#ef4444',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 6,
  },
  endButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#ffffff',
    marginLeft: 8,
  },
  deliveryTypeGrid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  deliveryTypeCard: {
    width: '48%',
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 20,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  deliveryTypeIcon: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#f1f5f9',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  deliveryTypeTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1e293b',
    marginBottom: 8,
    textAlign: 'center',
  },
  deliveryTypeSubtitle: {
    fontSize: 12,
    color: '#64748b',
    textAlign: 'center',
    lineHeight: 16,
  },
  statsGrid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  statCard: {
    flex: 1,
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginHorizontal: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  statNumber: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 11,
    color: '#64748b',
    textAlign: 'center',
  },
  deliveryCard: {
    marginBottom: 12,
  },
  loadingContainer: {
    padding: 40,
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 14,
    color: '#64748b',
  },
  emptyText: {
    fontSize: 14,
    color: '#64748b',
    textAlign: 'center',
    paddingVertical: 20,
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
  saveButton: {
    fontSize: 16,
    fontWeight: '600',
    color: '#3b82f6',
  },
  modalContent: {
    flex: 1,
    paddingHorizontal: 20,
  },
  formGroup: {
    marginVertical: 12,
  },
  formLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1e293b',
    marginBottom: 8,
  },
  formInput: {
    borderWidth: 1,
    borderColor: '#d1d5db',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    backgroundColor: '#ffffff',
  },
  notesInput: {
    height: 80,
    textAlignVertical: 'top',
  },
  typeSelector: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  typeOption: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#f1f5f9',
    marginRight: 8,
    marginBottom: 8,
  },
  typeOptionSelected: {
    backgroundColor: '#3b82f6',
  },
  typeOptionText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#64748b',
  },
  typeOptionTextSelected: {
    color: '#ffffff',
  },
  quantitySelector: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  quantityButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#f1f5f9',
    justifyContent: 'center',
    alignItems: 'center',
  },
  quantityText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
    marginHorizontal: 20,
  },
  locationPickerButton: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#d1d5db',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 14,
    backgroundColor: '#ffffff',
  },
  locationPickerText: {
    flex: 1,
    fontSize: 16,
    color: '#64748b',
    marginLeft: 8,
    marginRight: 8,
  },
  coordsText: {
    fontSize: 12,
    color: '#94a3b8',
    marginTop: 4,
    fontFamily: 'monospace',
  },
  statusSelector: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  statusOption: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#f1f5f9',
    marginRight: 8,
    marginBottom: 8,
  },
  statusOptionText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#64748b',
  },
  statusOptionTextSelected: {
    color: '#ffffff',
  },
});

export default DeliveryTrackingScreen;
