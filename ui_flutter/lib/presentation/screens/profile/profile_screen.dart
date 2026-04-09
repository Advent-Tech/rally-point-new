import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/profile/profile_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/help/help_mode_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if user is team leader to show back button
    final authState = context.read<AuthBloc>().state;
    final isTeamLeader =
        authState is AuthAuthenticated && authState.user.isTeamLeader;

    return Scaffold(
      appBar: AppBar(
        leading: isTeamLeader
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Check if we can pop, otherwise go to leader dashboard
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/leader/dashboard');
                  }
                },
              )
            : null,
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Settings
            },
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = state.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Header
                _ProfileHeader(
                  name: user.displayName ?? 'User',
                  email: user.email,
                  role: user.role ?? 'member',
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Stats Section
                _StatsSection(isDark: isDark),
                const SizedBox(height: 24),

                // Settings Section
                _SettingsSection(isDark: isDark),
                const SizedBox(height: 24),

                // Logout Button
                CustomButton(
                  text: 'Sign Out',
                  type: ButtonType.outline,
                  icon: Icons.logout,
                  width: double.infinity,
                  onPressed: () {
                    _showLogoutDialog(context);
                  },
                ),
                const SizedBox(height: 16),

                // App Info
                Text(
                  'Rally Point v1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogout());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final bool isDark;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.role,
    required this.isDark,
  });

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'leader':
        return 'Team Leader';
      case 'worker':
        return 'Field Worker';
      default:
        return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withAlpha(30),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRoleLabel(role),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Edit Button
          IconButton(
            onPressed: () {
              // TODO: Edit profile
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatefulWidget {
  final bool isDark;

  const _StatsSection({required this.isDark});

  @override
  State<_StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<_StatsSection> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const ProfileLoadStats());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        String totalHours = '0h';
        String totalDistance = '0 km';
        String totalVisits = '0';
        String totalDeliveries = '0';

        if (state is ProfileLoaded) {
          totalHours = state.totalHours;
          totalDistance = state.totalDistance;
          totalVisits = state.totalVisits.toString();
          totalDeliveries = state.totalDeliveries.toString();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark
                  ? AppColors.borderDark
                  : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Statistics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (state is ProfileLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    icon: Icons.timer_outlined,
                    value: totalHours,
                    label: 'Total Hours',
                    color: AppColors.primary,
                    isDark: widget.isDark,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    icon: Icons.route_outlined,
                    value: totalDistance,
                    label: 'Distance',
                    color: AppColors.secondary,
                    isDark: widget.isDark,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatCard(
                    icon: Icons.home_work_outlined,
                    value: totalVisits,
                    label: 'Visits',
                    color: AppColors.accent,
                    isDark: widget.isDark,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    icon: Icons.local_shipping_outlined,
                    value: totalDeliveries,
                    label: 'Deliveries',
                    color: AppColors.success,
                    isDark: widget.isDark,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final bool isDark;

  const _SettingsSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            isDark: isDark,
            trailing: BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, state) {
                return Switch(
                  value: state.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    context.read<ThemeBloc>().add(
                      ThemeChanged(
                        themeMode: value ? ThemeMode.dark : ThemeMode.light,
                      ),
                    );
                  },
                  activeColor: AppColors.primary,
                );
              },
            ),
          ),
          _buildDivider(isDark),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            isDark: isDark,
            onTap: () {
              // TODO: Notification settings
            },
          ),
          _buildDivider(isDark),
          _SettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Location Services',
            isDark: isDark,
            onTap: () {
              // TODO: Location settings
            },
          ),
          _buildDivider(isDark),
          _SettingsTile(
            icon: Icons.security_outlined,
            title: 'Privacy & Security',
            isDark: isDark,
            onTap: () {
              // TODO: Privacy settings
            },
          ),
          _buildDivider(isDark),
          _HelpModeTile(isDark: isDark),
          _buildDivider(isDark),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            isDark: isDark,
            onTap: () {
              // TODO: About
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      color: isDark ? AppColors.borderDark : AppColors.borderLight,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.isDark,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
      onTap: onTap,
    );
  }
}

class _HelpModeTile extends StatelessWidget {
  final bool isDark;
  const _HelpModeTile({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final helpNotifier = HelpModeProvider.notifierOf(context);

    if (helpNotifier == null) {
      return _SettingsTile(
        icon: Icons.help_outline,
        title: 'Help Mode',
        isDark: isDark,
        trailing: Switch(
          value: false,
          onChanged: (value) {},
          activeColor: AppColors.primary,
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: helpNotifier,
      builder: (context, isEnabled, _) {
        return _SettingsTile(
          icon: Icons.help_outline,
          title: 'Help Mode',
          isDark: isDark,
          trailing: Switch(
            value: isEnabled,
            onChanged: (value) {
              helpNotifier.value = value;
            },
            activeColor: AppColors.primary,
          ),
        );
      },
    );
  }
}
