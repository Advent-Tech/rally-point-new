import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated, Platform } from 'react-native';
import { ManagedUser } from '../../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';

interface TypingIndicatorProps {
  typingUsers: string[];
  teamMembers: ManagedUser[];
}

const TypingIndicator: React.FC<TypingIndicatorProps> = ({
  typingUsers,
  teamMembers
}) => {
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const scaleAnim = useRef(new Animated.Value(0.8)).current;
  const dotAnimations = useRef([
    new Animated.Value(0),
    new Animated.Value(0),
    new Animated.Value(0),
  ]).current;

  useEffect(() => {
    if (typingUsers.length > 0) {
      // Fade in animation
      Animated.parallel([
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration: Platform.OS === 'web' ? 100 : 200, // Faster on web
          useNativeDriver: Platform.OS !== 'web', // Disable native driver on web
        }),
        Animated.spring(scaleAnim, {
          toValue: 1,
          tension: Platform.OS === 'web' ? 200 : 100, // Less bouncy on web
          friction: Platform.OS === 'web' ? 12 : 8,
          useNativeDriver: Platform.OS !== 'web',
        }),
      ]).start();

      // Start dot animation only on mobile for better web performance
      if (Platform.OS !== 'web') {
        startDotAnimation();
      }
    } else {
      // Fade out animation
      Animated.parallel([
        Animated.timing(fadeAnim, {
          toValue: 0,
          duration: Platform.OS === 'web' ? 100 : 200,
          useNativeDriver: Platform.OS !== 'web',
        }),
        Animated.timing(scaleAnim, {
          toValue: 0.8,
          duration: Platform.OS === 'web' ? 100 : 200,
          useNativeDriver: Platform.OS !== 'web',
        }),
      ]).start();
    }
  }, [typingUsers.length]);

  const startDotAnimation = () => {
    const animateDot = (dotAnim: Animated.Value, delay: number) => {
      return Animated.loop(
        Animated.sequence([
          Animated.delay(delay),
          Animated.timing(dotAnim, {
            toValue: 1,
            duration: 400,
            useNativeDriver: Platform.OS !== 'web',
          }),
          Animated.timing(dotAnim, {
            toValue: 0,
            duration: 400,
            useNativeDriver: Platform.OS !== 'web',
          }),
        ])
      );
    };

    Animated.parallel([
      animateDot(dotAnimations[0], 0),
      animateDot(dotAnimations[1], 200),
      animateDot(dotAnimations[2], 400),
    ]).start();
  };

  const getTypingText = () => {
    if (typingUsers.length === 0) return '';

    const typingNames = typingUsers.map(userId => {
      const user = teamMembers.find(member => member.uid === userId);
      return user?.displayName || user?.email.split('@')[0] || 'Someone';
    });

    if (typingNames.length === 1) {
      return `${typingNames[0]} is typing`;
    } else if (typingNames.length === 2) {
      return `${typingNames[0]} and ${typingNames[1]} are typing`;
    } else {
      return `${typingNames[0]} and ${typingNames.length - 1} others are typing`;
    }
  };

  if (typingUsers.length === 0) return null;

  return (
    <Animated.View
      style={[
        styles.container,
        {
          opacity: fadeAnim,
          transform: [{ scale: scaleAnim }],
        },
      ]}
    >
      <View style={styles.bubble}>
        <Text style={styles.typingText}>{getTypingText()}</Text>
        <View style={styles.dotsContainer}>
          {Platform.OS === 'web' ? (
            // Static dots for web to prevent vibrating
            <>
              <View style={[styles.dot, styles.staticDot]} />
              <View style={[styles.dot, styles.staticDot]} />
              <View style={[styles.dot, styles.staticDot]} />
            </>
          ) : (
            // Animated dots for mobile
            dotAnimations.map((dotAnim, index) => (
              <Animated.View
                key={index}
                style={[
                  styles.dot,
                  {
                    opacity: dotAnim,
                  },
                ]}
              />
            ))
          )}
        </View>
      </View>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    alignItems: 'flex-start',
  },
  bubble: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.lg,
    borderBottomLeftRadius: RADIUS.sm,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border.light,
    maxWidth: '80%',
  },
  typingText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontStyle: 'italic',
    marginRight: SPACING.sm,
  },
  dotsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  dot: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: COLORS.text.secondary,
    marginHorizontal: 1,
  },
  staticDot: {
    opacity: 0.6, // Static opacity for web to prevent animation issues
  },
});

export default TypingIndicator;
