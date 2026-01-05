import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  Alert,
  RefreshControl,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { Header } from '../components';
import MinistryContactService from '../services/MinistryContactService';
import { MinistryContact } from '../types/ministryContact';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface MinistryContactListScreenProps {
  navigation: any;
}

const MinistryContactListScreen: React.FC<MinistryContactListScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [contacts, setContacts] = useState<MinistryContact[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadContacts();
  }, []);

  const loadContacts = async () => {
    if (!user) return;

    try {
      const contactsData = await MinistryContactService.getContactsForWorker(user.uid);
      setContacts(contactsData);
    } catch (error) {
      console.error('Error loading contacts:', error);
      Alert.alert('Error', 'Failed to load contacts');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadContacts();
    setRefreshing(false);
  };

  const handleSendContact = async (contact: MinistryContact, method: 'email' | 'phone' | 'letter' | 'visit') => {
    try {
      await MinistryContactService.sendContactInfo(contact.id, method);
      Alert.alert('Success', `Contact information sent via ${method}`);
      loadContacts(); // Refresh to show updated status
    } catch (error) {
      console.error('Error sending contact:', error);
      Alert.alert('Error', 'Failed to send contact information');
    }
  };

  const showSendOptions = (contact: MinistryContact) => {
    Alert.alert(
      'Send Contact Information',
      `Send information for ${contact.name}`,
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Email', onPress: () => handleSendContact(contact, 'email') },
        { text: 'Phone', onPress: () => handleSendContact(contact, 'phone') },
        { text: 'Letter', onPress: () => handleSendContact(contact, 'letter') },
      ]
    );
  };

  const getInterestsList = (contact: MinistryContact): string => {
    const interests = [];
    if (contact.personalBibleStudies) interests.push('Personal Bible Studies');
    if (contact.groupBibleStudies) interests.push('Group Bible Studies');
    if (contact.healthSeminar) interests.push('Health Seminar');
    if (contact.healthExpo) interests.push('Health Expo');
    if (contact.vbs) interests.push('VBS');
    if (contact.healthConsultation) interests.push('Health Consultation');
    
    return interests.length > 0 ? interests.join(', ') : 'No specific interests';
  };

  const renderContactCard = ({ item: contact }: { item: MinistryContact }) => (
    <View style={styles.contactCard}>
      <View style={styles.contactHeader}>
        <View style={styles.contactInfo}>
          <Text style={styles.contactName}>{contact.name}</Text>
          <Text style={styles.contactAddress}>{contact.address}</Text>
          {contact.email && (
            <Text style={styles.contactDetail}>📧 {contact.email}</Text>
          )}
          {contact.phone && (
            <Text style={styles.contactDetail}>📞 {contact.phone}</Text>
          )}
        </View>
        
        <View style={styles.contactActions}>
          <TouchableOpacity
            style={styles.actionButton}
            onPress={() => showSendOptions(contact)}
          >
            <MaterialIcons name="send" size={20} color={COLORS.primary} />
          </TouchableOpacity>
        </View>
      </View>

      <View style={styles.interestsSection}>
        <Text style={styles.interestsLabel}>Interests:</Text>
        <Text style={styles.interestsText}>{getInterestsList(contact)}</Text>
      </View>

      {contact.appointmentScheduled && contact.appointmentDate && (
        <View style={styles.appointmentSection}>
          <MaterialIcons name="event" size={16} color={COLORS.secondary} />
          <Text style={styles.appointmentText}>
            Appointment: {contact.appointmentDate.toLocaleDateString()} at {contact.appointmentTime}
          </Text>
        </View>
      )}

      {contact.contactSent && (
        <View style={styles.statusSection}>
          <MaterialIcons name="check-circle" size={16} color={COLORS.success} />
          <Text style={styles.statusText}>
            Contact sent via {contact.contactMethod} on {contact.contactSentAt?.toLocaleDateString()}
          </Text>
        </View>
      )}

      {contact.misc && (
        <View style={styles.notesSection}>
          <Text style={styles.notesLabel}>Notes:</Text>
          <Text style={styles.notesText}>{contact.misc}</Text>
        </View>
      )}

      <View style={styles.metaSection}>
        <Text style={styles.metaText}>
          Added: {contact.createdAt.toLocaleDateString()}
        </Text>
      </View>
    </View>
  );

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <MaterialIcons name="contacts" size={64} color={COLORS.text.secondary} />
      <Text style={styles.emptyTitle}>No Contacts Yet</Text>
      <Text style={styles.emptySubtitle}>
        Start adding ministry contacts to build your database
      </Text>
      <TouchableOpacity
        style={styles.addFirstButton}
        onPress={() => navigation.navigate('MinistryContact')}
      >
        <MaterialIcons name="add" size={20} color={COLORS.background.primary} />
        <Text style={styles.addFirstButtonText}>Add First Contact</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <Header
        title="Ministry Contacts"
        showBackButton
        onBackPress={() => navigation.goBack()}
        rightComponent={
          <TouchableOpacity
            style={styles.addButton}
            onPress={() => navigation.navigate('MinistryContact')}
          >
            <MaterialIcons name="add" size={24} color={COLORS.primary} />
          </TouchableOpacity>
        }
      />

      <FlatList
        data={contacts}
        keyExtractor={(item) => item.id}
        renderItem={renderContactCard}
        contentContainerStyle={styles.listContainer}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            colors={[COLORS.primary]}
            tintColor={COLORS.primary}
          />
        }
        ListEmptyComponent={!loading ? renderEmptyState : null}
      />

      {contacts.length > 0 && (
        <View style={styles.statsFooter}>
          <Text style={styles.statsText}>
            {contacts.length} contact{contacts.length !== 1 ? 's' : ''} • {' '}
            {contacts.filter(c => c.appointmentScheduled).length} appointment{contacts.filter(c => c.appointmentScheduled).length !== 1 ? 's' : ''} • {' '}
            {contacts.filter(c => c.contactSent).length} sent
          </Text>
        </View>
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  addButton: {
    padding: SPACING.sm,
  },
  listContainer: {
    padding: SPACING.md,
    paddingBottom: SPACING.xl,
  },
  contactCard: {
    backgroundColor: COLORS.background.surface,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    ...SHADOWS.sm,
  },
  contactHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  contactInfo: {
    flex: 1,
  },
  contactName: {
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  contactAddress: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  contactDetail: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    marginBottom: SPACING.xs,
  },
  contactActions: {
    flexDirection: 'row',
  },
  actionButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.primary + '20',
  },
  interestsSection: {
    marginBottom: SPACING.md,
  },
  interestsLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  interestsText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    lineHeight: 18,
  },
  appointmentSection: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.secondary + '20',
    padding: SPACING.sm,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
  },
  appointmentText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.secondary,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  statusSection: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.success + '20',
    padding: SPACING.sm,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.sm,
  },
  statusText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.success,
    marginLeft: SPACING.xs,
    fontWeight: TYPOGRAPHY.weights.medium,
  },
  notesSection: {
    marginBottom: SPACING.sm,
  },
  notesLabel: {
    fontSize: TYPOGRAPHY.sizes.sm,
    fontWeight: TYPOGRAPHY.weights.medium,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  notesText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    fontStyle: 'italic',
  },
  metaSection: {
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
    paddingTop: SPACING.sm,
  },
  metaText: {
    fontSize: TYPOGRAPHY.sizes.xs,
    color: COLORS.text.secondary,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING.xl * 2,
  },
  emptyTitle: {
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.semibold,
    color: COLORS.text.primary,
    marginTop: SPACING.lg,
    marginBottom: SPACING.sm,
  },
  emptySubtitle: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
    paddingHorizontal: SPACING.xl,
  },
  addFirstButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    ...SHADOWS.sm,
  },
  addFirstButtonText: {
    fontSize: TYPOGRAPHY.sizes.md,
    color: COLORS.background.primary,
    fontWeight: TYPOGRAPHY.weights.semibold,
    marginLeft: SPACING.xs,
  },
  statsFooter: {
    backgroundColor: COLORS.background.surface,
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
  },
  statsText: {
    fontSize: TYPOGRAPHY.sizes.sm,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
});

export default MinistryContactListScreen;
