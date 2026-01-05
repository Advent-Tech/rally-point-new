import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  Switch,
  Alert
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import { ProfileService } from '../services/ProfileService';
import { Header } from '../components';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { NotificationPreferences, ProfileSettings } from '../types/profile';

interface NotificationSettingsScreenProps {
  navigation: any;
}

const NotificationSettingsScreen: React.FC<NotificationSettingsScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [settings, setSettings] = useState<ProfileSettings | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (user) {
      loadSettings();
    }
  }, [user]);

  const loadSettings = async () => {
    if (!user) return;

    try {
      setLoading(true);
      const settingsData = await ProfileService.getProfileSettings(user.uid);
      setSettings(settingsData);
    } catch (error) {
      console.error('Error loading settings:', error);
      Alert.alert('Error', 'Failed to load notification settings.');
    } finally {
      setLoading(false);
    }
  };

  const updateNotificationSetting = async (
    key: keyof NotificationPreferences,
    value: boolean
  ) => {
    if (!user || !settings) return;

    try {
      setSaving(true);
      
      const updatedSettings = {
        ...settings,
        notifications: {
          ...settings.notifications,
          [key]: value
        }
      };

      const result = await ProfileService.updateProfileSettings(user.uid, updatedSettings);
      
      if (result.success) {
        setSettings(updatedSettings);
      } else {
        Alert.alert('Error', 'Failed to update notification settings.');
      }
    } catch (error) {
      console.error('Error updating notification setting:', error);
      Alert.alert('Error', 'Failed to update notification settings.');
    } finally {
      setSaving(false);
    }
  };

  const renderSettingItem = (
    title: string,
    description: string,
    key: keyof NotificationPreferences,
    value: boolean
  ) => (
    <View style={styles.settingItem}>
      <View style={styles.settingContent}>
        <Text style={styles.settingTitle}>{title}</Text>
        <Text style={styles.settingDescription}>{description}</Text>
      </View>
      <Switch
        value={value}
        onValueChange={(newValue) => updateNotificationSetting(key, newValue)}
        trackColor={{ false: COLORS.lightGray, true: COLORS.primary + '40' }}
        thumbColor={value ? COLORS.primary : COLORS.darkGray}
        disabled={saving}
      />
    </View>
  );

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
        <Header title="Notification Settings" showBackButton onBackPress={() => navigation.goBack()} />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading settings...</Text>
        </View>
      </SafeAreaView>
    );
  }

  if (!settings) {
    return (
      <SafeAreaView style={styles.container}>
        <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
        <Header title="Notification Settings" showBackButton onBackPress={() => navigation.goBack()} />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Failed to load settings</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={COLORS.white} />
      <Header title="Notification Settings" showBackButton onBackPress={() => navigation.goBack()} />
      
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>General Notifications</Text>
          
          {renderSettingItem(
            'Push Notifications',
            'Receive push notifications on your device',
            'pushNotifications',
            settings.notifications.pushNotifications
          )}
          
          {renderSettingItem(
            'Email Notifications',
            'Receive notifications via email',
            'emailNotifications',
            settings.notifications.emailNotifications
          )}
          
          {renderSettingItem(
            'SMS Notifications',
            'Receive notifications via text message',
            'smsNotifications',
            settings.notifications.smsNotifications
          )}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Work Notifications</Text>
          
          {renderSettingItem(
            'Survey Assignments',
            'Get notified when new surveys are assigned to you',
            'surveyAssignments',
            settings.notifications.surveyAssignments
          )}
          
          {renderSettingItem(
            'Territory Updates',
            'Get notified about territory changes and assignments',
            'territoryUpdates',
            settings.notifications.territoryUpdates
          )}
          
          {renderSettingItem(
            'Team Messages',
            'Receive notifications for team messages and announcements',
            'teamMessages',
            settings.notifications.teamMessages
          )}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>System Notifications</Text>
          
          {renderSettingItem(
            'System Updates',
            'Get notified about app updates and maintenance',
            'systemUpdates',
            settings.notifications.systemUpdates
          )}
          
          {renderSettingItem(
            'Emergency Alerts',
            'Receive critical emergency and safety alerts',
            'emergencyAlerts',
            settings.notifications.emergencyAlerts
          )}
        </View>

        <View style={styles.helpSection}>
          <Text style={styles.helpTitle}>About Notifications</Text>
          <Text style={styles.helpText}>
            You can customize which notifications you receive to stay informed about what matters most to you. 
            Emergency alerts are highly recommended for your safety during field work.
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: SPACING.xl,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.darkGray,
  },
  section: {
    backgroundColor: COLORS.white,
    marginBottom: SPACING.md,
    ...SHADOWS.small,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h4,
    color: COLORS.primary,
    fontWeight: 'bold',
    padding: SPACING.lg,
    paddingBottom: SPACING.md,
  },
  settingItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.borderFlat,
  },
  settingContent: {
    flex: 1,
    marginRight: SPACING.md,
  },
  settingTitle: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    fontWeight: '500',
    marginBottom: 4,
  },
  settingDescription: {
    ...TYPOGRAPHY.caption,
    color: COLORS.darkGray,
    lineHeight: 16,
  },
  helpSection: {
    backgroundColor: COLORS.white,
    margin: SPACING.md,
    padding: SPACING.lg,
    borderRadius: RADIUS.md,
    ...SHADOWS.small,
  },
  helpTitle: {
    ...TYPOGRAPHY.h4,
    color: COLORS.primary,
    fontWeight: 'bold',
    marginBottom: SPACING.md,
  },
  helpText: {
    ...TYPOGRAPHY.body,
    color: COLORS.darkGray,
    lineHeight: 20,
  },
});

export default NotificationSettingsScreen;
