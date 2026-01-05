/**
 * Walkie-Talkie Debug Test
 * Tests the complete walkie-talkie flow to identify issues
 */

import { WalkieTalkieService } from '../services/WalkieTalkieService';

export const testWalkieTalkieState = () => {
  console.log('🧪 Starting Walkie-Talkie Debug Test...');
  
  try {
    // Test 1: Get service instance
    console.log('\n📋 Test 1: Getting service instance...');
    const service = WalkieTalkieService.getInstance();
    console.log('✅ Service instance created:', service ? 'SUCCESS' : 'FAILED');
    
    // Test 2: Get initial state
    console.log('\n📋 Test 2: Getting initial state...');
    const initialState = service.getState();
    console.log('Initial State:', JSON.stringify(initialState, null, 2));
    
    if (!initialState) {
      console.error('❌ FAILED: Initial state is null/undefined');
      return false;
    }
    
    // Test 3: Verify state structure
    console.log('\n📋 Test 3: Verifying state structure...');
    const requiredFields = [
      'isConnected',
      'isTransmitting',
      'isReceiving',
      'currentSpeaker',
      'currentSpeakerName',
      'sessionId',
      'teamMembers'
    ];
    
    let structureValid = true;
    requiredFields.forEach(field => {
      if (!(field in initialState)) {
        console.error(`❌ Missing field: ${field}`);
        structureValid = false;
      } else {
        console.log(`✅ Field present: ${field} = ${JSON.stringify(initialState[field])}`);
      }
    });
    
    if (!structureValid) {
      console.error('❌ FAILED: State structure is invalid');
      return false;
    }
    
    // Test 4: Test state change subscription
    console.log('\n📋 Test 4: Testing state change subscription...');
    let callbackCalled = false;
    let receivedState = null;
    
    const unsubscribe = service.onStateChange((state) => {
      console.log('📢 State change callback called!');
      console.log('Received state:', JSON.stringify(state, null, 2));
      callbackCalled = true;
      receivedState = state;
    });
    
    // Wait a bit to see if callback is called
    setTimeout(() => {
      if (callbackCalled) {
        console.log('✅ State change callback was called');
        console.log('Received state:', JSON.stringify(receivedState, null, 2));
        
        // Verify received state
        if (receivedState && typeof receivedState === 'object') {
          console.log('✅ Received state is valid object');
          
          // Check all required fields
          let allFieldsPresent = true;
          requiredFields.forEach(field => {
            if (!(field in receivedState)) {
              console.error(`❌ Missing field in received state: ${field}`);
              allFieldsPresent = false;
            }
          });
          
          if (allFieldsPresent) {
            console.log('✅ All required fields present in received state');
          } else {
            console.error('❌ Some fields missing in received state');
          }
        } else {
          console.error('❌ Received state is not a valid object');
        }
      } else {
        console.error('❌ FAILED: State change callback was NOT called');
        console.error('This means onStateChange is not calling the callback immediately');
      }
      
      // Cleanup
      unsubscribe();
      
      console.log('\n🎉 Walkie-Talkie Debug Test Complete!');
      console.log('Summary:');
      console.log('- Service instance: ✅');
      console.log('- Initial state: ' + (initialState ? '✅' : '❌'));
      console.log('- State structure: ' + (structureValid ? '✅' : '❌'));
      console.log('- State callback: ' + (callbackCalled ? '✅' : '❌'));
    }, 1000);
    
    return true;
  } catch (error) {
    console.error('❌ Test failed with error:', error);
    return false;
  }
};

// Auto-run test when imported
if (typeof window !== 'undefined') {
  console.log('🚀 Auto-running Walkie-Talkie Debug Test...');
  setTimeout(() => {
    testWalkieTalkieState();
  }, 2000);
}

export default testWalkieTalkieState;

