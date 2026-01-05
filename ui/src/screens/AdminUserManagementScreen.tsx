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

  // ... rest of your component code ...

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

      {activeTab === 'users' ? (
        <>
          {/* Search and Filters */}
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
        </>
      ) : (
        <TeamListWithWorkers 
          teams={teamsWithWorkers} 
          onAddWorker={handleAddWorkerToTeam}
          onRemoveWorker={handleRemoveWorkerFromTeam}
        />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  // ... your existing styles ...
});

export default AdminUserManagementScreen;
