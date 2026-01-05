import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { MinistryContact, MinistryContactSession, ContactExportData } from '../types/ministryContact';
import { authService } from './authService';

const STORAGE_KEYS = {
  CONTACTS: '@rally_point_ministry_contacts',
};

export class MinistryContactService {
  private static getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  // Create a new ministry contact
  static async createContact(contact: Omit<MinistryContact, 'id'>): Promise<string> {
    try {
      const id = `contact_${Date.now()}`;
      const newContact: MinistryContact = {
        ...contact,
        id,
        createdAt: contact.createdAt || new Date(),
        updatedAt: contact.updatedAt || new Date(),
      };

      const data = await AsyncStorage.getItem(STORAGE_KEYS.CONTACTS);
      const contacts: MinistryContact[] = data ? JSON.parse(data) : [];
      contacts.push(newContact);
      await AsyncStorage.setItem(STORAGE_KEYS.CONTACTS, JSON.stringify(contacts));

      return id;
    } catch (error) {
      console.error('Error creating ministry contact:', error);
      throw error;
    }
  }

  // Update an existing contact
  static async updateContact(contactId: string, updates: Partial<MinistryContact>): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(STORAGE_KEYS.CONTACTS);
      const contacts: MinistryContact[] = data ? JSON.parse(data) : [];
      const index = contacts.findIndex(c => c.id === contactId);

      if (index !== -1) {
        contacts[index] = {
          ...contacts[index],
          ...updates,
          updatedAt: new Date(),
        };
        await AsyncStorage.setItem(STORAGE_KEYS.CONTACTS, JSON.stringify(contacts));
      }
    } catch (error) {
      console.error('Error updating ministry contact:', error);
      throw error;
    }
  }

  // Get contacts for a specific worker
  static async getContactsForWorker(workerId: string): Promise<MinistryContact[]> {
    try {
      const data = await AsyncStorage.getItem(STORAGE_KEYS.CONTACTS);
      const contacts: MinistryContact[] = data ? JSON.parse(data) : [];
      return contacts
        .filter(c => c.workerId === workerId)
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    } catch (error) {
      console.error('Error getting worker contacts:', error);
      throw error;
    }
  }

  // Get all contacts (for admin/team leader)
  static async getAllContacts(): Promise<MinistryContact[]> {
    try {
      const data = await AsyncStorage.getItem(STORAGE_KEYS.CONTACTS);
      const contacts: MinistryContact[] = data ? JSON.parse(data) : [];
      return contacts.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    } catch (error) {
      console.error('Error getting all contacts:', error);
      throw error;
    }
  }

  // Subscribe to real-time contact updates for a worker (polling-based)
  static subscribeToWorkerContacts(workerId: string, callback: (contacts: MinistryContact[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const contacts = await this.getContactsForWorker(workerId);
      callback(contacts);
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  // Send contact information (email/notification)
  static async sendContactInfo(contactId: string, method: 'email' | 'phone' | 'letter' | 'visit'): Promise<void> {
    try {
      await this.updateContact(contactId, {
        contactSent: true,
        contactSentAt: new Date(),
        contactMethod: method,
      });

      // In a real implementation, you would integrate with email service, SMS, etc.
      console.log(`Contact information sent via ${method} for contact ${contactId}`);
    } catch (error) {
      console.error('Error sending contact info:', error);
      throw error;
    }
  }

  // Schedule appointment
  static async scheduleAppointment(
    contactId: string,
    appointmentDate: Date,
    appointmentTime: string,
    notes?: string
  ): Promise<void> {
    try {
      await this.updateContact(contactId, {
        appointmentScheduled: true,
        appointmentDate,
        appointmentTime,
        appointmentNotes: notes,
      });
    } catch (error) {
      console.error('Error scheduling appointment:', error);
      throw error;
    }
  }

  // Delete contact
  static async deleteContact(contactId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(STORAGE_KEYS.CONTACTS);
      const contacts: MinistryContact[] = data ? JSON.parse(data) : [];
      const filtered = contacts.filter(c => c.id !== contactId);
      await AsyncStorage.setItem(STORAGE_KEYS.CONTACTS, JSON.stringify(filtered));
    } catch (error) {
      console.error('Error deleting contact:', error);
      throw error;
    }
  }

  // Get contact statistics for a worker
  static async getWorkerContactStats(workerId: string, days: number = 30): Promise<any> {
    try {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const allContacts = await this.getContactsForWorker(workerId);
      const contacts = allContacts.filter(c => new Date(c.createdAt) >= startDate);

      const stats = {
        totalContacts: contacts.length,
        appointmentsScheduled: contacts.filter(c => c.appointmentScheduled).length,
        contactsSent: contacts.filter(c => c.contactSent).length,
        interestsByType: {
          personalBibleStudies: contacts.filter(c => c.personalBibleStudies).length,
          groupBibleStudies: contacts.filter(c => c.groupBibleStudies).length,
          healthSeminar: contacts.filter(c => c.healthSeminar).length,
          healthExpo: contacts.filter(c => c.healthExpo).length,
          vbs: contacts.filter(c => c.vbs).length,
          healthConsultation: contacts.filter(c => c.healthConsultation).length,
        },
        averagePerDay: contacts.length / days,
      };

      return stats;
    } catch (error) {
      console.error('Error getting worker contact stats:', error);
      throw error;
    }
  }

  // Export contacts data
  static async exportContacts(
    workerId?: string,
    format: 'csv' | 'json' | 'pdf' = 'csv'
  ): Promise<ContactExportData> {
    try {
      const contacts = workerId
        ? await this.getContactsForWorker(workerId)
        : await this.getAllContacts();

      return {
        contacts,
        exportedAt: new Date(),
        exportedBy: workerId || 'admin',
        format,
      };
    } catch (error) {
      console.error('Error exporting contacts:', error);
      throw error;
    }
  }
}

export default MinistryContactService;
