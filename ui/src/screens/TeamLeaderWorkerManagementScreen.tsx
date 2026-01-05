import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  StatusBar,
  Platform,
  Alert,
  RefreshControl,
  TextInput,
  Clipboard,
  Share,
  Modal,
  ActivityIndicator,
  Animated,
} from 'react-native';
import { MaterialIcons, Feather } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import TeamServiceBackend, { Team } from '../services/TeamServiceBackend';
import { TerritoryServiceBackendInstance, Territory as BackendTerritory } from '../services/TerritoryServiceBackend';
import { ManagedUser } from '../types/userManagement';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import Header from '../components/Header';

interface TeamLeaderWorkerManagementScreenProps {
  navigation: any;
}

const TeamLeaderWorkerManagementScreen: React.FC<TeamLeaderWorkerManagementScreenProps> = ({ navigation }) => {
  const { user, refreshUserData } = useAuth();
  const teamId = user?.team_id || (user as any)?.teamId || (user as any)?.teamID || null;
  const [workers, setWorkers] = useState<ManagedUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [showCreateTeam, setShowCreateTeam] = useState(false);
  const [teamName, setTeamName] = useState('');
  const [creatingTeam, setCreatingTeam] = useState(false);
  const [inviteLink, setInviteLink] = useState('');
  const [hasTeam, setHasTeam] = useState(false); // Local state to force re-render

  // Worker action states
  const [selectedWorker, setSelectedWorker] = useState<ManagedUser | null>(null);
  const [showWorkerActionsModal, setShowWorkerActionsModal] = useState(false);
  const [removingWorker, setRemovingWorker] = useState(false);

  // Territory assignment states
  const [availableTerritories, setAvailableTerritories] = useState<BackendTerritory[]>([]);
  const [showTerritoryPicker, setShowTerritoryPicker] = useState(false);
  const [selectedTerritory, setSelectedTerritory] = useState<BackendTerritory | null>(null);
  const [loadingTerritories, setLoadingTerritories] = useState(false);
  const [assigningTerritory, setAssigningTerritory] = useState(false);

  // Map of workerId -> assigned territories
  const [workerTerritories, setWorkerTerritories] = useState<Record<string, BackendTerritory[]>>({});

  // Invite link expand/collapse state
  const [inviteLinkExpanded, setInviteLinkExpanded] = useState(false);

  // Load workers from backend
  useEffect(() => {
    const init = async () => {
      console.log('🔍 TeamLeaderWorkerManagement - init');
      console.log('   teamId (normalized):', teamId);
      if (teamId) {
        setHasTeam(true);
        setShowCreateTeam(false);
        generateInviteLink();
        await loadWorkers();
      } else {
        setHasTeam(false);
        setShowCreateTeam(true);
        setLoading(false);
      }
    };
    init();
  }, [teamId]);

  const loadWorkers = async () => {
    try {
      setLoading(true);
      if (!teamId) {
        setWorkers([]);
        setLoading(false);
        return;
      }
      const members = await TeamServiceBackend.getTeamMembers(teamId);
      // Exclude the team leader and ensure only worker roles are listed
      const filtered = members.filter(m => m.uid !== user?.id && String(m.role).toLowerCase() === 'worker');
      setWorkers(filtered);
      // Load each worker's assigned territories
      await fetchWorkerTerritories(filtered);
    } catch (err) {
      console.error('❌ Error loading team members from backend:', err);
      setWorkers([]);
    } finally {
      setLoading(false);
    }
  };

  const generateInviteLink = () => {
    const id = teamId;
    const name = (user as any)?.teamName || (user as any)?.team_name || '';
    if (id) {
      const link = `rallypoint://team/${id}`;
      setInviteLink(link);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadWorkers();
    setRefreshing(false);
  };

  const handleWorkerPress = (worker: ManagedUser) => {
    console.log('Worker pressed:', worker);
    setSelectedWorker(worker);
    setShowWorkerActionsModal(true);
  };

  const handleMessageWorker = async (worker: ManagedUser) => {
    console.log('📧 Message worker:', worker.displayName);
    setShowWorkerActionsModal(false);

    try {
      // Import MessagingService dynamically
      const { MessagingService } = await import('../services/MessagingService');

      if (!user?.id || !user?.display_name || !user?.role) {
        Alert.alert('Error', 'User not authenticated');
        return;
      }

      console.log('🔄 Creating or getting conversation with worker:', worker.uid);

      // Create or get existing conversation
      const conversationId = await MessagingService.getOrCreateDirectConversation(
        user.id,
        user.display_name,
        user.role,
        worker.uid,
        worker.displayName,
        worker.role
      );

      console.log('✅ Conversation ID:', conversationId);

      // Navigate to Chat screen
      navigation.navigate('Chat', {
        conversationId,
        recipientId: worker.uid,
        recipientName: worker.displayName,
        recipientRole: worker.role,
        isGroup: false,
      });
    } catch (error) {
      console.error('❌ Error opening chat:', error);
      Alert.alert('Error', 'Failed to open chat. Please try again.');
    }
  };

  // Load available territories
  const loadAvailableTerritories = async () => {
    setLoadingTerritories(true);
    try {
      console.log('🗺️ Loading available territories (backend)...');
      const { territories } = await TerritoryServiceBackendInstance.getTeamTerritories();
      const available = territories.filter(t => 
        t.is_active && (
          !t.assigned_worker_id || t.assigned_worker_id === selectedWorker?.uid
        )
      );
      setAvailableTerritories(available);
      console.log(`✅ Loaded ${available.length} available territories`);
    } catch (error) {
      console.error('❌ Error loading territories:', error);
      Alert.alert('Error', 'Failed to load territories. Please try again.');
    } finally {
      setLoadingTerritories(false);
    }
  };

  // Load assigned territories for a set of workers
  const fetchWorkerTerritories = async (list: ManagedUser[]) => {
    try {
      const results = await Promise.all(
        list.map(w => TerritoryServiceBackendInstance.getWorkerTerritories(w.uid).catch(() => ({ territories: [], count: 0 } as any)))
      );
      const map: Record<string, BackendTerritory[]> = {};
      list.forEach((w, idx) => {
        map[w.uid] = (results[idx]?.territories || []) as BackendTerritory[];
      });
      setWorkerTerritories(map);
    } catch (e) {
      console.warn('⚠️ Failed to load worker territories map');
    }
  };

  const handleAssignTerritory = async (worker: ManagedUser) => {
    console.log('🗺️ Assign territory to worker:', worker.displayName);
    setSelectedWorker(worker);
    setShowWorkerActionsModal(false);

    // Show the territory picker dialog
    Alert.alert(
      'Assign Territory',
      `Assign a territory to ${worker.displayName}`,
      [
        {
          text: 'Cancel',
          style: 'cancel'
        },
        {
          text: 'Select Territory',
          onPress: async () => {
            // Load territories and show picker
            await loadAvailableTerritories();
            setShowTerritoryPicker(true);
          }
        }
      ]
    );
  };

  // Handle territory assignment confirmation
  const confirmTerritoryAssignment = async () => {
    if (!selectedWorker || !selectedTerritory) return;

    setAssigningTerritory(true);
    try {
      console.log(`🗺️ Assigning territory "${selectedTerritory.name}" to ${selectedWorker.displayName} (backend)`);
      if ((TerritoryServiceBackendInstance as any).assignTerritory) {
        // Enforce single assignment: unassign any other territories from this worker
        const current = workerTerritories[selectedWorker.uid] || [];
        const toUnassign = current.filter(t => t.id !== selectedTerritory.id);
        for (const t of toUnassign) {
          await (TerritoryServiceBackendInstance as any).updateTerritory(t.id, { assigned_worker_id: null });
        }
        // Assign the selected territory
        await (TerritoryServiceBackendInstance as any).assignTerritory(selectedTerritory.id, selectedWorker.uid);
      } else {
        throw new Error('Assign territory API not implemented');
      }

      Alert.alert(
        'Territory Assigned!',
        `Territory "${selectedTerritory.name}" has been successfully assigned to ${selectedWorker.displayName}.`,
        [{ text: 'Great!' }]
      );

      // Reset states
      setShowTerritoryPicker(false);
      // Refresh mapping for this worker
      await fetchWorkerTerritories([selectedWorker]);
      setSelectedWorker(null);
      setSelectedTerritory(null);
      
    } catch (error) {
      console.error('❌ Error assigning territory:', error);
      Alert.alert(
        'Assignment Failed',
        'Failed to assign territory. Please try again.',
        [{ text: 'OK' }]
      );
    } finally {
      setAssigningTerritory(false);
    }
  };

  const handleRemoveWorker = async (worker: ManagedUser) => {
    console.log('🗑️ Remove worker:', worker.displayName);

    Alert.alert(
      'Remove Worker',
      `Are you sure you want to remove ${worker.displayName} from your team?`,
      [
        {
          text: 'Cancel',
          style: 'cancel'
        },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: async () => {
            try {
              setRemovingWorker(true);
              setShowWorkerActionsModal(false);

              if (!teamId) {
                Alert.alert('Error', 'Team ID not found');
                return;
              }

              console.log('🔄 Removing worker from team...');
              const result = await TeamServiceBackend.removeTeamMember(teamId, worker.uid);

              if (result.success) {
                console.log('✅ Worker removed successfully');
                await loadWorkers();
                Alert.alert('Success', `${worker.displayName} has been removed from your team.`);
              } else {
                console.error('❌ Failed to remove worker:', result.message);
                Alert.alert('Error', result.message || 'Failed to remove worker');
              }
            } catch (error) {
              console.error('❌ Error removing worker:', error);
              Alert.alert('Error', 'Failed to remove worker. Please try again.');
            } finally {
              setRemovingWorker(false);
            }
          }
        }
      ]
    );
  };

  const handleViewWorkerDetails = (worker: ManagedUser) => {
    console.log('👤 View worker details:', worker.displayName);
    setShowWorkerActionsModal(false);

    const assignedName = workerTerritories[worker.uid]?.[0]?.name || 'Unassigned';

    Alert.alert(
      'Worker Details',
      `Name: ${worker.displayName}\nEmail: ${worker.email}\nRole: ${worker.role}\nStatus: ${worker.status}\nTeam: ${worker.teamName}\nAssigned Territory: ${assignedName}\nLast Active: ${formatLastActive(worker.lastActiveAt)}`,
      [{ text: 'OK' }]
    );
  };

  const getWorkerStatusColor = (worker: ManagedUser) => {
    if (worker.isOnline) return COLORS.success;
    if (worker.status === 'active') return COLORS.info;
    return COLORS.text.secondary;
  };

  const formatLastActive = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - new Date(date).getTime();
    const minutes = Math.floor(diff / (1000 * 60));

    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;

    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;

    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  };

  const handleCreateTeam = async () => {
    if (!teamName.trim()) {
      Alert.alert('Error', 'Please enter a team name');
      return;
    }

    if (!user) {
      Alert.alert('Error', 'User not found');
      return;
    }

    try {
      setCreatingTeam(true);
      console.log('🚀 Starting team creation...');
      console.log('   User ID:', user.id);
      console.log('   Team Name:', teamName.trim());

      const result = await TeamServiceBackend.createTeam({
        name: teamName.trim(),
        description: '', // Optional - can be added later
      });

      console.log('📦 Team creation result:', result);

      if (result.success && result.teamId) {
        console.log('✅ Team created successfully!');
        console.log('   Team ID:', result.teamId);
        console.log('   Team Name:', teamName.trim());

        // STEP 1: Refresh user data from Firebase
        console.log('🔄 STEP 1: Calling refreshUserData()...');
        await refreshUserData();

        // STEP 2: Update local state
        console.log('🔄 STEP 2: Updating local state...');
        setTeamName('');
        setShowCreateTeam(false);
        
        // STEP 3: Generate invite link
        console.log('🔗 STEP 3: Generating invite link...');
        const link = `rallypoint://team/${result.teamId}`;
        setInviteLink(link);
        console.log('✅ STEP 3: Invite link generated:', link);

        // STEP 5: Load team workers
        console.log('👥 STEP 5: Loading team workers...');
        try {
          const teamWorkers = await TeamServiceBackend.getTeamMembers(result.teamId);
          setWorkers(teamWorkers);
          console.log('✅ STEP 5: Team workers loaded:', teamWorkers.length);
        } catch (workerError) {
          console.warn('⚠️ STEP 5: Error loading workers:', workerError);
          setWorkers([]);
        }

        setLoading(false);
        console.log('✅ ALL STEPS COMPLETED - Team creation successful!');

        Alert.alert(
          'Success',
          'Team created successfully! You can now share the invite link with workers.',
          [{ text: 'OK' }]
        );
      } else {
        console.error('❌ Team creation failed:', result.error);
        Alert.alert('Error', result.error || 'Failed to create team');
      }
    } catch (error) {
      console.error('❌ Error creating team:', error);
      Alert.alert('Error', 'Failed to create team. Please try again.');
    } finally {
      setCreatingTeam(false);
      console.log('🏁 handleCreateTeam finished');
    }
  };

  const handleCopyInviteLink = async () => {
    if (Platform.OS === 'web') {
      try {
        await navigator.clipboard.writeText(inviteLink);
        Alert.alert('Success', 'Invite link copied to clipboard!');
      } catch (error) {
        Alert.alert('Error', 'Failed to copy link');
      }
    } else {
      Clipboard.setString(inviteLink);
      Alert.alert('Success', 'Invite link copied to clipboard!');
    }
  };

  const handleShareInviteLink = async () => {
    try {
      if (Platform.OS === 'web') {
        if (navigator.share) {
          await navigator.share({
            title: 'Join My Team',
            text: `Join my team "${((user as any)?.team_name || (user as any)?.teamName || 'my team')}" on Rally Point!`,
            url: inviteLink,
          });
        } else {
          handleCopyInviteLink();
        }
      } else {
        await Share.share({
          message: `Join my team "${((user as any)?.team_name || (user as any)?.teamName || 'my team')}" on Rally Point!\n\n${inviteLink}`,
          title: 'Join My Team',
        });
      }
    } catch (error) {
      console.error('Error sharing invite link:', error);
    }
  };

  // Show create team form ONLY if user has no teamId AND showCreateTeam is true AND hasTeam is false
  console.log('🎨 Render decision:');
  console.log('   teamId:', teamId);
  console.log('   showCreateTeam:', showCreateTeam);
  console.log('   hasTeam:', hasTeam);
  console.log('   Decision:', (!teamId && showCreateTeam && !hasTeam) ? 'SHOW CREATE FORM' : 'SHOW MAIN CONTENT');

  if (!teamId && showCreateTeam && !hasTeam) {
    return (
      <View style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />
        <Header
          showMenu={true}
          showLogo={true}
          showProfile={true}
          showNotifications={true}
          onProfilePress={() => navigation.navigate('Profile')}
        />

        <ScrollView style={styles.content}>
          <View style={styles.createTeamSection}>
            <View style={styles.sectionHeader}>
              <MaterialIcons name="group-add" size={48} color={COLORS.primary} />
              <Text style={styles.createTeamTitle}>Create Your Team</Text>
              <Text style={styles.createTeamSubtitle}>
                You don't have a team yet. Create one to start managing workers.
              </Text>
            </View>

            <View style={styles.formCard}>
              <Text style={styles.inputLabel}>Team Name</Text>
              <TextInput
                style={styles.input}
                placeholder="Enter team name"
                value={teamName}
                onChangeText={setTeamName}
                editable={!creatingTeam}
              />

              <TouchableOpacity
                style={[styles.createButton, creatingTeam && styles.createButtonDisabled]}
                onPress={handleCreateTeam}
                disabled={creatingTeam}
              >
                <Text style={styles.createButtonText}>
                  {creatingTeam ? 'Creating Team...' : 'Create Team'}
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </ScrollView>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />
      <Header
        showBackButton={true}
        showMenu={false}
        showLogo={false}
        showProfile={true}
        showNotifications={true}
        title="Worker Management"
        onBackPress={() => navigation.goBack()}
        onProfilePress={() => navigation.navigate('Profile')}
      />

      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {/* Team Overview Section */}
        <View style={styles.overviewSection}>
          <View style={styles.sectionHeaderRow}>
            <Text style={styles.sectionTitle}>Team Workers</Text>
            {loading && (
              <View style={styles.loadingIndicator}>
                <MaterialIcons name="refresh" size={16} color={COLORS.text.secondary} />
                <Text style={styles.loadingText}>Loading...</Text>
              </View>
            )}
          </View>

          {/* Stats Cards */}
          <View style={styles.statsGrid}>
            <View style={styles.statCard}>
              <MaterialIcons name="people" size={32} color={COLORS.primary} />
              <Text style={styles.statValue}>{workers.length}</Text>
              <Text style={styles.statLabel}>Total Workers</Text>
            </View>
            <View style={styles.statCard}>
              <MaterialIcons name="online-prediction" size={32} color={COLORS.success} />
              <Text style={styles.statValue}>{workers.filter(w => w.isOnline).length}</Text>
              <Text style={styles.statLabel}>Online</Text>
            </View>
            <View style={styles.statCard}>
              <MaterialIcons name="check-circle" size={32} color={COLORS.info} />
              <Text style={styles.statValue}>{workers.filter(w => w.status === 'active').length}</Text>
              <Text style={styles.statLabel}>Active</Text>
            </View>
          </View>
        </View>

        {/* Invite Link Section - Expandable/Collapsible */}
        {inviteLink && (
          <View style={styles.inviteSection}>
            <TouchableOpacity
              style={styles.inviteSectionHeader}
              onPress={() => setInviteLinkExpanded(!inviteLinkExpanded)}
              activeOpacity={0.7}
            >
              <View style={styles.inviteHeaderLeft}>
                <MaterialIcons
                  name="link"
                  size={24}
                  color={COLORS.secondary}
                  style={styles.inviteHeaderIcon}
                />
                <View>
                  <Text style={styles.sectionTitle}>Team Invite Link</Text>
                  <Text style={styles.inviteHeaderSubtitle}>
                    {inviteLinkExpanded ? 'Tap to hide invite link' : 'Tap to show invite link'}
                  </Text>
                </View>
              </View>
              <MaterialIcons
                name={inviteLinkExpanded ? "keyboard-arrow-up" : "keyboard-arrow-down"}
                size={28}
                color={COLORS.text.secondary}
              />
            </TouchableOpacity>

            {inviteLinkExpanded && (
              <View style={styles.inviteCard}>
                <Text style={styles.inviteLabel}>Share this link with workers to join your team:</Text>
                <View style={styles.inviteLinkContainer}>
                  <Text style={styles.inviteLinkText} numberOfLines={1}>{inviteLink}</Text>
                </View>
                <View style={styles.inviteActions}>
                  <TouchableOpacity style={styles.inviteButton} onPress={handleCopyInviteLink}>
                    <MaterialIcons name="content-copy" size={20} color={COLORS.white} />
                    <Text style={styles.inviteButtonText}>Copy Link</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.inviteButton, styles.shareButton]} onPress={handleShareInviteLink}>
                    <MaterialIcons name="share" size={20} color={COLORS.white} />
                    <Text style={styles.inviteButtonText}>Share</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}
          </View>
        )}

        {/* Workers List Section */}
        <View style={styles.workersSection}>
          <View style={styles.sectionHeaderRow}>
            <Text style={styles.sectionTitle}>Workers List</Text>
          </View>

          {workers.length === 0 ? (
            <View style={styles.emptyCard}>
              <MaterialIcons name="people-outline" size={64} color={COLORS.text.secondary} />
              <Text style={styles.emptyText}>No workers found</Text>
              <Text style={styles.emptySubtext}>
                Workers will appear here when they join your team using the invite link
              </Text>
            </View>
          ) : (
            <View style={styles.workersGrid}>
              {workers.map((worker) => (
                <TouchableOpacity
                  key={worker.uid}
                  style={styles.workerCard}
                  onPress={() => handleWorkerPress(worker)}
                >
                  <View style={styles.workerCardHeader}>
                    <View style={[styles.workerIconContainer, { backgroundColor: `${COLORS.primary}15` }]}>
                      <MaterialIcons name="person" size={24} color={COLORS.primary} />
                    </View>
                    <View style={[styles.workerStatusDot, { backgroundColor: getWorkerStatusColor(worker) }]} />
                  </View>

                  <View style={styles.workerCardContent}>
                    <Text style={styles.workerCardName}>{worker.displayName}</Text>
                    <Text style={styles.workerCardEmail}>{worker.email}</Text>

                    <View style={styles.workerCardDetails}>
                      <View style={styles.workerDetailRow}>
                        <MaterialIcons name="access-time" size={14} color={COLORS.text.secondary} />
                        <Text style={styles.workerDetailText}>{formatLastActive(worker.lastActiveAt)}</Text>
                      </View>
                      <View style={styles.workerDetailRow}>
                        <MaterialIcons name="verified-user" size={14} color={COLORS.text.secondary} />
                        <Text style={styles.workerDetailText}>{worker.status}</Text>
                      </View>
                      <View style={styles.workerDetailRow}>
                        <MaterialIcons name="map" size={14} color={COLORS.text.secondary} />
                        <Text style={styles.workerDetailText}>
                          {(workerTerritories[worker.uid] && workerTerritories[worker.uid].length > 0)
                            ? `Territory: ${workerTerritories[worker.uid][0].name}`
                            : 'Territory: Unassigned'}
                        </Text>
                      </View>
                    </View>
                  </View>

                  <View style={styles.workerCardFooter}>
                    <Text style={styles.workerCardFooterText}>Tap for details</Text>
                    <MaterialIcons name="chevron-right" size={16} color={COLORS.text.secondary} />
                  </View>
                </TouchableOpacity>
              ))}
            </View>
          )}
        </View>
      </ScrollView>

      {/* Worker Actions Modal */}
      <Modal
        visible={showWorkerActionsModal}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setShowWorkerActionsModal(false)}
      >
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setShowWorkerActionsModal(false)}
        >
          <View style={styles.modalContent} onStartShouldSetResponder={() => true}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Worker Actions</Text>
              <TouchableOpacity onPress={() => setShowWorkerActionsModal(false)}>
                <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
            </View>

            {selectedWorker && (
              <>
                <View style={styles.modalWorkerInfo}>
                  <View style={styles.modalWorkerAvatar}>
                    <MaterialIcons name="person" size={32} color={COLORS.primary} />
                  </View>
                  <View style={styles.modalWorkerDetails}>
                    <Text style={styles.modalWorkerName}>{selectedWorker.displayName}</Text>
                    <Text style={styles.modalWorkerEmail}>{selectedWorker.email}</Text>
                  </View>
                </View>

                <View style={styles.modalActions}>
                  {/* View Details */}
                  <TouchableOpacity
                    style={styles.modalActionButton}
                    onPress={() => handleViewWorkerDetails(selectedWorker)}
                  >
                    <View style={[styles.modalActionIcon, { backgroundColor: `${COLORS.info}15` }]}>
                      <MaterialIcons name="info" size={24} color={COLORS.info} />
                    </View>
                    <View style={styles.modalActionTextContainer}>
                      <Text style={styles.modalActionTitle}>View Details</Text>
                      <Text style={styles.modalActionSubtitle}>See worker information</Text>
                    </View>
                    <MaterialIcons name="chevron-right" size={20} color={COLORS.text.secondary} />
                  </TouchableOpacity>

                  {/* Message Worker */}
                  <TouchableOpacity
                    style={styles.modalActionButton}
                    onPress={() => handleMessageWorker(selectedWorker)}
                  >
                    <View style={[styles.modalActionIcon, { backgroundColor: `${COLORS.primary}15` }]}>
                      <MaterialIcons name="message" size={24} color={COLORS.primary} />
                    </View>
                    <View style={styles.modalActionTextContainer}>
                      <Text style={styles.modalActionTitle}>Message Worker</Text>
                      <Text style={styles.modalActionSubtitle}>Send a direct message</Text>
                    </View>
                    <MaterialIcons name="chevron-right" size={20} color={COLORS.text.secondary} />
                  </TouchableOpacity>

                  {/* Assign Territory */}
                  <TouchableOpacity
                    style={styles.modalActionButton}
                    onPress={() => handleAssignTerritory(selectedWorker)}
                  >
                    <View style={[styles.modalActionIcon, { backgroundColor: `${COLORS.secondary}15` }]}>
                      <MaterialIcons name="map" size={24} color={COLORS.secondary} />
                    </View>
                    <View style={styles.modalActionTextContainer}>
                      <Text style={styles.modalActionTitle}>Assign Territory</Text>
                      <Text style={styles.modalActionSubtitle}>Assign a territory to worker</Text>
                    </View>
                    <MaterialIcons name="chevron-right" size={20} color={COLORS.text.secondary} />
                  </TouchableOpacity>

                  {/* Remove Worker */}
                  <TouchableOpacity
                    style={styles.modalActionButton}
                    onPress={() => handleRemoveWorker(selectedWorker)}
                    disabled={removingWorker}
                  >
                    <View style={[styles.modalActionIcon, { backgroundColor: `${COLORS.error}15` }]}>
                      {removingWorker ? (
                        <ActivityIndicator size="small" color={COLORS.error} />
                      ) : (
                        <MaterialIcons name="person-remove" size={24} color={COLORS.error} />
                      )}
                    </View>
                    <View style={styles.modalActionTextContainer}>
                      <Text style={[styles.modalActionTitle, { color: COLORS.error }]}>
                        {removingWorker ? 'Removing...' : 'Remove Worker'}
                      </Text>
                      <Text style={styles.modalActionSubtitle}>Remove from team</Text>
                    </View>
                    <MaterialIcons name="chevron-right" size={20} color={COLORS.text.secondary} />
                  </TouchableOpacity>
                </View>
              </>
            )}
          </View>
        </TouchableOpacity>
      </Modal>

      {/* Territory Picker Modal */}
      <Modal
        visible={showTerritoryPicker}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowTerritoryPicker(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.territoryModalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>🗺️ Select Territory</Text>
              <TouchableOpacity onPress={() => setShowTerritoryPicker(false)}>
                <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
            </View>
            
            {selectedWorker && (
              <Text style={styles.modalDescription}>
                Choose a territory to assign to {selectedWorker.displayName}:
              </Text>
            )}

            {loadingTerritories ? (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color={COLORS.primary} />
                <Text style={styles.territoryLoadingText}>Loading territories...</Text>
              </View>
            ) : (
              <ScrollView style={styles.territoryList}>
                {availableTerritories.length === 0 ? (
                  <View style={styles.emptyState}>
                    <MaterialIcons name="map" size={48} color={COLORS.text.secondary} />
                    <Text style={styles.emptyStateText}>No Available Territories</Text>
                    <Text style={styles.emptyStateSubtext}>
                      All territories are currently assigned or no territories exist.
                    </Text>
                  </View>
                ) : (
                  availableTerritories.map((territory) => (
                    <TouchableOpacity
                      key={territory.id}
                      style={[
                        styles.territoryItem,
                        selectedTerritory?.id === territory.id && styles.territoryItemSelected
                      ]}
                      onPress={() => setSelectedTerritory(territory)}
                    >
                      <View style={styles.territoryInfo}>
                        <Text style={styles.territoryName}>{territory.name}</Text>
                        <Text style={styles.territoryStatus}>
                          {territory.assigned_worker_id ? '👤 Assigned' : '⚪ Unassigned'}
                        </Text>
                      </View>
                      {selectedTerritory?.id === territory.id && (
                        <MaterialIcons name="check-circle" size={24} color={COLORS.primary} />
                      )}
                    </TouchableOpacity>
                  ))
                )}
              </ScrollView>
            )}

            <View style={styles.modalActions}>
              <TouchableOpacity
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => setShowTerritoryPicker(false)}
              >
                <Text style={styles.cancelButtonText}>Cancel</Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[
                  styles.modalButton,
                  styles.assignButton,
                  (!selectedTerritory || assigningTerritory) && styles.buttonDisabled
                ]}
                disabled={!selectedTerritory || assigningTerritory}
                onPress={confirmTerritoryAssignment}
              >
                {assigningTerritory ? (
                  <ActivityIndicator size="small" color="#ffffff" />
                ) : (
                  <Text style={styles.assignButtonText}>Assign Territory</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
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
  },

  // Create Team Section
  createTeamSection: {
    backgroundColor: '#f8fafc',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.xl,
    marginBottom: SPACING.md,
  },
  sectionHeader: {
    alignItems: 'center',
    marginBottom: SPACING.xl,
  },
  createTeamTitle: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
  },
  createTeamSubtitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
    paddingHorizontal: SPACING.xl,
  },
  formCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.xl,
    ...SHADOWS.sm,
  },
  inputLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  input: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.primary,
    marginBottom: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  createButton: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
  },
  createButtonDisabled: {
    opacity: 0.6,
  },
  createButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },

  // Overview Section
  overviewSection: {
    backgroundColor: '#f8fafc',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.xl,
    marginBottom: SPACING.md,
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  loadingIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
  },
  loadingText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },

  // Stats Grid
  statsGrid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: SPACING.md,
  },
  statCard: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    ...SHADOWS.sm,
  },
  statValue: {
    fontSize: TYPOGRAPHY.sizes['3xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginTop: SPACING.sm,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },

  // Invite Section
  inviteSection: {
    backgroundColor: '#f8fafc',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    marginBottom: SPACING.md,
  },
  inviteSectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  inviteHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  inviteHeaderIcon: {
    marginRight: SPACING.md,
  },
  inviteHeaderSubtitle: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
    marginTop: 2,
    fontStyle: 'italic',
  },
  inviteCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    ...SHADOWS.sm,
  },
  inviteLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.md,
  },
  inviteLinkContainer: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  inviteLinkText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.primary,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  inviteActions: {
    flexDirection: 'row',
    gap: SPACING.md,
  },
  inviteButton: {
    flex: 1,
    flexDirection: 'row',
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    justifyContent: 'center',
    gap: SPACING.sm,
  },
  shareButton: {
    backgroundColor: COLORS.secondary,
  },
  inviteButtonText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },

  // Workers Section
  workersSection: {
    backgroundColor: '#f8fafc',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.xl,
    marginBottom: SPACING.md,
  },
  // Empty State
  emptyCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING['2xl'],
    alignItems: 'center',
    ...SHADOWS.sm,
  },
  emptyText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
  },
  emptySubtext: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
    textAlign: 'center',
    paddingHorizontal: SPACING.lg,
  },

  // Workers Grid
  workersGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    gap: SPACING.md,
  },

  // Worker Card
  workerCard: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    width: Platform.OS === 'web' ? '48%' : '100%',
    ...SHADOWS.sm,
  },
  workerCardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  workerIconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  workerStatusDot: {
    width: 10,
    height: 10,
    borderRadius: RADIUS.full,
  },
  workerCardContent: {
    marginBottom: SPACING.md,
  },
  workerCardName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  workerCardEmail: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.md,
  },
  workerCardDetails: {
    gap: SPACING.sm,
  },
  workerDetailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
  },
  workerDetailText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },
  workerCardFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.default,
  },
  workerCardFooterText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },

  // Modal Styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.lg,
  },
  modalContent: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.xl,
    width: '100%',
    maxWidth: 500,
    ...SHADOWS.xl,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  modalTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  modalWorkerInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.lg,
    backgroundColor: `${COLORS.primary}08`,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  modalWorkerAvatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: `${COLORS.primary}15`,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  modalWorkerDetails: {
    flex: 1,
  },
  modalWorkerName: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  modalWorkerEmail: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  modalActions: {
    padding: SPACING.md,
  },
  modalActionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  modalActionIcon: {
    width: 48,
    height: 48,
    borderRadius: RADIUS.md,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  modalActionTextContainer: {
    flex: 1,
  },
  modalActionTitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  modalActionSubtitle: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },

  // Territory Modal Styles
  territoryModalContent: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.xl,
    width: '100%',
    maxWidth: 500,
    maxHeight: '80%',
    ...SHADOWS.xl,
  },
  modalDescription: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.md,
    textAlign: 'center',
  },
  loadingContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.xl,
  },
  territoryLoadingText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  territoryList: {
    maxHeight: 300,
    paddingHorizontal: SPACING.lg,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.xl,
  },
  emptyStateText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    textAlign: 'center',
  },
  emptyStateSubtext: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginTop: SPACING.sm,
    textAlign: 'center',
    lineHeight: 20,
  },
  territoryItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  territoryItemSelected: {
    borderColor: COLORS.primary,
    backgroundColor: `${COLORS.primary}10`,
  },
  territoryInfo: {
    flex: 1,
  },
  territoryName: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  territoryStatus: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
  },
  modalButton: {
    flex: 1,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 48,
  },
  cancelButton: {
    backgroundColor: COLORS.background.secondary,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  cancelButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.secondary,
  },
  assignButton: {
    backgroundColor: COLORS.primary,
  },
  assignButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.background.primary,
  },
  buttonDisabled: {
    opacity: 0.5,
  },
});

export default TeamLeaderWorkerManagementScreen;

