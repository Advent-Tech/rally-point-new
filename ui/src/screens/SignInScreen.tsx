import React, { useState } from 'react';
import { View, Text, ScrollView, Alert, TouchableOpacity, StyleSheet, Dimensions, TextInput, SafeAreaView, Platform, Image } from 'react-native';
import { useForm, Controller } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { Button, Input } from '../components';
import { SignInFormData } from '../types';
import { signInSchema } from '../utils/validation';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface SignInScreenProps {
  navigation: any;
}

const { width, height } = Dimensions.get('window');

const SignInScreen: React.FC<SignInScreenProps> = ({ navigation }) => {
  const { signIn, isFirstInstall } = useAuth();
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);

  const {
    control,
    handleSubmit,
    formState: { errors },
  } = useForm<SignInFormData>({
    resolver: yupResolver(signInSchema),
    defaultValues: {
      email: '',
      password: '',
    },
  });

  const onSubmit = async (data: SignInFormData) => {
    setLoading(true);
    try {
      await signIn(data.email, data.password, rememberMe);
    } catch (error: any) {
      Alert.alert('Sign In Error', error.message || 'An error occurred during sign in');
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      {/* Gradient Background - Matching WorkerDashboard */}
      <Image
        source={require('../../assets/top-gradient.png')}
        style={styles.gradientBackground}
        resizeMode="cover"
      />

      {/* Header - Clean Logo Only */}
      <View style={styles.headerBackground}>
        <View style={styles.header}>
          <View style={styles.headerContent}>
            <View style={styles.logoContainer}>
              <Image
                source={require('../../assets/appLogo.png')}
                style={styles.appLogo}
                resizeMode="contain"
              />
            </View>
          </View>
        </View>
      </View>

      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentContainer}
        showsVerticalScrollIndicator={false}
      >
        {/* Welcome Section */}
        <View style={styles.welcomeSection}>
          <Text style={styles.welcomeTitle}>Welcome back</Text>
          <Text style={styles.welcomeSubtitle}>Sign in to continue your ministry work</Text>
        </View>

        {/* Main Card */}
        <View style={styles.card}>
          {/* Email Input */}
          <Controller
            control={control}
            name="email"
            render={({ field: { onChange, value } }) => (
              <View style={styles.inputContainer}>
                <Text style={styles.inputLabel}>Email</Text>
                <TextInput
                  style={[styles.input, errors.email && styles.inputError]}
                  placeholder="Enter your email address"
                  placeholderTextColor={COLORS.text.placeholder}
                  value={value}
                  onChangeText={onChange}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  autoCorrect={false}
                />
                {errors.email && (
                  <Text style={styles.errorText}>{errors.email.message}</Text>
                )}
              </View>
            )}
          />

          {/* Password Input */}
          <Controller
            control={control}
            name="password"
            render={({ field: { onChange, value } }) => (
              <View style={styles.inputContainer}>
                <Text style={styles.inputLabel}>Password</Text>
                <View style={styles.passwordContainer}>
                  <TextInput
                    style={[styles.input, styles.passwordInput, errors.password && styles.inputError]}
                    placeholder="Enter your password"
                    placeholderTextColor={COLORS.text.placeholder}
                    value={value}
                    onChangeText={onChange}
                    secureTextEntry={!showPassword}
                    autoCapitalize="none"
                    autoCorrect={false}
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
                {errors.password && (
                  <Text style={styles.errorText}>{errors.password.message}</Text>
                )}
              </View>
            )}
          />

          {/* Remember Me & Forgot Password */}
          <View style={styles.optionsContainer}>
            <TouchableOpacity
              style={styles.rememberContainer}
              onPress={() => setRememberMe(!rememberMe)}
            >
              <View style={[styles.checkbox, rememberMe && styles.checkboxChecked]}>
                {rememberMe && (
                  <MaterialIcons name="check" size={14} color={COLORS.white} />
                )}
              </View>
              <Text style={styles.rememberText}>Remember me</Text>
            </TouchableOpacity>

            <TouchableOpacity onPress={() => Alert.alert('Coming Soon', 'Password reset will be available soon')}>
              <Text style={styles.forgotText}>Forgot password?</Text>
            </TouchableOpacity>
          </View>

          {/* Sign In Button */}
          <TouchableOpacity
            style={[styles.signInButton, loading && styles.signInButtonDisabled]}
            onPress={handleSubmit(onSubmit)}
            disabled={loading}
          >
            <Text style={styles.signInButtonText}>
              {loading ? 'Signing in...' : 'Sign in'}
            </Text>
          </TouchableOpacity>
        </View>

        {/* Sign Up Link */}
        <View style={styles.signUpContainer}>
          <Text style={styles.signUpText}>Don't have an account yet? </Text>
          <TouchableOpacity onPress={() => navigation.navigate('SignUp')}>
            <Text style={styles.signUpLink}>Sign Up</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.secondary,
    ...(Platform.OS === 'web' && {
      height: '100vh',
      display: 'flex',
      flexDirection: 'column',
    }),
  },
  gradientBackground: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 300,
    width: '100%',
    zIndex: -1,
  },
  headerBackground: {
    backgroundColor: 'transparent',
  },
  header: {
    backgroundColor: 'transparent',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    paddingTop: SPACING.xl,
    ...SHADOWS.sm,
  },
  headerContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  appLogo: {
    width: 80,
    height: 80,
  },
  content: {
    flex: 1,
    backgroundColor: COLORS.background.secondary,
  },
  contentContainer: {
    paddingHorizontal: SPACING.xl,
    paddingTop: SPACING['2xl'],
    paddingBottom: SPACING['4xl'],
  },
  welcomeSection: {
    marginBottom: SPACING['3xl'],
  },
  welcomeTitle: {
    fontSize: TYPOGRAPHY.sizes['4xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  welcomeSubtitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.secondary,
    textAlign: 'center',
    lineHeight: 24,
  },
  card: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
    padding: SPACING['2xl'],
    marginBottom: SPACING.xl,
    ...SHADOWS.md,
  },
  inputContainer: {
    marginBottom: SPACING.lg,
  },
  inputLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  input: {
    height: 56,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.lg,
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.primary,
    backgroundColor: COLORS.white,
  },
  inputError: {
    borderColor: COLORS.error,
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
    padding: SPACING.xs,
  },
  errorText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.error,
    marginTop: SPACING.xs,
    marginLeft: SPACING.xs,
  },
  optionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.xl,
  },
  rememberContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    width: 18,
    height: 18,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.sm,
    marginRight: SPACING.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxChecked: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  rememberText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
  },
  forgotText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  signInButton: {
    height: 56,
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.lg,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: SPACING.lg,
    ...SHADOWS.md,
  },
  signInButtonDisabled: {
    backgroundColor: COLORS.text.disabled,
  },
  signInButtonText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },
  signUpContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: SPACING.lg,
  },
  signUpText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
  },
  signUpLink: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.secondary,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
});

export default SignInScreen;
