import { Territory } from '../services/TerritoryService';
import { Alert } from 'react-native';

export interface LocationPoint {
  lat: number;
  lng: number;
}

export interface WorkerLocationData {
  latitude: number;
  longitude: number;
  timestamp: number;
}

/**
 * Check if a point is inside a polygon using ray casting algorithm
 */
export const isPointInPolygon = (
  point: LocationPoint, 
  polygon: LocationPoint[]
): boolean => {
  const x = point.lat;
  const y = point.lng;
  let inside = false;

  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const xi = polygon[i].lat;
    const yi = polygon[i].lng;
    const xj = polygon[j].lat;
    const yj = polygon[j].lng;

    if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }

  return inside;
};

/**
 * Check if a worker is inside any of their assigned territories
 */
export const isWorkerInsideAssignedTerritories = (
  workerLocation: WorkerLocationData,
  assignedTerritories: Territory[]
): { isInside: boolean; territory?: Territory } => {
  if (!workerLocation || assignedTerritories.length === 0) {
    return { isInside: false };
  }

  const point: LocationPoint = {
    lat: workerLocation.latitude,
    lng: workerLocation.longitude
  };

  for (const territory of assignedTerritories) {
    if (isPointInPolygon(point, territory.coordinates)) {
      return { isInside: true, territory };
    }
  }

  return { isInside: false };
};

/**
 * Get territory status for a worker
 */
export const getWorkerTerritoryStatus = (
  workerLocation: WorkerLocationData | undefined,
  assignedTerritories: Territory[]
): {
  status: 'inside' | 'outside' | 'no-territory' | 'no-location';
  territory?: Territory;
  statusText: string;
  statusColor: string;
} => {
  if (!workerLocation) {
    return {
      status: 'no-location',
      statusText: 'No Location',
      statusColor: '#9ca3af'
    };
  }

  if (assignedTerritories.length === 0) {
    return {
      status: 'no-territory',
      statusText: 'No Territory Assigned',
      statusColor: '#f59e0b'
    };
  }

  const result = isWorkerInsideAssignedTerritories(workerLocation, assignedTerritories);
  
  if (result.isInside) {
    return {
      status: 'inside',
      territory: result.territory,
      statusText: `Inside ${result.territory?.name}`,
      statusColor: '#10b981'
    };
  } else {
    return {
      status: 'outside',
      statusText: 'Outside Territory',
      statusColor: '#ef4444'
    };
  }
};

/**
 * Show territory boundary violation alert
 */
export const showTerritoryViolationAlert = (
  workerName: string,
  territoryName?: string,
  onAssignTerritory?: () => void
) => {
  if (!territoryName) {
    Alert.alert(
      '⚠️ No Territory Assigned',
      `${workerName} doesn't have any territories assigned. Please assign a territory first.`,
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Assign Territory', 
          onPress: onAssignTerritory 
        }
      ]
    );
  } else {
    Alert.alert(
      '🚨 Territory Boundary Alert',
      `${workerName} has moved outside their assigned territory: ${territoryName}`,
      [
        { text: 'OK' },
        { 
          text: 'View Location', 
          onPress: () => {
            console.log('Navigate to worker location');
          }
        }
      ]
    );
  }
};

/**
 * Calculate distance between two points using Haversine formula
 */
export const calculateDistance = (
  lat1: number, 
  lon1: number, 
  lat2: number, 
  lon2: number
): number => {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
};

/**
 * Format distance for display
 */
export const formatDistance = (distanceKm: number): string => {
  if (distanceKm < 1) {
    return `${Math.round(distanceKm * 1000)}m`;
  } else {
    return `${distanceKm.toFixed(1)}km`;
  }
};

/**
 * Smooth distance calculation using moving average to reduce GPS noise
 */
export const smoothDistance = (distances: number[], windowSize: number = 3): number => {
  if (distances.length === 0) return 0;
  if (distances.length < windowSize) return distances[distances.length - 1];
  
  // Take the last 'windowSize' distances and calculate average
  const recentDistances = distances.slice(-windowSize);
  const average = recentDistances.reduce((sum, dist) => sum + dist, 0) / recentDistances.length;
  
  return average;
};

/**
 * Validate if distance change is reasonable based on time interval
 */
export const isReasonableDistance = (
  distance: number, 
  timeIntervalSeconds: number, 
  maxSpeedKmh: number = 50
): boolean => {
  if (timeIntervalSeconds <= 0) return false;
  
  const speedKmh = (distance / (timeIntervalSeconds / 3600));
  return speedKmh <= maxSpeedKmh;
};

/**
 * Calculate smoothed distance with outlier detection
 */
export const calculateSmoothedDistance = (
  lat1: number, 
  lon1: number, 
  lat2: number, 
  lon2: number,
  previousDistances: number[] = [],
  timeIntervalSeconds: number = 0
): { distance: number; isValid: boolean; reason?: string } => {
  const rawDistance = calculateDistance(lat1, lon1, lat2, lon2);
  
  // Check if distance is reasonable
  if (timeIntervalSeconds > 0 && !isReasonableDistance(rawDistance, timeIntervalSeconds)) {
    return {
      distance: 0,
      isValid: false,
      reason: `Unrealistic speed: ${((rawDistance / (timeIntervalSeconds / 3600))).toFixed(1)} km/h`
    };
  }
  
  // Apply smoothing if we have previous distances
  const smoothedDistance = previousDistances.length > 0 
    ? smoothDistance([...previousDistances, rawDistance], 3)
    : rawDistance;
  
  return {
    distance: smoothedDistance,
    isValid: true
  };
};

/**
 * Get territory color based on status
 */
export const getTerritoryColor = (
  territory: Territory,
  isWorkerInside?: boolean
): string => {
  if (territory.color) {
    return territory.color;
  }
  
  // Default colors based on status
  if (isWorkerInside === true) {
    return '#10b981'; // Green for worker inside
  } else if (isWorkerInside === false) {
    return '#ef4444'; // Red for worker outside
  } else {
    return '#3b82f6'; // Blue for default
  }
};
