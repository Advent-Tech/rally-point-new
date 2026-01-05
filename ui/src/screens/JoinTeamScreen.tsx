import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  StatusBar,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import TeamServiceBackendInstance from '../services/TeamServiceBackend';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import Header from '../components/Header';

interface JoinTeamScreenProps {
  navigation: any;
  route: any;
}

const JoinTeamScreen: React.FC<JoinTeamScreenProps> = ({ navigation, route }) => {
  const { user, refreshUserData } = useAuth();
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [teamInfo, setTeamInfo] = useState<{ teamId: string; teamName: string } | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    parseInviteLink();
  }, [route.params]);

  const parseInviteLink = () => {
    try {
      // Try to get invite link from route params first
      let inviteLink = route.params?.inviteLink;

      // If not in params, try to get from URL (for web)
      if (!inviteLink && typeof window !== 'undefined') {
        const teamInfo = TeamService.getTeamInfoFromURL();
        if (teamInfo) {
          setTeamInfo(teamInfo);
          setLoading(false);
          return;
        }
      }

      if (!inviteLink) {
        setError('Invalid invite link');
        setLoading(false);
        return;
      }

      const parsed = TeamService.parseInviteLink(inviteLink);

      if (!parsed) {
        setError('Invalid invite link format');
        setLoading(false);
        return;
      }

      setTeamInfo(parsed);
      setLoading(false);
    } catch (err) {
      console.error('Error parsing invite link:', err);
      setError('Failed to parse invite link');
      setLoading(false);
    }
  };

  const handleJoinTeam = async () => {
    if (!teamInfo || !user) {
      Alert.alert('Error', 'Missing team or user information');
      return;
    }

    // Normalize backend user fields
    const currentTeamId = (user as any).team_id || (user as any).teamId || null;
    const currentTeamName = (user as any).team_name || (user as any).teamName || '';

    if (currentTeamId) {
      Alert.alert(
        'Already in a Team',
        `You are already a member of "${currentTeamName}". Do you want to leave and join "${teamInfo.teamName}"?`,
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Switch Teams', onPress: () => switchTeams() }
        ]
      );
      return;
    }

    try {
      setJoining(true);
      const result = await TeamServiceBackendInstance.joinTeam(teamInfo.teamId);

      if ((result as any)?.success !== false) {
        await refreshUserData();

        Alert.alert(
          'Success',
          `You have successfully joined "${teamInfo.teamName}"!`,
          [
            {
              text: 'OK',
              onPress: () => {
                // Navigate back to dashboard
                navigation.navigate('WorkerDashboard');
              }
            }
          ]
        );
      } else {
        Alert.alert('Error', (result as any)?.message || 'Failed to join team');
      }
    } catch (err) {
      console.error('Error joining team:', err);
      Alert.alert('Error', 'Failed to join team. Please try again.');
    } finally {
      setJoining(false);
    }
  };

  const switchTeams = async () => {
    const currentTeamId = (user as any)?.team_id || (user as any)?.teamId;
    if (!teamInfo || !user || !currentTeamId) return;

    try {
      setJoining(true);

      // Leave current team via backend
      await TeamServiceBackendInstance.leaveTeam();

      // Join new team via backend
      const result = await TeamServiceBackendInstance.joinTeam(teamInfo.teamId);

      if ((result as any)?.success !== false) {
        await refreshUserData();

        Alert.alert(
          'Success',
          `You have successfully switched to "${teamInfo.teamName}"!`,
          [
            {
              text: 'OK',
              onPress: () => {
                // Navigate back to dashboard
                navigation.navigate('WorkerDashboard');
              }
            }
          ]
        );
      } else {
        Alert.alert('Error', (result as any)?.message || 'Failed to switch teams');
      }
    } catch (err) {
      console.error('Error switching teams:', err);
      Alert.alert('Error', 'Failed to switch teams. Please try again.');
    } finally {
      setJoining(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />
        <Header
          showMenu={true}
          showLogo={true}
          showProfile={true}
          showNotifications={true}
          onProfilePress={() => navigation.navigate('Profile')}
          onNotificationPress={() => navigation.navigate('Notifications')}
        />
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading team information...</Text>
        </View>
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />
        <Header
          showMenu={true}
          showLogo={true}
          showProfile={true}
          showNotifications={true}
          onProfilePress={() => navigation.navigate('Profile')}
          onNotificationPress={() => navigation.navigate('Notifications')}
        />
        <View style={styles.centerContainer}>
          <MaterialIcons name="error-outline" size={64} color={COLORS.error} />
          <Text style={styles.errorTitle}>Invalid Invite Link</Text>
          <Text style={styles.errorText}>{error}</Text>
          <TouchableOpacity style={styles.backButton} onPress={() => navigation.goBack()}>
            <Text style={styles.backButtonText}>Go Back</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />
      <Header
        showMenu={true}
        showLogo={true}
        showProfile={true}
        showNotifications={true}
        onProfilePress={() => navigation.navigate('Profile')}
        onNotificationPress={() => navigation.navigate('Notifications')}
      />

      <View style={styles.content}>
        <View style={styles.inviteCard}>
          <View style={styles.iconContainer}>
            <MaterialIcons name="group-add" size={64} color={COLORS.primary} />
          </View>

          <Text style={styles.title}>Team Invitation</Text>
          <Text style={styles.subtitle}>You've been invited to join:</Text>

          <View style={styles.teamNameContainer}>
            <Text style={styles.teamName}>{teamInfo?.teamName}</Text>
          </View>

          {((user as any)?.team_id || (user as any)?.teamId) && (
            <View style={styles.warningContainer}>
              <MaterialIcons name="warning" size={20} color={COLORS.warning} />
              <Text style={styles.warningText}>
                You are currently in "{(user as any)?.team_name || (user as any)?.teamName}". Joining this team will remove you from your current team.
              </Text>
            </View>
          )}

          <TouchableOpacity
            style={[styles.joinButton, joining && styles.joinButtonDisabled]}
            onPress={handleJoinTeam}
            disabled={joining}
          >
            {joining ? (
              <ActivityIndicator size="small" color={COLORS.white} />
            ) : (
              <>
                <MaterialIcons name="check-circle" size={20} color={COLORS.white} />
                <Text style={styles.joinButtonText}>
                  {((user as any)?.team_id || (user as any)?.teamId) ? 'Switch to This Team' : 'Join Team'}
                </Text>
              </>
            )}
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.cancelButton}
            onPress={() => navigation.goBack()}
            disabled={joining}
          >
            <Text style={styles.cancelButtonText}>Cancel</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F3F4F9',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  loadingText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  errorTitle: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
  },
  errorText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
    textAlign: 'center',
  },
  backButton: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.md,
    marginTop: SPACING.xl,
  },
  backButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },
  inviteCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.xl,
    padding: SPACING['2xl'],
    width: '100%',
    maxWidth: 500,
    alignItems: 'center',
    ...SHADOWS.lg,
  },
  iconContainer: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: `${COLORS.primary}15`,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: SPACING.lg,
  },
  title: {
    fontSize: TYPOGRAPHY.sizes['3xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  subtitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginBottom: SPACING.lg,
  },
  teamNameContainer: {
    backgroundColor: `${COLORS.secondary}20`,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.lg,
    marginBottom: SPACING.xl,
  },
  teamName: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.primary,
  },
  warningContainer: {
    flexDirection: 'row',
    backgroundColor: `${COLORS.warning}15`,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.lg,
    gap: SPACING.sm,
  },
  warningText: {
    flex: 1,
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  joinButton: {
    flexDirection: 'row',
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.md,
    alignItems: 'center',
    justifyContent: 'center',
    gap: SPACING.sm,
    width: '100%',
    marginBottom: SPACING.md,
  },
  joinButtonDisabled: {
    opacity: 0.6,
  },
  joinButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },
  cancelButton: {
    paddingVertical: SPACING.md,
  },
  cancelButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
  },
});

export default JoinTeamScreen;

