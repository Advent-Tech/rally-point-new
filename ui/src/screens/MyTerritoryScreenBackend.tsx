import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
  Alert,
  Modal,
  TextInput,
  SafeAreaView,
} from 'react-native';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { TerritoryServiceBackendInstance, Territory, TerritoryStats } from '../services/TerritoryServiceBackend';
import { TeamServiceBackendInstance } from '../services/TeamServiceBackend';
import ModernVisualTerritoryMap from '../components/ModernVisualTerritoryMap';
import TerritoryDrawingWrapper from '../components/TerritoryDrawingWrapper';
import { SimpleWalkieTalkiePanel } from '../components/walkie-talkie/SimpleWalkieTalkiePanel';

// Adapter function to convert backend Territory to TerritoryMap format
const adaptTerritoryForMap = (territory: Territory): any => {
  // Extract coordinates from GeoJSON boundary

  let coordinates: Array<{lat: number, lng: number}> = [];
  
  
  try {
    if (territory.boundary) {
      console.log('🗺️ Processing territory boundary:', territory.boundary);
      
      // Parse the boundary string if it's a JSON string
      let boundaryData;
      if (typeof territory.boundary === 'string') {
        boundaryData = JSON.parse(territory.boundary);
      } else {
        boundaryData = territory.boundary;
      }
      
      console.log('🗺️ Parsed boundary data:', boundaryData);
      
      if (boundaryData.coordinates && boundaryData.coordinates[0]) {
        // GeoJSON Polygon coordinates: [[[lng, lat], [lng, lat], ...]]
        coordinates = boundaryData.coordinates[0].map((coord: number[]) => ({
          lat: coord[1], // latitude is second element
          lng: coord[0], // longitude is first element
        }));
        
        console.log('🗺️ Converted coordinates:', coordinates);
      } else {
        console.warn('🗺️ No coordinates found in boundary data');
      }
    } else {
      console.warn('🗺️ No boundary found for territory:', territory.id);
    }
  } catch (error) {
    console.warn('🗺️ Error parsing territory boundary:', error);
  }
  
  const adaptedTerritory = {
    id: territory.id,
    name: territory.name,
    coordinates,
    assignedWorker: territory.assigned_worker_id ? {
      id: territory.assigned_worker_id,
      name: 'Assigned Worker', // We don't have worker name in backend
      email: '',
    } : undefined,
    color: territory.color,
  };
  
  console.log('🗺️ Adapted territory for map:', adaptedTerritory);
  return adaptedTerritory;
};

interface MyTerritoryScreenProps {
  navigation: any;
}

const MyTerritoryScreenBackend: React.FC<MyTerritoryScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [stats, setStats] = useState<TerritoryStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newTerritory, setNewTerritory] = useState({
    name: '',
    description: '',
    color: '#007AFF'
  });
  const [isDrawingMode, setIsDrawingMode] = useState(false);
  const [drawnCoordinates, setDrawnCoordinates] = useState<Array<{lat: number, lng: number}> | null>(null);
  const [selectedTerritory, setSelectedTerritory] = useState<Territory | null>(null);
  const [showTerritoryMap, setShowTerritoryMap] = useState(false);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [assignTerritoryItem, setAssignTerritoryItem] = useState<Territory | null>(null);
  const [teamMembers, setTeamMembers] = useState<any[]>([]);
  const [assignLoading, setAssignLoading] = useState(false);
  const [showWalkieTalkie, setShowWalkieTalkie] = useState(false);

  // For workers, get only their assigned territory
  const myAssignedTerritory = territories.find(t => t.assigned_worker_id === user?.id);
  const isWorker = user?.role !== 'team_leader';

  const loadData = async () => {
    if (!user) return;

    try {
      setError(null);
      console.log('🗺️ Loading territory data for user:', user.email);

      // TEMPORARY DEBUG: Set test token if needed
      // Removed test token setup - now using real auth token

      if (user.role === 'team_leader') {
        // Team leaders see full team territories and stats
        const [territoriesResponse, statsResponse] = await Promise.all([
          TerritoryServiceBackendInstance.getTeamTerritories(),
          TerritoryServiceBackendInstance.getTeamStats(),
        ]);

        setTerritories(territoriesResponse.territories || []);
        setStats(statsResponse);
        console.log(`✅ Loaded ${territoriesResponse.count} territories (team leader view)`);
      } else {
        // Workers see only their assigned territories
        const territoriesResponse = await TerritoryServiceBackendInstance.getWorkerTerritories(user.id);
        setTerritories(territoriesResponse.territories || []);
        setStats(null);
        console.log(`✅ Loaded ${territoriesResponse.count} territories (worker view)`);
      }
    } catch (error: any) {
      console.error('❌ Error loading territory data:', error);
      setError(error.message || 'Failed to load territory data');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [user]);

  const handleRefresh = () => {
    setRefreshing(true);
    loadData();
  };

  const handleCreateTerritory = () => {
    if (user?.role !== 'team_leader') {
      Alert.alert('Permission Denied', 'Only team leaders can create territories.');
      return;
    }
    setIsDrawingMode(true);
    setShowCreateModal(true);
    setNewTerritory({
      name: '',
      description: '',
      color: COLORS.primary,
    });
  };

  const handlePolygonDrawn = (coordinates: Array<{lat: number, lng: number}>) => {
    console.log('🗺️ Territory drawn with coordinates:', coordinates);
    setDrawnCoordinates(coordinates);
    setIsDrawingMode(false);
  };

  const handleCancelDrawingComplete = () => {
    // Close the entire modal and reset all state
    setIsDrawingMode(false);
    setShowCreateModal(false);
    setDrawnCoordinates(null);
    setNewTerritory({
      name: '',
      description: '',
      color: COLORS.primary,
    });
  };

  const startDrawingMode = () => {
    setIsDrawingMode(true);
  };

  const handleMapReady = () => {
    console.log('🗺️ Drawing map is ready');
  };

  const convertCoordinatesToGeoJSON = (coordinates: Array<{lat: number, lng: number}>): string => {
    if (!coordinates || coordinates.length < 3) {
      throw new Error('At least 3 points are required to create a territory');
    }
    
    // Convert to GeoJSON Polygon format and close the ring
    const geoJsonCoordinates = [
      ...coordinates.map(coord => [coord.lng, coord.lat]),
      [coordinates[0].lng, coordinates[0].lat] // Close the polygon
    ];
    
    return JSON.stringify({
      type: "Polygon",
      coordinates: [geoJsonCoordinates]
    });
  };

  const handleCreateTerritorySubmit = async () => {
    if (!newTerritory.name.trim()) {
      Alert.alert('Error', 'Please enter a territory name');
      return;
    }

    if (!drawnCoordinates || drawnCoordinates.length < 3) {
      Alert.alert('Error', 'Please draw a territory boundary on the map (at least 3 points)');
      return;
    }

    try {
      // Determine team_id from backend profile (ensures it matches backend DB)
      const existingTeamId = await TerritoryServiceBackendInstance.getCurrentTeamId();
      if (!existingTeamId) {
        Alert.alert(
          'Team Not Linked',
          'Your account is not linked to a backend team yet. Please ensure your team is created and synced before creating territories.'
        );
        return;
      }

      // Convert drawn coordinates to GeoJSON boundary
      const boundary = convertCoordinatesToGeoJSON(drawnCoordinates);
      
      const territoryData = {
        name: newTerritory.name.trim(),
        description: newTerritory.description.trim() || 'Team territory for ministry work',
        team_id: existingTeamId,
        boundary: boundary,
        color: newTerritory.color
      };

      console.log('🗺️ Creating territory with boundary:', boundary);
      const createdTerritory = await TerritoryServiceBackendInstance.createTerritory(territoryData);
      
      setShowCreateModal(false);
      Alert.alert(
        'Territory Created!', 
        `Successfully created "${createdTerritory.name}" with ${drawnCoordinates?.length || 0} boundary points`,
        [{ text: 'OK', onPress: () => loadData() }] // Refresh the list
      );
    } catch (error: any) {
      console.error('❌ Error creating territory:', error);
      Alert.alert(
        'Creation Failed',
        error.message || 'Failed to create territory. Please try again.'
      );
    }
  };

  const handleTerritoryPress = (territory: Territory) => {
    setSelectedTerritory(territory);
    setShowTerritoryMap(true);
  };

  const openAssignModal = async (territory: Territory) => {
    if (user?.role !== 'team_leader') return;
    try {
      setAssignTerritoryItem(territory);
      setAssignLoading(true);
      let teamId = await TerritoryServiceBackendInstance.getCurrentTeamId();
      if (!teamId) {
        Alert.alert('Team Not Linked', 'Your account is not linked to a backend team.');
        setAssignLoading(false);
        return;
      }
      const members = await TeamServiceBackendInstance.getTeamMembers(teamId);
      setTeamMembers(members);
      setShowAssignModal(true);
    } catch (e) {
      Alert.alert('Error', 'Failed to load team members.');
    } finally {
      setAssignLoading(false);
    }
  };

  const handleAssignToWorker = async (workerId: string) => {
    if (!assignTerritoryItem) return;
    try {
      setAssignLoading(true);
      await TerritoryServiceBackendInstance.updateTerritory(assignTerritoryItem.id, { assigned_worker_id: workerId } as any);
      setShowAssignModal(false);
      setAssignTerritoryItem(null);
      await loadData();
    } catch (e: any) {
      Alert.alert('Assign Failed', e?.message || 'Could not assign territory');
    } finally {
      setAssignLoading(false);
    }
  };

  const handleUnassignTerritory = async () => {
    if (!assignTerritoryItem) return;
    try {
      setAssignLoading(true);
      await TerritoryServiceBackendInstance.updateTerritory(assignTerritoryItem.id, { assigned_worker_id: null } as any);
      setShowAssignModal(false);
      setAssignTerritoryItem(null);
      await loadData();
    } catch (e: any) {
      Alert.alert('Unassign Failed', e?.message || 'Could not unassign territory');
    } finally {
      setAssignLoading(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <MaterialIcons name="arrow-back" size={24} color={COLORS.text.primary} />
          </TouchableOpacity>
          <Text style={styles.title}>My Territory</Text>
          <View style={{ width: 24 }} />
        </View>
        
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading territories...</Text>
        </View>
      </View>
    );
  }

  // Worker View - Shows map with assigned territory and walkie-talkie FAB
  if (isWorker) {
    return (
      <View style={styles.container}>
        {/* Header */}
        <View style={styles.workerHeader}>
          <Text style={styles.workerTitle}>My Territory</Text>
          {myAssignedTerritory && (
            <Text style={styles.workerTerritoryName}>{myAssignedTerritory.name}</Text>
          )}
        </View>

        {/* Map or Empty State */}
        {myAssignedTerritory ? (
          <View style={styles.workerMapContainer}>
            <ModernVisualTerritoryMap
              territories={[adaptTerritoryForMap(myAssignedTerritory)]}
              onTerritoryPress={() => {}}
              showUserLocation={true}
              style={styles.fullMap}
            />
          </View>
        ) : (
          <View style={styles.workerEmptyState}>
            <MaterialIcons name="map" size={80} color={COLORS.text.disabled} />
            <Text style={styles.workerEmptyTitle}>No Territory Assigned</Text>
            <Text style={styles.workerEmptyMessage}>
              You haven't been assigned a territory yet. Please contact your team leader.
            </Text>
          </View>
        )}

        {/* Floating Walkie-Talkie Button */}
        <TouchableOpacity
          style={styles.walkieFab}
          onPress={() => setShowWalkieTalkie(true)}
          activeOpacity={0.8}
        >
          <Ionicons name="mic" size={28} color="#FFFFFF" />
        </TouchableOpacity>

        {/* Walkie-Talkie Modal */}
        <Modal
          visible={showWalkieTalkie}
          transparent
          animationType="slide"
          onRequestClose={() => setShowWalkieTalkie(false)}
        >
          <View style={styles.walkieModalOverlay}>
            <View style={styles.walkieModalContent}>
              {showWalkieTalkie && user && (
                <SimpleWalkieTalkiePanel
                  teamId={(user as any).team_id || `territory_${(user.id || '').slice(-8)}`}
                  userId={user.id}
                  userName={user.display_name || user.email?.split('@')[0] || 'User'}
                  teamName={undefined}
                  onClose={() => setShowWalkieTalkie(false)}
                />
              )}
            </View>
          </View>
        </Modal>
      </View>
    );
  }

  // Team Leader View - Full territory management
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.title}>My Territory</Text>
        {user?.role === 'team_leader' && (
          <TouchableOpacity onPress={handleCreateTerritory}>
            <MaterialIcons name="add" size={24} color={COLORS.primary} />
          </TouchableOpacity>
        )}
      </View>

      <ScrollView
        style={styles.content}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
        }
        showsVerticalScrollIndicator={false}
      >
        {error ? (
          <View style={styles.errorContainer}>
            <MaterialIcons name="error-outline" size={48} color={COLORS.error} />
            <Text style={styles.errorTitle}>Error Loading Data</Text>
            <Text style={styles.errorMessage}>{error}</Text>
            <TouchableOpacity style={styles.retryButton} onPress={loadData}>
              <Text style={styles.retryButtonText}>Retry</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <>
            {/* Stats Section */}
            {stats && (
              <View style={styles.statsSection}>
                <Text style={styles.sectionTitle}>Team Territory Overview</Text>
                <View style={styles.statsGrid}>
                  <View style={styles.statCard}>
                    <MaterialIcons name="map" size={24} color={COLORS.primary} />
                    <Text style={styles.statValue}>{stats.total_territories}</Text>
                    <Text style={styles.statLabel}>Total Areas</Text>
                  </View>
                  <View style={styles.statCard}>
                    <MaterialIcons name="assignment-ind" size={24} color={COLORS.success} />
                    <Text style={styles.statValue}>{stats.assigned_territories}</Text>
                    <Text style={styles.statLabel}>Assigned</Text>
                  </View>
                  <View style={styles.statCard}>
                    <MaterialIcons name="assignment-late" size={24} color={COLORS.warning} />
                    <Text style={styles.statValue}>{stats.unassigned_territories}</Text>
                    <Text style={styles.statLabel}>Unassigned</Text>
                  </View>
                  <View style={styles.statCard}>
                    <MaterialIcons name="people" size={24} color={COLORS.info} />
                    <Text style={styles.statValue}>{stats.total_workers}</Text>
                    <Text style={styles.statLabel}>Total Workers</Text>
                  </View>
                </View>
              </View>
            )}

            {/* Territory Map - only show when a territory is selected */}
            {showTerritoryMap && selectedTerritory && (
              <View style={styles.mapSection}>
                <View style={styles.mapHeader}>
                  <TouchableOpacity 
                    style={styles.backButton} 
                    onPress={() => {
                      setShowTerritoryMap(false);
                      setSelectedTerritory(null);
                    }}
                  >
                    <MaterialIcons name="arrow-back" size={24} color={COLORS.text.primary} />
                  </TouchableOpacity>
                  <Text style={styles.mapTitle}>{selectedTerritory.name}</Text>
                </View>
                <View style={styles.mapContainer}>
                  <ModernVisualTerritoryMap
                    territories={[adaptTerritoryForMap(selectedTerritory)]}
                    onTerritoryPress={() => {}}
                    showUserLocation={true}
                    style={styles.mapContainer}
                  />
                </View>
              </View>
            )}

            {/* Territories List */}
            <View style={styles.territoriesSection}>
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>Team Territories</Text>
                <Text style={styles.territoryCount}>{territories.length} areas</Text>
              </View>

              {territories.length === 0 ? (
                <View style={styles.emptyState}>
                  <MaterialIcons name="map" size={64} color={COLORS.text.disabled} />
                  <Text style={styles.emptyTitle}>No Territories Yet</Text>
                  <Text style={styles.emptyMessage}>
                    Your team hasn't been assigned any territories yet. Contact your team leader for assignments.
                  </Text>
                </View>
              ) : (
                territories.map((territory) => (
                  <TouchableOpacity
                    key={territory.id}
                    style={styles.territoryCard}
                    onPress={() => handleTerritoryPress(territory)}
                  >
                    <View style={[styles.territoryIndicator, { backgroundColor: territory.color }]} />
                    <View style={styles.territoryContent}>
                      <Text style={styles.territoryName}>{territory.name}</Text>
                      {territory.description && (
                        <Text style={styles.territoryDescription}>{territory.description}</Text>
                      )}
                      <View style={styles.territoryMeta}>
                        <MaterialIcons 
                          name={territory.assigned_worker_id ? "person" : "public"} 
                          size={16} 
                          color={COLORS.text.secondary} 
                        />
                        <Text style={styles.territoryMetaText}>
                          {territory.assigned_worker_id ? "Assigned" : "Unassigned"}
                        </Text>
                      </View>
                    </View>
                    {user?.role === 'team_leader' && (
                      <TouchableOpacity style={styles.assignIconButton} onPress={() => openAssignModal(territory)}>
                        <MaterialIcons name={territory.assigned_worker_id ? "person-remove" : "person-add"} size={20} color={COLORS.text.secondary} />
                      </TouchableOpacity>
                    )}
                    <MaterialIcons name="chevron-right" size={20} color={COLORS.text.disabled} />
                  </TouchableOpacity>
                ))
              )}
            </View>
          </>
        )}
      </ScrollView>


      {/* Create Territory Modal */}
      <Modal
        visible={showCreateModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowCreateModal(false)}
      >
        {isDrawingMode ? (
          <TerritoryDrawingWrapper
            isDrawingMode={isDrawingMode}
            territoryName={newTerritory.name}
            onTerritoryNameChange={(name: string) => setNewTerritory(prev => ({ ...prev, name }))}
            onPolygonDrawn={handlePolygonDrawn}
            onStopDrawing={handleCancelDrawingComplete}
            territories={territories.map(adaptTerritoryForMap)}
            onMapReady={handleMapReady}
            onSaveTerritory={handleCreateTerritorySubmit}
          />
        ) : (
          <View style={styles.modalContainer}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowCreateModal(false)}>
                <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Complete Territory Details</Text>
              <View style={{ width: 24 }} />
            </View>

            <ScrollView style={styles.modalContent}>
              <View style={styles.successBox}>
                <MaterialIcons name="check-circle" size={48} color={COLORS.success} />
                <Text style={styles.successTitle}>Territory Area Defined!</Text>
                <Text style={styles.successText}>
                  You've successfully drawn a territory with {drawnCoordinates?.length || 0} boundary points.
                </Text>
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.label}>Territory Name *</Text>
                <TextInput
                  style={styles.input}
                  value={newTerritory.name}
                  onChangeText={(text) => setNewTerritory(prev => ({ ...prev, name: text }))}
                  placeholder="Enter territory name"
                  placeholderTextColor={COLORS.text.secondary}
                />
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.label}>Description</Text>
                <TextInput
                  style={[styles.input, styles.textArea]}
                  value={newTerritory.description}
                  onChangeText={(text) => setNewTerritory(prev => ({ ...prev, description: text }))}
                  placeholder="Enter territory description (optional)"
                  placeholderTextColor={COLORS.text.secondary}
                  multiline
                  numberOfLines={3}
                />
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.label}>Color</Text>
                <View style={styles.colorOptions}>
                  {['#007AFF', '#FF3B30', '#34C759', '#FF9500', '#AF52DE', '#FF2D92'].map((color) => (
                    <TouchableOpacity
                      key={color}
                      style={[
                        styles.colorOption,
                        { backgroundColor: color },
                        newTerritory.color === color && styles.colorOptionSelected
                      ]}
                      onPress={() => setNewTerritory(prev => ({ ...prev, color }))}
                    />
                  ))}
                </View>
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.label}>Territory Boundary</Text>
                {drawnCoordinates ? (
                  <View style={styles.boundaryPreview}>
                    <MaterialIcons name="check-circle" size={20} color={COLORS.success} />
                    <Text style={styles.boundaryText}>
                      Boundary drawn with {drawnCoordinates?.length || 0} points
                    </Text>
                    <TouchableOpacity 
                      style={styles.redrawButton}
                      onPress={startDrawingMode}
                    >
                      <MaterialIcons name="edit" size={16} color={COLORS.primary} />
                      <Text style={styles.redrawButtonText}>Redraw</Text>
                    </TouchableOpacity>
                  </View>
                ) : (
                  <TouchableOpacity 
                    style={styles.drawBoundaryButton}
                    onPress={startDrawingMode}
                  >
                    <MaterialIcons name="map" size={24} color={COLORS.primary} />
                    <Text style={styles.drawBoundaryText}>Draw Territory on Map</Text>
                    <Text style={styles.drawBoundarySubtext}>Tap to open drawing interface</Text>
                  </TouchableOpacity>
                )}
              </View>
            </ScrollView>

            <View style={styles.modalFooter}>
              <TouchableOpacity
                style={[styles.button, styles.buttonCancel]}
                onPress={() => setShowCreateModal(false)}
              >
                <Text style={styles.buttonCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.button, styles.buttonCreate]}
                onPress={handleCreateTerritorySubmit}
              >
                <Text style={styles.buttonCreateText}>Create Territory</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}
      </Modal>
      {/* Assign Territory Modal (Team Leader only) */}
      <Modal
        visible={showAssignModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowAssignModal(false)}
      >
        <View style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <TouchableOpacity onPress={() => setShowAssignModal(false)}>
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
            <Text style={styles.modalTitle}>Assign Territory</Text>
            <View style={{ width: 24 }} />
          </View>

          <ScrollView style={styles.modalContent}>
            {assignTerritoryItem && (
              <View style={[styles.formGroup, { marginBottom: SPACING.md }] }>
                <Text style={styles.label}>Territory</Text>
                <Text style={styles.territoryName}>{assignTerritoryItem.name}</Text>
                <View style={[styles.territoryMeta, { marginTop: SPACING.xs }]}>
                  <MaterialIcons 
                    name={assignTerritoryItem.assigned_worker_id ? "person" : "public"} 
                    size={16} 
                    color={COLORS.text.secondary} 
                  />
                  <Text style={styles.territoryMetaText}>
                    {assignTerritoryItem.assigned_worker_id ? "Assigned" : "Unassigned"}
                  </Text>
                </View>
              </View>
            )}

            {assignTerritoryItem?.assigned_worker_id && (
              <TouchableOpacity
                style={[styles.button, styles.buttonCancel, { marginBottom: SPACING.md }]}
                onPress={handleUnassignTerritory}
                disabled={assignLoading}
              >
                <Text style={styles.buttonCancelText}>{assignLoading ? 'Unassigning...' : 'Unassign from Worker'}</Text>
              </TouchableOpacity>
            )}

            <Text style={[styles.label, { marginBottom: SPACING.sm }]}>Team Members</Text>
            {assignLoading ? (
              <View style={{ alignItems: 'center', padding: SPACING.md }}>
                <ActivityIndicator size="small" color={COLORS.primary} />
                <Text style={{ marginTop: SPACING.sm, color: COLORS.text.secondary }}>Loading team members...</Text>
              </View>
            ) : teamMembers.length === 0 ? (
              <View style={styles.emptyState}>
                <MaterialIcons name="people" size={48} color={COLORS.text.disabled} />
                <Text style={styles.emptyTitle}>No Team Members</Text>
                <Text style={styles.emptyMessage}>Add workers to your team to assign this territory.</Text>
              </View>
            ) : (
              teamMembers.map((member) => {
                const isAssignedToThis = assignTerritoryItem?.assigned_worker_id === member.uid;
                return (
                  <View key={member.uid} style={styles.memberRow}>
                    <View style={styles.memberInfo}>
                      <Text style={styles.memberName}>{member.displayName || member.email}</Text>
                      <Text style={styles.memberEmail}>{member.email}</Text>
                      {isAssignedToThis && (
                        <Text style={styles.memberAssignedLabel}>Currently assigned</Text>
                      )}
                    </View>
                    <TouchableOpacity
                      style={[
                        styles.memberAssignButton,
                        isAssignedToThis && styles.memberUnassignButton
                      ]}
                      onPress={() => isAssignedToThis ? handleUnassignTerritory() : handleAssignToWorker(member.uid)}
                      disabled={assignLoading}
                    >
                      <Text style={[
                        styles.memberAssignButtonText,
                        isAssignedToThis && styles.memberUnassignButtonText
                      ]}>
                        {assignLoading ? (isAssignedToThis ? 'Unassigning...' : 'Assigning...') : (isAssignedToThis ? 'Unassign' : 'Assign')}
                      </Text>
                    </TouchableOpacity>
                  </View>
                );
              })
            )}
          </ScrollView>

          <View style={styles.modalFooter}>
            <TouchableOpacity
              style={[styles.button, styles.buttonCancel]}
              onPress={() => setShowAssignModal(false)}
            >
              <Text style={styles.buttonCancelText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.md,
    paddingTop: SPACING.xl,
    paddingBottom: SPACING.md,
    backgroundColor: COLORS.background.primary,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  title: {
    fontSize: 24,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  content: {
    flex: 1,
    padding: SPACING.md,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: SPACING.md,
    fontSize: 16,
    color: COLORS.text.secondary,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  errorTitle: {
    fontSize: 20,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
  },
  errorMessage: {
    fontSize: 16,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginBottom: SPACING.lg,
  },
  retryButton: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.sm,
  },
  retryButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  statsSection: {
    marginBottom: SPACING.xl,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  statCard: {
    width: '48%',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  statValue: {
    fontSize: 24,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginVertical: SPACING.xs,
  },
  statLabel: {
    fontSize: 12,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  mapSection: {
    marginBottom: SPACING.lg,
  },
  mapContainer: {
    height: 300,
    borderRadius: RADIUS.md,
    overflow: 'hidden',
    ...SHADOWS.md,
  },
  territoriesSection: {
    flex: 1,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  territoryCount: {
    fontSize: 14,
    color: COLORS.text.secondary,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING['2xl'],
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
  },
  emptyMessage: {
    textAlign: 'center',
    marginHorizontal: SPACING.sm,
  },
  territoryCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    backgroundColor: 'white',
    borderRadius: RADIUS.lg,
    marginBottom: SPACING.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 3,
  },
  territoryIndicator: {
    width: 4,
    height: 40,
    borderRadius: 2,
    marginRight: SPACING.md,
  },
  territoryContent: {
    flex: 1,
  },
  territoryName: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  territoryDescription: {
    fontSize: 14,
    color: COLORS.text.secondary,
    marginBottom: SPACING.sm,
  },
  territoryMeta: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  territoryMetaText: {
    fontSize: 12,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
  assignIconButton: {
    padding: SPACING.sm,
    marginRight: SPACING.sm,
  },
  mapHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  backButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
    backgroundColor: COLORS.background.secondary,
  },
  mapTitle: {
    flex: 1,
    fontSize: 18,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    textAlign: 'center',
    marginHorizontal: SPACING.sm,
  },
  // Modal styles
  modalContainer: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.default,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
  },
  modalContent: {
    flex: 1,
    padding: SPACING.md,
  },
  formGroup: {
    marginBottom: SPACING.lg,
  },
  label: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  input: {
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    fontSize: 16,
    color: COLORS.text.primary,
    backgroundColor: COLORS.background.secondary,
  },
  textArea: {
    height: 80,
    textAlignVertical: 'top',
  },
  colorOptions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.sm,
  },
  colorOption: {
    width: 40,
    height: 40,
    borderRadius: 20,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  colorOptionSelected: {
    borderColor: COLORS.text.primary,
    borderWidth: 3,
  },
  note: {
    fontSize: 14,
    color: COLORS.text.secondary,
    fontStyle: 'italic',
    lineHeight: 20,
  },
  // Boundary drawing styles
  drawBoundaryButton: {
    borderWidth: 2,
    borderColor: COLORS.primary,
    borderStyle: 'dashed',
    borderRadius: RADIUS.md,
    padding: SPACING.lg,
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
  },
  drawBoundaryText: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.primary,
    marginTop: SPACING.sm,
  },
  drawBoundarySubtext: {
    fontSize: 14,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  boundaryPreview: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background.secondary,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.success,
  },
  boundaryText: {
    flex: 1,
    fontSize: 14,
    color: COLORS.text.primary,
    marginLeft: SPACING.sm,
  },
  redrawButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
    backgroundColor: COLORS.background.primary,
  },
  redrawButtonText: {
    fontSize: 14,
    color: COLORS.primary,
    marginLeft: SPACING.xs,
  },
  modalFooter: {
    flexDirection: 'row',
    padding: SPACING.md,
    gap: SPACING.sm,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.default,
  },
  button: {
    flex: 1,
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
  },
  buttonCancel: {
    backgroundColor: COLORS.background.secondary,
    borderWidth: 1,
    borderColor: COLORS.border.default,
  },
  buttonCreate: {
    backgroundColor: COLORS.primary,
  },
  buttonCancelText: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  buttonCreateText: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: 'white',
  },
  successBox: {
    backgroundColor: '#F0FDF4',
    borderWidth: 1,
    borderColor: COLORS.success,
    borderRadius: RADIUS.md,
    padding: SPACING.lg,
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  successTitle: {
    fontSize: 18,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.success,
    marginTop: SPACING.sm,
    marginBottom: SPACING.xs,
  },
  successText: {
    fontSize: 14,
    color: COLORS.text.secondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  memberRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.sm,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.light,
    marginBottom: SPACING.sm,
  },
  memberInfo: {
    flex: 1,
    marginRight: SPACING.sm,
  },
  memberName: {
    fontSize: 16,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
  },
  memberEmail: {
    fontSize: 12,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  memberAssignButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.xs,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.sm,
  },
  memberUnassignButton: {
    backgroundColor: COLORS.error,
  },
  memberAssignButtonText: {
    color: 'white',
    fontSize: 14,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  memberUnassignButtonText: {
    color: 'white',
  },
  memberAssignedLabel: {
    fontSize: 11,
    color: COLORS.success,
    marginTop: 2,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  // Worker View Styles
  workerHeader: {
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.xl,
    paddingBottom: SPACING.md,
    backgroundColor: COLORS.background.primary,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  workerTitle: {
    fontSize: 28,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
  },
  workerTerritoryName: {
    fontSize: 16,
    color: COLORS.primary,
    marginTop: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  workerMapContainer: {
    flex: 1,
  },
  fullMap: {
    flex: 1,
  },
  workerEmptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  workerEmptyTitle: {
    fontSize: 22,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.lg,
  },
  workerEmptyMessage: {
    fontSize: 16,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginTop: SPACING.sm,
    lineHeight: 24,
  },
  walkieFab: {
    position: 'absolute',
    bottom: 100,
    right: SPACING.lg,
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#10B981',
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
  },
  walkieModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  walkieModalContent: {
    backgroundColor: COLORS.background.primary,
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
  },
});

export default MyTerritoryScreenBackend;
