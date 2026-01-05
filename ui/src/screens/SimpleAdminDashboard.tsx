import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { COLORS } from '../constants';

const SimpleAdminDashboard: React.FC = () => {
  console.log('SimpleAdminDashboard: Rendering...');
  
  return (
    <View style={styles.container}>
      <Text style={styles.title}>ADMIN DASHBOARD</Text>
      <Text style={styles.subtitle}>This is a simple test dashboard</Text>
      
      <TouchableOpacity style={styles.button}>
        <Text style={styles.buttonText}>Test Button</Text>
      </TouchableOpacity>
      
      <View style={styles.debugBox}>
        <Text style={styles.debugText}>DEBUG: If you can see this, the component is working</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ff0000', // Bright red background for visibility
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#ffffff',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 16,
    color: '#ffffff',
    marginBottom: 20,
    textAlign: 'center',
  },
  button: {
    backgroundColor: '#ffffff',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
    marginBottom: 20,
  },
  buttonText: {
    color: '#ff0000',
    fontSize: 16,
    fontWeight: 'bold',
  },
  debugBox: {
    backgroundColor: '#000000',
    padding: 15,
    borderRadius: 8,
    marginTop: 20,
  },
  debugText: {
    color: '#ffffff',
    fontSize: 14,
    textAlign: 'center',
  },
});

export default SimpleAdminDashboard;
