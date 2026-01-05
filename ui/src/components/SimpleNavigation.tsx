import React, { useState, useEffect } from 'react';
import { View } from 'react-native';
import LocationTrackingScreen from '../screens/LocationTrackingScreen';
import MapScreen from '../screens/MapScreen';

interface SimpleNavigationProps {
  user: any;
  onSignOut: () => void;
}

const SimpleNavigation: React.FC<SimpleNavigationProps> = ({ user, onSignOut }) => {
  const [currentScreen, setCurrentScreen] = useState<'tracking' | 'map'>('tracking');

  const navigation = {
    navigate: (screen: string) => {
      if (screen === 'LocationTracking') {
        setCurrentScreen('tracking');
      } else if (screen === 'Map') {
        setCurrentScreen('map');
      }
    },
    goBack: () => {
      // This will be handled by parent component
      onSignOut(); // For now, just sign out to go back to home
    },
  };

  if (currentScreen === 'tracking') {
    return <LocationTrackingScreen navigation={navigation} />;
  }

  if (currentScreen === 'map') {
    return <MapScreen navigation={navigation} />;
  }

  // Default to tracking screen
  return <LocationTrackingScreen navigation={navigation} />;
};

export default SimpleNavigation;
