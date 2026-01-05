// Simple AudioPermissionsService using React Native's built-in permissions
import { Platform, PermissionsAndroid, Alert } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

export interface AudioPermissionResult {
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
      console.log('✅ AudioPermissionsService initialized');
    } catch (error) {
      console.error('❌ Error initializing audio permissions service:', error);
    }
  }

  /**
   * Request microphone permissions - SIMPLIFIED VERSION
   */
  async requestMicrophonePermission(): Promise<AudioPermissionResult> {
    try {
      console.log('🎤 Requesting microphone permission...');
      console.log('Platform:', Platform.OS);

      try {
        // For Android, use React Native's built-in PermissionsAndroid
        if (Platform.OS === 'android') {
          console.log('📱 Android platform detected: Checking microphone permission...');
          
          // Check current permission status first
          const currentStatus = await PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO);
          console.log('📱 Current Android microphone permission status:', currentStatus);
          
          if (currentStatus) {
            console.log('✅ Android microphone permission already granted');
            const result = {
              granted: true,
              canAskAgain: true,
              status: 'granted',
              message: 'Microphone permission already granted'
            };
            
            // Save this state
            await this.savePermissionStatus(result);
            return result;
          }

          // Request permission if not granted
          console.log('📱 Requesting new Android microphone permission...');
          const requestResult = await PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
            {
              title: 'Microphone Permission',
              message: 'Rally Point needs access to your microphone for walkie-talkie communication.',
              buttonNeutral: 'Ask Me Later',
              buttonNegative: 'Cancel',
              buttonPositive: 'OK',
            }
          );
          
          console.log('📱 Android permission request result:', requestResult);
          
          const result = {
            granted: requestResult === PermissionsAndroid.RESULTS.GRANTED,
            canAskAgain: requestResult !== PermissionsAndroid.RESULTS.NEVER_ASK_AGAIN,
            status: requestResult,
            message: requestResult === PermissionsAndroid.RESULTS.GRANTED ? 'Permission granted' : 'Permission denied'
          };

          // Save the result
          await this.savePermissionStatus(result);
          return result;
        }

        // For iOS, we would need expo-av or another solution
        if (Platform.OS === 'ios') {
          console.log('📱 iOS platform detected - would need expo-av for proper implementation');
          // For now, return a placeholder
          return {
            granted: false,
            canAskAgain: true,
            status: 'unavailable',
            message: 'iOS microphone permissions require expo-av module'
          };
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

      } catch (innerError) {
        console.error('❌ Error in permission request:', innerError);
        return {
          granted: false,
          canAskAgain: false,
          status: 'error',
          message: 'Error requesting microphone permission'
        };
      }

    } catch (error) {
      console.error('❌ Error requesting microphone permission:', error);
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

  /**
   * Show settings redirect dialog (simplified version)
   */
  async showSettingsRedirectDialog(): Promise<void> {
    Alert.alert(
      'Microphone Permission Required',
      'Please enable microphone permission in your device settings to use walkie-talkie functionality.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Open Settings', onPress: () => {
          // On Android, we can't directly open app settings, so just show instruction
          Alert.alert(
            'Enable Microphone Permission',
            'Go to Settings > Apps > Rally Point > Permissions > Microphone and enable it.',
            [{ text: 'OK' }]
          );
        }}
      ]
    );
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
      
      // For Android, check with PermissionsAndroid
      if (Platform.OS === 'android') {
        try {
          const currentStatus = await PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO);
          const result = {
            granted: currentStatus,
            canAskAgain: true,
            status: currentStatus ? 'granted' : 'denied',
            message: currentStatus ? 'Permission granted' : 'Permission not granted'
          };
          
          // Update saved state
          await this.savePermissionStatus(result);
          console.log('✅ Android permission status refreshed:', result);
          return result;
        } catch (error) {
          console.error('Error refreshing Android permission status:', error);
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
}
