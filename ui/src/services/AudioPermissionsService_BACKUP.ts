// Simple fix for Android microphone permission detection
import { Platform } from 'react-native';
import { Audio } from 'expo-av';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface AudioPermissionResult {
  granted: boolean;
  canAskAgain: boolean;
  status: string;
  message: string;
}

const STORAGE_KEYS = {
  AUDIO_PERMISSIONS: 'audio_permissions_status',
};

export class AudioPermissionsService {
  private static instance: AudioPermissionsService;
  private isRequestingPermission: boolean = false;

  static getInstance(): AudioPermissionsService {
    if (!AudioPermissionsService.instance) {
      AudioPermissionsService.instance = new AudioPermissionsService();
    }
    return AudioPermissionsService.instance;
  }

  /**
   * Request microphone permissions - FIXED VERSION
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
        // For mobile platforms (Android/iOS), use Expo Audio
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
   * Save permission status to storage
   */
  private async savePermissionStatus(permission: AudioPermissionResult): Promise<void> {
    try {
      const status = {
        granted: permission.granted,
        canAskAgain: permission.canAskAgain,
        status: permission.status,
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
   * Reset permissions for testing
   */
  async resetPermissions(): Promise<void> {
    try {
      await AsyncStorage.removeItem(STORAGE_KEYS.AUDIO_PERMISSIONS);
      console.log('🗑️ Reset audio permissions');
    } catch (error) {
      console.error('Error resetting permissions:', error);
    }
  }
}
