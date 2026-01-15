import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum ButtonType { primary, secondary, outline, text, danger, success }
enum ButtonSize { small, medium, large }

/// A customizable button component with haptic feedback and accessibility support.
///
/// Follows the design system with consistent sizing, colors, and interactions.
///
/// Example:
/// ```dart
/// CustomButton(
///   text: 'Submit',
///   icon: Icons.send,
///   onPressed: () => handleSubmit(),
/// )
/// ```
class CustomButton extends StatelessWidget {
  /// Button label text
  final String text;

  /// Callback when button is pressed
  final VoidCallback? onPressed;

  /// Visual style variant
  final ButtonType type;

  /// Size variant (small: 36px, medium: 48px, large: 56px)
  final ButtonSize size;

  /// Shows loading spinner when true
  final bool isLoading;

  /// Disables the button when true
  final bool isDisabled;

  /// Optional leading/trailing icon
  final IconData? icon;

  /// Places icon after text when true
  final bool iconTrailing;

  /// Fixed width (defaults to intrinsic width)
  final double? width;

  /// Custom padding override
  final EdgeInsetsGeometry? padding;

  /// Custom border radius override
  final BorderRadius? borderRadius;

  /// Enables haptic feedback on press (default: true)
  final bool enableHaptics;

  /// Semantic label for screen readers (defaults to text)
  final String? semanticLabel;

  /// Custom background color override
  final Color? backgroundColor;

  /// Custom foreground/text color override
  final Color? foregroundColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.iconTrailing = false,
    this.width,
    this.padding,
    this.borderRadius,
    this.enableHaptics = true,
    this.semanticLabel,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Wrap onPressed with haptic feedback
    final effectiveOnPressed = (isLoading || isDisabled)
        ? null
        : () {
            if (enableHaptics) {
              HapticFeedback.lightImpact();
            }
            onPressed?.call();
          };

    // Size configurations using design system constants
    final (double height, double fontSize, double iconSize, EdgeInsetsGeometry effectivePadding) =
        _getSizeConfig();

    // Color configurations
    final (Color bgColor, Color fgColor, Color borderColor) =
        _getColorConfig(isDark);

    final effectiveBgColor = backgroundColor ?? bgColor;
    final effectiveFgColor = foregroundColor ?? fgColor;

    // Apply disabled state
    final finalBgColor = isDisabled
        ? effectiveBgColor.withValues(alpha: 0.5)
        : effectiveBgColor;
    final finalFgColor = isDisabled
        ? effectiveFgColor.withValues(alpha: 0.5)
        : effectiveFgColor;

    final effectiveBorderRadius = borderRadius ?? AppSpacing.borderRadiusMd;

    // Create text style from theme
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: finalFgColor,
            ) ??
        TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: finalFgColor,
        );

    // Build button content
    Widget buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(finalFgColor),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
        ] else if (icon != null && !iconTrailing) ...[
          Icon(icon, size: iconSize, color: finalFgColor),
          SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            text,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (icon != null && iconTrailing && !isLoading) ...[
          SizedBox(width: AppSpacing.sm),
          Icon(icon, size: iconSize, color: finalFgColor),
        ],
      ],
    );

    // Wrap with semantics for accessibility
    Widget button = _buildButtonByType(
      context: context,
      child: buttonChild,
      effectiveOnPressed: effectiveOnPressed,
      effectivePadding: effectivePadding,
      effectiveBorderRadius: effectiveBorderRadius,
      finalBgColor: finalBgColor,
      finalFgColor: finalFgColor,
      borderColor: borderColor,
      height: height,
    );

    // Add semantic label
    return Semantics(
      button: true,
      enabled: !isDisabled && !isLoading,
      label: semanticLabel ?? text,
      child: button,
    );
  }

  (double, double, double, EdgeInsetsGeometry) _getSizeConfig() {
    return switch (size) {
      ButtonSize.small => (
          AppSpacing.buttonHeightSm,
          13.0,
          AppSpacing.iconSm + 2,
          padding ?? EdgeInsets.symmetric(horizontal: AppSpacing.smd),
        ),
      ButtonSize.medium => (
          AppSpacing.buttonHeightMd,
          15.0,
          AppSpacing.iconMd,
          padding ?? EdgeInsets.symmetric(horizontal: AppSpacing.mlg),
        ),
      ButtonSize.large => (
          AppSpacing.buttonHeightLg,
          17.0,
          AppSpacing.iconLg,
          padding ?? EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
    };
  }

  (Color, Color, Color) _getColorConfig(bool isDark) {
    return switch (type) {
      ButtonType.primary => (
          AppColors.primary,
          Colors.white,
          Colors.transparent,
        ),
      ButtonType.secondary => (
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ButtonType.outline => (
          Colors.transparent,
          AppColors.primary,
          AppColors.primary,
        ),
      ButtonType.text => (
          Colors.transparent,
          AppColors.primary,
          Colors.transparent,
        ),
      ButtonType.danger => (
          AppColors.error,
          Colors.white,
          Colors.transparent,
        ),
      ButtonType.success => (
          AppColors.success,
          Colors.white,
          Colors.transparent,
        ),
    };
  }

  Widget _buildButtonByType({
    required BuildContext context,
    required Widget child,
    required VoidCallback? effectiveOnPressed,
    required EdgeInsetsGeometry effectivePadding,
    required BorderRadius effectiveBorderRadius,
    required Color finalBgColor,
    required Color finalFgColor,
    required Color borderColor,
    required double height,
  }) {
    if (type == ButtonType.text) {
      return TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          foregroundColor: finalFgColor,
          padding: effectivePadding,
          minimumSize: Size(width ?? 0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: effectiveBorderRadius),
        ),
        child: child,
      );
    }

    if (type == ButtonType.outline) {
      return OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: finalFgColor,
          side: BorderSide(color: borderColor, width: 1.5),
          padding: effectivePadding,
          minimumSize: Size(width ?? 0, height),
          shape: RoundedRectangleBorder(borderRadius: effectiveBorderRadius),
        ),
        child: child,
      );
    }

    // Primary, secondary, danger, success - use ElevatedButton
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: finalBgColor,
          foregroundColor: finalFgColor,
          elevation: type == ButtonType.secondary ? 0 : 2,
          shadowColor: finalBgColor.withValues(alpha: 0.3),
          padding: effectivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: effectiveBorderRadius,
            side: BorderSide(color: borderColor),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A circular icon button with optional badge
class CustomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool hasBadge;
  final int? badgeCount;
  final bool enableHaptics;

  const CustomIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = AppSpacing.iconButtonSize,
    this.iconSize = AppSpacing.iconLg,
    this.tooltip,
    this.hasBadge = false,
    this.badgeCount,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackgroundColor =
        backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final effectiveIconColor =
        iconColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    Widget button = Material(
      color: effectiveBackgroundColor,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onPressed != null
            ? () {
                if (enableHaptics) {
                  HapticFeedback.lightImpact();
                }
                onPressed!();
              }
            : null,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: effectiveIconColor,
            ),
          ),
        ),
      ),
    );

    if (hasBadge && badgeCount != null && badgeCount! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                badgeCount! > 99 ? '99+' : badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    // Ensure minimum touch target
    button = SizedBox(
      width: size < AppSpacing.minTouchTarget ? AppSpacing.minTouchTarget : size,
      height: size < AppSpacing.minTouchTarget ? AppSpacing.minTouchTarget : size,
      child: Center(child: button),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return Semantics(
      button: true,
      label: tooltip,
      child: button,
    );
  }
}

/// A floating action button with optional extended label
class CustomFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool mini;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? tooltip;
  final bool enableHaptics;

  const CustomFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
    this.mini = false,
    this.backgroundColor,
    this.foregroundColor,
    this.tooltip,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = backgroundColor ?? AppColors.primary;
    final effectiveFgColor = foregroundColor ?? Colors.white;

    final effectiveOnPressed = onPressed != null
        ? () {
            if (enableHaptics) {
              HapticFeedback.mediumImpact();
            }
            onPressed!();
          }
        : null;

    Widget fab;
    if (label != null) {
      fab = FloatingActionButton.extended(
        onPressed: effectiveOnPressed,
        backgroundColor: effectiveBgColor,
        foregroundColor: effectiveFgColor,
        icon: Icon(icon),
        label: Text(label!),
        tooltip: tooltip,
      );
    } else {
      fab = FloatingActionButton(
        onPressed: effectiveOnPressed,
        backgroundColor: effectiveBgColor,
        foregroundColor: effectiveFgColor,
        mini: mini,
        tooltip: tooltip,
        child: Icon(icon),
      );
    }

    return Semantics(
      button: true,
      label: tooltip ?? label,
      child: fab,
    );
  }
}

/// A segmented button group for selecting between options
class SegmentedButtonGroup<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelBuilder;
  final IconData Function(T)? iconBuilder;
  final bool enableHaptics;

  const SegmentedButtonGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelBuilder,
    this.iconBuilder,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: options.map((option) {
        return ButtonSegment<T>(
          value: option,
          label: Text(labelBuilder(option)),
          icon: iconBuilder != null ? Icon(iconBuilder!(option)) : null,
        );
      }).toList(),
      selected: {selected},
      onSelectionChanged: (Set<T> selection) {
        if (enableHaptics) {
          HapticFeedback.selectionClick();
        }
        onChanged(selection.first);
      },
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
          ),
        ),
      ),
    );
  }
}
