import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';

/// Large colorful quick action tile for home screen.
///
/// Based on the ministry app design with large rounded colored backgrounds
/// and centered white icons. Supports an optional subtitle and badge count.
class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color backgroundColor;
  final Color? backgroundColorEnd;
  final VoidCallback onTap;
  final bool isSmall;
  final int? badgeCount;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.backgroundColor,
    this.backgroundColorEnd,
    required this.onTap,
    this.isSmall = false,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isSmall ? 36.0 : 56.0;
    final borderRadius = isSmall ? 20.0 : 24.0;
    final hasBadge = badgeCount != null && badgeCount! > 0;
    final endColor = backgroundColorEnd ?? backgroundColor;

    return SizedBox.expand(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [backgroundColor, endColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: backgroundColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: iconSize * 0.55,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 80,
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hasBadge)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount! > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      color: backgroundColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
        childAspectRatio: 1.25,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return QuickActionTile(
          icon: action.icon,
          label: action.label,
          subtitle: action.subtitle,
          backgroundColor: action.backgroundColor,
          backgroundColorEnd: action.backgroundColorEnd,
          onTap: action.onTap,
          isSmall: true,
          badgeCount: action.badgeCount,
        );
      },
    );
  }
}

/// Data class for quick action tile
class QuickActionTileData {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color backgroundColor;
  final Color? backgroundColorEnd;
  final VoidCallback onTap;
  final int? badgeCount;

  const QuickActionTileData({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.backgroundColor,
    this.backgroundColorEnd,
    required this.onTap,
    this.badgeCount,
  });
}

/// Predefined colors for quick action tiles - elegant vibrant palette
class QuickActionColors {
  QuickActionColors._();

  /// Purple gradient - My Territory
  static const Color territory = Color(0xFF7E57C2);
  static const Color territoryEnd = Color(0xFFB085F5);

  /// Coral/Rose gradient - Donation
  static const Color delivery = Color(0xFFE57373);
  static const Color deliveryEnd = Color(0xFFFF9E9E);

  /// Amber/Gold gradient - Survey Form
  static const Color survey = Color(0xFFFFB74D);
  static const Color surveyEnd = Color(0xFFFFE97D);

  /// Teal gradient - Team Group
  static const Color team = Color(0xFF4DB6AC);
  static const Color teamEnd = Color(0xFF80CBC4);

  /// Green gradient - GPS Tracking
  static const Color tracking = Color(0xFF66BB6A);
  static const Color trackingEnd = Color(0xFF81C784);

  /// Orange gradient - Achievements
  static const Color achievements = Color(0xFFFF8A65);
  static const Color achievementsEnd = Color(0xFFFFAB91);

  /// Blue gradient - Chat
  static const Color chat = Color(0xFF42A5F5);
  static const Color chatEnd = Color(0xFF64B5F6);

  /// Red/Coral gradient - End Session
  static const Color endSession = Color(0xFFEF5350);
  static const Color endSessionEnd = Color(0xFFEF9A9A);

  /// Green gradient - Start Session
  static const Color startSession = Color(0xFF66BB6A);
  static const Color startSessionEnd = Color(0xFF81C784);

  /// Deep Purple gradient - Prayer
  static const Color prayer = Color(0xFF9575CD);
  static const Color prayerEnd = Color(0xFFB39DDB);

  /// Indigo gradient - News
  static const Color news = Color(0xFF5C6BC0);
  static const Color newsEnd = Color(0xFF7986CB);

  /// Amber gradient - Walkie
  static const Color walkie = Color(0xFFFFB300);
  static const Color walkieEnd = Color(0xFFFFCA28);

  /// Navy Blue gradient - Targets
  static const Color targets = Color(0xFF1E3A5F);
  static const Color targetsEnd = Color(0xFF2E5077);
}
