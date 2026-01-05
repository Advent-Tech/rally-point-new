import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  StatusBar,
  SafeAreaView,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import UserProfileHeader from '../components/UserProfileHeader';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface UserProfileHeaderDemoProps {
  navigation: any;
}

const UserProfileHeaderDemo: React.FC<UserProfileHeaderDemoProps> = ({ navigation }) => {
  const [isActive, setIsActive] = useState(true);

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={COLORS.backgroundSecondary} />
      
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>User Profile Header Demo</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Demo Title */}
        <View style={styles.demoSection}>
          <Text style={styles.demoTitle}>🎯 User Profile Header Component</Text>
          <Text style={styles.demoDescription}>
            Exactly matching your reference image design with profile picture, name, territory, and status indicator.
          </Text>
        </View>

        {/* Live Demo */}
        <View style={styles.demoSection}>
          <Text style={styles.sectionTitle}>📱 Live Demo</Text>
          
          {/* Main Demo - Active State */}
          <View style={styles.demoContainer}>
            <Text style={styles.demoLabel}>Active User (Green Status)</Text>
            <UserProfileHeader
              userImage="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face"
              userName="Adam E."
              territoryName="Union Atlantic Territory"
              isActive={true}
              style={styles.demoItem}
            />
          </View>

          {/* Demo - Offline State */}
          <View style={styles.demoContainer}>
            <Text style={styles.demoLabel}>Offline User (Gray Status)</Text>
            <UserProfileHeader
              userImage="https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100&h=100&fit=crop&crop=face"
              userName="Sarah M."
              territoryName="Downtown District"
              isActive={false}
              style={styles.demoItem}
            />
          </View>

          {/* Demo - Different User */}
          <View style={styles.demoContainer}>
            <Text style={styles.demoLabel}>Another Active User</Text>
            <UserProfileHeader
              userImage="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face"
              userName="John D."
              territoryName="North Side Territory"
              isActive={true}
              style={styles.demoItem}
            />
          </View>

          {/* Interactive Demo */}
          <View style={styles.demoContainer}>
            <Text style={styles.demoLabel}>Interactive Demo (Tap to Toggle Status)</Text>
            <TouchableOpacity onPress={() => setIsActive(!isActive)}>
              <UserProfileHeader
                userImage="https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&crop=face"
                userName="Emma R."
                territoryName="West End Territory"
                isActive={isActive}
                style={styles.demoItem}
              />
            </TouchableOpacity>
            <Text style={styles.interactiveHint}>👆 Tap to toggle Active/Offline</Text>
          </View>
        </View>

        {/* Features List */}
        <View style={styles.featuresSection}>
          <Text style={styles.sectionTitle}>✨ Component Features</Text>
          
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>🖼️</Text>
            <Text style={styles.featureText}>Circular avatar image (48px x 48px)</Text>
          </View>
          
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>👤</Text>
            <Text style={styles.featureText}>User name - font-weight: 600, font-size: 16px</Text>
          </View>
          
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>🗺️</Text>
            <Text style={styles.featureText}>Territory name - font-size: 12px, color: #666</Text>
          </View>
          
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>🟢</Text>
            <Text style={styles.featureText}>Status indicator - Green dot (8px) for Active</Text>
          </View>
          
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>⚫</Text>
            <Text style={styles.featureText}>Status indicator - Gray dot (8px) for Offline</Text>
          </View>
          
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>✨</Text>
            <Text style={styles.featureText}>Glassmorphism effect with blur and shadow</Text>
          </View>
        </View>

        {/* Usage Instructions */}
        <View style={styles.usageSection}>
          <Text style={styles.sectionTitle}>🚀 How to Use</Text>
          <View style={styles.codeBlock}>
            <Text style={styles.codeText}>{`<UserProfileHeader
  userImage="https://example.com/avatar.jpg"
  userName="Adam E."
  territoryName="Union Atlantic Territory"
  isActive={true}
  style={customStyles}
/>`}</Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    backgroundColor: COLORS.white,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  headerTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  content: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
  },
  demoSection: {
    marginVertical: SPACING.lg,
  },
  demoTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  demoDescription: {
    fontSize: TYPOGRAPHY.sizes.base,
    color: COLORS.text.secondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  demoContainer: {
    marginBottom: SPACING.lg,
  },
  demoLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
  },
  demoItem: {
    marginBottom: SPACING.sm,
  },
  interactiveHint: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.primary,
    textAlign: 'center',
    marginTop: SPACING.xs,
    fontStyle: 'italic',
  },
  featuresSection: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginVertical: SPACING.lg,
    ...SHADOWS.md,
  },
  featureItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  featureIcon: {
    fontSize: 20,
    marginRight: SPACING.md,
    width: 30,
  },
  featureText: {
    fontSize: TYPOGRAPHY.sizes.base,
    color: COLORS.text.secondary,
    flex: 1,
  },
  usageSection: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginVertical: SPACING.lg,
    ...SHADOWS.md,
  },
  codeBlock: {
    backgroundColor: '#f8f9fa',
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    borderLeftWidth: 4,
    borderLeftColor: COLORS.primary,
  },
  codeText: {
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.primary,
    lineHeight: 20,
  },
});

export default UserProfileHeaderDemo;
