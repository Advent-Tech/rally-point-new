import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  StatusBar,
  Alert,
  RefreshControl,
  TextInput,
  Modal,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { TeamService, Team } from '../services/TeamService';
import { UserManagementService } from '../services/UserManagementService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import Header from '../components/Header';

interface AdminTeamManagementScreenProps {
  navigation: any;
}

interface Worker {
  uid: string;
  displayName: string;
  email: string;
  teamId?: string;
  teamName?: string;
}

const AdminTeamManagementScreen: React.FC<AdminTeamManagementScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [teams, setTeams] = useState<Team[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedTeam, setSelectedTeam] = useState<Team | null>(null);
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [selectedWorker, setSelectedWorker] = useState<Worker | null>(null);

  useEffect(() => {
    loadTeams();
    loadWorkers();
  }, []);

  const loadTeams = async () => {
    try {
      setLoading(true);
      const result = await TeamService.getAllTeams();
      
      if (result.success && result.teams) {
        setTeams(result.teams);
      } else {
        Alert.alert('Error', result.error || 'Failed to load teams');
      }
    } catch (error) {
      console.error('Error loading teams:', error);
      Alert.alert('Error', 'Failed to load teams');
    } finally {
      setLoading(false);
    }
  };

  const loadWorkers = async () => {
    try {
      const result = await UserManagementService.getAllUsers();
      
      if (result.success && result.users) {
        const workersList = result.users.filter(u => u.role === 'worker');
        setWorkers(workersList as Worker[]);
      }
    } catch (error) {
      console.error('Error loading workers:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await Promise.all([loadTeams(), loadWorkers()]);
    setRefreshing(false);
  };

  const handleViewTeam = async (team: Team) => {
    try {
      const result = await TeamService.getTeamWorkers(team.teamId);
      
      if (result.success && result.workers) {
        Alert.alert(
          `Team: ${team.teamName}`,
          `Workers: ${result.workers.length}\n\n${result.workers.map(w => `- ${w.displayName || w.email}`).join('\n')}`,
          [{ text: 'OK' }]
        );
      } else {
        Alert.alert('Error', result.error || 'Failed to load team workers');
      }
    } catch (error) {
      console.error('Error viewing team:', error);
      Alert.alert('Error', 'Failed to load team workers');
    }
  };

  const handleAssignWorker = async () => {
    if (!selectedWorker || !selectedTeam) {
      Alert.alert('Error', 'Please select both a worker and a team');
      return;
    }

    try {
      const result = await TeamService.addWorkerToTeam(
        selectedWorker.uid,
        selectedTeam.teamId,
        selectedTeam.teamName
      );

      if (result.success) {
        Alert.alert('Success', `${selectedWorker.displayName} has been assigned to ${selectedTeam.teamName}`);
        setShowAssignModal(false);
        setSelectedWorker(null);
        setSelectedTeam(null);
        await Promise.all([loadTeams(), loadWorkers()]);
      } else {
        Alert.alert('Error', result.error || 'Failed to assign worker');
      }
    } catch (error) {
      console.error('Error assigning worker:', error);
      Alert.alert('Error', 'Failed to assign worker');
    }
  };

  const filteredTeams = teams.filter(team =>
    team.teamName.toLowerCase().includes(searchQuery.toLowerCase()) ||
    team.leaderName.toLowerCase().includes(searchQuery.toLowerCase()) ||
    team.leaderEmail.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const unassignedWorkers = workers.filter(w => !w.teamId);

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />
      <Header
        showBackButton={true}
        showMenu={false}
        showLogo={false}
        showProfile={true}
        showNotifications={true}
        title="Team Management"
        onBackPress={() => navigation.goBack()}
        onProfilePress={() => navigation.navigate('Profile')}
        onNotificationPress={() => navigation.navigate('Notifications')}
      />

      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {/* Header Section */}
        <View style={styles.headerSection}>
          <View style={styles.sectionHeaderRow}>
            <Text style={styles.sectionTitle}>Team Management</Text>
            <TouchableOpacity
              style={styles.assignButton}
              onPress={() => setShowAssignModal(true)}
            >
              <MaterialIcons name="person-add" size={20} color={COLORS.white} />
              <Text style={styles.assignButtonText}>Assign Worker</Text>
            </TouchableOpacity>
          </View>

          {/* Search Bar */}
          <View style={styles.searchContainer}>
            <MaterialIcons name="search" size={20} color={COLORS.text.secondary} />
            <TextInput
              style={styles.searchInput}
              placeholder="Search teams or leaders..."
              value={searchQuery}
              onChangeText={setSearchQuery}
            />
          </View>

          {/* Stats */}
          <View style={styles.statsGrid}>
            <View style={styles.statCard}>
              <MaterialIcons name="groups" size={32} color={COLORS.primary} />
              <Text style={styles.statValue}>{teams.length}</Text>
              <Text style={styles.statLabel}>Total Teams</Text>
            </View>
            <View style={styles.statCard}>
              <MaterialIcons name="people" size={32} color={COLORS.success} />
              <Text style={styles.statValue}>{workers.length - unassignedWorkers.length}</Text>
              <Text style={styles.statLabel}>Assigned Workers</Text>
            </View>
            <View style={styles.statCard}>
              <MaterialIcons name="person-outline" size={32} color={COLORS.warning} />
              <Text style={styles.statValue}>{unassignedWorkers.length}</Text>
              <Text style={styles.statLabel}>Unassigned</Text>
            </View>
          </View>
        </View>

        {/* Teams List */}
        <View style={styles.teamsSection}>
          <Text style={styles.sectionTitle}>Teams</Text>

          {filteredTeams.length === 0 ? (
            <View style={styles.emptyCard}>
              <MaterialIcons name="groups" size={64} color={COLORS.text.secondary} />
              <Text style={styles.emptyText}>No teams found</Text>
              <Text style={styles.emptySubtext}>
                {searchQuery ? 'Try a different search term' : 'Teams will appear here when created'}
              </Text>
            </View>
          ) : (
            <View style={styles.teamsGrid}>
              {filteredTeams.map((team) => (
                <View key={team.teamId} style={styles.teamCard}>
                  <View style={styles.teamCardHeader}>
                    <View style={[styles.teamIconContainer, { backgroundColor: `${COLORS.primary}15` }]}>
                      <MaterialIcons name="groups" size={32} color={COLORS.primary} />
                    </View>
                  </View>

                  <View style={styles.teamCardContent}>
                    <Text style={styles.teamCardName}>{team.teamName}</Text>
                    
                    <View style={styles.teamCardDetail}>
                      <MaterialIcons name="person" size={16} color={COLORS.text.secondary} />
                      <Text style={styles.teamCardDetailText}>{team.leaderName}</Text>
                    </View>

                    <View style={styles.teamCardDetail}>
                      <MaterialIcons name="email" size={16} color={COLORS.text.secondary} />
                      <Text style={styles.teamCardDetailText}>{team.leaderEmail}</Text>
                    </View>

                    <View style={styles.teamCardDetail}>
                      <MaterialIcons name="people" size={16} color={COLORS.text.secondary} />
                      <Text style={styles.teamCardDetailText}>{team.workerCount} workers</Text>
                    </View>
                  </View>

                  <TouchableOpacity
                    style={styles.viewTeamButton}
                    onPress={() => handleViewTeam(team)}
                  >
                    <Text style={styles.viewTeamButtonText}>View Team</Text>
                    <MaterialIcons name="chevron-right" size={16} color={COLORS.primary} />
                  </TouchableOpacity>
                </View>
              ))}
            </View>
          )}
        </View>
      </ScrollView>

      {/* Assign Worker Modal */}
      <Modal
        visible={showAssignModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowAssignModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Assign Worker to Team</Text>
              <TouchableOpacity onPress={() => setShowAssignModal(false)}>
                <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
            </View>

            <Text style={styles.modalSectionTitle}>Select Worker</Text>
            <ScrollView style={styles.modalList}>
              {unassignedWorkers.map((worker) => (
                <TouchableOpacity
                  key={worker.uid}
                  style={[
                    styles.modalItem,
                    selectedWorker?.uid === worker.uid && styles.modalItemSelected
                  ]}
                  onPress={() => setSelectedWorker(worker)}
                >
                  <Text style={styles.modalItemText}>{worker.displayName}</Text>
                  <Text style={styles.modalItemSubtext}>{worker.email}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>

            <Text style={styles.modalSectionTitle}>Select Team</Text>
            <ScrollView style={styles.modalList}>
              {teams.map((team) => (
                <TouchableOpacity
                  key={team.teamId}
                  style={[
                    styles.modalItem,
                    selectedTeam?.teamId === team.teamId && styles.modalItemSelected
                  ]}
                  onPress={() => setSelectedTeam(team)}
                >
                  <Text style={styles.modalItemText}>{team.teamName}</Text>
                  <Text style={styles.modalItemSubtext}>Leader: {team.leaderName}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>

            <TouchableOpacity
              style={[styles.modalButton, (!selectedWorker || !selectedTeam) && styles.modalButtonDisabled]}
              onPress={handleAssignWorker}
              disabled={!selectedWorker || !selectedTeam}
            >
              <Text style={styles.modalButtonText}>Assign Worker</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F3F4F9',
  },
  content: {
    flex: 1,
  },
  headerSection: {
    backgroundColor: '#f8fafc',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.xl,
    marginBottom: SPACING.md,
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  assignButton: {
    flexDirection: 'row',
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    alignItems: 'center',
    gap: SPACING.xs,
  },
  assignButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    marginBottom: SPACING.lg,
    gap: SPACING.sm,
  },
  searchInput: {
    flex: 1,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
  },
  statsGrid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: SPACING.md,
  },
  statCard: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    ...SHADOWS.sm,
  },
  statValue: {
    fontSize: TYPOGRAPHY.sizes['3xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginTop: SPACING.sm,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  teamsSection: {
    backgroundColor: '#f8fafc',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.xl,
  },
  emptyCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING['2xl'],
    alignItems: 'center',
    ...SHADOWS.sm,
  },
  emptyText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
  },
  emptySubtext: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
    textAlign: 'center',
  },
  teamsGrid: {
    gap: SPACING.md,
  },
  teamCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    ...SHADOWS.sm,
  },
  teamCardHeader: {
    marginBottom: SPACING.md,
  },
  teamIconContainer: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  teamCardContent: {
    marginBottom: SPACING.md,
  },
  teamCardName: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  teamCardDetail: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    marginBottom: SPACING.xs,
  },
  teamCardDetailText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  viewTeamButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: `${COLORS.primary}15`,
    borderRadius: RADIUS.md,
    paddingVertical: SPACING.sm,
    gap: SPACING.xs,
  },
  viewTeamButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.primary,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.lg,
  },
  modalContent: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.xl,
    padding: SPACING.xl,
    width: '100%',
    maxWidth: 500,
    maxHeight: '80%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  modalTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  modalSectionTitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
  },
  modalList: {
    maxHeight: 150,
    marginBottom: SPACING.md,
  },
  modalItem: {
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
    backgroundColor: COLORS.background.secondary,
  },
  modalItemSelected: {
    backgroundColor: `${COLORS.primary}20`,
    borderWidth: 2,
    borderColor: COLORS.primary,
  },
  modalItemText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  modalItemSubtext: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  modalButton: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    paddingVertical: SPACING.md,
    alignItems: 'center',
    marginTop: SPACING.md,
  },
  modalButtonDisabled: {
    opacity: 0.5,
  },
  modalButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },
});

export default AdminTeamManagementScreen;

