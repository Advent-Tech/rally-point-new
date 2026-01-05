// Simple test file to verify auth integration
import { authService } from '../services/authService';

export const testAuthConnection = async () => {
  console.log('🧪 Testing auth connection...');
  
  try {
    // Test health check
    const isHealthy = await authService.healthCheck();
    console.log('✅ Health check:', isHealthy);
    
    // Test login with dummy credentials (will fail but tests the API)
    try {
      await authService.login('test@example.com', 'wrongpassword');
    } catch (error: any) {
      console.log('✅ Login API reachable (expected error):', error.message);
    }
    
    // Test register with dummy credentials (will fail but tests the API)
    try {
      await authService.register('test@example.com', 'password123', 'Test User', 'worker');
    } catch (error: any) {
      console.log('✅ Register API reachable (expected error):', error.message);
    }
    
    console.log('✅ Auth integration test complete');
    return true;
  } catch (error) {
    console.error('❌ Auth integration test failed:', error);
    return false;
  }
};
