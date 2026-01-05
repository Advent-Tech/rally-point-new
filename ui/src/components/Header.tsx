import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Image, Platform } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { useAuth } from '../contexts/AuthContext';
import { HeaderProps } from '../types';
import { COLORS, TYPOGRAPHY, SPACING, SHADOWS } from '../constants/Colors';
import { ProfileService } from '../services/ProfileService';

// Extended HeaderProps to support the new modern design
interface ModernHeaderProps extends Omit<HeaderProps, 'title'> {
  title?: string;
  showMenu?: boolean;
  showLogo?: boolean;
  showProfile?: boolean;
  onMenuPress?: () => void;
  onProfilePress?: () => void;
}

const Header: React.FC<ModernHeaderProps> = ({
  title,
  showBackButton = false,
  onBackPress,
  rightComponent,
  showNotifications = true,
  showMenu = true,
  showLogo = true,
  showProfile = true,
  onMenuPress,
  onProfilePress,
}) => {
  const navigation = useNavigation();
  const { user } = useAuth();
  const [profilePhotoUrl, setProfilePhotoUrl] = useState<string | null>(null);
  const [profileLoaded, setProfileLoaded] = useState<boolean>(false);

  // Load user's profile photo
  useEffect(() => {
    const loadProfilePhoto = async () => {
      if (user?.uid) {
        try {
          // Check ProfileService for custom uploaded photo
          const profileData = await ProfileService.getUserProfile(user.uid);
          if (profileData?.profilePhotoUrl) {
            console.log('🔍 Header: Profile photo URL found:', profileData.profilePhotoUrl);
            console.log('🌐 Platform:', Platform.OS);
            setProfilePhotoUrl(profileData.profilePhotoUrl);
          } else {
            console.log('📷 Header: No profile photo URL found');
            setProfilePhotoUrl(null);
          }
          setProfileLoaded(true);
        } catch (error) {
          console.log('❌ Header: Error loading profile photo:', error);
          setProfilePhotoUrl(null);
          setProfileLoaded(true);
        }
      }
    };

    loadProfilePhoto();
  }, [user?.uid]);

  const handleNotificationPress = () => {
    (navigation as any).navigate('Notifications');
  };

  const handleMenuPress = () => {
    if (onMenuPress) {
      onMenuPress();
    } else {
      // Default menu action - could open drawer or navigate
      console.log('Menu pressed');
    }
  };

  const handleProfilePress = () => {
    if (onProfilePress) {
      onProfilePress();
    } else {
      // Default profile action - navigate to Profile screen
      (navigation as any).navigate('Profile');
    }
  };

  return (
    <View style={styles.container}>
      {/* Left Section */}
      <View style={styles.leftSection}>
        {showBackButton ? (
          <TouchableOpacity
            onPress={onBackPress || (() => navigation.goBack())}
            style={styles.iconButton}
            activeOpacity={0.7}
          >
            <MaterialIcons
              name="arrow-back"
              size={24}
              color={COLORS.textInverse}
            />
          </TouchableOpacity>
        ) : showMenu ? (
          <TouchableOpacity
            onPress={handleMenuPress}
            style={styles.iconButton}
            activeOpacity={0.7}
          >
            <Image
              source={require('../../assets/menuIcon.png')}
              style={styles.iconImage}
              resizeMode="contain"
            />
          </TouchableOpacity>
        ) : null}

        {/* Only show logo when NOT showing back button */}
        {showLogo && !showBackButton && (
          <View style={styles.logoContainer}>
            <Image
              source={require('../../assets/appLogo.png')}
              style={styles.logo}
              resizeMode="contain"
            />
          </View>
        )}

        {title && (
          <Text style={styles.title}>
            {title}
          </Text>
        )}
      </View>

      {/* Right Section */}
      <View style={styles.rightSection}>
        {showNotifications && (
          <TouchableOpacity
            onPress={handleNotificationPress}
            style={styles.iconButton}
            activeOpacity={0.7}
          >
            <Image
              source={require('../../assets/notificationIcon.png')}
              style={styles.iconImage}
              resizeMode="contain"
            />
          </TouchableOpacity>
        )}

        {showProfile && (
          <TouchableOpacity
            onPress={handleProfilePress}
            style={styles.profileButton}
            activeOpacity={0.7}
          >
            <View style={[styles.profileAvatar, (!profilePhotoUrl && profileLoaded) && styles.defaultProfileAvatar]}>
              {profilePhotoUrl ? (
                <Image
                  source={{ uri: profilePhotoUrl }}
                  style={styles.profileImage}
                  resizeMode="cover"
                  onError={(error) => {
                    console.log('❌ Header profile image failed to load:', error);
                    setProfilePhotoUrl(null); // Fallback to icon
                  }}
                  onLoad={() => {
                    console.log('✅ Header profile image loaded successfully');
                  }}
                />
              ) : profileLoaded ? (
                <MaterialIcons
                  name="person"
                  size={24}
                  color={COLORS.primary}
                />
              ) : (
                <Text style={styles.profileInitial}>
                  {user?.displayName?.charAt(0)?.toUpperCase() ||
                   user?.email?.charAt(0)?.toUpperCase() || 'U'}
                </Text>
              )}
            </View>
          </TouchableOpacity>
        )}

        {rightComponent}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: 'transparent', // App theme background color
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    paddingTop: SPACING.xl, // Extra padding for status bar
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    ...SHADOWS.sm,
  },
  leftSection: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  iconButton: {
    backgroundColor: COLORS.white,
    width: 40,
    height: 40,
    borderRadius: 20, // Perfect circle (width/2)
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
    ...SHADOWS.sm,
  },
  iconImage: {
    width: 20,
    height: 20,
    tintColor: COLORS.text.primary,
  },
  logoContainer: {
    marginLeft: SPACING.xs,
  },
  logo: {
    width: 52,
    height: 52,
  },
  title: {
    color: COLORS.text.primary,
    fontSize: TYPOGRAPHY.sizes.xl,
    fontWeight: TYPOGRAPHY.weights.semibold,
    marginLeft: SPACING.md,
    flex: 1,
  },
  rightSection: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  profileButton: {
    marginLeft: SPACING.sm,
  },
  profileAvatar: {
    backgroundColor: '#FF6B35', // Orange color matching the design
    width: 40,
    height: 40,
    borderRadius: 20, // Perfect circle (width/2)
    justifyContent: 'center',
    alignItems: 'center',
    ...SHADOWS.sm,
    overflow: 'hidden', // Ensure image stays within circular bounds
  },
  defaultProfileAvatar: {
    backgroundColor: COLORS.white, // White background for default icon
  },
  profileImage: {
    width: 40,
    height: 40,
    borderRadius: 20,
    overflow: 'hidden',
  },
  profileInitial: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.sizes.lg,
    fontWeight: TYPOGRAPHY.weights.semibold,
  },
});

export default Header;
