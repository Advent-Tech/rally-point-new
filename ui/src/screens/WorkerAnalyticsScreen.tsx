import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  Dimensions,
  Platform,
  Image,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

const { width } = Dimensions.get('window');

interface WorkerAnalyticsScreenProps {
  navigation: any;
}

const WorkerAnalyticsScreen: React.FC<WorkerAnalyticsScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [selectedPeriod, setSelectedPeriod] = useState('week');
  const [isLoading, setIsLoading] = useState(false);

  // Mock data for demonstration
  const analyticsData = {
    week: {
      deliveries: 12,
      surveys: 8,
      distance: 24.5,
      timeSpent: 18,
    },
    month: {
      deliveries: 48,
      surveys: 32,
      distance: 98.0,
      timeSpent: 72,
    },
    year: {
      deliveries: 576,
      surveys: 384,
      distance: 1176.0,
      timeSpent: 864,
    },
  };

  const currentData = analyticsData[selectedPeriod as keyof typeof analyticsData];

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />

      {/* Blue Gradient Background */}
      <Image
        source={require('../../assets/top-gradient.png')}
        style={styles.gradientBackground}
        resizeMode="cover"
      />

      {/* Header */}
      <View style={styles.headerContainer}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <MaterialIcons name="arrow-back" size={24} color={COLORS.text.primary} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Analytics</Text>
          <View style={{ width: 24 }} />
        </View>
      </View>

      {/* Period Selector */}
      <View style={styles.periodSelector}>
        {['week', 'month', 'year'].map((period) => (
          <TouchableOpacity
            key={period}
            style={[
              styles.periodButton,
              selectedPeriod === period && styles.periodButtonActive,
            ]}
            onPress={() => setSelectedPeriod(period)}
          >
            <Text
              style={[
                styles.periodButtonText,
                selectedPeriod === period && styles.periodButtonTextActive,
              ]}
            >
              {period.charAt(0).toUpperCase() + period.slice(1)}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Main Content */}
      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentContainer}
        showsVerticalScrollIndicator={false}
      >
        {/* Performance Metrics */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Performance Metrics</Text>
          <View style={styles.metricsGrid}>
            <View style={styles.metricCard}>
              <MaterialIcons name="local-shipping" size={24} color={COLORS.primary} />
              <Text style={styles.metricValue}>{currentData.deliveries}</Text>
              <Text style={styles.metricLabel}>Deliveries</Text>
            </View>
            <View style={styles.metricCard}>
              <MaterialIcons name="assignment" size={24} color={COLORS.secondary} />
              <Text style={styles.metricValue}>{currentData.surveys}</Text>
              <Text style={styles.metricLabel}>Surveys</Text>
            </View>
            <View style={styles.metricCard}>
              <MaterialIcons name="directions" size={24} color={COLORS.success} />
              <Text style={styles.metricValue}>{currentData.distance}km</Text>
              <Text style={styles.metricLabel}>Distance</Text>
            </View>
            <View style={styles.metricCard}>
              <MaterialIcons name="schedule" size={24} color={COLORS.warning} />
              <Text style={styles.metricValue}>{currentData.timeSpent}h</Text>
              <Text style={styles.metricLabel}>Time Spent</Text>
            </View>
          </View>
        </View>

        {/* Progress Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Progress Overview</Text>
          <View style={styles.progressSection}>
            <View style={styles.progressItem}>
              <Text style={styles.progressLabel}>Weekly Goal</Text>
              <View style={styles.progressBar}>
                <View style={[styles.progressFill, { width: '68%' }]} />
              </View>
              <Text style={styles.progressText}>68% Complete</Text>
            </View>
            <View style={styles.progressItem}>
              <Text style={styles.progressLabel}>Monthly Target</Text>
              <View style={styles.progressBar}>
                <View style={[styles.progressFill, { width: '82%' }]} />
              </View>
              <Text style={styles.progressText}>82% Complete</Text>
            </View>
          </View>
        </View>

        {/* Goals Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Goals & Targets</Text>
          <View style={styles.goalsContainer}>
            <View style={styles.goalCard}>
              <Text style={styles.goalTitle}>This Week</Text>
              <Text style={styles.goalValue}>15 Deliveries</Text>
            </View>
            <View style={styles.goalCard}>
              <Text style={styles.goalTitle}>This Month</Text>
              <Text style={styles.goalValue}>60 Deliveries</Text>
            </View>
          </View>
        </View>

        {/* Bottom Padding */}
        <View style={styles.bottomPadding} />
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F3F4F9',
  },
  gradientBackground: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    width: Dimensions.get('window').width,
    height: Dimensions.get('window').height * 0.55,
  },
  headerContainer: {
    paddingTop: Platform.OS === 'ios' ? 50 : 25,
    paddingBottom: SPACING.sm,
    backgroundColor: 'transparent',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
  },
  headerTitle: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  periodSelector: {
    flexDirection: 'row',
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    borderRadius: RADIUS.lg,
    padding: SPACING.xs,
    marginHorizontal: SPACING.xl,
    marginBottom: SPACING.lg,
    ...SHADOWS.sm,
  },
  periodButton: {
    flex: 1,
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
  },
  periodButtonActive: {
    backgroundColor: COLORS.primary,
  },
  periodButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.secondary,
  },
  periodButtonTextActive: {
    color: COLORS.white,
  },
  content: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  contentContainer: {
    paddingHorizontal: SPACING.xl,
    paddingTop: SPACING.md,
    paddingBottom: 200,
  },
  section: {
    marginBottom: SPACING['2xl'],
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.lg,
  },
  metricsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  metricCard: {
    width: '48%',
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    marginBottom: SPACING.md,
    ...SHADOWS.md,
  },
  metricValue: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginTop: SPACING.sm,
    marginBottom: SPACING.xs,
  },
  metricLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  progressSection: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    ...SHADOWS.md,
  },
  progressItem: {
    marginBottom: SPACING.lg,
  },
  progressLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  progressBar: {
    height: 8,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.full,
    overflow: 'hidden',
    marginBottom: SPACING.xs,
  },
  progressFill: {
    height: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.full,
  },
  progressText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'right',
  },
  goalsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  goalCard: {
    width: '48%',
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    ...SHADOWS.md,
  },
  goalTitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
  },
  goalValue: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.primary,
  },
  bottomPadding: {
    height: 120,
  },
});

export default WorkerAnalyticsScreen;
