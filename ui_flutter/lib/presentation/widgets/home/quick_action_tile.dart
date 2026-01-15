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
    final size = isSmall ? 100.0 : 120.0;
    final iconSize = isSmall ? 32.0 : 40.0;
    final borderRadius = isSmall ? 20.0 : 24.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
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
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 0.85,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return QuickActionTile(
          icon: action.icon,
          label: action.label,
          backgroundColor: action.backgroundColor,
          onTap: action.onTap,
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

/// Predefined colors for quick action tiles matching the reference design
class QuickActionColors {
  QuickActionColors._();

  /// Purple/Lavender - My Territory
  static const Color territory = Color(0xFFB8A9E8);

  /// Pink/Coral - Deliver Book
  static const Color delivery = Color(0xFFF5B5B5);

  /// Tan/Beige - Survey Form
  static const Color survey = Color(0xFFE8D5B5);

  /// Teal/Blue - Team Group
  static const Color team = Color(0xFF5CB8B2);

  /// Green - GPS Tracking
  static const Color tracking = Color(0xFF4CAF50);

  /// Orange - Achievements
  static const Color achievements = Color(0xFFFFA726);

  /// Blue - Chat
  static const Color chat = Color(0xFF42A5F5);

  /// Red/Coral - End Session
  static const Color endSession = Color(0xFFEF5350);

  /// Green - Start Session
  static const Color startSession = Color(0xFF66BB6A);

  /// Purple - Prayer
  static const Color prayer = Color(0xFF9575CD);

  /// Indigo - News
  static const Color news = Color(0xFF5C6BC0);

  /// Amber - Walkie
  static const Color walkie = Color(0xFFFFB300);
}
