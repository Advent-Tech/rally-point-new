import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page transitions for the app.
///
/// Usage with GoRouter:
/// ```dart
/// GoRoute(
///   path: '/detail',
///   pageBuilder: (context, state) => AppPageTransitions.slide(
///     key: state.pageKey,
///     child: DetailScreen(),
///   ),
/// )
/// ```
class AppPageTransitions {
  AppPageTransitions._();

  /// Slide transition from right to left (default forward navigation)
  static CustomTransitionPage<T> slide<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }

  /// Slide transition from bottom to top (for modals/details)
  static CustomTransitionPage<T> slideUp<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Duration duration = const Duration(milliseconds: 350),
    Curve curve = Curves.easeOutCubic,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Fade transition (for replacing screens)
  static CustomTransitionPage<T> fade<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOut,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: curve,
          ),
          child: child,
        );
      },
    );
  }

  /// Scale and fade transition (for dialogs/important screens)
  static CustomTransitionPage<T> scale<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
    Alignment alignment = Alignment.center,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          alignment: alignment,
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Shared axis transition (Material 3 style)
  static CustomTransitionPage<T> sharedAxis<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    SharedAxisDirection direction = SharedAxisDirection.horizontal,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeIn = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        );

        Offset beginOffset;
        switch (direction) {
          case SharedAxisDirection.horizontal:
            beginOffset = const Offset(30.0, 0.0);
            break;
          case SharedAxisDirection.vertical:
            beginOffset = const Offset(0.0, 30.0);
            break;
        }

        return FadeTransition(
          opacity: fadeIn,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset.lerp(
                  beginOffset,
                  Offset.zero,
                  Curves.easeOutCubic.transform(animation.value),
                )!,
                child: child,
              );
            },
            child: child,
          ),
        );
      },
    );
  }

  /// No transition (instant)
  static CustomTransitionPage<T> none<T>({
    required LocalKey key,
    required Widget child,
    String? name,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  /// iOS-style slide with shadow effect
  static CustomTransitionPage<T> cupertino<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        // Main page slides in from right
        final primarySlide = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation);

        return SlideTransition(
          position: primarySlide,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15 * animation.value),
                  blurRadius: 20,
                  offset: const Offset(-4, 0),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Direction for shared axis transition
enum SharedAxisDirection {
  horizontal,
  vertical,
}

/// Animated route for dialogs with scale effect
class ScaleDialogRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;

  @override
  final bool barrierDismissible;

  @override
  final Color barrierColor;

  @override
  final String? barrierLabel;

  ScaleDialogRoute({
    required this.builder,
    this.barrierDismissible = true,
    this.barrierColor = Colors.black54,
    this.barrierLabel,
    super.settings,
  });

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
      child: FadeTransition(
        opacity: curvedAnimation,
        child: child,
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);
}

/// Shows a dialog with scale animation
Future<T?> showScaleDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
  String? barrierLabel,
}) {
  return Navigator.of(context).push<T>(
    ScaleDialogRoute<T>(
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
    ),
  );
}
