import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Card variants for different use cases
enum AppCardVariant {
  /// Elevated card with shadow - primary content
  elevated,

  /// Outlined card with border - secondary content
  outlined,

  /// Filled card with background color - subtle content
  filled,

  /// Gradient card for highlighted content
  gradient,
}

/// A unified card component following the design system.
///
/// Use this instead of inline `Container` decorations for consistency.
///
/// Example:
/// ```dart
/// AppCard(
///   variant: AppCardVariant.elevated,
///   onTap: () => navigateToDetail(),
///   child: Row(
///     children: [
///       Icon(Icons.star),
///       Text('Card content'),
///     ],
///   ),
/// )
/// ```
class AppCard extends StatefulWidget {
  /// The card variant style
  final AppCardVariant variant;

  /// Child widget to display inside the card
  final Widget child;

  /// Optional tap callback - enables ink splash when provided
  final VoidCallback? onTap;

  /// Optional long press callback
  final VoidCallback? onLongPress;

  /// Custom padding override (defaults to AppSpacing.cardPadding)
  final EdgeInsetsGeometry? padding;

  /// Custom border radius override
  final BorderRadius? borderRadius;

  /// Custom background color override
  final Color? backgroundColor;

  /// Gradient colors for gradient variant
  final List<Color>? gradientColors;

  /// Whether to show a subtle press animation
  final bool enablePressAnimation;

  /// Whether to provide haptic feedback on tap
  final bool enableHaptics;

  /// Custom margin around the card
  final EdgeInsetsGeometry? margin;

  /// Custom border color for outlined variant
  final Color? borderColor;

  /// Custom border width
  final double borderWidth;

  /// Semantic label for accessibility
  final String? semanticLabel;

  const AppCard({
    super.key,
    this.variant = AppCardVariant.elevated,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.gradientColors,
    this.enablePressAnimation = true,
    this.enableHaptics = true,
    this.margin,
    this.borderColor,
    this.borderWidth = 1.0,
    this.semanticLabel,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enablePressAnimation && widget.onTap != null) {
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enablePressAnimation) {
      _pressController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.enablePressAnimation) {
      _pressController.reverse();
    }
  }

  void _handleTap() {
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderRadius = widget.borderRadius ?? AppSpacing.borderRadiusLg;
    final effectivePadding = widget.padding ?? AppSpacing.cardPaddingAll;

    // Determine colors based on variant and theme
    final (Color bgColor, BoxBorder? border, List<BoxShadow>? shadows, Gradient? gradient) =
        _getVariantStyles(isDark);

    Widget cardContent = Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: gradient == null ? bgColor : null,
        gradient: gradient,
        borderRadius: effectiveBorderRadius,
        border: border,
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    // Wrap with ink effect if tappable
    if (widget.onTap != null || widget.onLongPress != null) {
      cardContent = Material(
        color: Colors.transparent,
        borderRadius: effectiveBorderRadius,
        child: InkWell(
          onTap: widget.onTap != null ? _handleTap : null,
          onLongPress: widget.onLongPress,
          borderRadius: effectiveBorderRadius,
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: cardContent,
        ),
      );

      // Add press animation
      if (widget.enablePressAnimation) {
        cardContent = GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
            child: cardContent,
          ),
        );
      }
    }

    // Apply margin if provided
    if (widget.margin != null) {
      cardContent = Padding(
        padding: widget.margin!,
        child: cardContent,
      );
    }

    // Wrap with semantics if label provided
    if (widget.semanticLabel != null) {
      cardContent = Semantics(
        button: widget.onTap != null,
        label: widget.semanticLabel,
        child: cardContent,
      );
    }

    return cardContent;
  }

  (Color, BoxBorder?, List<BoxShadow>?, Gradient?) _getVariantStyles(bool isDark) {
    switch (widget.variant) {
      case AppCardVariant.elevated:
        return (
          widget.backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          null,
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
          null,
        );

      case AppCardVariant.outlined:
        return (
          widget.backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          Border.all(
            color: widget.borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: widget.borderWidth,
          ),
          null,
          null,
        );

      case AppCardVariant.filled:
        return (
          widget.backgroundColor ??
              (isDark ? AppColors.surfaceDark : AppColors.backgroundLight),
          null,
          null,
          null,
        );

      case AppCardVariant.gradient:
        final colors = widget.gradientColors ??
            [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ];
        return (
          Colors.transparent,
          null,
          [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
    }
  }
}

/// A stat card variant for displaying metrics
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: onTap,
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: AppSpacing.avatarMd,
            height: AppSpacing.avatarMd,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppSpacing.borderRadiusSm,
            ),
            child: Icon(icon, color: color, size: AppSpacing.iconMd),
          ),
          SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A quick action card for prominent actions
class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isCompact;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: onTap,
      padding: EdgeInsets.all(isCompact ? AppSpacing.smd : AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? AppSpacing.avatarMd : AppSpacing.avatarLg,
            height: isCompact ? AppSpacing.avatarMd : AppSpacing.avatarLg,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Icon(
              icon,
              color: color,
              size: isCompact ? AppSpacing.iconMd : AppSpacing.iconLg,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A list item card for displaying items in a list
class ListItemCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const ListItemCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: onTap,
      padding: padding ?? EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
