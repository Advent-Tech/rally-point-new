import { UserRole } from '../types/userManagement';

// Validation rules
export const VALIDATION_RULES = {
  TEAM_NAME: {
    MIN_LENGTH: 2,
    MAX_LENGTH: 50,
    PATTERN: /^[a-zA-Z0-9\s\-_]+$/
  },
  TEAM_DESCRIPTION: {
    MAX_LENGTH: 200
  },
  USER_SELECTION: {
    MIN_USERS: 1,
    MAX_USERS: 50
  }
};

// Validation error messages
export const VALIDATION_MESSAGES = {
  TEAM_NAME_REQUIRED: 'Team name is required',
  TEAM_NAME_TOO_SHORT: `Team name must be at least ${VALIDATION_RULES.TEAM_NAME.MIN_LENGTH} characters`,
  TEAM_NAME_TOO_LONG: `Team name must be less than ${VALIDATION_RULES.TEAM_NAME.MAX_LENGTH} characters`,
  TEAM_NAME_INVALID_CHARS: 'Team name can only contain letters, numbers, spaces, hyphens, and underscores',
  TEAM_DESCRIPTION_TOO_LONG: `Team description must be less than ${VALIDATION_RULES.TEAM_DESCRIPTION.MAX_LENGTH} characters`,
  NO_USERS_SELECTED: 'Please select at least one user',
  TOO_MANY_USERS_SELECTED: `Cannot select more than ${VALIDATION_RULES.USER_SELECTION.MAX_USERS} users at once`,
  TEAM_REQUIRED: 'Please select a team',
  ROLE_REQUIRED: 'Please select a role',
  INVALID_ROLE: 'Invalid role selected',
  USER_NOT_FOUND: 'Selected user not found',
  TEAM_NOT_FOUND: 'Selected team not found',
  CANNOT_DEMOTE_SELF: 'You cannot change your own role',
  CANNOT_REMOVE_SELF: 'You cannot remove yourself from a team',
  INVALID_EMAIL: 'Please enter a valid email address',
  DUPLICATE_TEAM_NAME: 'A team with this name already exists'
};

// Validation functions
export const validateTeamName = (name: string): string | null => {
  if (!name || name.trim().length === 0) {
    return VALIDATION_MESSAGES.TEAM_NAME_REQUIRED;
  }
  
  const trimmedName = name.trim();
  
  if (trimmedName.length < VALIDATION_RULES.TEAM_NAME.MIN_LENGTH) {
    return VALIDATION_MESSAGES.TEAM_NAME_TOO_SHORT;
  }
  
  if (trimmedName.length > VALIDATION_RULES.TEAM_NAME.MAX_LENGTH) {
    return VALIDATION_MESSAGES.TEAM_NAME_TOO_LONG;
  }
  
  if (!VALIDATION_RULES.TEAM_NAME.PATTERN.test(trimmedName)) {
    return VALIDATION_MESSAGES.TEAM_NAME_INVALID_CHARS;
  }
  
  return null;
};

export const validateTeamDescription = (description: string): string | null => {
  if (description && description.length > VALIDATION_RULES.TEAM_DESCRIPTION.MAX_LENGTH) {
    return VALIDATION_MESSAGES.TEAM_DESCRIPTION_TOO_LONG;
  }
  
  return null;
};

export const validateUserSelection = (userIds: string[]): string | null => {
  if (!userIds || userIds.length === 0) {
    return VALIDATION_MESSAGES.NO_USERS_SELECTED;
  }
  
  if (userIds.length > VALIDATION_RULES.USER_SELECTION.MAX_USERS) {
    return VALIDATION_MESSAGES.TOO_MANY_USERS_SELECTED;
  }
  
  return null;
};

export const validateTeamSelection = (teamId: string): string | null => {
  if (!teamId || teamId.trim().length === 0) {
    return VALIDATION_MESSAGES.TEAM_REQUIRED;
  }
  
  return null;
};

export const validateRole = (role: string): string | null => {
  if (!role || role.trim().length === 0) {
    return VALIDATION_MESSAGES.ROLE_REQUIRED;
  }
  
  const validRoles: UserRole[] = ['admin', 'team_leader', 'worker'];
  if (!validRoles.includes(role as UserRole)) {
    return VALIDATION_MESSAGES.INVALID_ROLE;
  }
  
  return null;
};

export const validateEmail = (email: string): string | null => {
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  
  if (!email || email.trim().length === 0) {
    return 'Email is required';
  }
  
  if (!emailPattern.test(email.trim())) {
    return VALIDATION_MESSAGES.INVALID_EMAIL;
  }
  
  return null;
};

export const validateRoleChange = (
  currentUserId: string,
  targetUserId: string,
  currentRole: UserRole,
  newRole: UserRole
): string | null => {
  // Prevent users from changing their own role
  if (currentUserId === targetUserId) {
    return VALIDATION_MESSAGES.CANNOT_DEMOTE_SELF;
  }
  
  // Validate the new role
  const roleValidation = validateRole(newRole);
  if (roleValidation) {
    return roleValidation;
  }
  
  // Additional business logic validations can be added here
  // For example: only admins can create other admins, etc.
  
  return null;
};

export const validateTeamAssignment = (
  currentUserId: string,
  userIds: string[],
  teamId: string
): string | null => {
  // Validate user selection
  const userValidation = validateUserSelection(userIds);
  if (userValidation) {
    return userValidation;
  }
  
  // Validate team selection
  const teamValidation = validateTeamSelection(teamId);
  if (teamValidation) {
    return teamValidation;
  }
  
  return null;
};

export const validateTeamCreation = (
  name: string,
  description?: string,
  existingTeamNames?: string[]
): { isValid: boolean; errors: Record<string, string> } => {
  const errors: Record<string, string> = {};
  
  // Validate team name
  const nameValidation = validateTeamName(name);
  if (nameValidation) {
    errors.name = nameValidation;
  }
  
  // Check for duplicate team names
  if (existingTeamNames && existingTeamNames.includes(name.trim())) {
    errors.name = VALIDATION_MESSAGES.DUPLICATE_TEAM_NAME;
  }
  
  // Validate team description
  if (description) {
    const descriptionValidation = validateTeamDescription(description);
    if (descriptionValidation) {
      errors.description = descriptionValidation;
    }
  }
  
  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
};

// Utility functions for form validation
export const sanitizeTeamName = (name: string): string => {
  return name.trim().replace(/\s+/g, ' ');
};

export const sanitizeTeamDescription = (description: string): string => {
  return description.trim();
};

export const formatValidationErrors = (errors: Record<string, string>): string => {
  return Object.values(errors).join('. ');
};

// Role hierarchy and permissions
export const ROLE_HIERARCHY: Record<UserRole, number> = {
  worker: 1,
  team_leader: 2,
  admin: 3
};

export const canManageUser = (managerRole: UserRole, targetRole: UserRole): boolean => {
  return ROLE_HIERARCHY[managerRole] > ROLE_HIERARCHY[targetRole];
};

export const canPromoteToRole = (managerRole: UserRole, targetRole: UserRole): boolean => {
  // Admins can promote to any role
  if (managerRole === 'admin') {
    return true;
  }
  
  // Team leaders can only promote to worker or team_leader
  if (managerRole === 'team_leader') {
    return targetRole === 'worker' || targetRole === 'team_leader';
  }
  
  // Workers cannot promote anyone
  return false;
};

export const getAvailableRoles = (managerRole: UserRole): UserRole[] => {
  switch (managerRole) {
    case 'admin':
      return ['worker', 'team_leader', 'admin'];
    case 'team_leader':
      return ['worker', 'team_leader'];
    default:
      return [];
  }
};

// Export all validation functions as a single object for easier importing
export const UserManagementValidation = {
  validateTeamName,
  validateTeamDescription,
  validateUserSelection,
  validateTeamSelection,
  validateRole,
  validateEmail,
  validateRoleChange,
  validateTeamAssignment,
  validateTeamCreation,
  sanitizeTeamName,
  sanitizeTeamDescription,
  formatValidationErrors,
  canManageUser,
  canPromoteToRole,
  getAvailableRoles,
  VALIDATION_RULES,
  VALIDATION_MESSAGES,
  ROLE_HIERARCHY
};
