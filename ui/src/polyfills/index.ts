/**
 * Polyfills for Production Build
 * Minimal polyfills to ensure compatibility
 */

// Log initialization
console.log('🔧 Initializing polyfills...');

// Polyfill for global object (web compatibility)
if (typeof global === 'undefined') {
  (window as any).global = window;
}

// Polyfill for process.env (if needed)
if (typeof process === 'undefined') {
  (global as any).process = { env: {} };
}

// Suppress specific warnings in production
if (!__DEV__) {
  const originalWarn = console.warn;
  const originalError = console.error;

  console.warn = (...args: any[]) => {
    const message = args[0];
    if (
      typeof message === 'string' &&
      (message.includes('Require cycle:') ||
        message.includes('ViewPropTypes will be removed') ||
        message.includes('ColorPropType will be removed'))
    ) {
      return;
    }
    originalWarn(...args);
  };

  console.error = (...args: any[]) => {
    const message = args[0];
    if (
      typeof message === 'string' &&
      message.includes('Warning: ')
    ) {
      return;
    }
    originalError(...args);
  };
}

console.log('✅ Polyfills initialized');

export {};

