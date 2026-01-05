import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum ButtonType { primary, secondary, outline, text, danger }
enum ButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final bool iconTrailing;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

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
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveOnPressed = (isLoading || isDisabled) ? null : onPressed;

    // Size configurations
    final double height;
    final double fontSize;
    final double iconSize;
    final EdgeInsetsGeometry effectivePadding;

    switch (size) {
      case ButtonSize.small:
        height = 36;
        fontSize = 13;
        iconSize = 18;
        effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 12);
        break;
      case ButtonSize.medium:
        height = 48;
        fontSize = 15;
        iconSize = 20;
        effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 20);
        break;
      case ButtonSize.large:
        height = 56;
        fontSize = 17;
        iconSize = 24;
        effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 28);
        break;
    }

    // Color configurations
    Color backgroundColor;
    Color foregroundColor;
    Color borderColor;

    switch (type) {
      case ButtonType.primary:
        backgroundColor = AppColors.primary;
        foregroundColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case ButtonType.secondary:
        backgroundColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
        foregroundColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
        break;
      case ButtonType.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.primary;
        borderColor = AppColors.primary;
        break;
      case ButtonType.text:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.primary;
        borderColor = Colors.transparent;
        break;
      case ButtonType.danger:
        backgroundColor = AppColors.error;
        foregroundColor = Colors.white;
        borderColor = Colors.transparent;
        break;
    }

    if (isDisabled) {
      backgroundColor = backgroundColor.withOpacity(0.5);
      foregroundColor = foregroundColor.withOpacity(0.5);
    }

    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12);

    // Create text style that properly inherits from theme to avoid lerp issues
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: foregroundColor,
    ) ?? TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: foregroundColor,
    );

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
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null && !iconTrailing) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: textStyle,
        ),
        if (icon != null && iconTrailing && !isLoading) ...[
          const SizedBox(width: 8),
          Icon(icon, size: iconSize),
        ],
      ],
    );

    if (type == ButtonType.text) {
      return TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: effectivePadding,
          minimumSize: Size(width ?? 0, height),
          shape: RoundedRectangleBorder(borderRadius: effectiveBorderRadius),
        ),
        child: buttonChild,
      );
    }

    if (type == ButtonType.outline) {
      return OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor, width: 1.5),
          padding: effectivePadding,
          minimumSize: Size(width ?? 0, height),
          shape: RoundedRectangleBorder(borderRadius: effectiveBorderRadius),
        ),
        child: buttonChild,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: type == ButtonType.secondary ? 0 : 2,
          shadowColor: backgroundColor.withOpacity(0.3),
          padding: effectivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: effectiveBorderRadius,
            side: BorderSide(color: borderColor),
          ),
        ),
        child: buttonChild,
      ),
    );
  }
}

// Icon Button variant
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

  const CustomIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.iconSize = 24,
    this.tooltip,
    this.hasBadge = false,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackgroundColor = backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final effectiveIconColor = iconColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    Widget button = Material(
      color: effectiveBackgroundColor,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: effectiveIconColor,
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
              padding: const EdgeInsets.all(4),
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

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

// Floating Action Button variant
class CustomFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool mini;

  const CustomFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(icon),
        label: Text(label!),
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      mini: mini,
      child: Icon(icon),
    );
  }
}
