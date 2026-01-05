import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';
import { TypingIndicator as TypingIndicatorType } from '../../services/MessagingService';

interface TypingIndicatorProps {
  typingUsers: TypingIndicatorType[];
  currentUserId: string;
}

const TypingIndicator: React.FC<TypingIndicatorProps> = ({
  typingUsers,
  currentUserId,
}) => {
  const animatedValue = useRef(new Animated.Value(0)).current;

  // Filter out current user from typing indicators
  const otherUsersTyping = typingUsers.filter(user => user.userId !== currentUserId);

  useEffect(() => {
    if (otherUsersTyping.length > 0) {
      // Start animation
      Animated.loop(
        Animated.sequence([
          Animated.timing(animatedValue, {
            toValue: 1,
            duration: 600,
            useNativeDriver: true,
          }),
          Animated.timing(animatedValue, {
            toValue: 0,
            duration: 600,
            useNativeDriver: true,
          }),
        ])
      ).start();
    } else {
      // Stop animation
      animatedValue.setValue(0);
    }
  }, [otherUsersTyping.length, animatedValue]);

  if (otherUsersTyping.length === 0) {
    return null;
  }

  const getTypingText = () => {
    if (otherUsersTyping.length === 1) {
      return `${otherUsersTyping[0].userName} is typing...`;
    } else if (otherUsersTyping.length === 2) {
      return `${otherUsersTyping[0].userName} and ${otherUsersTyping[1].userName} are typing...`;
    } else {
      return `${otherUsersTyping[0].userName} and ${otherUsersTyping.length - 1} others are typing...`;
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.bubble}>
        <View style={styles.dotsContainer}>
          <Animated.View
            style={[
              styles.dot,
              {
                opacity: animatedValue.interpolate({
                  inputRange: [0, 0.33, 0.66, 1],
                  outputRange: [0.3, 1, 0.3, 0.3],
                }),
              },
            ]}
          />
          <Animated.View
            style={[
              styles.dot,
              {
                opacity: animatedValue.interpolate({
                  inputRange: [0, 0.33, 0.66, 1],
                  outputRange: [0.3, 0.3, 1, 0.3],
                }),
              },
            ]}
          />
          <Animated.View
            style={[
              styles.dot,
              {
                opacity: animatedValue.interpolate({
                  inputRange: [0, 0.33, 0.66, 1],
                  outputRange: [0.3, 0.3, 0.3, 1],
                }),
              },
            ]}
          />
        </View>
        <Text style={styles.typingText}>{getTypingText()}</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    alignItems: 'flex-start',
  },
  bubble: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F0F0F0',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    borderBottomLeftRadius: 6,
    maxWidth: '80%',
  },
  dotsContainer: {
    flexDirection: 'row',
    marginRight: 8,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: '#666',
    marginHorizontal: 1,
  },
  typingText: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
  },
});

export default TypingIndicator;
