


import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Animated,
  Dimensions,
  StatusBar,
  Platform,
  ScrollView,
  SafeAreaView,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocation } from '../contexts/LocationContext';
import { useAuth } from '../contexts/AuthContext';
import Icon from '../components/Icon';
import { MaterialIcons } from '@expo/vector-icons';

const { width, height } = Dimensions.get('window');

interface Territory {
  id: string;
  name: string;
  center: {
    latitude: number;
    longitude: number;
  };
  radius: number;
  color: string;
  assigned: boolean;
  completionRate: number;
}

interface MapScreenProps {
  navigation: any;
}

const MapScreen: React.FC<MapScreenProps> = ({ navigation }) => {
  console.log('🗺️ MapScreen rendering...');
  const { user } = useAuth();
  const { currentLocation, pathHistory, isTracking } = useLocation();
  const [selectedTerritory, setSelectedTerritory] = useState<Territory | null>(null);
  const [slideAnim] = useState(new Animated.Value(0));
  const [mapMode, setMapMode] = useState<'3d' | 'satellite' | 'street'>('3d');
  const [showMissionPanel, setShowMissionPanel] = useState(false);
  const [missionPanelAnim] = useState(new Animated.Value(0));
  const [territories] = useState<Territory[]>([
    {
      id: '1',
      name: 'Downtown District',
      center: { latitude: 37.7849, longitude: -122.4094 },
      radius: 500,
      color: '#00FF88',
      assigned: true,
      completionRate: 75,
    },
    {
      id: '2',
      name: 'Residential Area A',
      center: { latitude: 37.7749, longitude: -122.4194 },
      radius: 800,
      color: '#40E0FF',
      assigned: false,
      completionRate: 0,
    },
    {
      id: '3',
      name: 'Business Quarter',
      center: { latitude: 37.7949, longitude: -122.3994 },
      radius: 600,
      color: '#FF6B6B',
      assigned: true,
      completionRate: 45,
    },
  ]);

  const missions = [
    {
      id: '1',
      title: 'Discover the nearest unidentified area',
      progress: 1,
      total: 2,
      icon: 'search',
      category: 'Exploration'
    },
    {
      id: '2',
      title: 'Spot 3 species of abundance in the area',
      progress: 2,
      total: 3,
      icon: 'location',
      category: 'Discovery'
    },
    {
      id: '3',
      title: 'Find 5 trees with broad leaves',
      progress: 3,
      total: 5,
      icon: 'check',
      category: 'Collection'
    }
  ];

  useEffect(() => {
    Animated.timing(slideAnim, {
      toValue: 1,
      duration: 800,
      useNativeDriver: true,
    }).start();
  }, [slideAnim]);

  const toggleMissionPanel = () => {
    const toValue = showMissionPanel ? 0 : 1;
    setShowMissionPanel(!showMissionPanel);

    Animated.spring(missionPanelAnim, {
      toValue,
      useNativeDriver: true,
      tension: 100,
      friction: 8,
    }).start();
  };

  const handleTerritorySelect = (territory: Territory) => {
    setSelectedTerritory(territory);
  };

  // Remove unused mapStyle and initialRegion for now

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F8F9FA" />

      {/* 3D Map Background */}
      <View style={styles.mapBackground}>
        <LinearGradient
          colors={['#E8E8E8', '#F5F5F5', '#FFFFFF']}
          style={styles.mapGradient}
        />

        {/* Debug Text */}
        <View style={styles.debugContainer}>
          <Text style={styles.debugText}>Rally Point Map</Text>
          <Text style={styles.debugSubtext}>Territory Overview</Text>
        </View>

        {/* 3D Buildings Simulation */}
        <View style={styles.buildingsContainer}>
          {[...Array(12)].map((_, i) => (
            <View
              key={i}
              style={[
                styles.building,
                {
                  left: `${10 + (i % 4) * 20}%`,
                  top: `${20 + Math.floor(i / 4) * 25}%`,
                  width: 40,
                  height: 60,
                }
              ]}
            />
          ))}
        </View>

        {/* Location Markers */}
        {territories.map((territory, index) => (
          <TouchableOpacity
            key={territory.id}
            style={[
              styles.locationMarker,
              {
                left: `${15 + index * 30}%`,
                top: `${40 + index * 10}%`,
              }
            ]}
            onPress={() => handleTerritorySelect(territory)}
          >
            <View style={[styles.markerDot, { backgroundColor: territory.color }]} />
            <View style={styles.markerPulse} />
          </TouchableOpacity>
        ))}
      </View>

      {/* Left Side Panel */}
      <View style={styles.leftPanel}>
        <TouchableOpacity
          style={styles.panelButton}
          onPress={() => navigation.goBack()}
        >
          <MaterialIcons name="arrow-back" size={24} color="#2C3E50" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.panelButton}>
          <Icon name="menu" size={24} color="#2C3E50" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.panelButton}>
          <Icon name="search" size={24} color="#2C3E50" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.panelButton}>
          <Icon name="location" size={24} color="#2C3E50" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.panelButton}>
          <Icon name="settings" size={24} color="#2C3E50" />
        </TouchableOpacity>
      </View>

      {/* Right Side Panel */}
      <View style={styles.rightPanel}>
        <TouchableOpacity style={styles.panelButton}>
          <Icon name="add" size={24} color="#2C3E50" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.panelButton}>
          <Icon name="filter" size={24} color="#2C3E50" />
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.panelButton}
          onPress={toggleMissionPanel}
        >
          <Icon name="check" size={24} color="#2C3E50" />
        </TouchableOpacity>
      </View>

      {/* Bottom Controls */}
      <View style={styles.bottomControls}>
        <TouchableOpacity style={styles.controlButton}>
          <Icon name="map" size={20} color="#FFFFFF" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.controlButton}>
          <Icon name="navigation" size={20} color="#FFFFFF" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.controlButton}>
          <Icon name="menu" size={20} color="#FFFFFF" />
        </TouchableOpacity>
      </View>

      {/* Mission Panel */}
      <Animated.View
        style={[
          styles.missionPanel,
          {
            transform: [{
              translateX: missionPanelAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [width, 0]
              })
            }]
          }
        ]}
      >
        <View style={styles.missionHeader}>
          <Text style={styles.missionTitle}>Mission</Text>
          <TouchableOpacity onPress={toggleMissionPanel}>
            <Icon name="close" size={24} color="#2C3E50" />
          </TouchableOpacity>
        </View>

        <ScrollView style={styles.missionContent}>
          {missions.map((mission, index) => (
            <View key={mission.id} style={styles.missionItem}>
              <View style={styles.missionIcon}>
                <Icon name={mission.icon} size={20} color="#FFFFFF" />
              </View>
              <View style={styles.missionDetails}>
                <Text style={styles.missionItemTitle}>{mission.title}</Text>
                <Text style={styles.missionCategory}>{mission.category}</Text>
                <View style={styles.progressContainer}>
                  <View style={styles.progressBar}>
                    <View
                      style={[
                        styles.progressFill,
                        { width: `${(mission.progress / mission.total) * 100}%` }
                      ]}
                    />
                  </View>
                  <Text style={styles.progressText}>
                    {mission.progress}/{mission.total}
                  </Text>
                </View>
              </View>
              <TouchableOpacity style={styles.missionAction}>
                <Icon name="forward" size={16} color="#2C3E50" />
              </TouchableOpacity>
            </View>
          ))}
        </ScrollView>

        <TouchableOpacity style={styles.continueButton}>
          <Text style={styles.continueButtonText}>Continue to probe</Text>
        </TouchableOpacity>
      </Animated.View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8F9FA',
  },
  mapBackground: {
    flex: 1,
    backgroundColor: '#E8E8E8',
  },
  mapGradient: {
    flex: 1,
  },
  debugContainer: {
    position: 'absolute',
    top: 100,
    left: 20,
    right: 20,
    alignItems: 'center',
    zIndex: 5,
  },
  debugText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#2C3E50',
    marginBottom: 8,
  },
  debugSubtext: {
    fontSize: 16,
    color: '#6B7280',
  },
  buildingsContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 1,
  },
  building: {
    position: 'absolute',
    backgroundColor: '#D1D5DB',
    borderRadius: 2,
    shadowColor: '#000',
    shadowOffset: { width: 2, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 5,
  },
  locationMarker: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 2,
  },
  markerDot: {
    width: 16,
    height: 16,
    borderRadius: 8,
    borderWidth: 3,
    borderColor: '#FFFFFF',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 5,
  },
  markerPulse: {
    position: 'absolute',
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    borderWidth: 1,
    borderColor: 'rgba(59, 130, 246, 0.3)',
  },

  leftPanel: {
    position: 'absolute',
    left: 20,
    top: 60,
    alignItems: 'center',
    zIndex: 10,
  },
  rightPanel: {
    position: 'absolute',
    right: 20,
    top: 60,
    alignItems: 'center',
    zIndex: 10,
  },
  panelButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  bottomControls: {
    position: 'absolute',
    bottom: 40,
    left: 20,
    right: 20,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
  },
  controlButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#2C3E50',
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
  },

  missionPanel: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: width * 0.85,
    backgroundColor: '#FFFFFF',
    shadowColor: '#000',
    shadowOffset: { width: -2, height: 0 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 5,
    zIndex: 20,
  },
  missionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E7EB',
  },
  missionTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#2C3E50',
  },
  missionContent: {
    flex: 1,
    padding: 20,
  },
  missionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F8F9FA',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  missionIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#2C3E50',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  missionDetails: {
    flex: 1,
  },
  missionItemTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#2C3E50',
    marginBottom: 4,
  },
  missionCategory: {
    fontSize: 12,
    color: '#6B7280',
    marginBottom: 8,
  },
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  progressBar: {
    flex: 1,
    height: 4,
    backgroundColor: '#E5E7EB',
    borderRadius: 2,
    marginRight: 8,
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#10B981',
    borderRadius: 2,
  },
  progressText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#6B7280',
  },
  missionAction: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#E5E7EB',
    alignItems: 'center',
    justifyContent: 'center',
  },
  continueButton: {
    margin: 20,
    backgroundColor: '#2C3E50',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
  },
  continueButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default MapScreen;
