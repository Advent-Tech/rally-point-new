import OfflineManager, { OfflineDeliveryData } from './OfflineManager';
import { DeliveryService } from './DeliveryService';
import { BookDelivery, DeliveryStatus } from '../types/delivery';

export interface DeliveryLocationData {
  latitude: number;
  longitude: number;
  address?: string;
  timestamp: number;
}

export interface OfflineDeliveryRecord {
  id: string;
  workerId: string;
  workerName: string;
  bookTitle: string;
  deliveryType: 'door' | 'person';
  location: DeliveryLocationData;
  status: DeliveryStatus;
  notes?: string;
  sessionId?: string;
  timestamp: number;
}

class OfflineDeliveryService {
  private offlineManager: OfflineManager;

  constructor() {
    this.offlineManager = OfflineManager.getInstance();
  }

  /**
   * Record a delivery - handles both online and offline scenarios
   */
  async recordDelivery(deliveryData: OfflineDeliveryRecord): Promise<string> {
    try {
      const networkStatus = this.offlineManager.getNetworkStatus();
      
      if (networkStatus.isConnected) {
        // Online: Save directly to Firebase
        try {
          const firebaseDelivery = {
            workerId: deliveryData.workerId,
            workerName: deliveryData.workerName,
            bookTitle: deliveryData.bookTitle,
            deliveryType: deliveryData.deliveryType,
            location: {
              latitude: deliveryData.location.latitude,
              longitude: deliveryData.location.longitude,
              address: deliveryData.location.address,
            },
            deliveryTime: new Date(deliveryData.timestamp),
            status: deliveryData.status,
            notes: deliveryData.notes,
            sessionId: deliveryData.sessionId,
          };

          const deliveryId = await DeliveryService.createDelivery(firebaseDelivery);
          console.log('✅ Delivery recorded online:', deliveryId);
          return deliveryId;
        } catch (error) {
          console.error('❌ Failed to save delivery online, storing offline:', error);
          // Fall back to offline storage
          return await this.storeDeliveryOffline(deliveryData);
        }
      } else {
        // Offline: Store locally
        return await this.storeDeliveryOffline(deliveryData);
      }
    } catch (error) {
      console.error('❌ Error recording delivery:', error);
      throw error;
    }
  }

  /**
   * Store delivery data offline
   */
  private async storeDeliveryOffline(deliveryData: OfflineDeliveryRecord): Promise<string> {
    try {
      const offlineDeliveryData: OfflineDeliveryData = {
        id: deliveryData.id,
        workerId: deliveryData.workerId,
        workerName: deliveryData.workerName,
        bookTitle: deliveryData.bookTitle,
        deliveryType: deliveryData.deliveryType,
        location: deliveryData.location,
        timestamp: deliveryData.timestamp,
        status: deliveryData.status,
        notes: deliveryData.notes,
        sessionId: deliveryData.sessionId,
        syncStatus: 'pending'
      };

      await this.offlineManager.storeOfflineDelivery(offlineDeliveryData);
      console.log('✅ Delivery stored offline:', deliveryData.id);
      return deliveryData.id;
    } catch (error) {
      console.error('❌ Error storing delivery offline:', error);
      throw error;
    }
  }

  /**
   * Get all offline deliveries
   */
  async getOfflineDeliveries(): Promise<OfflineDeliveryData[]> {
    try {
      return await this.offlineManager.getOfflineDeliveries();
    } catch (error) {
      console.error('❌ Error getting offline deliveries:', error);
      return [];
    }
  }

  /**
   * Get offline deliveries by session
   */
  async getOfflineDeliveriesBySession(sessionId: string): Promise<OfflineDeliveryData[]> {
    try {
      return await this.offlineManager.getOfflineDeliveriesBySession(sessionId);
    } catch (error) {
      console.error('❌ Error getting offline deliveries by session:', error);
      return [];
    }
  }

  /**
   * Get pending sync count for deliveries
   */
  async getPendingDeliveryCount(): Promise<number> {
    try {
      const offlineDeliveries = await this.offlineManager.getOfflineDeliveries();
      return offlineDeliveries.filter(d => d.syncStatus === 'pending').length;
    } catch (error) {
      console.error('❌ Error getting pending delivery count:', error);
      return 0;
    }
  }

  /**
   * Manually sync offline deliveries
   */
  async syncOfflineDeliveries(): Promise<{ success: number; failed: number }> {
    try {
      const result = await this.offlineManager.syncOfflineData();
      console.log('✅ Offline deliveries sync completed:', result);
      return result;
    } catch (error) {
      console.error('❌ Error syncing offline deliveries:', error);
      return { success: 0, failed: 0 };
    }
  }

  /**
   * Create a delivery record with current location
   */
  async createDeliveryWithLocation(
    workerId: string,
    workerName: string,
    bookTitle: string,
    deliveryType: 'door' | 'person',
    status: DeliveryStatus,
    notes?: string,
    sessionId?: string
  ): Promise<string> {
    try {
      // Get current location
      let currentLocation: DeliveryLocationData;
      
      if (typeof navigator !== 'undefined' && navigator.geolocation) {
        // Web platform
        currentLocation = await new Promise((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(
            (position) => {
              resolve({
                latitude: position.coords.latitude,
                longitude: position.coords.longitude,
                timestamp: Date.now()
              });
            },
            (error) => {
              console.warn('Failed to get location:', error);
              // Use default location if geolocation fails
              resolve({
                latitude: 0,
                longitude: 0,
                timestamp: Date.now()
              });
            },
            { enableHighAccuracy: true, timeout: 10000, maximumAge: 30000 }
          );
        });
      } else {
        // Mobile platform - would use Expo Location
        try {
          const Location = require('expo-location');
          const location = await Location.getCurrentPositionAsync({
            accuracy: Location.Accuracy.High,
          });
          
          currentLocation = {
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
            timestamp: Date.now()
          };
        } catch (error) {
          console.warn('Failed to get mobile location:', error);
          // Use default location if geolocation fails
          currentLocation = {
            latitude: 0,
            longitude: 0,
            timestamp: Date.now()
          };
        }
      }

      const deliveryRecord: OfflineDeliveryRecord = {
        id: `delivery_${workerId}_${Date.now()}`,
        workerId,
        workerName,
        bookTitle,
        deliveryType,
        location: currentLocation,
        status,
        notes,
        sessionId,
        timestamp: Date.now()
      };

      return await this.recordDelivery(deliveryRecord);
    } catch (error) {
      console.error('❌ Error creating delivery with location:', error);
      throw error;
    }
  }

  /**
   * Get delivery statistics including offline data
   */
  async getDeliveryStats(workerId: string, days: number = 7): Promise<{
    totalDeliveries: number;
    onlineDeliveries: number;
    offlineDeliveries: number;
    pendingSync: number;
    deliveriesByStatus: Record<DeliveryStatus, number>;
  }> {
    try {
      const [onlineStats, offlineDeliveries] = await Promise.all([
        DeliveryService.getWorkerStats(workerId, days).catch(() => ({
          totalDeliveries: 0,
          deliveriesByStatus: {} as Record<DeliveryStatus, number>,
          deliveriesByType: {},
          averagePerDay: 0
        })),
        this.getOfflineDeliveries()
      ]);

      const workerOfflineDeliveries = offlineDeliveries.filter(d => d.workerId === workerId);
      const pendingSync = workerOfflineDeliveries.filter(d => d.syncStatus === 'pending').length;

      // Combine online and offline stats
      const combinedStats = {
        totalDeliveries: onlineStats.totalDeliveries + workerOfflineDeliveries.length,
        onlineDeliveries: onlineStats.totalDeliveries,
        offlineDeliveries: workerOfflineDeliveries.length,
        pendingSync,
        deliveriesByStatus: { ...onlineStats.deliveriesByStatus } as Record<DeliveryStatus, number>
      };

      // Add offline deliveries to status counts
      workerOfflineDeliveries.forEach(delivery => {
        combinedStats.deliveriesByStatus[delivery.status] = 
          (combinedStats.deliveriesByStatus[delivery.status] || 0) + 1;
      });

      return combinedStats;
    } catch (error) {
      console.error('❌ Error getting delivery stats:', error);
      return {
        totalDeliveries: 0,
        onlineDeliveries: 0,
        offlineDeliveries: 0,
        pendingSync: 0,
        deliveriesByStatus: {} as Record<DeliveryStatus, number>
      };
    }
  }
}

export default OfflineDeliveryService;
