import { useState, useEffect, useCallback } from 'react';
import { OfflineManager, NetworkStatus } from '../services/OfflineManager';
import { SurveyResponse } from '../types/survey';

export interface OfflineManagerState {
  networkStatus: NetworkStatus;
  pendingSyncCount: number;
  syncInProgress: boolean;
  lastSyncTime: Date | null;
  offlineResponses: SurveyResponse[];
}

export interface OfflineManagerActions {
  syncNow: () => Promise<{ success: number; failed: number }>;
  storeOfflineResponse: (response: SurveyResponse) => Promise<void>;
  clearOfflineData: () => Promise<void>;
  refreshOfflineData: () => Promise<void>;
}

export const useOfflineManager = (): [OfflineManagerState, OfflineManagerActions] => {
  const [state, setState] = useState<OfflineManagerState>({
    networkStatus: {
      isConnected: false,
      type: null,
      isInternetReachable: null
    },
    pendingSyncCount: 0,
    syncInProgress: false,
    lastSyncTime: null,
    offlineResponses: []
  });

  const offlineManager = OfflineManager.getInstance();

  // Load initial data
  const loadInitialData = useCallback(async () => {
    try {
      const [
        pendingCount,
        lastSync,
        offlineResponses
      ] = await Promise.all([
        offlineManager.getPendingSyncCount(),
        offlineManager.getLastSyncTime(),
        offlineManager.getOfflineResponses()
      ]);

      setState(prev => ({
        ...prev,
        pendingSyncCount: pendingCount,
        lastSyncTime: lastSync,
        offlineResponses: offlineResponses,
        syncInProgress: offlineManager.isSyncInProgress()
      }));
    } catch (error) {
      console.error('Error loading offline manager data:', error);
    }
  }, [offlineManager]);

  // Network status listener
  useEffect(() => {
    const handleNetworkChange = (networkStatus: NetworkStatus) => {
      setState(prev => ({
        ...prev,
        networkStatus
      }));
    };

    offlineManager.addNetworkListener(handleNetworkChange);
    loadInitialData();

    return () => {
      offlineManager.removeNetworkListener(handleNetworkChange);
    };
  }, [offlineManager, loadInitialData]);

  // Periodic data refresh
  useEffect(() => {
    const interval = setInterval(async () => {
      try {
        const [pendingCount, offlineResponses] = await Promise.all([
          offlineManager.getPendingSyncCount(),
          offlineManager.getOfflineResponses()
        ]);

        setState(prev => ({
          ...prev,
          pendingSyncCount: pendingCount,
          offlineResponses: offlineResponses,
          syncInProgress: offlineManager.isSyncInProgress()
        }));
      } catch (error) {
        console.error('Error refreshing offline data:', error);
      }
    }, 5000); // Refresh every 5 seconds

    return () => clearInterval(interval);
  }, [offlineManager]);

  // Actions
  const syncNow = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, syncInProgress: true }));
      
      const result = await offlineManager.syncOfflineData();
      
      // Refresh data after sync
      await loadInitialData();
      
      return result;
    } catch (error) {
      console.error('Error during manual sync:', error);
      throw error;
    } finally {
      setState(prev => ({ ...prev, syncInProgress: false }));
    }
  }, [offlineManager, loadInitialData]);

  const storeOfflineResponse = useCallback(async (response: SurveyResponse) => {
    try {
      await offlineManager.storeOfflineResponse(response);
      await loadInitialData(); // Refresh counts
    } catch (error) {
      console.error('Error storing offline response:', error);
      throw error;
    }
  }, [offlineManager, loadInitialData]);

  const clearOfflineData = useCallback(async () => {
    try {
      await offlineManager.clearOfflineData();
      await loadInitialData(); // Refresh state
    } catch (error) {
      console.error('Error clearing offline data:', error);
      throw error;
    }
  }, [offlineManager, loadInitialData]);

  const refreshOfflineData = useCallback(async () => {
    await loadInitialData();
  }, [loadInitialData]);

  const actions: OfflineManagerActions = {
    syncNow,
    storeOfflineResponse,
    clearOfflineData,
    refreshOfflineData
  };

  return [state, actions];
};

// Hook for network status only
export const useNetworkStatus = (): NetworkStatus => {
  const [networkStatus, setNetworkStatus] = useState<NetworkStatus>({
    isConnected: false,
    type: null,
    isInternetReachable: null
  });

  useEffect(() => {
    const offlineManager = OfflineManager.getInstance();
    
    const handleNetworkChange = (status: NetworkStatus) => {
      setNetworkStatus(status);
    };

    offlineManager.addNetworkListener(handleNetworkChange);

    return () => {
      offlineManager.removeNetworkListener(handleNetworkChange);
    };
  }, []);

  return networkStatus;
};

// Hook for sync status only
export const useSyncStatus = () => {
  const [syncStatus, setSyncStatus] = useState({
    pendingCount: 0,
    syncInProgress: false,
    lastSyncTime: null as Date | null
  });

  useEffect(() => {
    const offlineManager = OfflineManager.getInstance();
    
    const updateSyncStatus = async () => {
      try {
        const [pendingCount, lastSync] = await Promise.all([
          offlineManager.getPendingSyncCount(),
          offlineManager.getLastSyncTime()
        ]);

        setSyncStatus({
          pendingCount,
          syncInProgress: offlineManager.isSyncInProgress(),
          lastSyncTime: lastSync
        });
      } catch (error) {
        console.error('Error updating sync status:', error);
      }
    };

    // Initial load
    updateSyncStatus();

    // Periodic updates
    const interval = setInterval(updateSyncStatus, 3000);

    return () => clearInterval(interval);
  }, []);

  return syncStatus;
};

export default useOfflineManager;
