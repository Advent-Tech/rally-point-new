import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const AdminLayout({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isSuperAdmin = authState is AuthAuthenticated && authState.isSuperAdmin;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isExpanded ? 250 : 72,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  right: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isExpanded ? 16 : 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        if (_isExpanded) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Admin Panel',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Navigation Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _NavItem(
                          icon: Icons.dashboard_outlined,
                          selectedIcon: Icons.dashboard,
                          label: 'Dashboard',
                          path: '/dashboard',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.people_outlined,
                          selectedIcon: Icons.people,
                          label: 'Users',
                          path: '/users',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.groups_outlined,
                          selectedIcon: Icons.groups,
                          label: 'Teams',
                          path: '/teams',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.map_outlined,
                          selectedIcon: Icons.map,
                          label: 'Territories',
                          path: '/territories',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.assignment_outlined,
                          selectedIcon: Icons.assignment,
                          label: 'Surveys',
                          path: '/surveys',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.volunteer_activism_outlined,
                          selectedIcon: Icons.volunteer_activism,
                          label: 'Donations',
                          path: '/donations',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.article_outlined,
                          selectedIcon: Icons.article,
                          label: 'Blog Posts',
                          path: '/blogs',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.volunteer_activism_outlined,
                          selectedIcon: Icons.volunteer_activism,
                          label: 'Prayer Requests',
                          path: '/prayer-requests',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.analytics_outlined,
                          selectedIcon: Icons.analytics,
                          label: 'Analytics',
                          path: '/analytics',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        _NavItem(
                          icon: Icons.explore_outlined,
                          selectedIcon: Icons.explore,
                          label: 'Activity Map',
                          path: '/activity-map',
                          currentPath: widget.currentPath,
                          isExpanded: _isExpanded,
                        ),
                        if (isSuperAdmin) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Divider(),
                          ),
                          _NavItem(
                            icon: Icons.admin_panel_settings_outlined,
                            selectedIcon: Icons.admin_panel_settings,
                            label: 'Admin Accounts',
                            path: '/admins',
                            currentPath: widget.currentPath,
                            isExpanded: _isExpanded,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Footer
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isExpanded ? Icons.chevron_left : Icons.chevron_right,
                          ),
                          onPressed: () {
                            setState(() => _isExpanded = !_isExpanded);
                          },
                          tooltip: _isExpanded ? 'Collapse' : 'Expand',
                        ),
                        if (_isExpanded) ...[
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Logout'),
                                  content: const Text('Are you sure you want to logout?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        context.read<AuthBloc>().add(const AuthLogout());
                                        context.go('/login');
                                      },
                                      child: const Text('Logout'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            tooltip: 'Logout',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: Container(
              color: AppColors.background,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
  final String currentPath;
  final bool isExpanded;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.isExpanded,
  });

  bool get isSelected => currentPath.startsWith(path);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? AppColors.primary.withAlpha(20) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(path),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 12 : 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
