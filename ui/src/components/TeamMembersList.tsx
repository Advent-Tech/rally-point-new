import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  StyleSheet
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { UserManagementService } from '../services/UserManagementService';
import { TeamMember, Team } from '../types/userManagement';
import UserRoleBadge from './UserRoleBadge';
import { COLORS } from '../constants/Colors';

interface TeamMembersListProps {
  team: Team;
  onPromoteMember?: (memberId: string, teamId: string) => void;
  onRemoveMember?: (memberId: string, teamId: string) => void;
  showActions?: boolean;
  currentUserId?: string;
}

const TeamMembersList: React.FC<TeamMembersListProps> = ({
  team,
  onPromoteMember,
  onRemoveMember,
  showActions = true,
  currentUserId
}) => {
  const [members, setMembers] = useState<TeamMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadTeamMembers();
  }, [team.id]);

  const loadTeamMembers = async () => {
    try {
      setLoading(true);
      const response = await UserManagementService.getTeamMembers(team.id);
      
      if (response.success && response.data) {
        setMembers(response.data);
      } else {
        console.error('Failed to load team members:', response.error);
      }
    } catch (error) {
      console.error('Error loading team members:', error);
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadTeamMembers();
    setRefreshing(false);
  };

  const handlePromoteMember = (member: TeamMember) => {
    if (!onPromoteMember) return;

    Alert.alert(
      'Promote to Team Leader',
      `Are you sure you want to promote ${member.name} to team leader? This will demote the current leader to a worker.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Promote',
          style: 'default',
          onPress: () => onPromoteMember(member.uid, team.id)
        }
      ]
    );
  };

  const handleRemoveMember = (member: TeamMember) => {
    if (!onRemoveMember) return;

    Alert.alert(
      'Remove Team Member',
      `Are you sure you want to remove ${member.name} from the team?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: () => onRemoveMember(member.uid, team.id)
        }
      ]
    );
  };

  const renderMember = ({ item: member }: { item: TeamMember }) => (
    <View style={styles.memberCard}>
      <View style={styles.memberInfo}>
        <View style={styles.memberHeader}>
          <Text style={styles.memberName}>{member.name}</Text>
          {member.isOnline && (
            <View style={styles.onlineIndicator} />
          )}
        </View>
        
        <Text style={styles.memberEmail}>{member.email}</Text>
        
        <View style={styles.memberMeta}>
          <UserRoleBadge role={member.role} size="small" />
          <Text style={styles.joinedDate}>
            Joined: {member.joinedAt.toLocaleDateString()}
          </Text>
        </View>
        
        <Text style={styles.lastActive}>
          Last active: {member.lastActiveAt.toLocaleDateString()}
        </Text>
      </View>

      {showActions && currentUserId !== member.uid && (
        <View style={styles.memberActions}>
          {member.role !== 'team_leader' && onPromoteMember && (
            <TouchableOpacity
              style={styles.promoteButton}
              onPress={() => handlePromoteMember(member)}
            >
              <MaterialIcons name="trending-up" size={16} color={COLORS.secondary} />
              <Text style={styles.promoteButtonText}>Promote</Text>
            </TouchableOpacity>
          )}
          
          {onRemoveMember && (
            <TouchableOpacity
              style={styles.removeButton}
              onPress={() => handleRemoveMember(member)}
            >
              <MaterialIcons name="remove-circle-outline" size={16} color="#dc2626" />
              <Text style={styles.removeButtonText}>Remove</Text>
            </TouchableOpacity>
          )}
        </View>
      )}
    </View>
  );

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <MaterialIcons name="people-outline" size={64} color={COLORS.textSecondary} />
      <Text style={styles.emptyStateText}>No team members</Text>
      <Text style={styles.emptyStateSubtext}>
        Team members will appear here when assigned
      </Text>
    </View>
  );

  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={styles.headerTitle}>Team Members ({members.length})</Text>
      {team.leaderName && (
        <Text style={styles.headerSubtitle}>
          Led by {team.leaderName}
        </Text>
      )}
    </View>
  );

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={COLORS.primary} />
        <Text style={styles.loadingText}>Loading team members...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={members}
        renderItem={renderMember}
        keyExtractor={(item) => item.uid}
        ListHeaderComponent={renderHeader}
        ListEmptyComponent={renderEmptyState}
        refreshing={refreshing}
        onRefresh={onRefresh}
        contentContainerStyle={styles.listContent}
        showsVerticalScrollIndicator={false}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: COLORS.textSecondary,
  },
  listContent: {
    padding: 16,
  },
  header: {
    marginBottom: 16,
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: COLORS.text,
  },
  headerSubtitle: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 4,
  },
  memberCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    flexDirection: 'row',
    alignItems: 'center',
  },
  memberInfo: {
    flex: 1,
  },
  memberHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 4,
  },
  memberName: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  onlineIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#10b981',
  },
  memberEmail: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginBottom: 8,
  },
  memberMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  joinedDate: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  lastActive: {
    fontSize: 11,
    color: COLORS.textSecondary,
  },
  memberActions: {
    alignItems: 'center',
    gap: 8,
  },
  promoteButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
    paddingHorizontal: 8,
    backgroundColor: '#fef3c7',
    borderRadius: 6,
    gap: 4,
  },
  promoteButtonText: {
    fontSize: 12,
    color: COLORS.secondary,
    fontWeight: '500',
  },
  removeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
    paddingHorizontal: 8,
    backgroundColor: '#fee2e2',
    borderRadius: 6,
    gap: 4,
  },
  removeButtonText: {
    fontSize: 12,
    color: '#dc2626',
    fontWeight: '500',
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
  },
  emptyStateText: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginTop: 16,
  },
  emptyStateSubtext: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 8,
    textAlign: 'center',
  },
});

export default TeamMembersList;
