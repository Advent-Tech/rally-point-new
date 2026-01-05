import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, SHADOWS } from '../constants/Colors';

interface MinistryProgressProps {
  progress?: number;
  onMenuPress?: () => void;
}

const MinistryProgress: React.FC<MinistryProgressProps> = ({
  progress = 68,
  onMenuPress,
}) => {
  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Ministry Progress</Text>
        <TouchableOpacity
          style={styles.menuButton}
          onPress={onMenuPress}
          activeOpacity={0.7}
        >
          <MaterialIcons name="more-horiz" size={24} color={COLORS.text.secondary} />
        </TouchableOpacity>
      </View>

      {/* Progress Card */}
      <View style={styles.progressCard}>
        <View style={styles.progressContent}>
          {/* Icon Container */}
          <View style={styles.iconContainer}>
            <MaterialIcons name="map" size={28} color={COLORS.secondary} />
          </View>

          {/* Progress Info */}
          <View style={styles.progressInfo}>
            <Text style={styles.progressTitle}>Territory Coverage</Text>
            
            {/* Progress Bar */}
            <View style={styles.progressBarContainer}>
              <View style={styles.progressBarBackground}>
                <View 
                  style={[
                    styles.progressBarFill, 
                    { width: `${progress}%` }
                  ]} 
                />
              </View>
              <Text style={styles.progressPercentage}>{progress}%</Text>
            </View>
          </View>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    // marginHorizontal: SPACING.lg,
    marginVertical: SPACING.md,
    padding: SPACING.lg,
    backgroundColor: 'rgba(255, 255, 255, 0.50)',
    borderRadius: 15,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  title: {
    fontSize: TYPOGRAPHY['3xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: '#000000',
  },
  menuButton: {
    padding: 4,
  },
  progressCard: {
    backgroundColor: COLORS.white,
    borderRadius: 16,
    padding: SPACING.lg,
    ...SHADOWS.sm,
  },
  progressContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  iconContainer: {
    backgroundColor: COLORS.secondary + '20',
    width: 56,
    height: 56,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.lg,
  },
  progressInfo: {
    flex: 1,
  },
  progressTitle: {
    fontSize: TYPOGRAPHY.xl,
    fontWeight: TYPOGRAPHY.semibold,
    color: '#000000',
    marginBottom: SPACING.sm,
  },
  progressBarContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.md,
  },
  progressBarBackground: {
    flex: 1,
    height: 8,
    backgroundColor: COLORS.background.disabled,
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: COLORS.secondary,
    borderRadius: 4,
  },
  progressPercentage: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.secondary,
    minWidth: 40,
    textAlign: 'right',
  },
});

export default MinistryProgress;
