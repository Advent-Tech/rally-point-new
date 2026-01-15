import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../custom_button.dart';

/// A rich empty state component with animation and clear call-to-action.
///
/// Use this instead of inline empty state implementations for consistency.
///
/// Example:
/// ```dart
/// EmptyState(
///   icon: Icons.map_outlined,
///   title: 'No Territories',
///   description: 'You don\'t have any territories assigned yet.',
///   actionLabel: 'Browse Available',
///   onAction: () => navigateToAvailable(),
/// )
/// ```
class EmptyState extends StatefulWidget {
  /// Icon to display in the circular container
  final IconData icon;

  /// Main title text
  final String title;

  /// Descriptive text explaining the empty state
  final String description;

  /// Optional primary action button label
  final String? actionLabel;

  /// Optional primary action callback
  final VoidCallback? onAction;

  /// Optional secondary action button label
  final String? secondaryActionLabel;

  /// Optional secondary action callback
  final VoidCallback? onSecondaryAction;

  /// Custom icon color (defaults to primary)
  final Color? iconColor;

  /// Secondary gradient color for icon background
  final Color? secondaryColor;

  /// Whether to animate the icon on appear
  final bool animateIcon;

  /// Custom icon size (defaults to 48)
  final double iconSize;

  /// Whether to show in compact mode (smaller spacing)
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.iconColor,
    this.secondaryColor,
    this.animateIcon = true,
    this.iconSize = 48,
    this.compact = false,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    if (widget.animateIcon) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = widget.iconColor ?? AppColors.primary;
    final secondaryGradientColor = widget.secondaryColor ?? AppColors.secondary;

    final containerSize = widget.compact ? 80.0 : 100.0;
    final spacing = widget.compact ? AppSpacing.md : AppSpacing.lg;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? AppSpacing.lg : AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon container
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: child,
                ),
              ),
              child: Container(
                width: containerSize,
                height: containerSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.15),
                      secondaryGradientColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: primaryColor,
                ),
              ),
            ),

            SizedBox(height: spacing),

            // Title
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppSpacing.sm),

            // Description
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
            ),

            // Primary action
            if (widget.actionLabel != null) ...[
              SizedBox(height: spacing),
              CustomButton(
                text: widget.actionLabel!,
                onPressed: widget.onAction,
              ),
            ],

            // Secondary action
            if (widget.secondaryActionLabel != null) ...[
              SizedBox(height: AppSpacing.sm),
              CustomButton(
                text: widget.secondaryActionLabel!,
                type: ButtonType.text,
                onPressed: widget.onSecondaryAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Specialized empty state for error scenarios
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      description: message,
      iconColor: AppColors.error,
      secondaryColor: AppColors.error,
      actionLabel: onRetry != null ? retryLabel : null,
      onAction: onRetry,
    );
  }
}

/// Specialized empty state for no internet connection
class NoConnectionState extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoConnectionState({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'No Connection',
      description: 'Please check your internet connection and try again.',
      iconColor: AppColors.warning,
      secondaryColor: AppColors.warning,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

/// Specialized empty state for no search results
class NoResultsState extends StatelessWidget {
  final String query;
  final VoidCallback? onClear;

  const NoResultsState({
    super.key,
    required this.query,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Results',
      description: 'No results found for "$query".\nTry adjusting your search.',
      iconColor: AppColors.secondary,
      actionLabel: onClear != null ? 'Clear Search' : null,
      onAction: onClear,
    );
  }
}

/// Inline error widget for in-context error display
class InlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry? margin;

  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: AppSpacing.iconMd,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
