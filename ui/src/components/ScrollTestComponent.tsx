import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Platform, ScrollView } from 'react-native';
import { COLORS, SPACING, TYPOGRAPHY } from '../constants/Colors';

/**
 * ScrollTestComponent
 * A component to test and verify scrolling functionality on web
 */
const ScrollTestComponent: React.FC = () => {
  const [scrollPosition, setScrollPosition] = useState(0);
  const [isScrollable, setIsScrollable] = useState(false);

  useEffect(() => {
    if (Platform.OS === 'web') {
      // Test if scrolling is working
      const testScroll = () => {
        const scrollableElement = document.querySelector('.scrollable-content');
        if (scrollableElement) {
          setIsScrollable(true);
          console.log('✅ Scrollable element found');
        } else {
          console.log('❌ Scrollable element not found');
        }
      };

      // Run test after a short delay to ensure DOM is ready
      setTimeout(testScroll, 1000);
    }
  }, []);

  const handleScroll = (event: any) => {
    if (Platform.OS === 'web') {
      setScrollPosition(event.nativeEvent.contentOffset.y);
    }
  };

  if (Platform.OS !== 'web') {
    return null; // Only show on web
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>🔧 Web Scroll Test</Text>
      <Text style={styles.status}>
        Status: {isScrollable ? '✅ Scrolling Enabled' : '❌ Scrolling Disabled'}
      </Text>
      <Text style={styles.position}>
        Scroll Position: {Math.round(scrollPosition)}px
      </Text>
      
      {/* Test content to ensure there's enough to scroll */}
      <View style={styles.testContent}>
        {Array.from({ length: 20 }, (_, index) => (
          <View key={index} style={styles.testItem}>
            <Text style={styles.testText}>Test Item {index + 1}</Text>
          </View>
        ))}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: SPACING.md,
    backgroundColor: COLORS.warning + '20',
    borderRadius: 8,
    margin: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.warning,
  },
  title: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.textPrimary,
    marginBottom: SPACING.sm,
  },
  status: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    marginBottom: SPACING.xs,
  },
  position: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textSecondary,
    marginBottom: SPACING.md,
  },
  testContent: {
    marginTop: SPACING.md,
  },
  testItem: {
    padding: SPACING.sm,
    backgroundColor: COLORS.white,
    marginBottom: SPACING.xs,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  testText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.textPrimary,
  },
});

export default ScrollTestComponent;
