/**
 * Rally Point Offline Geotracking Test Script
 *
 * This script demonstrates how to test the enhanced offline geotracking feature
 * including location tracking, delivery recording, and offline sync functionality
 */

// Mock Firebase Realtime Database structure for testing
const mockWorkerData = {
  // Encoded email: john_DOT_smith_AT_example_DOT_com
  "john_DOT_smith_AT_example_DOT_com": {
    id: "john.smith@example.com",
    name: "John Smith",
    isActive: true,
    currentLocation: {
      latitude: 40.7128,
      longitude: -74.0060,
      timestamp: Date.now(),
      accuracy: 5.0,
      speed: 0.0,
      heading: 0.0
    },
    lastSeen: Date.now(),
    updatedAt: Date.now()
  },
  "mary_DOT_johnson_AT_example_DOT_com": {
    id: "mary.johnson@example.com", 
    name: "Mary Johnson",
    isActive: true,
    currentLocation: {
      latitude: 40.7589,
      longitude: -73.9851,
      timestamp: Date.now(),
      accuracy: 3.0,
      speed: 1.2,
      heading: 45.0
    },
    lastSeen: Date.now(),
    updatedAt: Date.now()
  },
  "david_DOT_wilson_AT_example_DOT_com": {
    id: "david.wilson@example.com",
    name: "David Wilson", 
    isActive: true,
    currentLocation: {
      latitude: 40.7505,
      longitude: -73.9934,
      timestamp: Date.now(),
      accuracy: 4.0,
      speed: 0.5,
      heading: 180.0
    },
    lastSeen: Date.now(),
    updatedAt: Date.now()
  }
};

// Mock territory data
const mockTerritoryData = [
  {
    id: "territory-1",
    name: "Manhattan District 1",
    coordinates: [
      { lat: 40.7100, lng: -74.0100 },
      { lat: 40.7200, lng: -74.0100 },
      { lat: 40.7200, lng: -74.0000 },
      { lat: 40.7100, lng: -74.0000 }
    ],
    assignedWorker: {
      id: "john.smith@example.com",
      name: "John Smith",
      email: "john.smith@example.com"
    },
    color: "#002b5b",
    createdAt: Date.now(),
    isActive: true,
    source: "manual"
  },
  {
    id: "territory-2", 
    name: "Manhattan District 2",
    coordinates: [
      { lat: 40.7550, lng: -73.9900 },
      { lat: 40.7650, lng: -73.9900 },
      { lat: 40.7650, lng: -73.9800 },
      { lat: 40.7550, lng: -73.9800 }
    ],
    assignedWorker: {
      id: "mary.johnson@example.com",
      name: "Mary Johnson", 
      email: "mary.johnson@example.com"
    },
    color: "#d7a638",
    createdAt: Date.now(),
    isActive: true,
    source: "manual"
  },
  {
    id: "territory-3",
    name: "Manhattan District 3", 
    coordinates: [
      { lat: 40.7450, lng: -73.9980 },
      { lat: 40.7550, lng: -73.9980 },
      { lat: 40.7550, lng: -73.9880 },
      { lat: 40.7450, lng: -73.9880 }
    ],
    assignedWorker: {
      id: "david.wilson@example.com",
      name: "David Wilson",
      email: "david.wilson@example.com"
    },
    color: "#10b981",
    createdAt: Date.now(),
    isActive: true,
    source: "manual"
  }
];

/**
 * Simulate real-time location updates for testing
 */
function simulateLocationUpdates() {
  console.log('🚀 Starting geotracking simulation...');
  
  // Simulate location updates every 2 seconds (faster than real 1-second updates for demo)
  setInterval(() => {
    Object.keys(mockWorkerData).forEach(workerId => {
      const worker = mockWorkerData[workerId];
      
      // Simulate small location changes (worker movement)
      const latChange = (Math.random() - 0.5) * 0.001; // ~100m movement
      const lngChange = (Math.random() - 0.5) * 0.001;
      
      worker.currentLocation.latitude += latChange;
      worker.currentLocation.longitude += lngChange;
      worker.currentLocation.timestamp = Date.now();
      worker.lastSeen = Date.now();
      worker.updatedAt = Date.now();
      
      // Simulate speed changes
      worker.currentLocation.speed = Math.random() * 2.0; // 0-2 m/s walking speed
      worker.currentLocation.heading = Math.random() * 360; // Random direction
      
      console.log(`📍 Updated location for ${worker.name}:`, {
        lat: worker.currentLocation.latitude.toFixed(6),
        lng: worker.currentLocation.longitude.toFixed(6),
        speed: worker.currentLocation.speed.toFixed(1),
        timestamp: new Date(worker.currentLocation.timestamp).toLocaleTimeString()
      });
    });
  }, 2000);
}

/**
 * Test territory boundary detection
 */
function testTerritoryBoundaryDetection() {
  console.log('🗺️ Testing territory boundary detection...');
  
  mockTerritoryData.forEach(territory => {
    const worker = Object.values(mockWorkerData).find(w => 
      w.id === territory.assignedWorker?.id
    );
    
    if (worker) {
      const isInside = isPointInTerritory(
        { lat: worker.currentLocation.latitude, lng: worker.currentLocation.longitude },
        territory.coordinates
      );
      
      console.log(`${worker.name} in ${territory.name}: ${isInside ? '✅ INSIDE' : '❌ OUTSIDE'}`);
    }
  });
}

/**
 * Simple point-in-polygon test (basic implementation)
 */
function isPointInTerritory(point, territoryCoords) {
  let inside = false;
  const x = point.lat;
  const y = point.lng;
  
  for (let i = 0, j = territoryCoords.length - 1; i < territoryCoords.length; j = i++) {
    const xi = territoryCoords[i].lat;
    const yi = territoryCoords[i].lng;
    const xj = territoryCoords[j].lat;
    const yj = territoryCoords[j].lng;
    
    if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  
  return inside;
}

/**
 * Display current tracking status
 */
function displayTrackingStatus() {
  console.log('\n📊 CURRENT TRACKING STATUS');
  console.log('=' .repeat(50));
  
  const activeWorkers = Object.values(mockWorkerData).filter(w => w.isActive);
  console.log(`Active Workers: ${activeWorkers.length}`);
  console.log(`Total Territories: ${mockTerritoryData.length}`);
  
  activeWorkers.forEach(worker => {
    const territory = mockTerritoryData.find(t => 
      t.assignedWorker?.id === worker.id
    );
    
    console.log(`\n👤 ${worker.name}`);
    console.log(`   📍 Location: ${worker.currentLocation.latitude.toFixed(6)}, ${worker.currentLocation.longitude.toFixed(6)}`);
    console.log(`   🗺️ Territory: ${territory?.name || 'Unassigned'}`);
    console.log(`   🚶 Speed: ${worker.currentLocation.speed.toFixed(1)} m/s`);
    console.log(`   🕐 Last Update: ${new Date(worker.currentLocation.timestamp).toLocaleTimeString()}`);
  });
  
  console.log('\n' + '=' .repeat(50));
}

/**
 * Test offline functionality
 */
function testOfflineFunctionality() {
  console.log('\n🔌 TESTING OFFLINE FUNCTIONALITY');
  console.log('=' .repeat(50));

  // Simulate offline location storage
  const offlineLocations = [];
  const offlineDeliveries = [];

  Object.values(mockWorkerData).forEach((worker, index) => {
    // Simulate offline location data
    for (let i = 0; i < 5; i++) {
      offlineLocations.push({
        id: `offline_location_${worker.id}_${i}`,
        userId: worker.id,
        userName: worker.name,
        latitude: worker.currentLocation.latitude + (Math.random() - 0.5) * 0.001,
        longitude: worker.currentLocation.longitude + (Math.random() - 0.5) * 0.001,
        timestamp: Date.now() - (i * 60000), // 1 minute intervals
        accuracy: 5.0,
        speed: Math.random() * 2.0,
        heading: Math.random() * 360,
        sessionId: `session_${worker.id}_${Date.now()}`,
        syncStatus: 'pending'
      });
    }

    // Simulate offline delivery data
    for (let i = 0; i < 3; i++) {
      offlineDeliveries.push({
        id: `offline_delivery_${worker.id}_${i}`,
        workerId: worker.id,
        workerName: worker.name,
        bookTitle: `Book ${i + 1}`,
        deliveryType: i % 2 === 0 ? 'door' : 'person',
        location: {
          latitude: worker.currentLocation.latitude + (Math.random() - 0.5) * 0.001,
          longitude: worker.currentLocation.longitude + (Math.random() - 0.5) * 0.001,
          timestamp: Date.now() - (i * 30000) // 30 second intervals
        },
        timestamp: Date.now() - (i * 30000),
        status: ['delivered_to_person', 'delivered_to_door', 'not_home'][i],
        notes: `Delivery note ${i + 1}`,
        sessionId: `session_${worker.id}_${Date.now()}`,
        syncStatus: 'pending'
      });
    }
  });

  console.log(`📍 Offline Locations: ${offlineLocations.length}`);
  console.log(`📦 Offline Deliveries: ${offlineDeliveries.length}`);
  console.log(`🔄 Total Pending Sync: ${offlineLocations.length + offlineDeliveries.length}`);

  // Simulate sync process
  setTimeout(() => {
    console.log('\n🔄 SIMULATING SYNC PROCESS');
    console.log('Network connection restored...');

    let syncedCount = 0;
    const totalItems = offlineLocations.length + offlineDeliveries.length;

    const syncInterval = setInterval(() => {
      if (syncedCount < totalItems) {
        syncedCount++;
        const progress = Math.round((syncedCount / totalItems) * 100);
        console.log(`Syncing... ${progress}% (${syncedCount}/${totalItems})`);
      } else {
        clearInterval(syncInterval);
        console.log('✅ All offline data synced successfully!');
        console.log(`📊 Sync Summary:`);
        console.log(`   - Locations synced: ${offlineLocations.length}`);
        console.log(`   - Deliveries synced: ${offlineDeliveries.length}`);
        console.log(`   - Total items: ${totalItems}`);
      }
    }, 500);
  }, 3000);
}

/**
 * Main test function
 */
function runGeotrackingTest() {
  console.log('🎯 Rally Point Offline Geotracking Test Started');
  console.log('This script simulates the enhanced offline geotracking feature\n');

  // Display initial status
  displayTrackingStatus();

  // Test boundary detection
  setTimeout(() => {
    testTerritoryBoundaryDetection();
  }, 1000);

  // Test offline functionality
  setTimeout(() => {
    testOfflineFunctionality();
  }, 2000);

  // Start location simulation
  setTimeout(() => {
    simulateLocationUpdates();
  }, 5000);

  // Display status updates every 15 seconds
  setInterval(() => {
    displayTrackingStatus();
    testTerritoryBoundaryDetection();
  }, 15000);

  console.log('\n💡 To test the enhanced offline functionality in the app:');
  console.log('1. Assign territories to workers in Territory Management');
  console.log('2. Have workers start "Ministry Tracking" in My Territory tab');
  console.log('3. Turn off internet connection on worker devices');
  console.log('4. Continue tracking locations and recording deliveries');
  console.log('5. Turn internet back on - data will auto-sync');
  console.log('6. View real-time locations in Admin Dashboard > Live Worker Tracking');
  console.log('7. Check offline sync status in app indicators\n');
}

// Export for use in other test files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    mockWorkerData,
    mockTerritoryData,
    simulateLocationUpdates,
    testTerritoryBoundaryDetection,
    displayTrackingStatus,
    runGeotrackingTest
  };
}

// Run test if this file is executed directly
if (typeof window === 'undefined' && require.main === module) {
  runGeotrackingTest();
}
