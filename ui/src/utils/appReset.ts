import AsyncStorage from '@react-native-async-storage/async-storage';

// Storage keys (should match AuthContext)
const AUTH_STORAGE_KEY = '@rally_point_auth_user';
const AUTH_TOKEN_KEY = '@rally_point_auth_token';
const APP_INSTALL_KEY = '@rally_point_app_install_id';
const DEVICE_ID_KEY = '@rally_point_device_id';

/**
 * Completely reset the app to fresh installation state
 * This will clear all stored data and force user to login again
 */
export const resetAppToFreshInstall = async (): Promise<void> => {
  try {
    console.log('Resetting app to fresh installation state...');
    
    // Clear all authentication and app data
    await AsyncStorage.multiRemove([
      AUTH_STORAGE_KEY,
      AUTH_TOKEN_KEY,
      APP_INSTALL_KEY,
      DEVICE_ID_KEY,
    ]);
    
    console.log('App reset to fresh installation state successfully');
    
    // Note: After calling this function, the app should be restarted
    // or navigation should be reset to login screen
    
  } catch (error) {
    console.error('Error resetting app:', error);
    throw new Error('Failed to reset app to fresh installation state');
  }
};

/**
 * Check if this is a fresh installation
 */
export const isFreshInstallation = async (): Promise<boolean> => {
  try {
    const installId = await AsyncStorage.getItem(APP_INSTALL_KEY);
    return !installId;
  } catch (error) {
    console.error('❌ Error checking installation status:', error);
    return true; // Default to fresh install if error
  }
};

/**
 * Get app installation info
 */
export const getAppInstallationInfo = async (): Promise<{
  isFirstInstall: boolean;
  deviceId: string | null;
  installId: string | null;
  installDate: Date | null;
}> => {
  try {
    const deviceId = await AsyncStorage.getItem(DEVICE_ID_KEY);
    const installId = await AsyncStorage.getItem(APP_INSTALL_KEY);
    
    // Extract install date from install ID if available
    let installDate: Date | null = null;
    if (installId) {
      const timestamp = installId.split('_')[1];
      if (timestamp) {
        installDate = new Date(parseInt(timestamp));
      }
    }
    
    return {
      isFirstInstall: !installId,
      deviceId,
      installId,
      installDate,
    };
  } catch (error) {
    console.error('❌ Error getting installation info:', error);
    return {
      isFirstInstall: true,
      deviceId: null,
      installId: null,
      installDate: null,
    };
  }
};

/**
 * Force logout and require fresh login
 * This clears auth data but keeps installation tracking
 */
export const forceLogoutAndRequireLogin = async (): Promise<void> => {
  try {
    console.log('🚪 Forcing logout and requiring fresh login...');
    
    // Clear only authentication data, keep installation tracking
    await AsyncStorage.multiRemove([
      AUTH_STORAGE_KEY,
      AUTH_TOKEN_KEY,
    ]);
    
    console.log('✅ Forced logout successful - login required');
    
  } catch (error) {
    console.error('❌ Error forcing logout:', error);
    throw new Error('Failed to force logout');
  }
};

/**
 * Clear all app data (for debugging/testing purposes)
 */
export const clearAllAppData = async (): Promise<void> => {
  try {
    console.log('Clearing all app data...');
    
    // Get all keys and clear everything related to Rally Point
    const allKeys = await AsyncStorage.getAllKeys();
    const rallyPointKeys = allKeys.filter(key => key.startsWith('@rally_point_'));
    
    if (rallyPointKeys.length > 0) {
      await AsyncStorage.multiRemove(rallyPointKeys);
      console.log(`Cleared ${rallyPointKeys.length} app data keys`);
    } else {
      console.log('No app data found to clear');
    }
    
  } catch (error) {
    console.error('Error clearing all app data:', error);
    throw new Error('Failed to clear all app data');
  }
};

export default {
  resetAppToFreshInstall,
  isFreshInstallation,
  getAppInstallationInfo,
  forceLogoutAndRequireLogin,
  clearAllAppData,
};
