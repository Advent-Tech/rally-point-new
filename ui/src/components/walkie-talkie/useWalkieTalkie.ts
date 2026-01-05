/**
 * useWalkieTalkie Hook
 * React hook for easy integration with the WalkieTalkie service
 */

import { useEffect, useState, useCallback, useRef } from 'react';
import { 
  UseWalkieTalkieReturn, 
  WalkieTalkieConfig, 
  WalkieTalkieServiceState 
} from './types';
import { WalkieTalkieService } from './WalkieTalkieService';

interface RecordingJob {
  id: string;
  state: 'recording' | 'stopping' | 'processing' | 'uploading' | 'completed' | 'failed';
  duration?: number;
  uploadProgress?: number;
  error?: any;
}

export function useWalkieTalkie(): UseWalkieTalkieReturn {
  const serviceRef = useRef<WalkieTalkieService | null>(null);
  const [state, setState] = useState<WalkieTalkieServiceState>(() => {
    const service = WalkieTalkieService.getInstance();
    return service.getState();
  });

  // Initialize service reference
  useEffect(() => {
    serviceRef.current = WalkieTalkieService.getInstance();
    
    // Subscribe to state changes
    const unsubscribe = serviceRef.current && serviceRef.current['stateManager']?.subscribe ? 
      serviceRef.current['stateManager'].subscribe(setState) : 
      null;

    // Initial state sync
    setState(serviceRef.current.getState());

    return () => {
      if (unsubscribe) {
        unsubscribe();
      }
    };
  }, []);

  /**
   * Initialize the walkie-talkie service
   */
  const initialize = useCallback(async (config: WalkieTalkieConfig): Promise<void> => {
    console.log('🎯 useWalkieTalkie.initialize() called with config:', config);
    
    if (!serviceRef.current) {
      console.error('❌ serviceRef.current is null - cannot initialize');
      return;
    }
    
    try {
      console.log('🎯 Calling WalkieTalkieService.initialize()...');
      await serviceRef.current.initialize(config);
      console.log('🎯 WalkieTalkieService.initialize() completed successfully');
    } catch (error) {
      console.error('❌ Failed to initialize walkie-talkie:', error);
      throw error;
    }
  }, []);

  /**
   * Start recording (non-blocking)
   */
  const startRecording = useCallback((): void => {
    if (!serviceRef.current) return;
    
    // Start recording asynchronously (non-blocking)
    serviceRef.current.startRecording()
      .then(recordingId => {
        console.log('✅ Recording started:', recordingId);
      })
      .catch(error => {
        console.error('❌ Failed to start recording:', error);
      });
  }, []);

  /**
   * Stop recording (non-blocking)
   */
  const stopRecording = useCallback((): void => {
    if (!serviceRef.current) return;
    
    // Stop recording asynchronously (non-blocking)
    serviceRef.current.stopRecording()
      .then(recording => {
        console.log('✅ Recording stopped:', recording.id);
        // Send message asynchronously (non-blocking)
        return serviceRef.current?.sendMessage(recording);
      })
      .then(message => {
        if (message) {
          console.log('✅ Message sent:', message.id);
        }
      })
      .catch(error => {
        console.error('❌ Failed to stop recording or send message:', error);
      });
  }, []);

  /**
   * Play a specific message
   */
  const playMessage = useCallback(async (messageId: string): Promise<void> => {
    if (!serviceRef.current) return;
    
    try {
      await serviceRef.current.playMessage(messageId);
    } catch (error) {
      console.error('Failed to play message:', error);
      throw error;
    }
  }, []);

  /**
   * Clear current error
   */
  const clearError = useCallback((): void => {
    if (!serviceRef.current) return;
    serviceRef.current.clearError();
  }, []);

  /**
   * Retry last failed operation
   */
  const retry = useCallback(async (): Promise<void> => {
    if (!serviceRef.current) return;
    
    try {
      await serviceRef.current.retry();
    } catch (error) {
      console.error('Retry failed:', error);
      throw error;
    }
  }, []);

  // Computed properties
  const isReady = state.connectionState === 'connected' && state.state === 'ready';
  const canStartRecording = state.canRecord && !state.isRecording && !state.isProcessing;
  const hasError = state.error !== null;
  const isConnected = state.connectionState === 'connected';

  return {
    // State
    state,
    
    // Actions
    initialize,
    startRecording,
    stopRecording,
    playMessage,
    clearError,
    retry,
    
    // Computed
    isReady,
    canStartRecording,
    hasError,
    isConnected,
  };
}
