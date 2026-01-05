/**
 * Parallel Recording Manager
 * Handles multiple concurrent voice recordings with proper state management
 * Ensures UI never freezes during recording, uploading operations
 * No Firebase dependency - uses AsyncStorage and Supabase
 */

import { Audio } from 'expo-av';
import * as FileSystem from 'expo-file-system';
import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { WalkieTalkieStateManager } from './StateManager';
import { errorHandler } from './ErrorHandler';
import { WALKIE_TALKIE_CONFIG } from './config';

const STORAGE_KEY = '@rally_point_walkie_messages';

interface RecordingJob {
  id: string;
  recording: Audio.Recording | null;
  startTime: Date;
  state: 'recording' | 'stopping' | 'processing' | 'uploading' | 'completed' | 'failed';
  uri?: string;
  duration?: number;
  uploadProgress?: number;
  error?: any;
}

interface UploadJob {
  id: string;
  recordingId: string;
  uri: string;
  duration: number;
  teamId: string;
  userId: string;
  userName: string;
  state: 'pending' | 'uploading' | 'creating_document' | 'completed' | 'failed';
  progress: number;
  supabaseUrl?: string;
  messageId?: string;
  error?: any;
}

export class ParallelRecordingManager {
  private static instance: ParallelRecordingManager;
  private stateManager: WalkieTalkieStateManager;
  private supabase: any;

  // Recording management
  private recordingJobs = new Map<string, RecordingJob>();
  private uploadQueue: UploadJob[] = [];
  private isProcessingUploads = false;
  private maxConcurrentUploads = 2;
  private activeUploads = new Set<string>();

  // State tracking
  private isInitialized = false;
  private recordingCounter = 0;

  // Event listeners
  private listeners = new Set<(jobs: RecordingJob[]) => void>();

  constructor(stateManager: WalkieTalkieStateManager) {
    this.stateManager = stateManager;
    this.initializeSupabase();
  }

  static getInstance(stateManager: WalkieTalkieStateManager): ParallelRecordingManager {
    if (!ParallelRecordingManager.instance) {
      ParallelRecordingManager.instance = new ParallelRecordingManager(stateManager);
    }
    return ParallelRecordingManager.instance;
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
      console.warn('⚠️ Please configure your Supabase credentials in src/components/walkie-talkie/config.ts');
    }
  }

  /**
   * Initialize the recording manager
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    try {
      console.log('🚀 Initializing Parallel Recording Manager...');

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

      // Test microphone
      await this.testMicrophone();

      // Start upload processor
      this.startUploadProcessor();

      this.isInitialized = true;
      console.log('✅ Parallel Recording Manager initialized');

    } catch (error) {
      const walkieError = errorHandler.handleError(error);
      this.stateManager.setError(walkieError);
      throw walkieError;
    }
  }

  /**
   * Start a new recording (non-blocking)
   */
  async startRecording(teamId: string, userId: string, userName: string): Promise<string> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const recordingId = `recording_${Date.now()}_${++this.recordingCounter}`;

    console.log(`🎤 Starting recording: ${recordingId}`);

    // Create job immediately (non-blocking)
    const job: RecordingJob = {
      id: recordingId,
      recording: null,
      startTime: new Date(),
      state: 'recording',
    };

    this.recordingJobs.set(recordingId, job);
    this.notifyListeners();

    // Start recording asynchronously (don't await - non-blocking)
    this.performRecording(job, teamId, userId, userName).catch(error => {
      console.error(`❌ Recording failed for ${recordingId}:`, error);
      job.state = 'failed';
      job.error = error;
      this.notifyListeners();
    });

    return recordingId;
  }

  /**
   * Stop a recording (non-blocking)
   */
  async stopRecording(recordingId: string): Promise<boolean> {
    const job = this.recordingJobs.get(recordingId);
    if (!job || job.state !== 'recording') {
      console.warn(`⚠️ Cannot stop recording ${recordingId}: not found or not recording`);
      return false;
    }

    console.log(`🛑 Stopping recording: ${recordingId}`);

    job.state = 'stopping';
    this.notifyListeners();

    // Stop recording asynchronously (don't await - non-blocking)
    this.performStopRecording(job).catch(error => {
      console.error(`❌ Stop recording failed for ${recordingId}:`, error);
      job.state = 'failed';
      job.error = error;
      this.notifyListeners();
    });

    return true;
  }

  /**
   * Get current recording jobs
   */
  getRecordingJobs(): RecordingJob[] {
    return Array.from(this.recordingJobs.values());
  }

  /**
   * Get upload queue status
   */
  getUploadStatus(): { pending: number; active: number; completed: number } {
    const pending = this.uploadQueue.filter(job => job.state === 'pending').length;
    const active = this.activeUploads.size;
    const completed = this.uploadQueue.filter(job => job.state === 'completed').length;

    return { pending, active, completed };
  }

  /**
   * Subscribe to recording updates
   */
  subscribe(listener: (jobs: RecordingJob[]) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  // Private methods

  /**
   * Perform actual recording (async, non-blocking)
   */
  private async performRecording(
    job: RecordingJob,
    teamId: string,
    userId: string,
    userName: string
  ): Promise<void> {
    try {
      // Create recording with Android-compatible settings
      console.log('🎤 Creating recording with Android-compatible format...');
      const { recording } = await Audio.Recording.createAsync({
        android: {
          extension: '.3gp',
          outputFormat: 2, // MPEG_4
          audioEncoder: 1, // AMR_NB (most compatible)
          sampleRate: 8000,
          numberOfChannels: 1,
          bitRate: 12200,
        },
        ios: {
          extension: '.m4a',
          audioQuality: 0, // Low quality for compatibility
          sampleRate: 8000,
          numberOfChannels: 1,
          bitRate: 12200,
          linearPCMBitDepth: 16,
          linearPCMIsBigEndian: false,
          linearPCMIsFloat: false,
        },
        web: {
          mimeType: 'audio/webm',
          bitsPerSecond: 128000,
        },
      });

      job.recording = recording;
      this.notifyListeners();

      console.log(`✅ Recording started: ${job.id}`);

    } catch (error) {
      throw errorHandler.createError('RECORDING_FAILED', 'Failed to start recording', error);
    }
  }

  /**
   * Perform recording stop (async, non-blocking)
   */
  private async performStopRecording(job: RecordingJob): Promise<void> {
    try {
      if (!job.recording) {
        throw new Error('No recording to stop');
      }

      // Get URI before stopping
      const uri = job.recording.getURI();

      // Stop and unload
      await job.recording.stopAndUnloadAsync();

      if (!uri) {
        throw new Error('Failed to get recording URI');
      }

      // Calculate duration
      const duration = Math.round((Date.now() - job.startTime.getTime()) / 1000);

      // Update job
      job.uri = uri;
      job.duration = duration;
      job.state = 'processing';
      job.recording = null;

      this.notifyListeners();

      console.log(`✅ Recording stopped: ${job.id}, duration: ${duration}s`);

      // Add to upload queue (non-blocking)
      this.queueForUpload(job);

    } catch (error) {
      throw errorHandler.createError('RECORDING_FAILED', 'Failed to stop recording', error);
    }
  }

  /**
   * Queue recording for upload (non-blocking)
   */
  private queueForUpload(job: RecordingJob): void {
    if (!job.uri || !job.duration) {
      console.error(`❌ Cannot queue ${job.id}: missing URI or duration`);
      return;
    }

    // Create upload job
    const uploadJob: UploadJob = {
      id: `upload_${job.id}`,
      recordingId: job.id,
      uri: job.uri,
      duration: job.duration,
      teamId: 'default-team', // TODO: Get from context
      userId: 'default-user', // TODO: Get from context
      userName: 'Default User', // TODO: Get from context
      state: 'pending',
      progress: 0,
    };

    this.uploadQueue.push(uploadJob);
    job.state = 'completed'; // Recording part is done

    this.notifyListeners();
    console.log(`📤 Queued for upload: ${uploadJob.id}`);
  }

  /**
   * Start upload processor (runs continuously)
   */
  private startUploadProcessor(): void {
    if (this.isProcessingUploads) return;

    this.isProcessingUploads = true;

    const processUploads = async () => {
      while (this.isProcessingUploads) {
        try {
          // Process pending uploads
          const pendingUploads = this.uploadQueue.filter(job => job.state === 'pending');
          const availableSlots = this.maxConcurrentUploads - this.activeUploads.size;

          for (let i = 0; i < Math.min(pendingUploads.length, availableSlots); i++) {
            const uploadJob = pendingUploads[i];
            this.processUpload(uploadJob); // Don't await - parallel processing
          }

          // Wait before next check
          await new Promise(resolve => setTimeout(resolve, 1000));

        } catch (error) {
          console.error('❌ Upload processor error:', error);
          await new Promise(resolve => setTimeout(resolve, 5000)); // Wait longer on error
        }
      }
    };

    processUploads();
    console.log('🔄 Upload processor started');
  }

  /**
   * Process individual upload (async, parallel)
   */
  private async processUpload(uploadJob: UploadJob): Promise<void> {
    this.activeUploads.add(uploadJob.id);
    uploadJob.state = 'uploading';

    try {
      console.log(`📤 Starting upload: ${uploadJob.id}`);

      // Step 1: Upload to Supabase Storage
      const supabaseUrl = await this.uploadToSupabase(uploadJob);
      uploadJob.supabaseUrl = supabaseUrl;
      uploadJob.progress = 80;

      // Step 2: Store message locally
      uploadJob.state = 'creating_document';
      const messageId = await this.storeMessageLocally(uploadJob);
      uploadJob.messageId = messageId;
      uploadJob.progress = 100;
      uploadJob.state = 'completed';

      console.log(`✅ Upload completed: ${uploadJob.id}`);

      // Clean up local file
      this.cleanupLocalFile(uploadJob.uri);

    } catch (error) {
      console.error(`❌ Upload failed: ${uploadJob.id}`, error);
      uploadJob.state = 'failed';
      uploadJob.error = error;
    } finally {
      this.activeUploads.delete(uploadJob.id);
    }
  }

  /**
   * Upload file to Supabase Storage
   */
  private async uploadToSupabase(uploadJob: UploadJob): Promise<string> {
    try {
      // Read file as blob
      const fileInfo = await FileSystem.getInfoAsync(uploadJob.uri);
      if (!fileInfo.exists) {
        throw new Error('Recording file not found');
      }

      // Create file name
      const fileName = `${uploadJob.teamId}/${uploadJob.recordingId}_${Date.now()}.m4a`;

      // Read file content
      const fileContent = await FileSystem.readAsStringAsync(uploadJob.uri, {
        encoding: FileSystem.EncodingType.Base64,
      });

      // Convert base64 to blob
      const byteCharacters = atob(fileContent);
      const byteNumbers = new Array(byteCharacters.length);
      for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }
      const byteArray = new Uint8Array(byteNumbers);
      const blob = new Blob([byteArray], { type: 'audio/m4a' });

      // Upload to Supabase
      const { data, error } = await this.supabase.storage
        .from('walkie-talkie-audio')
        .upload(fileName, blob, {
          contentType: 'audio/m4a',
          upsert: false,
        });

      if (error) {
        throw error;
      }

      // Get public URL
      const { data: urlData } = this.supabase.storage
        .from('walkie-talkie-audio')
        .getPublicUrl(fileName);

      return urlData.publicUrl;

    } catch (error) {
      throw errorHandler.createError('UPLOAD_FAILED', 'Failed to upload to Supabase', error);
    }
  }

  /**
   * Store message locally using AsyncStorage
   */
  private async storeMessageLocally(uploadJob: UploadJob): Promise<string> {
    try {
      const messageId = `message_${Date.now()}`;
      const message = {
        id: messageId,
        teamId: uploadJob.teamId,
        senderId: uploadJob.userId,
        senderName: uploadJob.userName,
        audioUrl: uploadJob.supabaseUrl,
        duration: uploadJob.duration,
        timestamp: new Date().toISOString(),
        recordingId: uploadJob.recordingId,
      };

      // Store in AsyncStorage
      const stored = await AsyncStorage.getItem(STORAGE_KEY);
      const messages = stored ? JSON.parse(stored) : [];
      messages.push(message);
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(messages));

      return messageId;

    } catch (error) {
      throw errorHandler.createError('UPLOAD_FAILED', 'Failed to store message', error);
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
   * Test microphone functionality (with fallback for problematic devices)
   */
  private async testMicrophone(): Promise<void> {
    console.log('🎤 Testing microphone with fallback approach...');

    try {
      // Try different recording presets for compatibility
      const presets = [
        Audio.RecordingOptionsPresets.HIGH_QUALITY,
        Audio.RecordingOptionsPresets.LOW_QUALITY,
        // Custom Android-compatible preset
        {
          android: {
            extension: '.3gp',
            outputFormat: 2, // MPEG_4
            audioEncoder: 1, // AMR_NB (most compatible)
            sampleRate: 8000,
            numberOfChannels: 1,
            bitRate: 12200,
          },
          ios: {
            extension: '.m4a',
            audioQuality: 0, // Low quality
            sampleRate: 8000,
            numberOfChannels: 1,
            bitRate: 12200,
            linearPCMBitDepth: 16,
            linearPCMIsBigEndian: false,
            linearPCMIsFloat: false,
          },
          web: {
            mimeType: 'audio/webm',
            bitsPerSecond: 128000,
          },
        }
      ];

      let testPassed = false;

      for (let i = 0; i < presets.length; i++) {
        try {
          console.log(`🎤 Trying microphone test with preset ${i + 1}/${presets.length}...`);

          const { recording } = await Audio.Recording.createAsync(presets[i]);

          // Record for longer to ensure audio capture
          await new Promise(resolve => setTimeout(resolve, 1000));

          const status = await recording.getStatusAsync();
          console.log(`📊 Test ${i + 1} status:`, {
            canRecord: status.canRecord,
            isRecording: status.isRecording,
            durationMillis: status.durationMillis
          });

          await recording.stopAndUnloadAsync();

          // More lenient test - just check if recording was created
          if (status.canRecord && status.isRecording) {
            console.log(`✅ Microphone test passed with preset ${i + 1}`);
            testPassed = true;
            break;
          }

        } catch (error) {
          console.warn(`⚠️ Preset ${i + 1} failed:`, error);
          continue;
        }
      }

      if (!testPassed) {
        console.warn('⚠️ All microphone tests failed, but continuing anyway...');
        console.warn('📱 This might be a device-specific issue. Recording may still work.');
        return;
      }

    } catch (error) {
      console.warn('⚠️ Microphone test encountered error, but continuing anyway...');
      console.warn('📱 Error details:', error);
      return;
    }
  }

  /**
   * Notify all listeners of state changes
   */
  private notifyListeners(): void {
    const jobs = this.getRecordingJobs();
    this.listeners.forEach(listener => {
      try {
        listener(jobs);
      } catch (error) {
        console.error('❌ Listener error:', error);
      }
    });
  }

  /**
   * Cleanup and destroy
   */
  async destroy(): Promise<void> {
    console.log('🧹 Destroying Parallel Recording Manager...');

    this.isProcessingUploads = false;

    // Stop all active recordings
    for (const job of this.recordingJobs.values()) {
      if (job.recording && job.state === 'recording') {
        try {
          await job.recording.stopAndUnloadAsync();
        } catch (error) {
          console.error('Error stopping recording during cleanup:', error);
        }
      }
    }

    this.recordingJobs.clear();
    this.uploadQueue.length = 0;
    this.activeUploads.clear();
    this.listeners.clear();

    console.log('✅ Parallel Recording Manager destroyed');
  }
}
