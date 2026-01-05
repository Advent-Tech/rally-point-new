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
import MinistryProgress from '../components/MinistryProgress';
import QuickActions from '../components/QuickActions';
import ModernBottomNavigation from '../components/ModernBottomNavigation';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface UIShowcaseScreenProps {
  navigation: any;
}

const UIShowcaseScreen: React.FC<UIShowcaseScreenProps> = ({ navigation }) => {
  const [selectedDemo, setSelectedDemo] = useState<'header' | 'overview' | 'both'>('both');
  const [activeTab, setActiveTab] = useState<string>('territory');

  const handleMenuPress = () => {
    Alert.alert('Menu Pressed', 'The hamburger menu was pressed!');
  };

  const handleProfilePress = () => {
    Alert.alert('Profile Pressed', 'The profile avatar was pressed!');
  };

  const demoData = {
    distanceCovered: 1200,
    booksDelivered: 35,
    hoursActive: 4.2,
    donationsCollected: 280,
  };

  const renderDemoControls = () => (
    <View style={styles.controlsContainer}>
      <Text style={styles.controlsTitle}>Demo Controls</Text>
      <View style={styles.buttonRow}>
        <TouchableOpacity
          style={[styles.controlButton, selectedDemo === 'header' && styles.controlButtonActive]}
          onPress={() => setSelectedDemo('header')}
        >
          <Text style={[styles.controlButtonText, selectedDemo === 'header' && styles.controlButtonTextActive]}>
            Header Only
          </Text>
        </TouchableOpacity>
        
        <TouchableOpacity
          style={[styles.controlButton, selectedDemo === 'overview' && styles.controlButtonActive]}
          onPress={() => setSelectedDemo('overview')}
        >
          <Text style={[styles.controlButtonText, selectedDemo === 'overview' && styles.controlButtonTextActive]}>
            Overview Only
          </Text>
        </TouchableOpacity>
        
        <TouchableOpacity
          style={[styles.controlButton, selectedDemo === 'both' && styles.controlButtonActive]}
          onPress={() => setSelectedDemo('both')}
        >
          <Text style={[styles.controlButtonText, selectedDemo === 'both' && styles.controlButtonTextActive]}>
            Both Components
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  const renderFeatureList = () => (
    <View style={styles.featuresContainer}>
      <Text style={styles.featuresTitle}>✨ Implemented Features</Text>
      
      <View style={styles.featureSection}>
        <Text style={styles.featureSectionTitle}>🎯 Header Component</Text>
        <Text style={styles.featureItem}>✅ Pixel-perfect Figma design match</Text>
        <Text style={styles.featureItem}>✅ PNG icons from assets folder</Text>
        <Text style={styles.featureItem}>✅ Perfect circular icon buttons</Text>
        <Text style={styles.featureItem}>✅ User profile avatar with initials</Text>
        <Text style={styles.featureItem}>✅ Interactive menu and notifications</Text>
      </View>

      <View style={styles.featureSection}>
        <Text style={styles.featureSectionTitle}>📊 Ministry Overview</Text>
        <Text style={styles.featureItem}>✅ 2x2 responsive grid layout</Text>
        <Text style={styles.featureItem}>✅ Four ministry metric cards</Text>
        <Text style={styles.featureItem}>✅ Trend indicators (up/down arrows)</Text>
        <Text style={styles.featureItem}>✅ Interactive three-dot menus</Text>
        <Text style={styles.featureItem}>✅ Professional shadows and styling</Text>
      </View>

      <View style={styles.featureSection}>
        <Text style={styles.featureSectionTitle}>⚡ Quick Actions</Text>
        <Text style={styles.featureItem}>✅ 2x2 grid layout with colored buttons</Text>
        <Text style={styles.featureItem}>✅ Purple, Pink, Gold, Blue backgrounds</Text>
        <Text style={styles.featureItem}>✅ White icons on colored backgrounds</Text>
        <Text style={styles.featureItem}>✅ My Territory, Deliver Book, Survey, Team</Text>
        <Text style={styles.featureItem}>✅ Pixel-perfect Figma design match</Text>
      </View>

      <View style={styles.featureSection}>
        <Text style={styles.featureSectionTitle}>🎨 Design System</Text>
        <Text style={styles.featureItem}>✅ Rally Point brand colors</Text>
        <Text style={styles.featureItem}>✅ Material Design principles</Text>
        <Text style={styles.featureItem}>✅ Consistent typography scale</Text>
        <Text style={styles.featureItem}>✅ Professional spacing system</Text>
        <Text style={styles.featureItem}>✅ Responsive layouts</Text>
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />
      
      {/* Demo Header */}
      {(selectedDemo === 'header' || selectedDemo === 'both') && (
        <Header
          showMenu={true}
          showLogo={true}
          showProfile={true}
          showNotifications={true}
          onMenuPress={handleMenuPress}
          onProfilePress={handleProfilePress}
          onBackPress={() => navigation.goBack()}
        />
      )}

      {/* Demo Ministry Overview */}
      {(selectedDemo === 'overview' || selectedDemo === 'both') && (
        <>
          <MinistryOverview data={demoData} />
          <MinistryProgress progress={68} />
          <QuickActions />
        </>
      )}

      {/* Demo Content */}
      <ScrollView style={styles.content} contentContainerStyle={styles.contentContainer}>
        {renderDemoControls()}
        {renderFeatureList()}

        <View style={styles.nextStepsContainer}>
          <Text style={styles.nextStepsTitle}>🚀 Ready for Next Components</Text>
          <Text style={styles.nextStepsText}>
            The header and Ministry Overview components are complete and pixel-perfect! 
            Ready to implement the next UI components from your Figma designs.
          </Text>
          
          <TouchableOpacity 
            style={styles.backButton}
            onPress={() => navigation.goBack()}
          >
            <Text style={styles.backButtonText}>← Back to Dashboard</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>

      {/* Demo Bottom Navigation */}
      <View style={styles.bottomNavDemo}>
        <Text style={styles.demoLabel}>Bottom Navigation Demo:</Text>
        <ModernBottomNavigation
          activeTab={activeTab}
          onTabPress={setActiveTab}
        />
      </View>
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
  controlsContainer: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginBottom: SPACING.xl,
    ...SHADOWS.md,
  },
  controlsTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.lg,
    textAlign: 'center',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  controlButton: {
    backgroundColor: COLORS.border.default,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    borderRadius: RADIUS.lg,
    flex: 1,
    marginHorizontal: SPACING.xs,
    alignItems: 'center',
  },
  controlButtonActive: {
    backgroundColor: COLORS.primary,
  },
  controlButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  controlButtonTextActive: {
    color: COLORS.white,
  },
  featuresContainer: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginBottom: SPACING.xl,
    ...SHADOWS.md,
  },
  featuresTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.lg,
    textAlign: 'center',
  },
  featureSection: {
    marginBottom: SPACING.lg,
  },
  featureSectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  featureItem: {
    fontSize: TYPOGRAPHY.sizes.base,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
    paddingLeft: SPACING.md,
  },
  nextStepsContainer: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.xl,
    padding: SPACING.xl,
    alignItems: 'center',
    ...SHADOWS.md,
  },
  nextStepsTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.white,
    marginBottom: SPACING.md,
    textAlign: 'center',
  },
  nextStepsText: {
    fontSize: TYPOGRAPHY.sizes.base,
    color: COLORS.white,
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: SPACING.xl,
  },
  backButton: {
    backgroundColor: COLORS.white,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.xl,
    borderRadius: RADIUS.lg,
  },
  backButtonText: {
    color: COLORS.primary,
    fontSize: TYPOGRAPHY.sizes.base,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
  bottomNavDemo: {
    backgroundColor: COLORS.white,
    paddingTop: SPACING.lg,
    paddingHorizontal: SPACING.lg,
  },
  demoLabel: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
    textAlign: 'center',
  },
});

export default UIShowcaseScreen;
