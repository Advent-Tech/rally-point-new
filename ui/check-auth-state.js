// Check Current Authentication State
const { initializeApp } = require('firebase/app');
const { getAuth, onAuthStateChanged } = require('firebase/auth');

const firebaseConfig = {
  apiKey: "AIzaSyD8UKq7_DoAKTS-L8D90oWXPaJepgDWGTs",
  authDomain: "rally-point-mobile.firebaseapp.com",
  projectId: "rally-point-mobile",
  storageBucket: "rally-point-mobile.firebasestorage.app",
  messagingSenderId: "503617293297",
  appId: "1:503617293297:web:78fd9cd53925b6c5a4d250"
};

async function checkAuthState() {
  console.log('🔐 Checking Firebase Authentication State...');
  
  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  
  return new Promise((resolve) => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (user) {
        console.log('✅ User is authenticated:');
        console.log('  - UID:', user.uid);
        console.log('  - Email:', user.email || 'No email');
        console.log('  - Anonymous:', user.isAnonymous);
        console.log('  - Provider:', user.providerData.length > 0 ? user.providerData[0].providerId : 'anonymous');
        
        // Check if token is valid
        user.getIdToken().then(token => {
          console.log('✅ Auth token is valid');
          console.log('  - Token length:', token.length);
        }).catch(tokenError => {
          console.error('❌ Auth token error:', tokenError);
        });
        
      } else {
        console.log('❌ No user is authenticated');
        console.log('🔧 This is why Firestore writes are failing!');
        console.log('');
        console.log('Solutions:');
        console.log('1. Enable Anonymous Auth in Firebase Console');
        console.log('2. Sign in user before using walkie-talkie');
        console.log('3. Check authentication flow in your app');
      }
      
      unsubscribe();
      resolve(user);
    });
  });
}

checkAuthState();
