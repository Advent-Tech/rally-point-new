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
  ScrollView,
  Animated,
  Dimensions,
  ActivityIndicator,
  FlatList,
} from 'react-native';
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { BookDelivery, DeliveryType } from '../types/ministry';
import { DeliveryService } from '../services/DeliveryService';
import { BookService, Book } from '../services/BookService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface ComprehensiveDeliveryModalProps {
  visible: boolean;
  onClose: () => void;
  onDeliveryLogged: (delivery: BookDelivery) => void;
}

type DeliveryStep = 'book-selection' | 'delivery-method' | 'data-collection';

const { height: screenHeight } = Dimensions.get('window');

const ComprehensiveDeliveryModal: React.FC<ComprehensiveDeliveryModalProps> = ({
  visible,
  onClose,
  onDeliveryLogged,
}) => {
  const { user } = useAuth();
  const { currentLocation } = useLocation();
  
  // Modal state management
  const [currentStep, setCurrentStep] = useState<DeliveryStep>('book-selection');
  const [slideAnim] = useState(new Animated.Value(screenHeight));
  const [isLoading, setIsLoading] = useState(false);
  
  // Book selection state
  const [availableBooks, setAvailableBooks] = useState<Book[]>([]);
  const [selectedBook, setSelectedBook] = useState<Book | null>(null);
  const [loadingBooks, setLoadingBooks] = useState(false);
  
  // Delivery method state
  const [selectedDeliveryMethod, setSelectedDeliveryMethod] = useState<DeliveryType>('door');
  
  // Data collection form state
  const [formData, setFormData] = useState({
    recipientName: '',
    recipientPhone: '',
    deliveryNotes: '',
  });
  
  // Form validation errors
  const [errors, setErrors] = useState<Record<string, string>>({});

  // Load available books when modal opens
  useEffect(() => {
    if (visible) {
      loadAvailableBooks();
      // Animate modal in
      Animated.spring(slideAnim, {
        toValue: 0,
        useNativeDriver: true,
        tension: 100,
        friction: 8,
      }).start();
    } else {
      // Reset state when modal closes
      setCurrentStep('book-selection');
      setSelectedBook(null);
      setSelectedDeliveryMethod('door');
      setFormData({
        recipientName: '',
        recipientPhone: '',
        deliveryNotes: '',
      });
      setErrors({});
    }
  }, [visible]);

  const loadAvailableBooks = async () => {
    try {
      setLoadingBooks(true);
      const books = await BookService.getActiveBooks();
      setAvailableBooks(books);
    } catch (error) {
      console.error('Error loading books:', error);
      Alert.alert('Error', 'Failed to load available books');
    } finally {
      setLoadingBooks(false);
    }
  };

  const handleClose = () => {
    Animated.spring(slideAnim, {
      toValue: screenHeight,
      useNativeDriver: true,
      tension: 100,
      friction: 8,
    }).start(() => {
      onClose();
    });
  };

  const handleBookSelection = (book: Book) => {
    setSelectedBook(book);
    setCurrentStep('delivery-method');
  };

  const handleDeliveryMethodSelection = (method: DeliveryType) => {
    setSelectedDeliveryMethod(method);
    setCurrentStep('data-collection');
  };

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {};

    // Phone number validation (optional but must be valid if provided)
    if (formData.recipientPhone && !/^\+?[\d\s\-\(\)]{10,}$/.test(formData.recipientPhone)) {
      newErrors.recipientPhone = 'Please enter a valid phone number';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmitDelivery = async () => {
    if (!validateForm()) {
      return;
    }

    if (!selectedBook || !currentLocation) {
      Alert.alert('Error', 'Missing required information');
      return;
    }

    setIsLoading(true);
    try {
      const deliveryData: Omit<BookDelivery, 'id'> = {
        workerId: user.uid,
        workerName: user.displayName || user.email?.split('@')[0] || 'Unknown Worker',
        territoryId: 'current-territory', // TODO: Get from territory context
        deliveryType: selectedDeliveryMethod,
        bookTitle: selectedBook.title,
        bookType: selectedBook.category,
        quantity: 1,
        recipientName: formData.recipientName || undefined,
        recipientPhone: formData.recipientPhone || undefined,
        recipientAddress: currentLocation.address || 'Current Location',
        location: {
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          accuracy: currentLocation.accuracy,
        },
        deliveryTime: new Date(),
        notes: formData.deliveryNotes || undefined,
        followUpRequired: false,
        status: selectedDeliveryMethod === 'door' ? 'delivered_to_door' : 'delivered_to_person',
        syncStatus: 'synced',
      };

      const deliveryId = await DeliveryService.createDelivery(deliveryData);
      
      const newDelivery: BookDelivery = {
        id: deliveryId,
        ...deliveryData,
      };

      // Update book stock
      await BookService.updateStock(selectedBook.id, 1, 'subtract');

      onDeliveryLogged(newDelivery);
      handleClose();
      
      Alert.alert(
        'Success!', 
        `${selectedDeliveryMethod === 'door' ? 'Door-to-door' : 'Person-to-person'} delivery logged successfully!`
      );
    } catch (error) {
      console.error('Error logging delivery:', error);
      Alert.alert('Error', 'Failed to log delivery. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const renderBookSelection = () => (
    <View style={styles.stepContainer}>
      <Text style={styles.stepTitle}>Select Book for Delivery</Text>
      <Text style={styles.stepSubtitle}>Choose from available books in inventory</Text>

      {loadingBooks ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary.main} />
          <Text style={styles.loadingText}>Loading books...</Text>
        </View>
      ) : availableBooks.length === 0 ? (
        <View style={styles.emptyStateContainer}>
          <MaterialIcons name="library-books" size={64} color={COLORS.text.secondary} />
          <Text style={styles.emptyStateTitle}>No Books Available</Text>
          <Text style={styles.emptyStateMessage}>
            No books are currently available in the inventory. Please contact your admin to add books to the system.
          </Text>
          <TouchableOpacity
            style={styles.retryButton}
            onPress={loadAvailableBooks}
            activeOpacity={0.7}
          >
            <Ionicons name="refresh" size={20} color={COLORS.primary.main} />
            <Text style={styles.retryButtonText}>Retry</Text>
          </TouchableOpacity>
        </View>
      ) : (
        <FlatList
          data={availableBooks}
          keyExtractor={(item) => item.id}
          showsVerticalScrollIndicator={false}
          renderItem={({ item }) => (
            <TouchableOpacity
              style={styles.bookItem}
              onPress={() => handleBookSelection(item)}
              activeOpacity={0.7}
            >
              <View style={styles.bookInfo}>
                <View style={[styles.bookIcon, { backgroundColor: getCategoryColor(item.category) }]}>
                  <MaterialIcons name={getCategoryIcon(item.category)} size={24} color="#FFFFFF" />
                </View>
                <View style={styles.bookDetails}>
                  <Text style={styles.bookTitle}>{item.title}</Text>
                  {item.author && <Text style={styles.bookAuthor}>by {item.author}</Text>}
                  <Text style={styles.bookCategory}>{item.category.replace('_', ' ').toUpperCase()}</Text>
                  <Text style={styles.bookStock}>Stock: {item.stockQuantity}</Text>
                </View>
              </View>
              <Ionicons name="chevron-forward" size={20} color={COLORS.text.secondary} />
            </TouchableOpacity>
          )}
          contentContainerStyle={styles.booksList}
        />
      )}
    </View>
  );

  const renderDeliveryMethodSelection = () => (
    <View style={styles.stepContainer}>
      <Text style={styles.stepTitle}>Delivery Method</Text>
      <Text style={styles.stepSubtitle}>How was the book delivered?</Text>
      
      <View style={styles.deliveryMethods}>
        <TouchableOpacity
          style={[
            styles.deliveryMethodCard,
            selectedDeliveryMethod === 'door' && styles.selectedMethodCard
          ]}
          onPress={() => handleDeliveryMethodSelection('door')}
          activeOpacity={0.7}
        >
          <View style={[styles.methodIcon, { backgroundColor: COLORS.primary.main }]}>
            <Ionicons name="home" size={32} color="#FFFFFF" />
          </View>
          <Text style={styles.methodTitle}>To Door</Text>
          <Text style={styles.methodDescription}>Left at door or with household member</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.deliveryMethodCard,
            selectedDeliveryMethod === 'person' && styles.selectedMethodCard
          ]}
          onPress={() => handleDeliveryMethodSelection('person')}
          activeOpacity={0.7}
        >
          <View style={[styles.methodIcon, { backgroundColor: COLORS.secondary.main }]}>
            <Ionicons name="person" size={32} color="#FFFFFF" />
          </View>
          <Text style={styles.methodTitle}>To Person</Text>
          <Text style={styles.methodDescription}>Handed directly to recipient</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

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
                  {currentStep === 'book-selection' ? '1/3' : 
                   currentStep === 'delivery-method' ? '2/3' : '3/3'}
                </Text>
              </View>
            </View>

            {/* Content based on current step */}
            <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
              {currentStep === 'book-selection' && renderBookSelection()}
              {currentStep === 'delivery-method' && renderDeliveryMethodSelection()}
              {currentStep === 'data-collection' && (
                <View style={styles.stepContainer}>
                  <Text style={styles.stepTitle}>Delivery Details</Text>
                  <Text style={styles.stepSubtitle}>Optional information about the delivery</Text>

                  {/* Selected Book Summary */}
                  {selectedBook && (
                    <View style={styles.selectedBookSummary}>
                      <View style={[styles.bookIcon, { backgroundColor: getCategoryColor(selectedBook.category) }]}>
                        <MaterialIcons name={getCategoryIcon(selectedBook.category)} size={20} color="#FFFFFF" />
                      </View>
                      <View style={styles.summaryDetails}>
                        <Text style={styles.summaryTitle}>{selectedBook.title}</Text>
                        <Text style={styles.summaryMethod}>
                          {selectedDeliveryMethod === 'door' ? 'Door-to-door' : 'Person-to-person'} delivery
                        </Text>
                      </View>
                    </View>
                  )}

                  {/* Form Fields */}
                  <View style={styles.formSection}>
                    <Text style={styles.formLabel}>Recipient Name (Optional)</Text>
                    <TextInput
                      style={[styles.textInput, errors.recipientName && styles.inputError]}
                      value={formData.recipientName}
                      onChangeText={(text) => setFormData(prev => ({ ...prev, recipientName: text }))}
                      placeholder="Enter recipient's name"
                      placeholderTextColor={COLORS.text.secondary}
                    />
                    {errors.recipientName && <Text style={styles.errorText}>{errors.recipientName}</Text>}
                  </View>

                  <View style={styles.formSection}>
                    <Text style={styles.formLabel}>Phone Number (Optional)</Text>
                    <TextInput
                      style={[styles.textInput, errors.recipientPhone && styles.inputError]}
                      value={formData.recipientPhone}
                      onChangeText={(text) => setFormData(prev => ({ ...prev, recipientPhone: text }))}
                      placeholder="Enter phone number"
                      placeholderTextColor={COLORS.text.secondary}
                      keyboardType="phone-pad"
                    />
                    {errors.recipientPhone && <Text style={styles.errorText}>{errors.recipientPhone}</Text>}
                  </View>

                  <View style={styles.formSection}>
                    <Text style={styles.formLabel}>Delivery Notes (Optional)</Text>
                    <TextInput
                      style={[styles.textArea, errors.deliveryNotes && styles.inputError]}
                      value={formData.deliveryNotes}
                      onChangeText={(text) => setFormData(prev => ({ ...prev, deliveryNotes: text }))}
                      placeholder="Any additional notes about the delivery..."
                      placeholderTextColor={COLORS.text.secondary}
                      multiline
                      numberOfLines={4}
                      textAlignVertical="top"
                    />
                    {errors.deliveryNotes && <Text style={styles.errorText}>{errors.deliveryNotes}</Text>}
                  </View>

                  {/* Location Info */}
                  {currentLocation && (
                    <View style={styles.locationInfo}>
                      <Ionicons name="location" size={16} color={COLORS.primary.main} />
                      <Text style={styles.locationText}>
                        Location: {currentLocation.latitude.toFixed(6)}, {currentLocation.longitude.toFixed(6)}
                        {currentLocation.accuracy && ` (±${Math.round(currentLocation.accuracy)}m)`}
                      </Text>
                    </View>
                  )}

                  {/* Submit Button */}
                  <TouchableOpacity
                    style={[styles.submitButton, isLoading && styles.disabledButton]}
                    onPress={handleSubmitDelivery}
                    disabled={isLoading}
                    activeOpacity={0.8}
                  >
                    {isLoading ? (
                      <ActivityIndicator size="small" color="#FFFFFF" />
                    ) : (
                      <>
                        <Ionicons name="checkmark-circle" size={20} color="#FFFFFF" />
                        <Text style={styles.submitButtonText}>Log Delivery</Text>
                      </>
                    )}
                  </TouchableOpacity>
                </View>
              )}
            </ScrollView>
          </SafeAreaView>
        </Animated.View>
      </View>
    </Modal>
  );
};

// Helper functions
const getCategoryColor = (category: string): string => {
  const colors: Record<string, string> = {
    bible: '#7c3aed',
    tract: '#059669',
    magazine: '#dc2626',
    study_guide: '#2563eb',
    book: '#ea580c',
    other: '#6b7280',
  };
  return colors[category] || colors.other;
};

const getCategoryIcon = (category: string): string => {
  const icons: Record<string, string> = {
    bible: 'menu-book',
    tract: 'article',
    magazine: 'library-books',
    study_guide: 'school',
    book: 'book',
    other: 'description',
  };
  return icons[category] || icons.other;
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContainer: {
    backgroundColor: '#FFFFFF',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: screenHeight * 0.9,
    ...SHADOWS.medium,
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
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    fontWeight: '600',
  },
  stepIndicator: {
    backgroundColor: COLORS.primary.main,
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
  },
  stepText: {
    ...TYPOGRAPHY.caption,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  content: {
    flex: 1,
  },
  stepContainer: {
    padding: SPACING.lg,
  },
  stepTitle: {
    ...TYPOGRAPHY.h2,
    color: COLORS.text.primary,
    fontWeight: '700',
    marginBottom: SPACING.xs,
  },
  stepSubtitle: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xl,
  },
  loadingContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING.xl * 2,
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  emptyStateContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING.xl * 2,
    paddingHorizontal: SPACING.lg,
  },
  emptyStateTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    marginTop: SPACING.lg,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  emptyStateMessage: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: SPACING.xl,
  },
  retryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.primary.main,
  },
  retryButtonText: {
    ...TYPOGRAPHY.button,
    color: COLORS.primary.main,
    marginLeft: SPACING.xs,
  },
  booksList: {
    paddingBottom: SPACING.lg,
  },
  bookItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#FFFFFF',
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.light,
    ...SHADOWS.small,
  },
  bookInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  bookIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  bookDetails: {
    flex: 1,
  },
  bookTitle: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginBottom: 2,
  },
  bookAuthor: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginBottom: 2,
  },
  bookCategory: {
    ...TYPOGRAPHY.caption,
    color: COLORS.primary.main,
    fontWeight: '500',
    marginBottom: 2,
  },
  bookStock: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
  deliveryMethods: {
    gap: SPACING.md,
  },
  deliveryMethodCard: {
    backgroundColor: '#FFFFFF',
    padding: SPACING.lg,
    borderRadius: RADIUS.lg,
    borderWidth: 2,
    borderColor: COLORS.border.light,
    alignItems: 'center',
    ...SHADOWS.small,
  },
  selectedMethodCard: {
    borderColor: COLORS.primary.main,
    backgroundColor: COLORS.primary.light,
  },
  methodIcon: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: SPACING.md,
  },
  methodTitle: {
    ...TYPOGRAPHY.h3,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  methodDescription: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  selectedBookSummary: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.lg,
  },
  summaryDetails: {
    marginLeft: SPACING.md,
    flex: 1,
  },
  summaryTitle: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginBottom: 2,
  },
  summaryMethod: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
  formSection: {
    marginBottom: SPACING.lg,
  },
  formLabel: {
    ...TYPOGRAPHY.body,
    fontWeight: '500',
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  textInput: {
    borderWidth: 1,
    borderColor: COLORS.border.light,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    backgroundColor: '#FFFFFF',
  },
  textArea: {
    borderWidth: 1,
    borderColor: COLORS.border.light,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    backgroundColor: '#FFFFFF',
    minHeight: 100,
  },
  inputError: {
    borderColor: COLORS.error.main,
  },
  errorText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.error.main,
    marginTop: SPACING.xs,
  },
  locationInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.lg,
  },
  locationText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
    flex: 1,
  },
  submitButton: {
    backgroundColor: COLORS.primary.main,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    ...SHADOWS.small,
  },
  disabledButton: {
    backgroundColor: COLORS.text.secondary,
  },
  submitButtonText: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
    color: '#FFFFFF',
    marginLeft: SPACING.xs,
  },
});

export default ComprehensiveDeliveryModal;
