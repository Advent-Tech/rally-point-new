import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Base shimmer effect wrapper that adapts to theme
class ShimmerEffect extends StatelessWidget {
  final Widget child;

  const ShimmerEffect({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.surfaceDark : Colors.grey.shade300,
      highlightColor: isDark ? AppColors.borderDark : Colors.grey.shade100,
      child: child,
    );
  }
}

/// A skeleton placeholder box with customizable dimensions
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? AppSpacing.borderRadiusMd,
      ),
    );
  }
}

/// A skeleton line for text placeholders
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonLine({
    super.key,
    this.width = double.infinity,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
    );
  }
}

/// A skeleton circle for avatar placeholders
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({
    super.key,
    this.size = AppSpacing.avatarMd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A complete skeleton card matching the app's card style
class SkeletonCard extends StatelessWidget {
  final double? height;
  final EdgeInsetsGeometry? margin;
  final bool showLeading;
  final int textLines;

  const SkeletonCard({
    super.key,
    this.height,
    this.margin,
    this.showLeading = true,
    this.textLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      margin: margin ?? EdgeInsets.only(bottom: AppSpacing.itemGap),
      padding: AppSpacing.cardPaddingAll,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: ShimmerEffect(
        child: Row(
          children: [
            if (showLeading) ...[
              const SkeletonBox(
                width: AppSpacing.avatarLg,
                height: AppSpacing.avatarLg,
              ),
              SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SkeletonLine(width: 120, height: 16),
                  if (textLines > 1) ...[
                    SizedBox(height: AppSpacing.sm),
                    const SkeletonLine(height: 12),
                  ],
                  if (textLines > 2) ...[
                    SizedBox(height: AppSpacing.xs),
                    const SkeletonLine(width: 80, height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton list with multiple skeleton cards
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double? itemHeight;
  final bool showLeading;
  final int textLines;
  final EdgeInsetsGeometry? padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight,
    this.showLeading = true,
    this.textLines = 2,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding ?? AppSpacing.screenPaddingH,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (_, __) => SkeletonCard(
        height: itemHeight,
        showLeading: showLeading,
        textLines: textLines,
      ),
    );
  }
}

/// A skeleton grid for quick action cards
class SkeletonQuickActionGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const SkeletonQuickActionGrid({
    super.key,
    this.itemCount = 4,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.itemGap,
        crossAxisSpacing: AppSpacing.itemGap,
        childAspectRatio: 1.1,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => Container(
        padding: AppSpacing.cardPaddingAll,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: ShimmerEffect(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SkeletonBox(
                width: AppSpacing.avatarLg,
                height: AppSpacing.avatarLg,
              ),
              SizedBox(height: AppSpacing.sm),
              const SkeletonLine(width: 60, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// A skeleton stat row
class SkeletonStatRow extends StatelessWidget {
  final int itemCount;

  const SkeletonStatRow({
    super.key,
    this.itemCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: List.generate(itemCount, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index < itemCount - 1 ? AppSpacing.md : 0,
            ),
            padding: AppSpacing.cardPaddingAll,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppSpacing.borderRadiusLg,
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: ShimmerEffect(
              child: Row(
                children: [
                  const SkeletonBox(
                    width: AppSpacing.avatarMd,
                    height: AppSpacing.avatarMd,
                  ),
                  SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SkeletonLine(width: 40, height: 18),
                        SizedBox(height: AppSpacing.xs),
                        const SkeletonLine(width: 60, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A skeleton for territory/assignment cards with progress indicator
class SkeletonTerritoryCard extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const SkeletonTerritoryCard({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin ?? EdgeInsets.only(bottom: AppSpacing.itemGap),
      padding: AppSpacing.cardPaddingAll,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: ShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox(
                  width: AppSpacing.avatarLg,
                  height: AppSpacing.avatarLg,
                ),
                SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonLine(width: 120, height: 16),
                      SizedBox(height: AppSpacing.xs),
                      const SkeletonLine(width: 80, height: 12),
                    ],
                  ),
                ),
                const SkeletonBox(
                  width: 70,
                  height: 28,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonLine(width: 80, height: 12),
                const SkeletonLine(width: 30, height: 12),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            const SkeletonLine(height: 6),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for the activity/feed items
class SkeletonActivityItem extends StatelessWidget {
  const SkeletonActivityItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      child: ShimmerEffect(
        child: Row(
          children: [
            const SkeletonBox(
              width: AppSpacing.avatarMd,
              height: AppSpacing.avatarMd,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLine(width: 100, height: 14),
                  SizedBox(height: AppSpacing.xs),
                  const SkeletonLine(height: 12),
                ],
              ),
            ),
            const SkeletonLine(width: 50, height: 10),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for profile/header sections
class SkeletonHeader extends StatelessWidget {
  const SkeletonHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLine(width: 100, height: 14),
          SizedBox(height: AppSpacing.xs),
          const SkeletonLine(width: 150, height: 24),
        ],
      ),
    );
  }
}
