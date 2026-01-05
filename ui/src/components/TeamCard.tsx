import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { MaterialIcons, FontAwesome } from '@expo/vector-icons';
import { Team } from '../types/userManagement';
import { COLORS } from '../constants/Colors';

interface TeamCardProps {
  team: Team;
  onPress?: (team: Team) => void;
  onEditTeam?: (team: Team) => void;
  onViewMembers?: (team: Team) => void;
  onAssignTerritory?: (team: Team) => void;
  showActions?: boolean;
}

const TeamCard: React.FC<TeamCardProps> = ({
  team,
  onPress,
  onEditTeam,
  onViewMembers,
  onAssignTerritory,
  showActions = true
}) => {
  return (
    <TouchableOpacity
      style={[styles.card, { borderLeftColor: team.color || COLORS.primary }]}
      onPress={() => onPress?.(team)}
      activeOpacity={0.7}
    >
      <View style={styles.cardHeader}>
        <View style={styles.teamInfo}>
          <Text style={styles.teamName}>{team.name}</Text>
          {team.description && (
            <Text style={styles.teamDescription}>{team.description}</Text>
          )}
        </View>
        
        <View style={styles.teamStats}>
          <View style={styles.statItem}>
            <MaterialIcons name="people" size={16} color={COLORS.primary} />
            <Text style={styles.statText}>{team.memberCount}</Text>
          </View>
          {!team.isActive && (
            <View style={styles.inactiveBadge}>
              <Text style={styles.inactiveBadgeText}>INACTIVE</Text>
            </View>
          )}
        </View>
      </View>

      {team.leaderId && (
        <View style={styles.leaderSection}>
          <MaterialIcons name="person" size={16} color={COLORS.secondary} />
          <Text style={styles.leaderText}>
            Leader: {team.leaderName || 'Unknown'}
          </Text>
          {team.leaderEmail && (
            <Text style={styles.leaderEmail}>({team.leaderEmail})</Text>
          )}
        </View>
      )}

      {team.territory && (
        <View style={styles.territorySection}>
          <MaterialIcons name="map" size={16} color={COLORS.info} />
          <Text style={styles.territoryText}>
            Territory: {team.territory.name}
          </Text>
        </View>
      )}

      <View style={styles.cardFooter}>
        <Text style={styles.createdDate}>
          Created: {team.createdAt.toLocaleDateString()}
        </Text>
        
        {showActions && (
          <View style={styles.actionButtons}>
            {onViewMembers && (
              <TouchableOpacity
                style={styles.actionButton}
                onPress={() => onViewMembers(team)}
              >
                <MaterialIcons name="group" size={18} color={COLORS.primary} />
              </TouchableOpacity>
            )}
            
            {onAssignTerritory && (
              <TouchableOpacity
                style={styles.actionButton}
                onPress={() => onAssignTerritory(team)}
              >
                <MaterialIcons name="map" size={18} color={COLORS.info} />
              </TouchableOpacity>
            )}
            
            {onEditTeam && (
              <TouchableOpacity
                style={styles.actionButton}
                onPress={() => onEditTeam(team)}
              >
                <MaterialIcons name="edit" size={18} color={COLORS.secondary} />
              </TouchableOpacity>
            )}
          </View>
        )}
      </View>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginVertical: 6,
    marginHorizontal: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    borderLeftWidth: 4,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  teamInfo: {
    flex: 1,
    marginRight: 12,
  },
  teamName: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 4,
  },
  teamDescription: {
    fontSize: 14,
    color: COLORS.textSecondary,
    lineHeight: 20,
  },
  teamStats: {
    alignItems: 'flex-end',
    gap: 8,
  },
  statItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  statText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.primary,
  },
  inactiveBadge: {
    backgroundColor: '#fee2e2',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
  },
  inactiveBadgeText: {
    fontSize: 10,
    fontWeight: '600',
    color: '#dc2626',
  },
  leaderSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 8,
    paddingVertical: 8,
    paddingHorizontal: 12,
    backgroundColor: '#fef3c7',
    borderRadius: 8,
  },
  leaderText: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.secondary,
    flex: 1,
  },
  leaderEmail: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  territorySection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 8,
    paddingVertical: 8,
    paddingHorizontal: 12,
    backgroundColor: '#e0f2fe',
    borderRadius: 8,
  },
  territoryText: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.info,
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 8,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
  },
  createdDate: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  actionButtons: {
    flexDirection: 'row',
    gap: 8,
  },
  actionButton: {
    padding: 8,
    borderRadius: 6,
    backgroundColor: '#f1f5f9',
  },
});

export default TeamCard;
