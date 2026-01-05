import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { authService } from './authService';
import { BookDelivery, DeliverySession, DeliveryStatus } from '../types/ministry';

const DELIVERIES_KEY = 'deliveries';
const SESSIONS_KEY = 'delivery_sessions';

export class DeliveryService {
  private static getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  static async createDelivery(delivery: Omit<BookDelivery, 'id'>): Promise<string> {
    try {
      const id = `delivery_${Date.now()}`;
      const deliveryData = {
        ...delivery,
        id,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };

      const data = await AsyncStorage.getItem(DELIVERIES_KEY);
      const deliveries: any[] = data ? JSON.parse(data) : [];
      deliveries.push(deliveryData);
      await AsyncStorage.setItem(DELIVERIES_KEY, JSON.stringify(deliveries));

      return id;
    } catch (error) {
      console.error('Error creating delivery:', error);
      throw error;
    }
  }

  static async updateDelivery(deliveryId: string, updates: Partial<BookDelivery>): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(DELIVERIES_KEY);
      const deliveries: any[] = data ? JSON.parse(data) : [];
      const index = deliveries.findIndex(d => d.id === deliveryId);

      if (index !== -1) {
        deliveries[index] = { ...deliveries[index], ...updates, updatedAt: Date.now() };
        await AsyncStorage.setItem(DELIVERIES_KEY, JSON.stringify(deliveries));
      }
    } catch (error) {
      console.error('Error updating delivery:', error);
      throw error;
    }
  }

  static async getWorkerDeliveries(workerId: string, limitCount: number = 50): Promise<BookDelivery[]> {
    try {
      const data = await AsyncStorage.getItem(DELIVERIES_KEY);
      const deliveries: BookDelivery[] = data ? JSON.parse(data) : [];

      return deliveries
        .filter(d => d.workerId === workerId)
        .sort((a, b) => new Date(b.deliveryTime).getTime() - new Date(a.deliveryTime).getTime())
        .slice(0, limitCount);
    } catch (error) {
      console.error('Error getting worker deliveries:', error);
      throw error;
    }
  }

  static async getAllDeliveries(): Promise<BookDelivery[]> {
    try {
      const data = await AsyncStorage.getItem(DELIVERIES_KEY);
      const deliveries: BookDelivery[] = data ? JSON.parse(data) : [];

      return deliveries.sort((a, b) =>
        new Date(b.deliveryTime).getTime() - new Date(a.deliveryTime).getTime()
      );
    } catch (error) {
      console.error('Error getting all deliveries:', error);
      throw error;
    }
  }

  static async getDeliveriesByStatus(workerId: string, status: DeliveryStatus): Promise<BookDelivery[]> {
    try {
      const data = await AsyncStorage.getItem(DELIVERIES_KEY);
      const deliveries: BookDelivery[] = data ? JSON.parse(data) : [];

      return deliveries
        .filter(d => d.workerId === workerId && d.status === status)
        .sort((a, b) => new Date(b.deliveryTime).getTime() - new Date(a.deliveryTime).getTime());
    } catch (error) {
      console.error('Error getting deliveries by status:', error);
      throw error;
    }
  }

  static async createSession(session: Omit<DeliverySession, 'id'>): Promise<string> {
    try {
      const id = `session_${Date.now()}`;
      const sessionData = {
        ...session,
        id,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };

      const data = await AsyncStorage.getItem(SESSIONS_KEY);
      const sessions: any[] = data ? JSON.parse(data) : [];
      sessions.push(sessionData);
      await AsyncStorage.setItem(SESSIONS_KEY, JSON.stringify(sessions));

      return id;
    } catch (error) {
      console.error('Error creating session:', error);
      throw error;
    }
  }

  static async updateSession(sessionId: string, updates: Partial<DeliverySession>): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(SESSIONS_KEY);
      const sessions: any[] = data ? JSON.parse(data) : [];
      const index = sessions.findIndex(s => s.id === sessionId);

      if (index !== -1) {
        sessions[index] = { ...sessions[index], ...updates, updatedAt: Date.now() };
        await AsyncStorage.setItem(SESSIONS_KEY, JSON.stringify(sessions));
      }
    } catch (error) {
      console.error('Error updating session:', error);
      throw error;
    }
  }

  static async getActiveSession(workerId: string): Promise<DeliverySession | null> {
    try {
      const data = await AsyncStorage.getItem(SESSIONS_KEY);
      const sessions: DeliverySession[] = data ? JSON.parse(data) : [];

      const activeSessions = sessions
        .filter(s => s.workerId === workerId && s.isActive)
        .sort((a, b) => new Date(b.startTime).getTime() - new Date(a.startTime).getTime());

      return activeSessions[0] || null;
    } catch (error) {
      console.error('Error getting active session:', error);
      throw error;
    }
  }

  static subscribeToWorkerDeliveries(
    workerId: string,
    callback: (deliveries: BookDelivery[]) => void
  ): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      try {
        const deliveries = await this.getWorkerDeliveries(workerId, 20);
        callback(deliveries);
      } catch (error) {
        callback([]);
      }
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  static async getWorkerStats(workerId: string, days: number = 30): Promise<{
    totalDeliveries: number;
    deliveriesByStatus: Record<DeliveryStatus, number>;
    deliveriesByType: Record<string, number>;
    averagePerDay: number;
  }> {
    try {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const data = await AsyncStorage.getItem(DELIVERIES_KEY);
      const allDeliveries: BookDelivery[] = data ? JSON.parse(data) : [];

      const deliveries = allDeliveries.filter(d =>
        d.workerId === workerId &&
        new Date(d.deliveryTime).getTime() >= startDate.getTime()
      );

      const stats = {
        totalDeliveries: deliveries.length,
        deliveriesByStatus: {} as Record<DeliveryStatus, number>,
        deliveriesByType: {} as Record<string, number>,
        averagePerDay: deliveries.length / days,
      };

      const statuses: DeliveryStatus[] = ['pending', 'delivered_to_person', 'delivered_to_door', 'rejected', 'not_home', 'refused', 'follow_up', 'interested'];
      statuses.forEach(status => {
        stats.deliveriesByStatus[status] = 0;
      });

      deliveries.forEach(delivery => {
        stats.deliveriesByStatus[delivery.status]++;
        stats.deliveriesByType[delivery.deliveryType] = (stats.deliveriesByType[delivery.deliveryType] || 0) + 1;
      });

      return stats;
    } catch (error) {
      console.error('Error getting worker stats:', error);
      throw error;
    }
  }

  static async deleteDelivery(deliveryId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(DELIVERIES_KEY);
      const deliveries: any[] = data ? JSON.parse(data) : [];
      const filtered = deliveries.filter(d => d.id !== deliveryId);
      await AsyncStorage.setItem(DELIVERIES_KEY, JSON.stringify(filtered));
    } catch (error) {
      console.error('Error deleting delivery:', error);
      throw error;
    }
  }

  static async syncOfflineDeliveries(deliveries: BookDelivery[]): Promise<void> {
    try {
      const promises = deliveries
        .filter(delivery => delivery.syncStatus === 'pending')
        .map(delivery => this.createDelivery(delivery));

      await Promise.all(promises);
    } catch (error) {
      console.error('Error syncing offline deliveries:', error);
      throw error;
    }
  }
}

export default DeliveryService;
