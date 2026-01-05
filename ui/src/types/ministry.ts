// Ministry-specific types for Rally Point App

export interface Territory {
  id: string;
  name: string;
  description: string;
  boundaries: {
    latitude: number;
    longitude: number;
  }[];
  assignedWorker?: string;
  status: 'assigned' | 'unassigned' | 'completed';
  priority: 'high' | 'medium' | 'low';
  estimatedHouses: number;
  completedHouses: number;
  createdAt: Date;
  updatedAt: Date;
}

// Enhanced Delivery Tracking Types
export type DeliveryType = 'door' | 'person';
export type DeliveryStatus = 'pending' | 'delivered' | 'delivered_to_person' | 'delivered_to_door' | 'rejected' | 'not_home' | 'refused' | 'follow_up' | 'interested' | 'in_progress' | 'failed' | 'cancelled';

export interface BookDelivery {
  id: string;
  workerId: string;
  workerName: string;
  territoryId: string;
  deliveryType: DeliveryType; // door-to-door or person-to-person
  bookTitle: string;
  bookType: 'bible' | 'tract' | 'magazine' | 'study_guide';
  quantity: number;
  recipientName?: string;
  recipientPhone?: string;
  recipientAddress: string;
  location: {
    latitude: number;
    longitude: number;
    accuracy?: number;
  };
  deliveryTime: Date;
  notes?: string;
  followUpRequired: boolean;
  donationReceived?: number;
  receiptNumber?: string;
  status: DeliveryStatus;
  syncStatus: 'synced' | 'pending' | 'failed';
  barcode?: string; // For barcode scanning
}

export interface DeliverySession {
  id: string;
  workerId: string;
  workerName: string;
  startTime: Date;
  endTime?: Date;
  territoryId?: string;
  territoryName?: string; // Name of the geo territory for display
  totalDeliveries: number;
  deliveriesByStatus: Record<DeliveryStatus, number>;
  totalDistance: number; // in kilometers
  isActive: boolean;
  syncStatus: 'synced' | 'pending' | 'failed';
}

export interface PersonSurvey {
  id: string;
  workerId: string;
  workerName: string;
  territoryId: string;
  personName: string;
  personPhone?: string;
  personEmail?: string;
  address: string;
  location: {
    latitude: number;
    longitude: number;
  };
  age?: number;
  gender?: 'male' | 'female' | 'other';
  religion?: string;
  interests: string[];
  questions: {
    question: string;
    answer: string;
  }[];
  followUpInterest: boolean;
  bestTimeToContact?: string;
  notes?: string;
  surveyDate: Date;
  status: 'new' | 'contacted' | 'interested' | 'not_interested';
}

export interface Donation {
  id: string;
  workerId: string;
  workerName: string;
  territoryId?: string;
  donorName?: string;
  donorPhone?: string;
  donorEmail?: string;
  amount: number;
  currency: string;
  paymentMethod: 'cash' | 'card' | 'upi' | 'bank_transfer' | 'cheque';
  purpose: 'books' | 'general' | 'event' | 'construction' | 'other';
  receiptNumber: string;
  location?: {
    latitude: number;
    longitude: number;
  };
  donationDate: Date;
  notes?: string;
  status: 'received' | 'pending' | 'verified';
}

export interface BookInventory {
  id: string;
  title: string;
  type: 'bible' | 'tract' | 'magazine' | 'study_guide';
  language: string;
  totalStock: number;
  availableStock: number;
  distributedCount: number;
  costPerUnit: number;
  supplier?: string;
  lastRestocked: Date;
  minimumThreshold: number;
  status: 'in_stock' | 'low_stock' | 'out_of_stock';
}

export interface WorkerActivity {
  id: string;
  workerId: string;
  workerName: string;
  date: Date;
  territoryId: string;
  startTime: Date;
  endTime?: Date;
  totalHousesVisited: number;
  booksDistributed: number;
  surveysCompleted: number;
  donationsCollected: number;
  totalDonationAmount: number;
  notes?: string;
  status: 'active' | 'completed' | 'paused';
}

export interface TeamChat {
  id: string;
  senderId: string;
  senderName: string;
  senderRole: string;
  message: string;
  messageType: 'text' | 'image' | 'location' | 'announcement';
  territoryId?: string;
  timestamp: Date;
  readBy: string[];
  isAnnouncement: boolean;
  priority: 'normal' | 'high' | 'urgent';
}

export interface TrainingMaterial {
  id: string;
  title: string;
  description: string;
  type: 'video' | 'pdf' | 'audio' | 'text';
  category: 'evangelism' | 'bible_study' | 'safety' | 'communication' | 'general';
  url?: string;
  content?: string;
  duration?: number; // in minutes
  targetRoles: string[];
  isRequired: boolean;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface Announcement {
  id: string;
  title: string;
  message: string;
  type: 'general' | 'urgent' | 'training' | 'event' | 'policy';
  targetRoles: string[];
  targetTerritories?: string[];
  createdBy: string;
  createdByName: string;
  createdAt: Date;
  expiresAt?: Date;
  readBy: string[];
  isActive: boolean;
}

export interface DailyReport {
  id: string;
  workerId: string;
  workerName: string;
  date: Date;
  territoriesWorked: string[];
  totalHousesVisited: number;
  booksDistributed: {
    [bookType: string]: number;
  };
  surveysCompleted: number;
  donationsCollected: number;
  totalDonationAmount: number;
  followUpsScheduled: number;
  challenges?: string;
  highlights?: string;
  tomorrowPlan?: string;
  submittedAt: Date;
  approvedBy?: string;
  status: 'draft' | 'submitted' | 'approved' | 'needs_revision';
}

// Dashboard Analytics Types
export interface DashboardStats {
  totalWorkers: number;
  activeWorkers: number;
  totalTerritories: number;
  completedTerritories: number;
  totalBooksDistributed: number;
  totalDonationsCollected: number;
  totalSurveysCompleted: number;
  totalFollowUps: number;
  monthlyStats: {
    month: string;
    booksDistributed: number;
    donationsCollected: number;
    surveysCompleted: number;
  }[];
  topPerformers: {
    workerId: string;
    workerName: string;
    booksDistributed: number;
    donationsCollected: number;
  }[];
}

// Real-time tracking types
export interface WorkerLocation {
  workerId: string;
  workerName: string;
  currentLocation: {
    latitude: number;
    longitude: number;
    accuracy?: number;
  };
  currentTerritory?: string;
  status: 'active' | 'break' | 'offline';
  lastUpdate: Date;
  todayStats: {
    housesVisited: number;
    booksDistributed: number;
    donationsCollected: number;
  };
}
