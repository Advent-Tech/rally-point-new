import React, { useState } from 'react';
import {
  View,
  Text,
  Modal,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  TextInput,
  Alert,
  Image,
  ScrollView,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import Icon from './Icon';
import LocationPickerModal from './LocationPickerModal';
import { BookDelivery, DeliveryType, DeliveryStatus } from '../types/ministry';
import { DeliveryServiceBackend, CreateDeliveryRequest } from '../services/DeliveryServiceBackend';

interface QuickDeliveryModalProps {
  visible: boolean;
  onClose: () => void;
  onDeliveryLogged: (delivery: BookDelivery) => void;
}

const QuickDeliveryModal: React.FC<QuickDeliveryModalProps> = ({
  visible,
  onClose,
  onDeliveryLogged,
}) => {
  const { user } = useAuth();
  const { currentLocation } = useLocation();
  const [selectedType, setSelectedType] = useState<DeliveryType>('door');
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [showLocationPicker, setShowLocationPicker] = useState(false);
  const [selectedCoordinates, setSelectedCoordinates] = useState<{
    latitude: number;
    longitude: number;
  } | null>(null);
  const [formData, setFormData] = useState({
    bookTitle: '',
    bookType: 'tract' as const,
    quantity: 1,
    recipientName: '',
    address: '',
    notes: '',
    status: 'delivered_to_door' as DeliveryStatus,
  });

  const resetForm = () => {
    setFormData({
      bookTitle: '',
      bookType: 'tract',
      quantity: 1,
      recipientName: '',
      address: '',
      notes: '',
      status: 'delivered_to_door',
    });
    setPhotoUri(null);
    setSelectedType('door');
    setSelectedCoordinates(null);
  };

  const handleLocationSelected = (location: {
    latitude: number;
    longitude: number;
    address: string;
  }) => {
    setSelectedCoordinates({
      latitude: location.latitude,
      longitude: location.longitude,
    });
    setFormData({ ...formData, address: location.address });
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  const takePhoto = async () => {
    try {
      const { status } = await ImagePicker.requestCameraPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Required', 'Camera permission is needed to take photos.');
        return;
      }

      const result = await ImagePicker.launchCameraAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        aspect: [4, 3],
        quality: 0.8,
      });

      if (!result.canceled && result.assets[0]) {
        setPhotoUri(result.assets[0].uri);
      }
    } catch (error) {
      console.error('Error taking photo:', error);
      Alert.alert('Error', 'Failed to take photo. Please try again.');
    }
  };

  const selectFromGallery = async () => {
    try {
      const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Required', 'Gallery permission is needed to select photos.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        aspect: [4, 3],
        quality: 0.8,
      });

      if (!result.canceled && result.assets[0]) {
        setPhotoUri(result.assets[0].uri);
      }
    } catch (error) {
      console.error('Error selecting photo:', error);
      Alert.alert('Error', 'Failed to select photo. Please try again.');
    }
  };

  const handlePhotoOptions = () => {
    Alert.alert(
      'Add Photo Proof',
      'Choose how you want to add a photo',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Take Photo', onPress: takePhoto },
        { text: 'Choose from Gallery', onPress: selectFromGallery },
      ]
    );
  };

  const logDelivery = async () => {
    // Use selected coordinates if available, otherwise fall back to current location
    const deliveryLocation = selectedCoordinates || currentLocation;

    if (!deliveryLocation || !user) {
      Alert.alert('Error', 'Location or user information is missing.');
      return;
    }

    if (!formData.bookTitle.trim()) {
      Alert.alert('Error', 'Please enter the book/literature title.');
      return;
    }

    if (!user.team_id) {
      Alert.alert('Error', 'You must be part of a team to log deliveries.');
      return;
    }

    setIsLoading(true);

    try {
      const deliveryRequest: CreateDeliveryRequest = {
        team_id: user.team_id,
        recipient_name: formData.recipientName || 'Unknown',
        address: formData.address || 'Current Location',
        latitude: deliveryLocation.latitude,
        longitude: deliveryLocation.longitude,
        delivery_type: selectedType === 'door' ? 'literature' : 'visit',
        priority: 'medium',
        notes: `${formData.bookTitle} (${formData.bookType}) x${formData.quantity}${formData.notes ? '\n' + formData.notes : ''}`,
        items: [{
          item_type: formData.bookType,
          item_name: formData.bookTitle,
          quantity: formData.quantity,
        }],
      };

      const newBackendDelivery = await DeliveryServiceBackend.createDelivery(deliveryRequest);

      // If status is delivered, mark it as complete
      if (formData.status === 'delivered_to_person' || formData.status === 'delivered_to_door') {
        await DeliveryServiceBackend.completeDelivery(
          newBackendDelivery.id,
          formData.notes,
          deliveryLocation.latitude,
          deliveryLocation.longitude
        );
      }

      // Create a BookDelivery object for the callback
      const newDelivery: BookDelivery = {
        id: newBackendDelivery.id,
        workerId: user.id,
        workerName: user.display_name || 'Worker',
        territoryId: 'territory_1',
        deliveryType: selectedType,
        bookTitle: formData.bookTitle,
        bookType: formData.bookType,
        quantity: formData.quantity,
        recipientName: formData.recipientName || undefined,
        recipientAddress: formData.address,
        location: {
          latitude: deliveryLocation.latitude,
          longitude: deliveryLocation.longitude,
          accuracy: currentLocation?.accuracy,
        },
        deliveryTime: new Date(),
        notes: formData.notes || undefined,
        followUpRequired: formData.status === 'follow_up' || formData.status === 'interested',
        status: formData.status,
        syncStatus: 'synced',
      };

      onDeliveryLogged(newDelivery);
      handleClose();

      Alert.alert(
        'Success!',
        `${selectedType === 'door' ? 'Door-to-door' : 'Person-to-person'} delivery logged successfully!`
      );
    } catch (error: any) {
      console.error('Error logging delivery:', error);
      Alert.alert('Error', error.message || 'Failed to log delivery. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={handleClose}
    >
      <SafeAreaView style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={handleClose}>
            <Icon name="close" size={24} color="#64748b" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Log Delivery</Text>
          <TouchableOpacity 
            onPress={logDelivery} 
            disabled={isLoading}
            style={[styles.saveButton, isLoading && styles.saveButtonDisabled]}
          >
            <Text style={[styles.saveButtonText, isLoading && styles.saveButtonTextDisabled]}>
              {isLoading ? 'Saving...' : 'Save'}
            </Text>
          </TouchableOpacity>
        </View>

        <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
          {/* Delivery Type Selection */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Delivery Type</Text>
            <View style={styles.typeSelector}>
              <TouchableOpacity
                style={[styles.typeCard, selectedType === 'door' && styles.typeCardSelected]}
                onPress={() => setSelectedType('door')}
              >
                <Icon name="house" size={24} color={selectedType === 'door' ? '#ffffff' : '#3b82f6'} />
                <Text style={[styles.typeText, selectedType === 'door' && styles.typeTextSelected]}>
                  To Door
                </Text>
                <Text style={[styles.typeSubtext, selectedType === 'door' && styles.typeSubtextSelected]}>
                  Left at doorstep
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.typeCard, selectedType === 'person' && styles.typeCardSelected]}
                onPress={() => setSelectedType('person')}
              >
                <Icon name="handshake" size={24} color={selectedType === 'person' ? '#ffffff' : '#3b82f6'} />
                <Text style={[styles.typeText, selectedType === 'person' && styles.typeTextSelected]}>
                  To Person
                </Text>
                <Text style={[styles.typeSubtext, selectedType === 'person' && styles.typeSubtextSelected]}>
                  Handed directly
                </Text>
              </TouchableOpacity>
            </View>
          </View>

          {/* Photo Proof Section */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Photo Proof (Optional)</Text>
            {photoUri ? (
              <View style={styles.photoContainer}>
                <Image source={{ uri: photoUri }} style={styles.photoPreview} />
                <TouchableOpacity style={styles.changePhotoButton} onPress={handlePhotoOptions}>
                  <Icon name="edit" size={16} color="#3b82f6" />
                  <Text style={styles.changePhotoText}>Change Photo</Text>
                </TouchableOpacity>
              </View>
            ) : (
              <TouchableOpacity style={styles.addPhotoButton} onPress={handlePhotoOptions}>
                <Icon name="camera" size={24} color="#64748b" />
                <Text style={styles.addPhotoText}>Add Photo Proof</Text>
                <Text style={styles.addPhotoSubtext}>
                  {selectedType === 'door' ? 'Photo of door/house' : 'Photo with person'}
                </Text>
              </TouchableOpacity>
            )}
          </View>

          {/* Book Details */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Literature Details</Text>
            
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Title *</Text>
              <TextInput
                style={styles.formInput}
                value={formData.bookTitle}
                onChangeText={(text) => setFormData({...formData, bookTitle: text})}
                placeholder="Enter book or literature title"
              />
            </View>

            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Type</Text>
              <View style={styles.bookTypeSelector}>
                {['tract', 'magazine', 'bible', 'study_guide'].map((type) => (
                  <TouchableOpacity
                    key={type}
                    style={[
                      styles.bookTypeOption,
                      formData.bookType === type && styles.bookTypeOptionSelected
                    ]}
                    onPress={() => setFormData({...formData, bookType: type as any})}
                  >
                    <Text style={[
                      styles.bookTypeText,
                      formData.bookType === type && styles.bookTypeTextSelected
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
                  onPress={() => setFormData({
                    ...formData, 
                    quantity: Math.max(1, formData.quantity - 1)
                  })}
                >
                  <Icon name="remove" size={20} color="#64748b" />
                </TouchableOpacity>
                <Text style={styles.quantityText}>{formData.quantity}</Text>
                <TouchableOpacity
                  style={styles.quantityButton}
                  onPress={() => setFormData({
                    ...formData, 
                    quantity: formData.quantity + 1
                  })}
                >
                  <Icon name="add" size={20} color="#64748b" />
                </TouchableOpacity>
              </View>
            </View>
          </View>

          {/* Additional Details */}
          {selectedType === 'person' && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Recipient Details</Text>
              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Name (Optional)</Text>
                <TextInput
                  style={styles.formInput}
                  value={formData.recipientName}
                  onChangeText={(text) => setFormData({...formData, recipientName: text})}
                  placeholder="Enter recipient's name"
                />
              </View>
            </View>
          )}

          <View style={styles.section}>
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Address/Location</Text>
              <View style={styles.addressInputContainer}>
                <TextInput
                  style={[styles.formInput, styles.addressInput]}
                  value={formData.address}
                  onChangeText={(text) => setFormData({...formData, address: text})}
                  placeholder="Enter address or location details"
                  multiline
                  numberOfLines={2}
                />
                <TouchableOpacity
                  style={styles.locationPickerButton}
                  onPress={() => setShowLocationPicker(true)}
                >
                  <MaterialIcons name="map" size={20} color="#ffffff" />
                  <Text style={styles.locationPickerButtonText}>Pick</Text>
                </TouchableOpacity>
              </View>
              {selectedCoordinates && (
                <View style={styles.selectedLocationBadge}>
                  <MaterialIcons name="check-circle" size={14} color="#10b981" />
                  <Text style={styles.selectedLocationText}>
                    Location selected on map
                  </Text>
                </View>
              )}
            </View>

            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Status</Text>
              <View style={styles.statusSelector}>
                {[
                  { key: 'delivered_to_person', label: 'Delivered to Person', color: '#10b981' },
                  { key: 'delivered_to_door', label: 'Delivered to Door', color: '#059669' },
                  { key: 'rejected', label: 'Rejected', color: '#ef4444' },
                  { key: 'not_home', label: 'Not Home', color: '#f59e0b' },
                  { key: 'interested', label: 'Interested', color: '#3b82f6' },
                ].map((status) => (
                  <TouchableOpacity
                    key={status.key}
                    style={[
                      styles.statusOption,
                      formData.status === status.key && { backgroundColor: status.color }
                    ]}
                    onPress={() => setFormData({...formData, status: status.key as DeliveryStatus})}
                  >
                    <Text style={[
                      styles.statusText,
                      formData.status === status.key && styles.statusTextSelected
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
                value={formData.notes}
                onChangeText={(text) => setFormData({...formData, notes: text})}
                placeholder="Add any additional notes..."
                multiline
                numberOfLines={3}
              />
            </View>
          </View>

          {/* GPS Location Display */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>📍 GPS Location</Text>
            <View style={styles.gpsCard}>
              <Text style={styles.gpsText}>
                Lat: {(selectedCoordinates?.latitude || currentLocation?.latitude)?.toFixed(6) || 'N/A'}
              </Text>
              <Text style={styles.gpsText}>
                Lng: {(selectedCoordinates?.longitude || currentLocation?.longitude)?.toFixed(6) || 'N/A'}
              </Text>
              <Text style={styles.gpsSubtext}>
                {selectedCoordinates ? 'Selected on map' : 'Auto-captured at delivery time'}
              </Text>
            </View>
          </View>
        </ScrollView>
      </SafeAreaView>

      {/* Location Picker Modal */}
      <LocationPickerModal
        visible={showLocationPicker}
        onClose={() => setShowLocationPicker(false)}
        onLocationSelected={handleLocationSelected}
        initialLocation={selectedCoordinates || (currentLocation ? {
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
        } : undefined)}
        initialAddress={formData.address}
      />
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  saveButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: '#3b82f6',
  },
  saveButtonDisabled: {
    backgroundColor: '#94a3b8',
  },
  saveButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#ffffff',
  },
  saveButtonTextDisabled: {
    color: '#e2e8f0',
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
  },
  section: {
    marginVertical: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 12,
  },
  typeSelector: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  typeCard: {
    width: '48%',
    backgroundColor: '#f8fafc',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#e2e8f0',
  },
  typeCardSelected: {
    backgroundColor: '#3b82f6',
    borderColor: '#3b82f6',
  },
  typeText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1e293b',
    marginTop: 8,
  },
  typeTextSelected: {
    color: '#ffffff',
  },
  typeSubtext: {
    fontSize: 12,
    color: '#64748b',
    marginTop: 4,
  },
  typeSubtextSelected: {
    color: '#e2e8f0',
  },
  photoContainer: {
    alignItems: 'center',
  },
  photoPreview: {
    width: 200,
    height: 150,
    borderRadius: 12,
    marginBottom: 12,
  },
  changePhotoButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: '#f1f5f9',
  },
  changePhotoText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#3b82f6',
    marginLeft: 6,
  },
  addPhotoButton: {
    backgroundColor: '#f8fafc',
    borderRadius: 12,
    padding: 24,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#e2e8f0',
    borderStyle: 'dashed',
  },
  addPhotoText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#64748b',
    marginTop: 8,
  },
  addPhotoSubtext: {
    fontSize: 12,
    color: '#94a3b8',
    marginTop: 4,
  },
  formGroup: {
    marginBottom: 16,
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
  addressInputContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
  },
  addressInput: {
    flex: 1,
  },
  locationPickerButton: {
    backgroundColor: '#3b82f6',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 12,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 4,
  },
  locationPickerButtonText: {
    color: '#ffffff',
    fontWeight: '600',
    fontSize: 14,
  },
  selectedLocationBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: 8,
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: '#ecfdf5',
    borderRadius: 12,
    alignSelf: 'flex-start',
  },
  selectedLocationText: {
    fontSize: 12,
    color: '#10b981',
    fontWeight: '500',
  },
  notesInput: {
    height: 80,
    textAlignVertical: 'top',
  },
  bookTypeSelector: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  bookTypeOption: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#f1f5f9',
    marginRight: 8,
    marginBottom: 8,
  },
  bookTypeOptionSelected: {
    backgroundColor: '#3b82f6',
  },
  bookTypeText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#64748b',
  },
  bookTypeTextSelected: {
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
  statusText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#64748b',
  },
  statusTextSelected: {
    color: '#ffffff',
  },
  gpsCard: {
    backgroundColor: '#f1f5f9',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  gpsText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1e293b',
    fontFamily: 'monospace',
    marginBottom: 4,
  },
  gpsSubtext: {
    fontSize: 12,
    color: '#64748b',
    marginTop: 8,
  },
});

export default QuickDeliveryModal;
