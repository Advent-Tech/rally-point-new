/**
 * Voice Pitch Indicator Component
 * Shows animated bars that flicker during audio playback to simulate voice activity
 */

import React, { useEffect, useRef } from 'react';
import { View, Animated, StyleSheet } from 'react-native';

interface VoicePitchIndicatorProps {
  isActive: boolean; // Whether audio is playing
  audioLevel?: number; // Real-time audio level (0-1)
  barCount?: number; // Number of bars to display
  height?: number; // Height of the indicator
  color?: string; // Color of the bars
}

export function VoicePitchIndicator({
  isActive,
  audioLevel = 0,
  barCount = 5,
  height = 30,
  color = '#4CAF50'
}: VoicePitchIndicatorProps) {
  const animatedValues = useRef(
    Array.from({ length: barCount }, () => new Animated.Value(0.2))
  ).current;

  useEffect(() => {
    if (isActive && audioLevel > 0.01) {
      // Use real audio levels when available (only if > 0.01 to avoid noise)
      console.log(`📊 Using real audio level: ${audioLevel.toFixed(3)}`);
      animatedValues.forEach((animatedValue, index) => {
        // Create variation across bars based on audio level
        const variation = (Math.sin(index * 0.5) + 1) * 0.3; // 0-0.6 variation
        const targetLevel = Math.max(0.1, audioLevel * (0.7 + variation));
        
        Animated.timing(animatedValue, {
          toValue: targetLevel,
          duration: 100, // Quick response to real audio
          useNativeDriver: false,
        }).start();
      });
    } else if (isActive) {
      // When active but no real audio levels, show static low bars (no fake animation)
      console.log('📊 No real audio levels - showing static bars');
      animatedValues.forEach(animatedValue => {
        Animated.timing(animatedValue, {
          toValue: 0.2, // Static low level
          duration: 200,
          useNativeDriver: false,
        }).start();
      });
    } else {
      // Reset to low values when not active
      animatedValues.forEach(animatedValue => {
        Animated.timing(animatedValue, {
          toValue: 0.2,
          duration: 200,
          useNativeDriver: false,
        }).start();
      });
    }
  }, [isActive, audioLevel, animatedValues]);

  return (
    <View style={[styles.container, { height }]}>
      {animatedValues.map((animatedValue, index) => (
        <Animated.View
          key={index}
          style={[
            styles.bar,
            {
              backgroundColor: color,
              height: animatedValue.interpolate({
                inputRange: [0, 1],
                outputRange: [2, height],
              }),
              opacity: isActive ? 1 : 0.3,
            },
          ]}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'center',
    paddingHorizontal: 8,
  },
  bar: {
    width: 3,
    marginHorizontal: 1,
    borderRadius: 1.5,
    minHeight: 2,
  },
});
