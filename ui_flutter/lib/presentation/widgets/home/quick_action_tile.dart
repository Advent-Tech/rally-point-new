import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';

/// Large colorful quick action tile for home screen.
///
/// Based on the ministry app design with large rounded colored backgrounds
/// and centered white icons.
class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;
  final bool isSmall;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isSmall ? 48.0 : 56.0;
    final borderRadius = isSmall ? 20.0 : 24.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
            const SizedBox(height: AppSpacing.smd),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid of quick action tiles
class QuickActionGrid extends StatelessWidget {
  final List<QuickActionTileData> actions;
  final int crossAxisCount;
  final double spacing;

  const QuickActionGrid({
    super.key,
    required this.actions,
    this.crossAxisCount = 2,
    this.spacing = AppSpacing.lg,
  });

  @override
  Widget build(BuildContext context) {
    // Use GridView with 2 columns for consistent layout
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.0,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return QuickActionTile(
          icon: action.icon,
          label: action.label,
          backgroundColor: action.backgroundColor,
          onTap: action.onTap,
          isSmall: true,
        );
      },
    );
  }
}

/// Data class for quick action tile
class QuickActionTileData {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  const QuickActionTileData({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });
}

/// Predefined colors for quick action tiles - elegant vibrant palette
class QuickActionColors {
  QuickActionColors._();

  /// Purple - My Territory
  static const Color territory = Color(0xFF7E57C2);

  /// Coral/Rose - Donation
  static const Color delivery = Color(0xFFE57373);

  /// Amber/Gold - Survey Form
  static const Color survey = Color(0xFFFFB74D);

  /// Teal - Team Group
  static const Color team = Color(0xFF4DB6AC);

  /// Green - GPS Tracking
  static const Color tracking = Color(0xFF66BB6A);

  /// Orange - Achievements
  static const Color achievements = Color(0xFFFF8A65);

  /// Blue - Chat
  static const Color chat = Color(0xFF42A5F5);

  /// Red/Coral - End Session
  static const Color endSession = Color(0xFFEF5350);

  /// Green - Start Session
  static const Color startSession = Color(0xFF66BB6A);

  /// Deep Purple - Prayer
  static const Color prayer = Color(0xFF9575CD);

  /// Indigo - News
  static const Color news = Color(0xFF5C6BC0);

  /// Amber - Walkie
  static const Color walkie = Color(0xFFFFB300);
}
