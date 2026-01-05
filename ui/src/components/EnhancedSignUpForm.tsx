/**
 * Enhanced Sign-Up Form
 * Complete production-ready sign-up form with all required fields
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import TeamServiceBackend, { Team } from '../services/TeamServiceBackend';

export interface SignUpFormData {
  name: string;
  email: string;
  phone: string;
  password?: string;
  confirmPassword?: string;
  role: 'worker' | 'team_leader' | '';
  teamId?: string;
  teamName?: string;
  skills: string;
  selfDescription: string;
}

interface EnhancedSignUpFormProps {
  initialData?: Partial<SignUpFormData>;
  onSubmit: (data: SignUpFormData) => Promise<void>;
  isGoogleSignUp?: boolean;
  loading?: boolean;
}

const EnhancedSignUpForm: React.FC<EnhancedSignUpFormProps> = ({
  initialData,
  onSubmit,
  isGoogleSignUp = false,
  loading = false,
}) => {
  // Form state
  const [formData, setFormData] = useState<SignUpFormData>({
    name: initialData?.name || '',
    email: initialData?.email || '',
    phone: initialData?.phone || '',
    password: '',
    confirmPassword: '',
    role: initialData?.role || '',
    teamId: initialData?.teamId || '',
    teamName: initialData?.teamName || '',
    skills: initialData?.skills || '',
    selfDescription: initialData?.selfDescription || '',
  });

  // Validation errors
  const [errors, setErrors] = useState<Partial<Record<keyof SignUpFormData, string>>>({});

  // Team search state
  const [teamSearchText, setTeamSearchText] = useState('');
  const [teamSearchResults, setTeamSearchResults] = useState<Team[]>([]);
  const [teamSearchLoading, setTeamSearchLoading] = useState(false);
  const [showTeamDropdown, setShowTeamDropdown] = useState(false);

  // Password visibility
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  // Character count for self description
  const [descriptionLength, setDescriptionLength] = useState(0);
  const MAX_DESCRIPTION_LENGTH = 500;

  // Update field value
  const updateField = (field: keyof SignUpFormData, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    // Clear error for this field
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  };

  // Team search with debounce
  useEffect(() => {
    const searchTeams = async () => {
      if (!teamSearchText || teamSearchText.trim().length === 0) {
        setTeamSearchResults([]);
        return;
      }

      setTeamSearchLoading(true);
      try {
        const results = await TeamServiceBackend.searchTeams(teamSearchText);
        setTeamSearchResults(results);
      } catch (error) {
        console.error('Team search error:', error);
        setTeamSearchResults([]);
      } finally {
        setTeamSearchLoading(false);
      }
    };

    const debounceTimer = setTimeout(searchTeams, 300);
    return () => clearTimeout(debounceTimer);
  }, [teamSearchText]);

  // Select team from search results
  const selectTeam = (team: Team) => {
    setFormData((prev) => ({
      ...prev,
      teamId: team.teamId,
      teamName: team.teamName,
    }));
    setTeamSearchText(team.teamName);
    setShowTeamDropdown(false);
    if (errors.teamId) {
      setErrors((prev) => ({ ...prev, teamId: undefined }));
    }
  };

  // Validate form
  const validateForm = (): boolean => {
    const newErrors: Partial<Record<keyof SignUpFormData, string>> = {};

    // Name validation
    if (!formData.name || formData.name.trim().length < 2) {
      newErrors.name = 'Name must be at least 2 characters';
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!formData.email || !emailRegex.test(formData.email)) {
      newErrors.email = 'Please enter a valid email address';
    }

    // Phone validation
    const phoneRegex = /^\+?[1-9]\d{1,14}$/;
    if (!formData.phone || !phoneRegex.test(formData.phone.replace(/[\s-]/g, ''))) {
      newErrors.phone = 'Please enter a valid phone number';
    }

    // Password validation (only for email/password signup)
    if (!isGoogleSignUp) {
      if (!formData.password || formData.password.length < 6) {
        newErrors.password = 'Password must be at least 6 characters';
      }

      if (formData.password !== formData.confirmPassword) {
        newErrors.confirmPassword = 'Passwords do not match';
      }
    }

    // Role validation
    if (!formData.role) {
      newErrors.role = 'Please select a role';
    }

    // Team validation (only for workers)
    if (formData.role === 'worker' && !formData.teamId) {
      newErrors.teamId = 'Please select a team';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  // Handle form submission
  const handleSubmit = async () => {
    if (!validateForm()) {
      return;
    }

    try {
      await onSubmit(formData);
    } catch (error) {
      console.error('Form submission error:', error);
    }
  };

  return (
    <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
      <View style={styles.formContainer}>
        {/* Name Field */}
        <View style={styles.inputContainer}>
          <Text style={styles.label}>Full Name *</Text>
          <TextInput
            style={[styles.input, errors.name && styles.inputError]}
            placeholder="Enter your full name"
            value={formData.name}
            onChangeText={(value) => updateField('name', value)}
            editable={!loading}
            placeholderTextColor={COLORS.text.secondary}
          />
          {errors.name && <Text style={styles.errorText}>{errors.name}</Text>}
        </View>

        {/* Email Field */}
        <View style={styles.inputContainer}>
          <Text style={styles.label}>Email Address *</Text>
          <TextInput
            style={[styles.input, errors.email && styles.inputError]}
            placeholder="Enter your email"
            value={formData.email}
            onChangeText={(value) => updateField('email', value)}
            keyboardType="email-address"
            autoCapitalize="none"
            editable={!loading && !isGoogleSignUp}
            placeholderTextColor={COLORS.text.secondary}
          />
          {errors.email && <Text style={styles.errorText}>{errors.email}</Text>}
        </View>

        {/* Phone Number Field */}
        <View style={styles.inputContainer}>
          <Text style={styles.label}>Phone Number *</Text>
          <TextInput
            style={[styles.input, errors.phone && styles.inputError]}
            placeholder="+1234567890"
            value={formData.phone}
            onChangeText={(value) => updateField('phone', value)}
            keyboardType="phone-pad"
            editable={!loading}
            placeholderTextColor={COLORS.text.secondary}
          />
          {errors.phone && <Text style={styles.errorText}>{errors.phone}</Text>}
        </View>

        {/* Password Fields (only for email/password signup) */}
        {!isGoogleSignUp && (
          <>
            <View style={styles.inputContainer}>
              <Text style={styles.label}>Password *</Text>
              <View style={styles.passwordContainer}>
                <TextInput
                  style={[styles.input, styles.passwordInput, errors.password && styles.inputError]}
                  placeholder="Enter your password"
                  value={formData.password}
                  onChangeText={(value) => updateField('password', value)}
                  secureTextEntry={!showPassword}
                  editable={!loading}
                  placeholderTextColor={COLORS.text.secondary}
                />
                <TouchableOpacity
                  style={styles.eyeButton}
                  onPress={() => setShowPassword(!showPassword)}
                >
                  <MaterialIcons
                    name={showPassword ? 'visibility-off' : 'visibility'}
                    size={20}
                    color={COLORS.text.secondary}
                  />
                </TouchableOpacity>
              </View>
              {errors.password && <Text style={styles.errorText}>{errors.password}</Text>}
            </View>

            <View style={styles.inputContainer}>
              <Text style={styles.label}>Confirm Password *</Text>
              <View style={styles.passwordContainer}>
                <TextInput
                  style={[styles.input, styles.passwordInput, errors.confirmPassword && styles.inputError]}
                  placeholder="Confirm your password"
                  value={formData.confirmPassword}
                  onChangeText={(value) => updateField('confirmPassword', value)}
                  secureTextEntry={!showConfirmPassword}
                  editable={!loading}
                  placeholderTextColor={COLORS.text.secondary}
                />
                <TouchableOpacity
                  style={styles.eyeButton}
                  onPress={() => setShowConfirmPassword(!showConfirmPassword)}
                >
                  <MaterialIcons
                    name={showConfirmPassword ? 'visibility-off' : 'visibility'}
                    size={20}
                    color={COLORS.text.secondary}
                  />
                </TouchableOpacity>
              </View>
              {errors.confirmPassword && <Text style={styles.errorText}>{errors.confirmPassword}</Text>}
            </View>
          </>
        )}

        {/* Role Selection */}
        <View style={styles.inputContainer}>
          <Text style={styles.label}>Role *</Text>
          <View style={styles.roleContainer}>
            <TouchableOpacity
              style={[
                styles.roleButton,
                formData.role === 'worker' && styles.roleButtonSelected,
              ]}
              onPress={() => updateField('role', 'worker')}
              disabled={loading}
            >
              <MaterialIcons
                name="work"
                size={24}
                color={formData.role === 'worker' ? COLORS.white : COLORS.primary}
              />
              <Text
                style={[
                  styles.roleButtonText,
                  formData.role === 'worker' && styles.roleButtonTextSelected,
                ]}
              >
                Worker
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[
                styles.roleButton,
                formData.role === 'team_leader' && styles.roleButtonSelected,
              ]}
              onPress={() => updateField('role', 'team_leader')}
              disabled={loading}
            >
              <MaterialIcons
                name="groups"
                size={24}
                color={formData.role === 'team_leader' ? COLORS.white : COLORS.secondary}
              />
              <Text
                style={[
                  styles.roleButtonText,
                  formData.role === 'team_leader' && styles.roleButtonTextSelected,
                ]}
              >
                Team Leader
              </Text>
            </TouchableOpacity>
          </View>
          {errors.role && <Text style={styles.errorText}>{errors.role}</Text>}
        </View>

        {/* Team Name Field (Conditional - Only for Workers) */}
        {formData.role === 'worker' && (
          <View style={styles.inputContainer}>
            <Text style={styles.label}>Team Name *</Text>
            <View>
              <TextInput
                style={[styles.input, errors.teamId && styles.inputError]}
                placeholder="Search for your team..."
                value={teamSearchText}
                onChangeText={(value) => {
                  setTeamSearchText(value);
                  setShowTeamDropdown(true);
                }}
                onFocus={() => setShowTeamDropdown(true)}
                editable={!loading}
                placeholderTextColor={COLORS.text.secondary}
              />
              
              {/* Team Search Dropdown */}
              {showTeamDropdown && teamSearchText.length >= 2 && (
                <View style={styles.dropdown}>
                  {teamSearchLoading ? (
                    <View style={styles.dropdownItem}>
                      <ActivityIndicator size="small" color={COLORS.primary} />
                      <Text style={styles.dropdownText}>Searching...</Text>
                    </View>
                  ) : teamSearchResults.length > 0 ? (
                    teamSearchResults.map((team) => (
                      <TouchableOpacity
                        key={team.teamId}
                        style={styles.dropdownItem}
                        onPress={() => selectTeam(team)}
                      >
                        <MaterialIcons name="group" size={20} color={COLORS.primary} />
                        <View style={styles.dropdownTextContainer}>
                          <Text style={styles.dropdownText}>{team.teamName}</Text>
                          {team.leaderName && (
                            <Text style={styles.dropdownSubtext}>
                              Leader: {team.leaderName}
                            </Text>
                          )}
                        </View>
                      </TouchableOpacity>
                    ))
                  ) : (
                    <View style={styles.dropdownItem}>
                      <Text style={styles.dropdownText}>No teams found</Text>
                    </View>
                  )}
                </View>
              )}
            </View>
            {errors.teamId && <Text style={styles.errorText}>{errors.teamId}</Text>}
          </View>
        )}

        {/* Skills Field */}
        <View style={styles.inputContainer}>
          <Text style={styles.label}>Skills (Optional)</Text>
          <TextInput
            style={[styles.input, styles.textArea]}
            placeholder="e.g., Bible Study, Community Outreach, Youth Ministry"
            value={formData.skills}
            onChangeText={(value) => updateField('skills', value)}
            multiline
            numberOfLines={3}
            editable={!loading}
            placeholderTextColor={COLORS.text.secondary}
          />
        </View>

        {/* Self Description Field */}
        <View style={styles.inputContainer}>
          <View style={styles.labelRow}>
            <Text style={styles.label}>About You (Optional)</Text>
            <Text style={styles.characterCount}>
              {descriptionLength}/{MAX_DESCRIPTION_LENGTH}
            </Text>
          </View>
          <TextInput
            style={[styles.input, styles.textArea]}
            placeholder="Tell us about yourself and your ministry experience..."
            value={formData.selfDescription}
            onChangeText={(value) => {
              if (value.length <= MAX_DESCRIPTION_LENGTH) {
                updateField('selfDescription', value);
                setDescriptionLength(value.length);
              }
            }}
            multiline
            numberOfLines={5}
            maxLength={MAX_DESCRIPTION_LENGTH}
            editable={!loading}
            placeholderTextColor={COLORS.text.secondary}
          />
        </View>

        {/* Submit Button */}
        <TouchableOpacity
          style={[styles.submitButton, loading && styles.submitButtonDisabled]}
          onPress={handleSubmit}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator size="small" color={COLORS.white} />
          ) : (
            <Text style={styles.submitButtonText}>
              {isGoogleSignUp ? 'Complete Sign Up' : 'Create Account'}
            </Text>
          )}
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  formContainer: {
    padding: SPACING.xl,
  },
  inputContainer: {
    marginBottom: SPACING.lg,
  },
  label: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  labelRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  characterCount: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },
  input: {
    height: 56,
    borderWidth: 1,
    borderColor: COLORS.border.light,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.lg,
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.primary,
    backgroundColor: COLORS.white,
  },
  inputError: {
    borderColor: COLORS.error,
  },
  textArea: {
    height: 100,
    paddingTop: SPACING.md,
    textAlignVertical: 'top',
  },
  passwordContainer: {
    position: 'relative',
  },
  passwordInput: {
    paddingRight: 50,
  },
  eyeButton: {
    position: 'absolute',
    right: SPACING.lg,
    top: 18,
  },
  errorText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.error,
    marginTop: SPACING.xs,
  },
  roleContainer: {
    flexDirection: 'row',
    gap: SPACING.md,
  },
  roleButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: SPACING.sm,
    height: 80,
    borderWidth: 2,
    borderColor: COLORS.border.light,
    borderRadius: RADIUS.lg,
    backgroundColor: COLORS.white,
  },
  roleButtonSelected: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.primary,
  },
  roleButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  roleButtonTextSelected: {
    color: COLORS.white,
  },
  dropdown: {
    position: 'absolute',
    top: 60,
    left: 0,
    right: 0,
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    borderWidth: 1,
    borderColor: COLORS.border.light,
    maxHeight: 200,
    zIndex: 1000,
    ...SHADOWS.md,
  },
  dropdownItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    gap: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  dropdownTextContainer: {
    flex: 1,
  },
  dropdownText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
  },
  dropdownSubtext: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  submitButton: {
    height: 56,
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.lg,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: SPACING.xl,
    ...SHADOWS.md,
  },
  submitButtonDisabled: {
    opacity: 0.6,
  },
  submitButtonText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },
});

export default EnhancedSignUpForm;

