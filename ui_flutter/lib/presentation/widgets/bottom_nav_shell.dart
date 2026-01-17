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
      debugPrint(
        'BottomNav - role: "${authState.user.role}", isLeader: $isLeader',
      );
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
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: isLeader
              ? _buildLeaderNavItems(context, currentIndex, isDark)
              : _buildWorkerNavItems(context, currentIndex, isDark),
        ),
      ),
    );
  }

  List<Widget> _buildLeaderNavItems(BuildContext context, int currentIndex, bool isDark) {
    final items = [
      _NavItemData(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0),
      _NavItemData(Icons.people_outline, Icons.people, 'Team', 1),
      _NavItemData(Icons.assignment_outlined, Icons.assignment, 'Surveys', 2),
      _NavItemData(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports', 3),
    ];
    return items.map((item) => _buildNavItem(context, item, currentIndex, isDark, true)).toList();
  }

  List<Widget> _buildWorkerNavItems(BuildContext context, int currentIndex, bool isDark) {
    final items = [
      _NavItemData(Icons.home_outlined, Icons.home, 'Home', 0),
      _NavItemData(Icons.map_outlined, Icons.map, 'Territory', 1),
      _NavItemData(Icons.volunteer_activism_outlined, Icons.volunteer_activism, 'Donations', 2),
      _NavItemData(Icons.assignment_outlined, Icons.assignment, 'Survey', 3),
    ];
    return items.map((item) => _buildNavItem(context, item, currentIndex, isDark, false)).toList();
  }

  Widget _buildNavItem(BuildContext context, _NavItemData item, int currentIndex, bool isDark, bool isLeader) {
    final isSelected = currentIndex == item.index;
    final color = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(context, item.index, isLeader),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;

  const _NavItemData(this.icon, this.selectedIcon, this.label, this.index);
}
