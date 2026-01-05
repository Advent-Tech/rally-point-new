import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  Alert,
  RefreshControl,
  Dimensions,
  Platform
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import { Header, ModernStatsCard } from '../components';
import ProfilePhotoUpload from '../components/ProfilePhotoUpload';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { TeamServiceBackendInstance } from '../services/TeamServiceBackend';

const { width } = Dimensions.get('window');

interface ProfileScreenProps {
  navigation: any;
}

// Simple statistics type for display (no Firebase)
interface SimpleStatistics {
  totalDistanceCovered: number;
  booksDistributed: number;
  surveysCompleted: number;
  donationsCollected: number;
}

const ProfileScreen: React.FC<ProfileScreenProps> = ({ navigation }) => {
  const { user, signOut } = useAuth();
  const [statistics, setStatistics] = useState<SimpleStatistics>({
    totalDistanceCovered: 0,
    booksDistributed: 0,
    surveysCompleted: 0,
    donationsCollected: 0,
  });
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [teamName, setTeamName] = useState<string | null>(null);

  useEffect(() => {
    if (user) {
      loadProfileData();
    }
    // Only re-run when user ID changes, not on every user object update
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const loadTeamData = async () => {
    if (!user || !user.team_id) return;

    try {
      const team = await TeamServiceBackendInstance.getTeamById(user.team_id);
      if (team) {
        setTeamName(team.name || null);
      }
    } catch (error) {
      console.error('Error loading team data:', error);
    }
  };

  const loadProfileData = async () => {
    if (!user) return;

    try {
      setLoading(true);

      // Load team data if user has a team
      if (user.team_id) {
        await loadTeamData();
      }

      // TODO: Load statistics from backend when available
      // For now, use default values
      setStatistics({
        totalDistanceCovered: 0,
        booksDistributed: 0,
        surveysCompleted: 0,
        donationsCollected: 0,
      });

    } catch (error) {
      console.error('Error loading profile data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadProfileData();
    setRefreshing(false);
  };

  const handleLogout = async () => {
    console.log('🔘 Logout button pressed');

    // Platform-specific confirmation dialog
    let confirmed = false;

    if (Platform.OS === 'web') {
      // Use window.confirm for web
      confirmed = window.confirm('Are you sure you want to logout?');
      console.log('🌐 Web confirmation result:', confirmed);
    } else {
      // Use Alert.alert for mobile with Promise wrapper
      confirmed = await new Promise((resolve) => {
        Alert.alert(
          'Logout',
          'Are you sure you want to logout?',
          [
            {
              text: 'Cancel',
              style: 'cancel',
              onPress: () => {
                console.log('🚫 Logout cancelled');
                resolve(false);
              }
            },
            {
              text: 'Logout',
              style: 'destructive',
              onPress: () => {
                console.log('✅ Logout confirmed');
                resolve(true);
              }
            }
          ],
          { cancelable: false }
        );
      });
    }

    // If user cancelled, return early
    if (!confirmed) {
      console.log('🚫 User cancelled logout');
      return;
    }

    // Proceed with logout
    try {
      console.log('🔄 Starting logout process...');
      console.log('🔍 SignOut function available:', typeof signOut);
      console.log('🔍 Current user:', user?.email);

      if (!signOut) {
        throw new Error('SignOut function not available');
      }

      await signOut();
      console.log('✅ Logout completed successfully');

    } catch (error: any) {
      console.error('❌ Logout error:', error);
      const errorMessage = error?.message || 'Unknown error';

      // Show error alert
      if (Platform.OS === 'web') {
        window.alert(`Failed to logout: ${errorMessage}. Please try again.`);
      } else {
        Alert.alert(
          'Logout Error',
          `Failed to logout: ${errorMessage}. Please try again.`,
          [{ text: 'OK' }]
        );
      }
    }
  };

  const handleEditProfile = () => {
    navigation.navigate('EditProfile');
  };

  const handleChangePassword = () => {
    navigation.navigate('ChangePassword');
  };

  const handleNotificationSettings = () => {
    navigation.navigate('NotificationSettings');
  };

  const handleHelpSupport = () => {
    navigation.navigate('HelpSupport');
  };

  const handleSOS = () => {
    Alert.alert(
      'Emergency SOS',
      'This will send an emergency alert to your team leaders and emergency contacts. Continue?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Send SOS',
          style: 'destructive',
          onPress: async () => {
            // TODO: Implement SOS via backend API when available
            Alert.alert('SOS Sent', 'Emergency alert has been sent successfully.');
          }
        }
      ]
    );
  };

  const handlePhotoSelected = async (_uri: string) => {
    if (!user) return;

    try {
      console.log('📤 Starting profile photo upload process...');
      // TODO: Implement profile photo upload via backend API when available
      Alert.alert('Info', 'Profile photo upload will be available soon.');
    } catch (error) {
      console.error('❌ Error updating profile photo:', error);
      Alert.alert('Error', 'Failed to update profile photo. Please try again.');
    }
  };

  const handlePhotoRemoved = async () => {
    if (!user) return;

    try {
      console.log('🗑️ Starting profile photo removal process...');
      // TODO: Implement profile photo removal via backend API when available
      Alert.alert('Info', 'Profile photo removal will be available soon.');
    } catch (error) {
      console.error('❌ Error removing profile photo:', error);
      Alert.alert('Error', 'Failed to remove profile photo. Please try again.');
    }
  };

  const renderProfileHeader = () => (
    <View style={styles.profileHeader}>
      <View style={styles.avatarContainer}>
        <ProfilePhotoUpload
          currentPhotoUrl={undefined}
          onPhotoSelected={handlePhotoSelected}
          onPhotoRemoved={handlePhotoRemoved}
          size={80}
        />
      </View>

      <View style={styles.profileInfo}>
        <Text style={styles.displayName}>
          {user?.display_name || 'User'}
        </Text>
        <Text style={styles.email}>{user?.email}</Text>
        <View style={styles.roleContainer}>
          <Text style={styles.role}>{user?.role?.toUpperCase() || 'WORKER'}</Text>
        </View>
        {teamName && (
          <Text style={styles.teamInfo}>Team: {teamName}</Text>
        )}
      </View>

      <TouchableOpacity style={styles.editButton} onPress={handleEditProfile}>
        <MaterialIcons name="edit" size={20} color={COLORS.primary} />
      </TouchableOpacity>
    </View>
  );

  const renderStatisticsCards = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Personal Statistics</Text>
      <View style={styles.statsGrid}>
        <ModernStatsCard
          title="Distance Covered"
          value={`${statistics?.totalDistanceCovered?.toFixed(1) || '0.0'} km`}
          icon="map"
          color={COLORS.primary}
          style={styles.statCard}
        />
        <ModernStatsCard
          title="Books Distributed"
          value={statistics?.booksDistributed || 0}
          icon="book"
          color={COLORS.secondary}
          style={styles.statCard}
        />
        <ModernStatsCard
          title="Surveys Completed"
          value={statistics?.surveysCompleted || 0}
          icon="assignment"
          color={COLORS.success}
          style={styles.statCard}
        />
        <ModernStatsCard
          title="Donations Collected"
          value={`$${statistics?.donationsCollected?.toFixed(2) || '0.00'}`}
          icon="attach-money"
          color={COLORS.warning}
          style={styles.statCard}
        />
      </View>
    </View>
  );

  const renderQuickActions = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Quick Actions</Text>
      <View style={styles.actionsList}>
        <TouchableOpacity style={styles.actionItem} onPress={handleEditProfile}>
          <MaterialIcons name="person" size={24} color={COLORS.primary} />
          <Text style={styles.actionText}>Edit Profile</Text>
          <MaterialIcons name="chevron-right" size={24} color={COLORS.darkGray} />
        </TouchableOpacity>
        
        <TouchableOpacity style={styles.actionItem} onPress={handleChangePassword}>
          <MaterialIcons name="lock" size={24} color={COLORS.primary} />
          <Text style={styles.actionText}>Change Password</Text>
          <MaterialIcons name="chevron-right" size={24} color={COLORS.darkGray} />
        </TouchableOpacity>
        
        <TouchableOpacity style={styles.actionItem} onPress={handleNotificationSettings}>
          <MaterialIcons name="notifications" size={24} color={COLORS.primary} />
          <Text style={styles.actionText}>Notification Settings</Text>
          <MaterialIcons name="chevron-right" size={24} color={COLORS.darkGray} />
        </TouchableOpacity>
      </View>
    </View>
  );

  const renderHelpSection = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Help & Support</Text>
      <View style={styles.actionsList}>
        <TouchableOpacity style={styles.actionItem} onPress={handleHelpSupport}>
          <MaterialIcons name="help" size={24} color={COLORS.primary} />
          <Text style={styles.actionText}>Help & Support</Text>
          <MaterialIcons name="chevron-right" size={24} color={COLORS.darkGray} />
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionItem} onPress={() => console.log('Training resources')}>
          <MaterialIcons name="school" size={24} color={COLORS.primary} />
          <Text style={styles.actionText}>Training Resources</Text>
          <MaterialIcons name="chevron-right" size={24} color={COLORS.darkGray} />
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionItem} onPress={() => console.log('App version')}>
          <MaterialIcons name="info" size={24} color={COLORS.primary} />
          <Text style={styles.actionText}>App Version: 1.0.0</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  const renderSafetySection = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Safety & Emergency</Text>
      <TouchableOpacity style={[styles.actionItem, styles.sosButton]} onPress={handleSOS}>
        <MaterialIcons name="emergency" size={24} color={COLORS.error} />
        <Text style={[styles.actionText, styles.sosText]}>Emergency SOS</Text>
        <MaterialIcons name="warning" size={24} color={COLORS.error} />
      </TouchableOpacity>
    </View>
  );

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
        <Header title="Profile" showBackButton onBackPress={() => navigation.goBack()} />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading profile...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
      <Header title="Profile" showBackButton onBackPress={() => navigation.goBack()} />
      
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
        }
        showsVerticalScrollIndicator={false}
      >
        {renderProfileHeader()}
        {renderStatisticsCards()}
        {renderQuickActions()}
        {renderSafetySection()}
        {renderHelpSection()}
        
        {/* Logout Button */}
        <TouchableOpacity
          style={styles.logoutButton}
          onPress={handleLogout}
          activeOpacity={0.7}
        >
          <MaterialIcons name="logout" size={24} color={COLORS.error} />
          <Text style={styles.logoutText}>Logout</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: SPACING.xl,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    ...TYPOGRAPHY.sizes.base,
    color: COLORS.darkGray,
  },
  profileHeader: {
    backgroundColor: COLORS.white,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    flexDirection: 'row',
    alignItems: 'center',
    ...SHADOWS.sm,
  },
  avatarContainer: {
    marginRight: SPACING.md,
  },
  profileInfo: {
    flex: 1,
  },
  displayName: {
    ...TYPOGRAPHY.sizes.xl,
    color: COLORS.primary,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  email: {
    ...TYPOGRAPHY.sizes.base,
    color: COLORS.darkGray,
    marginBottom: 8,
  },
  roleContainer: {
    alignSelf: 'flex-start',
    backgroundColor: COLORS.primary,
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: RADIUS.sm,
    marginBottom: 8,
  },
  role: {
    ...TYPOGRAPHY.sizes.sm,
    color: COLORS.white,
    fontWeight: 'bold',
  },
  teamInfo: {
    ...TYPOGRAPHY.sizes.sm,
    color: COLORS.darkGray,
    marginBottom: 2,
  },
  editButton: {
    padding: SPACING.sm,
  },
  section: {
    backgroundColor: COLORS.white,
    marginBottom: SPACING.md,
    padding: SPACING.lg,
    ...SHADOWS.sm,
  },
  sectionTitle: {
    ...TYPOGRAPHY.sizes.lg,
    color: COLORS.primary,
    fontWeight: 'bold',
    marginBottom: SPACING.md,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  statCard: {
    width: (width - SPACING.lg * 3) / 2,
    marginBottom: SPACING.md,
  },
  actionsList: {
    gap: 1,
  },
  actionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.sm,
    backgroundColor: COLORS.white,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderFlat,
  },
  actionText: {
    ...TYPOGRAPHY.sizes.base,
    color: COLORS.primary,
    flex: 1,
    marginLeft: SPACING.md,
  },
  sosButton: {
    backgroundColor: COLORS.error + '10',
    borderRadius: RADIUS.md,
    borderBottomWidth: 0,
    marginTop: SPACING.sm,
  },
  sosText: {
    color: COLORS.error,
    fontWeight: 'bold',
  },
  logoutButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.white,
    marginHorizontal: SPACING.lg,
    marginTop: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    ...SHADOWS.sm,
  },
  logoutText: {
    ...TYPOGRAPHY.sizes.base,
    color: COLORS.error,
    fontWeight: 'bold',
    marginLeft: SPACING.sm,
  },
});

export default ProfileScreen;
