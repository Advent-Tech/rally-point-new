import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Platform } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';

interface LiveMapScreenProps {
  navigation: any;
  route: {
    params: {
      workerId: string;
      workerName: string;
    };
  };
}

interface WorkerLocation {
  latitude: number;
  longitude: number;
  timestamp: Date;
}

export default function LiveMapScreen({ navigation, route }: LiveMapScreenProps) {
  const { workerId, workerName } = route.params;
  const [workerLocation, setWorkerLocation] = useState<WorkerLocation | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());

  useEffect(() => {
    console.log('LiveMapScreen opened for:', workerName, 'ID:', workerId);

    // Real-time location updates would be handled through a service layer
    setIsLoading(false);

    // Cleanup function
    return () => {};
  }, [workerId, workerName]);

  // Auto-refresh every 3 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      setLastUpdate(new Date());
    }, 3000);

    return () => clearInterval(interval);
  }, []);

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  const openInGoogleMaps = () => {
    if (workerLocation) {
      const url = `https://www.google.com/maps?q=${workerLocation.latitude},${workerLocation.longitude}&z=16`;
      if (Platform.OS === 'web') {
        window.open(url, '_blank');
      }
    }
  };

  if (isLoading) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>Loading...</Text>
        </View>
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>🔍 Locating worker...</Text>
        </View>
      </View>
    );
  }

  if (!workerLocation) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>{workerName}</Text>
        </View>
        <View style={styles.noLocationContainer}>
          <Text style={styles.noLocationIcon}>📍</Text>
          <Text style={styles.noLocationTitle}>Location Not Available</Text>
          <Text style={styles.noLocationSubtitle}>
            Worker hasn't enabled location tracking yet.
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <MaterialIcons name="arrow-back" size={24} color="#ffffff" />
        </TouchableOpacity>
        <Text style={styles.title}>Live Tracking</Text>
        <View style={styles.liveIndicator}>
          <View style={styles.liveDot} />
          <Text style={styles.liveText}>LIVE</Text>
        </View>
      </View>

      {/* Google Maps Embed - Full Screen */}
      <View style={styles.mapContainer}>
        {Platform.OS === 'web' ? (
          <iframe
            key={`map-${workerLocation.latitude}-${workerLocation.longitude}-${lastUpdate.getTime()}`}
            src={`https://www.google.com/maps/embed/v1/place?key=AIzaSyD8UKq7_DoAKTS-L8D90oWXPaJepgDWGTs&q=${workerLocation.latitude},${workerLocation.longitude}&zoom=16&maptype=roadmap`}
            style={{
              width: '100%',
              height: '100%',
              border: 0,
              borderRadius: '0px',
            }}
            allowFullScreen
            loading="lazy"
            title={`${workerName} Live Location`}
          />
        ) : (
          <View style={styles.mobileMapPlaceholder}>
            <Text style={styles.mobileMapText}>📍 {workerName}</Text>
            <Text style={styles.mobileMapCoords}>
              {workerLocation.latitude.toFixed(6)}, {workerLocation.longitude.toFixed(6)}
            </Text>
          </View>
        )}
      </View>

      {/* Bottom Info Panel */}
      <View style={styles.bottomPanel}>
        <View style={styles.workerInfo}>
          <Text style={styles.workerName}>📍 {workerName}</Text>
          <Text style={styles.coordinates}>
            {workerLocation.latitude.toFixed(6)}, {workerLocation.longitude.toFixed(6)}
          </Text>
          <Text style={styles.lastUpdate}>
            Last updated: {formatTime(workerLocation.timestamp)} • Auto-refresh: {formatTime(lastUpdate)}
          </Text>
        </View>
        
        <TouchableOpacity style={styles.openMapsButton} onPress={openInGoogleMaps}>
          <Text style={styles.openMapsText}>🗺️ Open in Google Maps</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  header: {
    backgroundColor: '#1a1a1a',
    paddingTop: 50,
    paddingHorizontal: 20,
    paddingBottom: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  backButton: {
    fontSize: 16,
    color: '#3b82f6',
    fontWeight: '600',
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#ffffff',
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(16, 185, 129, 0.2)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#10b981',
    marginRight: 6,
  },
  liveText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#10b981',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
  },
  loadingText: {
    fontSize: 18,
    color: '#ffffff',
  },
  noLocationContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
    padding: 40,
  },
  noLocationIcon: {
    fontSize: 64,
    marginBottom: 20,
  },
  noLocationTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#ffffff',
    marginBottom: 12,
    textAlign: 'center',
  },
  noLocationSubtitle: {
    fontSize: 16,
    color: '#9ca3af',
    textAlign: 'center',
    lineHeight: 24,
  },
  mapContainer: {
    flex: 1,
  },
  mobileMapPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
  },
  mobileMapText: {
    fontSize: 24,
    color: '#ffffff',
    marginBottom: 16,
  },
  mobileMapCoords: {
    fontSize: 18,
    color: '#3b82f6',
    fontFamily: 'monospace',
  },
  bottomPanel: {
    backgroundColor: '#1a1a1a',
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: '#374151',
  },
  workerInfo: {
    marginBottom: 16,
  },
  workerName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#ffffff',
    marginBottom: 8,
  },
  coordinates: {
    fontSize: 16,
    color: '#3b82f6',
    fontFamily: 'monospace',
    marginBottom: 8,
  },
  lastUpdate: {
    fontSize: 12,
    color: '#9ca3af',
  },
  openMapsButton: {
    backgroundColor: '#3b82f6',
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 12,
    alignItems: 'center',
  },
  openMapsText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
});
