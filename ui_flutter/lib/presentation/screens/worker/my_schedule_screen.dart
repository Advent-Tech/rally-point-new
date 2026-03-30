import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../blocs/worker_schedule/worker_schedule_bloc.dart';
import '../../blocs/schedule/schedule_bloc.dart';
import '../../blocs/work_session/work_session_bloc.dart';
import '../../widgets/animations/staggered_fade_in.dart';
import '../../widgets/navigation/app_back_button.dart';
import '../../widgets/states/empty_state.dart';

class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  late WorkerScheduleBloc _scheduleBloc;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleBloc = WorkerScheduleBloc();
    _loadSchedules();
  }

  void _loadSchedules() {
    // Load a week's worth of schedules
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    _scheduleBloc.add(
      WorkerScheduleLoadRange(startDate: startOfWeek, endDate: endOfWeek),
    );
  }

  @override
  void dispose() {
    _scheduleBloc.close();
    super.dispose();
  }

  void _showStartSessionDialog(BuildContext context, ScheduleEntry schedule) {
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
              _scheduleBloc.add(
                WorkerScheduleStartSession(scheduleId: schedule.id),
              );
              // Also start work session
              context.read<WorkSessionBloc>().add(
                WorkSessionCheckIn(
                  territoryId: schedule.territoryId ?? '',
                  territoryName: schedule.territoryName ?? 'Unknown Territory',
                ),
              );
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

    return BlocProvider.value(
      value: _scheduleBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Schedule'),
          leading: AppBackButton.leading(context, fallbackRoute: '/home'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSchedules,
            ),
          ],
        ),
        body: BlocConsumer<WorkerScheduleBloc, WorkerScheduleState>(
          listener: (context, state) {
            if (state is WorkerScheduleTimeToStart) {
              _showStartSessionDialog(context, state.schedule);
            } else if (state is WorkerScheduleSessionStarted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session started!'),
                  backgroundColor: AppColors.success,
                ),
              );
            } else if (state is WorkerScheduleError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is WorkerScheduleLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is WorkerScheduleRangeLoaded) {
              return _buildCalendarView(context, state, isDark);
            }

            if (state is WorkerScheduleLoaded) {
              return _buildDayView(context, state, isDark);
            }

            if (state is WorkerScheduleError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error: ${state.message}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadSchedules,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildCalendarView(
    BuildContext context,
    WorkerScheduleRangeLoaded state,
    bool isDark,
  ) {
    final schedulesByDate = state.schedulesByDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate list of days in the week
    final startOfWeek = state.startDate;
    final days = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );

    return Column(
      children: [
        // Week navigation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(
                      const Duration(days: 7),
                    );
                  });
                  _loadSchedules();
                },
              ),
              Text(
                '${DateFormat('MMM d').format(state.startDate)} - ${DateFormat('MMM d, yyyy').format(state.endDate)}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 7));
                  });
                  _loadSchedules();
                },
              ),
            ],
          ),
        ),

        // Day tabs
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: days.map((day) {
              final isToday = day == today;
              final hasSchedule = schedulesByDate.containsKey(day);
              final isSelected =
                  day ==
                  DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                  );

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = day);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : isToday
                          ? AppColors.primary.withOpacity(0.2)
                          : isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(day),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                        if (hasSchedule)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(),

        // Schedule list for selected date
        Expanded(
          child: _buildScheduleList(
            context,
            schedulesByDate[DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                )] ??
                [],
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDayView(
    BuildContext context,
    WorkerScheduleLoaded state,
    bool isDark,
  ) {
    return _buildScheduleList(context, state.schedules, isDark);
  }

  Widget _buildScheduleList(
    BuildContext context,
    List<ScheduleEntry> schedules,
    bool isDark,
  ) {
    if (schedules.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No schedule set',
        description:
            'No shifts scheduled for this day. Your team leader will assign your schedule.',
        compact: true,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return StaggeredFadeIn(
          index: index,
          child: _ScheduleCard(
            schedule: schedule,
            onStart: schedule.status == 'scheduled'
                ? () => _showStartSessionDialog(context, schedule)
                : null,
            onComplete: schedule.status == 'in_progress'
                ? () => _scheduleBloc.add(
                    WorkerScheduleCompleteSession(scheduleId: schedule.id),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final ScheduleEntry schedule;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  const _ScheduleCard({required this.schedule, this.onStart, this.onComplete});

  Color _getStatusColor() {
    switch (schedule.status) {
      case 'in_progress':
        return AppColors.success;
      case 'completed':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      case 'missed':
        return AppColors.warning;
      default:
        return AppColors.secondary;
    }
  }

  IconData _getStatusIcon() {
    switch (schedule.status) {
      case 'in_progress':
        return Icons.play_circle_filled;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'missed':
        return Icons.warning;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: schedule.isNow
              ? statusColor
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: schedule.isNow ? 2 : 1,
        ),
        boxShadow: schedule.isNow
            ? [
                BoxShadow(
                  color: statusColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Time column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.startTime,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      schedule.endTime,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: 2,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                // Details column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getStatusIcon(), color: statusColor, size: 18),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              schedule.status.toUpperCase().replaceAll(
                                '_',
                                ' ',
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (schedule.territoryName != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
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
                      if (schedule.notes != null && schedule.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            schedule.notes!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontStyle: FontStyle.italic,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          if (onStart != null || onComplete != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  if (onStart != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onStart,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Start'),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                      ),
                    ),
                  if (onComplete != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.check, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Complete'),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
