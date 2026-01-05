import React from 'react';
import { View, Text, Modal, TouchableOpacity, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

export interface GoogleAccount {
  id: string;
  email: string;
  name: string;
  photoUrl?: string;
}

interface GoogleAccountPickerProps {
  visible: boolean;
  onSelectAccount: (account: GoogleAccount) => void;
  onCancel: () => void;
}

const GoogleAccountPicker: React.FC<GoogleAccountPickerProps> = ({
  visible,
  onSelectAccount,
  onCancel,
}) => {
  // Mock account for now - in production this would show real Google accounts
  const mockAccount: GoogleAccount = {
    id: '1',
    email: 'user@gmail.com',
    name: 'User',
  };

  const handleSelectAccount = () => {
    onSelectAccount(mockAccount);
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onCancel}
    >
      <View style={styles.overlay}>
        <View style={styles.container}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.title}>Choose an account</Text>
            <TouchableOpacity onPress={onCancel} style={styles.closeButton}>
              <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
            </TouchableOpacity>
          </View>

          {/* Account Option */}
          <TouchableOpacity
            style={styles.accountOption}
            onPress={handleSelectAccount}
          >
            <View style={styles.accountIcon}>
              <MaterialIcons name="account-circle" size={40} color={COLORS.primary} />
            </View>
            <View style={styles.accountInfo}>
              <Text style={styles.accountName}>{mockAccount.name}</Text>
              <Text style={styles.accountEmail}>{mockAccount.email}</Text>
            </View>
          </TouchableOpacity>

          {/* Use Another Account */}
          <TouchableOpacity
            style={styles.anotherAccountButton}
            onPress={handleSelectAccount}
          >
            <MaterialIcons name="person-add" size={24} color={COLORS.primary} />
            <Text style={styles.anotherAccountText}>Use another account</Text>
          </TouchableOpacity>

          {/* Cancel Button */}
          <TouchableOpacity style={styles.cancelButton} onPress={onCancel}>
            <Text style={styles.cancelButtonText}>Cancel</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  container: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.lg,
    width: '90%',
    maxWidth: 400,
    padding: SPACING.xl,
    ...SHADOWS.large,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  title: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
  },
  closeButton: {
    padding: SPACING.xs,
  },
  accountOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.secondary,
    marginBottom: SPACING.md,
  },
  accountIcon: {
    marginRight: SPACING.md,
  },
  accountInfo: {
    flex: 1,
  },
  accountName: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  accountEmail: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
  anotherAccountButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.secondary,
    marginBottom: SPACING.lg,
  },
  anotherAccountText: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    marginLeft: SPACING.md,
  },
  cancelButton: {
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.secondary,
    alignItems: 'center',
  },
  cancelButtonText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
  },
});

export default GoogleAccountPicker;

