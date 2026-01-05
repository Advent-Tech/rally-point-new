// Rally Point Brand Colors
export const COLORS = {
  // Primary Brand Colors
  primary: '#002b5b',      // Navy Blue
  secondary: '#d7a638',    // Gold
  accent: '#d7a638',

  // Supporting Colors
  white: '#ffffff',
  lightGray: '#f1f5f9',
  darkGray: '#64748b',

  // Semantic Colors
  success: '#10b981',
  warning: '#f59e0b',
  error: '#ef4444',
  info: '#3b82f6',

  // Nested structure for survey components
  background: {
    primary: '#ffffff',
    secondary: '#f8fafc',
    surface: '#ffffff',
    disabled: '#f1f5f9',
    success: '#ecfdf5',
  },

  text: {
    primary: '#002b5b',
    secondary: '#64748b',
    disabled: '#94a3b8',
    placeholder: '#94a3b8',
  },

  border: {
    default: '#e2e8f0',
    light: '#f1f5f9',
    dark: '#cbd5e1',
  },

  // Legacy flat structure (for backward compatibility)
  backgroundSecondary: '#f8fafc',
  backgroundTertiary: '#f1f5f9',

  // Text Colors
  textPrimary: '#002b5b',
  textSecondary: '#64748b',
  textTertiary: '#94a3b8',
  textInverse: '#ffffff',

  // Border Colors (legacy)
  borderFlat: '#e2e8f0',
  borderLight: '#f1f5f9',
  borderDark: '#cbd5e1',
  
  // Shadow Colors
  shadow: 'rgba(0, 43, 91, 0.1)',
  shadowDark: 'rgba(0, 43, 91, 0.2)',
  
  // Status Colors
  delivered: '#10b981',
  pending: '#f59e0b',
  failed: '#ef4444',
  interested: '#3b82f6',
  notHome: '#8b5cf6',
  
  // Overlay Colors
  overlay: 'rgba(0, 43, 91, 0.5)',
  overlayLight: 'rgba(0, 43, 91, 0.1)',
  
  // Gradient Colors
  gradientStart: '#002b5b',
  gradientEnd: '#1e40af',
  
  // Card Colors
  cardBackground: '#ffffff',
  cardBorder: '#f1f5f9',
  cardShadow: 'rgba(0, 43, 91, 0.08)',
};

// Color utility functions
export const getStatusColor = (status: string): string => {
  const statusColors: Record<string, string> = {
    delivered: COLORS.delivered,
    pending: COLORS.pending,
    failed: COLORS.failed,
    interested: COLORS.interested,
    not_home: COLORS.notHome,
    refused: COLORS.error,
    follow_up: COLORS.warning,
  };
  
  return statusColors[status] || COLORS.darkGray;
};

export const getStatusBackgroundColor = (status: string): string => {
  const statusBgColors: Record<string, string> = {
    delivered: '#ecfdf5',
    pending: '#fef3c7',
    failed: '#fef2f2',
    interested: '#eff6ff',
    not_home: '#f3e8ff',
    refused: '#fef2f2',
    follow_up: '#fef3c7',
  };
  
  return statusBgColors[status] || COLORS.lightGray;
};

// Typography scale
export const TYPOGRAPHY = {
  // Font Sizes
  sizes: {
    xs: 10,
    sm: 12,
    md: 14,
    base: 14,
    lg: 16,
    xl: 18,
    '2xl': 20,
    '3xl': 24,
    '4xl': 28,
    '5xl': 32,
  },

  // Font Weights
  weights: {
    light: '300' as const,
    normal: '400' as const,
    medium: '500' as const,
    semibold: '600' as const,
    bold: '700' as const,
    extrabold: '800' as const,
  },

  // Legacy flat structure (for backward compatibility)
  xs: 10,
  sm: 12,
  md: 14,
  base: 14,
  lg: 16,
  xl: 18,
  '2xl': 20,
  '3xl': 24,
  '4xl': 28,
  '5xl': 32,
  light: '300' as const,
  normal: '400' as const,
  medium: '500' as const,
  semibold: '600' as const,
  bold: '700' as const,
  extrabold: '800' as const,

  // Line Heights
  lineHeight: {
    tight: 1.2,
    normal: 1.4,
    relaxed: 1.6,
  },
};

// Spacing scale
export const SPACING = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  '2xl': 24,
  '3xl': 32,
  '4xl': 40,
  '5xl': 48,
  '6xl': 64,
};

// Border radius scale
export const RADIUS = {
  none: 0,
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  '2xl': 20,
  '3xl': 24,
  full: 9999,
};

// Shadow presets
export const SHADOWS = {
  sm: {
    shadowColor: COLORS.shadow,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  md: {
    shadowColor: COLORS.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 4,
  },
  lg: {
    shadowColor: COLORS.shadow,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 8,
  },
  xl: {
    shadowColor: COLORS.shadowDark,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.2,
    shadowRadius: 16,
    elevation: 16,
  },
};

export default COLORS;
