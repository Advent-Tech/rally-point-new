import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Modal } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface RoleSelectionModalProps {
  visible: boolean;
  onSelectRole: (role: 'worker' | 'team_leader') => void;
  userName?: string;
}

const RoleSelectionModal: React.FC<RoleSelectionModalProps> = ({
  visible,
  onSelectRole,
  userName,
}) => {
  const [selectedRole, setSelectedRole] = useState<'worker' | 'team_leader' | null>(null);

  const handleSelectRole = (role: 'worker' | 'team_leader') => {
    setSelectedRole(role);
  };

  const handleConfirm = () => {
    if (selectedRole) {
      onSelectRole(selectedRole);
    }
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={() => {}} // Prevent closing without selection
    >
      <View style={styles.overlay}>
        <View style={styles.container}>
          {/* Header */}
          <View style={styles.header}>
            <View style={styles.iconContainer}>
              <MaterialIcons name="person" size={40} color={COLORS.white} />
            </View>
            <Text style={styles.title}>Welcome to Rally Point!</Text>
            {userName && (
              <Text style={styles.userName}>{userName}</Text>
            )}
            <Text style={styles.subtitle}>Please select your role to continue</Text>
          </View>

          {/* Role Options */}
          <View style={styles.rolesContainer}>
            {/* Worker Role */}
            <TouchableOpacity
              style={[
                styles.roleCard,
                selectedRole === 'worker' && styles.roleCardSelected,
              ]}
              onPress={() => handleSelectRole('worker')}
              activeOpacity={0.7}
            >
              <View style={[
                styles.roleIconContainer,
                selectedRole === 'worker' && styles.roleIconContainerSelected,
              ]}>
                <MaterialIcons 
                  name="work" 
                  size={32} 
                  color={selectedRole === 'worker' ? COLORS.white : COLORS.primary} 
                />
              </View>
              <Text style={[
                styles.roleTitle,
                selectedRole === 'worker' && styles.roleTitleSelected,
              ]}>
                Worker
              </Text>
              <Text style={styles.roleDescription}>
                Field worker conducting ministry activities, Bible studies, and community outreach
              </Text>
              {selectedRole === 'worker' && (
                <View style={styles.checkmarkContainer}>
                  <MaterialIcons name="check-circle" size={24} color={COLORS.primary} />
                </View>
              )}
            </TouchableOpacity>

            {/* Team Leader Role */}
            <TouchableOpacity
              style={[
                styles.roleCard,
                selectedRole === 'team_leader' && styles.roleCardSelected,
              ]}
              onPress={() => handleSelectRole('team_leader')}
              activeOpacity={0.7}
            >
              <View style={[
                styles.roleIconContainer,
                selectedRole === 'team_leader' && styles.roleIconContainerSelected,
              ]}>
                <MaterialIcons 
                  name="groups" 
                  size={32} 
                  color={selectedRole === 'team_leader' ? COLORS.white : COLORS.secondary} 
                />
              </View>
              <Text style={[
                styles.roleTitle,
                selectedRole === 'team_leader' && styles.roleTitleSelected,
              ]}>
                Team Leader
              </Text>
              <Text style={styles.roleDescription}>
                Lead and coordinate ministry teams, manage territories, and oversee field operations
              </Text>
              {selectedRole === 'team_leader' && (
                <View style={styles.checkmarkContainer}>
                  <MaterialIcons name="check-circle" size={24} color={COLORS.secondary} />
                </View>
              )}
            </TouchableOpacity>
          </View>

          {/* Confirm Button */}
          <View style={styles.footer}>
            <TouchableOpacity
              style={[
                styles.confirmButton,
                !selectedRole && styles.confirmButtonDisabled,
              ]}
              onPress={handleConfirm}
              disabled={!selectedRole}
              activeOpacity={0.8}
            >
              <Text style={styles.confirmButtonText}>
                Continue
              </Text>
              <MaterialIcons name="arrow-forward" size={20} color={COLORS.white} />
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  container: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS['2xl'],
    width: '100%',
    maxWidth: 500,
    ...SHADOWS.xl,
  },
  header: {
    padding: SPACING['2xl'],
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  iconContainer: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: SPACING.lg,
    ...SHADOWS.md,
  },
  title: {
    fontSize: TYPOGRAPHY.sizes['2xl'],
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
    textAlign: 'center',
  },
  userName: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.secondary,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  rolesContainer: {
    padding: SPACING['2xl'],
    gap: SPACING.lg,
  },
  roleCard: {
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.xl,
    padding: SPACING.xl,
    borderWidth: 2,
    borderColor: 'transparent',
    position: 'relative',
  },
  roleCardSelected: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.white,
    ...SHADOWS.md,
  },
  roleIconContainer: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: COLORS.white,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  roleIconContainerSelected: {
    backgroundColor: COLORS.primary,
  },
  roleTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.bold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  roleTitleSelected: {
    color: COLORS.primary,
  },
  roleDescription: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    lineHeight: 20,
  },
  checkmarkContainer: {
    position: 'absolute',
    top: SPACING.lg,
    right: SPACING.lg,
  },
  footer: {
    padding: SPACING['2xl'],
    paddingTop: 0,
  },
  confirmButton: {
    flexDirection: 'row',
    height: 56,
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.lg,
    justifyContent: 'center',
    alignItems: 'center',
    gap: SPACING.sm,
    ...SHADOWS.md,
  },
  confirmButtonDisabled: {
    backgroundColor: COLORS.border.light,
    opacity: 0.5,
  },
  confirmButtonText: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.white,
  },
});

export default RoleSelectionModal;

