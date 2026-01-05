import React, { useState, useCallback } from 'react';
import {
  View,
  StyleSheet,
  SafeAreaView,
  StatusBar,
} from 'react-native';
import Header from '../components/Header';
import GeoTerritoryMap from '../components/GeoTerritoryMap';
import { GeoTerritory, ChurchLocation } from '../services/GeoTerritoryService';
import { COLORS } from '../constants/Colors';

interface GeoTerritoryMapScreenProps {
  navigation: any;
  route?: {
    params?: {
      onTerritorySelect?: (territory: GeoTerritory) => void;
      onChurchSelect?: (church: ChurchLocation) => void;
      initialTerritoryId?: string;
      selectionMode?: boolean;
    };
  };
}

const GeoTerritoryMapScreen: React.FC<GeoTerritoryMapScreenProps> = ({
  navigation,
  route
}) => {
  const {
    onTerritorySelect,
    onChurchSelect,
    initialTerritoryId,
    selectionMode = false
  } = route?.params || {};

  const [selectedTerritory, setSelectedTerritory] = useState<GeoTerritory | null>(null);

  const handleTerritorySelect = useCallback((territory: GeoTerritory) => {
    setSelectedTerritory(territory);

    // If in selection mode, call the callback and navigate back
    if (selectionMode && onTerritorySelect) {
      onTerritorySelect(territory);
      navigation.goBack();
    }
  }, [selectionMode, onTerritorySelect, navigation]);

  const handleChurchSelect = useCallback((church: ChurchLocation) => {
    if (selectionMode && onChurchSelect) {
      onChurchSelect(church);
      navigation.goBack();
    }
  }, [selectionMode, onChurchSelect, navigation]);

  const handleBackPress = useCallback(() => {
    if (navigation.canGoBack()) {
      navigation.goBack();
    } else {
      navigation.navigate('AdminDashboard');
    }
  }, [navigation]);

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#1e293b" />

      <Header
        title={selectionMode ? "Select Territory" : "Territory Map"}
        subtitle={selectionMode ? "Tap a territory to select" : "View all church territories"}
        showBackButton={true}
        onBackPress={handleBackPress}
      />

      <View style={styles.mapWrapper}>
        <GeoTerritoryMap
          height="100%"
          showSearch={true}
          showStats={true}
          onTerritorySelect={handleTerritorySelect}
          onChurchSelect={handleChurchSelect}
          selectedTerritoryId={initialTerritoryId}
        />
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  mapWrapper: {
    flex: 1,
  },
});

export default GeoTerritoryMapScreen;
