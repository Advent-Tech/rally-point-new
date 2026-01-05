import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  StyleSheet,
  SafeAreaView,
  Alert,
  Switch,
  Platform,
} from 'react-native';
// Platform-specific imports for DateTimePicker
let DateTimePicker: any;
if (Platform.OS !== 'web') {
  try {
    DateTimePicker = require('@react-native-community/datetimepicker').default;
  } catch (error) {
    console.warn('DateTimePicker not available on this platform');
  }
}
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { useLocation } from '../contexts/LocationContext';
import { Header } from '../components';
import MinistryContactService from '../services/MinistryContactService';
import { MinistryContact, ContactFormData, ContactFormErrors } from '../types/ministryContact';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface MinistryContactScreenProps {
  navigation: any;
}

const MinistryContactScreen: React.FC<MinistryContactScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const { currentLocation } = useLocation();
  
  const [formData, setFormData] = useState<ContactFormData>({
    name: '',
    address: '',
    email: '',
    phone: '',
    personalBibleStudies: false,
    groupBibleStudies: false,
    healthSeminar: false,
    healthExpo: false,
    vbs: false,
    healthConsultation: false,
    misc: '',
    appointmentScheduled: false,
    appointmentDate: '',
    appointmentTime: '',
    appointmentNotes: '',
  });

  const [errors, setErrors] = useState<ContactFormErrors>({});
  const [isLoading, setIsLoading] = useState(false);
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showTimePicker, setShowTimePicker] = useState(false);
  const [selectedDate, setSelectedDate] = useState(new Date());

  const validateForm = (): boolean => {
    const newErrors: ContactFormErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Name is required';
    }

    if (!formData.address.trim()) {
      newErrors.address = 'Address is required';
    }

    if (formData.email && !isValidEmail(formData.email)) {
      newErrors.email = 'Please enter a valid email address';
    }

    if (formData.appointmentScheduled) {
      if (!formData.appointmentDate) {
        newErrors.appointmentDate = 'Appointment date is required';
      }
      if (!formData.appointmentTime) {
        newErrors.appointmentTime = 'Appointment time is required';
      }
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const isValidEmail = (email: string): boolean => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const handleSubmit = async () => {
    if (!validateForm()) {
      Alert.alert('Validation Error', 'Please correct the errors and try again.');
      return;
    }

    if (!user) {
      Alert.alert('Error', 'User not authenticated');
      return;
    }

    setIsLoading(true);
    try {
      const contactData: Omit<MinistryContact, 'id'> = {
        workerId: user.uid,
        workerName: user.displayName || user.email.split('@')[0],
        name: formData.name.trim(),
        address: formData.address.trim(),
        email: formData.email.trim() || undefined,
        phone: formData.phone.trim() || undefined,
        personalBibleStudies: formData.personalBibleStudies,
        groupBibleStudies: formData.groupBibleStudies,
        healthSeminar: formData.healthSeminar,
        healthExpo: formData.healthExpo,
        vbs: formData.vbs,
        healthConsultation: formData.healthConsultation,
        misc: formData.misc.trim() || undefined,
        appointmentScheduled: formData.appointmentScheduled,
        appointmentDate: formData.appointmentScheduled && formData.appointmentDate 
          ? new Date(formData.appointmentDate) 
          : undefined,
        appointmentTime: formData.appointmentScheduled ? formData.appointmentTime : undefined,
        appointmentNotes: formData.appointmentScheduled ? formData.appointmentNotes : undefined,
        location: currentLocation ? {
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          accuracy: currentLocation.accuracy,
        } : undefined,
        createdAt: new Date(),
        updatedAt: new Date(),
        syncStatus: 'pending',
      };

      await MinistryContactService.createContact(contactData);
      
      Alert.alert(
        'Success!',
        'Ministry contact has been saved successfully.',
        [
          {
            text: 'Add Another',
            onPress: resetForm,
          },
          {
            text: 'View Contacts',
            onPress: () => navigation.navigate('MinistryContactList'),
          },
        ]
      );
    } catch (error) {
      console.error('Error saving contact:', error);
      Alert.alert('Error', 'Failed to save contact. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      address: '',
      email: '',
      phone: '',
      personalBibleStudies: false,
      groupBibleStudies: false,
      healthSeminar: false,
      healthExpo: false,
      vbs: false,
      healthConsultation: false,
      misc: '',
      appointmentScheduled: false,
      appointmentDate: '',
      appointmentTime: '',
      appointmentNotes: '',
    });
    setErrors({});
  };

  const handleDateChange = (event: any, selectedDate?: Date) => {
    if (Platform.OS === 'web') {
      // For web, event.target.value contains the date string
      const dateValue = event.target?.value;
      if (dateValue) {
        setFormData({
          ...formData,
          appointmentDate: dateValue,
        });
      }
    } else {
      setShowDatePicker(false);
      if (selectedDate) {
        setSelectedDate(selectedDate);
        setFormData({
          ...formData,
          appointmentDate: selectedDate.toISOString().split('T')[0],
        });
      }
    }
  };

  const handleTimeChange = (event: any, selectedTime?: Date) => {
    if (Platform.OS === 'web') {
      // For web, event.target.value contains the time string
      const timeValue = event.target?.value;
      if (timeValue) {
        setFormData({
          ...formData,
          appointmentTime: timeValue,
        });
      }
    } else {
      setShowTimePicker(false);
      if (selectedTime) {
        const timeString = selectedTime.toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit'
        });
        setFormData({
          ...formData,
          appointmentTime: timeString,
        });
      }
    }
  };

  const sendContact = async () => {
    if (!validateForm()) {
      Alert.alert('Validation Error', 'Please fill in the required fields first.');
      return;
    }

    Alert.alert(
      'Send Contact Information',
      'How would you like to send this contact information?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Email', onPress: () => handleSendContact('email') },
        { text: 'Phone', onPress: () => handleSendContact('phone') },
        { text: 'Letter', onPress: () => handleSendContact('letter') },
      ]
    );
  };

  const handleSendContact = async (method: 'email' | 'phone' | 'letter' | 'visit') => {
    // In a real implementation, this would integrate with email/SMS services
    Alert.alert(
      'Contact Sent',
      `Contact information has been prepared for sending via ${method}.`,
      [{ text: 'OK' }]
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title="Ministry Contact Survey"
        showBackButton
        onBackPress={() => navigation.goBack()}
      />

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Contact Information Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Contact Information</Text>
          
          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Name *</Text>
            <TextInput
              style={[styles.textInput, errors.name && styles.inputError]}
              value={formData.name}
              onChangeText={(text) => setFormData({ ...formData, name: text })}
              placeholder="Enter full name"
              placeholderTextColor={COLORS.text.placeholder}
            />
            {errors.name && <Text style={styles.errorText}>{errors.name}</Text>}
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Address *</Text>
            <TextInput
              style={[styles.textArea, errors.address && styles.inputError]}
              value={formData.address}
              onChangeText={(text) => setFormData({ ...formData, address: text })}
              placeholder="Enter complete address"
              placeholderTextColor={COLORS.text.placeholder}
              multiline
              numberOfLines={3}
            />
            {errors.address && <Text style={styles.errorText}>{errors.address}</Text>}
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Email</Text>
            <TextInput
              style={[styles.textInput, errors.email && styles.inputError]}
              value={formData.email}
              onChangeText={(text) => setFormData({ ...formData, email: text })}
              placeholder="Enter email address"
              placeholderTextColor={COLORS.text.placeholder}
              keyboardType="email-address"
              autoCapitalize="none"
            />
            {errors.email && <Text style={styles.errorText}>{errors.email}</Text>}
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Phone</Text>
            <TextInput
              style={styles.textInput}
              value={formData.phone}
              onChangeText={(text) => setFormData({ ...formData, phone: text })}
              placeholder="Enter phone number"
              placeholderTextColor={COLORS.text.placeholder}
              keyboardType="phone-pad"
            />
          </View>
        </View>

        {/* Ministry Interests Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Ministry Interests</Text>

          <View style={styles.checkboxGroup}>
            <TouchableOpacity
              style={styles.checkboxRow}
              onPress={() => setFormData({ ...formData, personalBibleStudies: !formData.personalBibleStudies })}
            >
              <View style={[styles.checkbox, formData.personalBibleStudies && styles.checkboxChecked]}>
                {formData.personalBibleStudies && (
                  <MaterialIcons name="check" size={16} color={COLORS.background.primary} />
                )}
              </View>
              <Text style={styles.checkboxLabel}>Personal Bible Studies</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.checkboxRow}
              onPress={() => setFormData({ ...formData, groupBibleStudies: !formData.groupBibleStudies })}
            >
              <View style={[styles.checkbox, formData.groupBibleStudies && styles.checkboxChecked]}>
                {formData.groupBibleStudies && (
                  <MaterialIcons name="check" size={16} color={COLORS.background.primary} />
                )}
              </View>
              <Text style={styles.checkboxLabel}>Group Bible Studies</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.checkboxRow}
              onPress={() => setFormData({ ...formData, healthSeminar: !formData.healthSeminar })}
            >
              <View style={[styles.checkbox, formData.healthSeminar && styles.checkboxChecked]}>
                {formData.healthSeminar && (
                  <MaterialIcons name="check" size={16} color={COLORS.background.primary} />
                )}
              </View>
              <Text style={styles.checkboxLabel}>Health Seminar</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.checkboxRow}
              onPress={() => setFormData({ ...formData, healthExpo: !formData.healthExpo })}
            >
              <View style={[styles.checkbox, formData.healthExpo && styles.checkboxChecked]}>
                {formData.healthExpo && (
                  <MaterialIcons name="check" size={16} color={COLORS.background.primary} />
                )}
              </View>
              <Text style={styles.checkboxLabel}>Health Expo</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.checkboxRow}
              onPress={() => setFormData({ ...formData, vbs: !formData.vbs })}
            >
              <View style={[styles.checkbox, formData.vbs && styles.checkboxChecked]}>
                {formData.vbs && (
                  <MaterialIcons name="check" size={16} color={COLORS.background.primary} />
                )}
              </View>
              <Text style={styles.checkboxLabel}>VBS (Vacation Bible School)</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.checkboxRow}
              onPress={() => setFormData({ ...formData, healthConsultation: !formData.healthConsultation })}
            >
              <View style={[styles.checkbox, formData.healthConsultation && styles.checkboxChecked]}>
                {formData.healthConsultation && (
                  <MaterialIcons name="check" size={16} color={COLORS.background.primary} />
                )}
              </View>
              <Text style={styles.checkboxLabel}>Health Consultation</Text>
            </TouchableOpacity>
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Misc. (Additional Notes)</Text>
            <TextInput
              style={styles.textArea}
              value={formData.misc}
              onChangeText={(text) => setFormData({ ...formData, misc: text })}
              placeholder="Any additional information or interests..."
              placeholderTextColor={COLORS.text.placeholder}
              multiline
              numberOfLines={3}
            />
          </View>
        </View>

        {/* Appointment Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Appointment Scheduling</Text>

          <View style={styles.switchRow}>
            <Text style={styles.switchLabel}>Schedule Appointment</Text>
            <Switch
              value={formData.appointmentScheduled}
              onValueChange={(value) => setFormData({ ...formData, appointmentScheduled: value })}
              trackColor={{ false: COLORS.border.default, true: COLORS.primary + '40' }}
              thumbColor={formData.appointmentScheduled ? COLORS.primary : COLORS.text.secondary}
            />
          </View>

          {formData.appointmentScheduled && (
            <>
              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Appointment Date *</Text>
                {Platform.OS === 'web' ? (
                  <TextInput
                    style={[styles.textInput, errors.appointmentDate && styles.inputError]}
                    value={formData.appointmentDate}
                    onChangeText={(text) => setFormData({ ...formData, appointmentDate: text })}
                    placeholder="YYYY-MM-DD"
                    placeholderTextColor={COLORS.text.placeholder}
                  />
                ) : (
                  <TouchableOpacity
                    style={[styles.dateTimeButton, errors.appointmentDate && styles.inputError]}
                    onPress={() => setShowDatePicker(true)}
                  >
                    <Text style={styles.dateTimeText}>
                      {formData.appointmentDate || 'Select Date'}
                    </Text>
                    <MaterialIcons name="calendar-today" size={20} color={COLORS.text.secondary} />
                  </TouchableOpacity>
                )}
                {errors.appointmentDate && <Text style={styles.errorText}>{errors.appointmentDate}</Text>}
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Appointment Time *</Text>
                {Platform.OS === 'web' ? (
                  <TextInput
                    style={[styles.textInput, errors.appointmentTime && styles.inputError]}
                    value={formData.appointmentTime}
                    onChangeText={(text) => setFormData({ ...formData, appointmentTime: text })}
                    placeholder="HH:MM"
                    placeholderTextColor={COLORS.text.placeholder}
                  />
                ) : (
                  <TouchableOpacity
                    style={[styles.dateTimeButton, errors.appointmentTime && styles.inputError]}
                    onPress={() => setShowTimePicker(true)}
                  >
                    <Text style={styles.dateTimeText}>
                      {formData.appointmentTime || 'Select Time'}
                    </Text>
                    <MaterialIcons name="access-time" size={20} color={COLORS.text.secondary} />
                  </TouchableOpacity>
                )}
                {errors.appointmentTime && <Text style={styles.errorText}>{errors.appointmentTime}</Text>}
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Appointment Notes</Text>
                <TextInput
                  style={styles.textArea}
                  value={formData.appointmentNotes}
                  onChangeText={(text) => setFormData({ ...formData, appointmentNotes: text })}
                  placeholder="Additional notes for the appointment..."
                  placeholderTextColor={COLORS.text.placeholder}
                  multiline
                  numberOfLines={2}
                />
              </View>
            </>
          )}
        </View>

        {/* Action Buttons */}
        <View style={styles.actionSection}>
          <TouchableOpacity
            style={styles.sendButton}
            onPress={sendContact}
            disabled={isLoading}
          >
            <MaterialIcons name="send" size={20} color={COLORS.background.primary} />
            <Text style={styles.sendButtonText}>Send to Contact</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.saveButton, isLoading && styles.saveButtonDisabled]}
            onPress={handleSubmit}
            disabled={isLoading}
          >
            <MaterialIcons name="save" size={20} color={COLORS.background.primary} />
            <Text style={styles.saveButtonText}>
              {isLoading ? 'Saving...' : 'Save Contact'}
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>

      {/* Date Picker - Mobile Only */}
      {Platform.OS !== 'web' && showDatePicker && DateTimePicker && (
        <DateTimePicker
          value={selectedDate}
          mode="date"
          display="default"
          onChange={handleDateChange}
          minimumDate={new Date()}
        />
      )}

      {/* Time Picker - Mobile Only */}
      {Platform.OS !== 'web' && showTimePicker && DateTimePicker && (
        <DateTimePicker
          value={new Date()}
          mode="time"
          display="default"
          onChange={handleTimeChange}
        />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  content: {
    flex: 1,
    padding: SPACING.md,
  },
  section: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  inputGroup: {
    marginBottom: SPACING.md,
  },
  inputLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  textInput: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.surface,
    minHeight: 48,
  },
  textArea: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.surface,
    minHeight: 80,
    textAlignVertical: 'top',
  },
  inputError: {
    borderColor: COLORS.error,
  },
  errorText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.error,
    marginTop: SPACING.xs,
  },
  checkboxGroup: {
    marginBottom: SPACING.md,
  },
  checkboxRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  checkbox: {
    width: 20,
    height: 20,
    borderRadius: 4,
    borderWidth: 2,
    borderColor: COLORS.border.default,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.sm,
  },
  checkboxChecked: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  checkboxLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    flex: 1,
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  switchLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  dateTimeButton: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: COLORS.background.surface,
    minHeight: 48,
  },
  dateTimeText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
  },
  actionSection: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: SPACING.lg,
    marginBottom: SPACING.xl,
  },
  sendButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.secondary,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    marginRight: SPACING.sm,
    ...SHADOWS.sm,
  },
  sendButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.semibold,
    marginLeft: SPACING.xs,
  },
  saveButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    marginLeft: SPACING.sm,
    ...SHADOWS.sm,
  },
  saveButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.semibold,
    marginLeft: SPACING.xs,
  },
  saveButtonDisabled: {
    opacity: 0.6,
  },
});

export default MinistryContactScreen;
