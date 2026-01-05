# 🚀 SUPABASE SETUP FOR WALKIE-TALKIE AUDIO STORAGE

## 📋 STEP-BY-STEP SETUP:

### **1. Create Supabase Account:**
1. Go to [https://supabase.com/](https://supabase.com/)
2. Sign up for free account
3. Create a new project

### **2. Get Your Credentials:**
1. In your Supabase dashboard, go to **Settings** → **API**
2. Copy these values:
   - **Project URL** (e.g., `https://abc123.supabase.co`)
   - **Anon/Public Key** (starts with `eyJ...`)

### **3. Configure Environment Variables:**
1. Copy `.env.supabase.example` to `.env`
2. Fill in your actual values:
```bash
EXPO_PUBLIC_SUPABASE_URL=https://your-project-id.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### **4. Create Storage Bucket:**
1. In Supabase dashboard, go to **Storage**
2. Click **Create Bucket**
3. Name: `walkie-talkie-audio`
4. Make it **Public** (so audio files can be accessed)

### **5. Set Storage Policies:**
1. Go to **Storage** → **Policies**
2. For `walkie-talkie-audio` bucket, add these policies:

**INSERT Policy:**
```sql
CREATE POLICY "Allow authenticated users to upload audio" ON storage.objects
FOR INSERT WITH CHECK (
  auth.role() = 'authenticated' AND 
  bucket_id = 'walkie-talkie-audio'
);
```

**SELECT Policy:**
```sql
CREATE POLICY "Allow public access to audio files" ON storage.objects
FOR SELECT USING (bucket_id = 'walkie-talkie-audio');
```

### **6. Test the Integration:**
1. Update your config:
```typescript
ENABLE_AUDIO_UPLOAD: true,
STORAGE_PROVIDER: 'supabase',
```

2. Test walkie-talkie - should see:
```
📤 Uploading recorded audio...
✅ Audio uploaded to supabase: https://abc123.supabase.co/storage/v1/object/public/walkie-talkie-audio/...
```

## ✅ BENEFITS OF SUPABASE:

- **Free Tier**: 1GB storage + 2GB bandwidth/month
- **Real-time**: Built-in real-time subscriptions
- **PostgreSQL**: Full database included
- **Auth**: Built-in authentication system
- **Fast**: Global CDN for audio files

## 🔧 TROUBLESHOOTING:

**If upload fails:**
1. Check your environment variables
2. Verify bucket exists and is public
3. Check storage policies are set correctly
4. Look for CORS issues in browser console

**Current Status**: Ready to use! Just need to set up your Supabase project and add credentials.
