import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { authService } from './authService';
import {
  ManagedUser,
  Team,
  TeamMember,
  TeamAssignment,
  RoleChangeRequest,
  UserManagementFilters,
  UserManagementStats,
  BulkUserOperation,
  BulkOperationResult,
  CreateTeamFormData,
  AssignTeamFormData,
  ChangeRoleFormData,
  UserManagementApiResponse,
  UserStatusUpdate,
  TeamUpdate,
  UserManagementActivity,
  UserRole
} from '../types/userManagement';

const STORAGE_KEYS = {
  USERS: '@rally_point_users',
  TEAMS: '@rally_point_teams',
  TEAM_ASSIGNMENTS: '@rally_point_team_assignments',
  ACTIVITY_LOG: '@rally_point_activity_log',
};

export class UserManagementService {
  private static getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  // User Management Methods

  /**
   * Get user profile by ID
   */
  static async getUserProfile(userId: string): Promise<UserManagementApiResponse<ManagedUser>> {
    try {
      // Try API first
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/users/${userId}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (response.ok) {
          const data = await response.json();
          return { success: true, data };
        }
      }

      // Fallback to local storage
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      const users: ManagedUser[] = stored ? JSON.parse(stored) : [];
      const user = users.find(u => u.uid === userId);

      if (!user) {
        return { success: false, error: 'User not found' };
      }

      return { success: true, data: user };
    } catch (error) {
      console.error('Error fetching user profile:', error);
      return { success: false, error: 'Failed to fetch user profile' };
    }
  }

  /**
   * Get all users with optional filtering
   */
  static async getAllUsers(filters?: UserManagementFilters): Promise<UserManagementApiResponse<ManagedUser[]>> {
    try {
      // Try API first
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/users`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (response.ok) {
          let users: ManagedUser[] = await response.json();

          // Apply filters
          if (filters?.role) {
            users = users.filter(u => u.role === filters.role);
          }
          if (filters?.status) {
            users = users.filter(u => u.status === filters.status);
          }
          if (filters?.teamId) {
            users = users.filter(u => u.teamId === filters.teamId);
          }
          if (filters?.searchQuery) {
            const search = filters.searchQuery.toLowerCase();
            users = users.filter(u =>
              u.displayName.toLowerCase().includes(search) ||
              u.email.toLowerCase().includes(search)
            );
          }

          // Sort
          const sortField = filters?.sortBy || 'createdAt';
          const sortDir = filters?.sortOrder === 'asc' ? 1 : -1;
          users.sort((a, b) => {
            const aVal = a[sortField as keyof ManagedUser];
            const bVal = b[sortField as keyof ManagedUser];
            if (aVal instanceof Date && bVal instanceof Date) {
              return sortDir * (aVal.getTime() - bVal.getTime());
            }
            return sortDir * String(aVal).localeCompare(String(bVal));
          });

          await AsyncStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));
          return { success: true, data: users };
        }
      }

      // Fallback to local storage
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      let users: ManagedUser[] = stored ? JSON.parse(stored) : [];

      // Apply filters
      if (filters?.role) {
        users = users.filter(u => u.role === filters.role);
      }
      if (filters?.status) {
        users = users.filter(u => u.status === filters.status);
      }
      if (filters?.teamId) {
        users = users.filter(u => u.teamId === filters.teamId);
      }
      if (filters?.searchQuery) {
        const search = filters.searchQuery.toLowerCase();
        users = users.filter(u =>
          u.displayName.toLowerCase().includes(search) ||
          u.email.toLowerCase().includes(search)
        );
      }

      return { success: true, data: users };
    } catch (error) {
      console.error('❌ Error fetching users:', error);
      return { success: false, error: 'Failed to fetch users' };
    }
  }

  /**
   * Get user by ID
   */
  static async getUserById(userId: string): Promise<UserManagementApiResponse<ManagedUser>> {
    return this.getUserProfile(userId);
  }

  /**
   * Update user role
   */
  static async updateUserRole(
    userId: string,
    newRole: UserRole,
    adminId: string,
    reason?: string
  ): Promise<UserManagementApiResponse<void>> {
    try {
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/users/${userId}/role`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({ role: newRole, reason }),
        });
        if (response.ok) {
          await this.logActivity({
            type: 'role_changed',
            performedBy: { uid: adminId, name: 'Admin', email: '' },
            targetUser: { uid: userId, name: '', email: '' },
            details: { newRole, reason },
            timestamp: new Date(),
          });
          return { success: true, message: `User role updated to ${newRole}` };
        }
      }

      // Fallback to local update
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      const users: ManagedUser[] = stored ? JSON.parse(stored) : [];
      const index = users.findIndex(u => u.uid === userId);

      if (index === -1) {
        return { success: false, error: 'User not found' };
      }

      users[index].role = newRole;
      users[index].updatedAt = new Date();
      await AsyncStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));

      return { success: true, message: `User role updated to ${newRole}` };
    } catch (error) {
      console.error('❌ Error updating user role:', error);
      return { success: false, error: 'Failed to update user role' };
    }
  }

  /**
   * Permanently delete a user (Admin only)
   */
  static async deleteUserPermanently(
    userId: string,
    adminId: string
  ): Promise<UserManagementApiResponse<void>> {
    try {
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/users/${userId}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${token}` },
        });
        if (response.ok) {
          return { success: true, message: 'User deleted successfully' };
        }
      }

      // Fallback to local delete
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      const users: ManagedUser[] = stored ? JSON.parse(stored) : [];
      const filtered = users.filter(u => u.uid !== userId);
      await AsyncStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(filtered));

      return { success: true, message: 'User deleted successfully' };
    } catch (error) {
      console.error('❌ Error deleting user:', error);
      return { success: false, error: 'Failed to delete user permanently' };
    }
  }

  /**
   * Create or update user profile (called on login)
   */
  static async createOrUpdateUserProfile(
    userId: string,
    email: string,
    displayName?: string,
    role?: UserRole,
    teamId?: string,
    teamName?: string
  ): Promise<UserManagementApiResponse<ManagedUser>> {
    try {
      const now = new Date();
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      const users: ManagedUser[] = stored ? JSON.parse(stored) : [];
      const existingIndex = users.findIndex(u => u.uid === userId);

      const userData: ManagedUser = {
        uid: userId,
        email,
        displayName: displayName || email.split('@')[0],
        role: role || 'worker',
        isOnline: true,
        lastActiveAt: now,
        createdAt: existingIndex >= 0 ? users[existingIndex].createdAt : now,
        updatedAt: now,
        status: 'active',
        permissions: [],
        teamId,
        teamName,
      };

      if (existingIndex >= 0) {
        // Preserve existing team data if not provided
        if (!teamId && users[existingIndex].teamId) {
          userData.teamId = users[existingIndex].teamId;
          userData.teamName = users[existingIndex].teamName;
        }
        users[existingIndex] = { ...users[existingIndex], ...userData };
      } else {
        users.push(userData);
      }

      await AsyncStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));

      // Try to sync to backend
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        await fetch(`${apiBase}/api/users/${userId}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify(userData),
        }).catch(() => {});
      }

      return {
        success: true,
        data: userData,
        message: existingIndex >= 0 ? 'User profile updated' : 'User profile created'
      };
    } catch (error) {
      console.error('❌ Error creating/updating user profile:', error);
      return { success: false, error: 'Failed to create/update user profile' };
    }
  }

  /**
   * Update user online status
   */
  static async updateUserStatus(userId: string, isOnline: boolean): Promise<void> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      const users: ManagedUser[] = stored ? JSON.parse(stored) : [];
      const index = users.findIndex(u => u.uid === userId);

      if (index >= 0) {
        users[index].isOnline = isOnline;
        users[index].lastActiveAt = new Date();
        users[index].updatedAt = new Date();
        await AsyncStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));
      }
    } catch (error) {
      console.error('❌ Error updating user status:', error);
    }
  }

  /**
   * Get user management statistics
   */
  static async getUserManagementStats(): Promise<UserManagementApiResponse<UserManagementStats>> {
    try {
      const usersResult = await this.getAllUsers();
      const teamsResult = await this.getAllTeams();

      const users = usersResult.data || [];
      const teams = teamsResult.data || [];

      const oneWeekAgo = new Date();
      oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

      const stats: UserManagementStats = {
        totalUsers: users.length,
        activeUsers: users.filter(u => u.status === 'active').length,
        onlineUsers: users.filter(u => u.isOnline).length,
        usersByRole: {
          admin: users.filter(u => u.role === 'admin').length,
          team_leader: users.filter(u => u.role === 'team_leader').length,
          worker: users.filter(u => u.role === 'worker').length,
        },
        totalTeams: teams.length,
        activeTeams: teams.filter(t => t.isActive).length,
        usersWithoutTeam: users.filter(u => !u.teamId).length,
        recentSignups: users.filter(u => new Date(u.createdAt) > oneWeekAgo).length,
      };

      return { success: true, data: stats };
    } catch (error) {
      console.error('❌ Error fetching user management stats:', error);
      return { success: false, error: 'Failed to fetch statistics' };
    }
  }

  // Team Management Methods

  /**
   * Get all teams
   */
  static async getAllTeams(): Promise<UserManagementApiResponse<Team[]>> {
    try {
      const token = await authService.getValidToken();
      if (token) {
        const apiBase = this.getApiBase();
        const response = await fetch(`${apiBase}/api/teams`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (response.ok) {
          const teams = await response.json();
          await AsyncStorage.setItem(STORAGE_KEYS.TEAMS, JSON.stringify(teams));
          return { success: true, data: teams };
        }
      }

      // Fallback to local storage
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.TEAMS);
      const teams: Team[] = stored ? JSON.parse(stored) : [];
      return { success: true, data: teams };
    } catch (error) {
      console.error('❌ Error fetching teams:', error);
      return { success: false, error: 'Failed to fetch teams' };
    }
  }

  /**
   * Get team by ID
   */
  static async getTeam(teamId: string): Promise<UserManagementApiResponse<Team>> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.TEAMS);
      const teams: Team[] = stored ? JSON.parse(stored) : [];
      const team = teams.find(t => t.id === teamId);

      if (!team) {
        return { success: false, error: 'Team not found' };
      }

      return { success: true, data: team };
    } catch (error) {
      console.error('❌ Error fetching team:', error);
      return { success: false, error: 'Failed to fetch team' };
    }
  }

  /**
   * Create a new team
   */
  static async createTeam(
    teamData: CreateTeamFormData,
    adminId: string
  ): Promise<UserManagementApiResponse<Team>> {
    try {
      const now = new Date();
      const id = `team_${Date.now()}`;

      const team: Team = {
        id,
        name: teamData.name,
        description: teamData.description || '',
        leaderId: teamData.leaderId || null,
        leaderName: null,
        leaderEmail: null,
        memberIds: teamData.leaderId ? [teamData.leaderId] : [],
        memberCount: teamData.leaderId ? 1 : 0,
        createdAt: now,
        updatedAt: now,
        isActive: true,
        color: teamData.color || '#002b5b',
      };

      // If leader specified, update their role
      if (teamData.leaderId) {
        const usersStored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
        const users: ManagedUser[] = usersStored ? JSON.parse(usersStored) : [];
        const leaderIndex = users.findIndex(u => u.uid === teamData.leaderId);

        if (leaderIndex >= 0) {
          team.leaderName = users[leaderIndex].displayName;
          team.leaderEmail = users[leaderIndex].email;
          users[leaderIndex].role = 'team_leader';
          users[leaderIndex].teamId = id;
          users[leaderIndex].teamName = team.name;
          await AsyncStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));
        }
      }

      const stored = await AsyncStorage.getItem(STORAGE_KEYS.TEAMS);
      const teams: Team[] = stored ? JSON.parse(stored) : [];
      teams.push(team);
      await AsyncStorage.setItem(STORAGE_KEYS.TEAMS, JSON.stringify(teams));

      return { success: true, data: team, message: 'Team created successfully' };
    } catch (error) {
      console.error('❌ Error creating team:', error);
      return { success: false, error: 'Failed to create team' };
    }
  }

  /**
   * Assign users to a team
   */
  static async assignUsersToTeam(
    assignmentData: AssignTeamFormData,
    adminId: string
  ): Promise<UserManagementApiResponse<void>> {
    try {
      const teamsStored = await AsyncStorage.getItem(STORAGE_KEYS.TEAMS);
      const teams: Team[] = teamsStored ? JSON.parse(teamsStored) : [];
      const teamIndex = teams.findIndex(t => t.id === assignmentData.teamId);

      if (teamIndex === -1) {
        return { success: false, error: 'Team not found' };
      }

      const team = teams[teamIndex];
      const newMemberIds = [...new Set([...team.memberIds, ...assignmentData.userIds])];
      teams[teamIndex].memberIds = newMemberIds;
      teams[teamIndex].memberCount = newMemberIds.length;
      teams[teamIndex].updatedAt = new Date();

      await AsyncStorage.setItem(STORAGE_KEYS.TEAMS, JSON.stringify(teams));

      // Update users
      const usersStored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      const users: ManagedUser[] = usersStored ? JSON.parse(usersStored) : [];

      for (const userId of assignmentData.userIds) {
        const userIndex = users.findIndex(u => u.uid === userId);
        if (userIndex >= 0) {
          users[userIndex].teamId = assignmentData.teamId;
          users[userIndex].teamName = team.name;
          users[userIndex].teamLeaderId = team.leaderId || undefined;
          users[userIndex].teamLeaderName = team.leaderName || undefined;
          users[userIndex].updatedAt = new Date();
        }
      }

      await AsyncStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));

      return { success: true, message: `${assignmentData.userIds.length} users assigned to team` };
    } catch (error) {
      console.error('❌ Error assigning users to team:', error);
      return { success: false, error: 'Failed to assign users to team' };
    }
  }

  /**
   * Promote user to team leader
   */
  static async promoteToTeamLeader(
    userId: string,
    teamId: string,
    adminId: string
  ): Promise<UserManagementApiResponse<void>> {
    try {
      const usersStored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      const users: ManagedUser[] = usersStored ? JSON.parse(usersStored) : [];

      const teamsStored = await AsyncStorage.getItem(STORAGE_KEYS.TEAMS);
      const teams: Team[] = teamsStored ? JSON.parse(teamsStored) : [];

      const userIndex = users.findIndex(u => u.uid === userId);
      const teamIndex = teams.findIndex(t => t.id === teamId);

      if (userIndex === -1 || teamIndex === -1) {
        return { success: false, error: 'User or team not found' };
      }

      // Demote current leader if exists
      if (teams[teamIndex].leaderId) {
        const currentLeaderIndex = users.findIndex(u => u.uid === teams[teamIndex].leaderId);
        if (currentLeaderIndex >= 0) {
          users[currentLeaderIndex].role = 'worker';
          users[currentLeaderIndex].updatedAt = new Date();
        }
      }

      // Promote new leader
      users[userIndex].role = 'team_leader';
      users[userIndex].teamId = teamId;
      users[userIndex].teamName = teams[teamIndex].name;
      users[userIndex].updatedAt = new Date();

      // Update team
      teams[teamIndex].leaderId = userId;
      teams[teamIndex].leaderName = users[userIndex].displayName;
      teams[teamIndex].leaderEmail = users[userIndex].email;
      teams[teamIndex].updatedAt = new Date();

      await AsyncStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));
      await AsyncStorage.setItem(STORAGE_KEYS.TEAMS, JSON.stringify(teams));

      return { success: true, message: 'User promoted to team leader' };
    } catch (error) {
      console.error('❌ Error promoting user:', error);
      return { success: false, error: 'Failed to promote user' };
    }
  }

  // Real-time Listeners (polling-based)

  /**
   * Listen to all users changes
   */
  static listenToUsers(
    callback: (users: ManagedUser[]) => void,
    filters?: UserManagementFilters
  ): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const result = await this.getAllUsers(filters);
      if (result.success && result.data) {
        callback(result.data);
      }
    };

    poll();
    intervalId = setInterval(poll, 10000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  /**
   * Listen to all teams changes
   */
  static listenToTeams(callback: (teams: Team[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const result = await this.getAllTeams();
      if (result.success && result.data) {
        callback(result.data);
      }
    };

    poll();
    intervalId = setInterval(poll, 10000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  /**
   * Listen to user management statistics
   */
  static listenToUserStats(callback: (stats: UserManagementStats) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const result = await this.getUserManagementStats();
      if (result.success && result.data) {
        callback(result.data);
      }
    };

    poll();
    intervalId = setInterval(poll, 15000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  /**
   * Get team members
   */
  static async getTeamMembers(teamId: string): Promise<UserManagementApiResponse<TeamMember[]>> {
    try {
      const usersStored = await AsyncStorage.getItem(STORAGE_KEYS.USERS);
      const users: ManagedUser[] = usersStored ? JSON.parse(usersStored) : [];

      const members: TeamMember[] = users
        .filter(u => u.teamId === teamId)
        .map(u => ({
          uid: u.uid,
          name: u.displayName,
          email: u.email,
          role: u.role,
          joinedAt: u.updatedAt,
          isOnline: u.isOnline,
          lastActiveAt: u.lastActiveAt,
          permissions: u.permissions || [],
        }));

      return { success: true, data: members };
    } catch (error) {
      console.error('❌ Error fetching team members:', error);
      return { success: false, error: 'Failed to fetch team members' };
    }
  }

  /**
   * Log user management activity
   */
  private static async logActivity(activity: Omit<UserManagementActivity, 'id'>): Promise<void> {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.ACTIVITY_LOG);
      const activities: UserManagementActivity[] = stored ? JSON.parse(stored) : [];

      const newActivity: UserManagementActivity = {
        ...activity,
        id: `activity_${Date.now()}`,
      };

      activities.unshift(newActivity);

      // Keep only last 100 activities
      if (activities.length > 100) {
        activities.splice(100);
      }

      await AsyncStorage.setItem(STORAGE_KEYS.ACTIVITY_LOG, JSON.stringify(activities));
    } catch (error) {
      console.error('❌ Error logging activity:', error);
    }
  }
}
