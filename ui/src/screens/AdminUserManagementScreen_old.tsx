import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Alert,
  RefreshControl,
  Modal,
  ActivityIndicator,
  StyleSheet
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Picker } from '@react-native-picker/picker';
import { MaterialIcons, FontAwesome } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { UserManagementService } from '../services/UserManagementService';
import { TeamService } from '../services/TeamService';
import TeamListWithWorkers from '../components/TeamListWithWorkers';
import {
  ManagedUser,
  Team,
  UserManagementFilters,
  UserManagementStats,
  UserRole
} from '../types/userManagement';
import { COLORS } from '../constants/Colors';

interface AdminUserManagementScreenProps {
  navigation: any;
}

const AdminUserManagementScreen: React.FC<AdminUserManagementScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState<'users' | 'teams'>('users');
  const [users, setUsers] = useState<ManagedUser[]>([]);
  const [teams, setTeams] = useState<Team[]>([]);
  const [teamsWithWorkers, setTeamsWithWorkers] = useState<any[]>([]);
  const [stats, setStats] = useState<UserManagementStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedRole, setSelectedRole] = useState<UserRole | ''>('');
  const [selectedTeam, setSelectedTeam] = useState<string>('');
  const [showRoleModal, setShowRoleModal] = useState(false);
  const [showTeamModal, setShowTeamModal] = useState(false);
  const [showCreateTeamModal, setShowCreateTeamModal] = useState(false);
  const [showAddWorkerModal, setShowAddWorkerModal] = useState(false);
  const [selectedTeamForWorker, setSelectedTeamForWorker] = useState<any>(null);
  const [selectedUser, setSelectedUser] = useState<ManagedUser | null>(null);
  const [selectedUsers, setSelectedUsers] = useState<string[]>([]);
  const [newRole, setNewRole] = useState<UserRole>('worker');
  const [newTeamName, setNewTeamName] = useState('');
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showSecondDeleteConfirm, setShowSecondDeleteConfirm] = useState(false);
  const [userToDelete, setUserToDelete] = useState<ManagedUser | null>(null);
  const [newTeamDescription, setNewTeamDescription] = useState('');
  const [assignToTeam, setAssignToTeam] = useState<string>('');
  const [workerToAdd, setWorkerToAdd] = useState<string>('');

  useEffect(() => {
    loadInitialData();
    setupRealtimeListeners();
  }, []);

  const loadInitialData = async () => {
    try {
      setLoading(true);

      // Load users, teams, and stats in parallel
      const [usersResponse, teamsResponse, statsResponse] = await Promise.all([
        UserManagementService.getAllUsers(),
        UserManagementService.getAllTeams(),
        UserManagementService.getUserManagementStats()
      ]);

      if (usersResponse.success && usersResponse.data) {
        setUsers(usersResponse.data);
      }

      if (teamsResponse.success && teamsResponse.data) {
        setTeams(teamsResponse.data);
      }

      if (statsResponse.success && statsResponse.data) {
        setStats(statsResponse.data);
      }

      // Load teams with workers for team tab
      await loadTeamsWithWorkers();
    } catch (error) {
      console.error('❌ Error loading initial data:', error);
      Alert.alert('Error', 'Failed to load user management data');
    } finally {
      setLoading(false);
    }
  };

  const loadTeamsWithWorkers = async () => {
    try {
      const result = await TeamService.getAllTeamsWithWorkers();
      if (result.success && result.teams) {
        setTeamsWithWorkers(result.teams);
      }
    } catch (error) {
      console.error('❌ Error loading teams with workers:', error);
    }
  };

  const setupRealtimeListeners = () => {
    // Listen to users changes
    const unsubscribeUsers = UserManagementService.listenToUsers((updatedUsers) => {
      setUsers(updatedUsers);
    });

    // Listen to teams changes
    const unsubscribeTeams = UserManagementService.listenToTeams((updatedTeams) => {
      setTeams(updatedTeams);
    });

    // Listen to stats changes
    const unsubscribeStats = UserManagementService.listenToUserStats((updatedStats) => {
      setStats(updatedStats);
    });

    // Cleanup listeners on unmount
    return () => {
      unsubscribeUsers();
      unsubscribeTeams();
      unsubscribeStats();
    };
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadInitialData();
    setRefreshing(false);
  };

  const getFilteredUsers = () => {
    let filtered = users;

    // Apply search filter
    if (searchQuery.trim()) {
      const searchLower = searchQuery.toLowerCase();
      filtered = filtered.filter(user => 
        user.displayName.toLowerCase().includes(searchLower) ||
        user.email.toLowerCase().includes(searchLower) ||
        (user.teamName && user.teamName.toLowerCase().includes(searchLower))
      );
    }

    // Apply role filter
    if (selectedRole) {
      filtered = filtered.filter(user => user.role === selectedRole);
    }

    // Apply team filter
    if (selectedTeam) {
      filtered = filtered.filter(user => user.teamId === selectedTeam);
    }

    return filtered;
  };

  const handleChangeRole = async () => {
    if (!selectedUser || !user) return;

    try {
      const response = await UserManagementService.updateUserRole(
        selectedUser.uid,
        newRole,
        user.uid,
        `Role changed by admin ${user.displayName || user.email}`
      );

      if (response.success) {
        Alert.alert('Success', response.message || 'User role updated successfully');
        setShowRoleModal(false);
        setSelectedUser(null);
      } else {
        Alert.alert('Error', response.error || 'Failed to update user role');
      }
    } catch (error) {
      console.error('❌ Error changing user role:', error);
      Alert.alert('Error', 'Failed to update user role');
    }
  };

  const handleAssignToTeam = async () => {
    if (!assignToTeam || selectedUsers.length === 0 || !user) return;

    try {
      const response = await UserManagementService.assignUsersToTeam(
        {
          teamId: assignToTeam,
          userIds: selectedUsers
        },
        user.uid
      );

      if (response.success) {
        Alert.alert('Success', response.message || 'Users assigned to team successfully');
        setShowTeamModal(false);
        setSelectedUsers([]);
        setAssignToTeam('');
      } else {
        Alert.alert('Error', response.error || 'Failed to assign users to team');
      }
    } catch (error) {
      console.error('❌ Error assigning users to team:', error);
      Alert.alert('Error', 'Failed to assign users to team');
    }
  };

  const handleCreateTeam = async () => {
    if (!newTeamName.trim() || !user) return;

    try {
      const response = await UserManagementService.createTeam(
        {
          name: newTeamName.trim(),
          description: newTeamDescription.trim() || undefined,
          color: COLORS.primary
        },
        user.uid
      );

      if (response.success) {
        Alert.alert('Success', 'Team created successfully');
        setShowCreateTeamModal(false);
        setNewTeamName('');
        setNewTeamDescription('');
      } else {
        Alert.alert('Error', response.error || 'Failed to create team');
      }
    } catch (error) {
      console.error('❌ Error creating team:', error);
      Alert.alert('Error', 'Failed to create team');
    }
  };

  const handleDeleteUser = (userToDelete: ManagedUser) => {
    setUserToDelete(userToDelete);
    setShowDeleteConfirm(true);
  };

  const handleFirstDeleteConfirm = () => {
    setShowDeleteConfirm(false);
    setShowSecondDeleteConfirm(true);
  };

  const handleFinalDeleteConfirm = async () => {
    if (!userToDelete || !user) return;

    try {
      setShowSecondDeleteConfirm(false);

      const response = await UserManagementService.deleteUserPermanently(
        userToDelete.uid,
        user.uid
      );

      if (response.success) {
        Alert.alert('Success', response.message || `User ${userToDelete.displayName} has been permanently deleted`);
        setUserToDelete(null);
        await loadInitialData(); // Reload users list
      } else {
        Alert.alert('Error', response.error || 'Failed to delete user');
      }
    } catch (error) {
      console.error('❌ Error deleting user:', error);
      Alert.alert('Error', 'Failed to delete user permanently');
    }
  };

  const handleCancelDelete = () => {
    setShowDeleteConfirm(false);
    setShowSecondDeleteConfirm(false);
    setUserToDelete(null);
  };

  const handlePromoteToLeader = async (userId: string, teamId: string) => {
    if (!user) return;

    Alert.alert(
      'Promote to Team Leader',
      'Are you sure you want to promote this user to team leader?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Promote',
          style: 'default',
          onPress: async () => {
            try {
              const response = await UserManagementService.promoteToTeamLeader(
                userId,
                teamId,
                user.uid
              );

              if (response.success) {
                Alert.alert('Success', response.message || 'User promoted to team leader');
              } else {
                Alert.alert('Error', response.error || 'Failed to promote user');
              }
            } catch (error) {
              console.error('❌ Error promoting user:', error);
              Alert.alert('Error', 'Failed to promote user');
            }
          }
        }
      ]
    );
  };

  // Team Management Handlers
  const handleAddWorkerToTeam = (team: any) => {
    setSelectedTeamForWorker(team);
    setShowAddWorkerModal(true);
  };

  const handleConfirmAddWorker = async () => {
    if (!workerToAdd || !selectedTeamForWorker || !user) return;

    try {
      const response = await UserManagementService.assignUserToTeam(
        workerToAdd,
        selectedTeamForWorker.teamId,
        user.uid
      );

      if (response.success) {
        Alert.alert('Success', 'Worker added to team successfully');
        setShowAddWorkerModal(false);
        setWorkerToAdd('');
        setSelectedTeamForWorker(null);
        await loadTeamsWithWorkers();
      } else {
        Alert.alert('Error', response.error || 'Failed to add worker to team');
      }
    } catch (error) {
      console.error('❌ Error adding worker to team:', error);
      Alert.alert('Error', 'Failed to add worker to team');
    }
  };

  const handleRemoveWorkerFromTeam = async (worker: any, team: any) => {
    if (!user) return;

    try {
      const response = await UserManagementService.removeUserFromTeam(
        worker.uid,
        user.uid
      );

      if (response.success) {
        Alert.alert('Success', 'Worker removed from team successfully');
        await loadTeamsWithWorkers();
      } else {
        Alert.alert('Error', response.error || 'Failed to remove worker from team');
      }
    } catch (error) {
      console.error('❌ Error removing worker from team:', error);
      Alert.alert('Error', 'Failed to remove worker from team');
    }
  };

  const handleEditTeam = (team: any) => {
    // TODO: Implement team editing
    Alert.alert('Edit Team', 'Team editing feature coming soon');
  };

  const handleDeleteTeam = (team: any) => {
    // TODO: Implement team deletion
    Alert.alert('Delete Team', 'Team deletion feature coming soon');
  };

  const toggleUserSelection = (userId: string) => {
    setSelectedUsers(prev => 
      prev.includes(userId) 
        ? prev.filter(id => id !== userId)
        : [...prev, userId]
    );
  };

  const getRoleColor = (role: UserRole) => {
    switch (role) {
      case 'admin': return '#dc2626';
      case 'team_leader': return '#d97706';
      case 'worker': return '#059669';
      default: return '#6b7280';
    }
  };

  const getRoleBadge = (role: UserRole) => {
    const color = getRoleColor(role);
    const label = role.replace('_', ' ').toUpperCase();
    
    return (
      <View style={[styles.roleBadge, { backgroundColor: color }]}>
        <Text style={styles.roleBadgeText}>{label}</Text>
      </View>
    );
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading user management...</Text>
        </View>
      </SafeAreaView>
    );
  }

  const filteredUsers = getFilteredUsers();

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity
          style={styles.backButton}
          onPress={() => navigation.goBack()}
        >
          <MaterialIcons name="arrow-back" size={24} color={COLORS.text} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>User Management</Text>
        <TouchableOpacity
          style={styles.createButton}
          onPress={() => setShowCreateTeamModal(true)}
        >
          <MaterialIcons name="add" size={24} color={COLORS.primary} />
        </TouchableOpacity>
      </View>

      {/* Statistics Cards */}
      {stats && (
        <View style={styles.statsContainer}>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{stats.totalUsers}</Text>
            <Text style={styles.statLabel}>Total Users</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{stats.onlineUsers}</Text>
            <Text style={styles.statLabel}>Online</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{stats.totalTeams}</Text>
            <Text style={styles.statLabel}>Teams</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{stats.usersWithoutTeam}</Text>
            <Text style={styles.statLabel}>No Team</Text>
          </View>
        </View>
      )}

      {/* Tab Navigation */}
      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'users' && styles.activeTab]}
          onPress={() => setActiveTab('users')}
        >
          <MaterialIcons
            name="people"
            size={20}
            color={activeTab === 'users' ? COLORS.primary : COLORS.textSecondary}
          />
          <Text style={[styles.tabText, activeTab === 'users' && styles.activeTabText]}>
            Users
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'teams' && styles.activeTab]}
          onPress={() => setActiveTab('teams')}
        >
          <MaterialIcons
            name="groups"
            size={20}
            color={activeTab === 'teams' ? COLORS.primary : COLORS.textSecondary}
          />
          <Text style={[styles.tabText, activeTab === 'teams' && styles.activeTabText]}>
            Teams
          </Text>
        </TouchableOpacity>
      </View>

      {/* Search and Filters - Only show for users tab */}
      {activeTab === 'users' && (
        <View style={styles.filtersContainer}>
        <View style={styles.searchContainer}>
          <MaterialIcons name="search" size={20} color={COLORS.textSecondary} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search users..."
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholderTextColor={COLORS.textSecondary}
          />
        </View>

        <View style={styles.filterRow}>
          <View style={styles.filterItem}>
            <Text style={styles.filterLabel}>Role:</Text>
            <Picker
              selectedValue={selectedRole}
              onValueChange={setSelectedRole}
              style={styles.picker}
            >
              <Picker.Item label="All Roles" value="" />
              <Picker.Item label="Admin" value="admin" />
              <Picker.Item label="Team Leader" value="team_leader" />
              <Picker.Item label="Worker" value="worker" />
            </Picker>
          </View>

          <View style={styles.filterItem}>
            <Text style={styles.filterLabel}>Team:</Text>
            <Picker
              selectedValue={selectedTeam}
              onValueChange={setSelectedTeam}
              style={styles.picker}
            >
              <Picker.Item label="All Teams" value="" />
              {teams.map(team => (
                <Picker.Item key={team.id} label={team.name} value={team.id} />
              ))}
            </Picker>
          </View>
        </View>
      </View>

      {/* Users Tab Content */}
      {activeTab === 'users' && (
        <>
          {/* Action Buttons */}
          <View style={styles.actionButtonsContainer}>
            <TouchableOpacity
              style={[styles.actionButton, { opacity: selectedUsers.length > 0 ? 1 : 0.5 }]}
              onPress={() => selectedUsers.length > 0 && setShowTeamModal(true)}
              disabled={selectedUsers.length === 0}
            >
              <MaterialIcons name="group-add" size={20} color="white" />
              <Text style={styles.actionButtonText}>Assign to Team ({selectedUsers.length})</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.clearButton}
              onPress={() => setSelectedUsers([])}
            >
              <Text style={styles.clearButtonText}>Clear Selection</Text>
            </TouchableOpacity>
          </View>

          {/* Users List */}
          <ScrollView
            style={styles.usersList}
            refreshControl={
              <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
            }
          >
        {filteredUsers.map((user) => (
          <View key={user.uid} style={styles.userCard}>
            <View style={styles.userCardHeader}>
              <TouchableOpacity
                style={styles.checkbox}
                onPress={() => toggleUserSelection(user.uid)}
              >
                <MaterialIcons
                  name={selectedUsers.includes(user.uid) ? "check-box" : "check-box-outline-blank"}
                  size={24}
                  color={selectedUsers.includes(user.uid) ? COLORS.primary : COLORS.textSecondary}
                />
              </TouchableOpacity>

              <View style={styles.userInfo}>
                <View style={styles.userNameRow}>
                  <Text style={styles.userName}>{user.displayName}</Text>
                  {user.isOnline && (
                    <View style={styles.onlineIndicator} />
                  )}
                </View>
                <Text style={styles.userEmail}>{user.email}</Text>
                {user.teamName && (
                  <Text style={styles.userTeam}>Team: {user.teamName}</Text>
                )}
              </View>

              <View style={styles.userActions}>
                {getRoleBadge(user.role)}
                <TouchableOpacity
                  style={styles.actionIcon}
                  onPress={() => {
                    setSelectedUser(user);
                    setNewRole(user.role);
                    setShowRoleModal(true);
                  }}
                >
                  <MaterialIcons name="edit" size={20} color={COLORS.primary} />
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.actionIcon, styles.deleteIcon]}
                  onPress={() => handleDeleteUser(user)}
                >
                  <MaterialIcons name="delete" size={20} color={COLORS.error} />
                </TouchableOpacity>
              </View>
            </View>

            {user.teamId && user.role !== 'team_leader' && (
              <TouchableOpacity
                style={styles.promoteButton}
                onPress={() => handlePromoteToLeader(user.uid, user.teamId)}
              >
                <MaterialIcons name="trending-up" size={16} color={COLORS.secondary} />
                <Text style={styles.promoteButtonText}>Promote to Leader</Text>
              </TouchableOpacity>
            )}
          </View>
        ))}

        {filteredUsers.length === 0 && (
          <View style={styles.emptyState}>
            <MaterialIcons name="people-outline" size={64} color={COLORS.textSecondary} />
            <Text style={styles.emptyStateText}>No users found</Text>
            <Text style={styles.emptyStateSubtext}>
              {searchQuery || selectedRole || selectedTeam
                ? 'Try adjusting your filters'
                : 'Users will appear here when they sign up'
              }
            </Text>
          </View>
        )}
      </ScrollView>
        </>
      )}

      {/* Teams Tab Content */}
      {activeTab === 'teams' && (
        <View style={{ flex: 1 }}>
          <TeamListWithWorkers
            teams={teamsWithWorkers}
            onRefresh={loadTeamsWithWorkers}
            onAddWorker={handleAddWorkerToTeam}
            onRemoveWorker={handleRemoveWorkerFromTeam}
            onEditTeam={handleEditTeam}
            onDeleteTeam={handleDeleteTeam}
          />
        </View>
      )}

      {/* Add Worker to Team Modal */}
      <Modal
        visible={showAddWorkerModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowAddWorkerModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Add Worker to Team</Text>
            {selectedTeamForWorker && (
              <Text style={styles.modalSubtitle}>
                Team: {selectedTeamForWorker.teamName}
              </Text>
            )}

            <View style={styles.modalSection}>
              <Text style={styles.modalLabel}>Select Worker:</Text>
              <Picker
                selectedValue={workerToAdd}
                onValueChange={setWorkerToAdd}
                style={styles.modalPicker}
              >
                <Picker.Item label="Select a worker..." value="" />
                {users
                  .filter(u => !u.teamId || u.teamId !== selectedTeamForWorker?.teamId)
                  .map(user => (
                    <Picker.Item
                      key={user.uid}
                      label={`${user.displayName} (${user.email})`}
                      value={user.uid}
                    />
                  ))}
              </Picker>
            </View>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={() => {
                  setShowAddWorkerModal(false);
                  setWorkerToAdd('');
                  setSelectedTeamForWorker(null);
                }}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalConfirmButton, { opacity: workerToAdd ? 1 : 0.5 }]}
                onPress={handleConfirmAddWorker}
                disabled={!workerToAdd}
              >
                <Text style={styles.modalConfirmText}>Add Worker</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Role Change Modal */}
      <Modal
        visible={showRoleModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowRoleModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Change User Role</Text>
            {selectedUser && (
              <Text style={styles.modalSubtitle}>
                {selectedUser.displayName} ({selectedUser.email})
              </Text>
            )}

            <View style={styles.modalSection}>
              <Text style={styles.modalLabel}>New Role:</Text>
              <Picker
                selectedValue={newRole}
                onValueChange={setNewRole}
                style={styles.modalPicker}
              >
                <Picker.Item label="Worker" value="worker" />
                <Picker.Item label="Team Leader" value="team_leader" />
                <Picker.Item label="Admin" value="admin" />
              </Picker>
            </View>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={() => setShowRoleModal(false)}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.modalConfirmButton}
                onPress={handleChangeRole}
              >
                <Text style={styles.modalConfirmText}>Change Role</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Team Assignment Modal */}
      <Modal
        visible={showTeamModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowTeamModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Assign to Team</Text>
            <Text style={styles.modalSubtitle}>
              {selectedUsers.length} user(s) selected
            </Text>

            <View style={styles.modalSection}>
              <Text style={styles.modalLabel}>Select Team:</Text>
              <Picker
                selectedValue={assignToTeam}
                onValueChange={setAssignToTeam}
                style={styles.modalPicker}
              >
                <Picker.Item label="Select a team..." value="" />
                {teams.map(team => (
                  <Picker.Item key={team.id} label={team.name} value={team.id} />
                ))}
              </Picker>
            </View>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={() => setShowTeamModal(false)}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalConfirmButton, { opacity: assignToTeam ? 1 : 0.5 }]}
                onPress={handleAssignToTeam}
                disabled={!assignToTeam}
              >
                <Text style={styles.modalConfirmText}>Assign</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Create Team Modal */}
      <Modal
        visible={showCreateTeamModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowCreateTeamModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Create New Team</Text>

            <View style={styles.modalSection}>
              <Text style={styles.modalLabel}>Team Name:</Text>
              <TextInput
                style={styles.modalInput}
                placeholder="Enter team name..."
                value={newTeamName}
                onChangeText={setNewTeamName}
                placeholderTextColor={COLORS.textSecondary}
              />
            </View>

            <View style={styles.modalSection}>
              <Text style={styles.modalLabel}>Description (Optional):</Text>
              <TextInput
                style={[styles.modalInput, styles.modalTextArea]}
                placeholder="Enter team description..."
                value={newTeamDescription}
                onChangeText={setNewTeamDescription}
                multiline
                numberOfLines={3}
                placeholderTextColor={COLORS.textSecondary}
              />
            </View>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={() => setShowCreateTeamModal(false)}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalConfirmButton, { opacity: newTeamName.trim() ? 1 : 0.5 }]}
                onPress={handleCreateTeam}
                disabled={!newTeamName.trim()}
              >
                <Text style={styles.modalConfirmText}>Create Team</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* First Delete Confirmation Modal */}
      <Modal
        visible={showDeleteConfirm}
        transparent
        animationType="fade"
        onRequestClose={handleCancelDelete}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <MaterialIcons name="warning" size={48} color={COLORS.error} style={{ alignSelf: 'center', marginBottom: 16 }} />
            <Text style={styles.modalTitle}>Delete User?</Text>
            {userToDelete && (
              <Text style={styles.modalSubtitle}>
                {userToDelete.displayName} ({userToDelete.email})
              </Text>
            )}
            <Text style={styles.deleteWarningText}>
              Are you sure you want to delete this user? This action cannot be undone.
            </Text>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={handleCancelDelete}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.modalDeleteButton}
                onPress={handleFirstDeleteConfirm}
              >
                <Text style={styles.modalDeleteText}>Continue</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Second Delete Confirmation Modal */}
      <Modal
        visible={showSecondDeleteConfirm}
        transparent
        animationType="fade"
        onRequestClose={handleCancelDelete}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <MaterialIcons name="error" size={48} color={COLORS.error} style={{ alignSelf: 'center', marginBottom: 16 }} />
            <Text style={styles.modalTitle}>Final Confirmation</Text>
            {userToDelete && (
              <Text style={styles.modalSubtitle}>
                Please confirm again. This will permanently delete {userToDelete.displayName} and all their data.
              </Text>
            )}
            <Text style={[styles.deleteWarningText, { fontWeight: 'bold', color: COLORS.error }]}>
              This action is PERMANENT and CANNOT be undone!
            </Text>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={handleCancelDelete}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.modalDeleteButton}
                onPress={handleFinalDeleteConfirm}
              >
                <Text style={styles.modalDeleteText}>Delete Permanently</Text>
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
  createButton: {
    padding: 8,
  },
  statsContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 12,
  },
  statCard: {
    flex: 1,
    backgroundColor: 'white',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  statNumber: {
    fontSize: 24,
    fontWeight: 'bold',
    color: COLORS.primary,
  },
  statLabel: {
    fontSize: 12,
    color: COLORS.textSecondary,
    marginTop: 4,
  },
  roleBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  roleBadgeText: {
    color: 'white',
    fontSize: 10,
    fontWeight: '600',
  },
  filtersContainer: {
    backgroundColor: 'white',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginBottom: 12,
  },
  searchInput: {
    flex: 1,
    marginLeft: 8,
    fontSize: 16,
    color: COLORS.text,
  },
  filterRow: {
    flexDirection: 'row',
    gap: 12,
  },
  filterItem: {
    flex: 1,
  },
  filterLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.text,
    marginBottom: 4,
  },
  picker: {
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
  },
  actionButtonsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
    gap: 12,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.primary,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    gap: 8,
  },
  actionButtonText: {
    color: 'white',
    fontSize: 14,
    fontWeight: '600',
  },
  clearButton: {
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  clearButtonText: {
    color: COLORS.primary,
    fontSize: 14,
    fontWeight: '500',
  },
  usersList: {
    flex: 1,
    paddingHorizontal: 16,
  },
  userCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginVertical: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  userCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    marginRight: 12,
  },
  userInfo: {
    flex: 1,
  },
  userNameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  userName: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  onlineIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#10b981',
  },
  userEmail: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 2,
  },
  userTeam: {
    fontSize: 12,
    color: COLORS.primary,
    marginTop: 4,
    fontWeight: '500',
  },
  userActions: {
    alignItems: 'center',
    gap: 8,
  },
  actionIcon: {
    padding: 8,
  },
  deleteIcon: {
    marginLeft: 4,
  },
  promoteButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 12,
    paddingVertical: 8,
    paddingHorizontal: 12,
    backgroundColor: '#fef3c7',
    borderRadius: 6,
    gap: 4,
  },
  promoteButtonText: {
    fontSize: 12,
    color: COLORS.secondary,
    fontWeight: '500',
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
    textAlign: 'center',
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
    maxWidth: 400,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: 8,
  },
  modalSubtitle: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: 24,
  },
  modalSection: {
    marginBottom: 20,
  },
  modalLabel: {
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.text,
    marginBottom: 8,
  },
  modalPicker: {
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
  },
  modalInput: {
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    color: COLORS.text,
  },
  modalTextArea: {
    height: 80,
    textAlignVertical: 'top',
  },
  modalButtons: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 8,
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
  modalDeleteButton: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    backgroundColor: COLORS.error,
    alignItems: 'center',
  },
  modalDeleteText: {
    fontSize: 16,
    color: 'white',
    fontWeight: '600',
  },
  deleteWarningText: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginTop: 12,
    marginBottom: 16,
    lineHeight: 20,
  },
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    gap: 8,
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  activeTab: {
    borderBottomColor: COLORS.primary,
  },
  tabText: {
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.textSecondary,
  },
  activeTabText: {
    color: COLORS.primary,
    fontWeight: '600',
  },
});

export default AdminUserManagementScreen;
