// Community feature types for Rally Point App

export interface NewsItem {
  id: string;
  title: string;
  content: string;
  author: string;
  authorId: string;
  timestamp: Date;
  likes: number;
  comments: number;
  shares?: number;
  image?: string;
  tags?: string[];
}

export interface NewsComment {
  id: string;
  newsId: string;
  author: string;
  authorId: string;
  content: string;
  timestamp: Date;
  likes: number;
}

export interface Message {
  id: string;
  sender: string;
  senderId: string;
  recipient?: string;
  recipientId?: string;
  content: string;
  timestamp: Date;
  isRead: boolean;
  messageType: 'direct' | 'group' | 'announcement';
  groupId?: string;
  attachments?: MessageAttachment[];
}

export interface MessageAttachment {
  id: string;
  type: 'image' | 'document' | 'audio';
  url: string;
  name: string;
  size: number;
}

export interface ChatGroup {
  id: string;
  name: string;
  description?: string;
  members: string[];
  admins: string[];
  createdBy: string;
  createdAt: Date;
  isPrivate: boolean;
  avatar?: string;
}

export interface MissionTrip {
  id: string;
  title: string;
  description: string;
  location: string;
  date: string;
  endDate?: string;
  duration: string;
  spotsAvailable: number;
  totalSpots: number;
  organizer: string;
  organizerId: string;
  requirements?: string[];
  signedUpUsers: string[];
  createdAt: Date;
  status: 'upcoming' | 'ongoing' | 'completed' | 'cancelled';
  cost?: number;
  meetingPoint?: string;
  contactInfo?: string;
}

export interface TripSignup {
  id: string;
  tripId: string;
  userId: string;
  userName: string;
  signupDate: Date;
  status: 'pending' | 'confirmed' | 'cancelled';
  notes?: string;
  emergencyContact?: string;
}

export interface Volunteer {
  id: string;
  userId: string;
  name: string;
  email: string;
  phone?: string;
  skills: string[];
  availability: string;
  contact: string;
  rating: number;
  totalRatings: number;
  isActive: boolean;
  joinedDate: Date;
  bio?: string;
  experience?: string;
  languages?: string[];
  certifications?: string[];
}

export interface VolunteerSkill {
  id: string;
  name: string;
  category: string;
  description?: string;
  isActive: boolean;
}

export interface VolunteerRating {
  id: string;
  volunteerId: string;
  raterId: string;
  rating: number;
  comment?: string;
  timestamp: Date;
  eventId?: string;
}

export interface ChildCheckIn {
  id: string;
  childName: string;
  childAge?: number;
  parentName: string;
  parentContact: string;
  emergencyContact?: string;
  checkInTime: Date;
  checkOutTime?: Date;
  status: 'checked_in' | 'checked_out';
  eventId?: string;
  eventName?: string;
  notes?: string;
  qrCode: string;
  checkedInBy: string;
  checkedOutBy?: string;
  allergies?: string[];
  medicalNotes?: string;
}

export interface Event {
  id: string;
  title: string;
  description: string;
  date: Date;
  endDate?: Date;
  location: string;
  organizer: string;
  organizerId: string;
  attendees: string[];
  maxAttendees?: number;
  isPublic: boolean;
  category: 'ministry' | 'social' | 'training' | 'meeting' | 'service';
  status: 'upcoming' | 'ongoing' | 'completed' | 'cancelled';
  createdAt: Date;
  requiresCheckIn: boolean;
}

export interface CommunityNotification {
  id: string;
  userId: string;
  type: 'news' | 'message' | 'trip' | 'event' | 'volunteer' | 'checkin';
  title: string;
  content: string;
  isRead: boolean;
  timestamp: Date;
  actionUrl?: string;
  metadata?: Record<string, any>;
}

export interface CommunityStats {
  totalMembers: number;
  activeVolunteers: number;
  upcomingTrips: number;
  recentNews: number;
  unreadMessages: number;
  activeCheckIns: number;
}

// Community preferences and settings
export interface CommunitySettings {
  userId: string;
  notifications: {
    news: boolean;
    messages: boolean;
    trips: boolean;
    events: boolean;
    checkins: boolean;
  };
  privacy: {
    showProfile: boolean;
    showSkills: boolean;
    allowDirectMessages: boolean;
  };
  preferences: {
    language: string;
    timezone: string;
    emailDigest: 'daily' | 'weekly' | 'never';
  };
}

// API response types
export interface CommunityApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  hasMore: boolean;
}

// Form types for community features
export interface NewsItemForm {
  title: string;
  content: string;
  tags?: string[];
  image?: string;
}

export interface MessageForm {
  content: string;
  recipientId?: string;
  groupId?: string;
  messageType: 'direct' | 'group' | 'announcement';
}

export interface MissionTripForm {
  title: string;
  description: string;
  location: string;
  date: string;
  endDate?: string;
  duration: string;
  totalSpots: number;
  requirements?: string[];
  cost?: number;
  meetingPoint?: string;
  contactInfo?: string;
}

export interface VolunteerForm {
  name: string;
  email: string;
  phone?: string;
  skills: string[];
  availability: string;
  bio?: string;
  experience?: string;
  languages?: string[];
  certifications?: string[];
}

export interface ChildCheckInForm {
  childName: string;
  childAge?: number;
  parentName: string;
  parentContact: string;
  emergencyContact?: string;
  eventId?: string;
  notes?: string;
  allergies?: string[];
  medicalNotes?: string;
}

// Filter and search types
export interface CommunityFilters {
  dateRange?: {
    start: Date;
    end: Date;
  };
  category?: string;
  status?: string;
  location?: string;
  skills?: string[];
  availability?: string;
}

export interface SearchParams {
  query: string;
  filters?: CommunityFilters;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  page?: number;
  limit?: number;
}
