import AsyncStorage from '@react-native-async-storage/async-storage';
import { Alert, Platform } from 'react-native';
import * as Location from 'expo-location';
import GeotrackingService, { LocationPoint } from './GeotrackingService';

export interface DeliveryPoint {
  id: string;
  latitude: number;
  longitude: number;
  accuracy: number;
  timestamp: number;
  address?: string;
}

export interface DeliveryRecord {
  id: string;
  bookTitle: string;
  bookId: string;
  deliveryType: 'to_door' | 'to_person';
  recipientName?: string;
  recipientContact?: string;
  location: DeliveryPoint;
  timestamp: number;
  sessionId?: string; // Link to geotracking session
  notes?: string;
  photos?: string[]; // Photo URLs
  barcode?: string; // Scanned barcode
  quantity: number;
  price?: number;
  paymentMethod?: 'cash' | 'card' | 'digital';
  isDonation: boolean;
  synced: boolean;
  teamId?: string;
  workerId?: string;
}

export interface DeliveryStats {
  todayDeliveries: number;
  todayToDoor: number;
  todayToPerson: number;
  todayDistance: number;
  weeklyDeliveries: number;
  totalDeliveries: number;
  averageDeliveryTime: number;
  mostActiveHour: number;
}

class DeliveryTrackingService {
  private static instance: DeliveryTrackingService;
  private currentSession: string | null = null;
  private deliveryQueue: DeliveryRecord[] = [];

  private readonly STORAGE_KEYS = {
    DELIVERIES: 'delivery_records',
    QUEUE: 'delivery_queue',
    STATS: 'delivery_stats',
    CURRENT_SESSION: 'delivery_current_session',
  };

  static getInstance(): DeliveryTrackingService {
    if (!DeliveryTrackingService.instance) {
      DeliveryTrackingService.instance = new DeliveryTrackingService();
    }
    return DeliveryTrackingService.instance;
  }

  // Initialize delivery tracking
  async initialize(): Promise<boolean> {
    try {
      // Load any pending deliveries from queue
      await this.loadDeliveryQueue();
      
      // Try to sync pending deliveries
      if (this.deliveryQueue.length > 0) {
        console.log(`Found ${this.deliveryQueue.length} pending deliveries to sync`);
        await this.syncPendingDeliveries();
      }

      return true;
    } catch (error) {
      console.error('Error initializing delivery tracking:', error);
      return false;
    }
  }

  // Start a new delivery session
  async startDeliverySession(): Promise<string> {
    try {
      const sessionId = `delivery_session_${Date.now()}`;
      this.currentSession = sessionId;
      
      // Start geotracking if not already active
      if (!GeotrackingService.isCurrentlyTracking()) {
        await GeotrackingService.startTracking('delivery');
      }

      await AsyncStorage.setItem(this.STORAGE_KEYS.CURRENT_SESSION, sessionId);
      console.log(`📦 Started delivery session: ${sessionId}`);
      
      return sessionId;
    } catch (error) {
      console.error('Error starting delivery session:', error);
      throw error;
    }
  }

  // Stop current delivery session
  async stopDeliverySession(): Promise<void> {
    try {
      if (this.currentSession) {
        // Sync any pending deliveries
        await this.syncPendingDeliveries();
        
        this.currentSession = null;
        await AsyncStorage.removeItem(this.STORAGE_KEYS.CURRENT_SESSION);
        console.log('📦 Stopped delivery session');
      }
    } catch (error) {
      console.error('Error stopping delivery session:', error);
      throw error;
    }
  }

  // Record a new delivery
  async recordDelivery(deliveryData: Omit<DeliveryRecord, 'id' | 'timestamp' | 'synced'>): Promise<DeliveryRecord> {
    try {
      // Get current location
      const currentLocation = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.High,
      });

      const location: DeliveryPoint = {
        id: `location_${Date.now()}`,
        latitude: currentLocation.coords.latitude,
        longitude: currentLocation.coords.longitude,
        accuracy: currentLocation.coords.accuracy || 0,
        timestamp: Date.now(),
      };

      const delivery: DeliveryRecord = {
        ...deliveryData,
        id: `delivery_${Date.now()}`,
        location,
        timestamp: Date.now(),
        synced: false,
        sessionId: this.currentSession || undefined,
      };

      // Add to queue for syncing
      this.deliveryQueue.push(delivery);
      await this.saveDeliveryQueue();

      // Try to sync immediately if online
      try {
        await this.syncDelivery(delivery);
        delivery.synced = true;
      } catch (syncError) {
        console.warn('Delivery queued for later sync:', syncError);
      }

      // Save to local storage
      await this.saveDelivery(delivery);
      await this.updateStats();

      console.log(`📦 Recorded delivery: ${delivery.bookTitle} (${delivery.deliveryType})`);
      return delivery;
    } catch (error) {
      console.error('Error recording delivery:', error);
      throw error;
    }
  }

  // Quick delivery recording (for "to door" deliveries)
  async quickDelivery(bookTitle: string, bookId: string, quantity: number = 1): Promise<DeliveryRecord> {
    const currentLocation = await this.getCurrentDeliveryLocation();
    return this.recordDelivery({
      bookTitle,
      bookId,
      deliveryType: 'to_door',
      quantity,
      isDonation: false,
      location: currentLocation || {
        id: `fallback_${Date.now()}`,
        latitude: 0,
        longitude: 0,
        accuracy: 0,
        timestamp: Date.now(),
      },
    });
  }

  // Person delivery with details
  async personDelivery(
    bookTitle: string,
    bookId: string,
    recipientName: string,
    recipientContact?: string,
    notes?: string,
    quantity: number = 1
  ): Promise<DeliveryRecord> {
    const currentLocation = await this.getCurrentDeliveryLocation();
    return this.recordDelivery({
      bookTitle,
      bookId,
      deliveryType: 'to_person',
      recipientName,
      recipientContact,
      notes,
      quantity,
      isDonation: false,
      location: currentLocation || {
        id: `fallback_${Date.now()}`,
        latitude: 0,
        longitude: 0,
        accuracy: 0,
        timestamp: Date.now(),
      },
    });
  }

  // Donation delivery
  async donationDelivery(
    bookTitle: string,
    bookId: string,
    amount: number,
    paymentMethod: 'cash' | 'card' | 'digital',
    recipientName?: string
  ): Promise<DeliveryRecord> {
    const currentLocation = await this.getCurrentDeliveryLocation();
    return this.recordDelivery({
      bookTitle,
      bookId,
      deliveryType: 'to_person',
      recipientName,
      price: amount,
      paymentMethod,
      quantity: 1,
      isDonation: true,
      location: currentLocation || {
        id: `fallback_${Date.now()}`,
        latitude: 0,
        longitude: 0,
        accuracy: 0,
        timestamp: Date.now(),
      },
    });
  }

  // Get current location for delivery
  async getCurrentDeliveryLocation(): Promise<DeliveryPoint | null> {
    try {
      const currentLocation = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.High,
      });

      return {
        id: `location_${Date.now()}`,
        latitude: currentLocation.coords.latitude,
        longitude: currentLocation.coords.longitude,
        accuracy: currentLocation.coords.accuracy || 0,
        timestamp: Date.now(),
      };
    } catch (error) {
      console.error('Error getting current location:', error);
      return null;
    }
  }

  // Get all deliveries
  async getDeliveries(): Promise<DeliveryRecord[]> {
    try {
      const deliveriesJson = await AsyncStorage.getItem(this.STORAGE_KEYS.DELIVERIES);
      return deliveriesJson ? JSON.parse(deliveriesJson) : [];
    } catch (error) {
      console.error('Error getting deliveries:', error);
      return [];
    }
  }

  // Get today's deliveries
  async getTodayDeliveries(): Promise<DeliveryRecord[]> {
    const allDeliveries = await this.getDeliveries();
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    return allDeliveries.filter(delivery => {
      return delivery.timestamp >= today.getTime();
    });
  }

  // Get deliveries by date range
  async getDeliveriesByDateRange(startDate: Date, endDate: Date): Promise<DeliveryRecord[]> {
    const allDeliveries = await this.getDeliveries();
    return allDeliveries.filter(delivery => {
      const deliveryDate = new Date(delivery.timestamp);
      return deliveryDate >= startDate && deliveryDate <= endDate;
    });
  }

  // Get delivery statistics
  async getStats(): Promise<DeliveryStats> {
    try {
      const statsJson = await AsyncStorage.getItem(this.STORAGE_KEYS.STATS);
      if (statsJson) {
        return JSON.parse(statsJson);
      }
    } catch (error) {
      console.error('Error getting stats:', error);
    }

    // Calculate stats if not cached
    return this.calculateStats();
  }

  // Calculate statistics from deliveries
  private async calculateStats(): Promise<DeliveryStats> {
    const deliveries = await this.getDeliveries();
    const now = Date.now();
    const weekAgo = now - (7 * 24 * 60 * 60 * 1000);
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const todayDeliveries = deliveries.filter(d => d.timestamp >= todayStart.getTime());
    const weeklyDeliveries = deliveries.filter(d => d.timestamp >= weekAgo);

    // Calculate average delivery time (time between deliveries)
    const deliveryTimes = todayDeliveries
      .map((d, i) => i > 0 ? d.timestamp - todayDeliveries[i - 1].timestamp : 0)
      .filter(t => t > 0);
    
    const avgDeliveryTime = deliveryTimes.length > 0 
      ? deliveryTimes.reduce((sum, t) => sum + t, 0) / deliveryTimes.length 
      : 0;

    // Find most active hour
    const hourCounts = new Array(24).fill(0);
    todayDeliveries.forEach(d => {
      const hour = new Date(d.timestamp).getHours();
      hourCounts[hour]++;
    });
    const mostActiveHour = hourCounts.indexOf(Math.max(...hourCounts));

    const stats: DeliveryStats = {
      todayDeliveries: todayDeliveries.length,
      todayToDoor: todayDeliveries.filter(d => d.deliveryType === 'to_door').length,
      todayToPerson: todayDeliveries.filter(d => d.deliveryType === 'to_person').length,
      todayDistance: await this.calculateTodayDeliveryDistance(todayDeliveries),
      weeklyDeliveries: weeklyDeliveries.length,
      totalDeliveries: deliveries.length,
      averageDeliveryTime: avgDeliveryTime,
      mostActiveHour,
    };

    await this.saveStats(stats);
    return stats;
  }

  // Calculate distance covered during deliveries today
  private async calculateTodayDeliveryDistance(deliveries: DeliveryRecord[]): Promise<number> {
    if (deliveries.length < 2) return 0;

    let totalDistance = 0;
    for (let i = 1; i < deliveries.length; i++) {
      const prev = deliveries[i - 1].location;
      const curr = deliveries[i].location;
      totalDistance += this.calculateDistance(prev, curr);
    }
    return totalDistance;
  }

  // Calculate distance between two points
  private calculateDistance(point1: DeliveryPoint, point2: DeliveryPoint): number {
    const R = 6371000; // Earth's radius in meters
    const lat1Rad = (point1.latitude * Math.PI) / 180;
    const lat2Rad = (point2.latitude * Math.PI) / 180;
    const deltaLatRad = ((point2.latitude - point1.latitude) * Math.PI) / 180;
    const deltaLonRad = ((point2.longitude - point1.longitude) * Math.PI) / 180;

    const a =
      Math.sin(deltaLatRad / 2) * Math.sin(deltaLatRad / 2) +
      Math.cos(lat1Rad) * Math.cos(lat2Rad) *
      Math.sin(deltaLonRad / 2) * Math.sin(deltaLonRad / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  // Sync delivery to backend
  private async syncDelivery(delivery: DeliveryRecord): Promise<void> {
    try {
      // This would integrate with your backend API
      const response = await fetch(`${__DEV__ ? (Platform.OS === 'android' ? 'http://10.0.2.2:8080' : 'http://localhost:8080') : 'https://api.rallypoint.app'}/api/deliveries`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          // Add auth token if needed
        },
        body: JSON.stringify(delivery),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      console.log(`📦 Synced delivery: ${delivery.id}`);
    } catch (error) {
      console.error('Error syncing delivery:', error);
      throw error;
    }
  }

  // Sync all pending deliveries
  async syncPendingDeliveries(): Promise<void> {
    const pendingDeliveries = this.deliveryQueue.filter(d => !d.synced);
    
    for (const delivery of pendingDeliveries) {
      try {
        await this.syncDelivery(delivery);
        delivery.synced = true;
        
        // Update in queue
        const queueIndex = this.deliveryQueue.findIndex(d => d.id === delivery.id);
        if (queueIndex >= 0) {
          this.deliveryQueue[queueIndex] = delivery;
        }
        
        // Update in storage
        await this.saveDelivery(delivery);
      } catch (error) {
        console.warn(`Failed to sync delivery ${delivery.id}:`, error);
      }
    }

    // Remove synced deliveries from queue
    this.deliveryQueue = this.deliveryQueue.filter(d => !d.synced);
    await this.saveDeliveryQueue();
  }

  // Save delivery to local storage
  private async saveDelivery(delivery: DeliveryRecord): Promise<void> {
    try {
      const deliveries = await this.getDeliveries();
      const existingIndex = deliveries.findIndex(d => d.id === delivery.id);
      
      if (existingIndex >= 0) {
        deliveries[existingIndex] = delivery;
      } else {
        deliveries.push(delivery);
      }
      
      await AsyncStorage.setItem(this.STORAGE_KEYS.DELIVERIES, JSON.stringify(deliveries));
    } catch (error) {
      console.error('Error saving delivery:', error);
    }
  }

  // Save delivery queue
  private async saveDeliveryQueue(): Promise<void> {
    try {
      await AsyncStorage.setItem(this.STORAGE_KEYS.DELIVERIES, JSON.stringify(this.deliveryQueue));
    } catch (error) {
      console.error('Error saving delivery queue:', error);
    }
  }

  // Load delivery queue
  private async loadDeliveryQueue(): Promise<void> {
    try {
      const queueJson = await AsyncStorage.getItem(this.STORAGE_KEYS.QUEUE);
      this.deliveryQueue = queueJson ? JSON.parse(queueJson) : [];
    } catch (error) {
      console.error('Error loading delivery queue:', error);
      this.deliveryQueue = [];
    }
  }

  // Save statistics
  private async saveStats(stats: DeliveryStats): Promise<void> {
    try {
      await AsyncStorage.setItem(this.STORAGE_KEYS.STATS, JSON.stringify(stats));
    } catch (error) {
      console.error('Error saving stats:', error);
    }
  }

  // Update statistics
  private async updateStats(): Promise<void> {
    await this.calculateStats();
  }

  // Delete delivery
  async deleteDelivery(deliveryId: string): Promise<void> {
    try {
      const deliveries = await this.getDeliveries();
      const filteredDeliveries = deliveries.filter(d => d.id !== deliveryId);
      await AsyncStorage.setItem(this.STORAGE_KEYS.DELIVERIES, JSON.stringify(filteredDeliveries));
      await this.updateStats();
    } catch (error) {
      console.error('Error deleting delivery:', error);
    }
  }

  // Get current session
  getCurrentSession(): string | null {
    return this.currentSession;
  }

  // Check if delivery session is active
  isDeliverySessionActive(): boolean {
    return this.currentSession !== null;
  }

  // Clear all data
  async clearAllData(): Promise<void> {
    try {
      await AsyncStorage.multiRemove([
        this.STORAGE_KEYS.DELIVERIES,
        this.STORAGE_KEYS.QUEUE,
        this.STORAGE_KEYS.STATS,
        this.STORAGE_KEYS.CURRENT_SESSION,
      ]);
      this.deliveryQueue = [];
      this.currentSession = null;
    } catch (error) {
      console.error('Error clearing all data:', error);
    }
  }

  // Get delivery route for today
  async getTodayRoute(): Promise<DeliveryPoint[]> {
    const todayDeliveries = await this.getTodayDeliveries();
    return todayDeliveries.map(d => d.location).sort((a, b) => a.timestamp - b.timestamp);
  }

  // Get delivery heatmap data
  async getDeliveryHeatmap(days: number = 7): Promise<{ latitude: number; longitude: number; weight: number }[]> {
    const deliveries = await this.getDeliveriesByDateRange(
      new Date(Date.now() - days * 24 * 60 * 60 * 1000),
      new Date()
    );

    // Group nearby deliveries for heatmap
    const heatmapPoints: { [key: string]: { latitude: number; longitude: number; weight: number } } = {};
    
    deliveries.forEach(delivery => {
      const key = `${Math.round(delivery.location.latitude * 1000)},${Math.round(delivery.location.longitude * 1000)}`;
      
      if (heatmapPoints[key]) {
        heatmapPoints[key].weight += 1;
      } else {
        heatmapPoints[key] = {
          latitude: delivery.location.latitude,
          longitude: delivery.location.longitude,
          weight: 1,
        };
      }
    });

    return Object.values(heatmapPoints);
  }
}

export default DeliveryTrackingService.getInstance();
