import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { useLocation } from '../contexts/LocationContext';

interface PerformanceMetrics {
  locationUpdatesPerSecond: number;
  pathPointsCount: number;
  sessionDuration: number;
  memoryUsage: number;
  batteryOptimized: boolean;
  networkRequests: number;
  offlineQueueSize: number;
}

interface PerformanceMonitorProps {
  visible?: boolean;
  onToggle?: () => void;
}

const PerformanceMonitor: React.FC<PerformanceMonitorProps> = ({ 
  visible = false, 
  onToggle 
}) => {
  const { 
    currentMinistrySession, 
    isTracking, 
    sessionDuration,
    getSessionPath 
  } = useLocation();
  
  const [metrics, setMetrics] = useState<PerformanceMetrics>({
    locationUpdatesPerSecond: 0,
    pathPointsCount: 0,
    sessionDuration: 0,
    memoryUsage: 0,
    batteryOptimized: true,
    networkRequests: 0,
    offlineQueueSize: 0
  });

  const [updateCount, setUpdateCount] = useState(0);
  const [startTime, setStartTime] = useState<number>(Date.now());

  useEffect(() => {
    if (isTracking && currentMinistrySession) {
      const interval = setInterval(() => {
        const now = Date.now();
        const elapsedSeconds = (now - startTime) / 1000;
        const pathPoints = getSessionPath();
        
        setMetrics(prev => ({
          ...prev,
          locationUpdatesPerSecond: updateCount / elapsedSeconds,
          pathPointsCount: pathPoints.length,
          sessionDuration: sessionDuration,
          batteryOptimized: elapsedSeconds > 0 && (updateCount / elapsedSeconds) <= 1.2, // Optimal: ≤1.2 updates/sec
        }));
      }, 1000);

      return () => clearInterval(interval);
    }
  }, [isTracking, currentMinistrySession, updateCount, startTime, sessionDuration, getSessionPath]);

  useEffect(() => {
    if (isTracking) {
      setUpdateCount(prev => prev + 1);
    } else {
      setUpdateCount(0);
      setStartTime(Date.now());
    }
  }, [currentMinistrySession?.pathPoints?.length]);

  const formatDuration = (seconds: number): string => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
      return `${hours}h ${minutes}m ${secs}s`;
    } else if (minutes > 0) {
      return `${minutes}m ${secs}s`;
    } else {
      return `${secs}s`;
    }
  };

  const getPerformanceStatus = (): 'excellent' | 'good' | 'poor' => {
    if (metrics.batteryOptimized && metrics.locationUpdatesPerSecond <= 1.2) {
      return 'excellent';
    } else if (metrics.locationUpdatesPerSecond <= 2.0) {
      return 'good';
    } else {
      return 'poor';
    }
  };

  const getStatusColor = (status: string): string => {
    switch (status) {
      case 'excellent': return '#10B981'; // Green
      case 'good': return '#F59E0B'; // Yellow
      case 'poor': return '#EF4444'; // Red
      default: return '#6B7280'; // Gray
    }
  };

  if (!visible) {
    return (
      <TouchableOpacity
        onPress={onToggle}
        className="absolute top-20 right-4 bg-gray-800 bg-opacity-80 rounded-full p-2 z-50"
      >
        <Text className="text-white text-xs font-bold">📊</Text>
      </TouchableOpacity>
    );
  }

  const performanceStatus = getPerformanceStatus();
  const statusColor = getStatusColor(performanceStatus);

  return (
    <View className="absolute top-20 right-4 bg-white rounded-lg shadow-lg p-4 z-50 min-w-[280px]">
      {/* Header */}
      <View className="flex-row justify-between items-center mb-3">
        <Text className="text-lg font-bold text-gray-800">Performance Monitor</Text>
        <TouchableOpacity onPress={onToggle}>
          <Text className="text-gray-500 text-lg">✕</Text>
        </TouchableOpacity>
      </View>

      {/* Performance Status */}
      <View className="mb-4">
        <View className="flex-row items-center mb-2">
          <View 
            className="w-3 h-3 rounded-full mr-2"
            style={{ backgroundColor: statusColor }}
          />
          <Text className="font-semibold text-gray-800 capitalize">
            {performanceStatus} Performance
          </Text>
        </View>
        <Text className="text-xs text-gray-600">
          {performanceStatus === 'excellent' && 'Optimal battery usage and smooth tracking'}
          {performanceStatus === 'good' && 'Good performance with minor optimizations needed'}
          {performanceStatus === 'poor' && 'High resource usage detected'}
        </Text>
      </View>

      {/* Metrics */}
      <View className="space-y-2">
        <View className="flex-row justify-between">
          <Text className="text-sm text-gray-600">Updates/sec:</Text>
          <Text className="text-sm font-medium text-gray-800">
            {metrics.locationUpdatesPerSecond.toFixed(2)}
          </Text>
        </View>

        <View className="flex-row justify-between">
          <Text className="text-sm text-gray-600">Path Points:</Text>
          <Text className="text-sm font-medium text-gray-800">
            {metrics.pathPointsCount}
          </Text>
        </View>

        <View className="flex-row justify-between">
          <Text className="text-sm text-gray-600">Session Duration:</Text>
          <Text className="text-sm font-medium text-gray-800">
            {formatDuration(metrics.sessionDuration)}
          </Text>
        </View>

        <View className="flex-row justify-between">
          <Text className="text-sm text-gray-600">Battery Optimized:</Text>
          <Text className={`text-sm font-medium ${metrics.batteryOptimized ? 'text-green-600' : 'text-red-600'}`}>
            {metrics.batteryOptimized ? '✓ Yes' : '✗ No'}
          </Text>
        </View>

        <View className="flex-row justify-between">
          <Text className="text-sm text-gray-600">Tracking Active:</Text>
          <Text className={`text-sm font-medium ${isTracking ? 'text-green-600' : 'text-gray-600'}`}>
            {isTracking ? '✓ Active' : '○ Inactive'}
          </Text>
        </View>
      </View>

      {/* Recommendations */}
      {performanceStatus !== 'excellent' && (
        <View className="mt-4 p-3 bg-yellow-50 rounded-lg">
          <Text className="text-xs font-semibold text-yellow-800 mb-1">
            Performance Tips:
          </Text>
          <Text className="text-xs text-yellow-700">
            {performanceStatus === 'poor' && 
              '• Reduce location update frequency\n• Clear old path data\n• Check network connectivity'
            }
            {performanceStatus === 'good' && 
              '• Consider reducing update frequency for better battery life'
            }
          </Text>
        </View>
      )}

      {/* Debug Info (Development only) */}
      {__DEV__ && (
        <View className="mt-3 pt-3 border-t border-gray-200">
          <Text className="text-xs text-gray-500 mb-1">Debug Info:</Text>
          <Text className="text-xs text-gray-400">
            Session ID: {currentMinistrySession?.id?.substring(0, 8)}...
          </Text>
          <Text className="text-xs text-gray-400">
            Last Update: {new Date().toLocaleTimeString()}
          </Text>
        </View>
      )}
    </View>
  );
};

export default PerformanceMonitor;
