// Walkie-Talkie Configuration
// Controls audio recording behavior and test mode settings

export const WALKIE_TALKIE_CONFIG = {
  // Enable real audio recording (set to false for test mode only)
  ENABLE_AUDIO_RECORDING: true,
  
  // Force full service mode (bypasses test mode detection)
  FORCE_FULL_SERVICE: true,
  
  // Enable WebRTC real-time streaming (usually false for React Native)
  ENABLE_WEBRTC_STREAMING: false,
  
  // Enable audio file upload to storage (disable if no storage available)
  ENABLE_AUDIO_UPLOAD: true,
  
  // Storage provider (supabase)
  STORAGE_PROVIDER: 'supabase',

  // Audio recording settings
  AUDIO_SETTINGS: {
    sampleRate: 22050,
    numberOfChannels: 1,
    bitRate: 64000,
    extension: '.m4a',
  },

  // Storage settings
  STORAGE_PATH: 'audio/walkie-talkie',

  // Supabase configuration
  supabase: {
    url: process.env.EXPO_PUBLIC_SUPABASE_URL || 'https://your-project.supabase.co',
    anonKey: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || 'your-anon-key',
    bucket: 'walkie-talkie-audio',
  },

  // Debug logging
  ENABLE_DEBUG_LOGS: true,
};

export default WALKIE_TALKIE_CONFIG;
