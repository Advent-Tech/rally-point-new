/**
 * Walkie-Talkie Service
 * Main service class with clean architecture and proper error handling
 */

import { Audio } from 'expo-av';
import * as FileSystem from 'expo-file-system';
import { 
  IWalkieTalkieService,
  WalkieTalkieConfig,
  WalkieTalkieServiceState,
  WalkieTalkieState,
  RecordingResult,
  VoiceMessage,
  WalkieTalkieEvent,
  RecordingConfig
} from './types';
import { WalkieTalkieStateManager } from './StateManager';
import { errorHandler } from './ErrorHandler';
import { SingleRecordingManager } from './SingleRecordingManager';
import WalkieWSClient, { WalkieEvent } from '../../services/WalkieWSClient';

export class WalkieTalkieService implements IWalkieTalkieService {
  private static instance: WalkieTalkieService;
  private stateManager: WalkieTalkieStateManager;
  private recordingManager: SingleRecordingManager;
  private config: WalkieTalkieConfig | null = null;
  private recordingStartTime: Date | null = null;
  private currentSound: Audio.Sound | null = null;
  private testMode: boolean = false; // Production mode - only hear messages from other team members
  private wsClient: WalkieWSClient | null = null;

  constructor() {
    this.stateManager = new WalkieTalkieStateManager();
    this.recordingManager = SingleRecordingManager.getInstance(this.stateManager);
  }

  /**
   * Real-time listener via WebSocket with Firestore fallback
   */
  private async startRealtime(teamId: string, currentUserId: string): Promise<void> {
    if (this.wsClient) {
      this.wsClient.close();
      this.wsClient = null;
    }
    this.wsClient = new WalkieWSClient();

    let wsConnected = false;

    const onEvent = (evt: WalkieEvent) => {
      try {
        switch ((evt.type || '').toLowerCase()) {
          case 'message': {
            const m = evt.data || {};
            const id = m.id || m.message_id || `${m.team_id}_${m.sent_at || Date.now()}`;
            const isAudio = (m.message_type || '').toLowerCase() === 'audio';
            if (!isAudio || !m.message) return;

            const exists = this.stateManager.getState().messages.find(x => x.id === id);
            if (exists) return;

            const voice = {
              id,
              senderId: m.sender_id,
              senderName: m.sender_name || 'Teammate',
              teamId: m.team_id,
              audioUrl: m.message,
              duration: m.duration || 0,
              timestamp: m.sent_at ? new Date(m.sent_at) : new Date(),
              isOwn: String(m.sender_id) === String(currentUserId),
            } as VoiceMessage;

            this.stateManager.addMessage(voice);

            // Auto-play immediately when received from others
            if (!voice.isOwn) {
              this.autoPlayReceivedMessage(voice).catch(() => {});
            }
            break;
          }
          case 'transmission_start':
          case 'transmission_end':
          case 'team_state':
          default:
            // Could update UI indicators later
            break;
        }
      } catch (_) {}
    };

    await this.wsClient.connect({
      teamId,
      userId: currentUserId,
      onEvent,
      onOpen: () => {
        wsConnected = true;
        console.log('✅ WebSocket connected - using realtime');
        this.stateManager.setConnectionState('connected');
      },
      onClose: () => {
        if (wsConnected) {
          console.log('🔌 WebSocket disconnected');
          // Only set disconnected if we were previously connected
          // Firestore will continue to work
        }
      },
      onError: () => {
        console.log('⚠️ WebSocket error - will use Firestore fallback');
      },
    });

    // Log connection status
    if (!this.wsClient.isConnected()) {
      console.log('⚠️ WebSocket not connected - messages will only be received when WebSocket connects');
    }
  }

  static getInstance(): WalkieTalkieService {
    if (!WalkieTalkieService.instance) {
      WalkieTalkieService.instance = new WalkieTalkieService();
    }
    return WalkieTalkieService.instance;
  }

  /**
   * Force reset the singleton instance (for debugging)
   */
  static resetInstance(): void {
    if (WalkieTalkieService.instance) {
      WalkieTalkieService.instance.destroy();
      WalkieTalkieService.instance = null as any;
    }
  }

  /**
   * Get current state
   */
  getState(): WalkieTalkieServiceState {
    return this.stateManager.getState();
  }

  /**
   * Update test mode (for debugging)
   */
  setTestMode(enabled: boolean): void {
    this.testMode = enabled;
    console.log(`🧪 Test mode ${enabled ? 'ENABLED' : 'DISABLED'} - ${enabled ? 'will hear own messages' : 'will only hear team messages'}`);
  }

  /**
   * Initialize the service
   */
  async initialize(config: WalkieTalkieConfig): Promise<void> {
    try {
      console.log('🎤 ========== WALKIE-TALKIE INITIALIZATION STARTED ==========');
      console.log('🎤 Initializing WalkieTalkieService...', {
        teamId: config.teamId,
        userId: config.userId,
        userName: config.userName,
        testMode: this.testMode
      });
      this.stateManager.setWalkieTalkieState('initializing');
      this.stateManager.setConnectionState('connecting');
      this.config = config;

      // Log test mode setting
      console.log(`🧪 Test mode is ${this.testMode ? 'ENABLED' : 'DISABLED'} - ${this.testMode ? 'will hear own messages' : 'will only hear team messages'}`);

      // Initialize single recording manager
      await this.recordingManager.initialize(
        config.teamId,
        config.userId,
        config.userName
      );

      // Start WebSocket realtime with Firestore fallback
      console.log('🎤 STEP 3: Starting realtime listeners (WebSocket with Firestore fallback)...');
      await this.startRealtime(config.teamId, config.userId);

      // Mark as ready - connection will work via either WebSocket or Firestore
      console.log('🎤 STEP 5: Marking service as ready...');
      this.stateManager.setConnectionState('connected');
      this.stateManager.setWalkieTalkieState('ready');
      this.stateManager.updateState('canRecord', true);

      console.log('✅ ========== WALKIE-TALKIE INITIALIZATION COMPLETED ==========');
      console.log('✅ Status: WebSocket=' + (this.wsClient?.isConnected() ? 'connected' : 'fallback to Firestore'));

    } catch (error) {
      const walkieError = errorHandler.handleError(error);
      this.stateManager.setError(walkieError);
      // Don't set connection to error - allow user to still try recording
      // The error will be shown but they can still use basic functionality
      this.stateManager.setConnectionState('connected');
      this.stateManager.setWalkieTalkieState('ready');
      this.stateManager.updateState('canRecord', true);
      console.error('⚠️ Initialization had errors but service is still usable:', walkieError);
    }
  }

  /**
   * Destroy the service
   */
  async destroy(): Promise<void> {
    try {
      console.log('🧹 🚨 DESTROYING WALKIE-TALKIE SERVICE');

      // Close WebSocket connection
      if (this.wsClient) {
        this.wsClient.close();
        this.wsClient = null;
      }

      // Stop any ongoing playback
      if (this.currentSound) {
        await this.stopPlayback();
      }

      // Destroy recording manager
      await this.recordingManager.destroy();

      // Reset state
      this.stateManager.reset();
      this.config = null;

      console.log('✅ WalkieTalkie Service destroyed');

    } catch (error) {
      console.error('Error destroying service:', error);
    }
  }

  /**
   * Auto-play received voice message
   */
  private async autoPlayReceivedMessage(message: VoiceMessage): Promise<void> {
    try {
      console.log(`🔊 🎵 AUTO-PLAY STARTED for message from ${message.senderName}`, {
        messageId: message.id,
        audioUrl: message.audioUrl,
        duration: message.duration
      });
      
      // Set playback state to show listening feedback
      console.log(`🔊 Setting playback state...`);
      this.stateManager.setPlaybackState(true, message.id, message.senderName);
      
      // Play the audio using the audio URL directly
      console.log(`🔊 Starting audio playback...`);
      await this.playAudioFromUrl(message.audioUrl);
      
      console.log(`🔊 ✅ AUTO-PLAY COMPLETED for message from ${message.senderName}`);
      
    } catch (error) {
      console.error('❌ AUTO-PLAY FAILED:', error);
      // Clear playback state on error
      this.stateManager.setPlaybackState(false);
    }
  }

  /**
   * Download audio file locally then play to isolate network issues
   */
  private async downloadAndPlayAudio(audioUrl: string): Promise<void> {
    try {
      console.log('📥 Downloading audio file locally first...');
      console.log('📥 Remote URL:', audioUrl);
      
      // Import required modules
      const { Audio } = await import('expo-av');
      const FileSystem = await import('expo-file-system');
      
      // Create local file path
      const fileName = `temp_audio_${Date.now()}.mp3`;
      const localUri = `${FileSystem.default.documentDirectory}${fileName}`;
      
      console.log('📥 Local path:', localUri);
      
      // Download file with detailed logging
      console.log('📥 Starting download...');
      const downloadResult = await FileSystem.default.downloadAsync(audioUrl, localUri);
      
      console.log('📥 Download result:', {
        status: downloadResult.status,
        uri: downloadResult.uri,
        headers: downloadResult.headers
      });
      
      if (downloadResult.status !== 200) {
        throw new Error(`Download failed with status: ${downloadResult.status}`);
      }
      
      // Check downloaded file
      const fileInfo = await FileSystem.default.getInfoAsync(localUri);
      console.log('📁 Downloaded file info:', {
        exists: fileInfo.exists,
        size: fileInfo.exists ? (fileInfo as any).size : 0,
        uri: localUri
      });
      
      if (!fileInfo.exists || (fileInfo as any).size === 0) {
        throw new Error('Downloaded file is empty or does not exist');
      }
      
      // Configure audio mode for playback
      console.log('🔊 Configuring audio mode...');
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: false,
        staysActiveInBackground: false,
        playsInSilentModeIOS: true,
        shouldDuckAndroid: true,
        playThroughEarpieceAndroid: false,
      });
      
      // Play local file
      console.log('🔊 Playing local file:', localUri);
      const { sound } = await Audio.Sound.createAsync(
        { uri: localUri },
        { shouldPlay: true }
      );
      
      console.log('✅ Local file playback started successfully!');
      
      // Handle playback completion
      sound.setOnPlaybackStatusUpdate(async (status) => {
        if (status.isLoaded && status.didJustFinish) {
          console.log('✅ Audio playback completed');
          // Clear playback state
          this.stateManager.setPlaybackState(false);
          // Unload sound
          await sound.unloadAsync();
          // Clean up local file
          try {
            await FileSystem.default.deleteAsync(localUri, { idempotent: true });
            console.log('🗑️ Cleaned up local file');
          } catch (cleanupError) {
            console.warn('⚠️ Failed to clean up local file:', cleanupError);
          }
        }
      });
      
    } catch (error) {
      console.error('❌ Download-and-play failed:', error);
      // Clear playback state on error
      this.stateManager.setPlaybackState(false);
      
      // Fallback to direct URL approach
      console.log('🔊 Fallback: Trying direct URL playback...');
      await this.playAudioFromUrl(audioUrl);
    }
  }

  /**
   * Play audio from URL using expo-av (fallback method)
   */
  private async playAudioFromUrl(audioUrl: string): Promise<void> {
    try {
      console.log('🔊 Playing audio from URL:', audioUrl);
      
      // Import Audio from expo-av
      const { Audio } = await import('expo-av');
      
      // Configure audio mode for playback
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: false,
        staysActiveInBackground: false,
        playsInSilentModeIOS: true,
        shouldDuckAndroid: true,
        playThroughEarpieceAndroid: false,
      });

      // Create and load sound
      const { sound } = await Audio.Sound.createAsync(
        { uri: audioUrl },
        { shouldPlay: true }
      );

      // Handle playback completion
      sound.setOnPlaybackStatusUpdate((status) => {
        if (status.isLoaded && status.didJustFinish) {
          console.log('✅ Audio playback completed');
          // Clear playback state
          this.stateManager.setPlaybackState(false);
          // Unload sound
          sound.unloadAsync();
        }
      });

    } catch (error) {
      console.error('❌ Failed to play audio:', error);
      // Clear playback state on error
      this.stateManager.setPlaybackState(false);
      throw error;
    }
  }

  /**
   * Auto-play received voice message (legacy comment)
   */
  private async autoPlayMessage(message: VoiceMessage): Promise<void> {
    try {
      // Prevent multiple concurrent playback attempts
      if (this.currentSound) {
        console.log(`⚠️ Already playing audio, skipping message: ${message.id}`);
        return;
      }

      console.log(`🔊 Auto-playing message from ${message.senderName}`);
      await this.playAudio(message.audioUrl);
    } catch (error) {
      console.error('❌ Failed to auto-play message:', error);
    }
  }

  /**
   * Manually play audio message (public method for UI)
   */
  public async playAudioMessage(audioUrl: string, messageId?: string, senderName?: string): Promise<void> {
    try {
      console.log(`🎵 Manual play requested for: ${audioUrl}`);
      
      // Prevent multiple concurrent playback attempts
      if (this.currentSound) {
        console.log(`⚠️ Already playing audio, stopping current playback first...`);
        await this.stopPlayback();
      }

      // Set playback state - this will disable Hold to Talk button
      this.stateManager.setPlaybackState(true, messageId, senderName);

      await this.playAudio(audioUrl);
    } catch (error) {
      console.error('❌ Failed to manually play message:', error);
      // Clear playback state on error
      this.stateManager.setPlaybackState(false);
      throw error; // Re-throw for UI error handling
    }
  }

  /**
   * Play audio from URL
   */
  private async playAudio(audioUrl: string): Promise<void> {
    try {
      console.log('🔊 Attempting to play audio from URL:', audioUrl);
      
      // Stop any current playback
      if (this.currentSound) {
        await this.stopPlayback();
      }

      // BYPASS EXPO-AV: Use native Android Intent to play audio
      console.log('🎵 Using native Android audio player instead of ExoPlayer...');
      
      try {
        // Download the file first for native playback
        const downloadResult = await FileSystem.downloadAsync(
          audioUrl,
          FileSystem.documentDirectory + 'walkie_audio_' + Date.now() + '.m4a'
        );

        console.log('📥 Audio file downloaded for native playback:', downloadResult.uri);

        // Use Linking to open with native audio player
        const { Linking } = require('react-native');
        await Linking.openURL(downloadResult.uri);
        
        console.log('✅ Native audio player launched successfully');
        
        // Clean up file after a delay
        setTimeout(() => {
          FileSystem.deleteAsync(downloadResult.uri).catch(console.warn);
        }, 10000); // 10 seconds delay

        return;

      } catch (nativeError) {
        console.warn('⚠️ Native playback failed, falling back to expo-av:', (nativeError as any).message);
        
        // Fallback to original expo-av approach
        await this.configurePlaybackMode();

        console.log('🔊 Creating Audio.Sound from URL...');
        
        // Download first, then play with expo-av
        const downloadResult = await FileSystem.downloadAsync(
          audioUrl,
          FileSystem.documentDirectory + 'temp_audio_' + Date.now() + '.m4a'
        );

        console.log('📥 Audio file downloaded for expo-av:', downloadResult.uri);

        // Play the downloaded file locally with expo-av
        const { sound } = await Audio.Sound.createAsync(
          { uri: downloadResult.uri },
          { shouldPlay: true, volume: 1.0 }
        );

        this.currentSound = sound;
        
        // Add playback completion handler
        sound.setOnPlaybackStatusUpdate((playbackStatus) => {
          if (playbackStatus.isLoaded && playbackStatus.didJustFinish) {
            console.log('✅ Expo-av audio playback completed successfully');
            this.handlePlaybackComplete();
            // Clean up downloaded file
            FileSystem.deleteAsync(downloadResult.uri).catch(console.warn);
          }
        });

        console.log('🔊 Expo-av audio playback started successfully');
      }

    } catch (error) {
      console.error('❌ Audio playback failed:', error);
      console.error('❌ Error details:', {
        message: (error as any).message,
        stack: (error as any).stack,
        audioUrl: audioUrl
      });
      throw error;
    }
  }

  /**
   * Handle playback completion
   */
  private handlePlaybackComplete(): void {
    try {
      if (this.currentSound) {
        this.currentSound.unloadAsync();
        this.currentSound = null;
      }
      this.stateManager.setAudioState('idle');
      
      // Clear playback state - this will re-enable Hold to Talk button
      this.stateManager.setPlaybackState(false);
      
      console.log('🔊 Playback completed and cleaned up');
    } catch (error) {
      console.error('Error handling playback completion:', error);
    }
  }

  /**
   * Start recording (single recording only)
   */
  async startRecording(): Promise<string> {
    try {
      if (!this.config) {
        throw new Error('Service not initialized');
      }

      console.log('🎤 Starting single recording...');

      // Start recording using single manager
      const recordingId = await this.recordingManager.startRecording();

      console.log('✅ Recording started:', recordingId);
      return recordingId;

    } catch (error) {
      const walkieError = errorHandler.handleError(error);
      this.stateManager.setError(walkieError);
      throw walkieError;
    }
  }

  /**
   * Stop recording (single recording)
   */
  async stopRecording(): Promise<RecordingResult> {
    try {
      console.log('🛑 Stopping recording...');

      // Stop recording using single manager
      const success = await this.recordingManager.stopRecording();
      
      if (!success) {
        throw new Error('Failed to stop recording');
      }

      // Get recording status for result
      const status = this.recordingManager.getRecordingStatus();

      // Create result
      const recordingResult: RecordingResult = {
        id: status.recordingId || 'unknown',
        uri: '', // Will be processed in background
        duration: 0, // Will be calculated by manager
        size: 0, // Will be calculated by manager
        format: 'mp3',
        timestamp: new Date(),
      };

      console.log('✅ Recording stopped');
      return recordingResult;

    } catch (error) {
      const walkieError = errorHandler.handleError(error);
      this.stateManager.setError(walkieError);
      throw walkieError;
    }
  }

  /**
   * Play message
   */
  async playMessage(messageId: string): Promise<void> {
    try {
      const message = this.stateManager.getState().messages.find(m => m.id === messageId);
      if (!message) {
        throw new Error('Message not found');
      }

      console.log('🔊 Playing message:', messageId);

      // Stop any current playback
      if (this.currentSound) {
        await this.stopPlayback();
      }

      // Configure audio for playback
      await this.configurePlaybackMode();

      // Create and play sound
      const { sound } = await Audio.Sound.createAsync(
        { uri: message.audioUrl },
        { shouldPlay: true, volume: 1.0 }
      );

      this.currentSound = sound;
      this.stateManager.setAudioState('playing');

      // Handle playback completion
      sound.setOnPlaybackStatusUpdate((status) => {
        if (status.isLoaded && status.didJustFinish) {
          this.handlePlaybackComplete();
        }
      });

      // Mark as read
      this.stateManager.markAsRead(messageId);

      console.log('✅ Message playback started');

    } catch (error) {
      const walkieError = errorHandler.handleError(error);
      this.stateManager.setError(walkieError);
      throw walkieError;
    }
  }

  /**
   * Stop playback
   */
  async stopPlayback(): Promise<void> {
    try {
      if (this.currentSound) {
        await this.currentSound.unloadAsync();
        this.currentSound = null;
      }
      this.stateManager.setAudioState('idle');
    } catch (error) {
      console.error('Error stopping playback:', error);
    }
  }

  /**
   * Send message (upload recording)
   */
  async sendMessage(recording: RecordingResult): Promise<VoiceMessage> {
    try {
      if (!this.config) {
        throw new Error('Service not initialized');
      }

      console.log('📤 Sending message...');
      // Upload handled independently by SingleRecordingManager

      // TODO: Implement actual upload to your backend/storage
      // This is a placeholder - replace with your upload logic
      const audioUrl = await this.uploadRecording(recording);

      // Create message
      const message: VoiceMessage = {
        id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        senderId: this.config.userId,
        senderName: this.config.userName,
        teamId: this.config.teamId,
        audioUrl,
        duration: recording.duration,
        timestamp: new Date(),
        isOwn: true,
      };

      // Add to state
      this.stateManager.addMessage(message);
      // Upload completed independently

      console.log('✅ Message sent:', message.id);
      return message;

    } catch (error) {
      // Upload error handled independently
      const walkieError = errorHandler.handleError(error);
      this.stateManager.setError(walkieError);
      throw walkieError;
    }
  }

  /**
   * Get messages
   */
  getMessages(): VoiceMessage[] {
    return this.stateManager.getState().messages;
  }

  /**
   * Mark message as read
   */
  markAsRead(messageId: string): void {
    this.stateManager.markAsRead(messageId);
  }

  /**
   * Clear error
   */
  clearError(): void {
    this.stateManager.clearError();
  }

  /**
   * Retry last failed operation
   */
  async retry(): Promise<void> {
    try {
      const state = this.stateManager.getState();
      if (!state.lastError) {
        return;
      }

      console.log('🔄 Retrying last operation...');
      this.stateManager.clearError();

      // Retry based on error type
      switch (state.lastError.code) {
        case 'INITIALIZATION_FAILED':
          if (this.config) {
            await this.initialize(this.config);
          }
          break;
        
        case 'PERMISSION_DENIED':
          await this.requestPermissions();
          break;
        
        default:
          console.log('No specific retry logic for error:', state.lastError.code);
      }

    } catch (error) {
      const walkieError = errorHandler.handleError(error);
      this.stateManager.setError(walkieError);
    }
  }

  /**
   * Event handling
   */
  on(event: string, callback: (data: any) => void): void {
    this.stateManager.on(event, callback);
  }

  off(event: string, callback: (data: any) => void): void {
    // TODO: Implement event removal
  }

  emit(event: WalkieTalkieEvent): void {
    this.stateManager.emit(event);
  }

  // Private helper methods
  private async requestPermissions(): Promise<void> {
    console.log('🔐 Requesting audio permissions...');
    
    const { status } = await Audio.requestPermissionsAsync();
    if (status !== 'granted') {
      throw errorHandler.createError(
        'PERMISSION_DENIED',
        'Microphone permission is required',
        { status },
        true
      );
    }
    
    console.log('✅ Audio permissions granted');
  }

  private async configureAudioMode(): Promise<void> {
    console.log('🔧 Configuring audio mode...');
    
    await Audio.setAudioModeAsync({
      allowsRecordingIOS: true,
      playsInSilentModeIOS: true,
      staysActiveInBackground: false,
      shouldDuckAndroid: false,
      playThroughEarpieceAndroid: false,
    });
    
    console.log('✅ Audio mode configured');
  }

  private async configurePlaybackMode(): Promise<void> {
    await Audio.setAudioModeAsync({
      allowsRecordingIOS: false,
      playsInSilentModeIOS: true,
      staysActiveInBackground: false,
      shouldDuckAndroid: false,
      playThroughEarpieceAndroid: !this.config?.speakerMode,
    });
  }

  private async testMicrophone(): Promise<void> {
    console.log('🎤 Testing microphone...');
    
    try {
      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );
      
      // Record for 500ms
      await new Promise(resolve => setTimeout(resolve, 500));
      
      const result = await recording.stopAndUnloadAsync();
      const uri = recording.getURI();
      
      if (!uri) {
        throw new Error('Microphone test failed - no recording URI');
      }
      
      console.log('✅ Microphone test passed');
      
    } catch (error) {
      throw errorHandler.createError(
        'MICROPHONE_UNAVAILABLE',
        'Microphone test failed',
        error,
        true
      );
    }
  }

  private getRecordingOptions(config: RecordingConfig): any {
    // Return appropriate recording options based on config
    switch (config.quality) {
      case 'high':
        return Audio.RecordingOptionsPresets.HIGH_QUALITY;
      case 'low':
        return Audio.RecordingOptionsPresets.LOW_QUALITY;
      default:
        return Audio.RecordingOptionsPresets.HIGH_QUALITY;
    }
  }

  private startDurationTracking(): void {
    const updateDuration = () => {
      if (this.recordingStartTime && this.stateManager.getState().isRecording) {
        const duration = Math.round((Date.now() - this.recordingStartTime.getTime()) / 1000);
        this.stateManager.updateRecordingDuration(duration);
        setTimeout(updateDuration, 1000);
      }
    };
    updateDuration();
  }


  private getFileExtension(uri: string): string {
    const parts = uri.split('.');
    return parts.length > 1 ? parts[parts.length - 1] : 'unknown';
  }

  private async uploadRecording(recording: RecordingResult): Promise<string> {
    // TODO: Implement your actual upload logic here
    // This is a placeholder that simulates upload
    
    console.log('📤 Uploading recording to storage...');
    
    // Upload progress handled independently by SingleRecordingManager
    await new Promise(resolve => setTimeout(resolve, 500)); // Simulate processing time
    
    // Return a mock URL - replace with actual upload implementation
    return `https://your-storage.com/recordings/${recording.id}.${recording.format}`;
  }
}
