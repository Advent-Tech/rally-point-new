import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Color utility extensions for consistent color manipulation.
///
/// Flutter 3.27+ deprecates `withOpacity()` and `withAlpha()` in favor of
/// `withValues()`. These extensions provide convenient helpers using the
/// modern API.
///
/// Usage:
/// ```dart
/// // Instead of:
/// color.withOpacity(0.5) // deprecated
/// color.withAlpha(128)   // deprecated
///
/// // Use:
/// color.withAlphaValue(0.5)  // 0.0 to 1.0
/// color.subtle                // 0.12 opacity
/// color.muted                 // 0.3 opacity
/// ```
extension ColorOpacityExtension on Color {
  /// Returns color with the specified alpha value (0.0 to 1.0)
  ///
  /// This is the recommended replacement for the deprecated `withOpacity()`.
  Color withAlphaValue(double opacity) {
    assert(opacity >= 0.0 && opacity <= 1.0, 'Opacity must be between 0.0 and 1.0');
    return withValues(alpha: opacity);
  }

  /// Very subtle opacity (0.05) - for hover states
  Color get verySubtle => withValues(alpha: 0.05);

  /// Subtle opacity (0.1) - for splash/ripple effects
  Color get subtle => withValues(alpha: 0.1);

  /// Light opacity (0.12) - for icon backgrounds, chips
  Color get light => withValues(alpha: 0.12);

  /// Muted opacity (0.2) - for disabled states, dividers
  Color get muted => withValues(alpha: 0.2);

  /// Medium opacity (0.3) - for borders, shadows
  Color get medium => withValues(alpha: 0.3);

  /// Semi-transparent opacity (0.5) - for overlays
  Color get semiTransparent => withValues(alpha: 0.5);

  /// Mostly opaque (0.8) - for gradient ends
  Color get mostlyOpaque => withValues(alpha: 0.8);
}

/// BuildContext extension for easy access to theme colors
extension ThemeColorExtension on BuildContext {
  /// Whether the current theme is dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Current surface color based on theme
  Color get surfaceColor =>
      isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight;

  /// Current background color based on theme
  Color get backgroundColor =>
      isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight;

  /// Current card color based on theme
  Color get cardColor => isDarkMode ? AppColors.cardDark : AppColors.cardLight;

  /// Current border color based on theme
  Color get borderColor =>
      isDarkMode ? AppColors.borderDark : AppColors.borderLight;

  /// Current divider color based on theme
  Color get dividerColor =>
      isDarkMode ? AppColors.dividerDark : AppColors.dividerLight;

  /// Primary text color based on theme
  Color get textPrimary =>
      isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  /// Secondary text color based on theme
  Color get textSecondary =>
      isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  /// Tertiary text color based on theme
  Color get textTertiary =>
      isDarkMode ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

  /// Disabled text color based on theme
  Color get textDisabled =>
      isDarkMode ? AppColors.textDisabledDark : AppColors.textDisabledLight;
}

/// Pre-defined shadow styles
class AppShadows {
  AppShadows._();

  /// Subtle card shadow
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Dark mode card shadow
  static List<BoxShadow> get cardShadowDark => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Elevated button shadow
  static List<BoxShadow> buttonShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// Floating action button shadow
  static List<BoxShadow> get fabShadow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Bottom navigation shadow
  static List<BoxShadow> get bottomNavShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ];
}

/// Pre-defined gradient styles
class AppGradients {
  AppGradients._();

  /// Primary brand gradient
  static LinearGradient get primary => LinearGradient(
        colors: [
          AppColors.primary,
          AppColors.primary.withValues(alpha: 0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Success gradient for positive actions
  static LinearGradient get success => LinearGradient(
        colors: [
          AppColors.success,
          AppColors.success.withValues(alpha: 0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Subtle gradient for backgrounds
  static LinearGradient subtle(Color color) => LinearGradient(
        colors: [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Empty state icon gradient
  static LinearGradient get emptyStateIcon => LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.15),
          AppColors.secondary.withValues(alpha: 0.15),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
