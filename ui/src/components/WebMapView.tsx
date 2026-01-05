import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING } from '../constants';

interface WebMapViewProps {
  children?: React.ReactNode;
  style?: any;
}

const WebMapView: React.FC<WebMapViewProps> = ({ children, style }) => {
  return (
    <View style={[styles.container, style]}>
      <View style={styles.mapPlaceholder}>
        <Text style={styles.placeholderText}>🗺️</Text>
        <Text style={styles.placeholderTitle}>Map View</Text>
        <Text style={styles.placeholderSubtitle}>
          Map functionality is available on mobile devices
        </Text>
        <Text style={styles.placeholderDescription}>
          GPS tracking and path visualization work on iOS and Android
        </Text>
      </View>
      {children}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  mapPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(59, 130, 246, 0.05)',
    borderRadius: 16,
    borderWidth: 2,
    borderColor: 'rgba(59, 130, 246, 0.2)',
    margin: SPACING.md,
    padding: SPACING.xl,
  },
  placeholderText: {
    fontSize: 64,
    marginBottom: SPACING.md,
  },
  placeholderTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold as any,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  placeholderSubtitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginBottom: SPACING.sm,
  },
  placeholderDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'center',
    opacity: 0.7,
  },
});

export default WebMapView;
