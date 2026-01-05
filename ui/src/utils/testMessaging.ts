import { MessagingService } from '../services/MessagingService';
import { UserManagementService } from '../services/UserManagementService';

/**
 * Test utility functions for messaging functionality
 */
export class MessagingTestUtils {
  
  /**
   * Test team messaging setup
   */
  static async testTeamMessaging(userId: string) {
    try {
      console.log('🧪 Testing Team Messaging Setup...');
      
      // 1. Get user profile
      console.log('1. Getting user profile...');
      const userResult = await UserManagementService.getUserProfile(userId);
      if (!userResult.success || !userResult.data) {
        console.error('❌ User not found');
        return false;
      }
      
      const user = userResult.data;
      console.log('✅ User found:', user.displayName, 'Team:', user.teamName);
      
      // 2. Check if user has team
      if (!user.teamId) {
        console.error('❌ User not assigned to team');
        return false;
      }
      
      // 3. Get team details
      console.log('2. Getting team details...');
      const teamResult = await UserManagementService.getTeam(user.teamId);
      if (!teamResult.success || !teamResult.data) {
        console.error('❌ Team not found');
        return false;
      }
      
      const team = teamResult.data;
      console.log('✅ Team found:', team.name, 'Members:', team.memberCount);
      
      // 4. Get team members
      console.log('3. Getting team members...');
      const membersResult = await UserManagementService.getAllUsers({
        teamId: user.teamId,
        status: 'active'
      });
      
      if (!membersResult.success || !membersResult.data) {
        console.error('❌ Failed to get team members');
        return false;
      }
      
      const teamMembers = membersResult.data;
      console.log('✅ Team members found:', teamMembers.length);
      
      // 5. Test team conversation creation
      console.log('4. Testing team conversation...');
      const existingConversation = await MessagingService.getTeamConversation(user.teamId);
      
      if (existingConversation) {
        console.log('✅ Team conversation exists:', existingConversation.id);
      } else {
        console.log('📝 Creating team conversation...');
        
        const participantDetails = teamMembers
          .filter(member => member.uid !== userId)
          .map(member => ({
            userId: member.uid,
            name: member.displayName || member.email.split('@')[0],
            role: member.role,
            isOnline: member.isOnline || false,
            lastSeen: member.lastActiveAt || new Date(),
            joinedAt: new Date()
          }));
        
        const conversationId = await MessagingService.createTeamConversation(
          user.teamId,
          team.name,
          team.leaderId || userId,
          team.leaderName || user.displayName || 'Team Leader',
          teamMembers.filter(m => m.uid !== userId).map(m => m.uid),
          participantDetails,
          `Team chat for ${team.name}`
        );
        
        if (conversationId) {
          console.log('✅ Team conversation created:', conversationId);
        } else {
          console.error('❌ Failed to create team conversation');
          return false;
        }
      }
      
      console.log('🎉 Team messaging setup successful!');
      return true;
      
    } catch (error) {
      console.error('❌ Team messaging test failed:', error);
      return false;
    }
  }
  
  /**
   * Test direct messaging between team members
   */
  static async testDirectMessaging(userId1: string, userId2: string) {
    try {
      console.log('🧪 Testing Direct Messaging...');
      
      // 1. Get both users
      const [user1Result, user2Result] = await Promise.all([
        UserManagementService.getUserProfile(userId1),
        UserManagementService.getUserProfile(userId2)
      ]);
      
      if (!user1Result.success || !user2Result.success) {
        console.error('❌ One or both users not found');
        return false;
      }
      
      const user1 = user1Result.data!;
      const user2 = user2Result.data!;
      
      // 2. Check if users are in same team
      if (user1.teamId !== user2.teamId) {
        console.error('❌ Users not in same team');
        return false;
      }
      
      console.log('✅ Both users in same team:', user1.teamName);
      
      // 3. Test direct conversation creation
      const conversationId = await MessagingService.getOrCreateDirectConversation(
        userId1,
        user1.displayName || user1.email.split('@')[0],
        user1.role,
        userId2,
        user2.displayName || user2.email.split('@')[0],
        user2.role
      );
      
      if (conversationId) {
        console.log('✅ Direct conversation created/found:', conversationId);
        return true;
      } else {
        console.error('❌ Failed to create direct conversation');
        return false;
      }
      
    } catch (error) {
      console.error('❌ Direct messaging test failed:', error);
      return false;
    }
  }
  
  /**
   * Test message sending
   */
  static async testSendMessage(conversationId: string, userId: string, message: string) {
    try {
      console.log('🧪 Testing Message Sending...');
      
      const userResult = await UserManagementService.getUserProfile(userId);
      if (!userResult.success || !userResult.data) {
        console.error('❌ User not found');
        return false;
      }
      
      const user = userResult.data;
      
      const messageId = await MessagingService.sendMessage(
        conversationId,
        userId,
        user.displayName || user.email.split('@')[0],
        user.role,
        message,
        'text'
      );
      
      if (messageId) {
        console.log('✅ Message sent successfully:', messageId);
        return true;
      } else {
        console.error('❌ Failed to send message');
        return false;
      }
      
    } catch (error) {
      console.error('❌ Message sending test failed:', error);
      return false;
    }
  }
  
  /**
   * Run all messaging tests
   */
  static async runAllTests(userId: string, otherUserId?: string) {
    console.log('🚀 Starting Messaging Tests...\n');
    
    const results = {
      teamMessaging: false,
      directMessaging: false,
      messageSending: false
    };
    
    // Test team messaging
    results.teamMessaging = await this.testTeamMessaging(userId);
    
    // Test direct messaging if other user provided
    if (otherUserId) {
      results.directMessaging = await this.testDirectMessaging(userId, otherUserId);
    }
    
    console.log('\n📊 Test Results:');
    console.log('Team Messaging:', results.teamMessaging ? '✅' : '❌');
    console.log('Direct Messaging:', results.directMessaging ? '✅' : '❌');
    
    const allPassed = Object.values(results).every(result => result);
    console.log('\n🎯 Overall Result:', allPassed ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED');
    
    return results;
  }
}

// Export for easy testing in console
(global as any).MessagingTestUtils = MessagingTestUtils;
