import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  TouchableOpacity,
  ScrollView,
  Alert,
  Modal,
  ActivityIndicator,
  FlatList,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import Header from '../components/Header';
import GeoTerritoryMap from '../components/GeoTerritoryMap';
import {
  geoTerritoryService,
  GeoTerritory,
  TerritoryAssignmentWithDetails,
  CreateAssignmentRequest,
} from '../services/GeoTerritoryService';
import { UserManagementService, TeamMember } from '../services/UserManagementService';
import { useAuth } from '../contexts/AuthContext';
import { COLORS, SPACING, TYPOGRAPHY, RADIUS } from '../constants/Colors';

interface TeamLeaderTerritoryAssignmentScreenProps {
  navigation: any;
}

const TeamLeaderTerritoryAssignmentScreen: React.FC<TeamLeaderTerritoryAssignmentScreenProps> = ({
  navigation,
}) => {
  const { user } = useAuth();
  const [loading, setLoading] = useState(false);
  const [selectedTerritory, setSelectedTerritory] = useState<GeoTerritory | null>(null);
  const [teamAssignments, setTeamAssignments] = useState<TerritoryAssignmentWithDetails[]>([]);
  const [teamMembers, setTeamMembers] = useState<TeamMember[]>([]);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [showAssignmentsView, setShowAssignmentsView] = useState(false);
  const [selectedWorker, setSelectedWorker] = useState<TeamMember | null>(null);
  const [selectedPriority, setSelectedPriority] = useState<'high' | 'medium' | 'low'>('medium');

  // Load team data
  useEffect(() => {
    loadTeamData();
  }, []);

  const loadTeamData = async () => {
    if (!user?.team_id) return;

    try {
      setLoading(true);

      // Load team members
      const membersResult = await UserManagementService.getTeamMembers(user.team_id);
      setTeamMembers(membersResult.members || []);

      // Load team assignments
      const assignmentsResult = await geoTerritoryService.getTeamAssignments(user.team_id, 'active');
      setTeamAssignments(assignmentsResult.assignments || []);
    } catch (error) {
      console.error('Error loading team data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleTerritorySelect = useCallback((territory: GeoTerritory) => {
    setSelectedTerritory(territory);
    setShowAssignModal(true);
  }, []);

  const handleAssignTerritory = async () => {
    if (!selectedTerritory || !user?.team_id || !user?.id) {
      Alert.alert('Error', 'Missing required information');
      return;
    }

    try {
      setLoading(true);

      const request: CreateAssignmentRequest = {
        territory_id: selectedTerritory.id,
        team_id: user.team_id,
        assigned_worker_id: selectedWorker?.id,
        assigned_by: user.id,
        priority: selectedPriority,
      };

      await geoTerritoryService.assignTerritory(request);

      Alert.alert(
        'Success',
        `Territory "${selectedTerritory.entity_name}" has been assigned${selectedWorker ? ` to ${selectedWorker.display_name}` : ' to the team'}.`
      );

      setShowAssignModal(false);
      setSelectedTerritory(null);
      setSelectedWorker(null);
      setSelectedPriority('medium');

      // Refresh assignments
      loadTeamData();
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to assign territory');
    } finally {
      setLoading(false);
    }
  };

  const handleUnassign = async (assignmentId: string, territoryName: string) => {
    Alert.alert(
      'Unassign Territory',
      `Are you sure you want to unassign "${territoryName}"?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Unassign',
          style: 'destructive',
          onPress: async () => {
            try {
              setLoading(true);
              await geoTerritoryService.unassignTerritory(assignmentId);
              Alert.alert('Success', 'Territory has been unassigned');
              loadTeamData();
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to unassign territory');
            } finally {
              setLoading(false);
            }
          },
        },
      ]
    );
  };

  const handleBackPress = useCallback(() => {
    if (navigation.canGoBack()) {
      navigation.goBack();
    } else {
      navigation.navigate('TeamLeaderDashboard');
    }
  }, [navigation]);

  const renderAssignmentItem = ({ item }: { item: TerritoryAssignmentWithDetails }) => (
    <View style={styles.assignmentCard}>
      <View style={styles.assignmentHeader}>
        <View style={[styles.priorityBadge, styles[`priority${item.priority}`]]}>
          <Text style={styles.priorityText}>{item.priority.toUpperCase()}</Text>
        </View>
        <TouchableOpacity
          onPress={() => handleUnassign(item.id, item.entity_name)}
          style={styles.unassignButton}
        >
          <MaterialIcons name="close" size={18} color="#ef4444" />
        </TouchableOpacity>
      </View>

      <Text style={styles.assignmentName} numberOfLines={1}>
        {item.entity_name}
      </Text>

      <Text style={styles.assignmentLocation} numberOfLines={1}>
        {item.city}{item.city && item.state ? ', ' : ''}{item.state}
      </Text>

      <View style={styles.assignmentMeta}>
        <View style={styles.metaItem}>
          <MaterialIcons name="group" size={14} color={COLORS.text.secondary} />
          <Text style={styles.metaText}>
            {item.population?.toLocaleString() || 'N/A'} pop
          </Text>
        </View>
        <View style={styles.metaItem}>
          <MaterialIcons name="home" size={14} color={COLORS.text.secondary} />
          <Text style={styles.metaText}>
            {item.housing_units?.toLocaleString() || 'N/A'} homes
          </Text>
        </View>
      </View>

      <View style={styles.progressContainer}>
        <View style={styles.progressBar}>
          <View
            style={[styles.progressFill, { width: `${item.completeness_percentage}%` }]}
          />
        </View>
        <Text style={styles.progressText}>{item.completeness_percentage.toFixed(0)}%</Text>
      </View>

      <Text style={styles.visitsText}>
        {item.visits_count} visits
      </Text>
    </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#1e293b" />

      <Header
        title="Territory Assignment"
        subtitle={showAssignmentsView ? 'Team Assignments' : 'Select territory to assign'}
        showBackButton={true}
        onBackPress={handleBackPress}
        rightComponent={
          <TouchableOpacity
            style={styles.toggleButton}
            onPress={() => setShowAssignmentsView(!showAssignmentsView)}
          >
            <MaterialIcons
              name={showAssignmentsView ? 'map' : 'list'}
              size={24}
              color="#fff"
            />
          </TouchableOpacity>
        }
      />

      {showAssignmentsView ? (
        // Assignments List View
        <View style={styles.assignmentsContainer}>
          <View style={styles.statsRow}>
            <View style={styles.statCard}>
              <Text style={styles.statNumber}>{teamAssignments.length}</Text>
              <Text style={styles.statLabel}>Assigned</Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statNumber}>
                {teamAssignments.filter(a => a.completeness_percentage >= 100).length}
              </Text>
              <Text style={styles.statLabel}>Completed</Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statNumber}>
                {teamAssignments.reduce((sum, a) => sum + a.visits_count, 0)}
              </Text>
              <Text style={styles.statLabel}>Total Visits</Text>
            </View>
          </View>

          {loading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={COLORS.primary} />
            </View>
          ) : teamAssignments.length === 0 ? (
            <View style={styles.emptyContainer}>
              <MaterialIcons name="map" size={64} color={COLORS.text.secondary} />
              <Text style={styles.emptyTitle}>No Territories Assigned</Text>
              <Text style={styles.emptySubtitle}>
                Tap the map icon to assign territories to your team
              </Text>
            </View>
          ) : (
            <FlatList
              data={teamAssignments}
              renderItem={renderAssignmentItem}
              keyExtractor={(item) => item.id}
              contentContainerStyle={styles.assignmentsList}
              showsVerticalScrollIndicator={false}
            />
          )}
        </View>
      ) : (
        // Map View for Territory Selection
        <View style={styles.mapContainer}>
          <GeoTerritoryMap
            height="100%"
            showSearch={true}
            showStats={true}
            onTerritorySelect={handleTerritorySelect}
          />
        </View>
      )}

      {/* Assignment Modal */}
      <Modal
        visible={showAssignModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowAssignModal(false)}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <TouchableOpacity onPress={() => setShowAssignModal(false)}>
              <MaterialIcons name="close" size={24} color={COLORS.text.secondary} />
            </TouchableOpacity>
            <Text style={styles.modalTitle}>Assign Territory</Text>
            <TouchableOpacity
              onPress={handleAssignTerritory}
              disabled={loading}
            >
              {loading ? (
                <ActivityIndicator size="small" color={COLORS.primary} />
              ) : (
                <Text style={styles.assignButtonText}>Assign</Text>
              )}
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.modalContent}>
            {/* Territory Info */}
            {selectedTerritory && (
              <View style={styles.territoryInfo}>
                <Text style={styles.territoryName}>{selectedTerritory.entity_name}</Text>
                <Text style={styles.territoryLocation}>
                  {selectedTerritory.city}{selectedTerritory.city && selectedTerritory.state ? ', ' : ''}{selectedTerritory.state}
                </Text>
                {selectedTerritory.union_name && (
                  <Text style={styles.territoryOrg}>
                    {selectedTerritory.union_name} - {selectedTerritory.conference}
                  </Text>
                )}
                <View style={styles.territoryStats}>
                  <View style={styles.territoryStat}>
                    <MaterialIcons name="group" size={16} color={COLORS.primary} />
                    <Text style={styles.territoryStatText}>
                      {selectedTerritory.population?.toLocaleString() || 'N/A'} population
                    </Text>
                  </View>
                  <View style={styles.territoryStat}>
                    <MaterialIcons name="home" size={16} color={COLORS.primary} />
                    <Text style={styles.territoryStatText}>
                      {selectedTerritory.housing_units?.toLocaleString() || 'N/A'} housing units
                    </Text>
                  </View>
                </View>
              </View>
            )}

            {/* Worker Selection */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Assign to Worker (Optional)</Text>
              <Text style={styles.sectionSubtitle}>
                Leave unselected to assign to the entire team
              </Text>

              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.workersScroll}>
                <TouchableOpacity
                  style={[
                    styles.workerChip,
                    !selectedWorker && styles.workerChipSelected,
                  ]}
                  onPress={() => setSelectedWorker(null)}
                >
                  <MaterialIcons
                    name="groups"
                    size={20}
                    color={!selectedWorker ? '#fff' : COLORS.text.secondary}
                  />
                  <Text
                    style={[
                      styles.workerChipText,
                      !selectedWorker && styles.workerChipTextSelected,
                    ]}
                  >
                    Entire Team
                  </Text>
                </TouchableOpacity>

                {teamMembers.map((member) => (
                  <TouchableOpacity
                    key={member.id}
                    style={[
                      styles.workerChip,
                      selectedWorker?.id === member.id && styles.workerChipSelected,
                    ]}
                    onPress={() => setSelectedWorker(member)}
                  >
                    <MaterialIcons
                      name="person"
                      size={20}
                      color={selectedWorker?.id === member.id ? '#fff' : COLORS.text.secondary}
                    />
                    <Text
                      style={[
                        styles.workerChipText,
                        selectedWorker?.id === member.id && styles.workerChipTextSelected,
                      ]}
                      numberOfLines={1}
                    >
                      {member.display_name}
                    </Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            </View>

            {/* Priority Selection */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Priority</Text>

              <View style={styles.prioritySelector}>
                {(['high', 'medium', 'low'] as const).map((priority) => (
                  <TouchableOpacity
                    key={priority}
                    style={[
                      styles.priorityOption,
                      selectedPriority === priority && styles.priorityOptionSelected,
                      selectedPriority === priority && styles[`priorityOption${priority}`],
                    ]}
                    onPress={() => setSelectedPriority(priority)}
                  >
                    <Text
                      style={[
                        styles.priorityOptionText,
                        selectedPriority === priority && styles.priorityOptionTextSelected,
                      ]}
                    >
                      {priority.charAt(0).toUpperCase() + priority.slice(1)}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>
          </ScrollView>
        </SafeAreaView>
      </Modal>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  toggleButton: {
    padding: SPACING.xs,
  },
  mapContainer: {
    flex: 1,
  },
  assignmentsContainer: {
    flex: 1,
  },
  statsRow: {
    flexDirection: 'row',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    gap: SPACING.sm,
  },
  statCard: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
    borderRadius: RADIUS.md,
    padding: SPACING.sm,
    alignItems: 'center',
  },
  statNumber: {
    fontSize: TYPOGRAPHY.xl,
    fontWeight: 'bold',
    color: COLORS.primary,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
  },
  emptyTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginTop: SPACING.md,
  },
  emptySubtitle: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginTop: SPACING.xs,
  },
  assignmentsList: {
    padding: SPACING.md,
  },
  assignmentCard: {
    backgroundColor: COLORS.backgroundSecondary,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
  },
  assignmentHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  priorityBadge: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: 2,
    borderRadius: RADIUS.sm,
  },
  priorityhigh: {
    backgroundColor: '#fee2e2',
  },
  prioritymedium: {
    backgroundColor: '#fef3c7',
  },
  prioritylow: {
    backgroundColor: '#dcfce7',
  },
  priorityText: {
    fontSize: TYPOGRAPHY.xs,
    fontWeight: '600',
    color: COLORS.text.primary,
  },
  unassignButton: {
    padding: SPACING.xs,
  },
  assignmentName: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: '600',
    color: COLORS.text.primary,
  },
  assignmentLocation: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  assignmentMeta: {
    flexDirection: 'row',
    marginTop: SPACING.sm,
    gap: SPACING.md,
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  metaText: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.text.secondary,
  },
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: SPACING.sm,
    gap: SPACING.sm,
  },
  progressBar: {
    flex: 1,
    height: 6,
    backgroundColor: COLORS.border,
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: COLORS.success,
    borderRadius: 3,
  },
  progressText: {
    fontSize: TYPOGRAPHY.xs,
    fontWeight: '600',
    color: COLORS.text.secondary,
    width: 35,
    textAlign: 'right',
  },
  visitsText: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  modalContainer: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  modalTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: '600',
    color: COLORS.text.primary,
  },
  assignButtonText: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: '600',
    color: COLORS.primary,
  },
  modalContent: {
    flex: 1,
    padding: SPACING.md,
  },
  territoryInfo: {
    backgroundColor: COLORS.backgroundSecondary,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    marginBottom: SPACING.lg,
  },
  territoryName: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: 'bold',
    color: COLORS.text.primary,
  },
  territoryLocation: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    marginTop: 4,
  },
  territoryOrg: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.primary,
    marginTop: 4,
  },
  territoryStats: {
    flexDirection: 'row',
    marginTop: SPACING.sm,
    gap: SPACING.lg,
  },
  territoryStat: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  territoryStatText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
  },
  section: {
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginBottom: 4,
  },
  sectionSubtitle: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
  },
  workersScroll: {
    marginTop: SPACING.xs,
  },
  workerChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.backgroundSecondary,
    borderRadius: RADIUS.full,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    marginRight: SPACING.sm,
    gap: 6,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  workerChipSelected: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  workerChipText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
    maxWidth: 100,
  },
  workerChipTextSelected: {
    color: '#fff',
  },
  prioritySelector: {
    flexDirection: 'row',
    gap: SPACING.sm,
  },
  priorityOption: {
    flex: 1,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    backgroundColor: COLORS.backgroundSecondary,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  priorityOptionSelected: {
    borderWidth: 2,
  },
  priorityOptionhigh: {
    borderColor: '#ef4444',
    backgroundColor: '#fee2e2',
  },
  priorityOptionmedium: {
    borderColor: '#f59e0b',
    backgroundColor: '#fef3c7',
  },
  priorityOptionlow: {
    borderColor: '#10b981',
    backgroundColor: '#dcfce7',
  },
  priorityOptionText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: '600',
    color: COLORS.text.secondary,
  },
  priorityOptionTextSelected: {
    color: COLORS.text.primary,
  },
});

export default TeamLeaderTerritoryAssignmentScreen;
