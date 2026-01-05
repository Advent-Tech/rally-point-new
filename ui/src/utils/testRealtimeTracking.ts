/**
 * Test utility to verify real-time location tracking is working
 */

import { realtimeLocationService } from '../services/RealtimeLocationService';

export const testRealtimeTracking = async (userId: string, userName: string) => {
  console.log('🧪 Testing real-time location tracking...');
  
  try {
    // Start tracking
    console.log('Starting tracking for:', userName);
    await realtimeLocationService.startLocationTracking(userId, userName);
    console.log('Tracking started successfully');
    
    // Listen to updates for 30 seconds
    console.log('Listening for location updates...');
    const unsubscribe = realtimeLocationService.listenToWorker(userId, (worker) => {
      if (worker && worker.currentLocation) {
        console.log('Location update received:', {
          worker: worker.name,
          location: worker.currentLocation,
          timestamp: new Date(worker.currentLocation.timestamp).toLocaleTimeString(),
          isActive: worker.isActive
        });
      } else {
        console.log('No location data received for worker:', userName);
      }
    });
    
    // Stop test after 30 seconds
    setTimeout(() => {
      console.log('🛑 Stopping test...');
      unsubscribe();
      realtimeLocationService.stopLocationTracking();
      console.log('✅ Test completed');
    }, 30000);
    
    return true;
  } catch (error) {
    console.error('❌ Test failed:', error);
    return false;
  }
};

export const testAllWorkers = () => {
  console.log('Testing all workers listener...');
  
  const unsubscribe = realtimeLocationService.listenToAllWorkers((workers) => {
    console.log('All workers update:', {
      totalWorkers: workers.length,
      activeWorkers: workers.filter(w => w.isActive).length,
      workers: workers.map(w => ({
        name: w.name,
        isActive: w.isActive,
        hasLocation: !!w.currentLocation,
        lastSeen: w.lastSeen ? new Date(w.lastSeen).toLocaleTimeString() : 'Never'
      }))
    });
  });
  
  // Stop test after 30 seconds
  setTimeout(() => {
    console.log('Stopping all workers test...');
    unsubscribe();
    console.log('All workers test completed');
  }, 30000);
  
  return unsubscribe;
};
