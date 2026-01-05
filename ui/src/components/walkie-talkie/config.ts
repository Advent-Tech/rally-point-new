/**
 * Walkie-Talkie Configuration
 * 
 * SETUP INSTRUCTIONS:
 * 1. Uses existing 'ministry_storage' Supabase bucket
 * 2. Audio files will be stored in ministry_storage/walkie-talkie/ folder
 * 3. Make sure your Supabase URL and anon key are configured in environment variables
 * 
 * NOTE: If Supabase is not configured, the system will fallback to local storage
 */

export const WALKIE_TALKIE_CONFIG = {
  supabase: {
    url: process.env.EXPO_PUBLIC_SUPABASE_URL || 'https://your-project.supabase.co',
    anonKey: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || 'your-anon-key',
    bucket: 'ministry_storage', // Using existing ministry_storage bucket
  },
  
  // Recording settings
  recording: {
    maxDuration: 60, // seconds
    quality: 'high' as const,
    format: 'm4a' as const,
    sampleRate: 44100,
    bitRate: 128000,
  },
  
  // Upload settings
  upload: {
    timeout: 30000, // 30 seconds
    retryAttempts: 3,
    maxConcurrentUploads: 2,
  },
  
  // UI settings
  ui: {
    vibrationEnabled: true,
    soundEnabled: true,
    autoPlay: true,
    speakerMode: true,
  },
} as const;
