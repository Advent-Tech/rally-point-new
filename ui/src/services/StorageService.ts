import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Stub storage service - stores files locally or uses base64
export class StorageService {
  static async uploadProfileImage(userId: string, imageUri: string): Promise<string> {
    try {
      console.log('📤 Storing profile image locally for user:', userId);
      const key = `profile_image_${userId}`;
      await AsyncStorage.setItem(key, imageUri);
      return imageUri;
    } catch (error) {
      console.error('❌ Error storing profile image:', error);
      throw new Error(`Failed to store profile image: ${error}`);
    }
  }

  static async deleteProfileImage(userId: string): Promise<void> {
    try {
      const key = `profile_image_${userId}`;
      await AsyncStorage.removeItem(key);
      console.log('✅ Profile image deleted for user:', userId);
    } catch (error) {
      console.error('❌ Error deleting profile image:', error);
      throw error;
    }
  }

  static async getProfileImageUrl(userId: string): Promise<string | null> {
    try {
      const key = `profile_image_${userId}`;
      return await AsyncStorage.getItem(key);
    } catch (error) {
      console.error('❌ Error getting profile image:', error);
      return null;
    }
  }

  static async uploadFile(path: string, fileUri: string): Promise<string> {
    try {
      console.log('📤 Storing file locally:', path);
      await AsyncStorage.setItem(`file_${path}`, fileUri);
      return fileUri;
    } catch (error) {
      console.error('❌ Error storing file:', error);
      throw error;
    }
  }

  static async deleteFile(path: string): Promise<void> {
    try {
      await AsyncStorage.removeItem(`file_${path}`);
      console.log('✅ File deleted:', path);
    } catch (error) {
      console.error('❌ Error deleting file:', error);
      throw error;
    }
  }

  static async getFileUrl(path: string): Promise<string | null> {
    try {
      return await AsyncStorage.getItem(`file_${path}`);
    } catch (error) {
      console.error('❌ Error getting file:', error);
      return null;
    }
  }
}

export default StorageService;
