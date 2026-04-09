import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Custom color tokens that extend the base Material theme.
///
/// Access via: `Theme.of(context).extension<AppColorTokens>()!`
///
/// Example:
/// ```dart
/// final colors = Theme.of(context).extension<AppColorTokens>()!;
/// Container(color: colors.cardBackground);
/// ```
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  /// Card/surface background
  final Color cardBackground;

  /// Subtle background for chips, tags
  final Color subtle;

  /// Muted background for disabled states
  final Color muted;

  /// Overlay background for modals, sheets
  final Color overlay;

  /// Active/selected state background
  final Color activeBackground;

  /// Hover state background
  final Color hoverBackground;

  /// Success state background
  final Color successBackground;

  /// Warning state background
  final Color warningBackground;

  /// Error state background
  final Color errorBackground;

  /// Info state background
  final Color infoBackground;

  /// Icon default color
  final Color iconDefault;

  /// Icon muted color
  final Color iconMuted;

  const AppColorTokens({
    required this.cardBackground,
    required this.subtle,
    required this.muted,
    required this.overlay,
    required this.activeBackground,
    required this.hoverBackground,
    required this.successBackground,
    required this.warningBackground,
    required this.errorBackground,
    required this.infoBackground,
    required this.iconDefault,
    required this.iconMuted,
  });

  /// Light theme color tokens
  static const light = AppColorTokens(
    cardBackground: AppColors.cardLight,
    subtle: Color(0xFFF1F5F9),
    muted: Color(0xFFE2E8F0),
    overlay: Color(0x80000000),
    activeBackground: Color(0x1A3B82F6), // primary at 10%
    hoverBackground: Color(0x0D3B82F6), // primary at 5%
    successBackground: Color(0x1A10B981), // success at 10%
    warningBackground: Color(0x1AF59E0B), // warning at 10%
    errorBackground: Color(0x1AEF4444), // error at 10%
    infoBackground: Color(0x1A3B82F6), // info at 10%
    iconDefault: AppColors.textSecondaryLight,
    iconMuted: AppColors.textTertiaryLight,
  );

  /// Dark theme color tokens
  static const dark = AppColorTokens(
    cardBackground: AppColors.cardDark,
    subtle: Color(0xFF1E293B),
    muted: Color(0xFF334155),
    overlay: Color(0xB3000000),
    activeBackground: Color(0x333B82F6), // primary at 20%
    hoverBackground: Color(0x1A3B82F6), // primary at 10%
    successBackground: Color(0x3310B981), // success at 20%
    warningBackground: Color(0x33F59E0B), // warning at 20%
    errorBackground: Color(0x33EF4444), // error at 20%
    infoBackground: Color(0x333B82F6), // info at 20%
    iconDefault: AppColors.textSecondaryDark,
    iconMuted: AppColors.textTertiaryDark,
  );

  @override
  AppColorTokens copyWith({
    Color? cardBackground,
    Color? subtle,
    Color? muted,
    Color? overlay,
    Color? activeBackground,
    Color? hoverBackground,
    Color? successBackground,
    Color? warningBackground,
    Color? errorBackground,
    Color? infoBackground,
    Color? iconDefault,
    Color? iconMuted,
  }) {
    return AppColorTokens(
      cardBackground: cardBackground ?? this.cardBackground,
      subtle: subtle ?? this.subtle,
      muted: muted ?? this.muted,
      overlay: overlay ?? this.overlay,
      activeBackground: activeBackground ?? this.activeBackground,
      hoverBackground: hoverBackground ?? this.hoverBackground,
      successBackground: successBackground ?? this.successBackground,
      warningBackground: warningBackground ?? this.warningBackground,
      errorBackground: errorBackground ?? this.errorBackground,
      infoBackground: infoBackground ?? this.infoBackground,
      iconDefault: iconDefault ?? this.iconDefault,
      iconMuted: iconMuted ?? this.iconMuted,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      activeBackground: Color.lerp(activeBackground, other.activeBackground, t)!,
      hoverBackground: Color.lerp(hoverBackground, other.hoverBackground, t)!,
      successBackground: Color.lerp(successBackground, other.successBackground, t)!,
      warningBackground: Color.lerp(warningBackground, other.warningBackground, t)!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      infoBackground: Color.lerp(infoBackground, other.infoBackground, t)!,
      iconDefault: Color.lerp(iconDefault, other.iconDefault, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
    );
  }
}

/// Custom spacing/sizing tokens for component dimensions.
///
/// Access via: `Theme.of(context).extension<AppSizeTokens>()!`
@immutable
class AppSizeTokens extends ThemeExtension<AppSizeTokens> {
  /// Card border radius
  final double cardRadius;

  /// Button border radius
  final double buttonRadius;

  /// Input field border radius
  final double inputRadius;

  /// Chip/tag border radius
  final double chipRadius;

  /// Modal/sheet border radius
  final double sheetRadius;

  /// Default card padding
  final double cardPadding;

  /// Default screen padding
  final double screenPadding;

  /// Gap between list items
  final double listItemGap;

  /// Gap between sections
  final double sectionGap;

  const AppSizeTokens({
    required this.cardRadius,
    required this.buttonRadius,
    required this.inputRadius,
    required this.chipRadius,
    required this.sheetRadius,
    required this.cardPadding,
    required this.screenPadding,
    required this.listItemGap,
    required this.sectionGap,
  });

  /// Default size tokens
  static const defaults = AppSizeTokens(
    cardRadius: AppSpacing.radiusLg,
    buttonRadius: AppSpacing.radiusMd,
    inputRadius: AppSpacing.radiusMd,
    chipRadius: AppSpacing.radiusFull,
    sheetRadius: AppSpacing.radiusXl,
    cardPadding: AppSpacing.cardPadding,
    screenPadding: AppSpacing.screenPadding,
    listItemGap: AppSpacing.itemGap,
    sectionGap: AppSpacing.sectionGap,
  );

  @override
  AppSizeTokens copyWith({
    double? cardRadius,
    double? buttonRadius,
    double? inputRadius,
    double? chipRadius,
    double? sheetRadius,
    double? cardPadding,
    double? screenPadding,
    double? listItemGap,
    double? sectionGap,
  }) {
    return AppSizeTokens(
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      chipRadius: chipRadius ?? this.chipRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      cardPadding: cardPadding ?? this.cardPadding,
      screenPadding: screenPadding ?? this.screenPadding,
      listItemGap: listItemGap ?? this.listItemGap,
      sectionGap: sectionGap ?? this.sectionGap,
    );
  }

  @override
  AppSizeTokens lerp(ThemeExtension<AppSizeTokens>? other, double t) {
    if (other is! AppSizeTokens) return this;
    return AppSizeTokens(
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t)!,
      inputRadius: lerpDouble(inputRadius, other.inputRadius, t)!,
      chipRadius: lerpDouble(chipRadius, other.chipRadius, t)!,
      sheetRadius: lerpDouble(sheetRadius, other.sheetRadius, t)!,
      cardPadding: lerpDouble(cardPadding, other.cardPadding, t)!,
      screenPadding: lerpDouble(screenPadding, other.screenPadding, t)!,
      listItemGap: lerpDouble(listItemGap, other.listItemGap, t)!,
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t)!,
    );
  }
}

/// Helper function for double interpolation
double? lerpDouble(double? a, double? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}

/// Extension for easy access to custom theme extensions
extension ThemeExtensionsAccess on BuildContext {
  /// Get color tokens
  AppColorTokens get colorTokens =>
      Theme.of(this).extension<AppColorTokens>() ?? AppColorTokens.light;

  /// Get size tokens
  AppSizeTokens get sizeTokens =>
      Theme.of(this).extension<AppSizeTokens>() ?? AppSizeTokens.defaults;
}

/// List of all theme extensions for easy registration
List<ThemeExtension> get lightThemeExtensions => [
      AppColorTokens.light,
      AppSizeTokens.defaults,
    ];

List<ThemeExtension> get darkThemeExtensions => [
      AppColorTokens.dark,
      AppSizeTokens.defaults,
    ];
