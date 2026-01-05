import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  FlatList,
  Animated,
  Dimensions,
  StatusBar,
  Platform,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialIcons } from '@expo/vector-icons';
import { useLocation } from '../contexts/LocationContext';
import { useAuth } from '../contexts/AuthContext';

const { width, height } = Dimensions.get('window');

interface PathHistoryScreenProps {
  navigation: any;
}

const PathHistoryScreen: React.FC<PathHistoryScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const { pastSessions, loadPastSessions } = useLocation();
  const [slideAnim] = useState(new Animated.Value(0));
  const [selectedSession, setSelectedSession] = useState(null);

  useEffect(() => {
    loadPastSessions();
    
    Animated.timing(slideAnim, {
      toValue: 1,
      duration: 800,
      useNativeDriver: true,
    }).start();
  }, [slideAnim]);

  const formatDuration = (startTime: number, endTime?: number): string => {
    const duration = (endTime || Date.now()) - startTime;
    const hours = Math.floor(duration / (1000 * 60 * 60));
    const minutes = Math.floor((duration % (1000 * 60 * 60)) / (1000 * 60));
    return `${hours}h ${minutes}m`;
  };

  const formatDistance = (km: number): string => {
    if (km < 1) {
      return `${Math.round(km * 1000)}m`;
    }
    return `${km.toFixed(2)}km`;
  };

  const formatDate = (timestamp: number): string => {
    return new Date(timestamp).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const formatTime = (timestamp: number): string => {
    return new Date(timestamp).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const renderSessionItem = ({ item, index }) => (
    <Animated.View
      style={[
        styles.sessionCard,
        {
          transform: [{
            translateY: slideAnim.interpolate({
              inputRange: [0, 1],
              outputRange: [50 * (index + 1), 0],
            }),
          }],
          opacity: slideAnim,
        },
      ]}
    >
      <TouchableOpacity
        onPress={() => setSelectedSession(item)}
        activeOpacity={0.8}
      >
        <LinearGradient
          colors={item.isActive ? 
            ['rgba(0,255,136,0.1)', 'rgba(0,255,136,0.05)'] : 
            ['rgba(255,255,255,0.1)', 'rgba(255,255,255,0.05)']
          }
          style={styles.glassmorphismCard}
        >
          <View style={styles.sessionHeader}>
            <View style={styles.sessionInfo}>
              <Text style={styles.sessionName}>
                {item.sessionName || `Session ${formatDate(item.startTime)}`}
              </Text>
              <Text style={styles.sessionDate}>
                {formatDate(item.startTime)} • {formatTime(item.startTime)}
              </Text>
            </View>
            <View style={styles.statusIndicator}>
              <View style={[
                styles.statusDot,
                { backgroundColor: item.isActive ? '#00FF88' : '#64748b' }
              ]} />
              <Text style={styles.statusText}>
                {item.isActive ? 'ACTIVE' : 'COMPLETED'}
              </Text>
            </View>
          </View>

          <View style={styles.sessionStats}>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{formatDistance(item.totalDistance)}</Text>
              <Text style={styles.statLabel}>Distance</Text>
            </View>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>
                {formatDuration(item.startTime, item.endTime)}
              </Text>
              <Text style={styles.statLabel}>Duration</Text>
            </View>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{item.pathPoints?.length || 0}</Text>
              <Text style={styles.statLabel}>Points</Text>
            </View>
          </View>

          {item.isActive && (
            <View style={styles.activeIndicator}>
              <LinearGradient
                colors={['#00FF88', '#00CC6A']}
                style={styles.activeBar}
              />
            </View>
          )}
        </LinearGradient>
      </TouchableOpacity>
    </Animated.View>
  );

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="transparent" translucent />
      
      {/* Background Gradient */}
      <LinearGradient
        colors={['#0F0C29', '#24243e', '#302B63']}
        style={styles.backgroundGradient}
      />

      {/* Header */}
      <Animated.View 
        style={[
          styles.header,
          {
            transform: [{
              translateY: slideAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [-100, 0],
              }),
            }],
          },
        ]}
      >
        <View style={styles.glassmorphismCard}>
          <View style={styles.headerContent}>
            <TouchableOpacity
              onPress={() => navigation.goBack()}
              style={styles.backButton}
            >
              <MaterialIcons name="arrow-back" size={24} color="#ffffff" />
            </TouchableOpacity>
            <View style={styles.headerText}>
              <Text style={styles.headerTitle}>Path History</Text>
              <Text style={styles.headerSubtitle}>{user?.displayName} • {pastSessions.length} Sessions</Text>
            </View>
          </View>
        </View>
      </Animated.View>

      {/* Sessions List */}
      <View style={styles.content}>
        {pastSessions.length === 0 ? (
          <Animated.View 
            style={[
              styles.emptyState,
              { opacity: slideAnim }
            ]}
          >
            <Text style={styles.emptyStateTitle}>No Sessions Yet</Text>
            <Text style={styles.emptyStateText}>
              Start tracking your field operations to see your path history here.
            </Text>
            <TouchableOpacity
              style={styles.startTrackingButton}
              onPress={() => navigation.navigate('LocationTracking')}
            >
              <LinearGradient
                colors={['#00FF88', '#00CC6A']}
                style={styles.buttonGradient}
              >
                <Text style={styles.buttonText}>START TRACKING</Text>
              </LinearGradient>
            </TouchableOpacity>
          </Animated.View>
        ) : (
          <FlatList
            data={pastSessions}
            renderItem={renderSessionItem}
            keyExtractor={(item) => item.id}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={styles.listContainer}
          />
        )}
      </View>

      {/* Bottom Actions */}
      <View style={styles.bottomActions}>
        <TouchableOpacity
          style={styles.actionButton}
          onPress={() => loadPastSessions()}
        >
          <LinearGradient
            colors={['rgba(255,255,255,0.1)', 'rgba(255,255,255,0.05)']}
            style={styles.actionButtonGradient}
          >
            <Text style={styles.actionButtonText}>🔄 REFRESH</Text>
          </LinearGradient>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.actionButton}
          onPress={() => navigation.navigate('Map')}
        >
          <LinearGradient
            colors={['#40E0FF', '#0099CC']}
            style={styles.actionButtonGradient}
          >
            <Text style={styles.actionButtonText}>🗺️ VIEW MAP</Text>
          </LinearGradient>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0F0C29',
  },
  backgroundGradient: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
  },
  header: {
    paddingTop: Platform.OS === 'ios' ? 60 : 40,
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  glassmorphismCard: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
    elevation: 10,
  },
  headerContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 15,
  },
  backButtonText: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: 'bold',
  },
  headerText: {
    flex: 1,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 5,
  },
  headerSubtitle: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.7)',
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
  },
  listContainer: {
    paddingBottom: 20,
  },
  sessionCard: {
    marginBottom: 15,
  },
  sessionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 15,
  },
  sessionInfo: {
    flex: 1,
  },
  sessionName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 5,
  },
  sessionDate: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.6)',
  },
  statusIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 8,
  },
  statusText: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.8)',
    fontWeight: '600',
    letterSpacing: 1,
  },
  sessionStats: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 10,
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 5,
  },
  statLabel: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.6)',
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  activeIndicator: {
    marginTop: 10,
  },
  activeBar: {
    height: 3,
    borderRadius: 2,
  },
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
  },
  emptyStateTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 15,
    textAlign: 'center',
  },
  emptyStateText: {
    fontSize: 16,
    color: 'rgba(255,255,255,0.7)',
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: 30,
  },
  startTrackingButton: {
    borderRadius: 25,
    overflow: 'hidden',
    shadowColor: '#00FF88',
    shadowOffset: { width: 0, height: 5 },
    shadowOpacity: 0.3,
    shadowRadius: 10,
    elevation: 5,
  },
  buttonGradient: {
    paddingVertical: 18,
    paddingHorizontal: 40,
    alignItems: 'center',
  },
  buttonText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
    letterSpacing: 1,
  },
  bottomActions: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingBottom: 40,
    paddingTop: 20,
  },
  actionButton: {
    flex: 1,
    marginHorizontal: 5,
    borderRadius: 15,
    overflow: 'hidden',
  },
  actionButtonGradient: {
    paddingVertical: 15,
    alignItems: 'center',
  },
  actionButtonText: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#FFFFFF',
    letterSpacing: 1,
  },
});

export default PathHistoryScreen;
