// Simplified Walkie-Talkie Hook - No Hanging, Smooth Operation
import { useState, useEffect, useCallback } from 'react';
import SimpleWalkieTalkieService, { SimpleWalkieTalkieState } from '../services/SimpleWalkieTalkieService';

export interface SimpleWalkieTalkieHook {
  // State
  state: SimpleWalkieTalkieState;
  isInitialized: boolean;
  
  // Actions (all instant)
  initialize: () => boolean;
  startTransmitting: (userId: string, userName: string, teamId: string) => boolean;
  stopTransmitting: () => void;
  cleanup: () => void;
  clearError: () => void;
}

export const useSimpleWalkieTalkie = (): SimpleWalkieTalkieHook => {
  const [state, setState] = useState<SimpleWalkieTalkieState>({
    isConnected: false,
    isTransmitting: false,
    isReceiving: false,
    isLoading: false,
    currentSpeaker: null,
    currentSpeakerName: null,
    sessionId: null,
    error: null,
  });
  
  const [isInitialized, setIsInitialized] = useState(false);
  const service = SimpleWalkieTalkieService.getInstance();

  // Subscribe to service state changes
  useEffect(() => {
    const unsubscribe = service.onStateChange((newState) => {
      setState(newState);
    });

    // Initialize current state
    setState(service.getState());

    return unsubscribe;
  }, []);

  // INSTANT initialization
  const initialize = useCallback((): boolean => {
    console.log('🎤 Hook: Initializing simple walkie-talkie...');
    
    try {
      const success = service.initialize();
      setIsInitialized(success);
      
      if (success) {
        console.log('✅ Hook: Simple walkie-talkie initialized');
      } else {
        console.error('❌ Hook: Simple walkie-talkie initialization failed');
      }
      
      return success;
    } catch (error) {
      console.error('❌ Hook: Initialization error:', error);
      service.setError('Initialization failed');
      setIsInitialized(false);
      return false;
    }
  }, [service]);

  // INSTANT start transmission
  const startTransmitting = useCallback((userId: string, userName: string, teamId: string): boolean => {
    console.log('🎤 Hook: Starting transmission...');
    
    try {
      // Auto-initialize if not initialized
      if (!isInitialized) {
        console.log('🎤 Auto-initializing...');
        const initialized = initialize();
        if (!initialized) {
          return false;
        }
      }

      const success = service.startTransmitting(userId, userName, teamId);
      
      if (success) {
        console.log('✅ Hook: Transmission started');
      } else {
        console.error('❌ Hook: Failed to start transmission');
      }
      
      return success;
    } catch (error) {
      console.error('❌ Hook: Start transmission error:', error);
      service.setError('Failed to start transmission');
      return false;
    }
  }, [service, isInitialized, initialize]);

  // INSTANT stop transmission
  const stopTransmitting = useCallback((): void => {
    console.log('🎤 Hook: Stopping transmission...');
    
    try {
      service.stopTransmitting();
      console.log('✅ Hook: Transmission stopped');
    } catch (error) {
      console.error('❌ Hook: Stop transmission error:', error);
      service.setError('Failed to stop transmission');
    }
  }, [service]);

  // Cleanup
  const cleanup = useCallback((): void => {
    console.log('🎤 Hook: Cleaning up...');
    
    try {
      service.cleanup();
      setIsInitialized(false);
      console.log('✅ Hook: Cleanup completed');
    } catch (error) {
      console.error('❌ Hook: Cleanup error:', error);
    }
  }, [service]);

  // Clear error
  const clearError = useCallback((): void => {
    service.clearError();
  }, [service]);

  return {
    state,
    isInitialized,
    initialize,
    startTransmitting,
    stopTransmitting,
    cleanup,
    clearError,
  };
};
