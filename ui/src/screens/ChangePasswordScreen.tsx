import React, { useState } from 'react';
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
import { ProfileService } from '../services/ProfileService';
import { Header, Button, Input } from '../components';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { ChangePasswordFormData } from '../types/profile';

// Validation schema
const changePasswordSchema = yup.object().shape({
  currentPassword: yup
    .string()
    .required('Current password is required')
    .min(6, 'Password must be at least 6 characters'),
  newPassword: yup
    .string()
    .required('New password is required')
    .min(6, 'Password must be at least 6 characters')
    .matches(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'Password must contain at least one uppercase letter, one lowercase letter, and one number'
    ),
  confirmPassword: yup
    .string()
    .required('Please confirm your new password')
    .oneOf([yup.ref('newPassword')], 'Passwords must match'),
});

interface ChangePasswordScreenProps {
  navigation: any;
}

const ChangePasswordScreen: React.FC<ChangePasswordScreenProps> = ({ navigation }) => {
  const [saving, setSaving] = useState(false);
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const {
    control,
    handleSubmit,
    formState: { errors, isValid },
    reset
  } = useForm<ChangePasswordFormData>({
    resolver: yupResolver(changePasswordSchema),
    mode: 'onChange'
  });

  const onSubmit = async (data: ChangePasswordFormData) => {
    try {
      setSaving(true);

      const result = await ProfileService.changePassword(
        data.currentPassword,
        data.newPassword
      );

      if (result.success) {
        Alert.alert(
          'Success',
          'Password changed successfully!',
          [
            {
              text: 'OK',
              onPress: () => {
                reset();
                navigation.goBack();
              }
            }
          ]
        );
      } else {
        Alert.alert('Error', result.error || 'Failed to change password');
      }
    } catch (error) {
      console.error('Error changing password:', error);
      Alert.alert('Error', 'Failed to change password. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    navigation.goBack();
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
      <Header title="Change Password" showBackButton onBackPress={() => navigation.goBack()} />
      
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
            <Text style={styles.sectionTitle}>Change Password</Text>
            
            <Text style={styles.description}>
              For your security, please enter your current password and choose a new strong password.
            </Text>

            <Controller
              control={control}
              name="currentPassword"
              render={({ field: { onChange, onBlur, value } }) => (
                <Input
                  label="Current Password"
                  placeholder="Enter your current password"
                  value={value}
                  onChangeText={onChange}
                  secureTextEntry={!showCurrentPassword}
                  error={errors.currentPassword?.message}
                  rightIcon={showCurrentPassword ? 'eye-off' : 'eye'}
                  onRightIconPress={() => setShowCurrentPassword(!showCurrentPassword)}
                />
              )}
            />

            <Controller
              control={control}
              name="newPassword"
              render={({ field: { onChange, onBlur, value } }) => (
                <Input
                  label="New Password"
                  placeholder="Enter your new password"
                  value={value}
                  onChangeText={onChange}
                  secureTextEntry={!showNewPassword}
                  error={errors.newPassword?.message}
                  rightIcon={showNewPassword ? 'eye-off' : 'eye'}
                  onRightIconPress={() => setShowNewPassword(!showNewPassword)}
                />
              )}
            />

            <Controller
              control={control}
              name="confirmPassword"
              render={({ field: { onChange, onBlur, value } }) => (
                <Input
                  label="Confirm New Password"
                  placeholder="Confirm your new password"
                  value={value}
                  onChangeText={onChange}
                  secureTextEntry={!showConfirmPassword}
                  error={errors.confirmPassword?.message}
                  rightIcon={showConfirmPassword ? 'eye-off' : 'eye'}
                  onRightIconPress={() => setShowConfirmPassword(!showConfirmPassword)}
                />
              )}
            />

            <View style={styles.passwordRequirements}>
              <Text style={styles.requirementsTitle}>Password Requirements:</Text>
              <Text style={styles.requirement}>• At least 6 characters long</Text>
              <Text style={styles.requirement}>• Contains at least one uppercase letter</Text>
              <Text style={styles.requirement}>• Contains at least one lowercase letter</Text>
              <Text style={styles.requirement}>• Contains at least one number</Text>
            </View>
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
            title="Change Password"
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
    marginBottom: SPACING.md,
  },
  description: {
    ...TYPOGRAPHY.body,
    color: COLORS.darkGray,
    marginBottom: SPACING.lg,
    lineHeight: 20,
  },
  passwordRequirements: {
    backgroundColor: COLORS.backgroundTertiary,
    padding: SPACING.md,
    borderRadius: RADIUS.sm,
    marginTop: SPACING.md,
  },
  requirementsTitle: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    fontWeight: 'bold',
    marginBottom: SPACING.sm,
  },
  requirement: {
    ...TYPOGRAPHY.caption,
    color: COLORS.darkGray,
    marginBottom: 2,
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

export default ChangePasswordScreen;
