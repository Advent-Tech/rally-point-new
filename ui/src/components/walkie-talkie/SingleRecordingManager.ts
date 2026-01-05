/**
 * Single Recording Manager
 * Handles one recording at a time with proper state management
 * Fixes "Only one Recording object can be prepared at a given time" error
 */

import { Audio } from 'expo-av';
import * as FileSystem from 'expo-file-system';
import { createClient } from '@supabase/supabase-js';
// Backend service for sending messages (broadcasts to team via WebSocket)
import WalkieBackendService from '../../services/WalkieBackendService';
import { WalkieTalkieStateManager } from './StateManager';
import { errorHandler } from './ErrorHandler';
import { WALKIE_TALKIE_CONFIG } from './config';

interface RecordingState {
  id: string | null;
  recording: Audio.Recording | null;
  startTime: Date | null;
  isRecording: boolean;
  isProcessing: boolean;
  isUploading: boolean;
}

interface UploadJob {
  id: string;
  uri: string;
  duration: number;
  teamId: string;
  userId: string;
  userName: string;
}

export class SingleRecordingManager {
  private static instance: SingleRecordingManager;
  private stateManager: WalkieTalkieStateManager;
  private supabase: any;
  
  // Single recording state
  private recordingState: RecordingState = {
    id: null,
    recording: null,
    startTime: null,
    isRecording: false,
    isProcessing: false,
    isUploading: false,
  };
  
  // Upload queue for background processing
  private uploadQueue: UploadJob[] = [];
  private isProcessingUploads = false;
  
  // Current context
  private currentTeamId = '';
  private currentUserId = '';
  private currentUserName = '';

  constructor(stateManager: WalkieTalkieStateManager) {
    this.stateManager = stateManager;
    this.initializeSupabase();
  }

  static getInstance(stateManager: WalkieTalkieStateManager): SingleRecordingManager {
    if (!SingleRecordingManager.instance) {
      SingleRecordingManager.instance = new SingleRecordingManager(stateManager);
    }
    return SingleRecordingManager.instance;
  }

  /**
   * Initialize Supabase client
   */
  private initializeSupabase(): void {
    try {
      this.supabase = createClient(
        WALKIE_TALKIE_CONFIG.supabase.url,
        WALKIE_TALKIE_CONFIG.supabase.anonKey
      );
      console.log('✅ Supabase client initialized');
    } catch (error) {
      console.error('❌ Failed to initialize Supabase:', error);
    }
  }

  /**
   * Initialize the recording manager
   */
  async initialize(teamId: string, userId: string, userName: string): Promise<void> {
    try {
      console.log('🚀 Initializing Single Recording Manager...');

      // Store context
      this.currentTeamId = teamId;
      this.currentUserId = userId;
      this.currentUserName = userName;

      // Request audio permissions
      const { status } = await Audio.requestPermissionsAsync();
      if (status !== 'granted') {
        throw new Error('Audio permissions not granted');
      }

      // Configure audio mode for recording
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
        staysActiveInBackground: false,
        shouldDuckAndroid: false,
        playThroughEarpieceAndroid: false,
      });

      // Start upload processor
      this.startUploadProcessor();

      console.log('✅ Single Recording Manager initialized');

    } catch (error) {
      const walkieError = errorHandler.handleError(error);
      this.stateManager.setError(walkieError);
      throw walkieError;
    }
  }

  /**
   * Start recording (single recording only)
   */
  async startRecording(): Promise<string> {
    // Check if already recording
    if (this.recordingState.isRecording) {
      console.warn('⚠️ Already recording, ignoring new request');
      return this.recordingState.id || '';
    }

    // Check if processing
    if (this.recordingState.isProcessing) {
      console.warn('⚠️ Currently processing, cannot start new recording');
      throw new Error('Currently processing previous recording');
    }

    try {
      const recordingId = `recording_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      console.log(`🎤 Starting single recording: ${recordingId}`);

      // Try different recording formats for better Android compatibility
      let recording;
      const recordingOptions = [
        // Option 1: Try MP3 format (maximum ExoPlayer compatibility)
        {
          android: {
            extension: '.mp3',
            outputFormat: Audio.AndroidOutputFormat.MPEG_4,
            audioEncoder: Audio.AndroidAudioEncoder.AAC,
            sampleRate: 44100,
            numberOfChannels: 1,
            bitRate: 128000,
          },
          ios: {
            extension: '.mp3',
            outputFormat: Audio.IOSOutputFormat.MPEG4AAC,
            audioQuality: Audio.IOSAudioQuality.HIGH,
            sampleRate: 44100,
            numberOfChannels: 1,
            bitRate: 128000,
          },
          web: {
            mimeType: 'audio/webm;codecs=opus',
            bitsPerSecond: 12200,
          },
        },
        // Option 2: Try MPEG_4 format (more compatible)
        {
          android: {
            extension: '.m4a',
            outputFormat: Audio.AndroidOutputFormat.MPEG_4,
            audioEncoder: Audio.AndroidAudioEncoder.AAC,
            sampleRate: 8000,
            numberOfChannels: 1,
            bitRate: 12200,
          },
          ios: {
            extension: '.m4a',
            outputFormat: Audio.IOSOutputFormat.MPEG4AAC,
            audioQuality: Audio.IOSAudioQuality.LOW,
            sampleRate: 8000,
            numberOfChannels: 1,
            bitRate: 12200,
          },
          web: {
            mimeType: 'audio/webm;codecs=opus',
            bitsPerSecond: 12200,
          },
        }
      ];

      let lastError;
      for (let i = 0; i < recordingOptions.length; i++) {
        try {
          console.log(`🎤 Trying recording option ${i + 1}/${recordingOptions.length}...`);
          const result = await Audio.Recording.createAsync(recordingOptions[i]);
          recording = result.recording;
          console.log(`✅ Recording created successfully with option ${i + 1}`);
          break;
        } catch (error) {
          console.warn(`⚠️ Recording option ${i + 1} failed:`, error);
          lastError = error;
          continue;
        }
      }

      if (!recording) {
        console.error('❌ ALL RECORDING OPTIONS FAILED - This Android device cannot record audio with expo-av');
        console.error('❌ Possible causes:');
        console.error('   1. Hardware microphone issues');
        console.error('   2. Android audio system incompatibility');
        console.error('   3. expo-av library incompatibility with this device');
        console.error('   4. Missing system-level audio permissions');
        console.error('❌ RECOMMENDATION: Use a different device or implement alternative recording library');
        throw new Error('CRITICAL: Audio recording completely failed on this Android device. All recording formats failed.');
      }

      // Update state
      this.recordingState = {
        id: recordingId,
        recording,
        startTime: new Date(),
        isRecording: true,
        isProcessing: false,
        isUploading: false,
      };

      // Update service state
      this.stateManager.startRecording(recordingId);

      // Start real-time audio level monitoring
      this.startAudioLevelMonitoring(recording);

      console.log(`✅ Recording started: ${recordingId}`);
      return recordingId;

    } catch (error) {
      console.error('❌ Failed to start recording:', error);
      this.recordingState.isRecording = false;
      throw errorHandler.createError('RECORDING_FAILED', 'Failed to start recording', error);
    }
  }

  /**
   * Stop recording (immediately reset recording state, upload in background)
   */
  async stopRecording(): Promise<boolean> {
    if (!this.recordingState.isRecording || !this.recordingState.recording) {
      console.warn('⚠️ No active recording to stop');
      return false;
    }

    try {
      const { id, recording, startTime } = this.recordingState;
      
      console.log(`🛑 Stopping recording: ${id}`);

      // Stop and unload recording first, then get the URI.
      // On some platforms (especially web), getURI() may return null
      // until after stopAndUnloadAsync has completed.
      await recording.stopAndUnloadAsync();

      const uri = recording.getURI();
      
      if (!uri || !startTime) {
        throw new Error('Failed to get recording URI or start time');
      }

      // Validate the recorded file
      try {
        const fileInfo = await FileSystem.getInfoAsync(uri);
        console.log(`📊 Recording file info:`, {
          exists: fileInfo.exists,
          size: fileInfo.exists ? (fileInfo as any).size : 0,
          uri: uri
        });

        if (!fileInfo.exists) {
          throw new Error('Recording file does not exist');
        }

        const fileSize = (fileInfo as any).size || 0;
        if (fileSize === 0) {
          throw new Error('Recording file is empty - no audio data captured');
        }

        if (fileSize < 1000) { // Less than 1KB is likely invalid
          console.warn(`⚠️ Recording file is very small (${fileSize} bytes) - may contain no valid audio`);
        }

        // Test if the audio file can be loaded AND has valid duration
        try {
          console.log('🧪 Testing local audio file validity...');
          const { sound, status } = await Audio.Sound.createAsync({ uri });
          
          if (status.isLoaded) {
            const durationMs = status.durationMillis || 0;
            const durationSec = Math.round(durationMs / 1000);
            console.log(`📊 Audio file duration: ${durationSec}s (${durationMs}ms)`);
            
            if (durationMs === 0 || durationMs === null || durationMs === undefined) {
              await sound.unloadAsync();
              throw new Error('Audio file has 0 duration - file is corrupted or contains no audio data');
            }
            
            if (durationMs < 500) { // Less than 0.5 seconds is suspicious
              console.warn(`⚠️ Very short audio duration: ${durationMs}ms - may be corrupted`);
            }
            
            // Production: Skip immediate playback testing
            console.log('✅ Audio file ready for upload and sharing');
            
            await sound.unloadAsync();
            console.log('✅ Local audio file validation completed');
          } else {
            await sound.unloadAsync();
            throw new Error('Audio file could not be loaded - invalid format');
          }
        } catch (audioTestError) {
          console.error('❌ Local audio file validation failed:', audioTestError);
          throw new Error(`Audio file is corrupted: ${(audioTestError as any).message}`);
        }

      } catch (fileError) {
        console.error('❌ Recording file validation failed:', fileError);
        throw new Error(`Invalid recording file: ${(fileError as any).message}`);
      }

      // Calculate duration in milliseconds for accurate short press detection
      const durationMs = Date.now() - startTime.getTime();
      const duration = Math.round(durationMs / 1000);

      // IMMEDIATELY reset recording state (don't wait for upload)
      this.recordingState = {
        id: null,
        recording: null,
        startTime: null,
        isRecording: false,
        isProcessing: false,
        isUploading: false, // Upload state is separate
      };

      // Stop audio level monitoring
      this.stopAudioLevelMonitoring();

      // Update service state to show recording stopped
      this.stateManager.stopRecording(id!, duration);

      // Check minimum duration - skip upload if too short (less than 1 second)
      const MIN_RECORDING_DURATION_MS = 1000;
      if (durationMs < MIN_RECORDING_DURATION_MS) {
        console.log(`⚠️ Recording too short (${durationMs}ms < ${MIN_RECORDING_DURATION_MS}ms) - discarding`);
        // Clean up the local file since we won't upload it
        await this.cleanupLocalFile(uri);
        return true; // Still return true since we successfully stopped recording
      }

      // Queue for upload (completely non-blocking, independent of recording)
      this.queueForUpload({
        id: id!,
        uri,
        duration,
        teamId: this.currentTeamId,
        userId: this.currentUserId,
        userName: this.currentUserName,
      });

      console.log(`✅ Recording stopped immediately: ${id}, duration: ${duration}s`);
      console.log(`📤 Upload queued in background for: ${id}`);
      
      return true;

    } catch (error) {
      console.error('❌ Failed to stop recording:', error);
      
      // Always reset state on error
      this.recordingState = {
        id: null,
        recording: null,
        startTime: null,
        isRecording: false,
        isProcessing: false,
        isUploading: false,
      };
      
      throw errorHandler.createError('RECORDING_FAILED', 'Failed to stop recording', error);
    }
  }

  /**
   * Get current recording status
   */
  getRecordingStatus() {
    return {
      isRecording: this.recordingState.isRecording,
      isProcessing: this.recordingState.isProcessing,
      isUploading: this.recordingState.isUploading,
      recordingId: this.recordingState.id,
      uploadQueueLength: this.uploadQueue.length,
    };
  }

  /**
   * Queue recording for upload (non-blocking)
   */
  private queueForUpload(uploadJob: UploadJob): void {
    this.uploadQueue.push(uploadJob);
    console.log(`📤 Queued for upload: ${uploadJob.id}`);
  }

  /**
   * Start upload processor (runs continuously in background)
   */
  private startUploadProcessor(): void {
    if (this.isProcessingUploads) return;

    this.isProcessingUploads = true;

    const processUploads = async () => {
      while (this.isProcessingUploads) {
        try {
          if (this.uploadQueue.length > 0) {
            const uploadJob = this.uploadQueue.shift()!;
            await this.processUpload(uploadJob);
          } else {
            // Wait before checking again
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
        } catch (error) {
          console.error('❌ Upload processor error:', error);
          await new Promise(resolve => setTimeout(resolve, 5000));
        }
      }
    };

    processUploads();
    console.log('🔄 Upload processor started');
  }

  /**
   * Process individual upload (background, independent of recording state)
   */
  private async processUpload(uploadJob: UploadJob): Promise<void> {
    try {
      console.log(`📤 Background upload started: ${uploadJob.id}`);

      let audioUrl = '';

      // Try to upload to Supabase, fallback to local storage if it fails
      try {
        audioUrl = await this.uploadToSupabase(uploadJob);
        console.log(`✅ Supabase upload successful: ${audioUrl}`);
      } catch (supabaseError) {
        console.warn(`⚠️ Supabase upload failed, using local fallback:`, supabaseError);
        
        // Fallback: Use local file URI (for development/testing)
        audioUrl = uploadJob.uri;
        console.log(`📱 Using local file URI: ${audioUrl}`);
      }

      // Step 2: Send to backend for team broadcast via WebSocket
      await this.sendMessageToBackend(uploadJob, audioUrl);

      // Step 3: Clean up local file only if successfully uploaded to Supabase
      if (audioUrl !== uploadJob.uri) {
        await this.cleanupLocalFile(uploadJob.uri);
      } else {
        console.log(`📱 Keeping local file for playback: ${uploadJob.uri}`);
      }

      console.log(`✅ Background upload completed: ${uploadJob.id}`);

    } catch (error) {
      console.error(`❌ Background upload failed: ${uploadJob.id}`, error);
      // Even if Supabase upload fails, try to send with local URI as fallback
      try {
        await this.sendMessageToBackend(uploadJob, uploadJob.uri);
        console.log(`📱 Sent message to backend with local URI as fallback`);
      } catch (backendError) {
        console.error(`❌ Backend fallback also failed:`, backendError);
      }
    }
    // Note: No longer updating recordingState.isUploading since upload is independent
  }

  /**
   * Upload file to Supabase Storage (React Native compatible)
   * Uses FileSystem.uploadAsync for reliable uploads in React Native
   */
  private async uploadToSupabase(uploadJob: UploadJob): Promise<string> {
    try {
      // Check if file exists
      const fileInfo = await FileSystem.getInfoAsync(uploadJob.uri);
      if (!fileInfo.exists) {
        throw new Error('Recording file not found');
      }

      // Detect file extension from URI
      const fileExtension = this.getFileExtension(uploadJob.uri);

      // Create file name with walkie-talkie folder organization
      const fileName = `walkie-talkie/${uploadJob.teamId}/${uploadJob.id}_${Date.now()}.${fileExtension}`;

      // Determine content type based on file extension
      let contentType = 'audio/mpeg'; // Default for MP3
      if (fileExtension === 'wav') {
        contentType = 'audio/wav';
      } else if (fileExtension === '3gp') {
        contentType = 'audio/3gpp';
      } else if (fileExtension === 'm4a') {
        contentType = 'audio/mp4';
      } else if (fileExtension === 'amr') {
        contentType = 'audio/amr';
      } else if (fileExtension === 'mp3') {
        contentType = 'audio/mpeg';
      }

      console.log(`📤 Uploading ${fileName} to Supabase...`);
      console.log(`📤 File extension: ${fileExtension}, Content type: ${contentType}`);
      console.log(`📤 File size: ${(fileInfo as any).size || 'unknown'} bytes`);

      // Method 1: Use FileSystem.uploadAsync (most reliable for React Native)
      try {
        const uploadUrl = `${WALKIE_TALKIE_CONFIG.supabase.url}/storage/v1/object/${WALKIE_TALKIE_CONFIG.supabase.bucket}/${fileName}`;

        console.log('📤 Using FileSystem.uploadAsync...');

        const uploadResult = await FileSystem.uploadAsync(uploadUrl, uploadJob.uri, {
          httpMethod: 'POST',
          uploadType: FileSystem.FileSystemUploadType.BINARY_CONTENT,
          headers: {
            'Authorization': `Bearer ${WALKIE_TALKIE_CONFIG.supabase.anonKey}`,
            'Content-Type': contentType,
            'x-upsert': 'false',
          },
        });

        console.log('📤 Upload response status:', uploadResult.status);

        if (uploadResult.status >= 200 && uploadResult.status < 300) {
          // Get public URL
          const { data: urlData } = this.supabase.storage
            .from(WALKIE_TALKIE_CONFIG.supabase.bucket)
            .getPublicUrl(fileName);

          console.log(`✅ FileSystem.uploadAsync successful: ${urlData.publicUrl}`);
          return urlData.publicUrl;
        } else {
          console.warn(`⚠️ FileSystem.uploadAsync failed with status ${uploadResult.status}: ${uploadResult.body}`);
          throw new Error(`Upload failed with status ${uploadResult.status}`);
        }

      } catch (uploadAsyncError) {
        console.log('📤 FileSystem.uploadAsync failed, trying base64 approach...', uploadAsyncError);

        // Method 2: Read file as base64 and upload via Supabase client
        const fileData = await FileSystem.readAsStringAsync(uploadJob.uri, {
          encoding: FileSystem.EncodingType.Base64,
        });

        // Decode base64 to Uint8Array
        const binaryString = atob(fileData);
        const bytes = new Uint8Array(binaryString.length);
        for (let i = 0; i < binaryString.length; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }

        console.log(`📤 File data prepared: ${bytes.length} bytes`);

        const { error } = await this.supabase.storage
          .from(WALKIE_TALKIE_CONFIG.supabase.bucket)
          .upload(fileName, bytes.buffer, {
            contentType: contentType,
            upsert: false,
          });

        if (error) {
          throw error;
        }

        // Get public URL
        const { data: urlData } = this.supabase.storage
          .from(WALKIE_TALKIE_CONFIG.supabase.bucket)
          .getPublicUrl(fileName);

        console.log(`✅ Base64 upload successful: ${urlData.publicUrl}`);
        return urlData.publicUrl;
      }

    } catch (error) {
      console.error('❌ Supabase upload error:', error);
      throw errorHandler.createError('UPLOAD_FAILED', 'Failed to upload to Supabase', error);
    }
  }

  /**
   * Send message to backend for team broadcast via WebSocket
   * Backend will broadcast to all team members connected via WebSocket
   */
  private async sendMessageToBackend(uploadJob: UploadJob, audioUrl: string): Promise<string> {
    try {
      console.log('📤 🔍 SENDING MESSAGE TO BACKEND FOR TEAM BROADCAST:', {
        teamId: uploadJob.teamId,
        senderId: uploadJob.userId,
        senderName: uploadJob.userName,
        audioUrl,
        duration: uploadJob.duration,
      });

      // Send to backend - backend will broadcast to team via WebSocket
      const resp = await WalkieBackendService.sendMessage(uploadJob.teamId, audioUrl, 'audio');
      const messageId = resp?.id || resp?.message?.id || `msg_${uploadJob.id}`;

      console.log('📤 ✅ MESSAGE SENT TO BACKEND:', { id: messageId });
      return messageId;
    } catch (error) {
      console.error('❌ Failed to send message to backend:', error);
      throw errorHandler.createError('UPLOAD_FAILED', 'Failed to send message to team', error);
    }
  }

  /**
   * Clean up local file
   */
  private async cleanupLocalFile(uri: string): Promise<void> {
    try {
      await FileSystem.deleteAsync(uri, { idempotent: true });
      console.log(`🧹 Cleaned up local file: ${uri}`);
    } catch (error) {
      console.warn('⚠️ Failed to cleanup local file:', error);
    }
  }

  /**
   * Cleanup and destroy
   */
  async destroy(): Promise<void> {
    console.log('🧹 Destroying Single Recording Manager...');
    
    this.isProcessingUploads = false;
    
    // Stop any active recording
    if (this.recordingState.recording && this.recordingState.isRecording) {
      try {
        await this.recordingState.recording.stopAndUnloadAsync();
      } catch (error) {
        console.error('Error stopping recording during cleanup:', error);
      }
    }
    
    // Reset state
    this.recordingState = {
      id: null,
      recording: null,
      startTime: null,
      isRecording: false,
      isProcessing: false,
      isUploading: false,
    };
    
    this.uploadQueue.length = 0;
    
    console.log('✅ Single Recording Manager destroyed');
  }

  /**
   * Get file extension from URI
   */
  private getFileExtension(uri: string): string {
    const parts = uri.split('.');
    return parts.length > 1 ? parts[parts.length - 1] : 'wav'; // Default to wav
  }

  /**
   * Start real-time audio level monitoring during recording
   */
  private startAudioLevelMonitoring(recording: Audio.Recording): void {
    try {
      console.log('🎤 Starting real-time audio level monitoring...');
      
      // Set up status update listener to capture audio levels
      recording.setOnRecordingStatusUpdate((status) => {
        console.log('🎤 Recording status update:', {
          isRecording: status.isRecording,
          metering: status.metering,
          durationMillis: status.durationMillis
        });
        
        if (status.isRecording) {
          if (status.metering !== undefined && status.metering !== null) {
            // Convert metering level to 0-1 range for visualization
            // Metering is typically in dB, ranging from -160 (silence) to 0 (max)
            const dbLevel = status.metering;
            const normalizedLevel = Math.max(0, Math.min(1, (dbLevel + 160) / 160));
            
            console.log(`🎤 Real audio detected - dB: ${dbLevel}, normalized: ${normalizedLevel.toFixed(2)}`);
            
            // Update state manager with current audio level
            this.stateManager.updateAudioLevel(normalizedLevel);
          } else {
            console.log('🎤 No metering data available (Android emulator limitation)');
            // Set audio level to 0 when no real metering is available
            this.stateManager.updateAudioLevel(0);
          }
        }
      });
      
      console.log('✅ Audio level monitoring started');
      
    } catch (error) {
      console.warn('⚠️ Failed to start audio level monitoring:', error);
      // Continue without monitoring - not critical for recording
    }
  }

  /**
   * Stop audio level monitoring
   */
  private stopAudioLevelMonitoring(): void {
    try {
      // Reset audio level to 0
      this.stateManager.updateAudioLevel(0);
      console.log('🎤 Audio level monitoring stopped');
    } catch (error) {
      console.warn('⚠️ Error stopping audio level monitoring:', error);
    }
  }
}
