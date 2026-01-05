import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Alert,
  StyleSheet,
  SafeAreaView,
  Modal,
  FlatList
} from 'react-native';
import { MaterialIcons, FontAwesome } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { Header } from '../components';
import { SurveyQuestion } from '../components/survey';
import { SurveyService } from '../services/SurveyService';
import { UserManagementService } from '../services/UserManagementService';
import {
  Survey,
  AnyQuestion,
  QuestionType,
  SurveyBuilderState,
  SurveyTemplate
} from '../types/survey';
import { Team } from '../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface SurveyBuilderScreenProps {
  navigation: any;
}

const QUESTION_TYPES: { type: QuestionType; label: string; icon: string; description: string }[] = [
  { type: 'text', label: 'Short Text', icon: 'text-fields', description: 'Single line text input' },
  { type: 'textarea', label: 'Long Text', icon: 'notes', description: 'Multi-line text input' },
  { type: 'number', label: 'Number', icon: 'pin', description: 'Numeric input with validation' },
  { type: 'email', label: 'Email', icon: 'email', description: 'Email address input' },
  { type: 'phone', label: 'Phone', icon: 'phone', description: 'Phone number input' },
  { type: 'radio', label: 'Multiple Choice', icon: 'radio-button-checked', description: 'Select one option' },
  { type: 'checkbox', label: 'Checkboxes', icon: 'check-box', description: 'Select multiple options' },
  { type: 'dropdown', label: 'Dropdown', icon: 'arrow-drop-down', description: 'Select from dropdown list' },
  { type: 'rating', label: 'Rating Scale', icon: 'star', description: 'Star or numeric rating' },
  { type: 'yes_no', label: 'Yes/No', icon: 'help', description: 'Simple yes or no question' },
];

const SurveyBuilderScreen: React.FC<SurveyBuilderScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [builderState, setBuilderState] = useState<SurveyBuilderState>({
    survey: {
      title: '',
      description: '',
      questions: [],
      isActive: true,
      tags: []
    },
    currentQuestion: undefined,
    isEditing: false,
    isDirty: false,
    validationErrors: {}
  });

  const [showQuestionTypes, setShowQuestionTypes] = useState(false);
  const [showPreview, setShowPreview] = useState(false);
  const [showTemplates, setShowTemplates] = useState(false);
  const [templates, setTemplates] = useState<SurveyTemplate[]>([]);
  const [loading, setLoading] = useState(false);

  // Team assignment state
  const [teams, setTeams] = useState<Team[]>([]);
  const [selectedTeamIds, setSelectedTeamIds] = useState<string[]>([]);
  const [showTeamSelector, setShowTeamSelector] = useState(false);

  useEffect(() => {
    loadTemplates();
    loadTeams();
  }, []);

  const loadTemplates = async () => {
    try {
      // In a real implementation, you would load templates from Firebase
      const mockTemplates: SurveyTemplate[] = [
        {
          id: '1',
          name: 'Community Feedback',
          description: 'Basic community feedback survey',
          category: 'Community',
          tags: ['feedback', 'community'],
          isPublic: true,
          createdBy: 'system',
          usageCount: 45,
          questions: [
            {
              type: 'text',
              label: 'What is your name?',
              required: true,
              order: 1
            },
            {
              type: 'radio',
              label: 'Do you read the Bible?',
              options: ['Yes', 'No', 'Sometimes'],
              required: true,
              order: 2
            },
            {
              type: 'checkbox',
              label: 'What kind of support would you like?',
              options: ['Food', 'Clothes', 'Prayer', 'Bible Study'],
              required: false,
              order: 3
            }
          ]
        },
        {
          id: '2',
          name: 'Bible Interest Survey',
          description: 'Survey to gauge interest in Bible studies',
          category: 'Ministry',
          tags: ['bible', 'study', 'interest'],
          isPublic: true,
          createdBy: 'system',
          usageCount: 32,
          questions: [
            {
              type: 'text',
              label: 'Full Name',
              required: true,
              order: 1
            },
            {
              type: 'phone',
              label: 'Phone Number',
              required: false,
              order: 2
            },
            {
              type: 'rating',
              label: 'How interested are you in Bible study?',
              scale: 5,
              minLabel: 'Not interested',
              maxLabel: 'Very interested',
              required: true,
              order: 3
            },
            {
              type: 'yes_no',
              label: 'Would you like someone to contact you?',
              required: true,
              order: 4
            }
          ]
        }
      ];
      setTemplates(mockTemplates);
    } catch (error) {
      console.error('Error loading templates:', error);
    }
  };

  const loadTeams = async () => {
    try {
      const response = await UserManagementService.getAllTeams();
      if (response.success && response.data) {
        setTeams(response.data);
      }
    } catch (error) {
      console.error('Error loading teams:', error);
    }
  };

  const updateSurvey = (updates: Partial<Survey>) => {
    setBuilderState(prev => ({
      ...prev,
      survey: { ...prev.survey, ...updates },
      isDirty: true
    }));
  };

  const toggleTeamSelection = (teamId: string) => {
    setSelectedTeamIds(prev => {
      if (prev.includes(teamId)) {
        return prev.filter(id => id !== teamId);
      } else {
        return [...prev, teamId];
      }
    });
  };

  const getSelectedTeamsData = () => {
    return selectedTeamIds.map(teamId => {
      const team = teams.find(t => t.id === teamId);
      return {
        teamId,
        teamName: team?.name || 'Unknown Team'
      };
    });
  };

  const addQuestion = (type: QuestionType) => {
    const newQuestion: Partial<AnyQuestion> = {
      id: `q_${Date.now()}`,
      type,
      label: '',
      required: false,
      order: (builderState.survey.questions?.length || 0) + 1
    };

    // Add type-specific defaults
    switch (type) {
      case 'radio':
      case 'checkbox':
      case 'dropdown':
        (newQuestion as any).options = ['Option 1', 'Option 2'];
        break;
      case 'rating':
        (newQuestion as any).scale = 5;
        break;
      case 'text':
      case 'textarea':
        (newQuestion as any).maxLength = type === 'textarea' ? 1000 : 255;
        break;
    }

    setBuilderState(prev => ({
      ...prev,
      currentQuestion: newQuestion,
      isEditing: true,
      isDirty: true
    }));
    setShowQuestionTypes(false);
  };

  const saveQuestion = () => {
    if (!builderState.currentQuestion || !builderState.currentQuestion.label.trim()) {
      Alert.alert('Error', 'Please enter a question label');
      return;
    }

    const questions = builderState.survey.questions || [];
    const existingIndex = questions.findIndex(q => q.id === builderState.currentQuestion?.id);

    if (existingIndex >= 0) {
      questions[existingIndex] = builderState.currentQuestion as AnyQuestion;
    } else {
      questions.push(builderState.currentQuestion as AnyQuestion);
    }

    setBuilderState(prev => ({
      ...prev,
      survey: { ...prev.survey, questions },
      currentQuestion: undefined,
      isEditing: false,
      isDirty: true
    }));

    // Show success message
    Alert.alert('Success', 'Question added successfully!');
  };

  const editQuestion = (question: AnyQuestion) => {
    setBuilderState(prev => ({
      ...prev,
      currentQuestion: question,
      isEditing: true
    }));
  };

  const deleteQuestion = (questionId: string) => {
    Alert.alert(
      'Delete Question',
      'Are you sure you want to delete this question?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => {
            const questions = (builderState.survey.questions || []).filter(q => q.id !== questionId);
            updateSurvey({ questions });
          }
        }
      ]
    );
  };

  const saveSurvey = async () => {
    if (!builderState.survey.title) {
      Alert.alert('Error', 'Please enter a survey title');
      return;
    }

    if (!builderState.survey.questions || builderState.survey.questions.length === 0) {
      Alert.alert('Error', 'Please add at least one question');
      return;
    }

    if (!user) {
      Alert.alert('Error', 'User not authenticated');
      return;
    }

    setLoading(true);
    try {
      const surveyData = {
        ...builderState.survey,
        createdBy: {
          uid: user.uid,
          name: user.displayName || user.email.split('@')[0],
          email: user.email
        },
        // Add team assignments if any teams are selected
        ...(selectedTeamIds.length > 0 && {
          teamIds: selectedTeamIds,
          assignedTeams: getSelectedTeamsData()
        })
      };

      await SurveyService.createSurvey(surveyData);
      Alert.alert('Success', 'Survey created successfully!', [
        { text: 'OK', onPress: () => navigation.goBack() }
      ]);
    } catch (error) {
      console.error('Error saving survey:', error);
      Alert.alert('Error', 'Failed to save survey. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const loadTemplate = (template: SurveyTemplate) => {
    const questions: AnyQuestion[] = template.questions.map((q, index) => ({
      ...q,
      id: `q_${Date.now()}_${index}`,
      order: index + 1
    })) as AnyQuestion[];

    updateSurvey({
      title: template.name,
      description: template.description,
      questions,
      tags: template.tags
    });
    setShowTemplates(false);
  };

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title="Survey Builder"
        showBackButton
        onBackPress={() => navigation.goBack()}
        rightComponent={
          <TouchableOpacity onPress={saveSurvey} disabled={loading}>
            <Text style={[styles.saveButton, loading && styles.disabledButton]}>
              {loading ? 'Saving...' : 'Save'}
            </Text>
          </TouchableOpacity>
        }
      />

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Survey Basic Info */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Survey Information</Text>
          
          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Title *</Text>
            <TextInput
              style={styles.textInput}
              value={builderState.survey.title}
              onChangeText={(title) => updateSurvey({ title })}
              placeholder="Enter survey title"
              placeholderTextColor={COLORS.text.placeholder}
            />
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.inputLabel}>Description</Text>
            <TextInput
              style={[styles.textInput, styles.textArea]}
              value={builderState.survey.description}
              onChangeText={(description) => updateSurvey({ description })}
              placeholder="Enter survey description"
              placeholderTextColor={COLORS.text.placeholder}
              multiline
              numberOfLines={3}
            />
          </View>

          {/* Team Assignment */}
          <View style={styles.inputGroup}>
            <View style={styles.labelRow}>
              <Text style={styles.inputLabel}>Assign to Teams (Optional)</Text>
              <Text style={styles.helperText}>
                {selectedTeamIds.length} team{selectedTeamIds.length !== 1 ? 's' : ''} selected
              </Text>
            </View>
            <TouchableOpacity
              style={styles.teamSelectorButton}
              onPress={() => setShowTeamSelector(true)}
            >
              <MaterialIcons name="groups" size={20} color={COLORS.primary} />
              <Text style={styles.teamSelectorText}>
                {selectedTeamIds.length > 0
                  ? `${selectedTeamIds.length} team${selectedTeamIds.length !== 1 ? 's' : ''} selected`
                  : 'Select teams to assign this survey'
                }
              </Text>
              <MaterialIcons name="chevron-right" size={20} color={COLORS.textSecondary} />
            </TouchableOpacity>

            {/* Selected Teams Display */}
            {selectedTeamIds.length > 0 && (
              <View style={styles.selectedTeamsContainer}>
                {selectedTeamIds.map(teamId => {
                  const team = teams.find(t => t.id === teamId);
                  return (
                    <View key={teamId} style={styles.teamBadge}>
                      <Text style={styles.teamBadgeText}>{team?.name || 'Unknown'}</Text>
                      <TouchableOpacity onPress={() => toggleTeamSelection(teamId)}>
                        <MaterialIcons name="close" size={16} color={COLORS.textInverse} />
                      </TouchableOpacity>
                    </View>
                  );
                })}
              </View>
            )}
          </View>
        </View>

        {/* Action Buttons */}
        <View style={styles.actionButtons}>
          <TouchableOpacity
            style={styles.actionButton}
            onPress={() => setShowTemplates(true)}
          >
            <MaterialIcons name="library-books" size={20} color={COLORS.primary} />
            <Text style={styles.actionButtonText}>Use Template</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.actionButton}
            onPress={() => setShowPreview(true)}
          >
            <MaterialIcons name="preview" size={20} color={COLORS.primary} />
            <Text style={styles.actionButtonText}>Preview</Text>
          </TouchableOpacity>
        </View>

        {/* Questions Section */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Questions</Text>
            <TouchableOpacity
              style={styles.addButton}
              onPress={() => setShowQuestionTypes(true)}
            >
              <MaterialIcons name="add" size={20} color={COLORS.background.primary} />
              <Text style={styles.addButtonText}>Add Question</Text>
            </TouchableOpacity>
          </View>

          {builderState.survey.questions && builderState.survey.questions.length > 0 ? (
            builderState.survey.questions.map((question, index) => (
              <View key={question.id} style={styles.questionCard}>
                <View style={styles.questionHeader}>
                  <Text style={styles.questionNumber}>Q{index + 1}</Text>
                  <Text style={styles.questionType}>{question.type.toUpperCase()}</Text>
                  <View style={styles.questionActions}>
                    <TouchableOpacity
                      onPress={() => editQuestion(question)}
                      style={styles.questionAction}
                    >
                      <MaterialIcons name="edit" size={18} color={COLORS.primary} />
                    </TouchableOpacity>
                    <TouchableOpacity
                      onPress={() => deleteQuestion(question.id)}
                      style={styles.questionAction}
                    >
                      <MaterialIcons name="delete" size={18} color={COLORS.error} />
                    </TouchableOpacity>
                  </View>
                </View>
                <Text style={styles.questionLabel}>{question.label}</Text>
                {question.required && (
                  <Text style={styles.requiredIndicator}>Required</Text>
                )}
              </View>
            ))
          ) : (
            <View style={styles.emptyState}>
              <MaterialIcons name="quiz" size={48} color={COLORS.text.secondary} />
              <Text style={styles.emptyStateText}>No questions added yet</Text>
              <Text style={styles.emptyStateSubtext}>
                Tap "Add Question" to get started
              </Text>
            </View>
          )}
        </View>
      </ScrollView>

      {/* Question Types Modal */}
      <Modal
        visible={showQuestionTypes}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowQuestionTypes(false)}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Choose Question Type</Text>
            <TouchableOpacity
              onPress={() => setShowQuestionTypes(false)}
              style={styles.closeButton}
            >
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
          </View>

          <FlatList
            data={QUESTION_TYPES}
            keyExtractor={(item) => item.type}
            numColumns={2}
            contentContainerStyle={styles.questionTypesList}
            renderItem={({ item }) => (
              <TouchableOpacity
                style={styles.questionTypeCard}
                onPress={() => addQuestion(item.type)}
              >
                <MaterialIcons name={item.icon as any} size={32} color={COLORS.primary} />
                <Text style={styles.questionTypeLabel}>{item.label}</Text>
                <Text style={styles.questionTypeDescription}>{item.description}</Text>
              </TouchableOpacity>
            )}
          />
        </SafeAreaView>
      </Modal>

      {/* Templates Modal */}
      <Modal
        visible={showTemplates}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowTemplates(false)}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Survey Templates</Text>
            <TouchableOpacity
              onPress={() => setShowTemplates(false)}
              style={styles.closeButton}
            >
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
          </View>

          <FlatList
            data={templates}
            keyExtractor={(item) => item.id}
            contentContainerStyle={styles.templatesList}
            renderItem={({ item }) => (
              <TouchableOpacity
                style={styles.templateCard}
                onPress={() => loadTemplate(item)}
              >
                <View style={styles.templateHeader}>
                  <Text style={styles.templateName}>{item.name}</Text>
                  <Text style={styles.templateUsage}>{item.usageCount} uses</Text>
                </View>
                <Text style={styles.templateDescription}>{item.description}</Text>
                <View style={styles.templateTags}>
                  {item.tags.map((tag, index) => (
                    <View key={index} style={styles.templateTag}>
                      <Text style={styles.templateTagText}>{tag}</Text>
                    </View>
                  ))}
                </View>
                <Text style={styles.templateQuestionCount}>
                  {item.questions.length} questions
                </Text>
              </TouchableOpacity>
            )}
          />
        </SafeAreaView>
      </Modal>

      {/* Question Editor Modal */}
      <Modal
        visible={builderState.isEditing && builderState.currentQuestion !== undefined}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setBuilderState(prev => ({ ...prev, isEditing: false, currentQuestion: undefined }))}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>
              {builderState.currentQuestion?.id?.startsWith('q_') ? 'Add Question' : 'Edit Question'}
            </Text>
            <TouchableOpacity
              onPress={() => setBuilderState(prev => ({ ...prev, isEditing: false, currentQuestion: undefined }))}
              style={styles.closeButton}
            >
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.modalContent}>
            {builderState.currentQuestion && (
              <View style={styles.questionEditor}>
                {/* Question Label */}
                <View style={styles.editorField}>
                  <Text style={styles.editorLabel}>Question Label *</Text>
                  <TextInput
                    style={styles.editorInput}
                    value={builderState.currentQuestion.label}
                    onChangeText={(label) =>
                      setBuilderState(prev => ({
                        ...prev,
                        currentQuestion: prev.currentQuestion ? { ...prev.currentQuestion, label } : undefined
                      }))
                    }
                    placeholder="Enter your question"
                    placeholderTextColor={COLORS.text.placeholder}
                    multiline
                  />
                </View>

                {/* Question Description */}
                <View style={styles.editorField}>
                  <Text style={styles.editorLabel}>Description (Optional)</Text>
                  <TextInput
                    style={styles.editorInput}
                    value={(builderState.currentQuestion as any).description || ''}
                    onChangeText={(description) =>
                      setBuilderState(prev => ({
                        ...prev,
                        currentQuestion: prev.currentQuestion ? { ...prev.currentQuestion, description } : undefined
                      }))
                    }
                    placeholder="Add helpful description"
                    placeholderTextColor={COLORS.text.placeholder}
                    multiline
                  />
                </View>

                {/* Required Toggle */}
                <View style={styles.editorField}>
                  <TouchableOpacity
                    style={styles.toggleContainer}
                    onPress={() =>
                      setBuilderState(prev => ({
                        ...prev,
                        currentQuestion: prev.currentQuestion ?
                          { ...prev.currentQuestion, required: !prev.currentQuestion.required } : undefined
                      }))
                    }
                  >
                    <Text style={styles.editorLabel}>Required Question</Text>
                    <View style={[styles.toggle, builderState.currentQuestion.required && styles.toggleActive]}>
                      <View style={[styles.toggleThumb, builderState.currentQuestion.required && styles.toggleThumbActive]} />
                    </View>
                  </TouchableOpacity>
                </View>

                {/* Type-specific fields */}
                {(builderState.currentQuestion.type === 'radio' ||
                  builderState.currentQuestion.type === 'checkbox' ||
                  builderState.currentQuestion.type === 'dropdown') && (
                  <View style={styles.editorField}>
                    <Text style={styles.editorLabel}>Options *</Text>
                    {((builderState.currentQuestion as any).options || []).map((option: string, index: number) => (
                      <View key={index} style={styles.optionRow}>
                        <TextInput
                          style={[styles.editorInput, styles.optionInput]}
                          value={option}
                          onChangeText={(text) => {
                            const options = [...((builderState.currentQuestion as any).options || [])];
                            options[index] = text;
                            setBuilderState(prev => ({
                              ...prev,
                              currentQuestion: prev.currentQuestion ? { ...prev.currentQuestion, options } : undefined
                            }));
                          }}
                          placeholder={`Option ${index + 1}`}
                          placeholderTextColor={COLORS.text.placeholder}
                        />
                        <TouchableOpacity
                          onPress={() => {
                            const options = [...((builderState.currentQuestion as any).options || [])];
                            options.splice(index, 1);
                            setBuilderState(prev => ({
                              ...prev,
                              currentQuestion: prev.currentQuestion ? { ...prev.currentQuestion, options } : undefined
                            }));
                          }}
                          style={styles.removeOptionButton}
                        >
                          <MaterialIcons name="remove-circle" size={20} color={COLORS.error} />
                        </TouchableOpacity>
                      </View>
                    ))}
                    <TouchableOpacity
                      style={styles.addOptionButton}
                      onPress={() => {
                        const options = [...((builderState.currentQuestion as any).options || []), ''];
                        setBuilderState(prev => ({
                          ...prev,
                          currentQuestion: prev.currentQuestion ? { ...prev.currentQuestion, options } : undefined
                        }));
                      }}
                    >
                      <MaterialIcons name="add" size={20} color={COLORS.primary} />
                      <Text style={styles.addOptionText}>Add Option</Text>
                    </TouchableOpacity>
                  </View>
                )}

                {/* Rating Scale */}
                {builderState.currentQuestion.type === 'rating' && (
                  <View style={styles.editorField}>
                    <Text style={styles.editorLabel}>Rating Scale (1 to ?)</Text>
                    <TextInput
                      style={styles.editorInput}
                      value={((builderState.currentQuestion as any).scale || 5).toString()}
                      onChangeText={(text) => {
                        const scale = parseInt(text) || 5;
                        setBuilderState(prev => ({
                          ...prev,
                          currentQuestion: prev.currentQuestion ? { ...prev.currentQuestion, scale } : undefined
                        }));
                      }}
                      placeholder="5"
                      keyboardType="numeric"
                      placeholderTextColor={COLORS.text.placeholder}
                    />
                  </View>
                )}

                {/* Save Button */}
                <TouchableOpacity
                  style={styles.saveQuestionButton}
                  onPress={saveQuestion}
                >
                  <Text style={styles.saveQuestionText}>Save Question</Text>
                </TouchableOpacity>
              </View>
            )}
          </ScrollView>
        </SafeAreaView>
      </Modal>

      {/* Preview Modal */}
      <Modal
        visible={showPreview}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowPreview(false)}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Survey Preview</Text>
            <TouchableOpacity
              onPress={() => setShowPreview(false)}
              style={styles.closeButton}
            >
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.previewContent}>
            <View style={styles.previewHeader}>
              <Text style={styles.previewTitle}>{builderState.survey.title}</Text>
              <Text style={styles.previewDescription}>{builderState.survey.description}</Text>
            </View>

            {builderState.survey.questions?.map((question, index) => (
              <View key={question.id} style={styles.previewQuestion}>
                <SurveyQuestion
                  question={question}
                  value=""
                  onChange={() => {}}
                  disabled={true}
                />
              </View>
            ))}
          </ScrollView>
        </SafeAreaView>
      </Modal>

      {/* Team Selector Modal */}
      <Modal
        visible={showTeamSelector}
        transparent
        animationType="slide"
        onRequestClose={() => setShowTeamSelector(false)}
      >
        <View style={styles.teamModalOverlay}>
          <View style={styles.teamModalContent}>
            <View style={styles.teamModalHeader}>
              <Text style={styles.teamModalTitle}>Assign Survey to Teams</Text>
              <TouchableOpacity onPress={() => setShowTeamSelector(false)}>
                <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
            </View>

            <Text style={styles.teamModalSubtitle}>
              Select teams that can access this survey. Workers in selected teams will be able to view and complete this survey.
            </Text>

            <ScrollView style={styles.teamsList}>
              {teams.length === 0 ? (
                <View style={styles.emptyTeamsState}>
                  <MaterialIcons name="groups" size={48} color={COLORS.textSecondary} />
                  <Text style={styles.emptyTeamsText}>No teams available</Text>
                  <Text style={styles.emptyTeamsSubtext}>
                    Create teams in User Management to assign surveys
                  </Text>
                </View>
              ) : (
                teams.map(team => {
                  const isSelected = selectedTeamIds.includes(team.id);
                  return (
                    <TouchableOpacity
                      key={team.id}
                      style={[styles.teamItem, isSelected && styles.teamItemSelected]}
                      onPress={() => toggleTeamSelection(team.id)}
                    >
                      <View style={styles.teamItemContent}>
                        <View style={styles.teamItemInfo}>
                          <Text style={styles.teamItemName}>{team.name}</Text>
                          {team.description && (
                            <Text style={styles.teamItemDescription} numberOfLines={1}>
                              {team.description}
                            </Text>
                          )}
                          <View style={styles.teamItemMeta}>
                            <MaterialIcons name="people" size={14} color={COLORS.textSecondary} />
                            <Text style={styles.teamItemMetaText}>
                              {team.memberCount} member{team.memberCount !== 1 ? 's' : ''}
                            </Text>
                            {team.leaderName && (
                              <>
                                <Text style={styles.teamItemMetaDivider}>•</Text>
                                <Text style={styles.teamItemMetaText}>
                                  Led by {team.leaderName}
                                </Text>
                              </>
                            )}
                          </View>
                        </View>
                        <View style={[styles.checkbox, isSelected && styles.checkboxSelected]}>
                          {isSelected && (
                            <MaterialIcons name="check" size={18} color={COLORS.textInverse} />
                          )}
                        </View>
                      </View>
                    </TouchableOpacity>
                  );
                })
              )}
            </ScrollView>

            <View style={styles.teamModalFooter}>
              <TouchableOpacity
                style={styles.teamModalCancelButton}
                onPress={() => setShowTeamSelector(false)}
              >
                <Text style={styles.teamModalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.teamModalConfirmButton}
                onPress={() => setShowTeamSelector(false)}
              >
                <Text style={styles.teamModalConfirmText}>
                  Done ({selectedTeamIds.length})
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
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
  section: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
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
    minHeight: 80,
    textAlignVertical: 'top',
  },
  saveButton: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.primary,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
  },
  disabledButton: {
    opacity: 0.6,
  },
  actionButtons: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: SPACING.md,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.surface,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  actionButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.primary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
  },
  addButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.background.primary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  questionCard: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.light,
  },
  questionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  questionNumber: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.primary,
    backgroundColor: COLORS.primary + '20',
    paddingHorizontal: SPACING.xs,
    paddingVertical: 2,
    borderRadius: RADIUS.sm,
    minWidth: 24,
    textAlign: 'center',
  },
  questionType: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    marginLeft: SPACING.sm,
    flex: 1,
  },
  questionActions: {
    flexDirection: 'row',
  },
  questionAction: {
    padding: SPACING.xs,
    marginLeft: SPACING.xs,
  },
  questionLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  requiredIndicator: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.error,
    marginTop: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  emptyState: {
    alignItems: 'center',
    padding: SPACING.xl,
  },
  emptyStateText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  emptyStateSubtext: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
  // Modal Styles
  modalContainer: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  modalTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  closeButton: {
    padding: SPACING.xs,
  },
  questionTypesList: {
    padding: SPACING.md,
  },
  questionTypeCard: {
    flex: 1,
    backgroundColor: COLORS.background.surface,
    margin: SPACING.xs,
    padding: SPACING.lg,
    borderRadius: RADIUS.lg,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  questionTypeLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.sm,
    textAlign: 'center',
  },
  questionTypeDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
  templatesList: {
    padding: SPACING.md,
  },
  templateCard: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  templateHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  templateName: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    flex: 1,
  },
  templateUsage: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  templateDescription: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
  },
  templateTags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: SPACING.sm,
  },
  templateTag: {
    backgroundColor: COLORS.primary + '20',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.sm,
    marginRight: SPACING.xs,
    marginBottom: SPACING.xs,
  },
  templateTagText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  templateQuestionCount: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  previewContent: {
    flex: 1,
    padding: SPACING.md,
  },
  previewHeader: {
    marginBottom: SPACING.lg,
  },
  previewTitle: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  previewDescription: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
  },
  previewQuestion: {
    marginBottom: SPACING.lg,
  },
  // Question Editor Styles
  questionEditor: {
    padding: SPACING.lg,
  },
  editorField: {
    marginBottom: SPACING.lg,
  },
  editorLabel: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  editorInput: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.surface,
    minHeight: 48,
    textAlignVertical: 'top',
  },
  toggleContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  toggle: {
    width: 50,
    height: 28,
    borderRadius: 14,
    backgroundColor: COLORS.border.default,
    justifyContent: 'center',
    paddingHorizontal: 2,
  },
  toggleActive: {
    backgroundColor: COLORS.primary,
  },
  toggleThumb: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: COLORS.background.surface,
    alignSelf: 'flex-start',
  },
  toggleThumbActive: {
    alignSelf: 'flex-end',
  },
  optionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  optionInput: {
    flex: 1,
    marginRight: SPACING.sm,
  },
  removeOptionButton: {
    padding: SPACING.xs,
  },
  addOptionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.primary + '20',
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    marginTop: SPACING.sm,
  },
  addOptionText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.primary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  saveQuestionButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    marginTop: SPACING.xl,
  },
  saveQuestionText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
  // Team Assignment Styles
  labelRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  helperText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  teamSelectorButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.surface,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    gap: SPACING.sm,
  },
  teamSelectorText: {
    flex: 1,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
  },
  selectedTeamsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.sm,
    marginTop: SPACING.sm,
  },
  teamBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.full,
    gap: SPACING.xs,
  },
  teamBadgeText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.textInverse,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  // Team Modal Styles
  teamModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  teamModalContent: {
    backgroundColor: COLORS.background.primary,
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    maxHeight: '80%',
    paddingBottom: SPACING.xl,
  },
  teamModalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  teamModalTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  teamModalSubtitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    padding: SPACING.lg,
    paddingTop: SPACING.md,
    lineHeight: 20,
  },
  teamsList: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
  },
  emptyTeamsState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING.xl * 2,
  },
  emptyTeamsText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
  },
  emptyTeamsSubtext: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
  teamItem: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  teamItemSelected: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.primary + '10',
  },
  teamItemContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  teamItemInfo: {
    flex: 1,
    marginRight: SPACING.md,
  },
  teamItemName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  teamItemDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  teamItemMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
  },
  teamItemMetaText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },
  teamItemMetaDivider: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    marginHorizontal: SPACING.xs,
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: RADIUS.sm,
    borderWidth: 2,
    borderColor: COLORS.border.default,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxSelected: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  teamModalFooter: {
    flexDirection: 'row',
    gap: SPACING.md,
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.lg,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.default,
  },
  teamModalCancelButton: {
    flex: 1,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    alignItems: 'center',
  },
  teamModalCancelText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  teamModalConfirmButton: {
    flex: 1,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.primary,
    alignItems: 'center',
  },
  teamModalConfirmText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.textInverse,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
});

export default SurveyBuilderScreen;
