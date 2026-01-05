import React from 'react';
import { View, Text, ScrollView, StyleSheet, Dimensions } from 'react-native';
import { COLORS, SPACING, TYPOGRAPHY } from '../constants';

const { height } = Dimensions.get('window');

const TestScrollScreen: React.FC = () => {
  return (
    <View style={styles.container}>
      <Text style={styles.header}>SCROLL TEST SCREEN</Text>
      
      <ScrollView 
        style={styles.scrollView}
        contentContainerStyle={styles.contentContainer}
        showsVerticalScrollIndicator={true}
      >
        {/* Generate many items to test scrolling */}
        {Array.from({ length: 50 }, (_, index) => (
          <View key={index} style={styles.item}>
            <Text style={styles.itemText}>Item {index + 1}</Text>
            <Text style={styles.itemSubtext}>This is a test item to check scrolling functionality</Text>
          </View>
        ))}
      </ScrollView>
      
      {/* Test Bottom Navigation */}
      <View style={styles.bottomNav}>
        <Text style={styles.bottomNavText}>BOTTOM NAVIGATION TEST</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  header: {
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    padding: 20,
    backgroundColor: COLORS.primary,
    color: COLORS.white,
  },
  scrollView: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  contentContainer: {
    padding: SPACING.lg,
    paddingBottom: 100, // Space for bottom nav
  },
  item: {
    backgroundColor: COLORS.white,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderRadius: 8,
    shadowColor: COLORS.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  itemText: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.textPrimary,
    marginBottom: 4,
  },
  itemSubtext: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
  },
  bottomNav: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 80,
    backgroundColor: COLORS.secondary,
    justifyContent: 'center',
    alignItems: 'center',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  bottomNavText: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.bold,
  },
});

export default TestScrollScreen;
