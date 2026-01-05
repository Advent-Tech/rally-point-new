import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  SafeAreaView,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { COLORS, SPACING } from '../constants/Colors';
import ActionButtonsPanel from '../components/ActionButtonsPanel';

interface TerritoryScreenProps {
  navigation: any;
}

const TerritoryScreen: React.FC<TerritoryScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [isMinistryActive, setIsMinistryActive] = useState(false);

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <MaterialIcons name="arrow-back" size={24} color={COLORS.text.primary} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Territory Management</Text>
        </View>

        <View style={styles.content}>
          <Text style={styles.welcomeText}>Territory Screen</Text>
          <Text style={styles.subtitle}>Manage your ministry territories</Text>

          <TouchableOpacity
            style={styles.actionButton}
            onPress={() => setIsMinistryActive(!isMinistryActive)}
          >
            <Text style={styles.actionButtonText}>
              {isMinistryActive ? 'Stop Ministry' : 'Start Ministry'}
            </Text>
          </TouchableOpacity>

          <View style={styles.testBox}>
            <Text style={styles.testText}>Territory Section 1</Text>
          </View>
          <View style={styles.testBox}>
            <Text style={styles.testText}>Territory Section 2</Text>
          </View>
          <View style={styles.testBox}>
            <Text style={styles.testText}>Territory Section 3</Text>
          </View>
          <View style={styles.testBox}>
            <Text style={styles.testText}>Territory Section 4</Text>
          </View>
          <View style={styles.testBox}>
            <Text style={styles.testText}>Territory Section 5 - Scroll to see this!</Text>
          </View>
        </View>

        <ActionButtonsPanel
          onStartMinistry={() => setIsMinistryActive(true)}
          onStopMinistry={() => setIsMinistryActive(false)}
          isMinistryActive={isMinistryActive}
        />
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.secondary,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: SPACING.lg,
    paddingBottom: SPACING['4xl'],
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: COLORS.text.primary,
    marginLeft: SPACING.md,
  },
  content: {
    flex: 1,
  },
  welcomeText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  subtitle: {
    fontSize: 16,
    color: COLORS.text.secondary,
    marginBottom: SPACING.lg,
  },
  actionButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  actionButtonText: {
    color: COLORS.white,
    fontSize: 16,
    fontWeight: 'bold',
  },
  testBox: {
    height: 120,
    backgroundColor: '#fff',
    borderRadius: 8,
    marginBottom: SPACING.md,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  testText: {
    fontSize: 16,
    color: COLORS.text.primary,
  },
});

export default TerritoryScreen;
