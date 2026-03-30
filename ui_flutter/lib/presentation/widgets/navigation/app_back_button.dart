import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Consistent back behavior:
/// - Pop when possible
/// - Otherwise go to role-aware fallback route
class AppBackButton {
  AppBackButton._();

  static String inferFallbackRoute(
    BuildContext context, {
    String workerDefault = '/home',
    String leaderDefault = '/leader/dashboard',
  }) {
    final path = GoRouter.of(context).routeInformationProvider.value.uri.path;
    if (path.startsWith('/leader')) return leaderDefault;
    return workerDefault;
  }

  static void handleBack(BuildContext context, {String? fallbackRoute}) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(fallbackRoute ?? inferFallbackRoute(context));
  }

  static Widget leading(
    BuildContext context, {
    String? fallbackRoute,
    String tooltip = 'Back',
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => handleBack(context, fallbackRoute: fallbackRoute),
    );
  }
}
