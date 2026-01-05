// Simplified Walkie-Talkie Service - No Firebase, Uses AsyncStorage
import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEY = '@rally_point_walkie_sessions';

export interface SimpleWalkieTalkieState {
  isConnected: boolean;
  isTransmitting: boolean;
  isReceiving: boolean;
  isLoading: boolean;
  currentSpeaker: string | null;
  currentSpeakerName: string | null;
  sessionId: string | null;
  error: string | null;
}

export class SimpleWalkieTalkieService {
  private static instance: SimpleWalkieTalkieService;
  private listeners: ((state: SimpleWalkieTalkieState) => void)[] = [];
  private currentSessionId: string | null = null;

  public state: SimpleWalkieTalkieState = {
    isConnected: false,
    isTransmitting: false,
    isReceiving: false,
    isLoading: false,
    currentSpeaker: null,
    currentSpeakerName: null,
    sessionId: null,
    error: null,
  };

  static getInstance(): SimpleWalkieTalkieService {
    if (!SimpleWalkieTalkieService.instance) {
      SimpleWalkieTalkieService.instance = new SimpleWalkieTalkieService();
    }
    return SimpleWalkieTalkieService.instance;
  }

  /**
   * INSTANT initialization - no async operations
   */
  initialize(): boolean {
    console.log('🎤 Simple walkie-talkie initializing...');

    this.state.isConnected = true;
    this.state.error = null;
    this.notifyStateChange();

    console.log('✅ Simple walkie-talkie initialized instantly');
    return true;
  }

  /**
   * INSTANT start transmission - UI updates immediately
   */
  startTransmitting(userId: string, userName: string, teamId: string): boolean {
    console.log('🎤 Starting transmission (instant)...');

    // INSTANT UI update - no waiting
    this.state.isTransmitting = true;
    this.state.currentSpeaker = userId;
    this.state.currentSpeakerName = userName;
    this.state.isLoading = false;
    this.state.error = null;
    this.notifyStateChange();

    // Create session in background (non-blocking)
    this.createSessionInBackground(userId, userName, teamId);

    console.log('✅ Transmission started instantly');
    return true;
  }

  /**
   * INSTANT stop transmission - UI updates immediately
   */
  stopTransmitting(): void {
    console.log('🎤 Stopping transmission (instant)...');

    // INSTANT UI update - no waiting
    this.state.isTransmitting = false;
    this.state.currentSpeaker = null;
    this.state.currentSpeakerName = null;
    this.state.isLoading = false;
    this.notifyStateChange();

    // Update session in background (non-blocking)
    this.updateSessionInBackground();

    console.log('✅ Transmission stopped instantly');
  }

  /**
   * Create session in background using AsyncStorage - doesn't block UI
   */
  private createSessionInBackground(userId: string, userName: string, teamId: string): void {
    // Show brief loading indicator
    this.state.isLoading = true;
    this.notifyStateChange();

    // Create session without blocking UI
    setTimeout(async () => {
      try {
        const sessionId = `session_${Date.now()}`;
        const sessionData = {
          id: sessionId,
          teamId: teamId || 'default',
          speakerId: userId,
          speakerName: userName,
          isActive: true,
          startedAt: new Date().toISOString(),
        };

        // Store in AsyncStorage
        const stored = await AsyncStorage.getItem(STORAGE_KEY);
        const sessions = stored ? JSON.parse(stored) : [];
        sessions.push(sessionData);
        await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));

        this.currentSessionId = sessionId;
        this.state.sessionId = sessionId;

        console.log('✅ Background session created:', sessionId);

      } catch (error) {
        console.warn('⚠️ Background session creation failed:', error);
        // Don't show error to user - it's background operation
      } finally {
        this.state.isLoading = false;
        this.notifyStateChange();
      }
    }, 100); // Small delay to show loading briefly
  }

  /**
   * Update session in background using AsyncStorage - doesn't block UI
   */
  private updateSessionInBackground(): void {
    if (!this.currentSessionId) {
      console.log('ℹ️ No session to update');
      return;
    }

    const sessionIdToUpdate = this.currentSessionId;

    // Update session without blocking UI
    setTimeout(async () => {
      try {
        const stored = await AsyncStorage.getItem(STORAGE_KEY);
        const sessions = stored ? JSON.parse(stored) : [];
        const index = sessions.findIndex((s: any) => s.id === sessionIdToUpdate);

        if (index !== -1) {
          sessions[index].isActive = false;
          sessions[index].endedAt = new Date().toISOString();
          await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));
        }

        console.log('✅ Background session updated');

      } catch (error) {
        console.warn('⚠️ Background session update failed:', error);
        // Don't show error to user - it's background operation
      }

      this.currentSessionId = null;
      this.state.sessionId = null;
    }, 100);
  }

  /**
   * Get current state
   */
  getState(): SimpleWalkieTalkieState {
    return { ...this.state };
  }

  /**
   * Subscribe to state changes
   */
  onStateChange(callback: (state: SimpleWalkieTalkieState) => void): () => void {
    this.listeners.push(callback);

    return () => {
      const index = this.listeners.indexOf(callback);
      if (index > -1) {
        this.listeners.splice(index, 1);
      }
    };
  }

  /**
   * Notify all listeners of state change
   */
  private notifyStateChange(): void {
    const currentState = this.getState();
    this.listeners.forEach(listener => {
      try {
        listener(currentState);
      } catch (error) {
        console.error('Error in state change listener:', error);
      }
    });
  }

  /**
   * Cleanup - instant operation
   */
  cleanup(): void {
    console.log('🎤 Cleaning up simple walkie-talkie...');

    this.state = {
      isConnected: false,
      isTransmitting: false,
      isReceiving: false,
      isLoading: false,
      currentSpeaker: null,
      currentSpeakerName: null,
      sessionId: null,
      error: null,
    };

    this.currentSessionId = null;
    this.listeners = [];

    console.log('✅ Simple walkie-talkie cleaned up');
  }

  /**
   * Set error state
   */
  setError(error: string): void {
    this.state.error = error;
    this.state.isLoading = false;
    this.notifyStateChange();
  }

  /**
   * Clear error state
   */
  clearError(): void {
    this.state.error = null;
    this.notifyStateChange();
  }
}

export default SimpleWalkieTalkieService;
