import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme.dart';

/// Shows a styled bottom sheet with consistent animations and design.
///
/// Usage:
/// ```dart
/// AppBottomSheet.show(
///   context,
///   title: 'Select Option',
///   child: YourContent(),
/// );
/// ```
class AppBottomSheet {
  AppBottomSheet._();

  /// Show a modal bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
    bool useRootNavigator = false,
    double initialChildSize = 0.5,
    double minChildSize = 0.25,
    double maxChildSize = 0.9,
    bool expand = false,
    bool enableHaptics = true,
    Color? backgroundColor,
    List<Widget>? actions,
  }) {
    if (enableHaptics) {
      HapticFeedback.selectionClick();
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnimatedBottomSheet(
        title: title,
        subtitle: subtitle,
        backgroundColor: backgroundColor,
        actions: actions,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: expand,
        child: child,
      ),
    );
  }

  /// Show a simple action sheet with options
  static Future<T?> showActions<T>({
    required BuildContext context,
    required List<SheetAction<T>> actions,
    String? title,
    String? message,
    bool showCancel = true,
    String cancelLabel = 'Cancel',
  }) {
    return show<T>(
      context: context,
      title: title,
      subtitle: message,
      initialChildSize: 0.3,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...actions.map((action) => _ActionTile<T>(action: action)),
          if (showCancel) ...[
            const Divider(height: 1),
            _ActionTile<T>(
              action: SheetAction<T>(
                icon: Icons.close,
                label: cancelLabel,
                isDestructive: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Show a confirmation sheet
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      subtitle: message,
      initialChildSize: 0.3,
      minChildSize: 0.2,
      maxChildSize: 0.4,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBottomSheet extends StatefulWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Color? backgroundColor;
  final List<Widget>? actions;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool expand;

  const _AnimatedBottomSheet({
    required this.child,
    this.title,
    this.subtitle,
    this.backgroundColor,
    this.actions,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.expand,
  });

  @override
  State<_AnimatedBottomSheet> createState() => _AnimatedBottomSheetState();
}

class _AnimatedBottomSheetState extends State<_AnimatedBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ??
        (isDark ? AppColors.surfaceDark : AppColors.backgroundLight);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: widget.initialChildSize,
        minChildSize: widget.minChildSize,
        maxChildSize: widget.maxChildSize,
        expand: widget.expand,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppSpacing.borderRadiusTopXl,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                _SheetHandle(),
                // Header
                if (widget.title != null || widget.actions != null)
                  _SheetHeader(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    actions: widget.actions,
                  ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.smd),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;

  const _SheetHeader({
    this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.backgroundLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action item for action sheets
class SheetAction<T> {
  final IconData? icon;
  final String label;
  final T? value;
  final bool isDestructive;
  final VoidCallback? onTap;

  const SheetAction({
    this.icon,
    required this.label,
    this.value,
    this.isDestructive = false,
    this.onTap,
  });
}

class _ActionTile<T> extends StatelessWidget {
  final SheetAction<T> action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive ? AppColors.error : null;

    return ListTile(
      leading: action.icon != null
          ? Icon(action.icon, color: color)
          : null,
      title: Text(
        action.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        action.onTap?.call();
        Navigator.pop(context, action.value);
      },
    );
  }
}

/// A simple sheet for displaying content without draggable behavior
class SimpleBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsetsGeometry? padding;

  const SimpleBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.padding,
  });

  /// Show a simple bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    EdgeInsetsGeometry? padding,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SimpleBottomSheet(
        title: title,
        padding: padding,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
        borderRadius: AppSpacing.borderRadiusTopXl,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
