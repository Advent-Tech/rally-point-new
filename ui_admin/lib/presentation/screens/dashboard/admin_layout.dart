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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isSuperAdmin =
        authState is AuthAuthenticated && authState.isSuperAdmin;
    final isMobile = _isMobile(context);
    final isTablet = _isTablet(context);

    // Auto-collapse sidebar on tablet
    if (isTablet && _isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isExpanded = false);
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile ? _buildMobileAppBar(context) : null,
      drawer: isMobile ? _buildDrawer(context, isSuperAdmin) : null,
      body: Row(
        children: [
          // Sidebar Navigation (hidden on mobile)
          if (!isMobile)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isExpanded ? 250 : 72,
              child: _buildSidebar(context, isSuperAdmin),
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

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Admin Panel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(context),
          tooltip: 'Logout',
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, bool isSuperAdmin) {
    return Drawer(
      child: Container(
        color: AppColors.surface,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Admin Panel',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Navigation Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: _buildNavItems(context, isSuperAdmin, true),
                ),
              ),

              // Footer
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showLogoutDialog(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isSuperAdmin) {
    return Container(
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
              children: _buildNavItems(context, isSuperAdmin, _isExpanded),
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
                    onPressed: () => _showLogoutDialog(context),
                    tooltip: 'Logout',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(
      BuildContext context, bool isSuperAdmin, bool isExpanded) {
    return [
      _NavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Dashboard',
        path: '/dashboard',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/dashboard'),
      ),
      _NavItem(
        icon: Icons.people_outlined,
        selectedIcon: Icons.people,
        label: 'Users',
        path: '/users',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/users'),
      ),
      _NavItem(
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: 'Teams',
        path: '/teams',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/teams'),
      ),
      _NavItem(
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: 'Territories',
        path: '/territories',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/territories'),
      ),
      _NavItem(
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: 'Surveys',
        path: '/surveys',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/surveys'),
      ),
      _NavItem(
        icon: Icons.volunteer_activism_outlined,
        selectedIcon: Icons.volunteer_activism,
        label: 'Donations',
        path: '/donations',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/donations'),
      ),
      _NavItem(
        icon: Icons.article_outlined,
        selectedIcon: Icons.article,
        label: 'Blog Posts',
        path: '/blogs',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/blogs'),
      ),
      _NavItem(
        icon: Icons.volunteer_activism_outlined,
        selectedIcon: Icons.volunteer_activism,
        label: 'Prayer Requests',
        path: '/prayer-requests',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/prayer-requests'),
      ),
      _NavItem(
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics,
        label: 'Analytics',
        path: '/analytics',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/analytics'),
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: 'Activity Map',
        path: '/activity-map',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/activity-map'),
      ),
      if (isSuperAdmin) ...[
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 16 : 8,
            vertical: 8,
          ),
          child: const Divider(),
        ),
        _NavItem(
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: 'Admin Accounts',
          path: '/admins',
          currentPath: widget.currentPath,
          isExpanded: isExpanded,
          onTap: () => _navigateTo(context, '/admins'),
        ),
      ],
    ];
  }

  void _navigateTo(BuildContext context, String path) {
    // Close drawer if open on mobile
    if (_isMobile(context)) {
      Navigator.pop(context);
    }
    context.go(path);
  }

  void _showLogoutDialog(BuildContext context) {
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
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
  final String currentPath;
  final bool isExpanded;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.isExpanded,
    required this.onTap,
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
          onTap: onTap,
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
                        color:
                            isSelected ? AppColors.primary : AppColors.textPrimary,
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
