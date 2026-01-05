import 'package:flutter/material.dart';

/// Theme-aware app logo widget that shows different logos based on theme
/// - Dark theme: logo.png (people with flag, lighter colors)
/// - Light theme: splash.jpeg (same logo but optimized for light backgrounds)
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      isDark ? 'assets/logo.png' : 'assets/splash.jpeg',
      width: width,
      height: height,
      fit: fit,
    );
  }
}

/// Vertical logo widget for splash screens and branding
/// Uses the "Streams of Light International" vertical logo
class AppVerticalLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppVerticalLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/vertcal-logo.png',
      width: width,
      height: height,
      fit: fit,
    );
  }
}

/// Horizontal logo widget for app bars and headers
/// Uses the "Streams of Light International" horizontal logo
/// Same logo for both light and dark themes
class AppHorizontalLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppHorizontalLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/horizontal-logo.png',
      width: width,
      height: height,
      fit: fit,
    );
  }
}
