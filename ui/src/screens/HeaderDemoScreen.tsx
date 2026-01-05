import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  StatusBar,
  Alert,
} from 'react-native';
import Header from '../components/Header';
import MinistryOverview from '../components/MinistryOverview';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface HeaderDemoScreenProps {
  navigation: any;
}

const HeaderDemoScreen: React.FC<HeaderDemoScreenProps> = ({ navigation }) => {
  const [headerConfig, setHeaderConfig] = useState({
    showMenu: true,
    showLogo: true,
    showProfile: true,
    showNotifications: true,
    showBackButton: false,
    title: '',
  });

  const handleMenuPress = () => {
    Alert.alert('Menu Pressed', 'The hamburger menu was pressed!');
  };

  const handleProfilePress = () => {
    Alert.alert('Profile Pressed', 'The profile avatar was pressed!');
  };

  const handleNotificationPress = () => {
    Alert.alert('Notifications', 'Notification bell was pressed!');
  };

  const toggleOption = (option: keyof typeof headerConfig) => {
    setHeaderConfig(prev => ({
      ...prev,
      [option]: !prev[option]
    }));
  };

  const presets = [
    {
      name: 'Default (Figma Design)',
      config: {
        showMenu: true,
        showLogo: true,
        showProfile: true,
        showNotifications: true,
        showBackButton: false,
        title: '',
      }
    },
    {
      name: 'With Back Button',
      config: {
        showMenu: false,
        showLogo: false,
        showProfile: true,
        showNotifications: true,
        showBackButton: true,
        title: 'Settings',
      }
    },
    {
      name: 'Simple Title Only',
      config: {
        showMenu: false,
        showLogo: false,
        showProfile: false,
        showNotifications: false,
        showBackButton: false,
        title: 'Simple Header',
      }
    },
  ];

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />
      
      {/* Demo Header */}
      <Header
        {...headerConfig}
        onMenuPress={handleMenuPress}
        onProfilePress={handleProfilePress}
        onBackPress={() => navigation.goBack()}
      />

      {/* Ministry Overview Demo */}
      <MinistryOverview />

      {/* Demo Content */}
      <ScrollView style={styles.content} contentContainerStyle={styles.contentContainer}>
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>UI Components Demo</Text>
          <Text style={styles.description}>
            This demonstrates the new modern header and Ministry Overview components that match the Figma designs exactly.
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Design Features</Text>
          <View style={styles.featureList}>
            <Text style={styles.featureItem}>✅ Light background (#F3F4F9)</Text>
            <Text style={styles.featureItem}>✅ Hamburger menu with circular white background</Text>
            <Text style={styles.featureItem}>✅ App logo/icon display (PNG from assets)</Text>
            <Text style={styles.featureItem}>✅ Notification bell icon (PNG from assets)</Text>
            <Text style={styles.featureItem}>✅ User profile avatar with initials</Text>
            <Text style={styles.featureItem}>✅ Perfect circular icon buttons</Text>
            <Text style={styles.featureItem}>✅ Subtle shadows and elevation</Text>
            <Text style={styles.featureItem}>✅ Professional spacing and alignment</Text>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Configuration Options</Text>
          {Object.entries(headerConfig).map(([key, value]) => (
            <TouchableOpacity
              key={key}
              style={styles.optionRow}
              onPress={() => toggleOption(key as keyof typeof headerConfig)}
            >
              <Text style={styles.optionLabel}>{key}</Text>
              <View style={[styles.toggle, value && styles.toggleActive]}>
                <Text style={[styles.toggleText, value && styles.toggleTextActive]}>
                  {value ? 'ON' : 'OFF'}
                </Text>
              </View>
            </TouchableOpacity>
          ))}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Presets</Text>
          {presets.map((preset, index) => (
            <TouchableOpacity
              key={index}
              style={styles.presetButton}
              onPress={() => setHeaderConfig(preset.config)}
            >
              <Text style={styles.presetButtonText}>{preset.name}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Implementation Notes</Text>
          <Text style={styles.description}>
            • Uses exact PNG icons from assets folder (menuIcon.png, notificationIcon.png){'\n'}
            • Perfect circular icon buttons matching Figma design{'\n'}
            • The header uses the app's brand colors (Navy Blue #002b5b and Gold #d7a638){'\n'}
            • Icons have white circular backgrounds with subtle shadows{'\n'}
            • Profile avatar shows user initials with orange background{'\n'}
            • Fully responsive and follows Material Design principles{'\n'}
            • Supports all navigation patterns (menu, back button, etc.)
          </Text>
        </View>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  content: {
    flex: 1,
  },
  contentContainer: {
    padding: SPACING.lg,
  },
  section: {
    marginBottom: SPACING['3xl'],
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.lg,
  },
  description: {
    fontSize: TYPOGRAPHY.sizes.base,
    color: COLORS.text.secondary,
    lineHeight: 24,
  },
  featureList: {
    marginTop: SPACING.md,
  },
  featureItem: {
    fontSize: TYPOGRAPHY.sizes.base,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
    paddingLeft: SPACING.md,
  },
  optionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    marginBottom: SPACING.sm,
    ...SHADOWS.sm,
  },
  optionLabel: {
    fontSize: TYPOGRAPHY.sizes.base,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  toggle: {
    backgroundColor: COLORS.border.default,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
    minWidth: 50,
    alignItems: 'center',
  },
  toggleActive: {
    backgroundColor: COLORS.primary,
  },
  toggleText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  toggleTextActive: {
    color: COLORS.white,
  },
  presetButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    borderRadius: RADIUS.lg,
    marginBottom: SPACING.sm,
    ...SHADOWS.sm,
  },
  presetButtonText: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.sizes.base,
    fontWeight: TYPOGRAPHY.weights.medium,
    textAlign: 'center',
  },
});

export default HeaderDemoScreen;
