// User roles
export type UserRole = 'admin' | 'team_leader' | 'worker';

// Export profile types
export * from './profile';
export * from './userManagement';

// Google account interface for social login
export interface GoogleAccount {
  id: string;
  email: string;
  name: string;
  photoUrl?: string;
}

// User interface
export interface User {
  id: string;
  email: string;
  display_name: string;
  role: UserRole;
  team_id?: string;
  is_online: boolean;
  last_active_at: string;
  created_at: string;
  updated_at: string;
}

// Authentication context types
export interface AuthContextType {
  user: User | null;
  loading: boolean;
  isFirstInstall: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, role: UserRole, displayName?: string) => Promise<void>;
  signOut: () => Promise<void>;
}

// Form validation types
export interface SignInFormData {
  email: string;
  password: string;
}

export interface SignUpFormData {
  email: string;
  password: string;
  confirmPassword: string;
  displayName: string;
  role: UserRole;
}

// Navigation types
export type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
};

export type AuthStackParamList = {
  SignIn: undefined;
  SignUp: undefined;
};

export type MainStackParamList = {
  AdminDashboard: undefined;
  TeamLeaderDashboard: undefined;
  WorkerDashboard: undefined;
  WorkerTabs: undefined;
  DeliveryTracking: undefined;
  LocationTracking: undefined;
  Gamification: undefined;
  BookDelivery: undefined;
  AdminDeliveryMap: undefined;
  AdminWorkerTracking: undefined;
  AdminUserManagement: undefined;
  TeamManagement: undefined;
  AdminLiveMap: {
    workerId: string;
    workerName: string;
    assignedTerritories: any[];
    currentLocation?: {
      latitude: number;
      longitude: number;
      timestamp: number;
    };
  };
  Messaging: undefined;
  Chat: {
    conversationId: string;
    recipientId: string;
    recipientName: string;
    recipientRole?: string;
    isGroup?: boolean;
  };
  GroupChat: {
    groupId: string;
    groupName: string;
  };
  MyTerritory: undefined;
  Territory: undefined;
  TerritoryManagement: undefined;
  GeoTerritoryMap: {
    onTerritorySelect?: (territory: any) => void;
    onChurchSelect?: (church: any) => void;
    initialTerritoryId?: string;
    selectionMode?: boolean;
  } | undefined;
  PathHistory: undefined;
  WorkerAnalytics: undefined;
  // Survey-related screens
  SurveyBuilder: undefined;
  SurveyManagement: undefined;
  SurveyAssignment: { surveyId: string };
  SurveyResponses: { surveyId: string };
  Surveys: undefined;
  SurveyForm: { surveyId: string };
  Notifications: undefined;

  // Ministry Contact screens
  MinistryContact: undefined;
  MinistryContactList: undefined;

  // Community screen
  Community: undefined;

  // Demo screens
  HeaderDemo: undefined;
  UIShowcase: undefined;

  // Profile screens
  Profile: undefined;
  EditProfile: undefined;
  ChangePassword: undefined;
  NotificationSettings: undefined;
  HelpSupport: undefined;

  // Session Reports screens
  SessionReports: undefined;
  SessionDetails: { sessionId: string };

  // Additional admin and team leader screens
  AdminBookAssignment: undefined;
  AdminTeamManagement: undefined;
  TeamLeaderWorkerTracking: undefined;
  TeamLeaderSurveyManagement: undefined;
  TeamLeaderWorkerManagement: undefined;
  TeamLeaderDeliveryManagement: undefined;
  TeamLeaderTerritoryAssignment: undefined;
  JoinTeam: undefined;
  // Worker Detail and Path screens
  WorkerDetail: {
    workerId: string;
    workerName: string;
    workerEmail?: string;
  };
  WorkerPathMap: {
    workerId: string;
    workerName: string;
  };
};

// Component props types
export interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'outline';
  size?: 'small' | 'medium' | 'large';
  disabled?: boolean;
  loading?: boolean;
}

export interface InputProps {
  label?: string;
  placeholder?: string;
  value: string;
  onChangeText: (text: string) => void;
  secureTextEntry?: boolean;
  error?: string;
  disabled?: boolean;
  rightIcon?: string;
  onRightIconPress?: () => void;
}

export interface HeaderProps {
  title?: string;
  showBackButton?: boolean;
  onBackPress?: () => void;
  rightComponent?: React.ReactNode;
  showNotifications?: boolean;
  showMenu?: boolean;
  showLogo?: boolean;
  showProfile?: boolean;
  onMenuPress?: () => void;
  onProfilePress?: () => void;
}

// Export survey types
export * from './survey';

// Export community types
export * from './community';
