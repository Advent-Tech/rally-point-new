// PermissionDebugger - Debug component for testing microphone permissions
// Add this component to your app temporarily to debug permission issues

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
} from 'react-native';
import { AudioPermissionsService } from '../services/AudioPermissionsService';

const PermissionDebugger: React.FC = () => {
  const [permissionStatus, setPermissionStatus] = useState<any>(null);
  const [browserPermissionState, setBrowserPermissionState] = useState<string>('unknown');
  const [isLoading, setIsLoading] = useState(false);

  const audioService = AudioPermissionsService.getInstance();

  useEffect(() => {
    checkCurrentStatus();
    checkBrowserPermissionState();
  }, []);

  const checkCurrentStatus = async () => {
    try {
      const status = await audioService.getCurrentPermissionStatus();
      setPermissionStatus(status);
      console.log('🔍 Current permission status:', status);
    } catch (error) {
      console.error('Error checking status:', error);
    }
  };

  const checkBrowserPermissionState = async () => {
    try {
      if (typeof navigator !== 'undefined' && navigator.permissions) {
        const permissionStatus = await navigator.permissions.query({ name: 'microphone' as PermissionName });
        setBrowserPermissionState(permissionStatus.state);
        console.log('🌐 Browser permission state:', permissionStatus.state);
      } else {
        setBrowserPermissionState('not supported');
      }
    } catch (error) {
      console.error('Error checking browser permission:', error);
      setBrowserPermissionState('error');
    }
  };

  const requestPermission = async () => {
    try {
      setIsLoading(true);
      console.log('🎤 Manually requesting permission...');
      const result = await audioService.requestMicrophonePermission();
      console.log('🎤 Permission result:', result);
      setPermissionStatus(result);
      
      Alert.alert(
        'Permission Result',
        `Granted: ${result.granted}\nStatus: ${result.status}\nMessage: ${result.message}`,
        [{ text: 'OK' }]
      );
    } catch (error) {
      console.error('Error requesting permission:', error);
      Alert.alert('Error', 'Failed to request permission');
    } finally {
      setIsLoading(false);
    }
  };

  const resetPermissions = async () => {
    try {
      await audioService.resetPermissions();
      setPermissionStatus(null);
      Alert.alert('Reset', 'Permissions have been reset');
      console.log('🗑️ Permissions reset');
    } catch (error) {
      console.error('Error resetting permissions:', error);
    }
  };

  const resetRequestFlag = () => {
    try {
      audioService.resetRequestFlag();
      Alert.alert('Reset', 'Permission request flag has been reset');
      console.log('🔄 Request flag reset');
    } catch (error) {
      console.error('Error resetting request flag:', error);
    }
  };

  const refreshPermissions = async () => {
    try {
      setIsLoading(true);
      console.log('🔄 Refreshing permission status...');
      const result = await audioService.refreshPermissionStatus();
      console.log('🔄 Refresh result:', result);
      setPermissionStatus(result);
      
      Alert.alert(
        'Refresh Result',
        result 
          ? `Granted: ${result.granted}\nStatus: ${result.status}\nMessage: ${result.message}`
          : 'No permission status found',
        [{ text: 'OK' }]
      );
    } catch (error) {
      console.error('Error refreshing permissions:', error);
      Alert.alert('Error', 'Failed to refresh permissions');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>🎤 Permission Debugger</Text>
      
      <View style={styles.statusContainer}>
        <Text style={styles.statusTitle}>Browser Permission State:</Text>
        <Text style={[styles.statusText, { color: browserPermissionState === 'granted' ? '#34C759' : '#FF3B30' }]}>
          {browserPermissionState}
        </Text>
      </View>

      <View style={styles.statusContainer}>
        <Text style={styles.statusTitle}>App Saved Status:</Text>
        <Text style={styles.statusText}>
          {permissionStatus ? JSON.stringify(permissionStatus, null, 2) : 'No status'}
        </Text>
      </View>

      <TouchableOpacity 
        style={styles.button} 
        onPress={requestPermission}
        disabled={isLoading}
      >
        <Text style={styles.buttonText}>
          {isLoading ? 'Requesting...' : 'Request Permission'}
        </Text>
      </TouchableOpacity>

      <TouchableOpacity 
        style={[styles.button, styles.secondaryButton]} 
        onPress={checkCurrentStatus}
      >
        <Text style={styles.buttonText}>Check Status</Text>
      </TouchableOpacity>

      <TouchableOpacity 
        style={[styles.button, styles.refreshButton]} 
        onPress={refreshPermissions}
        disabled={isLoading}
      >
        <Text style={styles.buttonText}>
          {isLoading ? 'Refreshing...' : 'Refresh from Browser'}
        </Text>
      </TouchableOpacity>

      <TouchableOpacity 
        style={[styles.button, styles.dangerButton]} 
        onPress={resetPermissions}
      >
        <Text style={styles.buttonText}>Reset Permissions</Text>
      </TouchableOpacity>

      <TouchableOpacity 
        style={[styles.button, styles.warningButton]} 
        onPress={resetRequestFlag}
      >
        <Text style={styles.buttonText}>Reset Request Flag</Text>
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: 20,
    backgroundColor: '#f5f5f5',
    margin: 10,
    borderRadius: 10,
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 15,
    textAlign: 'center',
  },
  statusContainer: {
    backgroundColor: '#fff',
    padding: 15,
    borderRadius: 8,
    marginBottom: 15,
  },
  statusTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 8,
  },
  statusText: {
    fontSize: 12,
    fontFamily: 'monospace',
    color: '#666',
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 8,
    marginBottom: 10,
    alignItems: 'center',
  },
  secondaryButton: {
    backgroundColor: '#34C759',
  },
  refreshButton: {
    backgroundColor: '#FF9500',
  },
  dangerButton: {
    backgroundColor: '#FF3B30',
  },
  warningButton: {
    backgroundColor: '#FF9500',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default PermissionDebugger;
