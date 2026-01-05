import React from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { ManagedUser } from '../../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../../constants/Colors';
import UserRoleBadge from '../UserRoleBadge';
import UserStatusIndicator from '../UserStatusIndicator';

interface TeamMembersListProps {
  team: any;
  teamMembers: ManagedUser[];
  currentUser: any;
  onStartDirectMessage: (member: ManagedUser) => void;
}

const TeamMembersList: React.FC<TeamMembersListProps> = ({
  team,
  teamMembers,
  currentUser,
  onStartDirectMessage
}) => {
  // Include current user in the list
  const allMembers = [
    ...teamMembers,
    {
      uid: currentUser.uid,
      email: currentUser.email || '',
      displayName: currentUser.displayName || currentUser.email?.split('@')[0] || 'You',
      role: 'worker', // This should be updated with actual role
      isOnline: true,
      lastActiveAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
      status: 'active',
      permissions: []
    } as ManagedUser
  ];

  // Sort members: team leader first, then by online status, then alphabetically
  const sortedMembers = allMembers.sort((a, b) => {
    // Team leader first
    if (team.leaderId === a.uid) return -1;
    if (team.leaderId === b.uid) return 1;
    
    // Current user second (if not team leader)
    if (a.uid === currentUser.uid) return -1;
    if (b.uid === currentUser.uid) return 1;
    
    // Online users before offline
    if (a.isOnline && !b.isOnline) return -1;
    if (!a.isOnline && b.isOnline) return 1;
    
    // Alphabetical by name
    const nameA = a.displayName || a.email.split('@')[0];
    const nameB = b.displayName || b.email.split('@')[0];
    return nameA.localeCompare(nameB);
  });

  const renderMemberItem = ({ item }: { item: ManagedUser }) => {
    const isCurrentUser = item.uid === currentUser.uid;
    const isTeamLeader = item.uid === team.leaderId;
    const memberName = item.displayName || item.email.split('@')[0];

    return (
      <TouchableOpacity
        style={[
          styles.memberItem,
          isCurrentUser && styles.currentUserItem
        ]}
        onPress={() => !isCurrentUser && onStartDirectMessage(item)}
        disabled={isCurrentUser}
        activeOpacity={isCurrentUser ? 1 : 0.7}
      >
        <View style={styles.memberContent}>
          {/* Member Info */}
          <View style={styles.memberInfo}>
            <View style={styles.memberHeader}>
              <Text style={[
                styles.memberName,
                isCurrentUser && styles.currentUserName
              ]}>
                {isCurrentUser ? 'You' : memberName}
              </Text>
              {isTeamLeader && (
                <View style={styles.leaderBadge}>
                  <MaterialIcons name="star" size={16} color={COLORS.warning} />
                  <Text style={styles.leaderBadgeText}>Leader</Text>
                </View>
              )}
            </View>
            
            <View style={styles.memberMeta}>
              <UserRoleBadge role={item.role} size="small" />
              <Text style={styles.memberEmail}>{item.email}</Text>
            </View>
          </View>

          {/* Status and Actions */}
          <View style={styles.memberActions}>
            <UserStatusIndicator 
              isOnline={item.isOnline || false}
              lastActiveAt={item.lastActiveAt}
              size="medium"
            />
            
            {!isCurrentUser && (
              <TouchableOpacity
                style={styles.messageButton}
                onPress={() => onStartDirectMessage(item)}
                activeOpacity={0.7}
              >
                <MaterialIcons name="chat-bubble-outline" size={20} color={COLORS.primary} />
              </TouchableOpacity>
            )}
          </View>
        </View>
      </TouchableOpacity>
    );
  };

  const renderHeader = () => (
    <View style={styles.header}>
      <View style={styles.headerContent}>
        <MaterialIcons name="group" size={24} color={COLORS.primary} />
        <Text style={styles.headerTitle}>{team.name}</Text>
      </View>
      <Text style={styles.headerSubtitle}>
        {allMembers.length} {allMembers.length === 1 ? 'member' : 'members'}
      </Text>
      {team.description && (
        <Text style={styles.teamDescription}>{team.description}</Text>
      )}
    </View>
  );

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <MaterialIcons name="group-off" size={64} color={COLORS.text.secondary} />
      <Text style={styles.emptyStateText}>No Team Members</Text>
      <Text style={styles.emptyStateSubtext}>
        Contact your admin to add members to this team
      </Text>
    </View>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={sortedMembers}
        renderItem={renderMemberItem}
        keyExtractor={(item) => item.uid}
        ListHeaderComponent={renderHeader}
        ListEmptyComponent={renderEmptyState}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.surface,
  },
  listContent: {
    paddingHorizontal: SPACING.md,
    paddingBottom: SPACING.lg,
  },
  header: {
    paddingVertical: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
    marginBottom: SPACING.md,
  },
  headerContent: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  headerTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginLeft: SPACING.sm,
  },
  headerSubtitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  teamDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontStyle: 'italic',
  },
  memberItem: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  currentUserItem: {
    borderColor: COLORS.primary + '40',
    backgroundColor: COLORS.primary + '08',
  },
  memberContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  memberInfo: {
    flex: 1,
    marginRight: SPACING.md,
  },
  memberHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  memberName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginRight: SPACING.sm,
  },
  currentUserName: {
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
  leaderBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.warning + '20',
    paddingHorizontal: SPACING.xs,
    paddingVertical: 2,
    borderRadius: RADIUS.sm,
  },
  leaderBadgeText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.warning,
    fontWeight: TYPOGRAPHY.weights.medium,
    marginLeft: 2,
  },
  memberMeta: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  memberEmail: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.sm,
  },
  memberActions: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  messageButton: {
    backgroundColor: COLORS.primary + '15',
    borderRadius: RADIUS.full,
    width: 36,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: SPACING.sm,
  },
  emptyState: {
    alignItems: 'center',
    padding: SPACING.xl,
    marginTop: SPACING.xl,
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

export default TeamMembersList;
