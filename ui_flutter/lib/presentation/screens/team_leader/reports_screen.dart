import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/role_badge.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DashboardBloc _dashboardBloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dashboardBloc = DashboardBloc();
    _loadData();
  }

  void _loadData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.user.teamId != null) {
      _dashboardBloc.add(DashboardLoadStats(teamId: authState.user.teamId!));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dashboardBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _dashboardBloc,
      child: Scaffold(
        appBar: AppBar(
          leading: GoRouter.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                )
              : null,
          title: const Text('Reports & Analytics'),
          actions: [
            const RoleBadge(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Team'),
              Tab(text: 'Territories'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(isDark: isDark),
            _TeamTab(isDark: isDark),
            _TerritoriesTab(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final bool isDark;

  const _OverviewTab({required this.isDark});

  /// Calculate daily activity counts for the current week
  Map<String, int> _calculateDailyActivityCounts(
    List<TeamActivity> activities,
  ) {
    final counts = <String, int>{
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    for (final activity in activities) {
      final activityDate = DateTime(
        activity.timestamp.year,
        activity.timestamp.month,
        activity.timestamp.day,
      );

      // Only count activities from this week
      if (activityDate.isAfter(
            weekStartDate.subtract(const Duration(days: 1)),
          ) &&
          activityDate.isBefore(weekStartDate.add(const Duration(days: 7)))) {
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayIndex = activity.timestamp.weekday - 1; // weekday is 1-7
        if (dayIndex >= 0 && dayIndex < dayNames.length) {
          counts[dayNames[dayIndex]] = (counts[dayNames[dayIndex]] ?? 0) + 1;
        }
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DashboardLoaded) {
          final stats = state.stats;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Book Sales',
                        value: '${stats.totalBookSales}',
                        subtitle: 'Sold',
                        icon: Icons.menu_book_rounded,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Visits Today',
                        value: '${stats.visitsToday}',
                        subtitle: '${stats.visitsThisWeek} this week',
                        icon: Icons.today,
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
                      child: _MetricCard(
                        title: 'Active Workers',
                        value: '${stats.activeWorkers}',
                        subtitle: 'Right now',
                        icon: Icons.people,
                        color: AppColors.accent,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Donations',
                        value: '${stats.totalDonations}',
                        subtitle: 'Collected',
                        icon: Icons.volunteer_activism,
                        color: AppColors.secondary,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Activity Chart - Real data from recent activity
                Text(
                  'Activity Trend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    // Calculate daily activity counts for the past week
                    final dailyCounts = _calculateDailyActivityCounts(
                      state.recentActivity,
                    );
                    final maxCount = dailyCounts.values.fold<int>(
                      0,
                      (max, count) => count > max ? count : max,
                    );

                    return Container(
                      height: 200,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Simple bar chart visualization with real data
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children:
                                  [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ].map((day) {
                                    final count = dailyCounts[day] ?? 0;
                                    final value = maxCount > 0
                                        ? count / maxCount
                                        : 0.0;
                                    return _ChartBar(
                                      value: value,
                                      label: day,
                                      isDark: isDark,
                                      count: count,
                                    );
                                  }).toList(),
                            ),
                          ),
                          if (maxCount == 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'No activity data this week',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Recent Activity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(onPressed: () {}, child: const Text('See All')),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.recentActivity.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No recent activity',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...state.recentActivity
                      .take(5)
                      .map(
                        (activity) =>
                            _ActivityItem(activity: activity, isDark: isDark),
                      ),
              ],
            ),
          );
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load reports'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated &&
                      authState.user.teamId != null) {
                    context.read<DashboardBloc>().add(
                      DashboardLoadStats(teamId: authState.user.teamId!),
                    );
                  }
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamTab extends StatefulWidget {
  final bool isDark;

  const _TeamTab({required this.isDark});

  @override
  State<_TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<_TeamTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DashboardLoaded) {
          final filteredWorkers = state.workerPerformance
              .where(
                (w) =>
                    w.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Summary
                Container(
                  padding: const EdgeInsets.all(20),
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
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _TeamStatItem(
                            value: '${state.stats.totalMembers}',
                            label: 'Total Members',
                            color: AppColors.primary,
                          ),
                          _TeamStatItem(
                            value: '${state.stats.activeWorkers}',
                            label: 'Active Now',
                            color: AppColors.success,
                          ),
                          _TeamStatItem(
                            value:
                                '\$${state.workerPerformance.fold<double>(0, (sum, w) => sum + w.donationsTotal).toStringAsFixed(0)}',
                            label: 'Donations',
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search workers...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: widget.isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),

                const SizedBox(height: 24),

                // Worker Performance
                Text(
                  'Worker Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (filteredWorkers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.people_outline
                                : Icons.search_off,
                            size: 48,
                            color: widget.isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No worker data available'
                                : 'No workers found',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: widget.isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredWorkers.map(
                    (worker) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Builder(
                        builder: (ctx) {
                          final authState = context.read<AuthBloc>().state;
                          final teamId = authState is AuthAuthenticated
                              ? authState.user.teamId ?? ''
                              : '';
                          return GestureDetector(
                            onTap: () => context.push(
                              '/leader/worker/${worker.id}?name=${Uri.encodeComponent(worker.name)}&teamId=$teamId',
                            ),
                            child: _WorkerPerformanceCard(
                              name: worker.name,
                              donationsTotal: worker.donationsTotal,
                              coverage: worker.territoryCoverage / 100,
                              territoriesAssigned: worker.territoriesAssigned,
                              isActive: worker.isActive,
                              isDark: widget.isDark,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return const Center(child: Text('No data available'));
      },
    );
  }
}

class _TerritoriesTab extends StatelessWidget {
  final bool isDark;

  const _TerritoriesTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DashboardLoaded) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Territory Summary
                Builder(
                  builder: (context) {
                    // Calculate totals from territory stats
                    int totalHouseholds = 0;
                    int totalVisited = 0;
                    for (final t in state.territoryStats) {
                      totalHouseholds += t.housingUnits;
                      totalVisited += t.visitedCount;
                    }
                    final overallCoverage = totalHouseholds > 0
                        ? (totalVisited / totalHouseholds * 100)
                        : 0.0;

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _TeamStatItem(
                                value: '${state.stats.totalTerritories}',
                                label: 'Territories',
                                color: AppColors.primary,
                              ),
                              _TeamStatItem(
                                value: '$totalHouseholds',
                                label: 'Households',
                                color: AppColors.accent,
                              ),
                              _TeamStatItem(
                                value: '${overallCoverage.toStringAsFixed(0)}%',
                                label: 'Coverage',
                                color: AppColors.success,
                              ),
                            ],
                          ),
                          if (totalHouseholds > 0) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (overallCoverage / 100).clamp(0, 1),
                                backgroundColor: AppColors.success.withAlpha(
                                  30,
                                ),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.success,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$totalVisited visited • ${totalHouseholds - totalVisited} remaining',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'Territory Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (state.territoryStats.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 48,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No territory data available',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...state.territoryStats.map(
                    (territory) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TerritoryReportCard(
                        name: territory.name,
                        assignee: territory.assigneeName,
                        completion:
                            territory.completionRate /
                            100, // Convert percentage to 0-1
                        visits: territory.visitedCount,
                        housingUnits: territory.housingUnits,
                        remaining: territory.remaining,
                        lastVisited: territory.lastVisited,
                        isDark: isDark,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return const Center(child: Text('No data available'));
      },
    );
  }
}

// Helper Widgets

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
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
          color: color.withAlpha(isDark ? 90 : 65),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(isDark ? 16 : 12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withAlpha(isDark ? 80 : 55),
                      color.withAlpha(isDark ? 44 : 28),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  final double value;
  final String label;
  final bool isDark;
  final int count;

  const _ChartBar({
    required this.value,
    required this.label,
    required this.isDark,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$count activities',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          Container(
            width: 28,
            height: value > 0 ? (100 * value).clamp(8, 100) : 4,
            decoration: BoxDecoration(
              color: value > 0
                  ? AppColors.primary.withAlpha((100 + 155 * value).toInt())
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamStatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _TeamStatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _WorkerPerformanceCard extends StatelessWidget {
  final String name;
  final double donationsTotal;
  final double coverage;
  final int territoriesAssigned;
  final bool isActive;
  final bool isDark;

  const _WorkerPerformanceCard({
    required this.name,
    required this.donationsTotal,
    required this.coverage,
    this.territoriesAssigned = 0,
    this.isActive = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.success
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withAlpha(30),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isActive)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Active',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '\$${donationsTotal.toStringAsFixed(0)} donations',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    if (territoriesAssigned > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• $territoriesAssigned territories',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: coverage.clamp(0, 1),
                          backgroundColor: AppColors.primary.withAlpha(30),
                          valueColor: AlwaysStoppedAnimation(
                            _getCoverageColor(coverage),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(coverage * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getCoverageColor(coverage),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            size: 20,
          ),
        ],
      ),
    );
  }

  Color _getCoverageColor(double value) {
    if (value >= 0.75) return AppColors.success;
    if (value >= 0.5) return AppColors.warning;
    if (value >= 0.25) return AppColors.accent;
    return AppColors.error;
  }
}

class _TerritoryReportCard extends StatelessWidget {
  final String name;
  final String? assignee;
  final double completion;
  final int visits;
  final int housingUnits;
  final int remaining;
  final DateTime? lastVisited;
  final bool isDark;

  const _TerritoryReportCard({
    required this.name,
    this.assignee,
    required this.completion,
    required this.visits,
    this.housingUnits = 0,
    this.remaining = 0,
    this.lastVisited,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasAssignee =
        assignee != null && assignee!.isNotEmpty && assignee != 'Unassigned';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.map,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          hasAssignee
                              ? Icons.person
                              : Icons.person_off_outlined,
                          size: 14,
                          color: hasAssignee
                              ? AppColors.success
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hasAssignee ? assignee! : 'Unassigned',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: hasAssignee
                                      ? (isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight)
                                      : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight),
                                  fontWeight: hasAssignee
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(completion * 100).toInt()}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getCompletionColor(completion),
                    ),
                  ),
                  if (housingUnits > 0)
                    Text(
                      '$visits / $housingUnits',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    )
                  else
                    Text(
                      '$visits deliveries',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completion.clamp(0, 1),
              backgroundColor: _getCompletionColor(completion).withAlpha(30),
              valueColor: AlwaysStoppedAnimation(
                _getCompletionColor(completion),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (remaining > 0)
                Expanded(
                  child: Text(
                    '$remaining remaining',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              if (lastVisited != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Last: ${_formatLastVisited(lastVisited!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLastVisited(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      final months = (diff.inDays / 30).floor();
      return '${months}mo ago';
    }
  }

  Color _getCompletionColor(double value) {
    if (value >= 0.75) return AppColors.success;
    if (value >= 0.5) return AppColors.warning;
    if (value >= 0.25) return AppColors.accent;
    return AppColors.error;
  }
}

class _ActivityItem extends StatelessWidget {
  final TeamActivity activity;
  final bool isDark;

  const _ActivityItem({required this.activity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getActivityColor(activity.type).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getActivityIcon(activity.type),
              color: _getActivityColor(activity.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.workerName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_getActivityLabel(activity.type)} - ${activity.territoryName ?? ""}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(activity.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'check_in':
        return Icons.login;
      case 'check_out':
        return Icons.logout;
      case 'visit':
        return Icons.home;
      case 'delivery':
        return Icons.local_shipping;
      case 'donation':
        return Icons.volunteer_activism;
      case 'book_sale':
        return Icons.menu_book_rounded;
      default:
        return Icons.event;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'check_in':
        return AppColors.success;
      case 'check_out':
        return AppColors.warning;
      case 'visit':
        return AppColors.primary;
      case 'delivery':
        return AppColors.primary;
      case 'donation':
        return AppColors.accent;
      case 'book_sale':
        return AppColors.warning;
      default:
        return AppColors.secondary;
    }
  }

  String _getActivityLabel(String type) {
    switch (type) {
      case 'check_in':
        return 'Checked in';
      case 'check_out':
        return 'Checked out';
      case 'visit':
        return 'Visited';
      case 'delivery':
        return 'Delivery';
      case 'donation':
        return 'Donation';
      case 'book_sale':
        return 'Book sale';
      default:
        return type;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
