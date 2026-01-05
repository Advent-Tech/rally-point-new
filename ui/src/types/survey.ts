// Survey Question Types
export type QuestionType = 
  | 'text' 
  | 'textarea'
  | 'radio' 
  | 'checkbox' 
  | 'dropdown' 
  | 'rating' 
  | 'yes_no'
  | 'number'
  | 'email'
  | 'phone';

// Base Question Interface
export interface SurveyQuestion {
  id: string;
  type: QuestionType;
  label: string;
  description?: string;
  required: boolean;
  order: number;
}

// Specific Question Types
export interface TextQuestion extends SurveyQuestion {
  type: 'text' | 'textarea' | 'email' | 'phone';
  placeholder?: string;
  maxLength?: number;
  minLength?: number;
}

export interface NumberQuestion extends SurveyQuestion {
  type: 'number';
  placeholder?: string;
  min?: number;
  max?: number;
}

export interface RadioQuestion extends SurveyQuestion {
  type: 'radio';
  options: string[];
  allowOther?: boolean;
}

export interface CheckboxQuestion extends SurveyQuestion {
  type: 'checkbox';
  options: string[];
  minSelections?: number;
  maxSelections?: number;
  allowOther?: boolean;
}

export interface DropdownQuestion extends SurveyQuestion {
  type: 'dropdown';
  options: string[];
  placeholder?: string;
}

export interface RatingQuestion extends SurveyQuestion {
  type: 'rating';
  scale: number; // e.g., 5 for 1-5 scale
  minLabel?: string; // e.g., "Poor"
  maxLabel?: string; // e.g., "Excellent"
}

export interface YesNoQuestion extends SurveyQuestion {
  type: 'yes_no';
  yesLabel?: string;
  noLabel?: string;
}

// Union type for all question types
export type AnyQuestion = 
  | TextQuestion 
  | NumberQuestion
  | RadioQuestion 
  | CheckboxQuestion 
  | DropdownQuestion 
  | RatingQuestion 
  | YesNoQuestion;

// Survey Interface
export interface Survey {
  id: string;
  title: string;
  description: string;
  questions: AnyQuestion[];
  createdBy: {
    uid: string;
    name: string;
    email: string;
  };
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
  tags?: string[];
  estimatedDuration?: number; // in minutes
  teamIds?: string[]; // Array of team IDs that can access this survey
  assignedTeams?: Array<{ // Team details for display
    teamId: string;
    teamName: string;
  }>;
  // Optional recipients list for UI that shows assignment by workers
  assignedTo?: Array<{
    uid: string;
    name: string;
    email: string;
    role?: string;
  }>;
}

// Survey Assignment Interface
export interface SurveyAssignment {
  id: string;
  surveyId: string;
  assignedTo: {
    uid: string;
    name: string;
    email: string;
    role: string;
  }[];
  assignedBy: {
    uid: string;
    name: string;
    email: string;
  };
  assignedAt: Date;
  dueDate?: Date;
  isActive: boolean;
  instructions?: string;
}

// Survey Response Interface
export interface SurveyResponse {
  id: string;
  surveyId: string;
  respondentId: string;
  respondentName: string;
  answers: Record<string, any>; // questionId -> answer
  location?: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  submittedAt: Date;
  isComplete: boolean;
  syncStatus: 'pending' | 'synced' | 'failed';
  deviceInfo?: {
    platform: string;
    version: string;
  };
}

// Survey Analytics Interface
export interface SurveyAnalytics {
  surveyId: string;
  totalResponses: number;
  completionRate: number;
  averageCompletionTime: number;
  responsesByWorker: Record<string, number>;
  responsesByDate: Record<string, number>;
  questionAnalytics: Record<string, {
    questionId: string;
    questionType: QuestionType;
    responses: number;
    mostCommonAnswer?: string;
    averageRating?: number;
    optionCounts?: Record<string, number>;
  }>;
}

// Form State for Survey Builder
export interface SurveyBuilderState {
  survey: Partial<Survey>;
  currentQuestion?: Partial<AnyQuestion>;
  isEditing: boolean;
  isDirty: boolean;
  validationErrors: Record<string, string>;
}

// Survey Template Interface
export interface SurveyTemplate {
  id: string;
  name: string;
  description: string;
  category: string;
  questions: Omit<AnyQuestion, 'id'>[];
  tags: string[];
  isPublic: boolean;
  createdBy: string;
  usageCount: number;
}

// Survey Filter Options
export interface SurveyFilters {
  status?: 'active' | 'inactive' | 'all';
  createdBy?: string;
  assignedTo?: string;
  dateRange?: {
    start: Date;
    end: Date;
  };
  tags?: string[];
  hasResponses?: boolean;
}

// Survey Export Options
export interface SurveyExportOptions {
  format: 'csv' | 'pdf' | 'json';
  includeMetadata: boolean;
  includeLocation: boolean;
  dateRange?: {
    start: Date;
    end: Date;
  };
  workerIds?: string[];
}

// Offline Survey Data
export interface OfflineSurveyData {
  surveys: Survey[];
  assignments: SurveyAssignment[];
  pendingResponses: SurveyResponse[];
  lastSyncAt: Date;
}

// Survey Notification Types
export interface SurveyNotification {
  id: string;
  type: 'assignment' | 'reminder' | 'completion';
  surveyId: string;
  surveyTitle: string;
  recipientId: string;
  message: string;
  sentAt: Date;
  readAt?: Date;
}
