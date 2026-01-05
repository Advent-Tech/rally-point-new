// Fixed WalkieTalkieService - No Firebase, Uses AsyncStorage and Backend API
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { WALKIE_TALKIE_CONFIG } from '../config/walkieTalkieConfig';
import { SupabaseStorageService } from './SupabaseStorageService';
import { Audio } from 'expo-av';
import { authService } from './authService';

const STORAGE_KEYS = {
  SESSIONS: '@rally_point_walkie_sessions',
  TEAM_MEMBERS: '@rally_point_walkie_team_members',
};

export interface WalkieTalkieState {
  isConnected: boolean;
  isTransmitting: boolean;
  isReceiving: boolean;
  currentSpeaker: string | null;
  currentSpeakerName: string | null;
  sessionId: string | null;
  teamMembers: any[]; // Array of team members for UI compatibility
}

export interface WalkieTalkieSession {
  id: string;
  teamId: string;
  teamName: string;
  speakerId: string;
  speakerName: string;
  isActive: boolean;
  startedAt: Date;
  participants: string[];
  audioUrl?: string;
  duration?: number;
}

export class WalkieTalkieService {
  private static instance: WalkieTalkieService;
  private listeners: ((state: WalkieTalkieState) => void)[] = [];
  private currentSession: WalkieTalkieSession | null = null;
  private audioRecording: any = null;
  private recordingStartTime: number | null = null;
  private testMode: boolean = true; // Enable test mode to hear your own voice messages
  private pollingInterval: NodeJS.Timeout | null = null;

  public state: WalkieTalkieState = {
    isConnected: false,
    isTransmitting: false,
    isReceiving: false,
    currentSpeaker: null,
    currentSpeakerName: null,
    sessionId: null,
    teamMembers: [],
  };

  private getApiBase(): string {
    if (__DEV__) {
      return Platform.OS === 'android' ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
    }
    return 'https://api.rallypoint.app';
  }

  static getInstance(): WalkieTalkieService {
    if (!WalkieTalkieService.instance) {
      WalkieTalkieService.instance = new WalkieTalkieService();
    }
    return WalkieTalkieService.instance;
  }

  /**
   * Initialize the walkie-talkie service
   */
  async initialize(teamId: string, userId: string): Promise<boolean> {
    try {
      console.log('🎤 Initializing walkie-talkie service...');

      this.state.isConnected = true;

      // Load team members
      await this.loadTeamMembers(teamId, userId);

      // Start polling for active sessions
      this.startPollingForSessions(teamId);

      this.notifyStateChange();

      console.log('✅ Walkie-talkie initialized successfully');
      return true;
    } catch (error) {
      console.error('❌ Error initializing walkie-talkie:', error);
      return false;
    }
  }

  /**
   * Load team members from backend API
   */
  private async loadTeamMembers(teamId: string, currentUserId: string): Promise<void> {
    try {
      console.log('👥 Loading team members for team:', teamId);

      const token = await authService.getValidToken();
      const apiBase = this.getApiBase();

      let teamMembers: any[] = [];

      if (token) {
        try {
          const response = await fetch(`${apiBase}/api/teams/${teamId}/members`, {
            headers: { Authorization: `Bearer ${token}` },
          });

          if (response.ok) {
            const data = await response.json();
            teamMembers = (data.members || data || []).map((user: any) => ({
              userId: user.uid || user.id || user.userId,
              name: user.name || user.displayName || 'Unknown User',
              email: user.email,
              isOnline: user.isOnline || true,
              isCurrent: (user.uid || user.id || user.userId) === currentUserId,
            }));
          }
        } catch (e) {
          console.warn('⚠️ Failed to fetch team members from API:', e);
        }
      }

      // Fallback to local storage
      if (teamMembers.length === 0) {
        const stored = await AsyncStorage.getItem(STORAGE_KEYS.TEAM_MEMBERS);
        if (stored) {
          teamMembers = JSON.parse(stored);
        }
      }

      // If still no team members, add current user
      if (teamMembers.length === 0) {
        console.log('⚠️ No team members found, adding current user as fallback');
        teamMembers.push({
          userId: currentUserId,
          name: 'You',
          isOnline: true,
          isCurrent: true,
        });
      }

      this.state.teamMembers = teamMembers;
      await AsyncStorage.setItem(STORAGE_KEYS.TEAM_MEMBERS, JSON.stringify(teamMembers));

      console.log(`✅ Loaded ${teamMembers.length} team members`);
    } catch (error) {
      console.error('❌ Error loading team members:', error);
      this.state.teamMembers = [{
        userId: currentUserId,
        name: 'You',
        isOnline: true,
        isCurrent: true,
      }];
    }
  }

  /**
   * Start polling for active walkie-talkie sessions
   */
  private startPollingForSessions(teamId: string): void {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }

    const pollSessions = async () => {
      try {
        const stored = await AsyncStorage.getItem(STORAGE_KEYS.SESSIONS);
        const sessions: WalkieTalkieSession[] = stored ? JSON.parse(stored) : [];

        // Find active sessions for this team
        const activeSessions = sessions.filter(s =>
          s.teamId === teamId && s.isActive
        );

        // Check if someone else is speaking
        const otherSpeaker = activeSessions.find(s =>
          s.speakerId !== this.state.currentSpeaker && s.isActive
        );

        if (otherSpeaker) {
          this.state.isReceiving = true;
          this.state.currentSpeaker = otherSpeaker.speakerId;
          this.state.currentSpeakerName = otherSpeaker.speakerName;
          this.notifyStateChange();
        } else if (this.state.isReceiving && !this.state.isTransmitting) {
          this.state.isReceiving = false;
          this.state.currentSpeaker = null;
          this.state.currentSpeakerName = null;
          this.notifyStateChange();
        }
      } catch (error) {
        console.warn('⚠️ Error polling sessions:', error);
      }
    };

    pollSessions();
    this.pollingInterval = setInterval(pollSessions, 2000);
  }

  /**
   * Start transmitting audio
   */
  async startTransmitting(userId: string, userName: string, teamId: string, teamName: string): Promise<boolean> {
    try {
      console.log('🎤 Starting audio transmission...');

      // Check if another user is already transmitting
      if (this.state.currentSpeaker && this.state.currentSpeaker !== userId) {
        console.warn('Someone else is already transmitting');
        return false;
      }

      // Update state IMMEDIATELY for instant UI feedback
      this.state.isTransmitting = true;
      this.state.currentSpeaker = userId;
      this.state.currentSpeakerName = userName;
      this.state.isConnected = true;
      this.notifyStateChange();
      console.log('✅ UI state updated immediately');

      // Create session
      const sessionId = `session_${Date.now()}`;
      const sessionData: WalkieTalkieSession = {
        id: sessionId,
        teamId: teamId || 'unknown',
        teamName: teamName || 'Unknown Team',
        speakerId: userId,
        speakerName: userName,
        isActive: true,
        startedAt: new Date(),
        participants: [userId],
      };

      // Store session locally
      const stored = await AsyncStorage.getItem(STORAGE_KEYS.SESSIONS);
      const sessions: WalkieTalkieSession[] = stored ? JSON.parse(stored) : [];
      sessions.push(sessionData);
      await AsyncStorage.setItem(STORAGE_KEYS.SESSIONS, JSON.stringify(sessions));

      this.currentSession = sessionData;
      this.state.sessionId = sessionId;

      // Start audio recording (non-blocking)
      this.startAudioRecordingAsync();

      console.log('✅ Audio transmission started successfully');
      return true;
    } catch (error) {
      console.error('❌ Error starting audio transmission:', error);
      return false;
    }
  }

  /**
   * Stop transmitting audio
   */
  async stopTransmitting(): Promise<void> {
    try {
      console.log('🎤 Stopping audio transmission...');

      // Update state IMMEDIATELY for instant UI feedback
      this.state.isTransmitting = false;
      this.state.currentSpeaker = null;
      this.state.currentSpeakerName = null;
      this.state.isConnected = true;
      if (this.state.teamMembers.length === 0) {
        this.state.teamMembers = [{ userId: 'current', name: 'You' }];
      }
      this.notifyStateChange();
      console.log('✅ UI state updated immediately');

      // Store session info before clearing
      const sessionId = this.state.sessionId;
      const teamId = this.currentSession?.teamId || 'unknown';

      // Clear session immediately
      this.currentSession = null;
      this.state.sessionId = null;

      // Handle cleanup in background (non-blocking)
      setTimeout(async () => {
        try {
          let audioUrl: string | undefined;
          let duration: number | undefined;

          // Stop audio recording and get file info
          const recordingResult = await this.stopAudioRecording();
          if (recordingResult) {
            console.log('🎤 Audio recording stopped, starting upload...');

            // Upload audio file to Supabase storage
            try {
              const supabaseStorage = SupabaseStorageService.getInstance();
              audioUrl = await supabaseStorage.uploadAudioFile(
                recordingResult.uri,
                sessionId || 'unknown',
                teamId
              );
              duration = recordingResult.duration;
              console.log('✅ Audio uploaded successfully:', audioUrl);
            } catch (uploadError) {
              console.warn('⚠️ Audio upload failed:', uploadError);
            }
          }

          // Update session in local storage
          if (sessionId) {
            const stored = await AsyncStorage.getItem(STORAGE_KEYS.SESSIONS);
            const sessions: WalkieTalkieSession[] = stored ? JSON.parse(stored) : [];
            const index = sessions.findIndex(s => s.id === sessionId);

            if (index !== -1) {
              sessions[index].isActive = false;
              if (audioUrl) {
                sessions[index].audioUrl = audioUrl;
                sessions[index].duration = duration;
              }
              await AsyncStorage.setItem(STORAGE_KEYS.SESSIONS, JSON.stringify(sessions));

              // Play back audio if in test mode
              if (this.testMode && audioUrl) {
                console.log('🧪 TEST MODE: Playing back your own voice message...');
                setTimeout(() => this.playAudioMessage(audioUrl!), 500);
              }
            }
          }
        } catch (error) {
          console.warn('⚠️ Background cleanup error:', error);
        }
      }, 100);

      console.log('✅ Audio transmission stopped successfully');
    } catch (error) {
      console.error('❌ Error stopping audio transmission:', error);
    }
  }

  /**
   * Start audio recording asynchronously (non-blocking)
   */
  private startAudioRecordingAsync(): void {
    this.startAudioRecording().catch(error => {
      console.warn('⚠️ Audio recording failed to start:', error);
    });
  }

  /**
   * Start audio recording
   */
  private async startAudioRecording(): Promise<void> {
    try {
      if (!Audio) {
        console.warn('🎤 Audio not available, skipping recording');
        return;
      }

      console.log('🎤 Starting audio recording...');

      // Configure audio mode for recording
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
        shouldDuckAndroid: true,
        playThroughEarpieceAndroid: false,
        staysActiveInBackground: true,
      });

      // Create new recording instance
      this.audioRecording = new Audio.Recording();

      // Prepare recording with optimized settings for walkie-talkie
      await this.audioRecording.prepareToRecordAsync({
        android: {
          extension: '.m4a',
          outputFormat: Audio.AndroidOutputFormat.MPEG_4,
          audioEncoder: Audio.AndroidAudioEncoder.AAC,
          sampleRate: 22050,
          numberOfChannels: 1,
          bitRate: 64000,
        },
        ios: {
          extension: '.m4a',
          outputFormat: Audio.IOSOutputFormat.MPEG4AAC,
          audioQuality: Audio.IOSAudioQuality.MEDIUM,
          sampleRate: 22050,
          numberOfChannels: 1,
          bitRate: 64000,
          linearPCMBitDepth: 16,
          linearPCMIsBigEndian: false,
          linearPCMIsFloat: false,
        },
        web: {
          mimeType: 'audio/webm;codecs=opus',
          bitsPerSecond: 64000,
        },
      });

      // Start recording
      await this.audioRecording.startAsync();
      this.recordingStartTime = Date.now();

      console.log('✅ Audio recording started successfully');
    } catch (error) {
      console.error('❌ Error starting audio recording:', error);
      throw error;
    }
  }

  /**
   * Stop audio recording and return file info
   */
  private async stopAudioRecording(): Promise<{ uri: string; duration: number } | null> {
    try {
      if (!this.audioRecording) {
        console.warn('🎤 No active recording to stop');
        return null;
      }

      console.log('🎤 Stopping audio recording...');

      // Stop and get recording info
      await this.audioRecording.stopAndUnloadAsync();
      const uri = this.audioRecording.getURI();

      // Calculate duration
      const duration = this.recordingStartTime
        ? Math.round((Date.now() - this.recordingStartTime) / 1000)
        : 0;

      // Clean up
      this.audioRecording = null;
      this.recordingStartTime = null;

      if (!uri) {
        console.warn('🎤 No recording URI available');
        return null;
      }

      console.log(`✅ Audio recording stopped - Duration: ${duration}s, URI: ${uri}`);
      return { uri, duration };

    } catch (error) {
      console.error('❌ Error stopping audio recording:', error);
      this.audioRecording = null;
      this.recordingStartTime = null;
      return null;
    }
  }

  /**
   * Play received audio message
   */
  async playAudioMessage(audioUrl: string): Promise<void> {
    try {
      if (!Audio) {
        console.warn('🎤 Audio not available, cannot play message');
        return;
      }

      console.log('🔊 Playing audio message:', audioUrl);

      // Configure audio mode for playback
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: false,
        playsInSilentModeIOS: true,
        shouldDuckAndroid: true,
        playThroughEarpieceAndroid: false,
      });

      // Create and play sound
      const { sound } = await Audio.Sound.createAsync(
        { uri: audioUrl },
        { shouldPlay: true, volume: 1.0 }
      );

      // Wait for playback to complete
      sound.setOnPlaybackStatusUpdate((status: any) => {
        if (status.isLoaded && status.didJustFinish) {
          sound.unloadAsync();
          console.log('✅ Audio playback completed');
        }
      });

    } catch (error) {
      console.error('❌ Error playing audio message:', error);
    }
  }

  /**
   * Toggle test mode to hear your own voice messages
   */
  setTestMode(enabled: boolean): void {
    this.testMode = enabled;
    console.log(`🧪 Test mode ${enabled ? 'ENABLED' : 'DISABLED'}`);
  }

  /**
   * Get current state
   */
  getState(): WalkieTalkieState {
    return { ...this.state };
  }

  /**
   * Subscribe to state changes
   */
  onStateChange(callback: (state: WalkieTalkieState) => void): () => void {
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
   * Cleanup resources
   */
  async cleanup(): Promise<void> {
    try {
      console.log('🎤 Cleaning up walkie-talkie service...');

      // Stop polling
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval);
        this.pollingInterval = null;
      }

      // Stop any active recording
      if (this.audioRecording) {
        await this.audioRecording.stopAndUnloadAsync();
        this.audioRecording = null;
      }

      // Reset state
      this.state = {
        isConnected: false,
        isTransmitting: false,
        isReceiving: false,
        currentSpeaker: null,
        currentSpeakerName: null,
        sessionId: null,
        teamMembers: [],
      };

      // Clear session
      this.currentSession = null;

      // Clear listeners
      this.listeners = [];

      console.log('✅ Walkie-talkie service cleaned up');
    } catch (error) {
      console.error('❌ Error during cleanup:', error);
    }
  }
}

export default WalkieTalkieService;
