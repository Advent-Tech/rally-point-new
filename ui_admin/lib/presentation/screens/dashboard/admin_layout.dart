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
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.menu, color: Colors.white, size: 20),
        ),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: SizedBox(
        height: 36,
        child: Image.asset(
          'assets/horizontal-logo.png',
          fit: BoxFit.contain,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
            ),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'Logout',
          ),
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
              // Header with Logo
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Image.asset(
                        'assets/horizontal-logo.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
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
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text('Logout', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
          // Header with Logo
          Container(
            height: 72,
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 16 : 8,
              vertical: 12,
            ),
            child: _isExpanded
                ? Image.asset(
                    'assets/horizontal-logo.png',
                    fit: BoxFit.contain,
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 28,
                    ),
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.chevron_left : Icons.chevron_right,
                      color: const Color(0xFF6366F1),
                    ),
                    onPressed: () {
                      setState(() => _isExpanded = !_isExpanded);
                    },
                    tooltip: _isExpanded ? 'Collapse' : 'Expand',
                  ),
                ),
                if (_isExpanded) ...[
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                      onPressed: () => _showLogoutDialog(context),
                      tooltip: 'Logout',
                    ),
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
        iconColor: const Color(0xFF6366F1), // Indigo
      ),
      _NavItem(
        icon: Icons.people_outlined,
        selectedIcon: Icons.people,
        label: 'Users',
        path: '/users',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/users'),
        iconColor: const Color(0xFF3B82F6), // Blue
      ),
      _NavItem(
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: 'Teams',
        path: '/teams',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/teams'),
        iconColor: const Color(0xFF8B5CF6), // Purple
      ),
      _NavItem(
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: 'Territories',
        path: '/territories',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/territories'),
        iconColor: const Color(0xFF10B981), // Emerald
      ),
      _NavItem(
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: 'Surveys',
        path: '/surveys',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/surveys'),
        iconColor: const Color(0xFFF59E0B), // Amber
      ),
      _NavItem(
        icon: Icons.volunteer_activism_outlined,
        selectedIcon: Icons.volunteer_activism,
        label: 'Donations',
        path: '/donations',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/donations'),
        iconColor: const Color(0xFFEC4899), // Pink
      ),
      _NavItem(
        icon: Icons.article_outlined,
        selectedIcon: Icons.article,
        label: 'Blog Posts',
        path: '/blogs',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/blogs'),
        iconColor: const Color(0xFF14B8A6), // Teal
      ),
      _NavItem(
        icon: Icons.favorite_outlined,
        selectedIcon: Icons.favorite,
        label: 'Prayer Requests',
        path: '/prayer-requests',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/prayer-requests'),
        iconColor: const Color(0xFFEF4444), // Red
      ),
      _NavItem(
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics,
        label: 'Analytics',
        path: '/analytics',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/analytics'),
        iconColor: const Color(0xFF06B6D4), // Cyan
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: 'Activity Map',
        path: '/activity-map',
        currentPath: widget.currentPath,
        isExpanded: isExpanded,
        onTap: () => _navigateTo(context, '/activity-map'),
        iconColor: const Color(0xFF84CC16), // Lime
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
          iconColor: const Color(0xFFFF6B35), // Orange
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
  final Color iconColor;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.isExpanded,
    required this.onTap,
    required this.iconColor,
  });

  bool get isSelected => currentPath.startsWith(path);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? iconColor.withAlpha(25) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 12 : 12,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? iconColor : iconColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: iconColor.withAlpha(60),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected ? Colors.white : iconColor,
                    size: 20,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? iconColor : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
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
