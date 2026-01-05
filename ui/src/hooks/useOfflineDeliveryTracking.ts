import { useState, useEffect, useCallback } from 'react';
import OfflineDeliveryService, { OfflineDeliveryRecord } from '../services/OfflineDeliveryService';
import { OfflineDeliveryData } from '../services/OfflineManager';
import { DeliveryStatus } from '../types/delivery';
import { useNetworkStatus } from './useOfflineManager';

export interface DeliveryTrackingState {
  offlineDeliveries: OfflineDeliveryData[];
  pendingSyncCount: number;
  totalDeliveries: number;
  deliveriesByStatus: Record<DeliveryStatus, number>;
  isLoading: boolean;
  lastSync: Date | null;
}

export interface DeliveryTrackingActions {
  recordDelivery: (deliveryData: OfflineDeliveryRecord) => Promise<string>;
  createDeliveryWithLocation: (
    workerId: string,
    workerName: string,
    bookTitle: string,
    deliveryType: 'door' | 'person',
    status: DeliveryStatus,
    notes?: string,
    sessionId?: string
  ) => Promise<string>;
  syncOfflineDeliveries: () => Promise<{ success: number; failed: number }>;
  getOfflineDeliveriesBySession: (sessionId: string) => Promise<OfflineDeliveryData[]>;
  getDeliveryStats: (workerId: string, days?: number) => Promise<any>;
  refreshData: () => Promise<void>;
}

export const useOfflineDeliveryTracking = (workerId?: string): [DeliveryTrackingState, DeliveryTrackingActions] => {
  const [state, setState] = useState<DeliveryTrackingState>({
    offlineDeliveries: [],
    pendingSyncCount: 0,
    totalDeliveries: 0,
    deliveriesByStatus: {} as Record<DeliveryStatus, number>,
    isLoading: false,
    lastSync: null,
  });

  const networkStatus = useNetworkStatus();
  const offlineDeliveryService = new OfflineDeliveryService();

  // Load offline delivery data
  const loadOfflineData = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, isLoading: true }));

      const offlineDeliveries = await offlineDeliveryService.getOfflineDeliveries();
      const userDeliveries = workerId 
        ? offlineDeliveries.filter(d => d.workerId === workerId)
        : offlineDeliveries;

      const pendingSync = userDeliveries.filter(d => d.syncStatus === 'pending').length;

      // Calculate deliveries by status
      const deliveriesByStatus = {} as Record<DeliveryStatus, number>;
      const statuses: DeliveryStatus[] = [
        'pending', 'delivered_to_person', 'delivered_to_door', 
        'rejected', 'not_home', 'refused', 'follow_up', 'interested'
      ];
      
      statuses.forEach(status => {
        deliveriesByStatus[status] = userDeliveries.filter(d => d.status === status).length;
      });

      setState(prev => ({
        ...prev,
        offlineDeliveries: userDeliveries,
        pendingSyncCount: pendingSync,
        totalDeliveries: userDeliveries.length,
        deliveriesByStatus,
        isLoading: false,
        lastSync: new Date(),
      }));
    } catch (error) {
      console.error('Error loading offline delivery data:', error);
      setState(prev => ({ ...prev, isLoading: false }));
    }
  }, [workerId, offlineDeliveryService]);

  // Load data on mount and when network status changes
  useEffect(() => {
    loadOfflineData();
  }, [loadOfflineData, networkStatus.isConnected]);

  // Periodic data refresh
  useEffect(() => {
    const interval = setInterval(loadOfflineData, 10000); // Refresh every 10 seconds
    return () => clearInterval(interval);
  }, [loadOfflineData]);

  // Record a delivery
  const recordDelivery = useCallback(async (deliveryData: OfflineDeliveryRecord) => {
    try {
      console.log('📦 Recording delivery:', deliveryData.bookTitle);
      
      const deliveryId = await offlineDeliveryService.recordDelivery(deliveryData);
      
      // Refresh data to show new delivery
      await loadOfflineData();
      
      console.log('✅ Delivery recorded:', deliveryId);
      return deliveryId;
    } catch (error) {
      console.error('❌ Error recording delivery:', error);
      throw error;
    }
  }, [offlineDeliveryService, loadOfflineData]);

  // Create delivery with current location
  const createDeliveryWithLocation = useCallback(async (
    workerId: string,
    workerName: string,
    bookTitle: string,
    deliveryType: 'door' | 'person',
    status: DeliveryStatus,
    notes?: string,
    sessionId?: string
  ) => {
    try {
      console.log('📍 Creating delivery with location:', bookTitle);
      
      const deliveryId = await offlineDeliveryService.createDeliveryWithLocation(
        workerId,
        workerName,
        bookTitle,
        deliveryType,
        status,
        notes,
        sessionId
      );
      
      // Refresh data to show new delivery
      await loadOfflineData();
      
      console.log('✅ Delivery with location created:', deliveryId);
      return deliveryId;
    } catch (error) {
      console.error('❌ Error creating delivery with location:', error);
      throw error;
    }
  }, [offlineDeliveryService, loadOfflineData]);

  // Sync offline deliveries
  const syncOfflineDeliveries = useCallback(async () => {
    try {
      console.log('🔄 Syncing offline deliveries');
      
      const result = await offlineDeliveryService.syncOfflineDeliveries();
      
      // Refresh data after sync
      await loadOfflineData();
      
      console.log('✅ Offline deliveries synced:', result);
      return result;
    } catch (error) {
      console.error('❌ Error syncing offline deliveries:', error);
      return { success: 0, failed: 0 };
    }
  }, [offlineDeliveryService, loadOfflineData]);

  // Get offline deliveries by session
  const getOfflineDeliveriesBySession = useCallback(async (sessionId: string) => {
    try {
      return await offlineDeliveryService.getOfflineDeliveriesBySession(sessionId);
    } catch (error) {
      console.error('❌ Error getting offline deliveries by session:', error);
      return [];
    }
  }, [offlineDeliveryService]);

  // Get delivery statistics
  const getDeliveryStats = useCallback(async (workerId: string, days: number = 7) => {
    try {
      return await offlineDeliveryService.getDeliveryStats(workerId, days);
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
  }, [offlineDeliveryService]);

  // Refresh data manually
  const refreshData = useCallback(async () => {
    await loadOfflineData();
  }, [loadOfflineData]);

  const actions: DeliveryTrackingActions = {
    recordDelivery,
    createDeliveryWithLocation,
    syncOfflineDeliveries,
    getOfflineDeliveriesBySession,
    getDeliveryStats,
    refreshData,
  };

  return [state, actions];
};

// Hook for quick delivery recording
export const useQuickDelivery = (workerId: string, workerName: string, sessionId?: string) => {
  const [, actions] = useOfflineDeliveryTracking(workerId);

  const recordQuickDelivery = useCallback(async (
    bookTitle: string,
    deliveryType: 'door' | 'person',
    status: DeliveryStatus,
    notes?: string
  ) => {
    try {
      return await actions.createDeliveryWithLocation(
        workerId,
        workerName,
        bookTitle,
        deliveryType,
        status,
        notes,
        sessionId
      );
    } catch (error) {
      console.error('❌ Error recording quick delivery:', error);
      throw error;
    }
  }, [actions, workerId, workerName, sessionId]);

  return { recordQuickDelivery };
};

// Hook for delivery statistics
export const useDeliveryStats = (workerId: string, days: number = 7) => {
  const [stats, setStats] = useState({
    totalDeliveries: 0,
    onlineDeliveries: 0,
    offlineDeliveries: 0,
    pendingSync: 0,
    deliveriesByStatus: {} as Record<DeliveryStatus, number>,
    isLoading: false,
  });

  const offlineDeliveryService = new OfflineDeliveryService();

  useEffect(() => {
    const loadStats = async () => {
      try {
        setStats(prev => ({ ...prev, isLoading: true }));
        
        const deliveryStats = await offlineDeliveryService.getDeliveryStats(workerId, days);
        
        setStats({
          ...deliveryStats,
          isLoading: false,
        });
      } catch (error) {
        console.error('Error loading delivery stats:', error);
        setStats(prev => ({ ...prev, isLoading: false }));
      }
    };

    loadStats();
    const interval = setInterval(loadStats, 30000); // Update every 30 seconds
    
    return () => clearInterval(interval);
  }, [workerId, days, offlineDeliveryService]);

  return stats;
};

export default useOfflineDeliveryTracking;
