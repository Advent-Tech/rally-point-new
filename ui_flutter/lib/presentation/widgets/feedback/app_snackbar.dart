import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme.dart';

/// Snackbar type for different feedback scenarios
enum SnackbarType { success, error, warning, info }

/// Custom snackbar with consistent styling and animations.
///
/// Usage:
/// ```dart
/// AppSnackbar.show(
///   context,
///   message: 'Operation completed successfully',
///   type: SnackbarType.success,
/// );
/// ```
class AppSnackbar {
  AppSnackbar._();

  /// Show a snackbar with the given message and type
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    bool showIcon = true,
    bool enableHaptics = true,
  }) {
    // Provide haptic feedback based on type
    if (enableHaptics) {
      switch (type) {
        case SnackbarType.success:
          HapticFeedback.lightImpact();
          break;
        case SnackbarType.error:
          HapticFeedback.heavyImpact();
          break;
        case SnackbarType.warning:
          HapticFeedback.mediumImpact();
          break;
        case SnackbarType.info:
          HapticFeedback.selectionClick();
          break;
      }
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _SnackbarContent(
          message: message,
          type: type,
          showIcon: showIcon,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: EdgeInsets.zero,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: _getColor(type),
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  /// Show a success snackbar
  static void success(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackbarType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Show an error snackbar
  static void error(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackbarType.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Show a warning snackbar
  static void warning(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackbarType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Show an info snackbar
  static void info(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackbarType.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static Color _getColor(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return AppColors.success;
      case SnackbarType.error:
        return AppColors.error;
      case SnackbarType.warning:
        return AppColors.warning;
      case SnackbarType.info:
        return AppColors.info;
    }
  }
}

class _SnackbarContent extends StatelessWidget {
  final String message;
  final SnackbarType type;
  final bool showIcon;

  const _SnackbarContent({
    required this.message,
    required this.type,
    required this.showIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getColor();
    final backgroundColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            _AnimatedIcon(type: type, color: color),
            const SizedBox(width: AppSpacing.smd),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (type) {
      case SnackbarType.success:
        return AppColors.success;
      case SnackbarType.error:
        return AppColors.error;
      case SnackbarType.warning:
        return AppColors.warning;
      case SnackbarType.info:
        return AppColors.info;
    }
  }
}

class _AnimatedIcon extends StatefulWidget {
  final SnackbarType type;
  final Color color;

  const _AnimatedIcon({required this.type, required this.color});

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
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
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getIcon(),
          color: widget.color,
          size: 18,
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (widget.type) {
      case SnackbarType.success:
        return Icons.check_circle_outline_rounded;
      case SnackbarType.error:
        return Icons.error_outline_rounded;
      case SnackbarType.warning:
        return Icons.warning_amber_rounded;
      case SnackbarType.info:
        return Icons.info_outline_rounded;
    }
  }
}

/// A toast-style notification that appears at the top of the screen.
/// Use for less intrusive feedback.
class AppToast {
  AppToast._();

  static OverlayEntry? _currentToast;

  /// Show a toast notification
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentToast?.remove();

    final overlay = Overlay.of(context);
    _currentToast = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          _currentToast?.remove();
          _currentToast = null;
        },
        duration: duration,
      ),
    );

    overlay.insert(_currentToast!);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final SnackbarType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Positioned(
      top: MediaQuery.of(context).padding.top + AppSpacing.md,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                  _dismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.smd,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppSpacing.borderRadiusMd,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_getIcon(), color: Colors.white, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    switch (widget.type) {
      case SnackbarType.success:
        return AppColors.success;
      case SnackbarType.error:
        return AppColors.error;
      case SnackbarType.warning:
        return AppColors.warning;
      case SnackbarType.info:
        return AppColors.info;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case SnackbarType.success:
        return Icons.check_circle_outline_rounded;
      case SnackbarType.error:
        return Icons.error_outline_rounded;
      case SnackbarType.warning:
        return Icons.warning_amber_rounded;
      case SnackbarType.info:
        return Icons.info_outline_rounded;
    }
  }
}
