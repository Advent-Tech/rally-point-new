// Profile-related types and interfaces for Rally Point app

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  role: 'admin' | 'team_leader' | 'worker';
  phone?: string;
  profilePhotoUrl?: string;
  teamId?: string;
  teamName?: string;
  teamLeaderId?: string;
  teamLeaderName?: string;
  createdAt: Date;
  updatedAt: Date;
  lastActiveAt?: Date;
}

export interface UserStatistics {
  userId: string;
  totalDistanceCovered: number; // in kilometers
  booksDistributed: number;
  surveysCompleted: number;
  donationsCollected: number; // in currency units
  hoursWorked: number;
  territoriesCovered: number;
  contactsMade: number;
  lastUpdated: Date;
}

export interface NotificationPreferences {
  pushNotifications: boolean;
  emailNotifications: boolean;
  smsNotifications: boolean;
  surveyAssignments: boolean;
  territoryUpdates: boolean;
  teamMessages: boolean;
  systemUpdates: boolean;
  emergencyAlerts: boolean;
}

export interface PrivacySettings {
  showProfileToTeam: boolean;
  shareLocationWithTeam: boolean;
  allowDirectMessages: boolean;
  showStatisticsToTeam: boolean;
  shareContactInfo: boolean;
}

export interface UserPreferences {
  language: string;
  timezone: string;
  theme: 'light' | 'dark' | 'system';
  mapType: 'standard' | 'satellite' | 'hybrid';
  distanceUnit: 'km' | 'miles';
  currencySymbol: string;
  dateFormat: 'MM/DD/YYYY' | 'DD/MM/YYYY' | 'YYYY-MM-DD';
  timeFormat: '12h' | '24h';
}

export interface ProfileSettings {
  userId: string;
  notifications: NotificationPreferences;
  privacy: PrivacySettings;
  preferences: UserPreferences;
  updatedAt: Date;
}

// Form validation types
export interface UpdateProfileFormData {
  displayName: string;
  phone: string;
  email: string;
}

export interface ChangePasswordFormData {
  currentPassword: string;
  newPassword: string;
  confirmPassword: string;
}

export interface EmergencyContact {
  name: string;
  phone: string;
  relationship: string;
  isPrimary: boolean;
}

export interface SOSSettings {
  isEnabled: boolean;
  emergencyContacts: EmergencyContact[];
  autoLocationShare: boolean;
  emergencyMessage: string;
  countdownDuration: number; // in seconds
}

// API response types
export interface ProfileApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

// Statistics aggregation types
export interface StatisticsPeriod {
  daily: UserStatistics;
  weekly: UserStatistics;
  monthly: UserStatistics;
  yearly: UserStatistics;
  allTime: UserStatistics;
}

export interface TeamStatistics {
  teamId: string;
  teamName: string;
  totalMembers: number;
  activeMembers: number;
  teamStats: UserStatistics;
  topPerformers: Array<{
    userId: string;
    displayName: string;
    stats: UserStatistics;
  }>;
}

// Help and support types
export interface FAQItem {
  id: string;
  question: string;
  answer: string;
  category: string;
  isExpanded?: boolean;
}

export interface SupportTicket {
  id: string;
  userId: string;
  subject: string;
  description: string;
  category: 'technical' | 'account' | 'feature' | 'bug' | 'other';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  status: 'open' | 'in_progress' | 'resolved' | 'closed';
  createdAt: Date;
  updatedAt: Date;
  responses?: Array<{
    id: string;
    message: string;
    isFromSupport: boolean;
    createdAt: Date;
  }>;
}

export interface TrainingResource {
  id: string;
  title: string;
  description: string;
  type: 'video' | 'document' | 'interactive' | 'quiz';
  url: string;
  duration?: number; // in minutes
  category: string;
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  isRequired: boolean;
  completedBy?: string[]; // user IDs who completed this resource
}

// Profile update events
export interface ProfileUpdateEvent {
  userId: string;
  field: string;
  oldValue: any;
  newValue: any;
  timestamp: Date;
  source: 'user' | 'admin' | 'system';
}
