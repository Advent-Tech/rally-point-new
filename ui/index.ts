// Import gesture handler FIRST (critical for React Navigation)
import 'react-native-gesture-handler';

// Import polyfills
import './src/polyfills';

import { registerRootComponent } from 'expo';
import { Platform } from 'react-native';
import App from './App';

// Import global CSS only for web (React Native doesn't support CSS imports)
if (Platform.OS === 'web') {
  require('./global.css');
}

console.log('📱 Rally Point - Starting app...');
console.log('🔧 Platform:', Platform.OS);
console.log('🔧 DEV mode:', __DEV__);

// registerRootComponent calls AppRegistry.registerComponent('main', () => App);
// It also ensures that whether you load the app in Expo Go or in a native build,
// the environment is set up appropriately
registerRootComponent(App);
