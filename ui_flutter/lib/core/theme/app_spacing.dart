import 'package:flutter/material.dart';

/// Design System Spacing Constants
///
/// Uses a 4px base unit for consistent spacing throughout the app.
/// Prefer these constants over magic numbers for maintainability.
class AppSpacing {
  AppSpacing._();

  // ==========================================================================
  // BASE SPACING SCALE (4px base unit)
  // ==========================================================================

  /// 4px - Extra small spacing
  static const double xs = 4;

  /// 8px - Small spacing
  static const double sm = 8;

  /// 12px - Small-medium spacing
  static const double smd = 12;

  /// 16px - Medium spacing (default)
  static const double md = 16;

  /// 20px - Medium-large spacing
  static const double mlg = 20;

  /// 24px - Large spacing
  static const double lg = 24;

  /// 32px - Extra large spacing
  static const double xl = 32;

  /// 48px - 2x Extra large spacing
  static const double xxl = 48;

  /// 64px - 3x Extra large spacing
  static const double xxxl = 64;

  // ==========================================================================
  // SEMANTIC SPACING
  // ==========================================================================

  /// Screen edge padding (20px)
  static const double screenPadding = mlg;

  /// Horizontal screen padding
  static const EdgeInsets screenPaddingH = EdgeInsets.symmetric(horizontal: mlg);

  /// All-sides screen padding
  static const EdgeInsets screenPaddingAll = EdgeInsets.all(mlg);

  /// Card internal padding (16px)
  static const double cardPadding = md;

  /// Card padding as EdgeInsets
  static const EdgeInsets cardPaddingAll = EdgeInsets.all(md);

  /// Gap between sections (24px)
  static const double sectionGap = lg;

  /// Gap between list items (12px)
  static const double itemGap = smd;

  /// Gap between inline elements (8px)
  static const double inlineGap = sm;

  /// Gap between icon and text (8px)
  static const double iconTextGap = sm;

  /// Form field vertical spacing (16px)
  static const double formFieldGap = md;

  /// Button internal horizontal padding (20px)
  static const double buttonPaddingH = mlg;

  /// Button internal vertical padding (14px)
  static const double buttonPaddingV = 14;

  // ==========================================================================
  // BORDER RADII
  // ==========================================================================

  /// 4px radius - Very small elements
  static const double radiusXs = 4;

  /// 8px radius - Small elements (chips, tags)
  static const double radiusSm = 8;

  /// 12px radius - Medium elements (buttons, inputs)
  static const double radiusMd = 12;

  /// 16px radius - Large elements (cards)
  static const double radiusLg = 16;

  /// 20px radius - Extra large elements (bottom sheets)
  static const double radiusXl = 20;

  /// 24px radius - 2x Extra large
  static const double radiusXxl = 24;

  /// Full circular radius
  static const double radiusFull = 9999;

  // ==========================================================================
  // BORDER RADIUS PRESETS
  // ==========================================================================

  /// Small border radius
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));

  /// Medium border radius (buttons, inputs)
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));

  /// Large border radius (cards)
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));

  /// Extra large border radius (bottom sheets)
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));

  /// Top-only radius for bottom sheets
  static const BorderRadius borderRadiusTopXl = BorderRadius.vertical(
    top: Radius.circular(radiusXl),
  );

  /// Full circular radius (for pills, chips)
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(radiusFull));

  // ==========================================================================
  // COMPONENT SIZES
  // ==========================================================================

  /// Small icon size (16px)
  static const double iconSm = 16;

  /// Medium icon size (20px)
  static const double iconMd = 20;

  /// Large icon size (24px)
  static const double iconLg = 24;

  /// Extra large icon size (32px)
  static const double iconXl = 32;

  /// Small avatar size (32px)
  static const double avatarSm = 32;

  /// Medium avatar size (40px)
  static const double avatarMd = 40;

  /// Large avatar size (48px)
  static const double avatarLg = 48;

  /// Extra large avatar size (64px)
  static const double avatarXl = 64;

  /// Small button height (36px)
  static const double buttonHeightSm = 36;

  /// Medium button height (48px)
  static const double buttonHeightMd = 48;

  /// Large button height (56px)
  static const double buttonHeightLg = 56;

  /// Icon button size (48px) - matches Material touch target
  static const double iconButtonSize = 48;

  /// Minimum touch target (48px) - Material accessibility guideline
  static const double minTouchTarget = 48;

  // ==========================================================================
  // RESPONSIVE BREAKPOINTS
  // ==========================================================================

  /// Mobile breakpoint (< 600px)
  static const double breakpointMobile = 600;

  /// Tablet breakpoint (600px - 1024px)
  static const double breakpointTablet = 1024;

  /// Desktop breakpoint (> 1024px)
  static const double breakpointDesktop = 1440;
}

/// Extension for easy access to spacing in BuildContext
extension SpacingExtension on BuildContext {
  /// Get responsive column count based on screen width
  int get responsiveColumns {
    final width = MediaQuery.of(this).size.width;
    if (width >= AppSpacing.breakpointDesktop) return 4;
    if (width >= AppSpacing.breakpointTablet) return 3;
    return 2;
  }

  /// Check if current screen is mobile
  bool get isMobile => MediaQuery.of(this).size.width < AppSpacing.breakpointMobile;

  /// Check if current screen is tablet
  bool get isTablet {
    final width = MediaQuery.of(this).size.width;
    return width >= AppSpacing.breakpointMobile && width < AppSpacing.breakpointTablet;
  }

  /// Check if current screen is desktop
  bool get isDesktop => MediaQuery.of(this).size.width >= AppSpacing.breakpointTablet;
}
