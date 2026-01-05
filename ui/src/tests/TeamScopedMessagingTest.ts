// Team-Scoped Messaging Test for Rally Point App
// This test verifies that team-scoped messaging functionality works correctly

import { MessagingService } from '../services/MessagingService';

interface TestUser {
  uid: string;
  email: string;
  displayName: string;
  teamId: string;
  teamName: string;
}

// Mock test users
const testUsers: TestUser[] = [
  {
    uid: 'user1',
    email: 'worker1@team1.com',
    displayName: 'Worker 1',
    teamId: 'team1',
    teamName: 'Team Alpha'
  },
  {
    uid: 'user2',
    email: 'worker2@team1.com',
    displayName: 'Worker 2',
    teamId: 'team1',
    teamName: 'Team Alpha'
  },
  {
    uid: 'user3',
    email: 'worker3@team2.com',
    displayName: 'Worker 3',
    teamId: 'team2',
    teamName: 'Team Beta'
  }
];

/**
 * Test Team-Scoped Messaging Functionality
 */
export class TeamScopedMessagingTest {
  
  /**
   * Test 1: Users in the same team can message each other
   */
  static async testSameTeamMessaging(): Promise<boolean> {
    try {
      console.log('🧪 Testing same team messaging...');
      
      // Test if user1 can message user2 (both in team1)
      const canMessage = await MessagingService.canMessageUser('user1', 'user2');
      
      if (canMessage) {
        console.log('✅ Same team messaging test passed');
        return true;
      } else {
        console.log('❌ Same team messaging test failed');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in same team messaging test:', error);
      return false;
    }
  }

  /**
   * Test 2: Users in different teams cannot message each other
   */
  static async testDifferentTeamMessaging(): Promise<boolean> {
    try {
      console.log('🧪 Testing different team messaging restriction...');
      
      // Test if user1 can message user3 (different teams)
      const canMessage = await MessagingService.canMessageUser('user1', 'user3');
      
      if (!canMessage) {
        console.log('✅ Different team messaging restriction test passed');
        return true;
      } else {
        console.log('❌ Different team messaging restriction test failed');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in different team messaging test:', error);
      return false;
    }
  }

  /**
   * Test 3: Get team members returns only same team users
   */
  static async testGetTeamMembers(): Promise<boolean> {
    try {
      console.log('🧪 Testing get team members...');
      
      // Get team members for user1
      const teamMembers = await MessagingService.getTeamMembers('user1');
      
      // Should only return user2 (same team), not user3 (different team)
      const hasUser2 = teamMembers.some(member => member.userId === 'user2');
      const hasUser3 = teamMembers.some(member => member.userId === 'user3');
      
      if (hasUser2 && !hasUser3) {
        console.log('✅ Get team members test passed');
        return true;
      } else {
        console.log('❌ Get team members test failed');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in get team members test:', error);
      return false;
    }
  }

  /**
   * Test 4: Team conversation creation
   */
  static async testTeamConversationCreation(): Promise<boolean> {
    try {
      console.log('🧪 Testing team conversation creation...');
      
      // Create team conversation for user1
      const conversationId = await MessagingService.getOrCreateTeamConversation(
        'user1',
        'Worker 1',
        'worker'
      );
      
      if (conversationId) {
        console.log('✅ Team conversation creation test passed');
        return true;
      } else {
        console.log('❌ Team conversation creation test failed');
        return false;
      }
    } catch (error) {
      console.error('❌ Error in team conversation creation test:', error);
      return false;
    }
  }

  /**
   * Run all tests
   */
  static async runAllTests(): Promise<void> {
    console.log('🚀 Starting Team-Scoped Messaging Tests...\n');
    
    const tests = [
      { name: 'Same Team Messaging', test: this.testSameTeamMessaging },
      { name: 'Different Team Messaging Restriction', test: this.testDifferentTeamMessaging },
      { name: 'Get Team Members', test: this.testGetTeamMembers },
      { name: 'Team Conversation Creation', test: this.testTeamConversationCreation }
    ];

    let passedTests = 0;
    let totalTests = tests.length;

    for (const { name, test } of tests) {
      console.log(`\n📋 Running test: ${name}`);
      const result = await test();
      if (result) {
        passedTests++;
      }
    }

    console.log('\n📊 Test Results:');
    console.log(`✅ Passed: ${passedTests}/${totalTests}`);
    console.log(`❌ Failed: ${totalTests - passedTests}/${totalTests}`);
    
    if (passedTests === totalTests) {
      console.log('🎉 All team-scoped messaging tests passed!');
    } else {
      console.log('⚠️ Some tests failed. Please check the implementation.');
    }
  }
}

// Export for use in other files
export default TeamScopedMessagingTest;
