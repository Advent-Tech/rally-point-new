import React, { useState, useEffect, useRef } from 'react';
import { View, Text, ScrollView, Alert, TouchableOpacity, StyleSheet, SafeAreaView, Platform, Image, TextInput, Dimensions, ActivityIndicator, Clipboard, Modal, Pressable } from 'react-native';
import { useForm, Controller } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { Button, Input } from '../components';
import { SignUpFormData, UserRole } from '../types';
import { signUpSchema } from '../utils/validation';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import TeamServiceBackend, { Team } from '../services/TeamServiceBackend';

// Conditional import for Picker
let Picker: any;
if (Platform.OS !== 'web') {
  Picker = require('@react-native-picker/picker').Picker;
}

interface SignUpScreenProps {
  navigation: any;
}

interface ExtendedSignUpFormData extends SignUpFormData {
  teamId?: string;
  teamName?: string;
  teamLeaderId?: string;
  teamLeaderName?: string;
  skills?: string;
  selfDescription?: string;
}

const SignUpScreen: React.FC<SignUpScreenProps> = ({ navigation }) => {
  const { signUp } = useAuth();
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  // Team search states
  const [teamSearchText, setTeamSearchText] = useState('');
  const [teamSearchResults, setTeamSearchResults] = useState<Team[]>([]);
  const [teamSearchLoading, setTeamSearchLoading] = useState(false);
  const [showTeamDropdown, setShowTeamDropdown] = useState(false);
  const [selectedTeam, setSelectedTeam] = useState<Team | null>(null);

  // Additional fields
  const [skills, setSkills] = useState('');
  const [selfDescription, setSelfDescription] = useState('');
  const [descriptionCharCount, setDescriptionCharCount] = useState(0);

  const teamSearchContainerRef = useRef<View>(null);
  const [dropdownPos, setDropdownPos] = useState({ top: 0, left: 0, width: 0 });

  const measureDropdown = () => {
    try {
      teamSearchContainerRef.current?.measureInWindow((x: number, y: number, w: number, h: number) => {
        setDropdownPos({ top: y + h + 4, left: x, width: w });
      });
    } catch {}
  };

  const openDropdown = () => {
    setShowTeamDropdown(true);
    setTimeout(measureDropdown, 0);
  };

  const {
    control,
    handleSubmit,
    formState: { errors },
    watch,
    setError,
  } = useForm<SignUpFormData>({
    resolver: yupResolver(signUpSchema),
    defaultValues: {
      email: '',
      password: '',
      confirmPassword: '',
      displayName: '',
      role: 'worker',
    },
  });

  const selectedRole = watch('role');

  // Debounced team search
  useEffect(() => {
    if (selectedRole === 'team_leader') {
      // Team leaders create new teams, don't search existing teams
      setTeamSearchResults([]);
      setSelectedTeam(null);
      // Don't clear teamSearchText for team leaders as it's their team name
      return;
    }

    if (selectedRole !== 'worker') {
      setTeamSearchText('');
      setTeamSearchResults([]);
      setSelectedTeam(null);
      return;
    }

    if (teamSearchText.length < 2) {
      setTeamSearchResults([]);
      return;
    }

    const delayDebounce = setTimeout(async () => {
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
    }, 300);

    return () => clearTimeout(delayDebounce);
  }, [teamSearchText, selectedRole]);

  const handleTeamSelect = (team: Team) => {
    setSelectedTeam(team);
    setTeamSearchText(team.name);
    setShowTeamDropdown(false);
  };

  const handlePasteTeamLink = async () => {
    try {
      const clipboardContent = await Clipboard.getString();

      // Parse team link formats:
      // rallypoint://team/{teamId}
      // https://rallypoint.app/team/{teamId}
      let teamId: string | null = null;

      if (clipboardContent.startsWith('rallypoint://team/')) {
        teamId = clipboardContent.replace('rallypoint://team/', '');
      } else if (clipboardContent.includes('rallypoint.app/team/')) {
        const match = clipboardContent.match(/rallypoint\.app\/team\/([^/?]+)/);
        teamId = match ? match[1] : null;
      }

      if (teamId) {
        try {
          const team = await TeamServiceBackend.getTeamById(teamId);
          if (team) {
            handleTeamSelect(team);
            Alert.alert('Team Found', `Found team: ${team.teamName}`);
          } else {
            Alert.alert('Team Not Found', 'Could not find a team with that link.');
          }
        } catch (error) {
          Alert.alert('Error', 'Failed to fetch team information.');
        }
      } else {
        Alert.alert('Invalid Link', 'Please paste a valid team invite link.');
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to access clipboard.');
    }
  };

  const onSubmit = async (data: SignUpFormData) => {
    setLoading(true);

    try {
      // Validate team requirements
      if (selectedRole === 'worker' && !selectedTeam) {
        Alert.alert('Team Required', 'Please select a team to join as a worker.');
        setLoading(false);
        return;
      }

      if (selectedRole === 'team_leader' && !teamSearchText.trim()) {
        Alert.alert('Team Name Required', 'Please enter a team name to create as a team leader.');
        setLoading(false);
        return;
      }

      // Prepare extended data
      const extendedData: ExtendedSignUpFormData = {
        ...data,
        skills: skills.trim(),
        selfDescription: selfDescription.trim(),
      };

      // Add team information based on role
      if (selectedRole === 'worker' && selectedTeam) {
        extendedData.teamId = selectedTeam.id;
        extendedData.teamName = selectedTeam.name;
        extendedData.teamLeaderId = selectedTeam.leader_id;
        extendedData.teamLeaderName = ''; // Backend doesn't provide leader name
      } else if (selectedRole === 'team_leader') {
        // For team leaders, teamName will be used to create a new team
        extendedData.teamName = teamSearchText.trim();
      }

      await signUp(extendedData);

      Alert.alert(
        'Account Created!',
        'Your account has been created successfully.',
        [
          {
            text: 'OK',
            onPress: () => {
              navigation.replace('Main');
            },
          },
        ]
      );
    } catch (error: any) {
      console.error('Registration error:', error);
      
      // Handle specific errors with better UX
      let errorMessage = 'Something went wrong. Please try again.';
      
      if (error.message?.includes('already exists')) {
        errorMessage = 'An account with this email already exists. Please sign in or use a different email.';
        // Highlight email field
        setError('email', { 
          type: 'manual', 
          message: 'Email already exists' 
        });
      } else if (error.message?.includes('password')) {
        errorMessage = 'Password requirements not met. Please check your password.';
        setError('password', { 
          type: 'manual', 
          message: 'Invalid password' 
        });
      } else if (error.message?.includes('Invalid registration data')) {
        errorMessage = 'Please fill in all required fields correctly.';
      }
      
      Alert.alert('Registration Failed', errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const { width } = Dimensions.get('window');

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="always"
      >
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <MaterialIcons name="arrow-back" size={24} color={COLORS.text.primary} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Create Account</Text>
          <View style={{ width: 24 }} />
        </View>

        {/* Form */}
        <View style={styles.form}>
          {/* Role Selection */}
          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Account Type *</Text>
            <Controller
              control={control}
              name="role"
              render={({ field: { onChange, value } }) => (
                <View style={styles.pickerContainer}>
                  {Platform.OS === 'web' ? (
                    <select
                      value={value}
                      onChange={(e) => onChange(e.target.value)}
                      style={{
                        width: '100%',
                        padding: SPACING.md,
                        borderWidth: 1,
                        borderColor: COLORS.border.default,
                        borderRadius: RADIUS.md,
                        backgroundColor: 'transparent',
                        color: COLORS.text.primary,
                      }}
                    >
                      <option value="worker">Worker</option>
                      <option value="team_leader">Team Leader</option>
                    </select>
                  ) : (
                    <Picker
                      selectedValue={value}
                      onValueChange={onChange}
                      style={{ height: 56 }}
                    >
                      <Picker.Item label="Worker" value="worker" />
                      <Picker.Item label="Team Leader" value="team_leader" />
                    </Picker>
                  )}
                </View>
              )}
            />
            {errors.role && (
              <Text style={styles.errorText}>{errors.role.message}</Text>
            )}
          </View>

          {/* Team Name Field - Only for Workers */}
          {selectedRole === 'worker' && (
            <View
              style={[
                styles.inputContainer,
                showTeamDropdown && teamSearchText.length >= 2 && styles.inputContainerRaised,
              ]}
              pointerEvents="box-none"
            >
              <Text style={styles.inputLabel}>Team Name *</Text>
              <View style={styles.teamInputRow} pointerEvents="box-none">
                <View
                  ref={teamSearchContainerRef}
                  onLayout={measureDropdown}
                  style={styles.teamSearchContainer}
                >
                  <TextInput
                    style={styles.teamInput}
                    placeholder="Search for your team..."
                    value={teamSearchText}
                    onChangeText={(text) => {
                      setTeamSearchText(text);
                      openDropdown();
                    }}
                    // Don't auto-open on focus to avoid reopening after selection
                    placeholderTextColor={COLORS.text.secondary}
                  />
                  {teamSearchLoading && (
                    <ActivityIndicator
                      size="small"
                      color={COLORS.primary}
                      style={styles.searchLoader}
                    />
                  )}
                </View>
                <TouchableOpacity
                  style={styles.pasteLinkButton}
                  onPress={handlePasteTeamLink}
                  activeOpacity={0.7}
                >
                  <MaterialIcons name="content-paste" size={16} color={COLORS.primary} />
                  <Text style={styles.pasteLinkText}>Paste Link</Text>
                </TouchableOpacity>
              </View>

              {/* Team Search Dropdown (Modal Overlay) */}
              {showTeamDropdown && teamSearchText.length >= 2 && (
                <Modal
                  transparent
                  animationType="none"
                  visible={showTeamDropdown}
                  onRequestClose={() => setShowTeamDropdown(false)}
                >
                  <View style={styles.modalContainer}>
                    <Pressable style={styles.modalBackdrop} onPress={() => setShowTeamDropdown(false)} />
                    <View
                      style={[
                        styles.modalDropdown,
                        {
                          top: dropdownPos.top,
                          left: dropdownPos.left,
                          width: dropdownPos.width,
                        },
                      ]}
                    >
                      {teamSearchLoading ? (
                        <View style={styles.noTeamsContainer}>
                          <ActivityIndicator size="small" color={COLORS.primary} />
                        </View>
                      ) : teamSearchResults.length > 0 ? (
                        <ScrollView
                          style={styles.teamDropdownScroll}
                          nestedScrollEnabled
                          keyboardShouldPersistTaps="always"
                        >
                          {teamSearchResults.map((team) => (
                            <TouchableOpacity
                              key={team.id}
                              style={styles.teamDropdownItem}
                              onPress={() => {
                                handleTeamSelect(team);
                                setShowTeamDropdown(false);
                              }}
                              activeOpacity={0.7}
                            >
                              <View style={styles.teamDropdownItemContent}>
                                <Text style={styles.teamDropdownItemName}>{team.name}</Text>
                                <Text style={styles.teamDropdownItemLeader}>ID: {team.id}</Text>
                              </View>
                            </TouchableOpacity>
                          ))}
                        </ScrollView>
                      ) : (
                        <View style={styles.noTeamsContainer}>
                          <Text style={styles.noTeamsText}>No teams found</Text>
                        </View>
                      )}
                    </View>
                  </View>
                </Modal>
              )}

              {selectedTeam && (
                <View style={styles.selectedTeamContainer}>
                  <MaterialIcons name="check-circle" size={16} color={COLORS.success} />
                  <Text style={styles.selectedTeamText}>
                    Selected: {selectedTeam.name}
                  </Text>
                </View>
              )}
            </View>
          )}

          {/* Team Creation Field - Only for Team Leaders */}
          {selectedRole === 'team_leader' && (
            <View style={styles.inputContainer}>
              <Text style={styles.inputLabel}>Create Your Team *</Text>
              <TextInput
                style={styles.input}
                placeholder="Enter your team name..."
                value={teamSearchText}
                onChangeText={setTeamSearchText}
                placeholderTextColor={COLORS.text.secondary}
              />
              <Text style={styles.helperText}>
                As a team leader, you'll create and manage your own team
              </Text>
            </View>
          )}

          {/* Display Name */}
          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Full Name *</Text>
            <Controller
              control={control}
              name="displayName"
              render={({ field: { onChange, value } }) => (
                <TextInput
                  style={styles.input}
                  placeholder="Enter your full name"
                  value={value}
                  onChangeText={onChange}
                  placeholderTextColor={COLORS.text.secondary}
                />
              )}
            />
            {errors.displayName && (
              <Text style={styles.errorText}>{errors.displayName.message}</Text>
            )}
          </View>

          {/* Email */}
          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Email Address *</Text>
            <Controller
              control={control}
              name="email"
              render={({ field: { onChange, value } }) => (
                <TextInput
                  style={styles.input}
                  placeholder="Enter your email"
                  value={value}
                  onChangeText={onChange}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  placeholderTextColor={COLORS.text.secondary}
                />
              )}
            />
            {errors.email && (
              <Text style={styles.errorText}>{errors.email.message}</Text>
            )}
          </View>

          {/* Password */}
          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Password *</Text>
            <Controller
              control={control}
              name="password"
              render={({ field: { onChange, value } }) => (
                <View style={styles.passwordContainer}>
                  <TextInput
                    style={styles.passwordInput}
                    placeholder="Enter your password"
                    value={value}
                    onChangeText={onChange}
                    secureTextEntry={!showPassword}
                    placeholderTextColor={COLORS.text.secondary}
                  />
                  <TouchableOpacity
                    style={styles.eyeButton}
                    onPress={() => setShowPassword(!showPassword)}
                  >
                    <MaterialIcons
                      name={showPassword ? 'visibility' : 'visibility-off'}
                      size={20}
                      color={COLORS.text.secondary}
                    />
                  </TouchableOpacity>
                </View>
              )}
            />
            {errors.password && (
              <Text style={styles.errorText}>{errors.password.message}</Text>
            )}
          </View>

          {/* Confirm Password */}
          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Confirm Password *</Text>
            <Controller
              control={control}
              name="confirmPassword"
              render={({ field: { onChange, value } }) => (
                <View style={styles.passwordContainer}>
                  <TextInput
                    style={styles.passwordInput}
                    placeholder="Confirm your password"
                    value={value}
                    onChangeText={onChange}
                    secureTextEntry={!showConfirmPassword}
                    placeholderTextColor={COLORS.text.secondary}
                  />
                  <TouchableOpacity
                    style={styles.eyeButton}
                    onPress={() => setShowConfirmPassword(!showConfirmPassword)}
                  >
                    <MaterialIcons
                      name={showConfirmPassword ? 'visibility' : 'visibility-off'}
                      size={20}
                      color={COLORS.text.secondary}
                    />
                  </TouchableOpacity>
                </View>
              )}
            />
            {errors.confirmPassword && (
              <Text style={styles.errorText}>{errors.confirmPassword.message}</Text>
            )}
          </View>

          {/* Skills Field - Optional for both roles */}
          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Skills (Optional)</Text>
            <TextInput
              style={[styles.input, styles.multilineInput]}
              placeholder="e.g., Bible Study, Community Outreach, Translation, etc."
              value={skills}
              onChangeText={setSkills}
              multiline={true}
              numberOfLines={3}
              textAlignVertical="top"
              placeholderTextColor={COLORS.text.secondary}
            />
          </View>

          {/* Self Description Field - Optional for both roles */}
          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Self Description (Optional)</Text>
            <TextInput
              style={[styles.input, styles.multilineInput]}
              placeholder="Tell us about yourself and your ministry experience..."
              value={selfDescription}
              onChangeText={(text) => {
                if (text.length <= 500) {
                  setSelfDescription(text);
                  setDescriptionCharCount(text.length);
                }
              }}
              multiline={true}
              numberOfLines={4}
              maxLength={500}
              textAlignVertical="top"
              placeholderTextColor={COLORS.text.secondary}
            />
            <Text style={styles.characterCounter}>{descriptionCharCount}/500 characters</Text>
          </View>

          {/* Sign Up Button */}
          <TouchableOpacity
            style={[styles.signUpButton, loading && styles.signUpButtonDisabled]}
            onPress={handleSubmit(onSubmit)}
            disabled={loading}
            activeOpacity={0.8}
          >
            <Text style={styles.signUpButtonText}>
              {loading ? 'Creating Account...' : 'Create Account'}
            </Text>
          </TouchableOpacity>

          {/* Sign In Link */}
          <View style={styles.signInContainer}>
            <Text style={styles.signInText}>Already have an account? </Text>
            <TouchableOpacity onPress={() => navigation.navigate('SignIn')}>
              <Text style={styles.signInLink}>Sign In</Text>
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    padding: SPACING.lg,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.xl,
  },
  headerTitle: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  form: {
    flex: 1,
    overflow: 'visible',
  },
  inputContainer: {
    marginBottom: SPACING.lg,
    overflow: 'visible',
    zIndex: 9999,
    position: 'relative',
  },
  inputContainerRaised: {
    zIndex: 100000,
    elevation: 30,
  },
  inputLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  input: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.md,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.surface,
  },
  multilineInput: {
    height: 80,
    textAlignVertical: 'top',
  },
  passwordContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.surface,
  },
  passwordInput: {
    flex: 1,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.md,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
  },
  eyeButton: {
    paddingHorizontal: SPACING.md,
  },
  pickerContainer: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.surface,
  },
  teamInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    overflow: 'visible',
    zIndex: 9999,
    position: 'relative',
  },
  teamSearchContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.surface,
    paddingHorizontal: SPACING.md,
    position: 'relative', // Required for absolute positioning of dropdown
    overflow: 'visible',
    zIndex: 9999,
  },
  teamInput: {
    flex: 1,
    paddingVertical: SPACING.md,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
  },
  searchLoader: {
    marginLeft: SPACING.sm,
  },
  pasteLinkButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    gap: SPACING.xs,
  },
  pasteLinkText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  teamDropdown: {
    position: 'absolute',
    top: '100%',
    left: 0,
    right: 0,
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.light,
    marginTop: SPACING.xs,
    maxHeight: 200,
    zIndex: 9999,
    ...SHADOWS.lg,
    elevation: 20,
  },
  teamDropdownSpacer: {
    height: 200,
  },
  teamDropdownScroll: {
    maxHeight: 180,
  },
  teamDropdownItem: {
    padding: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  teamDropdownItemContent: {
    flex: 1,
  },
  teamDropdownItemName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  teamDropdownItemLeader: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  modalContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  modalBackdrop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'transparent',
  },
  modalDropdown: {
    position: 'absolute',
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.light,
    maxHeight: 200,
    ...SHADOWS.lg,
  },
  noTeamsContainer: {
    padding: SPACING.lg,
    alignItems: 'center',
  },
  noTeamsText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
  },
  selectedTeamContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: SPACING.sm,
    gap: SPACING.xs,
  },
  selectedTeamText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.success,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  helperText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  errorText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.error,
    marginTop: SPACING.xs,
  },
  characterCounter: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'right',
    marginTop: SPACING.xs,
  },
  signUpButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.lg,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    marginTop: SPACING.xl,
    ...SHADOWS.md,
  },
  signUpButtonDisabled: {
    opacity: 0.6,
  },
  signUpButtonText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.white,
  },
  signInContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: SPACING.xl,
  },
  signInText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
  },
  signInLink: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
});

export default SignUpScreen;