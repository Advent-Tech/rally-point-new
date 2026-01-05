import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  Modal,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
  Platform,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import GeoTerritoryMap from './GeoTerritoryMap';
import { GeoTerritory, ChurchLocation } from '../services/GeoTerritoryService';
import { COLORS, SPACING, TYPOGRAPHY, RADIUS } from '../constants/Colors';

interface TerritoryPickerModalProps {
  visible: boolean;
  onClose: () => void;
  onTerritorySelected: (territory: GeoTerritory) => void;
  onChurchSelected?: (church: ChurchLocation) => void;
  selectedTerritoryId?: string;
  title?: string;
}

const TerritoryPickerModal: React.FC<TerritoryPickerModalProps> = ({
  visible,
  onClose,
  onTerritorySelected,
  onChurchSelected,
  selectedTerritoryId,
  title = 'Select Territory',
}) => {
  const [pendingTerritory, setPendingTerritory] = useState<GeoTerritory | null>(null);

  const handleTerritorySelect = useCallback((territory: GeoTerritory) => {
    setPendingTerritory(territory);
  }, []);

  const handleConfirm = useCallback(() => {
    if (pendingTerritory) {
      onTerritorySelected(pendingTerritory);
      setPendingTerritory(null);
      onClose();
    }
  }, [pendingTerritory, onTerritorySelected, onClose]);

  const handleClose = useCallback(() => {
    setPendingTerritory(null);
    onClose();
  }, [onClose]);

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="fullScreen"
      onRequestClose={handleClose}
    >
      <SafeAreaView style={styles.container}>
        <StatusBar barStyle="dark-content" />

        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity style={styles.closeButton} onPress={handleClose}>
            <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
          </TouchableOpacity>

          <Text style={styles.title}>{title}</Text>

          <TouchableOpacity
            style={[
              styles.confirmButton,
              !pendingTerritory && styles.confirmButtonDisabled,
            ]}
            onPress={handleConfirm}
            disabled={!pendingTerritory}
          >
            <Text
              style={[
                styles.confirmButtonText,
                !pendingTerritory && styles.confirmButtonTextDisabled,
              ]}
            >
              Select
            </Text>
          </TouchableOpacity>
        </View>

        {/* Selected Territory Preview */}
        {pendingTerritory && (
          <View style={styles.selectionPreview}>
            <MaterialIcons name="check-circle" size={20} color="#10b981" />
            <View style={styles.selectionInfo}>
              <Text style={styles.selectionName} numberOfLines={1}>
                {pendingTerritory.entity_name}
              </Text>
              <Text style={styles.selectionDetails} numberOfLines={1}>
                {pendingTerritory.city}{pendingTerritory.city && pendingTerritory.state ? ', ' : ''}{pendingTerritory.state}
                {pendingTerritory.union_name ? ` - ${pendingTerritory.union_name}` : ''}
              </Text>
            </View>
            <TouchableOpacity onPress={() => setPendingTerritory(null)}>
              <MaterialIcons name="close" size={18} color={COLORS.text.secondary} />
            </TouchableOpacity>
          </View>
        )}

        {/* Map */}
        <View style={styles.mapContainer}>
          <GeoTerritoryMap
            height="100%"
            showSearch={true}
            showStats={false}
            onTerritorySelect={handleTerritorySelect}
            onChurchSelect={onChurchSelected}
            selectedTerritoryId={pendingTerritory?.id || selectedTerritoryId}
          />
        </View>

        {/* Instructions */}
        <View style={styles.instructions}>
          <MaterialIcons name="touch-app" size={16} color={COLORS.text.secondary} />
          <Text style={styles.instructionsText}>
            Tap on a territory to select it, or use the search bar above
          </Text>
        </View>
      </SafeAreaView>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
    backgroundColor: COLORS.background,
  },
  closeButton: {
    padding: SPACING.xs,
  },
  title: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: '600',
    color: COLORS.text.primary,
  },
  confirmButton: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.md,
  },
  confirmButtonDisabled: {
    backgroundColor: COLORS.border,
  },
  confirmButtonText: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: '600',
    color: '#ffffff',
  },
  confirmButtonTextDisabled: {
    color: COLORS.text.secondary,
  },
  selectionPreview: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: '#dcfce7',
    borderBottomWidth: 1,
    borderBottomColor: '#bbf7d0',
  },
  selectionInfo: {
    flex: 1,
    marginLeft: SPACING.sm,
    marginRight: SPACING.sm,
  },
  selectionName: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: '600',
    color: '#166534',
  },
  selectionDetails: {
    fontSize: TYPOGRAPHY.sm,
    color: '#15803d',
    marginTop: 2,
  },
  mapContainer: {
    flex: 1,
  },
  instructions: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    backgroundColor: COLORS.backgroundSecondary,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
  },
  instructionsText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
    marginLeft: SPACING.xs,
  },
});

export default TerritoryPickerModal;
