import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../blocs/auth/auth_bloc.dart';

class BottomNavShell extends StatelessWidget {
  final Widget child;

  const BottomNavShell({super.key, required this.child});

  bool _isLeader(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final isLeader = authState.user.isTeamLeader || authState.user.isAdmin;
      debugPrint('BottomNav - role: "${authState.user.role}", isLeader: $isLeader');
      return isLeader;
    }
    debugPrint('BottomNav - Not authenticated');
    return false;
  }

  int _getCurrentIndex(BuildContext context, bool isLeader) {
    final location = GoRouterState.of(context).matchedLocation;

    if (isLeader) {
      // Leader navigation: Dashboard, Team, Surveys, Reports
      switch (location) {
        case '/home':
          return 0;
        case '/team':
          return 1;
        case '/survey':
          return 2;
        case '/reports':
          return 3;
        default:
          return 0;
      }
    } else {
      // Worker navigation: Home, Territory, Delivery, Survey
      switch (location) {
        case '/home':
          return 0;
        case '/territory':
          return 1;
        case '/delivery':
          return 2;
        case '/survey':
          return 3;
        default:
          return 0;
      }
    }
  }

  void _onItemTapped(BuildContext context, int index, bool isLeader) {
    if (isLeader) {
      // Leader navigation
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/team');
          break;
        case 2:
          context.go('/survey');
          break;
        case 3:
          context.go('/reports');
          break;
      }
    } else {
      // Worker navigation
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/territory');
          break;
        case 2:
          context.go('/delivery');
          break;
        case 3:
          context.go('/survey');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeader = _isLeader(context);
    final currentIndex = _getCurrentIndex(context, isLeader);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => _onItemTapped(context, index, isLeader),
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            indicatorColor: AppColors.primary.withAlpha(38),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 70,
            destinations: isLeader
                ? _buildLeaderDestinations(currentIndex, isDark)
                : _buildWorkerDestinations(currentIndex, isDark),
          ),
        ),
      ),
    );
  }

  List<NavigationDestination> _buildLeaderDestinations(int currentIndex, bool isDark) {
    return [
      NavigationDestination(
        icon: Icon(
          Icons.dashboard_outlined,
          color: currentIndex == 0
              ? AppColors.primary
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        selectedIcon: const Icon(Icons.dashboard, color: AppColors.primary),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.people_outline,
          color: currentIndex == 1
              ? AppColors.primary
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        selectedIcon: const Icon(Icons.people, color: AppColors.primary),
        label: 'Team',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.assignment_outlined,
          color: currentIndex == 2
              ? AppColors.primary
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        selectedIcon: const Icon(Icons.assignment, color: AppColors.primary),
        label: 'Surveys',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.bar_chart_outlined,
          color: currentIndex == 3
              ? AppColors.primary
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        selectedIcon: const Icon(Icons.bar_chart, color: AppColors.primary),
        label: 'Reports',
      ),
    ];
  }

  List<NavigationDestination> _buildWorkerDestinations(int currentIndex, bool isDark) {
    return [
      NavigationDestination(
        icon: Icon(
          Icons.home_outlined,
          color: currentIndex == 0
              ? AppColors.primary
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        selectedIcon: const Icon(Icons.home, color: AppColors.primary),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.map_outlined,
          color: currentIndex == 1
              ? AppColors.primary
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        selectedIcon: const Icon(Icons.map, color: AppColors.primary),
        label: 'Territory',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.local_shipping_outlined,
          color: currentIndex == 2
              ? AppColors.primary
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        selectedIcon: const Icon(Icons.local_shipping, color: AppColors.primary),
        label: 'Delivery',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.assignment_outlined,
          color: currentIndex == 3
              ? AppColors.primary
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        selectedIcon: const Icon(Icons.assignment, color: AppColors.primary),
        label: 'Survey',
      ),
    ];
  }
}
