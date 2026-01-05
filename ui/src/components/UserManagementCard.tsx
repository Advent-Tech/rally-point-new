import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { ManagedUser, UserRole } from '../types/userManagement';
import { COLORS } from '../constants/Colors';

interface UserManagementCardProps {
  user: ManagedUser;
  isSelected: boolean;
  onSelect: (userId: string) => void;
  onEditRole: (user: ManagedUser) => void;
  onPromoteToLeader?: (userId: string, teamId: string) => void;
  showPromoteButton?: boolean;
}

const UserManagementCard: React.FC<UserManagementCardProps> = ({
  user,
  isSelected,
  onSelect,
  onEditRole,
  onPromoteToLeader,
  showPromoteButton = false
}) => {
  const getRoleColor = (role: UserRole) => {
    switch (role) {
      case 'admin': return '#dc2626';
      case 'team_leader': return '#d97706';
      case 'worker': return '#059669';
      default: return '#6b7280';
    }
  };

  const getRoleBadge = (role: UserRole) => {
    const color = getRoleColor(role);
    const label = role.replace('_', ' ').toUpperCase();
    
    return (
      <View style={[styles.roleBadge, { backgroundColor: color }]}>
        <Text style={styles.roleBadgeText}>{label}</Text>
      </View>
    );
  };

  return (
    <View style={[styles.card, isSelected && styles.selectedCard]}>
      <View style={styles.cardHeader}>
        <TouchableOpacity
          style={styles.checkbox}
          onPress={() => onSelect(user.uid)}
        >
          <MaterialIcons
            name={isSelected ? "check-box" : "check-box-outline-blank"}
            size={24}
            color={isSelected ? COLORS.primary : COLORS.textSecondary}
          />
        </TouchableOpacity>
        
        <View style={styles.userInfo}>
          <View style={styles.userNameRow}>
            <Text style={styles.userName}>{user.displayName}</Text>
            {user.isOnline && (
              <View style={styles.onlineIndicator} />
            )}
          </View>
          <Text style={styles.userEmail}>{user.email}</Text>
          {user.phone && (
            <Text style={styles.userPhone}>{user.phone}</Text>
          )}
          {user.teamName && (
            <Text style={styles.userTeam}>Team: {user.teamName}</Text>
          )}
          {user.teamLeaderName && (
            <Text style={styles.teamLeader}>Leader: {user.teamLeaderName}</Text>
          )}
        </View>
        
        <View style={styles.userActions}>
          {getRoleBadge(user.role)}
          <TouchableOpacity
            style={styles.actionIcon}
            onPress={() => onEditRole(user)}
          >
            <MaterialIcons name="edit" size={20} color={COLORS.primary} />
          </TouchableOpacity>
        </View>
      </View>
      
      {showPromoteButton && user.teamId && user.role !== 'team_leader' && onPromoteToLeader && (
        <TouchableOpacity
          style={styles.promoteButton}
          onPress={() => onPromoteToLeader(user.uid, user.teamId)}
        >
          <MaterialIcons name="trending-up" size={16} color={COLORS.secondary} />
          <Text style={styles.promoteButtonText}>Promote to Team Leader</Text>
        </TouchableOpacity>
      )}
      
      <View style={styles.cardFooter}>
        <Text style={styles.lastActive}>
          Last active: {user.lastActiveAt.toLocaleDateString()}
        </Text>
        <Text style={styles.joinDate}>
          Joined: {user.createdAt.toLocaleDateString()}
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginVertical: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  selectedCard: {
    borderColor: COLORS.primary,
    backgroundColor: '#f0f9ff',
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    marginRight: 12,
  },
  userInfo: {
    flex: 1,
  },
  userNameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  userName: {
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
  userEmail: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 2,
  },
  userPhone: {
    fontSize: 12,
    color: COLORS.textSecondary,
    marginTop: 2,
  },
  userTeam: {
    fontSize: 12,
    color: COLORS.primary,
    marginTop: 4,
    fontWeight: '500',
  },
  teamLeader: {
    fontSize: 12,
    color: COLORS.secondary,
    marginTop: 2,
    fontWeight: '500',
  },
  userActions: {
    alignItems: 'center',
    gap: 8,
  },
  actionIcon: {
    padding: 8,
  },
  roleBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  roleBadgeText: {
    color: 'white',
    fontSize: 10,
    fontWeight: '600',
  },
  promoteButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 12,
    paddingVertical: 8,
    paddingHorizontal: 12,
    backgroundColor: '#fef3c7',
    borderRadius: 6,
    gap: 4,
  },
  promoteButtonText: {
    fontSize: 12,
    color: COLORS.secondary,
    fontWeight: '500',
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
  },
  lastActive: {
    fontSize: 11,
    color: COLORS.textSecondary,
  },
  joinDate: {
    fontSize: 11,
    color: COLORS.textSecondary,
  },
});

export default UserManagementCard;
