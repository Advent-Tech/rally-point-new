// Supabase Storage Service for Audio Files
import { supabase } from '../config/supabase';
import * as FileSystem from 'expo-file-system';

export class SupabaseStorageService {
  private static instance: SupabaseStorageService;
  private bucketName = 'ministry_storage';

  static getInstance(): SupabaseStorageService {
    if (!SupabaseStorageService.instance) {
      SupabaseStorageService.instance = new SupabaseStorageService();
    }
    return SupabaseStorageService.instance;
  }

  /**
   * Upload audio file to Supabase Storage (optimized for performance)
   */
  async uploadAudioFile(uri: string, sessionId: string, teamId: string): Promise<string> {
    try {
      console.log('📤 Uploading audio file to Supabase Storage...');
      
      // Create file path first
      const fileName = `walkie-talkie/${teamId}/${sessionId}_${Date.now()}.m4a`;
      
      // Read file as binary (more efficient than base64)
      const fileInfo = await FileSystem.getInfoAsync(uri);
      if (!fileInfo.exists) {
        throw new Error('Audio file not found');
      }
      
      // Read file as base64 (required for Supabase)
      const base64 = await FileSystem.readAsStringAsync(uri, {
        encoding: FileSystem.EncodingType.Base64,
      });
      
      // Convert base64 to Uint8Array more efficiently
      const binaryString = atob(base64);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      
      // Upload to Supabase with optimized settings
      const { data, error } = await supabase.storage
        .from(this.bucketName)
        .upload(fileName, bytes, {
          contentType: 'audio/m4a',
          upsert: true,
          duplex: 'half', // Optimize for upload performance
        });

      if (error) {
        console.error('Supabase upload error details:', error);
        
        // Handle RLS policy error specifically
        if (error.message.includes('row-level security policy')) {
          throw new Error(`Storage permission denied. Please check bucket policies in Supabase dashboard:\n1. Go to Storage → Policies\n2. Add INSERT policy for ${this.bucketName}\n3. Policy: bucket_id = '${this.bucketName}'`);
        }
        
        throw new Error(`Supabase upload failed: ${error.message}`);
      }

      // Get public URL
      const { data: urlData } = supabase.storage
        .from(this.bucketName)
        .getPublicUrl(fileName);

      console.log('✅ Audio uploaded to Supabase:', urlData.publicUrl);
      return urlData.publicUrl;
    } catch (error) {
      console.error('❌ Error uploading to Supabase:', error);
      throw error;
    }
  }

  /**
   * Delete audio file from Supabase Storage
   */
  async deleteAudioFile(filePath: string): Promise<void> {
    try {
      const { error } = await supabase.storage
        .from(this.bucketName)
        .remove([filePath]);

      if (error) {
        throw new Error(`Supabase delete failed: ${error.message}`);
      }

      console.log('✅ Audio file deleted from Supabase');
    } catch (error) {
      console.error('❌ Error deleting from Supabase:', error);
      throw error;
    }
  }
}
