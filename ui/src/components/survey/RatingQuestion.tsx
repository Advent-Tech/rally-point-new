import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { RatingQuestion as RatingQuestionType } from '../../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS } from '../../constants/Colors';

interface RatingQuestionProps {
  question: RatingQuestionType;
  value: number;
  onChange: (value: number) => void;
  error?: string;
  disabled?: boolean;
}

const RatingQuestion: React.FC<RatingQuestionProps> = ({
  question,
  value,
  onChange,
  error,
  disabled = false
}) => {
  const scale = question.scale || 5;
  const ratings = Array.from({ length: scale }, (_, i) => i + 1);

  const handleRatingPress = (rating: number) => {
    if (!disabled) {
      onChange(rating);
    }
  };

  const getStarIcon = (rating: number) => {
    if (value >= rating) {
      return 'star';
    } else if (value >= rating - 0.5) {
      return 'star-half';
    } else {
      return 'star-border';
    }
  };

  const getStarColor = (rating: number) => {
    if (disabled) {
      return COLORS.text.disabled;
    }
    return value >= rating ? COLORS.secondary : COLORS.text.secondary;
  };

  return (
    <View style={styles.container}>
      {/* Labels */}
      {(question.minLabel || question.maxLabel) && (
        <View style={styles.labelsContainer}>
          {question.minLabel && (
            <Text style={styles.scaleLabel}>{question.minLabel}</Text>
          )}
          <View style={styles.spacer} />
          {question.maxLabel && (
            <Text style={styles.scaleLabel}>{question.maxLabel}</Text>
          )}
        </View>
      )}

      {/* Star Rating */}
      <View style={styles.starsContainer}>
        {ratings.map((rating) => (
          <TouchableOpacity
            key={rating}
            style={[
              styles.starButton,
              disabled && styles.disabledStar
            ]}
            onPress={() => handleRatingPress(rating)}
            activeOpacity={0.7}
            disabled={disabled}
          >
            <MaterialIcons
              name={getStarIcon(rating)}
              size={32}
              color={getStarColor(rating)}
            />
          </TouchableOpacity>
        ))}
      </View>

      {/* Numeric Rating Display */}
      <View style={styles.ratingDisplay}>
        <Text style={[
          styles.ratingText,
          disabled && styles.disabledText
        ]}>
          {value > 0 ? `${value} of ${scale}` : 'No rating selected'}
        </Text>
      </View>

      {/* Numeric Scale Alternative */}
      <View style={styles.numericContainer}>
        <Text style={styles.numericLabel}>Or select a number:</Text>
        <View style={styles.numbersContainer}>
          {ratings.map((rating) => (
            <TouchableOpacity
              key={rating}
              style={[
                styles.numberButton,
                value === rating && styles.selectedNumber,
                disabled && styles.disabledNumber
              ]}
              onPress={() => handleRatingPress(rating)}
              activeOpacity={0.7}
              disabled={disabled}
            >
              <Text style={[
                styles.numberText,
                value === rating && styles.selectedNumberText,
                disabled && styles.disabledText
              ]}>
                {rating}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
  },
  labelsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    marginBottom: SPACING.sm,
  },
  scaleLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  spacer: {
    flex: 1,
  },
  starsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: SPACING.md,
    paddingHorizontal: SPACING.sm,
  },
  starButton: {
    padding: SPACING.xs,
    marginHorizontal: 2,
  },
  disabledStar: {
    opacity: 0.6,
  },
  ratingDisplay: {
    marginBottom: SPACING.lg,
  },
  ratingText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
    textAlign: 'center',
  },
  disabledText: {
    color: COLORS.text.disabled,
  },
  numericContainer: {
    width: '100%',
    alignItems: 'center',
  },
  numericLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
  },
  numbersContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    flexWrap: 'wrap',
  },
  numberButton: {
    width: 40,
    height: 40,
    borderRadius: RADIUS.full,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    backgroundColor: COLORS.background.surface,
    justifyContent: 'center',
    alignItems: 'center',
    margin: SPACING.xs,
  },
  selectedNumber: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.primary,
  },
  disabledNumber: {
    backgroundColor: COLORS.background.disabled,
    opacity: 0.6,
  },
  numberText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  selectedNumberText: {
    color: COLORS.background.surface,
  },
});

export default RatingQuestion;
