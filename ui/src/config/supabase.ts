// Supabase Configuration
import { createClient } from '@supabase/supabase-js';

// Supabase configuration - replace with your actual values
const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL || 'YOUR_SUPABASE_URL';
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || 'YOUR_SUPABASE_ANON_KEY';

// Create Supabase client
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    // Disable auto refresh for React Native
    autoRefreshToken: false,
    persistSession: false,
  },
});

export default supabase;
