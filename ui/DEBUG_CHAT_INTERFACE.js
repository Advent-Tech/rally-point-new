// Debug script to check if team members are loading properly
const { initializeApp } = require('firebase/app');
const { getFirestore, collection, query, where, getDocs } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyD8UKq7_DoAKTS-L8D90oWXPaJepgDWGTs",
  authDomain: "rally-point-mobile.firebaseapp.com",
  projectId: "rally-point-mobile",
  storageBucket: "rally-point-mobile.firebasestorage.app",
  messagingSenderId: "503617293297",
  appId: "1:503617293297:web:78fd9cd53925b6c5a4d250"
};

async function debugTeamMembers() {
  try {
    console.log('🔍 Debugging team member loading...');
    
    const app = initializeApp(firebaseConfig);
    const db = getFirestore(app);
    
    // Check if users collection exists
    console.log('📋 Checking users collection...');
    const usersSnapshot = await getDocs(collection(db, 'users'));
    console.log(`Found ${usersSnapshot.size} total users in database`);
    
    if (usersSnapshot.size === 0) {
      console.log('❌ No users found in Firestore users collection');
      console.log('💡 This is why team members aren\'t showing up!');
      return;
    }
    
    // List all users and their teams
    console.log('\n👥 All users in database:');
    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      console.log(`- ${doc.id}: ${userData.name || userData.displayName || 'No name'} (Team: ${userData.teamId || 'No team'})`);
    });
    
    // Check for specific team
    console.log('\n🔍 Looking for users with teamId...');
    const teamsFound = new Set();
    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      if (userData.teamId) {
        teamsFound.add(userData.teamId);
      }
    });
    
    console.log(`\n📊 Teams found: ${Array.from(teamsFound).join(', ')}`);
    
    if (teamsFound.size === 0) {
      console.log('❌ No users have teamId field set');
      console.log('💡 Users need teamId field to appear in walkie-talkie');
    }
    
    // Test query for a specific team (if any exist)
    if (teamsFound.size > 0) {
      const firstTeam = Array.from(teamsFound)[0];
      console.log(`\n🧪 Testing query for team: ${firstTeam}`);
      
      const teamQuery = query(
        collection(db, 'users'),
        where('teamId', '==', firstTeam)
      );
      
      const teamSnapshot = await getDocs(teamQuery);
      console.log(`✅ Query returned ${teamSnapshot.size} members for team ${firstTeam}`);
      
      teamSnapshot.forEach((doc) => {
        const userData = doc.data();
        console.log(`  - ${userData.name || userData.displayName || 'No name'} (${doc.id})`);
      });
    }
    
  } catch (error) {
    console.error('❌ Debug failed:', error);
  }
}

debugTeamMembers();
