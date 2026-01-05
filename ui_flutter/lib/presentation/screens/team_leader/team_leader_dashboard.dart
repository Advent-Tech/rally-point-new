import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../widgets/app_logo.dart';

class TeamLeaderDashboard extends StatefulWidget {
  const TeamLeaderDashboard({super.key});

  @override
  State<TeamLeaderDashboard> createState() => _TeamLeaderDashboardState();
}

class _TeamLeaderDashboardState extends State<TeamLeaderDashboard> {
  late DashboardBloc _dashboardBloc;

  @override
  void initState() {
    super.initState();
    _dashboardBloc = DashboardBloc();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      String? teamId = authState.user.teamId;

      // If user is a team leader but has no teamId, try to fetch their led team
      if (teamId == null && authState.user.isTeamLeader) {
        teamId = await _fetchLedTeamId(authState.user.id);
      }

      if (teamId != null) {
        _dashboardBloc.add(DashboardLoadStats(teamId: teamId));
      }
    }
  }

  Future<String?> _fetchLedTeamId(String leaderId) async {
    try {
      final apiClient = await ApiClient.getInstance();
      final response = await apiClient.get('/api/teams?leader_id=$leaderId');

      if (response.statusCode == 200) {
        final data = response.data;
        final teams = data is List ? data : data['teams'] ?? [];
        if (teams.isNotEmpty) {
          return teams[0]['id']?.toString();
        }
      }
    } catch (e) {
      debugPrint('TeamLeaderDashboard: Error fetching led team: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _dashboardBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _dashboardBloc,
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              _dashboardBloc.add(const DashboardRefresh());
            },
            child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              centerTitle: false,
              title: const SizedBox(
                height: 36,
                child: AppHorizontalLogo(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    // TODO: Notifications
                  },
                ),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return IconButton(
                      icon: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.secondary.withAlpha(50),
                        child: Text(
                          state is AuthAuthenticated
                              ? (state.user.displayName?.isNotEmpty == true
                                  ? state.user.displayName![0].toUpperCase()
                                  : 'T')
                              : 'T',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onPressed: () => context.go('/leader/profile'),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Welcome Section
            SliverToBoxAdapter(
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final userName = state is AuthAuthenticated
                      ? state.user.displayName ?? 'Team Leader'
                      : 'Team Leader';
                  final teamName = state is AuthAuthenticated
                      ? state.user.teamName ?? 'Your Team'
                      : 'Your Team';
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.groups,
                                size: 16,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                teamName,
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Quick Stats Overview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BlocBuilder<DashboardBloc, DashboardState>(
                  builder: (context, state) {
                    final stats = state is DashboardLoaded
                        ? state.stats
                        : const TeamDashboardStats();
                    final isLoading = state is DashboardLoading;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Team Overview',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: _OverviewCard(
                                  icon: Icons.people,
                                  value: '${stats.totalMembers}',
                                  label: 'Team Members',
                                  color: AppColors.primary,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _OverviewCard(
                                  icon: Icons.online_prediction,
                                  value: '${stats.activeWorkers}',
                                  label: 'Currently Active',
                                  color: AppColors.success,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _OverviewCard(
                                  icon: Icons.map,
                                  value: '${stats.totalTerritories}',
                                  label: 'Territories',
                                  color: AppColors.accent,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _OverviewCard(
                                  icon: Icons.check_circle,
                                  value: stats.completionPercentage < 1 && stats.completionPercentage > 0
                                      ? '<1%'
                                      : '${stats.completionPercentage.toStringAsFixed(0)}%',
                                  label: 'Completion',
                                  color: AppColors.secondary,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Management Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Management',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ManagementTile(
                      icon: Icons.map,
                      title: 'Team Map',
                      subtitle: 'View workers and activities on map',
                      color: AppColors.info,
                      isDark: isDark,
                      onTap: () => context.push('/leader/team-map'),
                    ),
                    const SizedBox(height: 12),
                    _ManagementTile(
                      icon: Icons.map_outlined,
                      title: 'Territory Assignment',
                      subtitle: 'Assign territories to team members',
                      color: AppColors.primary,
                      isDark: isDark,
                      onTap: () => context.push('/leader/territory-assignment'),
                    ),
                    const SizedBox(height: 12),
                    _ManagementTile(
                      icon: Icons.people_outline,
                      title: 'Team Members',
                      subtitle: 'View and manage your team',
                      color: AppColors.secondary,
                      isDark: isDark,
                      onTap: () => context.push('/leader/team-members'),
                    ),
                    const SizedBox(height: 12),
                    _ManagementTile(
                      icon: Icons.analytics_outlined,
                      title: 'Reports & Analytics',
                      subtitle: 'View team performance',
                      color: AppColors.accent,
                      isDark: isDark,
                      onTap: () => context.push('/leader/reports'),
                    ),
                    const SizedBox(height: 12),
                    _ManagementTile(
                      icon: Icons.schedule_outlined,
                      title: 'Schedule',
                      subtitle: 'Manage team schedules',
                      color: AppColors.warning,
                      isDark: isDark,
                      onTap: () => context.push('/leader/schedule'),
                    ),
                    const SizedBox(height: 12),
                    _ManagementTile(
                      icon: Icons.assignment,
                      title: 'Surveys',
                      subtitle: 'Create and manage surveys',
                      color: AppColors.success,
                      isDark: isDark,
                      onTap: () => context.push('/leader/survey'),
                    ),
                    const SizedBox(height: 12),
                    _ManagementTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'Team Chat',
                      subtitle: 'Message team members',
                      color: AppColors.secondary,
                      isDark: isDark,
                      onTap: () => context.push('/leader/chat'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Recent Activity
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BlocBuilder<DashboardBloc, DashboardState>(
                  builder: (context, state) {
                    final activities = state is DashboardLoaded
                        ? state.recentActivity
                        : <TeamActivity>[];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Team Activity',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // TODO: View all activity
                              },
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (activities.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 48,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No recent team activity',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...activities.take(5).map((activity) => _ActivityCard(
                            activity: activity,
                            isDark: isDark,
                          )),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _OverviewCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ManagementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final TeamActivity activity;
  final bool isDark;

  const _ActivityCard({
    required this.activity,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.activityIcon,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      activity.workerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getActivityColor(activity.type).withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getActivityLabel(activity.type),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getActivityColor(activity.type),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description.isNotEmpty
                      ? activity.description
                      : _getDefaultDescription(activity),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                if (activity.territoryName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity.territoryName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatTimestamp(activity.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'check_in':
        return AppColors.success;
      case 'check_out':
        return AppColors.warning;
      case 'visit':
        return AppColors.primary;
      case 'assignment':
        return AppColors.secondary;
      default:
        return AppColors.accent;
    }
  }

  String _getActivityLabel(String type) {
    switch (type) {
      case 'check_in':
        return 'CHECK IN';
      case 'check_out':
        return 'CHECK OUT';
      case 'visit':
        return 'VISIT';
      case 'assignment':
        return 'ASSIGNED';
      default:
        return 'ACTIVITY';
    }
  }

  String _getDefaultDescription(TeamActivity activity) {
    switch (activity.type) {
      case 'check_in':
        return 'Started working on territory';
      case 'check_out':
        return 'Finished working on territory';
      case 'visit':
        return activity.address ?? 'Visited a household';
      case 'assignment':
        return 'New territory assigned';
      default:
        return 'Activity recorded';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }
}
