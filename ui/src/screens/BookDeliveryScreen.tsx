import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  TextInput,
  Alert,
  Animated,
  Dimensions,
  StatusBar,
  Platform,
  Modal,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { BookDelivery } from '../types/ministry';
import DeliveryTrackingService, { DeliveryRecord, DeliveryStats } from '../services/DeliveryTrackingService';
import GeotrackingService from '../services/GeotrackingService';
import MapView, { Marker, Circle } from 'react-native-maps';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../constants';

const { width } = Dimensions.get('window');

interface BookDeliveryScreenProps {
  navigation: any;
}

const BookDeliveryScreen: React.FC<BookDeliveryScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const { currentLocation } = useLocation();
  
  // Enhanced delivery tracking state
  const [deliveryType, setDeliveryType] = useState<'to_door' | 'to_person'>('to_door');
  const [selectedBook, setSelectedBook] = useState('');
  const [quantity, setQuantity] = useState('1');
  const [recipientName, setRecipientName] = useState('');
  const [recipientContact, setRecipientContact] = useState('');
  const [notes, setNotes] = useState('');
  const [showPersonForm, setShowPersonForm] = useState(false);
  const [showDonationForm, setShowDonationForm] = useState(false);
  const [donationAmount, setDonationAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<'cash' | 'card' | 'digital'>('cash');
  const [currentLocationPoint, setCurrentLocationPoint] = useState<any>(null);
  const [deliveryStats, setDeliveryStats] = useState<DeliveryStats>({
    todayDeliveries: 0,
    todayToDoor: 0,
    todayToPerson: 0,
    todayDistance: 0,
    weeklyDeliveries: 0,
    totalDeliveries: 0,
    averageDeliveryTime: 0,
    mostActiveHour: 0,
  });
  const [isRecording, setIsRecording] = useState(false);
  const [showLocationModal, setShowLocationModal] = useState(false);
  
  const mapRef = useRef<MapView>(null);
  const [slideAnim] = useState(new Animated.Value(0));
  
  // Form state
  const [formData, setFormData] = useState({
    bookTitle: '',
    bookType: 'bible' as 'bible' | 'tract' | 'magazine' | 'study_guide',
    recipientName: '',
    recipientPhone: '',
    recipientAddress: '',
    notes: '',
    donationReceived: '',
    followUpRequired: false,
    status: 'delivered' as 'delivered' | 'refused' | 'not_home' | 'interested',
  });

  const bookTypes = [
    { id: 'bible', title: 'Bible', icon: '📖' },
    { id: 'tract', title: 'Tract', icon: '📄' },
    { id: 'magazine', title: 'Magazine', icon: '📰' },
    { id: 'study_guide', title: 'Study Guide', icon: '📚' },
  ];

  const deliveryStatuses = [
    { id: 'delivered', title: 'Delivered', icon: '✅', color: '#10B981' },
    { id: 'refused', title: 'Refused', icon: '❌', color: '#EF4444' },
    { id: 'not_home', title: 'Not Home', icon: '🏠', color: '#F59E0B' },
    { id: 'interested', title: 'Interested', icon: '⭐', color: '#8B5CF6' },
  ];

  useEffect(() => {
    initializeDeliveryTracking();
    loadDeliveryStats();
    getCurrentLocationForDelivery();
  }, []);

  // Initialize enhanced delivery tracking
  const initializeDeliveryTracking = async () => {
    try {
      await DeliveryTrackingService.initialize();
      
      // Start delivery session if not active
      if (!DeliveryTrackingService.isDeliverySessionActive()) {
        await DeliveryTrackingService.startDeliverySession();
        setIsRecording(true);
      }
    } catch (error) {
      console.error('Failed to initialize delivery tracking:', error);
    }
  };

  // Load delivery statistics
  const loadDeliveryStats = async () => {
    try {
      const stats = await DeliveryTrackingService.getStats();
      setDeliveryStats(stats);
    } catch (error) {
      console.error('Failed to load delivery stats:', error);
    }
  };

  // Get current location for delivery
  const getCurrentLocationForDelivery = async () => {
    try {
      const location = await DeliveryTrackingService.getCurrentDeliveryLocation();
      setCurrentLocationPoint(location);
    } catch (error) {
      console.error('Failed to get current location:', error);
    }
  };

  // Enhanced delivery submission
  const handleQuickDelivery = async () => {
    if (!selectedBook) {
      Alert.alert('Error', 'Please select a book');
      return;
    }

    try {
      setIsRecording(true);
      
      const delivery = await DeliveryTrackingService.quickDelivery(
        selectedBook,
        selectedBook,
        parseInt(quantity) || 1
      );

      Alert.alert(
        'Delivery Recorded!',
        `${selectedBook} delivered to door\\nLocation: ${delivery.location.latitude.toFixed(6)}, ${delivery.location.longitude.toFixed(6)}`,
        [{ text: 'OK', onPress: () => resetForm() }]
      );

      // Reload stats
      await loadDeliveryStats();
    } catch (error) {
      console.error('Error recording delivery:', error);
      Alert.alert('Error', 'Failed to record delivery');
    } finally {
      setIsRecording(false);
    }
  };

  // Handle person delivery
  const handlePersonDelivery = async () => {
    if (!selectedBook || !recipientName) {
      Alert.alert('Error', 'Please select a book and enter recipient name');
      return;
    }

    try {
      setIsRecording(true);
      
      const delivery = await DeliveryTrackingService.personDelivery(
        selectedBook,
        selectedBook,
        recipientName,
        recipientContact || undefined,
        notes || undefined,
        parseInt(quantity) || 1
      );

      Alert.alert(
        'Delivery Recorded!',
        `${selectedBook} delivered to ${recipientName}\\nLocation: ${delivery.location.latitude.toFixed(6)}, ${delivery.location.longitude.toFixed(6)}`,
        [{ text: 'OK', onPress: () => resetForm() }]
      );

      // Reload stats
      await loadDeliveryStats();
    } catch (error) {
      console.error('Error recording delivery:', error);
      Alert.alert('Error', 'Failed to record delivery');
    } finally {
      setIsRecording(false);
    }
  };

  // Handle donation delivery
  const handleDonationDelivery = async () => {
    if (!selectedBook || !donationAmount) {
      Alert.alert('Error', 'Please select a book and enter donation amount');
      return;
    }

    try {
      setIsRecording(true);
      
      const delivery = await DeliveryTrackingService.donationDelivery(
        selectedBook,
        selectedBook,
        parseFloat(donationAmount),
        paymentMethod,
        recipientName || undefined
      );

      Alert.alert(
        'Donation Recorded!',
        `${selectedBook} donation of $${donationAmount} received\\nMethod: ${paymentMethod}\\nLocation: ${delivery.location.latitude.toFixed(6)}, ${delivery.location.longitude.toFixed(6)}`,
        [{ text: 'OK', onPress: () => resetForm() }]
      );

      // Reload stats
      await loadDeliveryStats();
    } catch (error) {
      console.error('Error recording donation:', error);
      Alert.alert('Error', 'Failed to record donation');
    } finally {
      setIsRecording(false);
    }
  };

  // Reset form
  const resetForm = () => {
    setSelectedBook('');
    setQuantity('1');
    setRecipientName('');
    setRecipientContact('');
    setNotes('');
    setDonationAmount('');
    setShowPersonForm(false);
    setShowDonationForm(false);
    setDeliveryType('to_door');
  };

  // Stop delivery session
  const stopDeliverySession = async () => {
    try {
      await DeliveryTrackingService.stopDeliverySession();
      setIsRecording(false);
      Alert.alert('Session Ended', 'Delivery session has been stopped');
    } catch (error) {
      console.error('Error stopping delivery session:', error);
    }
  };

  // Legacy form submission (for compatibility)
  const handleSubmit = async () => {
    if (!formData.bookTitle || !formData.recipientAddress) {
      Alert.alert('Error', 'Please fill in required fields');
      return;
    }

    if (!currentLocation) {
      Alert.alert('Error', 'Location not available. Please enable GPS.');
      return;
    }

    try {
      const delivery: Omit<BookDelivery, 'id'> = {
        workerId: user?.id || '',
        workerName: user?.displayName || '',
        territoryId: 'territory-1', // This would come from assigned territory
        bookTitle: formData.bookTitle,
        bookType: formData.bookType,
        recipientName: formData.recipientName || undefined,
        recipientPhone: formData.recipientPhone || undefined,
        recipientAddress: formData.recipientAddress,
        location: {
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          accuracy: currentLocation.accuracy,
        },
        deliveryTime: new Date(),
        notes: formData.notes || undefined,
        followUpRequired: formData.followUpRequired,
        donationReceived: formData.donationReceived ? parseFloat(formData.donationReceived) : undefined,
        receiptNumber: formData.donationReceived ? `RCP-${Date.now()}` : undefined,
        status: formData.status,
      };

      // In production, this would save to Firestore
      console.log('Book delivery recorded:', delivery);
      
      Alert.alert(
        'Success!',
        'Book delivery has been recorded successfully.',
        [
          {
            text: 'Record Another',
            onPress: () => {
              setFormData({
                bookTitle: '',
                bookType: 'bible',
                recipientName: '',
                recipientPhone: '',
                recipientAddress: '',
                notes: '',
                donationReceived: '',
                followUpRequired: false,
                status: 'delivered',
              });
            },
          },
          {
            text: 'Back to Dashboard',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } catch (error) {
      Alert.alert('Error', 'Failed to record delivery. Please try again.');
      console.error('Delivery recording error:', error);
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="transparent" translucent />
      
      {/* Background Gradient */}
      <LinearGradient
        colors={['#0F0C29', '#24243e', '#302B63']}
        style={styles.backgroundGradient}
      />

      {/* Header */}
      <Animated.View 
        style={[
          styles.header,
          {
            transform: [{
              translateY: slideAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [-100, 0],
              }),
            }],
            opacity: slideAnim,
          },
        ]}
      >
        <TouchableOpacity
          style={styles.backButton}
          onPress={() => navigation.goBack()}
        >
          <MaterialIcons name="arrow-back" size={24} color="#ffffff" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Book Delivery</Text>
        <View style={styles.headerSpacer} />
      </Animated.View>

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Location Info */}
        {currentLocation && (
          <Animated.View 
            style={[
              styles.locationCard,
              {
                transform: [{
                  translateY: slideAnim.interpolate({
                    inputRange: [0, 1],
                    outputRange: [50, 0],
                  }),
                }],
                opacity: slideAnim,
              },
            ]}
          >
            <LinearGradient
              colors={['rgba(16, 185, 129, 0.1)', 'rgba(16, 185, 129, 0.05)']}
              style={styles.glassmorphismCard}
            >
              <Text style={styles.locationTitle}>📍 Current Location</Text>
              <Text style={styles.locationText}>
                {currentLocation.latitude.toFixed(6)}, {currentLocation.longitude.toFixed(6)}
              </Text>
              <Text style={styles.accuracyText}>
                Accuracy: ±{currentLocation.accuracy?.toFixed(0) || 'N/A'}m
              </Text>
            </LinearGradient>
          </Animated.View>
        )}

        {/* Book Type Selection */}
        <Animated.View 
          style={[
            styles.section,
            {
              transform: [{
                translateY: slideAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [100, 0],
                }),
              }],
              opacity: slideAnim,
            },
          ]}
        >
          <Text style={styles.sectionTitle}>Book Type *</Text>
          <View style={styles.bookTypeGrid}>
            {bookTypes.map((type) => (
              <TouchableOpacity
                key={type.id}
                style={[
                  styles.bookTypeCard,
                  formData.bookType === type.id && styles.bookTypeCardSelected,
                ]}
                onPress={() => setFormData({ ...formData, bookType: type.id as any })}
              >
                <Text style={styles.bookTypeIcon}>{type.icon}</Text>
                <Text style={[
                  styles.bookTypeTitle,
                  formData.bookType === type.id && styles.bookTypeTextSelected,
                ]}>
                  {type.title}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </Animated.View>

        {/* Book Title */}
        <Animated.View 
          style={[
            styles.section,
            {
              transform: [{
                translateY: slideAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [150, 0],
                }),
              }],
              opacity: slideAnim,
            },
          ]}
        >
          <Text style={styles.sectionTitle}>Book Title *</Text>
          <TextInput
            style={styles.textInput}
            value={formData.bookTitle}
            onChangeText={(text) => setFormData({ ...formData, bookTitle: text })}
            placeholder="Enter book title"
            placeholderTextColor="rgba(255,255,255,0.5)"
          />
        </Animated.View>

        {/* Recipient Information */}
        <Animated.View 
          style={[
            styles.section,
            {
              transform: [{
                translateY: slideAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [200, 0],
                }),
              }],
              opacity: slideAnim,
            },
          ]}
        >
          <Text style={styles.sectionTitle}>Recipient Information</Text>
          
          <TextInput
            style={styles.textInput}
            value={formData.recipientName}
            onChangeText={(text) => setFormData({ ...formData, recipientName: text })}
            placeholder="Recipient name (optional)"
            placeholderTextColor="rgba(255,255,255,0.5)"
          />
          
          <TextInput
            style={styles.textInput}
            value={formData.recipientPhone}
            onChangeText={(text) => setFormData({ ...formData, recipientPhone: text })}
            placeholder="Phone number (optional)"
            placeholderTextColor="rgba(255,255,255,0.5)"
            keyboardType="phone-pad"
          />
          
          <TextInput
            style={[styles.textInput, styles.textArea]}
            value={formData.recipientAddress}
            onChangeText={(text) => setFormData({ ...formData, recipientAddress: text })}
            placeholder="Address *"
            placeholderTextColor="rgba(255,255,255,0.5)"
            multiline
            numberOfLines={3}
          />
        </Animated.View>

        {/* Delivery Status */}
        <Animated.View 
          style={[
            styles.section,
            {
              transform: [{
                translateY: slideAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [250, 0],
                }),
              }],
              opacity: slideAnim,
            },
          ]}
        >
          <Text style={styles.sectionTitle}>Delivery Status</Text>
          <View style={styles.statusGrid}>
            {deliveryStatuses.map((status) => (
              <TouchableOpacity
                key={status.id}
                style={[
                  styles.statusCard,
                  formData.status === status.id && { backgroundColor: status.color + '20' },
                ]}
                onPress={() => setFormData({ ...formData, status: status.id as any })}
              >
                <Text style={styles.statusIcon}>{status.icon}</Text>
                <Text style={[
                  styles.statusTitle,
                  formData.status === status.id && { color: status.color },
                ]}>
                  {status.title}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </Animated.View>

        {/* Donation */}
        <Animated.View 
          style={[
            styles.section,
            {
              transform: [{
                translateY: slideAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [300, 0],
                }),
              }],
              opacity: slideAnim,
            },
          ]}
        >
          <Text style={styles.sectionTitle}>Donation (Optional)</Text>
          <TextInput
            style={styles.textInput}
            value={formData.donationReceived}
            onChangeText={(text) => setFormData({ ...formData, donationReceived: text })}
            placeholder="Amount received ($)"
            placeholderTextColor="rgba(255,255,255,0.5)"
            keyboardType="numeric"
          />
        </Animated.View>

        {/* Notes and Follow-up */}
        <Animated.View 
          style={[
            styles.section,
            {
              transform: [{
                translateY: slideAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [350, 0],
                }),
              }],
              opacity: slideAnim,
            },
          ]}
        >
          <Text style={styles.sectionTitle}>Additional Information</Text>
          
          <TextInput
            style={[styles.textInput, styles.textArea]}
            value={formData.notes}
            onChangeText={(text) => setFormData({ ...formData, notes: text })}
            placeholder="Notes (optional)"
            placeholderTextColor="rgba(255,255,255,0.5)"
            multiline
            numberOfLines={3}
          />
          
          <TouchableOpacity
            style={styles.checkboxContainer}
            onPress={() => setFormData({ ...formData, followUpRequired: !formData.followUpRequired })}
          >
            <View style={[
              styles.checkbox,
              formData.followUpRequired && styles.checkboxChecked,
            ]}>
              {formData.followUpRequired && <Text style={styles.checkmark}>✓</Text>}
            </View>
            <Text style={styles.checkboxLabel}>Follow-up required</Text>
          </TouchableOpacity>
        </Animated.View>

        {/* Submit Button */}
        <Animated.View 
          style={[
            styles.submitContainer,
            {
              transform: [{
                translateY: slideAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [400, 0],
                }),
              }],
              opacity: slideAnim,
            },
          ]}
        >
          <TouchableOpacity
            style={styles.submitButton}
            onPress={handleSubmit}
          >
            <LinearGradient
              colors={['#10B981', '#059669']}
              style={styles.submitButtonGradient}
            >
              <Text style={styles.submitButtonText}>Record Delivery</Text>
            </LinearGradient>
          </TouchableOpacity>
        </Animated.View>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0F0C29',
  },
  backgroundGradient: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingTop: Platform.OS === 'ios' ? 60 : 40,
    paddingBottom: 20,
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.1)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  backButtonText: {
    fontSize: 20,
    color: '#FFFFFF',
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  headerSpacer: {
    width: 40,
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
  },
  locationCard: {
    marginBottom: 20,
  },
  glassmorphismCard: {
    borderRadius: 15,
    padding: 20,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
  },
  locationTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 10,
  },
  locationText: {
    fontSize: 14,
    color: '#10B981',
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    marginBottom: 5,
  },
  accuracyText: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.6)',
  },
  section: {
    marginBottom: 25,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 15,
  },
  bookTypeGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  bookTypeCard: {
    width: (width - 60) / 2,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 15,
    padding: 20,
    alignItems: 'center',
    marginBottom: 10,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  bookTypeCardSelected: {
    backgroundColor: 'rgba(16, 185, 129, 0.2)',
    borderColor: '#10B981',
  },
  bookTypeIcon: {
    fontSize: 30,
    marginBottom: 10,
  },
  bookTypeTitle: {
    fontSize: 14,
    color: '#FFFFFF',
    textAlign: 'center',
  },
  bookTypeTextSelected: {
    color: '#10B981',
    fontWeight: 'bold',
  },
  textInput: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 12,
    padding: 15,
    fontSize: 16,
    color: '#FFFFFF',
    marginBottom: 15,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  textArea: {
    height: 80,
    textAlignVertical: 'top',
  },
  statusGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  statusCard: {
    width: (width - 60) / 2,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 12,
    padding: 15,
    alignItems: 'center',
    marginBottom: 10,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  statusIcon: {
    fontSize: 24,
    marginBottom: 8,
  },
  statusTitle: {
    fontSize: 14,
    color: '#FFFFFF',
    textAlign: 'center',
  },
  checkboxContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 10,
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 6,
    borderWidth: 2,
    borderColor: 'rgba(255,255,255,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  checkboxChecked: {
    backgroundColor: '#10B981',
    borderColor: '#10B981',
  },
  checkmark: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  checkboxLabel: {
    fontSize: 16,
    color: '#FFFFFF',
  },
  submitContainer: {
    marginBottom: 40,
  },
  submitButton: {
    borderRadius: 15,
    overflow: 'hidden',
  },
  submitButtonGradient: {
    paddingVertical: 18,
    alignItems: 'center',
  },
  submitButtonText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
});

export default BookDeliveryScreen;
