import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Screen size categories
enum ScreenSize { mobile, tablet, desktop }

/// Responsive utilities for building adaptive layouts.
///
/// Usage:
/// ```dart
/// // Get current screen size
/// final size = Responsive.of(context);
///
/// // Use responsive value
/// padding: EdgeInsets.all(Responsive.value(context, mobile: 16, tablet: 24, desktop: 32)),
///
/// // Show different widgets
/// Responsive.builder(
///   context,
///   mobile: MobileLayout(),
///   tablet: TabletLayout(),
/// )
/// ```
class Responsive {
  Responsive._();

  /// Get the current screen size category
  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= AppSpacing.breakpointTablet) {
      return ScreenSize.desktop;
    } else if (width >= AppSpacing.breakpointMobile) {
      return ScreenSize.tablet;
    }
    return ScreenSize.mobile;
  }

  /// Check if the current screen is mobile
  static bool isMobile(BuildContext context) => of(context) == ScreenSize.mobile;

  /// Check if the current screen is tablet
  static bool isTablet(BuildContext context) => of(context) == ScreenSize.tablet;

  /// Check if the current screen is desktop
  static bool isDesktop(BuildContext context) => of(context) == ScreenSize.desktop;

  /// Check if the current screen is tablet or larger
  static bool isTabletOrLarger(BuildContext context) =>
      of(context) != ScreenSize.mobile;

  /// Get a responsive value based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    switch (of(context)) {
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.mobile:
        return mobile;
    }
  }

  /// Build different widgets based on screen size
  static Widget builder(
    BuildContext context, {
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    switch (of(context)) {
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.mobile:
        return mobile;
    }
  }

  /// Get responsive padding
  static EdgeInsets padding(BuildContext context) {
    return EdgeInsets.all(value(
      context,
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
    ));
  }

  /// Get responsive horizontal padding
  static EdgeInsets horizontalPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: value(
        context,
        mobile: AppSpacing.md,
        tablet: AppSpacing.lg,
        desktop: AppSpacing.xl,
      ),
    );
  }

  /// Get responsive content width (for centering content on large screens)
  static double maxContentWidth(BuildContext context) {
    return value(
      context,
      mobile: double.infinity,
      tablet: 720.0,
      desktop: 1200.0,
    );
  }

  /// Get responsive grid column count
  static int gridColumns(BuildContext context) {
    return value(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );
  }
}

/// Wrapper widget that constrains content width on larger screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool center;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? Responsive.maxContentWidth(context);
    final effectivePadding = padding ?? Responsive.horizontalPadding(context);

    Widget content = Padding(
      padding: effectivePadding,
      child: child,
    );

    if (effectiveMaxWidth != double.infinity) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: content,
      );

      if (center) {
        content = Center(child: content);
      }
    }

    return content;
  }
}

/// Responsive grid that adapts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.mainAxisSpacing = AppSpacing.md,
    this.crossAxisSpacing = AppSpacing.md,
    this.childAspectRatio = 1.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.value(
      context,
      mobile: mobileColumns ?? 2,
      tablet: tabletColumns ?? 3,
      desktop: desktopColumns ?? 4,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Responsive row that wraps to column on mobile
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment rowMainAxisAlignment;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final MainAxisAlignment columnMainAxisAlignment;
  final CrossAxisAlignment columnCrossAxisAlignment;
  final double spacing;
  final bool forceColumn;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
    this.columnMainAxisAlignment = MainAxisAlignment.start,
    this.columnCrossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = AppSpacing.md,
    this.forceColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    final useColumn = forceColumn || Responsive.isMobile(context);

    if (useColumn) {
      return Column(
        mainAxisAlignment: columnMainAxisAlignment,
        crossAxisAlignment: columnCrossAxisAlignment,
        children: _buildChildren(spacing, Axis.vertical),
      );
    }

    return Row(
      mainAxisAlignment: rowMainAxisAlignment,
      crossAxisAlignment: rowCrossAxisAlignment,
      children: _buildChildren(spacing, Axis.horizontal),
    );
  }

  List<Widget> _buildChildren(double spacing, Axis axis) {
    final spacer = axis == Axis.horizontal
        ? SizedBox(width: spacing)
        : SizedBox(height: spacing);

    return children.asMap().entries.expand((entry) {
      if (entry.key == children.length - 1) {
        return [entry.value];
      }
      return [entry.value, spacer];
    }).toList();
  }
}

/// Adaptive scaffold that shows different layouts based on screen size
class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final Widget? navigationRail;
  final Widget? bottomNavigation;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Color? backgroundColor;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.navigationRail,
    this.bottomNavigation,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = Responsive.isTabletOrLarger(context);

    // On larger screens, use navigation rail
    if (isLargeScreen && navigationRail != null) {
      return Scaffold(
        appBar: appBar,
        backgroundColor: backgroundColor,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: Row(
          children: [
            navigationRail!,
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // On mobile, use bottom navigation
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigation,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      backgroundColor: backgroundColor,
    );
  }
}

/// Extension for responsive context access
extension ResponsiveContext on BuildContext {
  /// Get current screen size
  ScreenSize get screenSize => Responsive.of(this);

  /// Check if mobile
  bool get isMobileScreen => Responsive.isMobile(this);

  /// Check if tablet
  bool get isTabletScreen => Responsive.isTablet(this);

  /// Check if desktop
  bool get isDesktopScreen => Responsive.isDesktop(this);

  /// Get responsive value
  T responsiveValue<T>({required T mobile, T? tablet, T? desktop}) {
    return Responsive.value(this, mobile: mobile, tablet: tablet, desktop: desktop);
  }
}
