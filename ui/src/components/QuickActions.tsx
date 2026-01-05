import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { MapIcon, BookIcon, FormIcon, MessageIcon } from './icons/BottomNavIcons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface QuickActionButtonProps {
  title: string;
  svgIcon: 'map' | 'book' | 'form' | 'message' | 'location' | 'gamification';
  iconColor: string;
  backgroundColor: string;
  onPress: () => void;
}

interface QuickActionsProps {
  onMyTerritoryPress?: () => void;
  onDeliverBookPress?: () => void;
  onSurveyFormPress?: () => void;
  onTeamGroupPress?: () => void;
  onLocationTrackingPress?: () => void;
  onGamificationPress?: () => void;
}

const QuickActionButton: React.FC<QuickActionButtonProps> = ({
  title,
  svgIcon,
  iconColor,
  backgroundColor,
  onPress,
}) => {
  const renderSvgIcon = () => {
    switch (svgIcon) {
      case 'map':
        return <MapIcon size={32} color={iconColor} />;
      case 'book':
        return <BookIcon size={32} color={iconColor} />;
      case 'form':
        return <FormIcon size={32} color={iconColor} />;
      case 'message':
        return <MessageIcon size={32} color={iconColor} />;
      case 'location':
        return <MaterialIcons name="gps-fixed" size={32} color={iconColor} />;
      case 'gamification':
        return <MaterialIcons name="emoji-events" size={32} color={iconColor} />;
      default:
        return <MapIcon size={32} color={iconColor} />;
    }
  };

  return (
    <TouchableOpacity
      style={styles.actionButton}
      onPress={onPress}
      activeOpacity={0.8}
    >
      {/* Icon Container */}
      <View style={[styles.iconContainer, { backgroundColor }]}>
        {renderSvgIcon()}
      </View>

      {/* Title */}
      <Text style={styles.actionTitle}>{title}</Text>
    </TouchableOpacity>
  );
};

const QuickActions: React.FC<QuickActionsProps> = ({
  onMyTerritoryPress,
  onDeliverBookPress,
  onSurveyFormPress,
  onTeamGroupPress,
  onLocationTrackingPress,
  onGamificationPress,
}) => {
  const handleMyTerritory = () => {
    if (onMyTerritoryPress) {
      onMyTerritoryPress();
    } else {
      console.log('My Territory pressed');
    }
  };

  const handleDeliverBook = () => {
    if (onDeliverBookPress) {
      onDeliverBookPress();
    } else {
      console.log('Deliver Book pressed');
    }
  };

  const handleSurveyForm = () => {
    if (onSurveyFormPress) {
      onSurveyFormPress();
    } else {
      console.log('Survey Form pressed');
    }
  };

  const handleTeamGroup = () => {
    if (onTeamGroupPress) {
      onTeamGroupPress();
    } else {
      console.log('Team Group pressed');
    }
  };

  const handleLocationTracking = () => {
    if (onLocationTrackingPress) {
      onLocationTrackingPress();
    } else {
      console.log('Location Tracking pressed');
    }
  };

  const handleGamification = () => {
    if (onGamificationPress) {
      onGamificationPress();
    } else {
      console.log('Gamification pressed');
    }
  };

  return (
    <View style={styles.container}>
      {/* Section Title */}
      <Text style={styles.sectionTitle}>Quick Action</Text>
      
      {/* Actions Grid */}
      <View style={styles.actionsGrid}>
        {/* Row 1 */}
        <View style={styles.actionRow}>
          <QuickActionButton
            title="My Territory"
            svgIcon="map"
            iconColor="#6056B6" // Purple color for map icon
            backgroundColor="#D1CEEA" // Purple
            onPress={handleMyTerritory}
          />

          <QuickActionButton
            title="Deliver Book"
            svgIcon="book"
            iconColor="white" // White color for book icon
            backgroundColor="#EEABB1" // Pink
            onPress={handleDeliverBook}
          />
        </View>

        {/* Row 2 */}
        <View style={styles.actionRow}>
          <QuickActionButton
            title="Survey Form"
            svgIcon="form"
            iconColor="white" // White color for form icon
            backgroundColor="#EDDEBC" // Gold/Yellow
            onPress={handleSurveyForm}
          />

          <QuickActionButton
            title="Team Group"
            svgIcon="message"
            iconColor="white" // White color for message icon
            backgroundColor="#5DB2CE" // Light Blue
            onPress={handleTeamGroup}
          />
        </View>

        {/* Row 3 - New Phase 1 Features */}
        <View style={styles.actionRow}>
          <QuickActionButton
            title="GPS Tracking"
            svgIcon="location"
            iconColor="white"
            backgroundColor="#4CAF50" // Green
            onPress={handleLocationTracking}
          />

          <QuickActionButton
            title="Achievements"
            svgIcon="gamification"
            iconColor="white"
            backgroundColor="#FF9800" // Orange
            onPress={handleGamification}
          />
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.lg,
    backgroundColor: 'rgba(255, 255, 255, 0.50)',
    borderRadius: 15,
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: '#000000',
    marginBottom: SPACING.xl,
  },
  actionsGrid: {
    gap: SPACING.lg,
  },
  actionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: SPACING.lg,
  },
  actionButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: SPACING.lg,
  },
  iconContainer: {
    width: 80,
    height: 80,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  actionTitle: {
    fontSize: TYPOGRAPHY.sizes.base,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: '#000000',
    textAlign: 'center',
    lineHeight: 20,
  },
});

export default QuickActions;
