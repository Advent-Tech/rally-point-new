// WalkieTalkieTest - Comprehensive test suite for walkie-talkie functionality
// Tests real-time audio streaming, team filtering, and push-to-talk mechanism

import { WalkieTalkieService } from '../services/WalkieTalkieService';
import { AudioPermissionsService } from '../services/AudioPermissionsService';

interface TestUser {
  uid: string;
  email: string;
  displayName: string;
  teamId: string;
  teamName: string;
  role: string;
}

// Mock test users for different teams
const testUsers: TestUser[] = [
  {
    uid: 'user1',
    email: 'worker1@team1.com',
    displayName: 'Worker 1',
    teamId: 'team1',
    teamName: 'Team Alpha',
    role: 'worker'
  },
  {
    uid: 'user2',
    email: 'worker2@team1.com',
    displayName: 'Worker 2',
    teamId: 'team1',
    teamName: 'Team Alpha',
    role: 'worker'
  },
  {
    uid: 'user3',
    email: 'leader1@team1.com',
    displayName: 'Team Leader 1',
    teamId: 'team1',
    teamName: 'Team Alpha',
    role: 'team_leader'
  },
  {
    uid: 'user4',
    email: 'worker3@team2.com',
    displayName: 'Worker 3',
    teamId: 'team2',
    teamName: 'Team Beta',
    role: 'worker'
  }
];

/**
 * Test Suite for Walkie-Talkie Functionality
 */
export class WalkieTalkieTest {
  private static walkieTalkieService = WalkieTalkieService.getInstance();
  private static audioPermissionsService = AudioPermissionsService.getInstance();

  /**
   * Test 1: Service Initialization
   */
  static async testServiceInitialization(): Promise<boolean> {
    try {
      console.log('🧪 Testing walkie-talkie service initialization...');
      
      const user = testUsers[0]; // Use first test user
      
      // Initialize audio permissions service
      await this.audioPermissionsService.initialize();
      
      // Initialize walkie-talkie service
      const initialized = await this.walkieTalkieService.initialize(
        user.uid,
        user.displayName
      );
      
      if (initialized) {
        console.log('✅ Service initialization test passed');
        return true;
      } else {
        console.log('❌ Service initialization test failed');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in service initialization test:', error);
      return false;
    }
  }

  /**
   * Test 2: Audio Permissions
   */
  static async testAudioPermissions(): Promise<boolean> {
    try {
      console.log('🧪 Testing audio permissions...');
      
      // Test permission request
      const permissionResult = await this.audioPermissionsService.requestMicrophonePermission();
      
      if (permissionResult.granted) {
        console.log('✅ Audio permissions test passed');
        return true;
      } else {
        console.log('❌ Audio permissions test failed:', permissionResult.message);
        return false;
      }
    } catch (error) {
      console.error('❌ Error in audio permissions test:', error);
      return false;
    }
  }

  /**
   * Test 3: Team-Scoped Session Creation
   */
  static async testTeamScopedSession(): Promise<boolean> {
    try {
      console.log('🧪 Testing team-scoped session creation...');
      
      const user = testUsers[0]; // Team Alpha worker
      
      // Start transmission
      const success = await this.walkieTalkieService.startTransmitting(
        user.uid,
        user.displayName,
        user.teamId,
        user.teamName
      );
      
      if (success) {
        // Check if session is created
        const state = this.walkieTalkieService.getState();
        
        if (state.isTransmitting && state.currentSpeaker === user.uid) {
          console.log('✅ Team-scoped session creation test passed');
          
          // Clean up
          await this.walkieTalkieService.stopTransmitting();
          return true;
        } else {
          console.log('❌ Team-scoped session creation test failed - invalid state');
          return false;
        }
      } else {
        console.log('❌ Team-scoped session creation test failed - could not start transmission');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in team-scoped session test:', error);
      return false;
    }
  }

  /**
   * Test 4: Team Member Filtering
   */
  static async testTeamMemberFiltering(): Promise<boolean> {
    try {
      console.log('🧪 Testing team member filtering...');
      
      const user1 = testUsers[0]; // Team Alpha
      const user4 = testUsers[3]; // Team Beta
      
      // Get team members for user1 (Team Alpha)
      const teamMembers1 = await this.walkieTalkieService.getTeamMembers(user1.uid);
      
      // Should include user2 and user3 (same team), but not user4 (different team)
      const hasTeamMember = teamMembers1.some(member => 
        member.userId === testUsers[1].uid || member.userId === testUsers[2].uid
      );
      const hasDifferentTeamMember = teamMembers1.some(member => 
        member.userId === user4.uid
      );
      
      if (hasTeamMember && !hasDifferentTeamMember) {
        console.log('✅ Team member filtering test passed');
        return true;
      } else {
        console.log('❌ Team member filtering test failed');
        console.log('Team members found:', teamMembers1.map(m => m.userId));
        return false;
      }
    } catch (error) {
      console.error('❌ Error in team member filtering test:', error);
      return false;
    }
  }

  /**
   * Test 5: Concurrent Speaker Prevention
   */
  static async testConcurrentSpeakerPrevention(): Promise<boolean> {
    try {
      console.log('🧪 Testing concurrent speaker prevention...');
      
      const user1 = testUsers[0]; // First speaker
      const user2 = testUsers[1]; // Second speaker (same team)
      
      // User1 starts transmitting
      const success1 = await this.walkieTalkieService.startTransmitting(
        user1.uid,
        user1.displayName,
        user1.teamId,
        user1.teamName
      );
      
      if (!success1) {
        console.log('❌ Could not start first transmission');
        return false;
      }
      
      // User2 tries to start transmitting (should fail)
      const success2 = await this.walkieTalkieService.startTransmitting(
        user2.uid,
        user2.displayName,
        user2.teamId,
        user2.teamName
      );
      
      // Clean up
      await this.walkieTalkieService.stopTransmitting();
      
      if (!success2) {
        console.log('✅ Concurrent speaker prevention test passed');
        return true;
      } else {
        console.log('❌ Concurrent speaker prevention test failed - second user could start transmission');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in concurrent speaker prevention test:', error);
      return false;
    }
  }

  /**
   * Test 6: Audio Configuration
   */
  static async testAudioConfiguration(): Promise<boolean> {
    try {
      console.log('🧪 Testing audio configuration...');
      
      // Test recording options
      const recordingOptions = this.audioPermissionsService.getRecordingOptions();
      
      if (recordingOptions && recordingOptions.android && recordingOptions.ios) {
        console.log('✅ Audio configuration test passed');
        return true;
      } else {
        console.log('❌ Audio configuration test failed - invalid recording options');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in audio configuration test:', error);
      return false;
    }
  }

  /**
   * Test 7: State Management
   */
  static async testStateManagement(): Promise<boolean> {
    try {
      console.log('🧪 Testing state management...');
      
      const user = testUsers[0];
      let stateChangeCount = 0;
      
      // Subscribe to state changes
      const unsubscribe = this.walkieTalkieService.onStateChange((state) => {
        stateChangeCount++;
        console.log('State changed:', state.isTransmitting, state.currentSpeaker);
      });
      
      // Start transmission
      await this.walkieTalkieService.startTransmitting(
        user.uid,
        user.displayName,
        user.teamId,
        user.teamName
      );
      
      // Wait a bit for state changes
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // Stop transmission
      await this.walkieTalkieService.stopTransmitting();
      
      // Wait a bit more
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // Cleanup
      unsubscribe();
      
      if (stateChangeCount > 0) {
        console.log('✅ State management test passed');
        return true;
      } else {
        console.log('❌ State management test failed - no state changes detected');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in state management test:', error);
      return false;
    }
  }

  /**
   * Run all walkie-talkie tests
   */
  static async runAllTests(): Promise<void> {
    console.log('🚀 Starting Walkie-Talkie Tests...\n');
    
    const tests = [
      { name: 'Service Initialization', test: this.testServiceInitialization },
      { name: 'Audio Permissions', test: this.testAudioPermissions },
      { name: 'Team-Scoped Session Creation', test: this.testTeamScopedSession },
      { name: 'Team Member Filtering', test: this.testTeamMemberFiltering },
      { name: 'Concurrent Speaker Prevention', test: this.testConcurrentSpeakerPrevention },
      { name: 'Audio Configuration', test: this.testAudioConfiguration },
      { name: 'State Management', test: this.testStateManagement }
    ];

    let passedTests = 0;
    let totalTests = tests.length;

    for (const { name, test } of tests) {
      console.log(`\n📋 Running test: ${name}`);
      try {
        const result = await test();
        if (result) {
          passedTests++;
        }
      } catch (error) {
        console.error(`❌ Test "${name}" threw an error:`, error);
      }
    }

    console.log('\n📊 Walkie-Talkie Test Results:');
    console.log(`✅ Passed: ${passedTests}/${totalTests}`);
    console.log(`❌ Failed: ${totalTests - passedTests}/${totalTests}`);
    
    if (passedTests === totalTests) {
      console.log('🎉 All walkie-talkie tests passed!');
    } else {
      console.log('⚠️ Some tests failed. Please check the implementation.');
    }

    // Cleanup
    await this.walkieTalkieService.cleanup();
  }
}

// Export for use in other files
export default WalkieTalkieTest;
