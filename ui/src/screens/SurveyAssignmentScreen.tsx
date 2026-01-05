import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  FlatList,
  Alert,
  StyleSheet,
  SafeAreaView,
  TextInput
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { Header } from '../components';
import { SurveyService } from '../services/SurveyService';
import { useSurveyNotifications } from '../hooks/useNotifications';
import {
  Survey,
  SurveyAssignment
} from '../types/survey';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface SurveyAssignmentScreenProps {
  navigation: any;
  route: {
    params: {
      surveyId: string;
    };
  };
}

interface Worker {
  uid: string;
  name: string;
  email: string;
  territory?: string;
  role: string;
  displayName: string;
}

const SurveyAssignmentScreen: React.FC<SurveyAssignmentScreenProps> = ({ navigation, route }) => {
  const { surveyId } = route.params;
  const { user } = useAuth();
  const { notifyAssignment } = useSurveyNotifications();
  
  const [survey, setSurvey] = useState<Survey | null>(null);
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [selectedWorkers, setSelectedWorkers] = useState<string[]>([]);
  const [instructions, setInstructions] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [loading, setLoading] = useState(true);
  const [assigning, setAssigning] = useState(false);

  useEffect(() => {
    loadSurvey();
    loadWorkers();
  }, [surveyId]);

  const loadSurvey = async () => {
    try {
      const surveyData = await SurveyService.getSurvey(surveyId);
      if (surveyData) {
        setSurvey(surveyData);
      } else {
        Alert.alert('Error', 'Survey not found', [
          { text: 'OK', onPress: () => navigation.goBack() }
        ]);
      }
    } catch (error) {
      console.error('Error loading survey:', error);
      Alert.alert('Error', 'Failed to load survey');
    } finally {
      setLoading(false);
    }
  };

  const loadWorkers = async () => {
    try {
      // Workers would be loaded through a service layer
      const workersData: Worker[] = [];

      // If no workers found, create some sample workers for demo
      if (workersData.length === 0) {
        console.log('No workers found, using sample data');
        const sampleWorkers: Worker[] = [
          { uid: 'sample1', name: 'John Smith', email: 'john@example.com', territory: 'North District', role: 'worker', displayName: 'John Smith' },
          { uid: 'sample2', name: 'Sarah Johnson', email: 'sarah@example.com', territory: 'South District', role: 'worker', displayName: 'Sarah Johnson' },
          { uid: 'sample3', name: 'Mike Davis', email: 'mike@example.com', territory: 'East District', role: 'worker', displayName: 'Mike Davis' },
          { uid: 'sample4', name: 'Lisa Wilson', email: 'lisa@example.com', territory: 'West District', role: 'team_leader', displayName: 'Lisa Wilson' },
        ];
        setWorkers(sampleWorkers);
      } else {
        setWorkers(workersData);
      }

      console.log('✅ Workers loaded:', workersData.length);
    } catch (error) {
      console.error('❌ Error loading workers:', error);
      // Fallback to sample data on error
      const fallbackWorkers: Worker[] = [
        { uid: 'fallback1', name: 'John Smith', email: 'john@example.com', territory: 'North District', role: 'worker', displayName: 'John Smith' },
        { uid: 'fallback2', name: 'Sarah Johnson', email: 'sarah@example.com', territory: 'South District', role: 'worker', displayName: 'Sarah Johnson' },
      ];
      setWorkers(fallbackWorkers);
    }
  };

  const toggleWorkerSelection = (workerId: string) => {
    setSelectedWorkers(prev => 
      prev.includes(workerId) 
        ? prev.filter(id => id !== workerId)
        : [...prev, workerId]
    );
  };

  const assignSurvey = async () => {
    if (!survey || !user) return;

    if (selectedWorkers.length === 0) {
      Alert.alert('Error', 'Please select at least one worker');
      return;
    }

    setAssigning(true);
    try {
      // Create assignment
      const assignedTo = selectedWorkers.map(workerId => {
        const worker = workers.find(w => w.uid === workerId);
        return {
          uid: workerId,
          name: worker?.name || 'Unknown',
          email: worker?.email || ''
        };
      });

      const assignment: Omit<SurveyAssignment, 'id'> = {
        surveyId: survey.id,
        assignedTo,
        assignedBy: {
          uid: user.uid,
          name: user.displayName || user.email.split('@')[0],
          email: user.email
        },
        assignedAt: new Date(),
        ...(dueDate && { dueDate: new Date(dueDate) }),
        ...(instructions.trim() && { instructions: instructions.trim() }),
        isActive: true
      };

      await SurveyService.createAssignment(assignment);

      // Send notifications to assigned workers
      await notifyAssignment(
        selectedWorkers,
        survey.title,
        survey.id,
        assignment.assignedBy.name
      );

      Alert.alert(
        'Success', 
        `Survey assigned to ${selectedWorkers.length} worker${selectedWorkers.length > 1 ? 's' : ''}!`,
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    } catch (error) {
      console.error('Error assigning survey:', error);
      Alert.alert('Error', 'Failed to assign survey. Please try again.');
    } finally {
      setAssigning(false);
    }
  };

  const renderWorkerItem = ({ item: worker }: { item: Worker }) => {
    const isSelected = selectedWorkers.includes(worker.uid);

    return (
      <TouchableOpacity
        style={[styles.workerCard, isSelected && styles.selectedWorkerCard]}
        onPress={() => toggleWorkerSelection(worker.uid)}
        activeOpacity={0.7}
      >
        <View style={styles.workerInfo}>
          <View style={styles.workerAvatar}>
            <Text style={styles.workerInitials}>
              {worker.name.split(' ').map(n => n[0]).join('')}
            </Text>
          </View>
          <View style={styles.workerDetails}>
            <Text style={styles.workerName}>{worker.name}</Text>
            <Text style={styles.workerEmail}>{worker.email}</Text>
            <Text style={styles.workerTerritory}>{worker.territory}</Text>
          </View>
        </View>
        <View style={[styles.checkbox, isSelected && styles.checkedBox]}>
          {isSelected && (
            <MaterialIcons name="check" size={16} color={COLORS.background.primary} />
          )}
        </View>
      </TouchableOpacity>
    );
  };

  if (loading || !survey) {
    return (
      <SafeAreaView style={styles.container}>
        <Header
          title="Loading..."
          showBackButton
          onBackPress={() => navigation.goBack()}
        />
        <View style={styles.loadingContainer}>
          <MaterialIcons name="hourglass-empty" size={48} color={COLORS.text.secondary} />
          <Text style={styles.loadingText}>Loading survey...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title="Assign Survey"
        showBackButton
        onBackPress={() => navigation.goBack()}
      />

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Survey Info */}
        <View style={styles.surveyInfo}>
          <Text style={styles.surveyTitle}>{survey.title}</Text>
          <Text style={styles.surveyDescription}>{survey.description}</Text>
          <Text style={styles.questionCount}>
            {survey.questions.length} question{survey.questions.length !== 1 ? 's' : ''}
          </Text>
        </View>

        {/* Assignment Details */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Assignment Details</Text>
          
          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Instructions (Optional)</Text>
            <TextInput
              style={styles.textArea}
              value={instructions}
              onChangeText={setInstructions}
              placeholder="Add specific instructions for workers..."
              placeholderTextColor={COLORS.text.placeholder}
              multiline
              numberOfLines={3}
            />
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Due Date (Optional)</Text>
            <TextInput
              style={styles.textInput}
              value={dueDate}
              onChangeText={setDueDate}
              placeholder="YYYY-MM-DD"
              placeholderTextColor={COLORS.text.placeholder}
            />
          </View>
        </View>

        {/* Worker Selection */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>
            Select Workers ({selectedWorkers.length} selected)
          </Text>
          
          <FlatList
            data={workers}
            keyExtractor={(item) => item.uid}
            renderItem={renderWorkerItem}
            scrollEnabled={false}
            showsVerticalScrollIndicator={false}
          />
        </View>

        {/* Assign Button */}
        <TouchableOpacity
          style={[styles.assignButton, assigning && styles.disabledButton]}
          onPress={assignSurvey}
          disabled={assigning || selectedWorkers.length === 0}
        >
          <Text style={styles.assignButtonText}>
            {assigning ? 'Assigning...' : `Assign to ${selectedWorkers.length} Worker${selectedWorkers.length !== 1 ? 's' : ''}`}
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  content: {
    flex: 1,
    padding: SPACING.md,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  loadingText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  surveyInfo: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  surveyTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  surveyDescription: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
    marginBottom: SPACING.sm,
  },
  questionCount: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  section: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  inputGroup: {
    marginBottom: SPACING.md,
  },
  inputLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  textInput: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.surface,
    minHeight: 48,
  },
  textArea: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.surface,
    minHeight: 80,
    textAlignVertical: 'top',
  },
  workerCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.light,
  },
  selectedWorkerCard: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.primary + '10',
  },
  workerInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  workerAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  workerInitials: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.background.primary,
  },
  workerDetails: {
    flex: 1,
  },
  workerName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  workerEmail: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  workerTerritory: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 4,
    borderWidth: 2,
    borderColor: COLORS.border.default,
    justifyContent: 'center',
    alignItems: 'center',
  },
  checkedBox: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  assignButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.lg,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    marginVertical: SPACING.xl,
    ...SHADOWS.sm,
  },
  assignButtonText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
  disabledButton: {
    opacity: 0.6,
  },
});

export default SurveyAssignmentScreen;
