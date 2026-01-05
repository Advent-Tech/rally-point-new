import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Platform,
  ActionSheetIOS,
  Image
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface ProfilePhotoUploadProps {
  currentPhotoUrl?: string;
  onPhotoSelected: (uri: string) => void;
  onPhotoRemoved: () => void;
  size?: number;
  disabled?: boolean;
}

const ProfilePhotoUpload: React.FC<ProfilePhotoUploadProps> = ({
  currentPhotoUrl,
  onPhotoSelected,
  onPhotoRemoved,
  size = 120,
  disabled = false
}) => {
  const [uploading, setUploading] = useState(false);

  const requestPermissions = async () => {
    if (Platform.OS !== 'web') {
      const { status: cameraStatus } = await ImagePicker.requestCameraPermissionsAsync();
      const { status: libraryStatus } = await ImagePicker.requestMediaLibraryPermissionsAsync();

      if (cameraStatus !== 'granted' || libraryStatus !== 'granted') {
        Alert.alert(
          'Permissions Required',
          'Please grant camera and photo library permissions to upload a profile photo.',
          [{ text: 'OK' }]
        );
        return false;
      }
    }
    return true;
  };

  const showImagePicker = async () => {
    if (disabled || uploading) return;

    const hasPermissions = await requestPermissions();
    if (!hasPermissions) return;

    const options = [
      'Take Photo',
      'Choose from Library',
      ...(currentPhotoUrl ? ['Remove Photo'] : []),
      'Cancel'
    ];

    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          options,
          cancelButtonIndex: options.length - 1,
          destructiveButtonIndex: currentPhotoUrl ? options.length - 2 : undefined,
        },
        (buttonIndex) => {
          handleImagePickerResponse(buttonIndex, options);
        }
      );
    } else {
      // For Android, show a simple alert
      Alert.alert(
        'Select Photo',
        'Choose how you want to select your profile photo',
        [
          { text: 'Take Photo', onPress: () => handleImagePickerResponse(0, options) },
          { text: 'Choose from Library', onPress: () => handleImagePickerResponse(1, options) },
          ...(currentPhotoUrl ? [{
            text: 'Remove Photo',
            style: 'destructive' as const,
            onPress: () => handleImagePickerResponse(2, options)
          }] : []),
          { text: 'Cancel', style: 'cancel' as const }
        ]
      );
    }
  };

  const handleImagePickerResponse = async (buttonIndex: number, options: string[]) => {
    const selectedOption = options[buttonIndex];

    if (selectedOption === 'Cancel') return;

    if (selectedOption === 'Remove Photo') {
      onPhotoRemoved();
      return;
    }

    setUploading(true);

    try {
      let result;

      if (selectedOption === 'Take Photo') {
        result = await ImagePicker.launchCameraAsync({
          mediaTypes: ImagePicker.MediaTypeOptions.Images,
          allowsEditing: true,
          aspect: [1, 1],
          quality: 0.8,
        });
      } else if (selectedOption === 'Choose from Library') {
        result = await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ImagePicker.MediaTypeOptions.Images,
          allowsEditing: true,
          aspect: [1, 1],
          quality: 0.8,
        });
      }

      if (result && !result.canceled && result.assets && result.assets[0]) {
        const imageUri = result.assets[0].uri;
        onPhotoSelected(imageUri);
      }
    } catch (error) {
      console.error('Error picking image:', error);
      Alert.alert('Error', 'Failed to select image. Please try again.');
    } finally {
      setUploading(false);
    }
  };

  const renderPhotoContent = () => {
    if (currentPhotoUrl) {
      return (
        <Image
          source={{ uri: currentPhotoUrl }}
          style={[styles.photo, { width: size, height: size, borderRadius: size / 2 }]}
          resizeMode="cover"
          onError={(error) => {
            console.log('❌ Profile image failed to load:', error);
          }}
          onLoad={() => {
            console.log('✅ Profile image loaded successfully');
          }}
        />
      );
    }

    return (
      <View style={[styles.placeholder, { width: size, height: size, borderRadius: size / 2 }]}>
        <MaterialIcons name="person" size={size * 0.4} color={COLORS.darkGray} />
      </View>
    );
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={[styles.photoContainer, disabled && styles.disabled]}
        onPress={showImagePicker}
        disabled={disabled || uploading}
        activeOpacity={0.8}
      >
        {renderPhotoContent()}
        
        {/* Upload overlay */}
        <View style={[styles.overlay, { width: size, height: size, borderRadius: size / 2 }]}>
          {uploading ? (
            <MaterialIcons name="hourglass-empty" size={24} color={COLORS.white} />
          ) : (
            <MaterialIcons name="camera-alt" size={24} color={COLORS.white} />
          )}
        </View>

        {/* Edit button */}
        <View style={[styles.editButton, { bottom: size * 0.05, right: size * 0.05 }]}>
          <MaterialIcons name="edit" size={16} color={COLORS.white} />
        </View>
      </TouchableOpacity>

      <Text style={styles.helpText}>
        {uploading ? 'Uploading...' : 'Tap to change photo'}
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
  },
  photoContainer: {
    position: 'relative',
    marginBottom: SPACING.sm,
  },
  photo: {
    backgroundColor: COLORS.lightGray,
    overflow: 'hidden',
  },
  placeholder: {
    backgroundColor: COLORS.white,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: COLORS.lightGray,
  },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
    justifyContent: 'center',
    alignItems: 'center',
    opacity: 0,
  },
  editButton: {
    position: 'absolute',
    backgroundColor: COLORS.secondary,
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: COLORS.white,
    ...SHADOWS.small,
  },
  helpText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.darkGray,
    textAlign: 'center',
  },
  disabled: {
    opacity: 0.6,
  },
});

// Add touch feedback for the overlay
const TouchablePhotoContainer = StyleSheet.create({
  photoContainer: {
    ...styles.photoContainer,
  },
});

// Override styles for active state
StyleSheet.create({
  'photoContainer:active overlay': {
    opacity: 1,
  },
});

export default ProfilePhotoUpload;
