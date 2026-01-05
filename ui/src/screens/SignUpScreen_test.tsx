import React, { useState, useEffect } from 'react';
import { View, Text, ScrollView, Alert, TouchableOpacity, StyleSheet, SafeAreaView, Platform, Image, TextInput, Dimensions, ActivityIndicator, Clipboard } from 'react-native';
import { useForm, Controller } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import { MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { Button, Input } from '../components';
import { SignUpFormData, UserRole } from '../types';
import { signUpSchema } from '../utils/validation';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import teamSearchService from '../services/TeamSearchService';
import type { Team } from '../services/TeamSearchService';

// Conditional import for Picker
let Picker: any;
if (Platform.OS !== 'web') {
  Picker = require('@react-native-picker/picker').Picker;
}

interface SignUpScreenProps {
  navigation: any;
}

interface ExtendedSignUpFormData extends SignUpFormData {
  teamId?: string;
  teamName?: string;
  teamLeaderId?: string;
  teamLeaderName?: string;
  skills?: string;
  selfDescription?: string;
}

const SignUpScreen: React.FC<SignUpScreenProps> = ({ navigation }) => {
  const { signUp } = useAuth();
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  // Team search states
  const [teamSearchText, setTeamSearchText] = useState('');
  const [teamSearchResults, setTeamSearchResults] = useState<Team[]>([]);
  const [teamSearchLoading, setTeamSearchLoading] = useState(false);
  const [showTeamDropdown, setShowTeamDropdown] = useState(false);
  const [selectedTeam, setSelectedTeam] = useState<Team | null>(null);

  // Additional fields
  const [skills, setSkills] = useState('');
  const [selfDescription, setSelfDescription] = useState('');
  const [descriptionCharCount, setDescriptionCharCount] = useState(0);

  const {
    control,
    handleSubmit,
    formState: { errors },
    watch,
  } = useForm<SignUpFormData>({
    resolver: yupResolver(signUpSchema),
    defaultValues: {
      email: '',
      password: '',
      confirmPassword: '',
      displayName: '',
      role: 'worker',
    },
  });

  const selectedRole = watch('role');

  // Debounced team search
  useEffect(() => {
    if (selectedRole !== 'worker') {
      setTeamSearchText('');
      setTeamSearchResults([]);
      setSelectedTeam(null);
      return;
    }

    if (teamSearchText.length < 2) {
      setTeamSearchResults([]);
      return;
    }

    const delayDebounce = setTimeout(async () => {
      setTeamSearchLoading(true);
      try {
        const results = await teamSearchService.searchTeams(teamSearchText);
        setTeamSearchResults(results);
      } catch (error) {
        console.error('Team search error:', error);
        setTeamSearchResults([]);
      } finally {
        setTeamSearchLoading(false);
      }
    }, 300);

    return () => clearTimeout(delayDebounce);
  }, [teamSearchText, selectedRole]);

  const handleTeamSelect = (team: Team) => {
    setSelectedTeam(team);
    setTeamSearchText(team.teamName);
    setShowTeamDropdown(false);
  };

  const handlePasteTeamLink = async () => {
    try {
      const clipboardContent = await Clipboard.getString();

      // Parse team link formats:
      // rallypoint://team/{teamId}
      // https://rallypoint.app/team/{teamId}
      let teamId: string | null = null;

      if (clipboardContent.startsWith('rallypoint://team/')) {
        teamId = clipboardContent.replace('rallypoint://team/', '');
      } else if (clipboardContent.includes('rallypoint.app/team/')) {
        const match = clipboardContent.match(/rallypoint\.app\/team\/([^/?]+)/);
        if (match) teamId = match[1];
      }

      if (!teamId) {
        Alert.alert('Invalid Link', 'The clipboard does not contain a valid team link.');
        return;
      }

      setTeamSearchLoading(true);
      const team = await teamSearchService.getTeamById(teamId);

      if (team) {
        setSelectedTeam(team);
        setTeamSearchText(team.teamName);
        Alert.alert(
          'Team Verified',
          `Team: ${team.teamName}\nLeader: ${team.leaderName || 'Unknown'}`,
          [{ text: 'OK' }]
        );
      } else {
        Alert.alert('Invalid Link', 'Team not found. Please check the link and try again.');
      }
    } catch (error) {
      console.error('Paste team link error:', error);
      Alert.alert('Error', 'Failed to verify team link. Please try again.');
    } finally {
      setTeamSearchLoading(false);
    }
  };

  const onSubmit = async (data: SignUpFormData) => {
    // Validate team selection for workers
    if (data.role === 'worker' && !selectedTeam) {
      Alert.alert('Team Required', 'Please select a team or paste a team link.');
      return;
    }

    setLoading(true);
    try {
      // Create the user account with backend API
      await signUp(data.email, data.password, data.role, data.displayName);

      // TODO: After successful registration, we might want to update the profile
      // with additional fields like team, skills, selfDescription
      // This would require additional API endpoints

      Alert.alert(
        'Success!',
        'Your account has been created successfully.',
        [{ text: 'OK', onPress: () => navigation.navigate('SignIn') }]
      );
    } catch (error: any) {
      console.error('Sign up error:', error);
      Alert.alert('Sign Up Error', error.message || 'An error occurred during sign up');
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      {/* Simple test ScrollView */}
      <ScrollView style={{ flex: 1, backgroundColor: 'yellow' }}>
        <View style={{ height: 200, backgroundColor: 'red', margin: 20 }}>
          <Text style={{ color: 'white', textAlign: 'center', marginTop: 100 }}>Test Box 1</Text>
        </View>
        <View style={{ height: 200, backgroundColor: 'blue', margin: 20 }}>
          <Text style={{ color: 'white', textAlign: 'center', marginTop: 100 }}>Test Box 2</Text>
        </View>
        <View style={{ height: 200, backgroundColor: 'green', margin: 20 }}>
          <Text style={{ color: 'white', textAlign: 'center', marginTop: 100 }}>Test Box 3</Text>
        </View>
        <View style={{ height: 200, backgroundColor: 'purple', margin: 20 }}>
          <Text style={{ color: 'white', textAlign: 'center', marginTop: 100 }}>Test Box 4 - Should be able to scroll to see this</Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});

export default SignUpScreen;
