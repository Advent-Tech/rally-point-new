import React, { useState, useEffect } from 'react';
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
  Animated,
  Dimensions,
} from 'react-native';
// import { BarCodeScanner } from 'expo-barcode-scanner'; // Commented out for Expo Go compatibility
import * as ImagePicker from 'expo-image-picker';
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { BookDelivery, DeliveryType, DeliveryStatus } from '../types/ministry';
import DeliveryService from '../services/DeliveryService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface EnhancedDeliveryModalProps {
  visible: boolean;
  onClose: () => void;
  onDeliveryLogged: (delivery: BookDelivery) => void;
}

const { height: screenHeight } = Dimensions.get('window');

const EnhancedDeliveryModal: React.FC<EnhancedDeliveryModalProps> = ({
  visible,
  onClose,
  onDeliveryLogged,
}) => {
  const { user } = useAuth();
  const { currentLocation } = useLocation();
  
  // Modal state management
  const [currentStep, setCurrentStep] = useState<'type' | 'scan' | 'details'>('type');
  const [selectedType, setSelectedType] = useState<DeliveryType>('door');
  const [showScanner, setShowScanner] = useState(false);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [scannedData, setScannedData] = useState<string | null>(null);
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  
  // Form data
  const [formData, setFormData] = useState({
    bookTitle: '',
    bookType: 'tract' as const,
    quantity: 1,
    recipientName: '',
    address: '',
    notes: '',
    status: 'delivered_to_door' as DeliveryStatus,
  });

  // Animation
  const slideAnim = useState(new Animated.Value(screenHeight))[0];

  // Request camera permissions (disabled for Expo Go compatibility)
  useEffect(() => {
    // For now, we'll skip the barcode scanner and go directly to manual entry
    // This will be enabled when using a development build
    setHasPermission(false);
  }, []);

  // Animate modal
  useEffect(() => {
    if (visible) {
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    } else {
      Animated.timing(slideAnim, {
        toValue: screenHeight,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }
  }, [visible]);

  const resetForm = () => {
    setCurrentStep('type');
    setSelectedType('door');
    setScannedData(null);
    setPhotoUri(null);
    setShowScanner(false);
    setFormData({
      bookTitle: '',
      bookType: 'tract',
      quantity: 1,
      recipientName: '',
      address: '',
      notes: '',
      status: 'delivered_to_door',
    });
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  // Handle delivery type selection
  const handleTypeSelection = (type: DeliveryType) => {
    setSelectedType(type);
    setFormData(prev => ({
      ...prev,
      status: type === 'door' ? 'delivered_to_door' : 'delivered_to_person'
    }));
    setCurrentStep('scan');
  };

  // Handle QR code scan
  const handleBarCodeScanned = ({ type, data }: { type: string; data: string }) => {
    setScannedData(data);
    setShowScanner(false);
    
    // Try to parse book information from QR code
    try {
      const bookInfo = JSON.parse(data);
      if (bookInfo.title) {
        setFormData(prev => ({
          ...prev,
          bookTitle: bookInfo.title,
          bookType: bookInfo.type || 'tract',
          quantity: bookInfo.quantity || 1,
        }));
      }
    } catch (error) {
      // If not JSON, use the raw data as book title
      setFormData(prev => ({
        ...prev,
        bookTitle: data,
      }));
    }
    
    setCurrentStep('details');
    Alert.alert('QR Code Scanned', `Book information captured: ${data}`);
  };

  // Skip scanning and go to manual entry
  const skipScanning = () => {
    setCurrentStep('details');
  };

  // Take photo proof
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

  // Submit delivery
  const submitDelivery = async () => {
    if (!currentLocation || !user) {
      Alert.alert('Error', 'Location or user information is missing.');
      return;
    }

    if (!formData.bookTitle.trim()) {
      Alert.alert('Error', 'Please enter the book/literature title.');
      return;
    }

    setIsLoading(true);

    try {
      const deliveryData: Omit<BookDelivery, 'id'> = {
        workerId: user.uid,
        workerName: user.displayName || 'Worker',
        territoryId: 'territory_1', // This would come from current territory
        deliveryType: selectedType,
        bookTitle: formData.bookTitle,
        bookType: formData.bookType,
        quantity: formData.quantity,
        recipientName: formData.recipientName || undefined,
        recipientAddress: formData.address,
        location: {
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          accuracy: currentLocation.accuracy,
        },
        deliveryTime: new Date(),
        notes: formData.notes || undefined,
        followUpRequired: formData.status === 'follow_up' || formData.status === 'interested',
        status: formData.status,
        syncStatus: 'pending',
        barcode: scannedData || undefined,
      };

      const deliveryId = await DeliveryService.createDelivery(deliveryData);
      
      const newDelivery: BookDelivery = {
        id: deliveryId,
        ...deliveryData,
      };

      onDeliveryLogged(newDelivery);
      handleClose();
      
      Alert.alert(
        'Success!', 
        `${selectedType === 'door' ? 'Door-to-door' : 'Person-to-person'} delivery logged successfully!`
      );
    } catch (error) {
      console.error('Error logging delivery:', error);
      Alert.alert('Error', 'Failed to log delivery. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  if (!visible) return null;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="none"
      onRequestClose={handleClose}
    >
      <View style={styles.overlay}>
        <Animated.View 
          style={[
            styles.modalContainer,
            {
              transform: [{ translateY: slideAnim }]
            }
          ]}
        >
          <SafeAreaView style={styles.container}>
            {/* Header */}
            <View style={styles.header}>
              <TouchableOpacity onPress={handleClose}>
                <Ionicons name="close" size={24} color={COLORS.text.secondary} />
              </TouchableOpacity>
              <Text style={styles.headerTitle}>Book Delivery</Text>
              <View style={styles.stepIndicator}>
                <Text style={styles.stepText}>
                  {currentStep === 'type' ? '1/3' : currentStep === 'scan' ? '2/3' : '3/3'}
                </Text>
              </View>
            </View>

            {/* Content based on current step */}
            {currentStep === 'type' && (
              <DeliveryTypeSelection
                selectedType={selectedType}
                onTypeSelect={handleTypeSelection}
              />
            )}

            {currentStep === 'scan' && (
              <QRScannerStep
                showScanner={showScanner}
                hasPermission={hasPermission}
                onStartScan={() => setShowScanner(true)}
                onBarCodeScanned={handleBarCodeScanned}
                onSkip={skipScanning}
                scannedData={scannedData}
              />
            )}

            {currentStep === 'details' && (
              <DeliveryDetailsForm
                formData={formData}
                setFormData={setFormData}
                selectedType={selectedType}
                photoUri={photoUri}
                onTakePhoto={takePhoto}
                currentLocation={currentLocation}
                isLoading={isLoading}
                onSubmit={submitDelivery}
                scannedData={scannedData}
              />
            )}
          </SafeAreaView>
        </Animated.View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContainer: {
    backgroundColor: COLORS.background.primary,
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    maxHeight: screenHeight * 0.9,
    minHeight: screenHeight * 0.6,
  },
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  headerTitle: {
    ...TYPOGRAPHY.h2,
    color: COLORS.text.primary,
  },
  stepIndicator: {
    backgroundColor: COLORS.primary.main,
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
  },
  stepText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.background.primary,
    fontWeight: '600',
  },
});

// Delivery Type Selection Component
interface DeliveryTypeSelectionProps {
  selectedType: DeliveryType;
  onTypeSelect: (type: DeliveryType) => void;
}

const DeliveryTypeSelection: React.FC<DeliveryTypeSelectionProps> = ({
  selectedType,
  onTypeSelect,
}) => {
  return (
    <View style={stepStyles.container}>
      <View style={stepStyles.content}>
        <Text style={stepStyles.title}>Select Delivery Type</Text>
        <Text style={stepStyles.subtitle}>
          How was the book/literature delivered?
        </Text>

        <View style={stepStyles.typeSelector}>
          <TouchableOpacity
            style={[
              stepStyles.typeCard,
              selectedType === 'door' && stepStyles.typeCardSelected
            ]}
            onPress={() => onTypeSelect('door')}
            activeOpacity={0.8}
          >
            <View style={stepStyles.typeIconContainer}>
              <Ionicons
                name="home"
                size={32}
                color={selectedType === 'door' ? COLORS.background.primary : COLORS.primary.main}
              />
            </View>
            <Text style={[
              stepStyles.typeTitle,
              selectedType === 'door' && stepStyles.typeTitleSelected
            ]}>
              Door Delivery
            </Text>
            <Text style={[
              stepStyles.typeDescription,
              selectedType === 'door' && stepStyles.typeDescriptionSelected
            ]}>
              Left at doorstep or handed to someone at the door
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              stepStyles.typeCard,
              selectedType === 'person' && stepStyles.typeCardSelected
            ]}
            onPress={() => onTypeSelect('person')}
            activeOpacity={0.8}
          >
            <View style={stepStyles.typeIconContainer}>
              <Ionicons
                name="person"
                size={32}
                color={selectedType === 'person' ? COLORS.background.primary : COLORS.primary.main}
              />
            </View>
            <Text style={[
              stepStyles.typeTitle,
              selectedType === 'person' && stepStyles.typeTitleSelected
            ]}>
              Person Delivery
            </Text>
            <Text style={[
              stepStyles.typeDescription,
              selectedType === 'person' && stepStyles.typeDescriptionSelected
            ]}>
              Handed directly to a specific person
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
};

// QR Scanner Step Component
interface QRScannerStepProps {
  showScanner: boolean;
  hasPermission: boolean | null;
  onStartScan: () => void;
  onBarCodeScanned: (data: { type: string; data: string }) => void;
  onSkip: () => void;
  scannedData: string | null;
}

const QRScannerStep: React.FC<QRScannerStepProps> = ({
  showScanner,
  hasPermission,
  onStartScan,
  onBarCodeScanned,
  onSkip,
  scannedData,
}) => {
  if (hasPermission === null) {
    return (
      <View style={stepStyles.container}>
        <View style={stepStyles.content}>
          <Text style={stepStyles.title}>Requesting Camera Permission</Text>
        </View>
      </View>
    );
  }

  if (hasPermission === false) {
    return (
      <View style={stepStyles.container}>
        <View style={stepStyles.content}>
          <Text style={stepStyles.title}>QR Scanner Unavailable</Text>
          <Text style={stepStyles.subtitle}>
            QR code scanning is not available in Expo Go. Please enter book details manually or use a development build for full scanning functionality.
          </Text>
          <TouchableOpacity style={stepStyles.primaryButton} onPress={onSkip}>
            <Text style={stepStyles.primaryButtonText}>Continue Manually</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  if (showScanner) {
    // For Expo Go compatibility, we'll show a placeholder
    return (
      <View style={stepStyles.container}>
        <View style={stepStyles.content}>
          <Text style={stepStyles.title}>QR Scanner Not Available</Text>
          <Text style={stepStyles.subtitle}>
            QR code scanning requires a development build. For now, please enter book details manually.
          </Text>
          <TouchableOpacity style={stepStyles.primaryButton} onPress={onSkip}>
            <Text style={stepStyles.primaryButtonText}>Continue Manually</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={stepStyles.container}>
      <View style={stepStyles.content}>
        <Text style={stepStyles.title}>Book Information</Text>
        <Text style={stepStyles.subtitle}>
          QR code scanning is not available in Expo Go. Please enter book details manually.
        </Text>

        <View style={stepStyles.scannerActions}>
          <View style={stepStyles.infoCard}>
            <Ionicons name="information-circle" size={48} color={COLORS.primary.main} />
            <Text style={stepStyles.infoText}>
              For QR code scanning functionality, please use a development build instead of Expo Go.
            </Text>
          </View>

          <TouchableOpacity
            style={stepStyles.primaryButton}
            onPress={onSkip}
            activeOpacity={0.8}
          >
            <Text style={stepStyles.primaryButtonText}>Continue to Manual Entry</Text>
          </TouchableOpacity>
        </View>

        {scannedData && (
          <View style={stepStyles.scannedDataContainer}>
            <Text style={stepStyles.scannedDataLabel}>Scanned Data:</Text>
            <Text style={stepStyles.scannedDataText}>{scannedData}</Text>
          </View>
        )}
      </View>
    </View>
  );
};

// Delivery Details Form Component
interface DeliveryDetailsFormProps {
  formData: any;
  setFormData: (data: any) => void;
  selectedType: DeliveryType;
  photoUri: string | null;
  onTakePhoto: () => void;
  currentLocation: any;
  isLoading: boolean;
  onSubmit: () => void;
  scannedData: string | null;
}

const DeliveryDetailsForm: React.FC<DeliveryDetailsFormProps> = ({
  formData,
  setFormData,
  selectedType,
  photoUri,
  onTakePhoto,
  currentLocation,
  isLoading,
  onSubmit,
  scannedData,
}) => {
  return (
    <ScrollView style={stepStyles.container} showsVerticalScrollIndicator={false}>
      <View style={stepStyles.content}>
        <Text style={stepStyles.title}>Delivery Details</Text>

        {scannedData && (
          <View style={stepStyles.scannedInfo}>
            <Ionicons name="checkmark-circle" size={20} color={COLORS.success.main} />
            <Text style={stepStyles.scannedInfoText}>QR Code Scanned Successfully</Text>
          </View>
        )}

        {/* Book Details */}
        <View style={stepStyles.section}>
          <Text style={stepStyles.sectionTitle}>Book Information</Text>

          <View style={stepStyles.formGroup}>
            <Text style={stepStyles.formLabel}>Title *</Text>
            <TextInput
              style={stepStyles.formInput}
              value={formData.bookTitle}
              onChangeText={(text) => setFormData({...formData, bookTitle: text})}
              placeholder="Enter book or literature title"
            />
          </View>

          <View style={stepStyles.formGroup}>
            <Text style={stepStyles.formLabel}>Type</Text>
            <View style={stepStyles.bookTypeSelector}>
              {['tract', 'magazine', 'bible', 'study_guide'].map((type) => (
                <TouchableOpacity
                  key={type}
                  style={[
                    stepStyles.bookTypeOption,
                    formData.bookType === type && stepStyles.bookTypeOptionSelected
                  ]}
                  onPress={() => setFormData({...formData, bookType: type})}
                >
                  <Text style={[
                    stepStyles.bookTypeText,
                    formData.bookType === type && stepStyles.bookTypeTextSelected
                  ]}>
                    {type.replace('_', ' ').toUpperCase()}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>

          <View style={stepStyles.formGroup}>
            <Text style={stepStyles.formLabel}>Quantity</Text>
            <View style={stepStyles.quantitySelector}>
              <TouchableOpacity
                style={stepStyles.quantityButton}
                onPress={() => setFormData({
                  ...formData,
                  quantity: Math.max(1, formData.quantity - 1)
                })}
              >
                <Ionicons name="remove" size={20} color={COLORS.text.secondary} />
              </TouchableOpacity>
              <Text style={stepStyles.quantityText}>{formData.quantity}</Text>
              <TouchableOpacity
                style={stepStyles.quantityButton}
                onPress={() => setFormData({
                  ...formData,
                  quantity: formData.quantity + 1
                })}
              >
                <Ionicons name="add" size={20} color={COLORS.text.secondary} />
              </TouchableOpacity>
            </View>
          </View>
        </View>

        {/* Recipient Details (for person delivery) */}
        {selectedType === 'person' && (
          <View style={stepStyles.section}>
            <Text style={stepStyles.sectionTitle}>Recipient Details</Text>
            <View style={stepStyles.formGroup}>
              <Text style={stepStyles.formLabel}>Name (Optional)</Text>
              <TextInput
                style={stepStyles.formInput}
                value={formData.recipientName}
                onChangeText={(text) => setFormData({...formData, recipientName: text})}
                placeholder="Enter recipient's name"
              />
            </View>
          </View>
        )}

        {/* Address/Location */}
        <View style={stepStyles.section}>
          <Text style={stepStyles.sectionTitle}>Location Details</Text>
          <View style={stepStyles.formGroup}>
            <Text style={stepStyles.formLabel}>Address/Location</Text>
            <TextInput
              style={[stepStyles.formInput, { height: 60 }]}
              value={formData.address}
              onChangeText={(text) => setFormData({...formData, address: text})}
              placeholder="Enter address or location details"
              multiline
              numberOfLines={2}
            />
          </View>

          <View style={stepStyles.formGroup}>
            <Text style={stepStyles.formLabel}>Delivery Status</Text>
            <View style={stepStyles.statusSelector}>
              {[
                { key: 'delivered_to_person', label: 'Delivered to Person', color: COLORS.success.main },
                { key: 'delivered_to_door', label: 'Delivered to Door', color: COLORS.success.main },
                { key: 'rejected', label: 'Rejected', color: COLORS.error.main },
                { key: 'not_home', label: 'Not Home', color: COLORS.warning.main },
                { key: 'interested', label: 'Interested', color: COLORS.primary.main },
              ].map((status) => (
                <TouchableOpacity
                  key={status.key}
                  style={[
                    stepStyles.statusOption,
                    formData.status === status.key && { backgroundColor: status.color }
                  ]}
                  onPress={() => setFormData({...formData, status: status.key as DeliveryStatus})}
                >
                  <Text style={[
                    stepStyles.statusText,
                    formData.status === status.key && stepStyles.statusTextSelected
                  ]}>
                    {status.label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>

          <View style={stepStyles.formGroup}>
            <Text style={stepStyles.formLabel}>Notes (Optional)</Text>
            <TextInput
              style={[stepStyles.formInput, { height: 80 }]}
              value={formData.notes}
              onChangeText={(text) => setFormData({...formData, notes: text})}
              placeholder="Add any additional notes..."
              multiline
              numberOfLines={3}
            />
          </View>
        </View>

        {/* Photo Proof */}
        <View style={stepStyles.section}>
          <Text style={stepStyles.sectionTitle}>Photo Proof (Optional)</Text>
          {photoUri ? (
            <View style={stepStyles.photoContainer}>
              <Image source={{ uri: photoUri }} style={stepStyles.photoPreview} />
              <TouchableOpacity style={stepStyles.changePhotoButton} onPress={onTakePhoto}>
                <Ionicons name="camera" size={16} color={COLORS.primary.main} />
                <Text style={stepStyles.changePhotoText}>Change Photo</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <TouchableOpacity style={stepStyles.addPhotoButton} onPress={onTakePhoto}>
              <Ionicons name="camera" size={24} color={COLORS.text.secondary} />
              <Text style={stepStyles.addPhotoText}>Add Photo Proof</Text>
              <Text style={stepStyles.addPhotoSubtext}>
                {selectedType === 'door' ? 'Photo of door/house' : 'Photo with person'}
              </Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Submit Button */}
        <TouchableOpacity
          style={[stepStyles.submitButton, isLoading && stepStyles.submitButtonDisabled]}
          onPress={onSubmit}
          disabled={isLoading}
        >
          <Text style={stepStyles.submitButtonText}>
            {isLoading ? 'Saving...' : 'Log Delivery'}
          </Text>
        </TouchableOpacity>

        {/* GPS Location Display */}
        <View style={stepStyles.gpsCard}>
          <Text style={stepStyles.gpsTitle}>📍 GPS Location</Text>
          <Text style={stepStyles.gpsText}>
            Lat: {currentLocation?.latitude.toFixed(6) || 'N/A'}
          </Text>
          <Text style={stepStyles.gpsText}>
            Lng: {currentLocation?.longitude.toFixed(6) || 'N/A'}
          </Text>
          <Text style={stepStyles.gpsSubtext}>Auto-captured at delivery time</Text>
        </View>
      </View>
    </ScrollView>
  );
};

// Step Styles
const stepStyles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: SPACING.lg,
    alignItems: 'center',
  },
  title: {
    ...TYPOGRAPHY.h2,
    color: COLORS.text.primary,
    textAlign: 'center',
    marginBottom: SPACING.sm,
  },
  subtitle: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },

  // Type Selection Styles
  typeSelector: {
    width: '100%',
    gap: SPACING.md,
  },
  typeCard: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: COLORS.border.light,
  },
  typeCardSelected: {
    backgroundColor: COLORS.primary.main,
    borderColor: COLORS.primary.main,
  },
  typeIconContainer: {
    marginBottom: SPACING.md,
  },
  typeTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  typeTitleSelected: {
    color: COLORS.background.primary,
  },
  typeDescription: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  typeDescriptionSelected: {
    color: COLORS.background.primary,
  },

  // Scanner Styles
  scannerContainer: {
    flex: 1,
    position: 'relative',
  },
  scannerOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
  },
  scannerFrame: {
    width: 250,
    height: 250,
    borderWidth: 2,
    borderColor: COLORS.background.primary,
    borderRadius: RADIUS.md,
    backgroundColor: 'transparent',
  },
  scannerText: {
    ...TYPOGRAPHY.body,
    color: COLORS.background.primary,
    marginTop: SPACING.lg,
    textAlign: 'center',
  },
  scannerActions: {
    alignItems: 'center',
    gap: SPACING.lg,
  },
  scanButton: {
    backgroundColor: COLORS.primary.main,
    borderRadius: RADIUS.lg,
    padding: SPACING.xl,
    alignItems: 'center',
    minWidth: 200,
  },
  scanButtonText: {
    ...TYPOGRAPHY.button,
    color: COLORS.background.primary,
    marginTop: SPACING.sm,
  },
  orText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
  },
  skipButton: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
  },
  skipButtonText: {
    ...TYPOGRAPHY.button,
    color: COLORS.text.primary,
  },
  primaryButton: {
    backgroundColor: COLORS.primary.main,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.md,
    marginTop: SPACING.lg,
  },
  primaryButtonText: {
    ...TYPOGRAPHY.button,
    color: COLORS.background.primary,
  },
  scannedDataContainer: {
    backgroundColor: COLORS.success.light,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginTop: SPACING.lg,
    width: '100%',
  },
  scannedDataLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.success.dark,
    fontWeight: '600',
    marginBottom: SPACING.xs,
  },
  scannedDataText: {
    ...TYPOGRAPHY.body,
    color: COLORS.success.dark,
    fontFamily: 'monospace',
  },

  // Form Styles
  scannedInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.success.light,
    borderRadius: RADIUS.md,
    padding: SPACING.sm,
    marginBottom: SPACING.lg,
    gap: SPACING.xs,
  },
  scannedInfoText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.success.dark,
    fontWeight: '600',
  },
  section: {
    width: '100%',
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  formGroup: {
    marginBottom: SPACING.md,
  },
  formLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.primary,
    fontWeight: '600',
    marginBottom: SPACING.xs,
  },
  formInput: {
    borderWidth: 1,
    borderColor: COLORS.border.light,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    ...TYPOGRAPHY.body,
    backgroundColor: COLORS.background.primary,
  },
  bookTypeSelector: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.xs,
  },
  bookTypeOption: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.full,
    backgroundColor: COLORS.background.secondary,
  },
  bookTypeOptionSelected: {
    backgroundColor: COLORS.primary.main,
  },
  bookTypeText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '600',
  },
  bookTypeTextSelected: {
    color: COLORS.background.primary,
  },
  quantitySelector: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: SPACING.lg,
  },
  quantityButton: {
    width: 40,
    height: 40,
    borderRadius: RADIUS.full,
    backgroundColor: COLORS.background.secondary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  quantityText: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    fontWeight: 'bold',
  },
  photoContainer: {
    alignItems: 'center',
  },
  photoPreview: {
    width: 200,
    height: 150,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
  },
  changePhotoButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
  },
  changePhotoText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.primary.main,
    fontWeight: '600',
  },
  addPhotoButton: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.lg,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: COLORS.border.light,
    borderStyle: 'dashed',
  },
  addPhotoText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    fontWeight: '600',
    marginTop: SPACING.sm,
  },
  addPhotoSubtext: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.tertiary,
    marginTop: SPACING.xs,
  },
  submitButton: {
    backgroundColor: COLORS.primary.main,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.md,
    width: '100%',
    alignItems: 'center',
    marginVertical: SPACING.lg,
  },
  submitButtonDisabled: {
    backgroundColor: COLORS.text.disabled,
  },
  submitButtonText: {
    ...TYPOGRAPHY.button,
    color: COLORS.background.primary,
  },
  gpsCard: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    width: '100%',
  },
  gpsTitle: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.primary,
    fontWeight: '600',
    marginBottom: SPACING.xs,
  },
  gpsText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.primary,
    fontFamily: 'monospace',
    marginBottom: SPACING.xs,
  },
  gpsSubtext: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },

  // Status Selector Styles
  statusSelector: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.xs,
  },
  statusOption: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.full,
    backgroundColor: COLORS.background.secondary,
    marginRight: SPACING.xs,
    marginBottom: SPACING.xs,
  },
  statusText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '600',
  },
  statusTextSelected: {
    color: COLORS.background.primary,
  },

  // Info Card Styles
  infoCard: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    marginBottom: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.border.light,
  },
  infoText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginTop: SPACING.sm,
  },
});

export default EnhancedDeliveryModal;
