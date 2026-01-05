// User Management System Types for Rally Point App

import { UserRole } from './index';

// Enhanced User interface for management
export interface ManagedUser {
  uid: string;
  email: string;
  displayName: string;
  role: UserRole;
  phone?: string;
  profilePhotoUrl?: string;
  teamId?: string;
  teamName?: string;
  teamLeaderId?: string;
  teamLeaderName?: string;
  isOnline: boolean;
  lastActiveAt: Date;
  createdAt: Date;
  updatedAt: Date;
  status: 'active' | 'inactive' | 'suspended';
  permissions?: string[];
}

// Team interface
export interface Team {
  id: string;
  name: string;
  description?: string;
  leaderId?: string;
  leaderName?: string;
  leaderEmail?: string;
  memberIds: string[];
  memberCount: number;
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
  color?: string;
  territory?: {
    id: string;
    name: string;
  };
}

// Team member interface
export interface TeamMember {
  uid: string;
  name: string;
  email: string;
  role: UserRole;
  joinedAt: Date;
  isOnline: boolean;
  lastActiveAt: Date;
  permissions?: string[];
}

// Team assignment interface
export interface TeamAssignment {
  id: string;
  teamId: string;
  teamName: string;
  userId: string;
  userName: string;
  userEmail: string;
  assignedBy: {
    uid: string;
    name: string;
    email: string;
  };
  assignedAt: Date;
  role: UserRole;
  isActive: boolean;
}

// Role change request interface
export interface RoleChangeRequest {
  id: string;
  userId: string;
  userName: string;
  userEmail: string;
  currentRole: UserRole;
  requestedRole: UserRole;
  requestedBy: {
    uid: string;
    name: string;
    email: string;
  };
  reason?: string;
  requestedAt: Date;
  status: 'pending' | 'approved' | 'rejected';
  processedBy?: {
    uid: string;
    name: string;
    email: string;
  };
  processedAt?: Date;
  notes?: string;
}

// User management filters
export interface UserManagementFilters {
  role?: UserRole;
  teamId?: string;
  status?: 'active' | 'inactive' | 'suspended';
  isOnline?: boolean;
  searchQuery?: string;
  sortBy?: 'name' | 'email' | 'role' | 'lastActive' | 'createdAt';
  sortOrder?: 'asc' | 'desc';
}

// User management statistics
export interface UserManagementStats {
  totalUsers: number;
  activeUsers: number;
  onlineUsers: number;
  usersByRole: {
    admin: number;
    team_leader: number;
    worker: number;
  };
  totalTeams: number;
  activeTeams: number;
  usersWithoutTeam: number;
  recentSignups: number;
}

// Bulk operation interfaces
export interface BulkUserOperation {
  operation: 'assign_team' | 'change_role' | 'activate' | 'deactivate' | 'delete';
  userIds: string[];
  data?: {
    teamId?: string;
    role?: UserRole;
    reason?: string;
  };
  performedBy: {
    uid: string;
    name: string;
    email: string;
  };
  performedAt: Date;
}

export interface BulkOperationResult {
  success: boolean;
  totalProcessed: number;
  successCount: number;
  failureCount: number;
  errors: Array<{
    userId: string;
    error: string;
  }>;
}

// Form data interfaces
export interface CreateTeamFormData {
  name: string;
  description?: string;
  leaderId?: string;
  color?: string;
}

export interface AssignTeamFormData {
  teamId: string;
  userIds: string[];
  role?: UserRole;
}

export interface ChangeRoleFormData {
  userId: string;
  newRole: UserRole;
  reason?: string;
}

// API response interfaces
export interface UserManagementApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

// Real-time update interfaces
export interface UserStatusUpdate {
  uid: string;
  isOnline: boolean;
  lastActiveAt: Date;
  location?: {
    latitude: number;
    longitude: number;
    timestamp: Date;
  };
}

export interface TeamUpdate {
  teamId: string;
  type: 'member_added' | 'member_removed' | 'leader_changed' | 'team_updated' | 'team_deleted';
  data: any;
  updatedBy: {
    uid: string;
    name: string;
  };
  updatedAt: Date;
}

// Permission system
export interface UserPermission {
  id: string;
  name: string;
  description: string;
  category: 'user_management' | 'territory' | 'survey' | 'messaging' | 'reports';
  level: 'read' | 'write' | 'admin';
}

export interface RolePermissions {
  role: UserRole;
  permissions: string[];
  inheritFrom?: UserRole;
}

// Activity log
export interface UserManagementActivity {
  id: string;
  type: 'user_created' | 'user_updated' | 'role_changed' | 'team_assigned' | 'team_created' | 'team_updated';
  performedBy: {
    uid: string;
    name: string;
    email: string;
  };
  targetUser?: {
    uid: string;
    name: string;
    email: string;
  };
  targetTeam?: {
    id: string;
    name: string;
  };
  details: Record<string, any>;
  timestamp: Date;
  ipAddress?: string;
  userAgent?: string;
}

// Export all types
export type {
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
  UserPermission,
  RolePermissions,
  UserManagementActivity
};
