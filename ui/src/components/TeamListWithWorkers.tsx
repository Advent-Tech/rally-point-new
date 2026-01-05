import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  FlatList,
  Alert
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { TeamService } from '../services/TeamService';

interface Worker {
  uid: string;
  displayName?: string;
  email: string;
  role: string;
  teamId?: string;
  teamName?: string;
  isOnline?: boolean;
  lastActiveAt?: any;
}

interface Team {
  teamId: string;
  teamName: string;
  leaderId: string;
  leaderName: string;
  leaderEmail: string;
  workerCount: number;
  createdAt: Date;
  updatedAt: Date;
  workers?: Worker[];
}

interface TeamListWithWorkersProps {
  teams: Team[];
  onRefresh?: () => void;
  onAddWorker?: (team: Team) => void;
  onRemoveWorker?: (worker: Worker, team: Team) => void;
  onEditTeam?: (team: Team) => void;
  onDeleteTeam?: (team: Team) => void;
}

const TeamListWithWorkers: React.FC<TeamListWithWorkersProps> = ({
  teams,
  onRefresh,
  onAddWorker,
  onRemoveWorker,
  onEditTeam,
  onDeleteTeam
}) => {
  const [expandedTeams, setExpandedTeams] = useState<Set<string>>(new Set());
  const [loadingWorkers, setLoadingWorkers] = useState<Set<string>>(new Set());
  const [teamWorkers, setTeamWorkers] = useState<Map<string, Worker[]>>(new Map());

  const toggleTeamExpansion = async (teamId: string) => {
    const newExpanded = new Set(expandedTeams);
    
    if (newExpanded.has(teamId)) {
      // Collapse
      newExpanded.delete(teamId);
      setExpandedTeams(newExpanded);
    } else {
      // Expand and load workers if not already loaded
      newExpanded.add(teamId);
      setExpandedTeams(newExpanded);

      if (!teamWorkers.has(teamId)) {
        await loadTeamWorkers(teamId);
      }
    }
  };

  const loadTeamWorkers = async (teamId: string) => {
    setLoadingWorkers(prev => new Set(prev).add(teamId));
    
    try {
      const result = await TeamService.getTeamWorkers(teamId);
      if (result.success && result.workers) {
        setTeamWorkers(prev => new Map(prev).set(teamId, result.workers || []));
      }
    } catch (error) {
      console.error('Error loading team workers:', error);
      Alert.alert('Error', 'Failed to load team workers');
    } finally {
      setLoadingWorkers(prev => {
        const newSet = new Set(prev);
        newSet.delete(teamId);
        return newSet;
      });
    }
  };

  const handleRemoveWorker = (worker: Worker, team: Team) => {
    Alert.alert(
      'Remove Worker',
      `Remove ${worker.displayName || worker.email} from ${team.teamName}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: async () => {
            if (onRemoveWorker) {
              onRemoveWorker(worker, team);
              // Reload workers after removal
              await loadTeamWorkers(team.teamId);
            }
          }
        }
      ]
    );
  };

  const renderWorkerItem = (worker: Worker, team: Team) => (
    <View key={worker.uid} style={styles.workerItem}>
      <View style={styles.workerAvatar}>
        <MaterialIcons name="person" size={20} color={COLORS.primary} />
      </View>
      
      <View style={styles.workerInfo}>
        <Text style={styles.workerName}>{worker.displayName || worker.email}</Text>
        <Text style={styles.workerEmail}>{worker.email}</Text>
        <View style={styles.workerMeta}>
          <View style={[styles.roleBadge, { backgroundColor: `${COLORS.primary}15` }]}>
            <Text style={[styles.roleText, { color: COLORS.primary }]}>
              {worker.role === 'team_leader' ? 'Team Leader' : 'Worker'}
            </Text>
          </View>
          {worker.isOnline && (
            <View style={styles.onlineBadge}>
              <View style={styles.onlineDot} />
              <Text style={styles.onlineText}>Online</Text>
            </View>
          )}
        </View>
      </View>

      {onRemoveWorker && worker.role !== 'team_leader' && (
        <TouchableOpacity
          style={styles.removeButton}
          onPress={() => handleRemoveWorker(worker, team)}
        >
          <MaterialIcons name="remove-circle-outline" size={24} color={COLORS.error} />
        </TouchableOpacity>
      )}
    </View>
  );

  const renderTeamCard = ({ item: team }: { item: Team }) => {
    const isExpanded = expandedTeams.has(team.teamId);
    const workers = teamWorkers.get(team.teamId) || [];
    const isLoading = loadingWorkers.has(team.teamId);

    return (
      <View style={styles.teamCard}>
        {/* Team Header */}
        <TouchableOpacity
          style={styles.teamHeader}
          onPress={() => toggleTeamExpansion(team.teamId)}
          activeOpacity={0.7}
        >
          <View style={styles.teamIconContainer}>
            <MaterialIcons name="groups" size={32} color={COLORS.primary} />
          </View>

          <View style={styles.teamInfo}>
            <Text style={styles.teamName}>{team.teamName}</Text>
            <Text style={styles.teamLeader}>
              <MaterialIcons name="person" size={14} color={COLORS.text.secondary} />
              {' '}{team.leaderName}
            </Text>
            <Text style={styles.teamMemberCount}>
              {team.workerCount} {team.workerCount === 1 ? 'member' : 'members'}
            </Text>
          </View>

          <View style={styles.teamActions}>
            <MaterialIcons
              name={isExpanded ? 'expand-less' : 'expand-more'}
              size={24}
              color={COLORS.text.secondary}
            />
          </View>
        </TouchableOpacity>

        {/* Expanded Content */}
        {isExpanded && (
          <View style={styles.expandedContent}>
            {/* Action Buttons */}
            <View style={styles.actionButtons}>
              {onAddWorker && (
                <TouchableOpacity
                  style={[styles.actionButton, styles.addButton]}
                  onPress={() => onAddWorker(team)}
                >
                  <MaterialIcons name="person-add" size={18} color={COLORS.white} />
                  <Text style={styles.actionButtonText}>Add Worker</Text>
                </TouchableOpacity>
              )}
              
              {onEditTeam && (
                <TouchableOpacity
                  style={[styles.actionButton, styles.editButton]}
                  onPress={() => onEditTeam(team)}
                >
                  <MaterialIcons name="edit" size={18} color={COLORS.primary} />
                  <Text style={[styles.actionButtonText, { color: COLORS.primary }]}>Edit</Text>
                </TouchableOpacity>
              )}
            </View>

            {/* Workers List */}
            <View style={styles.workersSection}>
              <Text style={styles.sectionTitle}>Team Members</Text>
              
              {isLoading ? (
                <View style={styles.loadingContainer}>
                  <ActivityIndicator size="small" color={COLORS.primary} />
                  <Text style={styles.loadingText}>Loading members...</Text>
                </View>
              ) : workers.length === 0 ? (
                <View style={styles.emptyContainer}>
                  <MaterialIcons name="people-outline" size={48} color={COLORS.text.disabled} />
                  <Text style={styles.emptyText}>No workers in this team</Text>
                  <Text style={styles.emptySubtext}>Add workers to get started</Text>
                </View>
              ) : (
                <View style={styles.workersList}>
                  {workers.map(worker => renderWorkerItem(worker, team))}
                </View>
              )}
            </View>
          </View>
        )}
      </View>
    );
  };

  return (
    <FlatList
      data={teams}
      renderItem={renderTeamCard}
      keyExtractor={(item) => item.teamId}
      contentContainerStyle={styles.listContainer}
      showsVerticalScrollIndicator={false}
      ListEmptyComponent={
        <View style={styles.emptyListContainer}>
          <MaterialIcons name="groups" size={64} color={COLORS.text.disabled} />
          <Text style={styles.emptyListText}>No teams found</Text>
          <Text style={styles.emptyListSubtext}>Create a team to get started</Text>
        </View>
      }
    />
  );
};

const styles = StyleSheet.create({
  listContainer: {
    padding: SPACING.md,
  },
  teamCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.medium,
  },
  teamHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
  },
  teamIconContainer: {
    width: 56,
    height: 56,
    borderRadius: RADIUS.full,
    backgroundColor: `${COLORS.primary}15`,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  teamInfo: {
    flex: 1,
  },
  teamName: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  teamLeader: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  teamMemberCount: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
  teamActions: {
    padding: SPACING.xs,
  },
  expandedContent: {
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
    padding: SPACING.md,
  },
  actionButtons: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginBottom: SPACING.md,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.md,
    gap: SPACING.xs,
  },
  addButton: {
    backgroundColor: COLORS.primary,
  },
  editButton: {
    backgroundColor: `${COLORS.primary}15`,
  },
  actionButtonText: {
    ...TYPOGRAPHY.button,
    color: COLORS.white,
  },
  workersSection: {
    marginTop: SPACING.sm,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h4,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  workersList: {
    gap: SPACING.sm,
  },
  workerItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.sm,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
  },
  workerAvatar: {
    width: 40,
    height: 40,
    borderRadius: RADIUS.full,
    backgroundColor: `${COLORS.primary}10`,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.sm,
  },
  workerInfo: {
    flex: 1,
  },
  workerName: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginBottom: 2,
  },
  workerEmail: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  workerMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  roleBadge: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: 2,
    borderRadius: RADIUS.sm,
  },
  roleText: {
    ...TYPOGRAPHY.caption,
    fontSize: 10,
    fontWeight: '600',
  },
  onlineBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  onlineDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: COLORS.success,
  },
  onlineText: {
    ...TYPOGRAPHY.caption,
    fontSize: 10,
    color: COLORS.success,
  },
  removeButton: {
    padding: SPACING.xs,
  },
  loadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.lg,
    gap: SPACING.sm,
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
  },
  emptyContainer: {
    alignItems: 'center',
    padding: SPACING.xl,
  },
  emptyText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
  },
  emptySubtext: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.disabled,
    marginTop: SPACING.xs,
  },
  emptyListContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.xl,
    marginTop: SPACING.xl,
  },
  emptyListText: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  emptyListSubtext: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.disabled,
    marginTop: SPACING.xs,
  },
});

export default TeamListWithWorkers;

