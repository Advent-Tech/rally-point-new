import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/work_session/work_session_bloc.dart';
import '../../blocs/territory/territory_bloc.dart';
import '../../blocs/worker_schedule/worker_schedule_bloc.dart';
import '../../blocs/schedule/schedule_bloc.dart';
import '../../blocs/delivery/delivery_bloc.dart';
import '../../../core/theme/theme.dart';
import '../../widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WorkSessionBloc _workSessionBloc;
  late WorkerScheduleBloc _scheduleBloc;

  @override
  void initState() {
    super.initState();
    _workSessionBloc = WorkSessionBloc();
    _workSessionBloc.add(const WorkSessionLoadCurrent());

    _scheduleBloc = WorkerScheduleBloc();
    _scheduleBloc.add(WorkerScheduleLoad(date: DateTime.now()));

    // Load assignments for territory selection (for workers)
    // For team leaders, we'll load allocations in build() after checking the role
    context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());

    // Load recent deliveries
    context.read<DeliveryBloc>().add(const DeliveryLoadList());

    // Load team leader allocations if user is a team leader
    // This is done after the first frame to ensure AuthBloc state is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated &&
          (authState.user.isTeamLeader || authState.user.isAdmin)) {
        // Load allocated territories for team leaders
        context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
      }
    });
  }

  @override
  void dispose() {
    _workSessionBloc.close();
    _scheduleBloc.close();
    super.dispose();
  }

  void _showTerritorySelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TerritorySelectionSheet(
        onTerritorySelected: (territoryId, territoryName) {
          _workSessionBloc.add(WorkSessionCheckIn(
            territoryId: territoryId,
            territoryName: territoryName,
          ));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEndSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end your current work session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _workSessionBloc.add(const WorkSessionCheckOut());
              Navigator.pop(context);
            },
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  void _showScheduleStartDialog(BuildContext context, ScheduleEntry schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your shift is scheduled for ${schedule.formattedTimeRange}.'),
            const SizedBox(height: 8),
            if (schedule.territoryName != null)
              Text('Territory: ${schedule.territoryName}'),
            const SizedBox(height: 16),
            const Text('Would you like to start your session now?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Yet'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _scheduleBloc.add(WorkerScheduleStartSession(scheduleId: schedule.id));
              _workSessionBloc.add(WorkSessionCheckIn(
                territoryId: schedule.territoryId ?? '',
                territoryName: schedule.territoryName ?? 'Unknown Territory',
              ));
            },
            child: const Text('Start Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _workSessionBloc),
        BlocProvider.value(value: _scheduleBloc),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        // Only rebuild when auth type changes or user role changes
        buildWhen: (previous, current) {
          // Rebuild if state type changed (e.g., from loading to authenticated)
          if (previous.runtimeType != current.runtimeType) return true;
          // If both are authenticated, only rebuild if role changed
          if (previous is AuthAuthenticated && current is AuthAuthenticated) {
            return previous.user.role != current.user.role ||
                   previous.user.id != current.user.id;
          }
          return false;
        },
        builder: (context, authState) {
          if (authState is AuthAuthenticated &&
              (authState.user.isTeamLeader || authState.user.isAdmin)) {
            return _buildLeaderDashboard(context, authState, isDark);
          }
          return _buildWorkerHome(context, authState, isDark);
        },
      ),
    );
  }

  // Leader Dashboard
  Widget _buildLeaderDashboard(BuildContext context, AuthAuthenticated authState, bool isDark) {
    final userName = authState.user.displayName ?? 'Leader';

    return Scaffold(
      body: SafeArea(
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
                  onPressed: () {},
                ),
                IconButton(
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'L',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onPressed: () => context.go('/profile'),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Welcome Section for Leader
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Team Dashboard',
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
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield, size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Team Leader',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Team Overview Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Team Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: const Text('Loading...'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Team Overview Stats Grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BlocBuilder<TerritoryBloc, TerritoryState>(
                  builder: (context, territoryState) {
                    int territoryCount = 0;
                    if (territoryState is TerritoryAllocationsLoaded) {
                      territoryCount = territoryState.territories.length;
                    } else if (territoryState is TerritoryAssignmentsLoaded) {
                      territoryCount = territoryState.assignments.length;
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OverviewStatCard(
                                icon: Icons.people_outline,
                                iconBackgroundColor: AppColors.primary,
                                title: 'Total Workers',
                                value: '0',
                                unit: 'workers',
                                description: 'Team members',
                                trendText: '0 online now',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OverviewStatCard(
                                icon: Icons.location_on_outlined,
                                iconBackgroundColor: AppColors.secondary,
                                title: 'Active Workers',
                                value: '0',
                                unit: 'tracking',
                                description: 'Currently in field',
                                trendText: 'No active tracking',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OverviewStatCard(
                                icon: Icons.map_outlined,
                                iconBackgroundColor: AppColors.warning,
                                title: 'Territories',
                                value: '$territoryCount',
                                unit: 'areas',
                                description: 'Assigned to team',
                                trendText: 'All assigned',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: BlocBuilder<DeliveryBloc, DeliveryState>(
                                builder: (context, deliveryState) {
                                  int deliveryCount = 0;
                                  if (deliveryState is DeliveryListLoaded) {
                                    deliveryCount = deliveryState.deliveries.length;
                                  }
                                  return OverviewStatCard(
                                    icon: Icons.local_shipping_outlined,
                                    iconBackgroundColor: AppColors.accent,
                                    title: "Today's Deliveries",
                                    value: '$deliveryCount',
                                    unit: 'books',
                                    description: 'Delivered today',
                                    trendText: '$deliveryCount total',
                                    trendColor: deliveryCount > 0 ? AppColors.success : AppColors.error,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OverviewStatCard(
                                icon: Icons.assignment_outlined,
                                iconBackgroundColor: AppColors.info,
                                title: 'Completed Surveys',
                                value: '0',
                                unit: 'responses',
                                description: 'Survey responses',
                                trendText: 'This month',
                                trendColor: AppColors.success,
                              ),
                            ),
                            const Expanded(child: SizedBox()), // Empty space for odd number
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Management Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team Management',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ManagementListCard(
                      items: [
                        _ManagementItem(
                          icon: Icons.verified_user,
                          label: 'Verify Workers',
                          description: 'Approve or reject join requests',
                          color: AppColors.accent,
                          onTap: () => context.go('/leader/worker-verification'),
                        ),
                        _ManagementItem(
                          icon: Icons.assignment,
                          label: 'Manage Surveys',
                          description: 'View surveys and responses',
                          color: AppColors.warning,
                          onTap: () => context.go('/survey'),
                        ),
                        _ManagementItem(
                          icon: Icons.people,
                          label: 'Team Members',
                          description: 'View and manage your team',
                          color: AppColors.primary,
                          onTap: () => context.go('/team'),
                        ),
                        _ManagementItem(
                          icon: Icons.calendar_month,
                          label: 'Schedule Workers',
                          description: 'Assign shifts and territories',
                          color: AppColors.secondary,
                          onTap: () => context.go('/schedule'),
                        ),
                        _ManagementItem(
                          icon: Icons.bar_chart,
                          label: 'Team Reports',
                          description: 'View performance metrics',
                          color: AppColors.success,
                          onTap: () => context.go('/reports'),
                        ),
                        _ManagementItem(
                          icon: Icons.article,
                          label: 'News & Updates',
                          description: 'View organization news',
                          color: AppColors.info,
                          onTap: () => context.go('/leader/blogs'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Quick Actions for Leaders - removed since Management section covers these

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Recent Team Activity
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Team Activity',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/reports'),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        children: [
                          _ActivityItem(
                            icon: Icons.assignment_turned_in,
                            title: 'Survey Completed',
                            subtitle: 'John D. completed "Customer Feedback"',
                            time: '5 min ago',
                            color: AppColors.success,
                            isDark: isDark,
                          ),
                          Divider(height: 1, indent: 72, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                          _ActivityItem(
                            icon: Icons.login,
                            title: 'Session Started',
                            subtitle: 'Sarah M. checked in at Territory A',
                            time: '15 min ago',
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                          Divider(height: 1, indent: 72, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                          _ActivityItem(
                            icon: Icons.local_shipping,
                            title: 'Delivery Made',
                            subtitle: 'Mike T. delivered to 123 Main St',
                            time: '32 min ago',
                            color: AppColors.accent,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // Worker Home Screen
  Widget _buildWorkerHome(BuildContext context, AuthState authState, bool isDark) {
    final userName = authState is AuthAuthenticated
        ? authState.user.displayName ?? 'User'
        : 'User';

    return Scaffold(
      body: SafeArea(
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
                  onPressed: () {},
                ),
                IconButton(
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      authState is AuthAuthenticated
                          ? (authState.user.displayName?.isNotEmpty == true
                              ? authState.user.displayName![0].toUpperCase()
                              : 'U')
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onPressed: () => context.go('/profile'),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Welcome Section
            SliverToBoxAdapter(
              child: Padding(
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
                  ],
                ),
              ),
            ),

            // Today's Schedule Card
            SliverToBoxAdapter(
              child: BlocBuilder<WorkerScheduleBloc, WorkerScheduleState>(
                builder: (context, state) {
                  if (state is WorkerScheduleLoaded) {
                    final currentSchedule = state.currentOrNextSchedule;
                    if (currentSchedule != null) {
                      return _TodayScheduleCard(
                        schedule: currentSchedule,
                        onViewAll: () => context.go('/my-schedule'),
                        onStartSession: currentSchedule.status == 'scheduled'
                            ? () => _showScheduleStartDialog(context, currentSchedule)
                            : null,
                      );
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _NoScheduleCard(onViewSchedule: () => context.go('/my-schedule')),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Location Status Banner
            SliverToBoxAdapter(
              child: Center(
                child: BlocBuilder<WorkSessionBloc, WorkSessionState>(
                  builder: (context, sessionState) {
                    final isActive = sessionState is WorkSessionActive;
                    return LocationStatusBanner(
                      isActive: isActive,
                      onTap: () {
                        if (isActive) {
                          _showEndSessionDialog(context);
                        } else {
                          _showTerritorySelectionSheet(context);
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Quick Actions Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Quick Action',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Quick Actions Grid (Worker) - Large colorful tiles
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BlocBuilder<WorkSessionBloc, WorkSessionState>(
                  builder: (context, sessionState) {
                    return QuickActionGrid(
                      actions: [
                        QuickActionTileData(
                          icon: Icons.map_outlined,
                          label: 'My Territory',
                          backgroundColor: QuickActionColors.territory,
                          onTap: () => context.go('/territory'),
                        ),
                        QuickActionTileData(
                          icon: Icons.volunteer_activism_outlined,
                          label: 'Donation',
                          backgroundColor: QuickActionColors.delivery,
                          onTap: () => context.go('/delivery'),
                        ),
                        QuickActionTileData(
                          icon: Icons.assignment_outlined,
                          label: 'Survey Form',
                          backgroundColor: QuickActionColors.survey,
                          onTap: () => context.go('/survey'),
                        ),
                        QuickActionTileData(
                          icon: Icons.volunteer_activism,
                          label: 'Prayer Request',
                          backgroundColor: QuickActionColors.prayer,
                          onTap: () => context.go('/prayer-requests/new'),
                        ),
                        QuickActionTileData(
                          icon: Icons.groups_outlined,
                          label: 'Team Group',
                          backgroundColor: QuickActionColors.team,
                          onTap: () => context.go('/chat'),
                        ),
                        QuickActionTileData(
                          icon: Icons.gps_fixed,
                          label: 'GPS Tracking',
                          backgroundColor: QuickActionColors.tracking,
                          onTap: () {
                            if (sessionState is WorkSessionActive) {
                              _showEndSessionDialog(context);
                            } else {
                              _showTerritorySelectionSheet(context);
                            }
                          },
                        ),
                        QuickActionTileData(
                          icon: Icons.article_outlined,
                          label: 'News',
                          backgroundColor: QuickActionColors.news,
                          onTap: () => context.go('/blogs'),
                        ),
                        QuickActionTileData(
                          icon: Icons.emoji_events_outlined,
                          label: 'Achievements',
                          backgroundColor: QuickActionColors.achievements,
                          onTap: () {}, // TODO: Navigate to achievements
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Session Tracking Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Tracking',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SessionTrackingCard(),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Ministry Overview Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Ministry Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Ministry Stats Grid
            SliverToBoxAdapter(
              child: BlocBuilder<WorkSessionBloc, WorkSessionState>(
                builder: (context, sessionState) {
                  String hoursActive = '0.0';

                  if (sessionState is WorkSessionActive) {
                    // Convert duration to hours
                    final duration = sessionState.session.duration;
                    hoursActive = (duration.inMinutes / 60).toStringAsFixed(1);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OverviewStatCard(
                                icon: Icons.route_outlined,
                                iconBackgroundColor: AppColors.primary,
                                title: 'Distance Covered',
                                value: '0.0',
                                unit: 'km',
                                description: 'Total distance',
                                trendText: 'No data',
                                trendColor: AppColors.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: BlocBuilder<DeliveryBloc, DeliveryState>(
                                builder: (context, deliveryState) {
                                  int deliveryCount = 0;
                                  if (deliveryState is DeliveryListLoaded) {
                                    deliveryCount = deliveryState.deliveries.length;
                                  }
                                  return OverviewStatCard(
                                    icon: Icons.menu_book_outlined,
                                    iconBackgroundColor: AppColors.secondary,
                                    title: 'Books Delivered',
                                    value: '$deliveryCount',
                                    unit: 'books',
                                    description: 'Total deliveries',
                                    trendText: deliveryCount > 0 ? '$deliveryCount total' : 'No activity',
                                    trendColor: deliveryCount > 0 ? AppColors.success : AppColors.error,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OverviewStatCard(
                                icon: Icons.schedule_outlined,
                                iconBackgroundColor: AppColors.accent,
                                title: 'Hours Active',
                                value: hoursActive,
                                unit: 'hours',
                                description: 'Total ministry time',
                                trendText: 'No surveys',
                                trendColor: AppColors.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OverviewStatCard(
                                icon: Icons.attach_money,
                                iconBackgroundColor: AppColors.success,
                                title: 'Donations Collected',
                                value: '\$0',
                                description: 'Total donations',
                                trendText: 'No donations',
                                trendColor: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Territory Overview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Territory',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/territory'),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BlocBuilder<TerritoryBloc, TerritoryState>(
                      builder: (context, state) {
                        if (state is TerritoryLoading) {
                          return Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (state is TerritoryAssignmentsLoaded && state.assignments.isNotEmpty) {
                          final assignment = state.assignments.first;
                          final territoryName = assignment.entityName ?? 'Territory ${assignment.entityId}';
                          final completeness = assignment.completenessPercentage;

                          return GestureDetector(
                            onTap: () => context.go('/territory'),
                            child: Container(
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
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.map,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          territoryName,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                assignment.status.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${completeness.toStringAsFixed(0)}% complete',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (state.assignments.length > 1) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '+${state.assignments.length - 1} more territories',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
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
                          );
                        }

                        // No territories assigned
                        return Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 48,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No territory assigned',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CustomButton(
                                  text: 'Browse Territories',
                                  type: ButtonType.outline,
                                  size: ButtonSize.small,
                                  onPressed: () => context.go('/territory'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Activity',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/delivery'),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BlocBuilder<DeliveryBloc, DeliveryState>(
                      builder: (context, state) {
                        if (state is DeliveryLoading) {
                          return Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (state is DeliveryListLoaded && state.deliveries.isNotEmpty) {
                          // Show up to 3 recent activities
                          final recentDeliveries = state.deliveries.take(3).toList();

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Column(
                              children: recentDeliveries.asMap().entries.map((entry) {
                                final index = entry.key;
                                final delivery = entry.value;
                                const color = AppColors.success;
                                final time = delivery.createdAt ?? delivery.completedAt;

                                return Column(
                                  children: [
                                    ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.volunteer_activism,
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        delivery.recipientName,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        time != null
                                            ? DateFormat('MMM d, h:mm a').format(time)
                                            : 'Donation',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                      trailing: Text(
                                        '\$${(delivery.donationAmount ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      onTap: () => context.go('/delivery'),
                                    ),
                                    if (index < recentDeliveries.length - 1)
                                      Divider(
                                        height: 1,
                                        indent: 72,
                                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                        }

                        // No recent activity
                        return Container(
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
                                  'No recent activity',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _TerritorySelectionSheet extends StatelessWidget {
  final Function(String territoryId, String territoryName) onTerritorySelected;

  const _TerritorySelectionSheet({
    required this.onTerritorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Territory',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Territory list
              Expanded(
                child: BlocBuilder<TerritoryBloc, TerritoryState>(
                  builder: (context, state) {
                    if (state is TerritoryLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is TerritoryAssignmentsLoaded) {
                      final assignments = state.assignments;
                      if (assignments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No territories assigned',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Contact your team leader for assignments',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: assignments.length,
                        itemBuilder: (context, index) {
                          final assignment = assignments[index];
                          // Use territoryId (UUID) for API calls, entityId for display
                          final territoryUuid = assignment.territoryId;
                          final displayId = assignment.entityId ?? assignment.territorySolid;
                          final entityName = assignment.entityName ?? 'Territory $displayId';
                          return _TerritoryListItem(
                            name: entityName,
                            id: displayId,
                            status: assignment.status,
                            completeness: assignment.completenessPercentage,
                            onTap: () => onTerritorySelected(territoryUuid, entityName),
                          );
                        },
                      );
                    }

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load territories',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TerritoryListItem extends StatelessWidget {
  final String name;
  final String id;
  final String status;
  final double? completeness;
  final VoidCallback onTap;

  const _TerritoryListItem({
    required this.name,
    required this.id,
    required this.status,
    this.completeness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completionPercent = completeness ?? 0.0;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.map,
          color: AppColors.primary,
        ),
      ),
      title: Text(
        name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${completionPercent.toStringAsFixed(0)}% complete',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.primary;
      default:
        return AppColors.textSecondaryLight;
    }
  }
}

class _TodayScheduleCard extends StatelessWidget {
  final ScheduleEntry schedule;
  final VoidCallback onViewAll;
  final VoidCallback? onStartSession;

  const _TodayScheduleCard({
    required this.schedule,
    required this.onViewAll,
    this.onStartSession,
  });

  Color _getStatusColor() {
    switch (schedule.status) {
      case 'in_progress':
        return AppColors.success;
      case 'completed':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor();
    final isNow = schedule.isNow;
    final isUpcoming = schedule.isUpcomingToday;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: isNow
              ? LinearGradient(
                  colors: [
                    AppColors.success.withValues(alpha: 0.15),
                    AppColors.success.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isNow ? null : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNow ? AppColors.success : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isNow ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: statusColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isNow ? "Current Shift" : (isUpcoming ? "Upcoming Shift" : "Today's Schedule"),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: onViewAll,
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          schedule.formattedTimeRange,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (schedule.territoryName != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      schedule.territoryName!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                schedule.status.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onStartSession != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: FilledButton.icon(
                  onPressed: onStartSession,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Session Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoScheduleCard extends StatelessWidget {
  final VoidCallback onViewSchedule;

  const _NoScheduleCard({required this.onViewSchedule});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onViewSchedule,
      child: Container(
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_available,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No scheduled shifts today',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view your full schedule',
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
    );
  }
}

// Data class for management items
class _ManagementItem {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ManagementItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });
}

// Management list card widget for team leaders
class _ManagementListCard extends StatelessWidget {
  final List<_ManagementItem> items;

  const _ManagementListCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(16) : Radius.zero,
                    bottom: isLast ? const Radius.circular(16) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: item.color, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 80,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// Activity item for team activity feed
class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;
  final bool isDark;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        time,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
