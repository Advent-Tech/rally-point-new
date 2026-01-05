import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  Alert,
  Linking
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { ProfileService } from '../services/ProfileService';
import { Header } from '../components';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { FAQItem, TrainingResource } from '../types/profile';

interface HelpSupportScreenProps {
  navigation: any;
}

const HelpSupportScreen: React.FC<HelpSupportScreenProps> = ({ navigation }) => {
  const [faqItems, setFaqItems] = useState<FAQItem[]>([]);
  const [trainingResources, setTrainingResources] = useState<TrainingResource[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedFAQ, setExpandedFAQ] = useState<string | null>(null);

  useEffect(() => {
    loadHelpData();
  }, []);

  const loadHelpData = async () => {
    try {
      setLoading(true);
      
      // Load FAQ and training resources
      const [faqData, trainingData] = await Promise.all([
        ProfileService.getFAQItems(),
        ProfileService.getTrainingResources()
      ]);

      setFaqItems(faqData);
      setTrainingResources(trainingData);
    } catch (error) {
      console.error('Error loading help data:', error);
      // Set mock data for demo purposes
      setFaqItems(mockFAQData);
      setTrainingResources(mockTrainingData);
    } finally {
      setLoading(false);
    }
  };

  const handleContactSupport = () => {
    Alert.alert(
      'Contact Support',
      'How would you like to contact support?',
      [
        {
          text: 'Email',
          onPress: () => Linking.openURL('mailto:support@rallypoint.app?subject=Support Request')
        },
        {
          text: 'Phone',
          onPress: () => Linking.openURL('tel:+1-800-RALLY-PT')
        },
        { text: 'Cancel', style: 'cancel' }
      ]
    );
  };

  const handleReportIssue = () => {
    navigation.navigate('ReportIssue');
  };

  const handleTrainingResource = (resource: TrainingResource) => {
    if (resource.url) {
      Linking.openURL(resource.url);
    }
  };

  const toggleFAQ = (id: string) => {
    setExpandedFAQ(expandedFAQ === id ? null : id);
  };

  const renderQuickActions = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Quick Actions</Text>
      
      <TouchableOpacity style={styles.actionItem} onPress={handleContactSupport}>
        <MaterialIcons name="support-agent" size={24} color={COLORS.primary} />
        <Text style={styles.actionText}>Contact Support</Text>
        <MaterialIcons name="chevron-right" size={24} color={COLORS.darkGray} />
      </TouchableOpacity>
      
      <TouchableOpacity style={styles.actionItem} onPress={handleReportIssue}>
        <MaterialIcons name="bug-report" size={24} color={COLORS.primary} />
        <Text style={styles.actionText}>Report an Issue</Text>
        <MaterialIcons name="chevron-right" size={24} color={COLORS.darkGray} />
      </TouchableOpacity>
    </View>
  );

  const renderTrainingResources = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Training Resources</Text>
      
      {trainingResources.map((resource) => (
        <TouchableOpacity
          key={resource.id}
          style={styles.resourceItem}
          onPress={() => handleTrainingResource(resource)}
        >
          <View style={styles.resourceIcon}>
            <MaterialIcons
              name={
                resource.type === 'video' ? 'play-circle-filled' :
                resource.type === 'document' ? 'description' :
                resource.type === 'quiz' ? 'quiz' : 'school'
              }
              size={24}
              color={COLORS.secondary}
            />
          </View>
          <View style={styles.resourceContent}>
            <Text style={styles.resourceTitle}>{resource.title}</Text>
            <Text style={styles.resourceDescription}>{resource.description}</Text>
            {resource.duration && (
              <Text style={styles.resourceDuration}>{resource.duration} minutes</Text>
            )}
          </View>
          <MaterialIcons name="open-in-new" size={20} color={COLORS.darkGray} />
        </TouchableOpacity>
      ))}
    </View>
  );

  const renderFAQ = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Frequently Asked Questions</Text>
      
      {faqItems.map((item) => (
        <View key={item.id} style={styles.faqItem}>
          <TouchableOpacity
            style={styles.faqQuestion}
            onPress={() => toggleFAQ(item.id)}
          >
            <Text style={styles.faqQuestionText}>{item.question}</Text>
            <MaterialIcons
              name={expandedFAQ === item.id ? 'expand-less' : 'expand-more'}
              size={24}
              color={COLORS.primary}
            />
          </TouchableOpacity>
          
          {expandedFAQ === item.id && (
            <View style={styles.faqAnswer}>
              <Text style={styles.faqAnswerText}>{item.answer}</Text>
            </View>
          )}
        </View>
      ))}
    </View>
  );

  const renderAppInfo = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>App Information</Text>
      
      <View style={styles.infoItem}>
        <Text style={styles.infoLabel}>Version</Text>
        <Text style={styles.infoValue}>1.0.0</Text>
      </View>
      
      <View style={styles.infoItem}>
        <Text style={styles.infoLabel}>Build</Text>
        <Text style={styles.infoValue}>2024.01.15</Text>
      </View>
      
      <View style={styles.infoItem}>
        <Text style={styles.infoLabel}>Support</Text>
        <Text style={styles.infoValue}>support@rallypoint.app</Text>
      </View>
    </View>
  );

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
        <Header title="Help & Support" showBackButton onBackPress={() => navigation.goBack()} />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading help content...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
      <Header title="Help & Support" showBackButton onBackPress={() => navigation.goBack()} />
      
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {renderQuickActions()}
        {renderTrainingResources()}
        {renderFAQ()}
        {renderAppInfo()}
      </ScrollView>
    </SafeAreaView>
  );
};

// Mock data for demo purposes
const mockFAQData: FAQItem[] = [
  {
    id: '1',
    question: 'How do I start tracking my ministry work?',
    answer: 'Tap the "Start Ministry" button on your dashboard. Make sure location permissions are enabled so your work can be tracked accurately.',
    category: 'tracking'
  },
  {
    id: '2',
    question: 'How do I complete a survey?',
    answer: 'Go to the Surveys section, select an assigned survey, and fill out all required fields. Your responses will be saved automatically.',
    category: 'surveys'
  },
  {
    id: '3',
    question: 'What should I do if I encounter an emergency?',
    answer: 'Use the Emergency SOS button in your profile. This will immediately alert your team leaders and emergency contacts with your location.',
    category: 'safety'
  },
  {
    id: '4',
    question: 'How do I view my assigned territory?',
    answer: 'Navigate to "My Territory" from the main menu. You can see your assigned areas and track your progress within them.',
    category: 'territory'
  }
];

const mockTrainingData: TrainingResource[] = [
  {
    id: '1',
    title: 'Getting Started with Rally Point',
    description: 'Learn the basics of using the Rally Point app for ministry work',
    type: 'video',
    url: 'https://example.com/training/getting-started',
    duration: 15,
    category: 'basics',
    difficulty: 'beginner',
    isRequired: true
  },
  {
    id: '2',
    title: 'Safety Guidelines for Field Work',
    description: 'Important safety protocols and emergency procedures',
    type: 'document',
    url: 'https://example.com/training/safety-guidelines',
    category: 'safety',
    difficulty: 'beginner',
    isRequired: true
  },
  {
    id: '3',
    title: 'Advanced Survey Techniques',
    description: 'Tips for conducting effective surveys and engaging with the community',
    type: 'interactive',
    url: 'https://example.com/training/survey-techniques',
    duration: 30,
    category: 'surveys',
    difficulty: 'intermediate',
    isRequired: false
  }
];

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: SPACING.xl,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.darkGray,
  },
  section: {
    backgroundColor: COLORS.white,
    marginBottom: SPACING.md,
    ...SHADOWS.small,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h4,
    color: COLORS.primary,
    fontWeight: 'bold',
    padding: SPACING.lg,
    paddingBottom: SPACING.md,
  },
  actionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderFlat,
  },
  actionText: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    flex: 1,
    marginLeft: SPACING.md,
  },
  resourceItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderFlat,
  },
  resourceIcon: {
    marginRight: SPACING.md,
  },
  resourceContent: {
    flex: 1,
  },
  resourceTitle: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    fontWeight: '500',
    marginBottom: 4,
  },
  resourceDescription: {
    ...TYPOGRAPHY.caption,
    color: COLORS.darkGray,
    marginBottom: 2,
  },
  resourceDuration: {
    ...TYPOGRAPHY.caption,
    color: COLORS.secondary,
    fontWeight: '500',
  },
  faqItem: {
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderFlat,
  },
  faqQuestion: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
  },
  faqQuestionText: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    flex: 1,
    fontWeight: '500',
  },
  faqAnswer: {
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.md,
    backgroundColor: COLORS.backgroundTertiary,
  },
  faqAnswerText: {
    ...TYPOGRAPHY.body,
    color: COLORS.darkGray,
    lineHeight: 20,
  },
  infoItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderFlat,
  },
  infoLabel: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    fontWeight: '500',
  },
  infoValue: {
    ...TYPOGRAPHY.body,
    color: COLORS.darkGray,
  },
});

export default HelpSupportScreen;
