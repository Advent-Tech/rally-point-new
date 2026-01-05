// Test Supabase Connection
const { createClient } = require('@supabase/supabase-js');

// Load environment variables
require('dotenv').config();

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

console.log('🔧 Testing Supabase connection...');
console.log('URL:', supabaseUrl);
console.log('Key:', supabaseKey ? 'Present' : 'Missing');

if (!supabaseUrl || !supabaseKey || supabaseUrl.includes('your-actual')) {
  console.log('❌ Please update your .env file with actual Supabase credentials');
  console.log('📋 Steps:');
  console.log('1. Go to your Supabase dashboard');
  console.log('2. Go to Settings → API');
  console.log('3. Copy URL and anon key to .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function testConnection() {
  try {
    console.log('🔍 Testing storage access...');
    
    // Test storage bucket access
    const { data, error } = await supabase.storage.listBuckets();
    
    if (error) {
      console.log('❌ Storage access failed:', error.message);
      console.log('💡 This might be normal - trying direct bucket access...');
      
      // Try to access ministry_storage directly
      const { data: files, error: filesError } = await supabase.storage
        .from('ministry_storage')
        .list();
        
      if (filesError) {
        console.log('❌ Direct bucket access failed:', filesError.message);
        console.log('📋 You need to:');
        console.log('1. Create "ministry_storage" bucket in Supabase dashboard');
        console.log('2. Make it public');
        console.log('3. Set proper storage policies');
      } else {
        console.log('✅ ministry_storage bucket accessible!');
        console.log('📁 Files in bucket:', files.length);
        console.log('🎤 Ready to upload audio files');
      }
      return;
    }
    
    console.log('✅ Connected to Supabase successfully!');
    console.log('📦 Available buckets:', data.map(b => b.name));
    
    // Check if ministry_storage bucket exists
    const bucket = data.find(b => b.name === 'ministry_storage');
    if (bucket) {
      console.log('✅ ministry_storage bucket found!');
      console.log('🎤 Ready to upload audio files');
    } else {
      console.log('❌ ministry_storage bucket not found in list');
      console.log('🔍 Trying direct access...');
      
      // Try direct access
      const { data: files, error: filesError } = await supabase.storage
        .from('ministry_storage')
        .list();
        
      if (!filesError) {
        console.log('✅ ministry_storage bucket exists but not listed (permissions issue)');
        console.log('🎤 Ready to upload audio files');
      } else {
        console.log('❌ ministry_storage bucket does not exist');
        console.log('📋 Please create the bucket in Supabase dashboard');
      }
    }
    
  } catch (error) {
    console.log('❌ Test failed:', error.message);
  }
}

testConnection();
