// Web polyfills for React Native modules
import { Platform } from 'react-native';

// Polyfill for missing Platform utilities
if (Platform.OS === 'web') {
  // Mock PaperUIManager for web
  if (!global.PaperUIManager) {
    global.PaperUIManager = {
      measure: () => {},
      measureInWindow: () => {},
      measureLayout: () => {},
      setJSResponder: () => {},
      clearJSResponder: () => {},
    };
  }

  // Mock other missing utilities
  if (!global.__DEV__) {
    global.__DEV__ = process.env.NODE_ENV !== 'production';
  }
}

export default {};
