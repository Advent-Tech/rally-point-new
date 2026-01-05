// Comprehensive Firestore Connection Test
const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, serverTimestamp, connectFirestoreEmulator } = require('firebase/firestore');
const { getAuth, signInAnonymously } = require('firebase/auth');

// Firebase config (same as your app)
const firebaseConfig = {
  apiKey: "AIzaSyD8UKq7_DoAKTS-L8D90oWXPaJepgDWGTs",
  authDomain: "rally-point-mobile.firebaseapp.com",
  databaseURL: "https://rally-point-mobile-default-rtdb.firebaseio.com/",
  projectId: "rally-point-mobile",
  storageBucket: "rally-point-mobile.firebasestorage.app",
  messagingSenderId: "503617293297",
  appId: "1:503617293297:web:78fd9cd53925b6c5a4d250"
};

async function testFirestoreConnection() {
  try {
    console.log('🔥 Testing Firestore Connection...');
    
    // Initialize Firebase
    const app = initializeApp(firebaseConfig);
    const db = getFirestore(app);
    const auth = getAuth(app);
    
    console.log('✅ Firebase initialized');
    
    // Check if using emulator
    try {
      // This will fail if not using emulator, which is fine
      connectFirestoreEmulator(db, 'localhost', 8080);
      console.log('🔧 Connected to Firestore emulator');
    } catch (emulatorError) {
      console.log('🌐 Using production Firestore');
    }
    
    // Test authentication
    console.log('🔐 Testing authentication...');
    const userCredential = await signInAnonymously(auth);
    console.log('✅ Authenticated as:', userCredential.user.uid);
    
    // Test basic Firestore write with timeout
    console.log('📝 Testing Firestore write...');
    
    const testData = {
      test: true,
      timestamp: serverTimestamp(),
      message: 'Connection test',
      userId: userCredential.user.uid
    };
    
    // Add timeout protection
    const writePromise = addDoc(collection(db, 'connection_test'), testData);
    const timeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Write timeout after 10 seconds')), 10000)
    );
    
    const result = await Promise.race([writePromise, timeoutPromise]);
    console.log('✅ Firestore write successful:', result.id);
    
    // Test walkie-talkie specific write
    console.log('🎤 Testing walkie-talkie session write...');
    
    const sessionData = {
      teamId: 'test-team',
      teamName: 'Test Team',
      speakerId: userCredential.user.uid,
      speakerName: 'Test User',
      isActive: true,
      startedAt: serverTimestamp(),
      participants: [userCredential.user.uid],
    };
    
    const sessionPromise = addDoc(collection(db, 'walkie_talkie_sessions'), sessionData);
    const sessionTimeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Session write timeout after 10 seconds')), 10000)
    );
    
    const sessionResult = await Promise.race([sessionPromise, sessionTimeoutPromise]);
    console.log('✅ Walkie-talkie session write successful:', sessionResult.id);
    
    console.log('🎉 All Firestore tests passed!');
    
  } catch (error) {
    console.error('❌ Firestore connection test failed:', error);
    
    // Detailed error analysis
    if (error.code) {
      console.error('Error code:', error.code);
    }
    if (error.message) {
      console.error('Error message:', error.message);
    }
    
    // Common issues and solutions
    console.log('\n🔧 Possible solutions:');
    
    if (error.message.includes('timeout')) {
      console.log('- Network connectivity issue');
      console.log('- Try different network connection');
      console.log('- Check firewall settings');
    }
    
    if (error.code === 'permission-denied') {
      console.log('- Firestore security rules blocking writes');
      console.log('- Check authentication state');
      console.log('- Verify user permissions');
    }
    
    if (error.code === 'unavailable') {
      console.log('- Firestore service unavailable');
      console.log('- Check Firebase project status');
      console.log('- Try again later');
    }
    
    if (error.message.includes('Failed to get document')) {
      console.log('- Firestore offline mode issue');
      console.log('- Check internet connection');
    }
  }
}

testFirestoreConnection();
