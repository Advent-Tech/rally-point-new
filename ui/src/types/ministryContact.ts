export interface MinistryContact {
  id: string;
  workerId: string;
  workerName: string;
  territoryId?: string;
  
  // Contact Information
  name: string;
  address: string;
  email?: string;
  phone?: string;
  
  // Ministry Interests (checkboxes/toggles)
  personalBibleStudies: boolean;
  groupBibleStudies: boolean;
  healthSeminar: boolean;
  healthExpo: boolean;
  vbs: boolean; // Vacation Bible School
  healthConsultation: boolean;
  
  // Additional Information
  misc?: string; // Additional notes
  
  // Appointment Information
  appointmentScheduled?: boolean;
  appointmentDate?: Date;
  appointmentTime?: string;
  appointmentNotes?: string;
  
  // Contact Status
  contactSent?: boolean;
  contactSentAt?: Date;
  contactMethod?: 'email' | 'phone' | 'letter' | 'visit';
  
  // Metadata
  location?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
  };
  createdAt: Date;
  updatedAt: Date;
  syncStatus: 'synced' | 'pending' | 'failed';
}

export interface MinistryContactSession {
  id: string;
  workerId: string;
  workerName: string;
  startTime: Date;
  endTime?: Date;
  territoryId?: string;
  totalContacts: number;
  contactsByInterest: {
    personalBibleStudies: number;
    groupBibleStudies: number;
    healthSeminar: number;
    healthExpo: number;
    vbs: number;
    healthConsultation: number;
  };
  appointmentsScheduled: number;
  contactsSent: number;
  isActive: boolean;
  syncStatus: 'synced' | 'pending' | 'failed';
}

export interface ContactExportData {
  contacts: MinistryContact[];
  exportedAt: Date;
  exportedBy: string;
  format: 'csv' | 'json' | 'pdf';
  filters?: {
    dateRange?: {
      start: Date;
      end: Date;
    };
    interests?: string[];
    hasAppointment?: boolean;
    contactSent?: boolean;
  };
}

// Form validation schema types
export interface ContactFormData {
  name: string;
  address: string;
  email: string;
  phone: string;
  personalBibleStudies: boolean;
  groupBibleStudies: boolean;
  healthSeminar: boolean;
  healthExpo: boolean;
  vbs: boolean;
  healthConsultation: boolean;
  misc: string;
  appointmentScheduled: boolean;
  appointmentDate: string;
  appointmentTime: string;
  appointmentNotes: string;
}

export interface ContactFormErrors {
  name?: string;
  address?: string;
  email?: string;
  phone?: string;
  appointmentDate?: string;
  appointmentTime?: string;
}
