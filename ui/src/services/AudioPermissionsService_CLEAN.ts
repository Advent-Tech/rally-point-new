// Clean AudioPermissionsService with proper Android permission handling
import { Platform, Alert } from 'react-native';
import { Audio } from 'expo-av';
import AsyncStorage from '@react-native-async-storage/async-storage';

export interface AudioPermissionResult {
  granted: boolean;
  canAskAgain: boolean;
  status: string;
  message: string;
}

interface AudioDeviceSettings {
  echoCancellation: boolean;
  noiseSuppression: boolean;
  autoGainControl: boolean;
  volume: number;
  muted: boolean;
}

interface AudioQualitySettings {
  sampleRate: number;
  bitRate: number;
  channels: number;
  format: string;
}

const STORAGE_KEYS = {
  AUDIO_PERMISSIONS: 'audio_permissions_status',
  AUDIO_SETTINGS: 'audio_device_settings',
  AUDIO_QUALITY: 'audio_quality_settings',
};

export class AudioPermissionsService {
  private static instance: AudioPermissionsService;
  private isRequestingPermission: boolean = false;
  private currentSettings: AudioDeviceSettings = {
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    volume: 1.0,
    muted: false,
  };

  private qualitySettings: AudioQualitySettings = {
    sampleRate: 44100,
    bitRate: 128000,
    channels: 1,
    format: 'mp4',
  };

  static getInstance(): AudioPermissionsService {
    if (!AudioPermissionsService.instance) {
      AudioPermissionsService.instance = new AudioPermissionsService();
    }
    return AudioPermissionsService.instance;
  }

  /**
   * Initialize the service
   */
  async initialize(): Promise<void> {
    try {
      await this.loadSavedSettings();
      console.log('✅ AudioPermissionsService initialized');
    } catch (error) {
      console.error('❌ Error initializing audio permissions service:', error);
    }
  }

  /**
   * Request microphone permissions - FIXED FOR ANDROID
   */
  async requestMicrophonePermission(): Promise<AudioPermissionResult> {
    try {
      console.log('🎤 Requesting microphone permission...');
      console.log('Platform:', Platform.OS);
      
      // Prevent multiple simultaneous requests
      if (this.isRequestingPermission) {
        console.log('⏳ Permission request already in progress');
        return {
          granted: false,
          canAskAgain: true,
          status: 'pending',
          message: 'Permission request already in progress'
        };
      }

      this.isRequestingPermission = true;

      try {
        // For mobile platforms (Android/iOS), use Expo Audio - PRIORITY CHECK
        if (Platform.OS !== 'web') {
          console.log('📱 Mobile platform detected: Checking actual permission status...');
          
          if (!Audio) {
            console.error('❌ Audio module not available');
            return {
              granted: false,
              canAskAgain: false,
              status: 'unavailable',
              message: 'Audio module not available on this platform'
            };
          }

          // Check current permission status first (same pattern as location)
          const currentStatus = await Audio.getPermissionsAsync();
          console.log('📱 Current mobile audio permission status:', currentStatus.status);
          
          if (currentStatus.granted) {
            console.log('✅ Mobile audio permission already granted');
            const result = {
              granted: true,
              canAskAgain: currentStatus.canAskAgain,
              status: currentStatus.status,
              message: 'Microphone permission already granted'
            };
            
            // Save this state
            await this.savePermissionStatus(result);
            return result;
          }

          // Request permission if not granted
          console.log('📱 Requesting new mobile audio permission...');
          const requestResult = await Audio.requestPermissionsAsync();
          
          const result = {
            granted: requestResult.granted,
            canAskAgain: requestResult.canAskAgain,
            status: requestResult.status,
            message: requestResult.granted ? 'Permission granted' : 'Permission denied'
          };

          // Save the result
          await this.savePermissionStatus(result);
          return result;
        }

        // For web platform, use browser APIs
        if (Platform.OS === 'web') {
          console.log('🌐 Web platform detected');
          
          if (typeof navigator !== 'undefined' && navigator.mediaDevices) {
            try {
              const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
              stream.getTracks().forEach(track => track.stop());
              
              const result = {
                granted: true,
                canAskAgain: true,
                status: 'granted',
                message: 'Web microphone permission granted'
              };
              
              await this.savePermissionStatus(result);
              return result;
            } catch (error) {
              return {
                granted: false,
                canAskAgain: true,
                status: 'denied',
                message: 'Web microphone permission denied'
              };
            }
          }
        }

        // Fallback
        return {
          granted: false,
          canAskAgain: false,
          status: 'unavailable',
          message: 'Platform not supported'
        };

      } finally {
        this.isRequestingPermission = false;
      }

    } catch (error) {
      console.error('❌ Error requesting microphone permission:', error);
      this.isRequestingPermission = false;
      return {
        granted: false,
        canAskAgain: false,
        status: 'error',
        message: 'Error requesting microphone permission'
      };
    }
  }

  /**
   * Configure audio mode for walkie-talkie
   */
  async configureAudioMode(): Promise<void> {
    try {
      if (Platform.OS === 'web') {
        console.log('ℹ️ Web platform detected, skipping audio mode configuration');
        return;
      }

      if (!Audio) {
        console.warn('⚠️ expo-av Audio module not available');
        return;
      }

      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
        shouldDuckAndroid: true,
        playThroughEarpieceAndroid: false,
        staysActiveInBackground: true,
      });

      console.log('✅ Audio mode configured for walkie-talkie');
    } catch (error) {
      console.error('❌ Error configuring audio mode:', error);
      throw error;
    }
  }

  /**
   * Save permission status to storage
   */
  private async savePermissionStatus(permission: AudioPermissionResult): Promise<void> {
    try {
      const status = {
        granted: permission.granted,
        canAskAgain: permission.canAskAgain,
        status: permission.status,
        expires: 'never',
        timestamp: Date.now()
      };
      console.log('💾 Saving permission status:', status);
      await AsyncStorage.setItem(STORAGE_KEYS.AUDIO_PERMISSIONS, JSON.stringify(status));
      console.log('✅ Permission status saved successfully');
    } catch (error) {
      console.error('❌ Error saving permission status:', error);
    }
  }

  /**
   * Load saved permission status
   */
  private async loadSavedPermissionStatus(): Promise<AudioPermissionResult | null> {
    try {
      console.log('📖 Loading saved permission status from key:', STORAGE_KEYS.AUDIO_PERMISSIONS);
      const savedStatus = await AsyncStorage.getItem(STORAGE_KEYS.AUDIO_PERMISSIONS);
      console.log('📖 Raw saved status:', savedStatus);
      if (savedStatus) {
        const parsed = JSON.parse(savedStatus);
        console.log('📖 Parsed saved status:', parsed);
        return parsed;
      }
      console.log('📖 No saved status found');
    } catch (error) {
      console.error('❌ Error loading saved permission status:', error);
    }
    return null;
  }

  /**
   * Load saved settings from storage
   */
  private async loadSavedSettings(): Promise<void> {
    try {
      // Load audio settings
      const audioSettings = await AsyncStorage.getItem(STORAGE_KEYS.AUDIO_SETTINGS);
      if (audioSettings) {
        this.currentSettings = { ...this.currentSettings, ...JSON.parse(audioSettings) };
      }

      // Load quality settings
      const qualitySettings = await AsyncStorage.getItem(STORAGE_KEYS.AUDIO_QUALITY);
      if (qualitySettings) {
        this.qualitySettings = { ...this.qualitySettings, ...JSON.parse(qualitySettings) };
      }

      console.log('✅ Audio settings loaded from storage');
    } catch (error) {
      console.error('❌ Error loading saved settings:', error);
    }
  }

  /**
   * Reset saved permission status (for testing)
   */
  async resetPermissions(): Promise<void> {
    try {
      await AsyncStorage.removeItem(STORAGE_KEYS.AUDIO_PERMISSIONS);
      console.log('🗑️ Reset audio permissions');
    } catch (error) {
      console.error('Error resetting permissions:', error);
    }
  }

  /**
   * Get current permission status without requesting
   */
  async getCurrentPermissionStatus(): Promise<AudioPermissionResult | null> {
    return await this.loadSavedPermissionStatus();
  }

  /**
   * Refresh permission status by checking actual system state
   */
  async refreshPermissionStatus(): Promise<AudioPermissionResult | null> {
    try {
      console.log('🔄 Refreshing permission status...');
      
      // For mobile platforms, check with expo-av
      if (Platform.OS !== 'web' && Audio) {
        try {
          const currentStatus = await Audio.getPermissionsAsync();
          const result = {
            granted: currentStatus.granted,
            canAskAgain: currentStatus.canAskAgain,
            status: currentStatus.status,
            message: currentStatus.granted ? 'Permission granted' : 'Permission not granted'
          };
          
          // Update saved state
          await this.savePermissionStatus(result);
          console.log('✅ Mobile permission status refreshed:', result);
          return result;
        } catch (error) {
          console.error('Error refreshing mobile permission status:', error);
        }
      }
      
      // For web platform, check browser permission state
      if (Platform.OS === 'web' && typeof navigator !== 'undefined' && navigator.permissions) {
        try {
          const permissionStatus = await navigator.permissions.query({ name: 'microphone' as PermissionName });
          console.log('🌐 Current browser permission state:', permissionStatus.state);
          
          if (permissionStatus.state === 'granted') {
            const browserGrantedResult = {
              granted: true,
              canAskAgain: true,
              status: 'granted',
              message: 'Microphone permission granted by browser'
            };
            // Update saved state
            await this.savePermissionStatus(browserGrantedResult);
            console.log('✅ Permission status refreshed - granted');
            return browserGrantedResult;
          }
        } catch (permissionError) {
          console.log('⚠️ Could not refresh browser permission state:', permissionError);
        }
      }
      
      // Fallback to saved status
      return await this.loadSavedPermissionStatus();
    } catch (error) {
      console.error('Error refreshing permission status:', error);
      return null;
    }
  }

  /**
   * Get audio settings
   */
  getAudioSettings(): AudioDeviceSettings {
    return { ...this.currentSettings };
  }

  /**
   * Get quality settings
   */
  getQualitySettings(): AudioQualitySettings {
    return { ...this.qualitySettings };
  }
}
