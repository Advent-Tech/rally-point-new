import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  Modal,
  TouchableOpacity,
  Animated,
  Dimensions,
  SafeAreaView,
  StyleSheet,
  Alert
} from 'react-native';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { UserManagementService } from '../services/UserManagementService';
import { MessagingService } from '../services/MessagingService';
import { ManagedUser } from '../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import TeamChatView from './messaging/TeamChatView';
import DirectMessagesView from './messaging/DirectMessagesView';
import TeamMembersList from './messaging/TeamMembersList';

interface TeamMessagingBottomSheetProps {
  visible: boolean;
  onClose: () => void;
}

type MessagingTab = 'team' | 'direct' | 'members';

const { height: screenHeight } = Dimensions.get('window');

const TeamMessagingBottomSheet: React.FC<TeamMessagingBottomSheetProps> = ({
  visible,
  onClose
}) => {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState<MessagingTab>('team');
  const [teamMembers, setTeamMembers] = useState<ManagedUser[]>([]);
  const [userTeam, setUserTeam] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const slideAnim = useRef(new Animated.Value(screenHeight)).current;

  // Load user's team and team members
  useEffect(() => {
    if (visible && user) {
      loadTeamData();
      animateIn();
    }
  }, [visible, user]);

  const loadTeamData = async () => {
    if (!user) return;

    try {
      setLoading(true);

      // First check if user has team_id in auth context (for workers)
      let teamId = (user as any).team_id;

      // If not, try to get from user profile
      if (!teamId) {
        const userProfile = await UserManagementService.getUserProfile(user.uid);
        teamId = userProfile.data?.teamId;
      }

      if (!teamId) {
        Alert.alert(
          'No Team Assigned',
          'You need to be assigned to a team to use team messaging. Please contact your admin.',
          [{ text: 'OK', onPress: onClose }]
        );
        return;
      }

      console.log('📱 Loading team data for teamId:', teamId);
      
      // Get team details
      const teamResult = await UserManagementService.getTeam(teamId);
      if (teamResult.success && teamResult.data) {
        setUserTeam(teamResult.data);
      }

      // Get team members
      const membersResult = await UserManagementService.getAllUsers({
        teamId: teamId,
        status: 'active'
      });
      
      if (membersResult.success && membersResult.data) {
        // Filter out current user from team members list for direct messaging
        const otherMembers = membersResult.data.filter(member => member.uid !== user.uid);
        setTeamMembers(otherMembers);
      }
    } catch (error) {
      console.error('Error loading team data:', error);
      Alert.alert('Error', 'Failed to load team information');
    } finally {
      setLoading(false);
    }
  };

  const animateIn = () => {
    Animated.timing(slideAnim, {
      toValue: 0,
      duration: 300,
      useNativeDriver: true,
    }).start();
  };

  const animateOut = () => {
    Animated.timing(slideAnim, {
      toValue: screenHeight,
      duration: 300,
      useNativeDriver: true,
    }).start(() => {
      onClose();
    });
  };

  const handleClose = () => {
    animateOut();
  };

  const renderTabButton = (tab: MessagingTab, icon: string, label: string, count?: number) => {
    const isActive = activeTab === tab;
    
    return (
      <TouchableOpacity
        key={tab}
        style={[styles.tabButton, isActive && styles.activeTabButton]}
        onPress={() => setActiveTab(tab)}
        activeOpacity={0.7}
      >
        <View style={styles.tabButtonContent}>
          <MaterialIcons 
            name={icon as any} 
            size={20} 
            color={isActive ? COLORS.primary : COLORS.text.secondary} 
          />
          <Text style={[styles.tabButtonText, isActive && styles.activeTabButtonText]}>
            {label}
          </Text>
          {count !== undefined && count > 0 && (
            <View style={styles.tabBadge}>
              <Text style={styles.tabBadgeText}>{count}</Text>
            </View>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  const renderContent = () => {
    if (loading) {
      return (
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading team information...</Text>
        </View>
      );
    }

    if (!userTeam) {
      return (
        <View style={styles.emptyState}>
          <MaterialIcons name="group-off" size={64} color={COLORS.text.secondary} />
          <Text style={styles.emptyStateText}>No Team Assigned</Text>
          <Text style={styles.emptyStateSubtext}>
            Contact your admin to be assigned to a team
          </Text>
        </View>
      );
    }

    if (!user) {
      return (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>Authentication required</Text>
        </View>
      );
    }

    try {
      switch (activeTab) {
        case 'team':
          return (
            <TeamChatView
              team={userTeam}
              currentUser={user}
              teamMembers={[...teamMembers, {
                uid: user.uid,
                email: user.email || '',
                displayName: user.displayName || user.email?.split('@')[0] || 'You',
                role: 'worker', // This will be updated with actual role
                isOnline: true,
                lastActiveAt: new Date(),
                createdAt: new Date(),
                updatedAt: new Date(),
                status: 'active',
                permissions: []
              }]}
            />
          );
        case 'direct':
          return (
            <DirectMessagesView
              currentUser={user}
              teamMembers={teamMembers}
            />
          );
        case 'members':
          return (
            <TeamMembersList
              team={userTeam}
              teamMembers={teamMembers}
              currentUser={user}
              onStartDirectMessage={(member) => {
                try {
                  setActiveTab('direct');
                  // TODO: Navigate to specific direct message
                } catch (error) {
                  console.error('Error starting direct message:', error);
                  Alert.alert('Error', 'Failed to start direct message');
                }
              }}
            />
          );
        default:
          return (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>Unknown tab selected</Text>
            </View>
          );
      }
    } catch (error) {
      console.error('Error rendering messaging content:', error);
      return (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>Failed to load messaging content</Text>
        </View>
      );
    }
  };

  if (!visible) return null;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="none"
      onRequestClose={handleClose}
    >
      <View style={styles.modalOverlay}>
        <TouchableOpacity
          style={styles.modalBackdrop}
          activeOpacity={1}
          onPress={handleClose}
        />

        <Animated.View
          style={[
            styles.bottomSheet,
            {
              transform: [{ translateY: slideAnim }],
            },
          ]}
        >
          <SafeAreaView style={styles.sheetContainer}>
            {/* Header */}
            <View style={styles.header}>
              <View style={styles.sheetHandle} />
              <View style={styles.headerContent}>
                <View style={styles.headerLeft}>
                  <MaterialIcons name="group" size={24} color={COLORS.primary} />
                  <Text style={styles.headerTitle}>
                    {userTeam?.name || 'Team Chat'}
                  </Text>
                </View>
                <TouchableOpacity onPress={handleClose} style={styles.closeButton}>
                  <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
                </TouchableOpacity>
              </View>
            </View>

            {/* Tab Navigation */}
            <View style={styles.tabContainer}>
              {renderTabButton('team', 'group', 'Team Chat')}
              {renderTabButton('direct', 'person', 'Direct', teamMembers.length)}
              {renderTabButton('members', 'people', 'Members', teamMembers.length + 1)}
            </View>

            {/* Content */}
            <View style={styles.content}>
              {renderContent()}
            </View>
          </SafeAreaView>
        </Animated.View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalBackdrop: {
    flex: 1,
  },
  bottomSheet: {
    backgroundColor: COLORS.background.surface,
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    maxHeight: screenHeight * 0.9,
    minHeight: screenHeight * 0.7,
    ...SHADOWS.large,
  },
  sheetContainer: {
    flex: 1,
  },
  header: {
    paddingTop: SPACING.md,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  sheetHandle: {
    width: 40,
    height: 4,
    backgroundColor: COLORS.border.default,
    borderRadius: 2,
    alignSelf: 'center',
    marginBottom: SPACING.md,
  },
  headerContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  headerTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginLeft: SPACING.sm,
  },
  closeButton: {
    padding: SPACING.xs,
  },
  tabContainer: {
    flexDirection: 'row',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  tabButton: {
    flex: 1,
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.md,
    marginHorizontal: SPACING.xs,
  },
  activeTabButton: {
    backgroundColor: COLORS.primary + '15',
  },
  tabButtonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
  },
  tabButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  activeTabButtonText: {
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
  tabBadge: {
    position: 'absolute',
    top: -8,
    right: -8,
    backgroundColor: COLORS.error,
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  tabBadgeText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.bold,
  },
  content: {
    flex: 1,
  },
  loadingContainer: {
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
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  errorText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.error,
    textAlign: 'center',
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  emptyStateText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  emptyStateSubtext: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
});

export default TeamMessagingBottomSheet;
