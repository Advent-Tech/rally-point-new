import { useState, useEffect, useCallback } from 'react';
import { UserManagementService } from '../services/UserManagementService';
import {
  ManagedUser,
  Team,
  UserManagementFilters,
  UserManagementStats,
  UserRole
} from '../types/userManagement';

interface UseUserManagementReturn {
  users: ManagedUser[];
  teams: Team[];
  stats: UserManagementStats | null;
  loading: boolean;
  error: string | null;
  refreshUsers: () => Promise<void>;
  refreshTeams: () => Promise<void>;
  refreshStats: () => Promise<void>;
  updateUserRole: (userId: string, newRole: UserRole, adminId: string, reason?: string) => Promise<boolean>;
  assignUsersToTeam: (teamId: string, userIds: string[], adminId: string) => Promise<boolean>;
  createTeam: (name: string, description: string | undefined, adminId: string) => Promise<boolean>;
  promoteToTeamLeader: (userId: string, teamId: string, adminId: string) => Promise<boolean>;
}

export const useUserManagement = (
  filters?: UserManagementFilters,
  enableRealtime: boolean = true
): UseUserManagementReturn => {
  const [users, setUsers] = useState<ManagedUser[]>([]);
  const [teams, setTeams] = useState<Team[]>([]);
  const [stats, setStats] = useState<UserManagementStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load initial data
  const loadInitialData = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const [usersResponse, teamsResponse, statsResponse] = await Promise.all([
        UserManagementService.getAllUsers(filters),
        UserManagementService.getAllTeams(),
        UserManagementService.getUserManagementStats()
      ]);

      if (usersResponse.success && usersResponse.data) {
        setUsers(usersResponse.data);
      } else {
        setError(usersResponse.error || 'Failed to load users');
      }

      if (teamsResponse.success && teamsResponse.data) {
        setTeams(teamsResponse.data);
      } else {
        console.warn('Failed to load teams:', teamsResponse.error);
      }

      if (statsResponse.success && statsResponse.data) {
        setStats(statsResponse.data);
      } else {
        console.warn('Failed to load stats:', statsResponse.error);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error occurred');
    } finally {
      setLoading(false);
    }
  }, [filters]);

  // Setup real-time listeners
  useEffect(() => {
    if (!enableRealtime) {
      loadInitialData();
      return;
    }

    let unsubscribeUsers: (() => void) | undefined;
    let unsubscribeTeams: (() => void) | undefined;
    let unsubscribeStats: (() => void) | undefined;

    try {
      // Listen to users changes
      unsubscribeUsers = UserManagementService.listenToUsers((updatedUsers) => {
        setUsers(updatedUsers);
        setLoading(false);
      }, filters);

      // Listen to teams changes
      unsubscribeTeams = UserManagementService.listenToTeams((updatedTeams) => {
        setTeams(updatedTeams);
      });

      // Listen to stats changes
      unsubscribeStats = UserManagementService.listenToUserStats((updatedStats) => {
        setStats(updatedStats);
      });

      console.log('✅ Real-time user management listeners setup');
    } catch (err) {
      console.error('❌ Error setting up real-time listeners:', err);
      setError(err instanceof Error ? err.message : 'Failed to setup real-time updates');
      // Fallback to loading initial data
      loadInitialData();
    }

    // Cleanup listeners on unmount
    return () => {
      unsubscribeUsers?.();
      unsubscribeTeams?.();
      unsubscribeStats?.();
      console.log('🧹 User management listeners cleaned up');
    };
  }, [filters, enableRealtime, loadInitialData]);

  // Refresh functions
  const refreshUsers = useCallback(async () => {
    try {
      const response = await UserManagementService.getAllUsers(filters);
      if (response.success && response.data) {
        setUsers(response.data);
      }
    } catch (err) {
      console.error('Error refreshing users:', err);
    }
  }, [filters]);

  const refreshTeams = useCallback(async () => {
    try {
      const response = await UserManagementService.getAllTeams();
      if (response.success && response.data) {
        setTeams(response.data);
      }
    } catch (err) {
      console.error('Error refreshing teams:', err);
    }
  }, []);

  const refreshStats = useCallback(async () => {
    try {
      const response = await UserManagementService.getUserManagementStats();
      if (response.success && response.data) {
        setStats(response.data);
      }
    } catch (err) {
      console.error('Error refreshing stats:', err);
    }
  }, []);

  // Action functions
  const updateUserRole = useCallback(async (
    userId: string,
    newRole: UserRole,
    adminId: string,
    reason?: string
  ): Promise<boolean> => {
    try {
      const response = await UserManagementService.updateUserRole(userId, newRole, adminId, reason);
      return response.success;
    } catch (err) {
      console.error('Error updating user role:', err);
      return false;
    }
  }, []);

  const assignUsersToTeam = useCallback(async (
    teamId: string,
    userIds: string[],
    adminId: string
  ): Promise<boolean> => {
    try {
      const response = await UserManagementService.assignUsersToTeam(
        { teamId, userIds },
        adminId
      );
      return response.success;
    } catch (err) {
      console.error('Error assigning users to team:', err);
      return false;
    }
  }, []);

  const createTeam = useCallback(async (
    name: string,
    description: string | undefined,
    adminId: string
  ): Promise<boolean> => {
    try {
      const response = await UserManagementService.createTeam(
        { name, description },
        adminId
      );
      return response.success;
    } catch (err) {
      console.error('Error creating team:', err);
      return false;
    }
  }, []);

  const promoteToTeamLeader = useCallback(async (
    userId: string,
    teamId: string,
    adminId: string
  ): Promise<boolean> => {
    try {
      const response = await UserManagementService.promoteToTeamLeader(userId, teamId, adminId);
      return response.success;
    } catch (err) {
      console.error('Error promoting to team leader:', err);
      return false;
    }
  }, []);

  return {
    users,
    teams,
    stats,
    loading,
    error,
    refreshUsers,
    refreshTeams,
    refreshStats,
    updateUserRole,
    assignUsersToTeam,
    createTeam,
    promoteToTeamLeader
  };
};
