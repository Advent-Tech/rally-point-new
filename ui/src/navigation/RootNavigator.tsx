import React, { useEffect, useRef } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { View, ActivityIndicator, StyleSheet, Platform } from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import AuthNavigator from './AuthNavigator';
import MainNavigator from './MainNavigator';
import { RootStackParamList } from '../types';
import { TeamService } from '../services/TeamService';

const Stack = createStackNavigator<RootStackParamList>();

// Linking configuration for deep links and web URLs
const linking = {
  prefixes: ['http://localhost:19006', 'https://rallypoint.app', 'rallypoint://'],
  config: {
    screens: {
      Auth: {
        screens: {
          SignIn: 'signin',
          SignUp: 'signup',
        },
      },
      Main: {
        screens: {
          JoinTeam: 'join-team',
          AdminTeamManagement: 'admin/teams',
          TeamLeaderWorkerManagement: 'team-leader/workers',
        },
      },
    },
  },
};

const RootNavigator: React.FC = () => {
  const { user, loading } = useAuth();
  const navigationRef = useRef<any>(null);

  // Handle URL-based team invites on web
  useEffect(() => {
    if (Platform.OS === 'web' && typeof window !== 'undefined') {
      const handleURLChange = () => {
        const teamInfo = TeamService.getTeamInfoFromURL();

        if (teamInfo && navigationRef.current) {
          console.log('Team invite detected in URL:', teamInfo);

          // If user is logged in, navigate to JoinTeam screen
          if (user) {
            setTimeout(() => {
              let origin = 'http://localhost:19006';
              try {
                if (typeof window !== 'undefined' && window.location && window.location.origin) {
                  origin = window.location.origin;
                }
              } catch (error) {
                console.warn('Error accessing window.location.origin in RootNavigator:', error);
              }
              
              navigationRef.current?.navigate('Main', {
                screen: 'JoinTeam',
                params: {
                  inviteLink: `${origin}/join-team?teamId=${teamInfo.teamId}&teamName=${teamInfo.teamName}`
                },
              });
            }, 500);
          } else {
            // Store invite link in sessionStorage for after login (web only)
            if (typeof sessionStorage !== 'undefined') {
              sessionStorage.setItem('pendingTeamInvite', JSON.stringify(teamInfo));
              console.log('User not logged in, storing invite for after login');
            }
          }
        }
      };

      // Check on mount
      handleURLChange();

      // Listen for URL changes (for SPA navigation)
      window.addEventListener('popstate', handleURLChange);

      return () => {
        window.removeEventListener('popstate', handleURLChange);
      };
    }
  }, [user]);

  // Handle pending team invite after login
  useEffect(() => {
    if (Platform.OS === 'web' && user && navigationRef.current && typeof sessionStorage !== 'undefined') {
      const pendingInvite = sessionStorage.getItem('pendingTeamInvite');

      if (pendingInvite) {
        try {
          const teamInfo = JSON.parse(pendingInvite);
          console.log('Processing pending team invite after login:', teamInfo);

          sessionStorage.removeItem('pendingTeamInvite');

          setTimeout(() => {
            let origin = 'http://localhost:19006';
            try {
              if (typeof window !== 'undefined' && window.location && window.location.origin) {
                origin = window.location.origin;
              }
            } catch (error) {
              console.warn('Error accessing window.location.origin in pending invite:', error);
            }
            
            navigationRef.current?.navigate('Main', {
              screen: 'JoinTeam',
              params: {
                inviteLink: `${origin}/join-team?teamId=${teamInfo.teamId}&teamName=${teamInfo.teamName}`
              },
            });
          }, 1000);
        } catch (error) {
          console.error('Error processing pending invite:', error);
          if (typeof sessionStorage !== 'undefined') {
            sessionStorage.removeItem('pendingTeamInvite');
          }
        }
      }
    }
  }, [user]);

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  return (
    <NavigationContainer ref={navigationRef} linking={linking}>
      <Stack.Navigator
        screenOptions={{
          headerShown: false,
        }}
      >
        {user ? (
          <Stack.Screen name="Main" component={MainNavigator} />
        ) : (
          <Stack.Screen name="Auth" component={AuthNavigator} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#ffffff',
  },
});

export default RootNavigator;
