import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING } from '../constants/Colors';

interface MyTerritoryScreenProps {
  navigation: any;
}

const MyTerritoryScreenTemp: React.FC<MyTerritoryScreenProps> = ({ navigation }) => {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <MaterialIcons 
          name="arrow-back" 
          size={24} 
          color={COLORS.text.primary} 
          onPress={() => navigation.goBack()}
          style={styles.backButton}
        />
        <Text style={styles.title}>My Territory</Text>
      </View>
      
      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.placeholderCard}>
          <MaterialIcons name="map" size={64} color={COLORS.secondary} />
          <Text style={styles.placeholderTitle}>Territory Management</Text>
          <Text style={styles.placeholderText}>
            Territory management is being updated to work with the new backend system. 
            This feature will be available soon.
          </Text>
          <Text style={styles.placeholderNote}>
            🚧 Under Development: Migrating from Firebase to PostgreSQL backend
          </Text>
        </View>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    paddingTop: SPACING.xl,
    paddingBottom: SPACING.md,
    backgroundColor: COLORS.background.primary,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  backButton: {
    marginRight: SPACING.md,
    padding: SPACING.xs,
  },
  title: {
    fontSize: 24,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  content: {
    flex: 1,
    padding: SPACING.md,
  },
  placeholderCard: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.xl,
    borderRadius: 12,
    marginTop: SPACING.xl,
  },
  placeholderTitle: {
    fontSize: 20,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  placeholderText: {
    fontSize: 16,
    color: COLORS.text.secondary,
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: SPACING.md,
  },
  placeholderNote: {
    fontSize: 14,
    color: COLORS.primary,
    textAlign: 'center',
    fontStyle: 'italic',
  },
});

export default MyTerritoryScreenTemp;
