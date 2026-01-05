import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  Modal,
  FlatList,
  StyleSheet,
  TextInput
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { Team } from '../types/userManagement';
import { COLORS } from '../constants/Colors';

interface TeamAssignmentDropdownProps {
  teams: Team[];
  selectedTeamId?: string;
  placeholder?: string;
  onSelect: (team: Team | null) => void;
  disabled?: boolean;
  showCreateOption?: boolean;
  onCreateTeam?: () => void;
}

const TeamAssignmentDropdown: React.FC<TeamAssignmentDropdownProps> = ({
  teams,
  selectedTeamId,
  placeholder = 'Select a team...',
  onSelect,
  disabled = false,
  showCreateOption = false,
  onCreateTeam
}) => {
  const [modalVisible, setModalVisible] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const selectedTeam = teams.find(team => team.id === selectedTeamId);
  
  const filteredTeams = teams.filter(team =>
    team.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (team.description && team.description.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  const handleSelect = (team: Team | null) => {
    onSelect(team);
    setModalVisible(false);
    setSearchQuery('');
  };

  const renderTeamItem = ({ item: team }: { item: Team }) => (
    <TouchableOpacity
      style={[
        styles.teamItem,
        selectedTeamId === team.id && styles.selectedTeamItem
      ]}
      onPress={() => handleSelect(team)}
    >
      <View style={styles.teamInfo}>
        <View style={styles.teamHeader}>
          <Text style={styles.teamName}>{team.name}</Text>
          <View style={[styles.colorIndicator, { backgroundColor: team.color || COLORS.primary }]} />
        </View>
        
        {team.description && (
          <Text style={styles.teamDescription} numberOfLines={2}>
            {team.description}
          </Text>
        )}
        
        <View style={styles.teamMeta}>
          <View style={styles.memberCount}>
            <MaterialIcons name="people" size={14} color={COLORS.textSecondary} />
            <Text style={styles.memberCountText}>{team.memberCount} members</Text>
          </View>
          
          {team.leaderName && (
            <Text style={styles.leaderText}>Led by {team.leaderName}</Text>
          )}
        </View>
      </View>
      
      {selectedTeamId === team.id && (
        <MaterialIcons name="check" size={24} color={COLORS.primary} />
      )}
    </TouchableOpacity>
  );

  const renderCreateOption = () => {
    if (!showCreateOption || !onCreateTeam) return null;
    
    return (
      <TouchableOpacity
        style={styles.createOption}
        onPress={() => {
          setModalVisible(false);
          onCreateTeam();
        }}
      >
        <MaterialIcons name="add-circle-outline" size={24} color={COLORS.primary} />
        <Text style={styles.createOptionText}>Create New Team</Text>
      </TouchableOpacity>
    );
  };

  return (
    <>
      <TouchableOpacity
        style={[
          styles.dropdown,
          disabled && styles.disabledDropdown
        ]}
        onPress={() => !disabled && setModalVisible(true)}
        disabled={disabled}
      >
        <View style={styles.dropdownContent}>
          {selectedTeam ? (
            <View style={styles.selectedTeamDisplay}>
              <View style={[styles.colorIndicator, { backgroundColor: selectedTeam.color || COLORS.primary }]} />
              <Text style={styles.selectedTeamText}>{selectedTeam.name}</Text>
            </View>
          ) : (
            <Text style={styles.placeholderText}>{placeholder}</Text>
          )}
        </View>
        
        <MaterialIcons
          name={modalVisible ? "keyboard-arrow-up" : "keyboard-arrow-down"}
          size={24}
          color={disabled ? COLORS.textSecondary : COLORS.text}
        />
      </TouchableOpacity>

      <Modal
        visible={modalVisible}
        transparent
        animationType="slide"
        onRequestClose={() => setModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Select Team</Text>
              <TouchableOpacity
                style={styles.closeButton}
                onPress={() => setModalVisible(false)}
              >
                <MaterialIcons name="close" size={24} color={COLORS.text} />
              </TouchableOpacity>
            </View>
            
            <View style={styles.searchContainer}>
              <MaterialIcons name="search" size={20} color={COLORS.textSecondary} />
              <TextInput
                style={styles.searchInput}
                placeholder="Search teams..."
                value={searchQuery}
                onChangeText={setSearchQuery}
                placeholderTextColor={COLORS.textSecondary}
              />
            </View>
            
            {selectedTeamId && (
              <TouchableOpacity
                style={styles.clearOption}
                onPress={() => handleSelect(null)}
              >
                <MaterialIcons name="clear" size={20} color="#dc2626" />
                <Text style={styles.clearOptionText}>Clear Selection</Text>
              </TouchableOpacity>
            )}
            
            <FlatList
              data={filteredTeams}
              renderItem={renderTeamItem}
              keyExtractor={(item) => item.id}
              ListHeaderComponent={renderCreateOption}
              ListEmptyComponent={
                <View style={styles.emptyState}>
                  <MaterialIcons name="group-off" size={48} color={COLORS.textSecondary} />
                  <Text style={styles.emptyStateText}>No teams found</Text>
                </View>
              }
              showsVerticalScrollIndicator={false}
              style={styles.teamsList}
            />
          </View>
        </View>
      </Modal>
    </>
  );
};

const styles = StyleSheet.create({
  dropdown: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 12,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  disabledDropdown: {
    opacity: 0.5,
  },
  dropdownContent: {
    flex: 1,
  },
  selectedTeamDisplay: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  selectedTeamText: {
    fontSize: 16,
    color: COLORS.text,
    fontWeight: '500',
  },
  placeholderText: {
    fontSize: 16,
    color: COLORS.textSecondary,
  },
  colorIndicator: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: 'white',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '80%',
    paddingTop: 20,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
  },
  closeButton: {
    padding: 4,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    margin: 20,
    marginBottom: 12,
  },
  searchInput: {
    flex: 1,
    marginLeft: 8,
    fontSize: 16,
    color: COLORS.text,
  },
  clearOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 12,
    gap: 8,
  },
  clearOptionText: {
    fontSize: 16,
    color: '#dc2626',
    fontWeight: '500',
  },
  createOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
    gap: 12,
  },
  createOptionText: {
    fontSize: 16,
    color: COLORS.primary,
    fontWeight: '500',
  },
  teamsList: {
    flex: 1,
  },
  teamItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  selectedTeamItem: {
    backgroundColor: '#f0f9ff',
  },
  teamInfo: {
    flex: 1,
  },
  teamHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  teamName: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    flex: 1,
  },
  teamDescription: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginBottom: 8,
    lineHeight: 20,
  },
  teamMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  memberCount: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  memberCountText: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  leaderText: {
    fontSize: 12,
    color: COLORS.primary,
    fontWeight: '500',
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 48,
  },
  emptyStateText: {
    fontSize: 16,
    color: COLORS.textSecondary,
    marginTop: 12,
  },
});

export default TeamAssignmentDropdown;
