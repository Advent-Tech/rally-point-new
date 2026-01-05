import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  Alert,
  Modal,
  TextInput,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { BookAssignmentService, BookAssignment, BookAssignmentFormData, BookAssignmentStats } from '../services/BookAssignmentService';
import { UserManagementService } from '../services/UserManagementService';
import { ManagedUser } from '../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface AdminBookAssignmentScreenProps {
  navigation: any;
}

const AdminBookAssignmentScreen: React.FC<AdminBookAssignmentScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [assignments, setAssignments] = useState<BookAssignment[]>([]);
  const [workers, setWorkers] = useState<ManagedUser[]>([]);
  const [stats, setStats] = useState<BookAssignmentStats | null>(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingAssignment, setEditingAssignment] = useState<BookAssignment | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const [formData, setFormData] = useState<BookAssignmentFormData>({
    workerId: '',
    workerName: '',
    workerEmail: '',
    bookTitle: '',
    bookType: 'bible',
    quantity: 1,
    deliveryDeadline: undefined,
    notes: '',
  });

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      await Promise.all([
        loadAssignments(),
        loadWorkers(),
        loadStats(),
      ]);
    } catch (error) {
      console.error('Error loading data:', error);
      Alert.alert('Error', 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const loadAssignments = async () => {
    try {
      const data = await BookAssignmentService.getAllAssignments();
      setAssignments(data);
    } catch (error) {
      console.error('Error loading assignments:', error);
    }
  };

  const loadWorkers = async () => {
    try {
      const response = await UserManagementService.getAllUsers({ role: 'worker' });
      if (response.success && response.data) {
        setWorkers(response.data);
      }
    } catch (error) {
      console.error('Error loading workers:', error);
    }
  };

  const loadStats = async () => {
    try {
      const data = await BookAssignmentService.getAssignmentStats();
      setStats(data);
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const handleWorkerSelect = (workerId: string) => {
    const selectedWorker = workers.find(w => w.uid === workerId);
    if (selectedWorker) {
      setFormData({
        ...formData,
        workerId: selectedWorker.uid,
        workerName: selectedWorker.displayName,
        workerEmail: selectedWorker.email,
      });
    }
  };

  const handleSubmit = async () => {
    if (!formData.workerId || !formData.bookTitle || formData.quantity < 1) {
      Alert.alert('Error', 'Please fill in all required fields');
      return;
    }

    if (!user) {
      Alert.alert('Error', 'User not authenticated');
      return;
    }

    setSubmitting(true);
    try {
      const result = await BookAssignmentService.createAssignment(
        formData,
        user.uid,
        user.displayName || user.email?.split('@')[0] || 'Admin',
        user.email || ''
      );

      if (result.success) {
        Alert.alert('Success', 'Book assigned successfully');
        setShowAddModal(false);
        resetForm();
        await loadData();
      } else {
        Alert.alert('Error', result.error || 'Failed to assign book');
      }
    } catch (error) {
      console.error('Error assigning book:', error);
      Alert.alert('Error', 'Failed to assign book');
    } finally {
      setSubmitting(false);
    }
  };

  const handleEdit = (assignment: BookAssignment) => {
    setEditingAssignment(assignment);
    setFormData({
      workerId: assignment.workerId,
      workerName: assignment.workerName,
      workerEmail: assignment.workerEmail,
      bookTitle: assignment.bookTitle,
      bookType: assignment.bookType,
      quantity: assignment.quantity,
      deliveryDeadline: assignment.deliveryDeadline,
      notes: assignment.notes || '',
    });
    setShowEditModal(true);
  };

  const handleUpdate = async () => {
    if (!editingAssignment) return;

    setSubmitting(true);
    try {
      const result = await BookAssignmentService.updateAssignment(editingAssignment.id, {
        bookTitle: formData.bookTitle,
        bookType: formData.bookType,
        quantity: formData.quantity,
        deliveryDeadline: formData.deliveryDeadline,
        notes: formData.notes,
      });

      if (result.success) {
        Alert.alert('Success', 'Assignment updated successfully');
        setShowEditModal(false);
        setEditingAssignment(null);
        resetForm();
        await loadData();
      } else {
        Alert.alert('Error', result.error || 'Failed to update assignment');
      }
    } catch (error) {
      console.error('Error updating assignment:', error);
      Alert.alert('Error', 'Failed to update assignment');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = (assignment: BookAssignment) => {
    Alert.alert(
      'Delete Assignment',
      `Are you sure you want to delete this assignment for ${assignment.workerName}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            const result = await BookAssignmentService.deleteAssignment(assignment.id);
            if (result.success) {
              Alert.alert('Success', 'Assignment deleted successfully');
              await loadData();
            } else {
              Alert.alert('Error', result.error || 'Failed to delete assignment');
            }
          },
        },
      ]
    );
  };

  const resetForm = () => {
    setFormData({
      workerId: '',
      workerName: '',
      workerEmail: '',
      bookTitle: '',
      bookType: 'bible',
      quantity: 1,
      deliveryDeadline: undefined,
      notes: '',
    });
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'assigned':
        return COLORS.info;
      case 'in_progress':
        return COLORS.warning;
      case 'completed':
        return COLORS.success;
      case 'cancelled':
        return COLORS.error;
      default:
        return COLORS.textSecondary;
    }
  };

  const getStatusLabel = (status: string) => {
    return status.replace('_', ' ').toUpperCase();
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading assignments...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
          <Ionicons name="arrow-back" size={24} color={COLORS.text} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Book Assignments</Text>
        <TouchableOpacity onPress={() => setShowAddModal(true)} style={styles.addButton}>
          <Ionicons name="add-circle" size={28} color={COLORS.primary} />
        </TouchableOpacity>
      </View>

      {/* Stats Cards */}
      {stats && (
        <View style={styles.statsContainer}>
          <View style={styles.statCard}>
            <Text style={styles.statValue}>{stats.totalAssignments}</Text>
            <Text style={styles.statLabel}>Total</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statValue}>{stats.activeAssignments}</Text>
            <Text style={styles.statLabel}>Active</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statValue}>{stats.completedAssignments}</Text>
            <Text style={styles.statLabel}>Completed</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statValue}>{stats.totalBooksAssigned}</Text>
            <Text style={styles.statLabel}>Books</Text>
          </View>
        </View>
      )}

      {/* Assignments List */}
      <ScrollView
        style={styles.listContainer}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {assignments.map((assignment) => (
          <View key={assignment.id} style={styles.assignmentCard}>
            <View style={styles.assignmentHeader}>
              <View style={styles.assignmentInfo}>
                <Text style={styles.workerName}>{assignment.workerName}</Text>
                <Text style={styles.workerEmail}>{assignment.workerEmail}</Text>
              </View>
              <View style={[styles.statusBadge, { backgroundColor: getStatusColor(assignment.status) + '20' }]}>
                <Text style={[styles.statusText, { color: getStatusColor(assignment.status) }]}>
                  {getStatusLabel(assignment.status)}
                </Text>
              </View>
            </View>

            <View style={styles.assignmentDetails}>
              <View style={styles.detailRow}>
                <MaterialIcons name="book" size={16} color={COLORS.textSecondary} />
                <Text style={styles.detailText}>{assignment.bookTitle}</Text>
              </View>
              <View style={styles.detailRow}>
                <MaterialIcons name="category" size={16} color={COLORS.textSecondary} />
                <Text style={styles.detailText}>{assignment.bookType}</Text>
              </View>
              <View style={styles.detailRow}>
                <MaterialIcons name="numbers" size={16} color={COLORS.textSecondary} />
                <Text style={styles.detailText}>
                  Quantity: {assignment.deliveredQuantity}/{assignment.quantity}
                </Text>
              </View>
            </View>

            {assignment.notes && (
              <Text style={styles.notesText}>Note: {assignment.notes}</Text>
            )}

            <View style={styles.assignmentActions}>
              <TouchableOpacity
                style={styles.editButton}
                onPress={() => handleEdit(assignment)}
              >
                <MaterialIcons name="edit" size={18} color={COLORS.primary} />
                <Text style={styles.editButtonText}>Edit</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.deleteButton}
                onPress={() => handleDelete(assignment)}
              >
                <MaterialIcons name="delete" size={18} color={COLORS.error} />
                <Text style={styles.deleteButtonText}>Delete</Text>
              </TouchableOpacity>
            </View>
          </View>
        ))}

        {assignments.length === 0 && (
          <View style={styles.emptyState}>
            <MaterialIcons name="assignment" size={64} color={COLORS.textSecondary} />
            <Text style={styles.emptyStateText}>No assignments yet</Text>
            <Text style={styles.emptyStateSubtext}>Tap + to assign books to workers</Text>
          </View>
        )}
      </ScrollView>

      {/* Add Assignment Modal */}
      <Modal
        visible={showAddModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowAddModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Assign Book to Worker</Text>

            <ScrollView style={styles.modalForm}>
              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Select Worker *</Text>
                <View style={styles.pickerContainer}>
                  <Picker
                    selectedValue={formData.workerId}
                    onValueChange={handleWorkerSelect}
                    style={styles.picker}
                  >
                    <Picker.Item label="Choose a worker..." value="" />
                    {workers.map((worker) => (
                      <Picker.Item
                        key={worker.uid}
                        label={`${worker.displayName} (${worker.email})`}
                        value={worker.uid}
                      />
                    ))}
                  </Picker>
                </View>
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Book Title *</Text>
                <TextInput
                  style={styles.input}
                  placeholder="Enter book title..."
                  value={formData.bookTitle}
                  onChangeText={(text) => setFormData({ ...formData, bookTitle: text })}
                  placeholderTextColor={COLORS.textSecondary}
                />
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Book Type *</Text>
                <View style={styles.pickerContainer}>
                  <Picker
                    selectedValue={formData.bookType}
                    onValueChange={(value) => setFormData({ ...formData, bookType: value as any })}
                    style={styles.picker}
                  >
                    <Picker.Item label="Bible" value="bible" />
                    <Picker.Item label="Tract" value="tract" />
                    <Picker.Item label="Magazine" value="magazine" />
                    <Picker.Item label="Study Guide" value="study_guide" />
                  </Picker>
                </View>
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Quantity *</Text>
                <TextInput
                  style={styles.input}
                  placeholder="Enter quantity..."
                  value={formData.quantity.toString()}
                  onChangeText={(text) => setFormData({ ...formData, quantity: parseInt(text) || 1 })}
                  keyboardType="number-pad"
                  placeholderTextColor={COLORS.textSecondary}
                />
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Notes (Optional)</Text>
                <TextInput
                  style={[styles.input, styles.textArea]}
                  placeholder="Add any notes..."
                  value={formData.notes}
                  onChangeText={(text) => setFormData({ ...formData, notes: text })}
                  multiline
                  numberOfLines={3}
                  placeholderTextColor={COLORS.textSecondary}
                />
              </View>
            </ScrollView>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={() => {
                  setShowAddModal(false);
                  resetForm();
                }}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalConfirmButton, { opacity: submitting ? 0.5 : 1 }]}
                onPress={handleSubmit}
                disabled={submitting}
              >
                {submitting ? (
                  <ActivityIndicator color="white" />
                ) : (
                  <Text style={styles.modalConfirmText}>Assign Book</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Edit Assignment Modal */}
      <Modal
        visible={showEditModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowEditModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Edit Assignment</Text>

            <ScrollView style={styles.modalForm}>
              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Worker</Text>
                <Text style={styles.readOnlyText}>{formData.workerName}</Text>
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Book Title *</Text>
                <TextInput
                  style={styles.input}
                  placeholder="Enter book title..."
                  value={formData.bookTitle}
                  onChangeText={(text) => setFormData({ ...formData, bookTitle: text })}
                  placeholderTextColor={COLORS.textSecondary}
                />
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Book Type *</Text>
                <View style={styles.pickerContainer}>
                  <Picker
                    selectedValue={formData.bookType}
                    onValueChange={(value) => setFormData({ ...formData, bookType: value as any })}
                    style={styles.picker}
                  >
                    <Picker.Item label="Bible" value="bible" />
                    <Picker.Item label="Tract" value="tract" />
                    <Picker.Item label="Magazine" value="magazine" />
                    <Picker.Item label="Study Guide" value="study_guide" />
                  </Picker>
                </View>
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Quantity *</Text>
                <TextInput
                  style={styles.input}
                  placeholder="Enter quantity..."
                  value={formData.quantity.toString()}
                  onChangeText={(text) => setFormData({ ...formData, quantity: parseInt(text) || 1 })}
                  keyboardType="number-pad"
                  placeholderTextColor={COLORS.textSecondary}
                />
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.formLabel}>Notes (Optional)</Text>
                <TextInput
                  style={[styles.input, styles.textArea]}
                  placeholder="Add any notes..."
                  value={formData.notes}
                  onChangeText={(text) => setFormData({ ...formData, notes: text })}
                  multiline
                  numberOfLines={3}
                  placeholderTextColor={COLORS.textSecondary}
                />
              </View>
            </ScrollView>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={() => {
                  setShowEditModal(false);
                  setEditingAssignment(null);
                  resetForm();
                }}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalConfirmButton, { opacity: submitting ? 0.5 : 1 }]}
                onPress={handleUpdate}
                disabled={submitting}
              >
                {submitting ? (
                  <ActivityIndicator color="white" />
                ) : (
                  <Text style={styles.modalConfirmText}>Update</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
};

export default AdminBookAssignmentScreen;

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: COLORS.textSecondary,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  backButton: {
    padding: 8,
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: COLORS.text,
  },
  addButton: {
    padding: 8,
  },
  statsContainer: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
  },
  statCard: {
    flex: 1,
    backgroundColor: 'white',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    ...SHADOWS.small,
  },
  statValue: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.primary,
  },
  statLabel: {
    fontSize: 12,
    color: COLORS.textSecondary,
    marginTop: 4,
  },
  listContainer: {
    flex: 1,
    padding: 16,
  },
  assignmentCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    ...SHADOWS.small,
  },
  assignmentHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  assignmentInfo: {
    flex: 1,
  },
  workerName: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  workerEmail: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 2,
  },
  statusBadge: {
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
  },
  assignmentDetails: {
    gap: 8,
    marginBottom: 12,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  detailText: {
    fontSize: 14,
    color: COLORS.text,
  },
  notesText: {
    fontSize: 13,
    color: COLORS.textSecondary,
    fontStyle: 'italic',
    marginBottom: 12,
  },
  assignmentActions: {
    flexDirection: 'row',
    gap: 12,
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
    paddingTop: 12,
  },
  editButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    paddingHorizontal: 12,
    backgroundColor: COLORS.primary + '10',
    borderRadius: 8,
    gap: 4,
  },
  editButtonText: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.primary,
  },
  deleteButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    paddingHorizontal: 12,
    backgroundColor: COLORS.error + '10',
    borderRadius: 8,
    gap: 4,
  },
  deleteButtonText: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.error,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
  },
  emptyStateText: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginTop: 16,
  },
  emptyStateSubtext: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 8,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: 'white',
    borderRadius: 16,
    padding: 24,
    width: '90%',
    maxWidth: 500,
    maxHeight: '80%',
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 20,
    textAlign: 'center',
  },
  modalForm: {
    maxHeight: 400,
  },
  formGroup: {
    marginBottom: 16,
  },
  formLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.text,
    marginBottom: 8,
  },
  input: {
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    color: COLORS.text,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  textArea: {
    height: 80,
    textAlignVertical: 'top',
  },
  pickerContainer: {
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    overflow: 'hidden',
  },
  picker: {
    backgroundColor: 'transparent',
  },
  readOnlyText: {
    fontSize: 16,
    color: COLORS.textSecondary,
    paddingVertical: 12,
    paddingHorizontal: 12,
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
  },
  modalButtons: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 20,
  },
  modalCancelButton: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: COLORS.textSecondary,
    alignItems: 'center',
  },
  modalCancelText: {
    fontSize: 16,
    color: COLORS.textSecondary,
    fontWeight: '500',
  },
  modalConfirmButton: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    backgroundColor: COLORS.primary,
    alignItems: 'center',
  },
  modalConfirmText: {
    fontSize: 16,
    color: 'white',
    fontWeight: '600',
  },
});

