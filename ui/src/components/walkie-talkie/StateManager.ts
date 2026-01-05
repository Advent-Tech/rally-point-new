/**
 * Walkie-Talkie State Manager
 * Centralized state management with proper event handling and persistence
 */

import { 
  WalkieTalkieServiceState, 
  WalkieTalkieState, 
  ConnectionState, 
  AudioState,
  WalkieTalkieEvent,
  VoiceMessage,
  WalkieTalkieError 
} from './types';

type StateListener = (state: WalkieTalkieServiceState) => void;
type EventListener = (event: WalkieTalkieEvent) => void;

export class WalkieTalkieStateManager {
  private state: WalkieTalkieServiceState;
  private stateListeners: Set<StateListener> = new Set();
  private eventListeners: Map<string, Set<EventListener>> = new Map();

  constructor() {
    this.state = this.getInitialState();
  }

  /**
   * Get current state
   */
  getState(): WalkieTalkieServiceState {
    return { ...this.state };
  }

  /**
   * Update state and notify listeners
   */
  setState(updates: Partial<WalkieTalkieServiceState>): void {
    const previousState = { ...this.state };
    this.state = { ...this.state, ...updates };
    
    // Log state changes in development
    if (__DEV__) {
      console.log('🔄 WalkieTalkie State Update:', {
        previous: this.getChangedFields(previousState, this.state),
        current: this.getChangedFields(this.state, previousState),
      });
    }

    this.notifyStateListeners();
  }

  /**
   * Update specific state field
   */
  updateState<K extends keyof WalkieTalkieServiceState>(
    key: K,
    value: WalkieTalkieServiceState[K]
  ): void {
    this.setState({ [key]: value } as Partial<WalkieTalkieServiceState>);
  }

  /**
   * Set walkie-talkie state
   */
  setWalkieTalkieState(state: WalkieTalkieState): void {
    this.setState({ state });
    this.emit({ type: 'STATE_CHANGED', payload: { state } });
  }

  /**
   * Set connection state
   */
  setConnectionState(connectionState: ConnectionState): void {
    this.setState({ 
      connectionState,
      isInitialized: connectionState === 'connected'
    });
    this.emit({ type: 'CONNECTION_CHANGED', payload: { connectionState } });
  }

  /**
   * Set audio state
   */
  setAudioState(audioState: AudioState): void {
    this.setState({ audioState });
  }

  /**
   * Set error
   */
  setError(error: WalkieTalkieError | null): void {
    this.setState({ 
      error,
      lastError: error || this.state.lastError,
      state: error ? 'error' : 'ready'
    });
    
    if (error) {
      this.emit({ type: 'ERROR_OCCURRED', payload: { error } });
    } else {
      this.emit({ type: 'ERROR_CLEARED', payload: {} });
    }
  }

  /**
   * Clear current error
   */
  clearError(): void {
    this.setError(null);
  }

  /**
   * Start recording
   */
  startRecording(recordingId: string): void {
    this.setState({
      isRecording: true,
      recordingDuration: 0,
      state: 'recording',
      error: null
    });
    this.emit({ type: 'RECORDING_STARTED', payload: { recordingId } });
  }

  /**
   * Update recording duration
   */
  updateRecordingDuration(duration: number): void {
    this.setState({ recordingDuration: duration });
  }

  /**
   * Stop recording (immediately ready for next recording)
   */
  stopRecording(recordingId: string, duration: number): void {
    this.setState({
      isRecording: false,
      recordingDuration: 0,
      isProcessing: false,
      state: 'ready' // Immediately ready, not processing
    });
    this.emit({ type: 'RECORDING_STOPPED', payload: { recordingId, duration } });
  }

  /**
   * Set processing state
   */
  setProcessing(isProcessing: boolean): void {
    this.setState({ 
      isProcessing,
      state: isProcessing ? 'processing' : 'ready'
    });
  }

  /**
   * Set uploading state
   */
  setUploading(isUploading: boolean, progress: number = 0): void {
    this.setState({ 
      isUploading,
      uploadProgress: progress,
      state: isUploading ? 'uploading' : 'ready'
    });
    
    if (isUploading) {
      this.emit({ type: 'UPLOAD_PROGRESS', payload: { progress } });
    }
  }

  /**
   * Update real-time audio level (0-1)
   */
  updateAudioLevel(level: number): void {
    // Clamp level between 0 and 1
    const clampedLevel = Math.max(0, Math.min(1, level));
    this.setState({ audioLevel: clampedLevel });
  }

  /**
   * Add new message
   */
  addMessage(message: VoiceMessage): void {
    const messages = [...this.state.messages, message];
    const unreadCount = message.isOwn ? this.state.unreadCount : this.state.unreadCount + 1;
    const totalReceived = message.isOwn ? this.state.totalMessagesReceived : this.state.totalMessagesReceived + 1;
    const totalSent = message.isOwn ? this.state.totalMessagesSent + 1 : this.state.totalMessagesSent;

    this.setState({
      messages,
      unreadCount,
      totalMessagesReceived: totalReceived,
      totalMessagesSent: totalSent
    });

    if (message.isOwn) {
      this.emit({ type: 'MESSAGE_SENT', payload: { message } });
    } else {
      this.emit({ type: 'MESSAGE_RECEIVED', payload: { message } });
    }
  }

  /**
   * Mark message as read
   */
  markAsRead(messageId: string): void {
    const message = this.state.messages.find(m => m.id === messageId);
    if (message && !message.isOwn) {
      this.setState({
        unreadCount: Math.max(0, this.state.unreadCount - 1)
      });
    }
  }

  /**
   * Set playback state
   */
  setPlaybackState(isPlaying: boolean, currentMessageId?: string, senderName?: string): void {
    this.setState({
      isPlayingMessage: isPlaying,
      currentPlayingMessageId: currentMessageId || null,
      currentPlayingSender: senderName || null
    });
    
    if (isPlaying && currentMessageId) {
      this.emit({ type: 'PLAYBACK_STARTED', payload: { messageId: currentMessageId, senderName } });
    } else {
      this.emit({ type: 'PLAYBACK_STOPPED', payload: {} });
    }
  }

  /**
   * Clear all messages
   */
  clearMessages(): void {
    this.setState({
      messages: [],
      unreadCount: 0
    });
  }

  /**
   * Reset state to initial
   */
  reset(): void {
    this.state = this.getInitialState();
    this.notifyStateListeners();
  }

  /**
   * Subscribe to state changes
   */
  subscribe(listener: StateListener): () => void {
    this.stateListeners.add(listener);
    return () => {
      this.stateListeners.delete(listener);
    };
  }

  /**
   * Subscribe to specific events
   */
  on(eventType: string, listener: EventListener): () => void {
    if (!this.eventListeners.has(eventType)) {
      this.eventListeners.set(eventType, new Set());
    }
    this.eventListeners.get(eventType)!.add(listener);
    
    return () => {
      const listeners = this.eventListeners.get(eventType);
      if (listeners) {
        listeners.delete(listener);
        if (listeners.size === 0) {
          this.eventListeners.delete(eventType);
        }
      }
    };
  }

  /**
   * Emit event to listeners
   */
  emit(event: WalkieTalkieEvent): void {
    const listeners = this.eventListeners.get(event.type);
    if (listeners) {
      listeners.forEach(listener => {
        try {
          listener(event);
        } catch (error) {
          console.error('Error in event listener:', error);
        }
      });
    }
  }

  /**
   * Get computed properties
   */
  getComputedState() {
    return {
      isReady: this.state.connectionState === 'connected' && this.state.state === 'ready',
      canStartRecording: this.state.canRecord && !this.state.isRecording && !this.state.isProcessing,
      hasError: this.state.error !== null,
      isConnected: this.state.connectionState === 'connected',
      isBusy: this.state.isRecording || this.state.isProcessing || this.state.isUploading,
    };
  }

  // Private methods
  private getInitialState(): WalkieTalkieServiceState {
    return {
      // Connection
      connectionState: 'disconnected',
      isInitialized: false,
      
      // Audio
      state: 'idle',
      audioState: 'idle',
      
      // Recording
      isRecording: false,
      recordingDuration: 0,
      canRecord: false,
      audioLevel: 0,
      
      // Processing
      isProcessing: false,
      isUploading: false,
      uploadProgress: 0,
      
      // Messages
      messages: [],
      unreadCount: 0,
      
      // Playback
      isPlayingMessage: false,
      currentPlayingMessageId: null,
      currentPlayingSender: null,
      
      // Error handling
      error: null,
      lastError: null,
      
      // Statistics
      totalMessagesSent: 0,
      totalMessagesReceived: 0,
    };
  }

  private notifyStateListeners(): void {
    this.stateListeners.forEach(listener => {
      try {
        listener(this.getState());
      } catch (error) {
        console.error('Error in state listener:', error);
      }
    });
  }

  private getChangedFields(obj1: any, obj2: any): any {
    const changes: any = {};
    for (const key in obj1) {
      if (obj1[key] !== obj2[key]) {
        changes[key] = obj1[key];
      }
    }
    return changes;
  }
}
