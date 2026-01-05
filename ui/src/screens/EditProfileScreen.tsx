import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  Alert,
  KeyboardAvoidingView,
  Platform
} from 'react-native';
import { useForm, Controller } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { useAuth } from '../contexts/AuthContext';
import { ProfileService } from '../services/ProfileService';
import { Header, Button, Input } from '../components';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { UpdateProfileFormData, UserProfile } from '../types/profile';

// Validation schema
const updateProfileSchema = yup.object().shape({
  displayName: yup
    .string()
    .required('Display name is required')
    .min(2, 'Display name must be at least 2 characters')
    .max(50, 'Display name must be less than 50 characters'),
  phone: yup
    .string()
    .matches(/^[\+]?[1-9][\d]{0,15}$/, 'Please enter a valid phone number')
    .optional(),
  email: yup
    .string()
    .email('Please enter a valid email address')
    .required('Email is required'),
});

interface EditProfileScreenProps {
  navigation: any;
}

const EditProfileScreen: React.FC<EditProfileScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const {
    control,
    handleSubmit,
    formState: { errors, isValid },
    setValue,
    reset
  } = useForm<UpdateProfileFormData>({
    resolver: yupResolver(updateProfileSchema),
    mode: 'onChange'
  });

  useEffect(() => {
    loadProfile();
  }, [user]);

  const loadProfile = async () => {
    if (!user) return;

    try {
      setLoading(true);
      const profileData = await ProfileService.getUserProfile(user.uid);
      
      if (profileData) {
        setProfile(profileData);
        // Set form values
        setValue('displayName', profileData.displayName || '');
        setValue('phone', profileData.phone || '');
        setValue('email', profileData.email || '');
      } else {
        // Set default values from user
        setValue('displayName', user.displayName || '');
        setValue('phone', '');
        setValue('email', user.email || '');
      }
    } catch (error) {
      console.error('Error loading profile:', error);
      Alert.alert('Error', 'Failed to load profile data.');
    } finally {
      setLoading(false);
    }
  };

  const onSubmit = async (data: UpdateProfileFormData) => {
    if (!user) return;

    try {
      setSaving(true);

      // Update profile
      const result = await ProfileService.updateUserProfile(user.uid, {
        displayName: data.displayName,
        phone: data.phone,
        email: data.email,
        updatedAt: new Date()
      });

      if (result.success) {
        Alert.alert(
          'Success',
          'Profile updated successfully!',
          [
            {
              text: 'OK',
              onPress: () => navigation.goBack()
            }
          ]
        );
      } else {
        Alert.alert('Error', result.error || 'Failed to update profile');
      }
    } catch (error) {
      console.error('Error updating profile:', error);
      Alert.alert('Error', 'Failed to update profile. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    navigation.goBack();
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
        <Header title="Edit Profile" showBackButton onBackPress={() => navigation.goBack()} />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading profile...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
      <Header title="Edit Profile" showBackButton onBackPress={() => navigation.goBack()} />
      
      <KeyboardAvoidingView
        style={styles.keyboardAvoid}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.form}>
            <Text style={styles.sectionTitle}>Basic Information</Text>
            
            <Controller
              control={control}
              name="displayName"
              render={({ field: { onChange, onBlur, value } }) => (
                <Input
                  label="Display Name"
                  placeholder="Enter your display name"
                  value={value}
                  onChangeText={onChange}
                  error={errors.displayName?.message}
                />
              )}
            />

            <Controller
              control={control}
              name="phone"
              render={({ field: { onChange, onBlur, value } }) => (
                <Input
                  label="Phone Number"
                  placeholder="Enter your phone number"
                  value={value}
                  onChangeText={onChange}
                  error={errors.phone?.message}
                />
              )}
            />

            <Controller
              control={control}
              name="email"
              render={({ field: { onChange, onBlur, value } }) => (
                <Input
                  label="Email Address"
                  placeholder="Enter your email address"
                  value={value}
                  onChangeText={onChange}
                  error={errors.email?.message}
                />
              )}
            />

            <Text style={styles.helpText}>
              Note: Changing your email address may require re-authentication.
            </Text>
          </View>
        </ScrollView>

        <View style={styles.buttonContainer}>
          <Button
            title="Cancel"
            variant="outline"
            onPress={handleCancel}
            style={styles.cancelButton}
          />
          <Button
            title="Save Changes"
            onPress={handleSubmit(onSubmit)}
            loading={saving}
            disabled={!isValid || saving}
            style={styles.saveButton}
          />
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  keyboardAvoid: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: SPACING.xl,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.darkGray,
  },
  form: {
    backgroundColor: COLORS.white,
    margin: SPACING.md,
    padding: SPACING.lg,
    borderRadius: RADIUS.md,
    ...SHADOWS.small,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h4,
    color: COLORS.primary,
    fontWeight: 'bold',
    marginBottom: SPACING.lg,
  },
  helpText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.darkGray,
    marginTop: SPACING.md,
    textAlign: 'center',
    fontStyle: 'italic',
  },
  buttonContainer: {
    flexDirection: 'row',
    padding: SPACING.lg,
    gap: SPACING.md,
    backgroundColor: COLORS.white,
    borderTopWidth: 1,
    borderTopColor: COLORS.borderFlat,
  },
  cancelButton: {
    flex: 1,
  },
  saveButton: {
    flex: 1,
  },
});

export default EditProfileScreen;
