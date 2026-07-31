import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/territory_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/schedule/schedule_bloc.dart';

class ScheduleScreen extends StatefulWidget {
  final String? teamId;

  const ScheduleScreen({super.key, this.teamId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    // Load data after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      String? teamId = widget.teamId;
      if (teamId == null && authState is AuthAuthenticated) {
        teamId = authState.user.teamId;
      }
      if (teamId != null) {
        context.read<ScheduleBloc>().add(ScheduleLoadData(teamId: teamId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Schedule Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddScheduleDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ScheduleBloc, ScheduleState>(
        builder: (context, state) {
          if (state is ScheduleLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ScheduleError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      String? teamId = widget.teamId;
                      if (teamId == null && authState is AuthAuthenticated) {
                        teamId = authState.user.teamId;
                      }
                      if (teamId != null) {
                        context.read<ScheduleBloc>().add(ScheduleLoadData(teamId: teamId));
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ScheduleLoaded) {
            return _buildLoadedContent(context, state, isDark);
          }

          return const Center(child: Text('Loading...'));
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: BlocBuilder<ScheduleBloc, ScheduleState>(
          builder: (context, state) {
            if (state is ScheduleLoaded) {
              return FloatingActionButton(
                onPressed: () => _showAddScheduleDialog(context),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                tooltip: 'Add Schedule',
                child: const Icon(Icons.add),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLoadedContent(BuildContext context, ScheduleLoaded state, bool isDark) {
    return Column(
      children: [
        // Date selector
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      final newDate = state.selectedDate.subtract(const Duration(days: 1));
                      context.read<ScheduleBloc>().add(ScheduleSelectDate(date: newDate));
                    },
                  ),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Column(
                      children: [
                        Text(
                          _formatDate(state.selectedDate),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isToday(state.selectedDate) ? 'Today' : _getDayName(state.selectedDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _isToday(state.selectedDate)
                                ? AppColors.primary
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      final newDate = state.selectedDate.add(const Duration(days: 1));
                      context.read<ScheduleBloc>().add(ScheduleSelectDate(date: newDate));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Week view
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final date = DateTime.now().subtract(Duration(days: 3 - index));
                    final isSelected = _isSameDay(date, state.selectedDate);
                    final isToday = _isToday(date);

                    return GestureDetector(
                      onTap: () {
                        context.read<ScheduleBloc>().add(ScheduleSelectDate(date: date));
                      },
                      child: Container(
                        width: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isToday ? AppColors.primary.withAlpha(30) : Colors.transparent),
                          borderRadius: BorderRadius.circular(12),
                          border: isToday && !isSelected
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getShortDayName(date),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Schedule list
        Expanded(
          child: state.schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No schedules for this day',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddScheduleDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Schedule'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.schedules.length,
                  itemBuilder: (context, index) {
                    final entry = state.schedules[index];
                    return _ScheduleCard(
                      entry: entry,
                      isDark: isDark,
                      onEdit: () => _showEditScheduleDialog(context, entry, state),
                      onDelete: () => _deleteSchedule(context, entry),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final state = context.read<ScheduleBloc>().state;
    final initialDate = state is ScheduleLoaded ? state.selectedDate : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      context.read<ScheduleBloc>().add(ScheduleSelectDate(date: picked));
    }
  }

  void _showAddScheduleDialog(BuildContext context) {
    final state = context.read<ScheduleBloc>().state;
    if (state is! ScheduleLoaded) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScheduleFormSheet(
        selectedDate: state.selectedDate,
        workers: state.workers,
        territories: state.territories,
        onSave: (workerId, workerName, territoryId, territoryName, startTime, endTime) {
          context.read<ScheduleBloc>().add(ScheduleCreate(
            workerId: workerId,
            workerName: workerName,
            territoryId: territoryId,
            territoryName: territoryName,
            date: state.selectedDate,
            startTime: startTime,
            endTime: endTime,
          ));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showEditScheduleDialog(BuildContext context, ScheduleEntry entry, ScheduleLoaded state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScheduleFormSheet(
        selectedDate: state.selectedDate,
        workers: state.workers,
        territories: state.territories,
        existingEntry: entry,
        onSave: (workerId, workerName, territoryId, territoryName, startTime, endTime) {
          context.read<ScheduleBloc>().add(ScheduleUpdate(
            scheduleId: entry.id,
            workerId: workerId,
            workerName: workerName,
            territoryId: territoryId,
            territoryName: territoryName,
            startTime: startTime,
            endTime: endTime,
          ));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _deleteSchedule(BuildContext context, ScheduleEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Are you sure you want to delete the schedule for ${entry.workerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<ScheduleBloc>().add(ScheduleDelete(scheduleId: entry.id));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getDayName(DateTime date) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  String _getShortDayName(DateTime date) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[date.weekday - 1];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ScheduleCard extends StatelessWidget {
  final ScheduleEntry entry;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.entry,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _getStatusColor(entry.status),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.workerName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 14,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      entry.territoryName ?? 'No territory',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(entry.status).withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusLabel(entry.status),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(entry.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatTime(entry.startTime)} - ${_formatTime(entry.endTime)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: onEdit,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return AppColors.success;
      case 'scheduled':
        return AppColors.primary;
      case 'completed':
        return AppColors.secondary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'scheduled':
        return 'Scheduled';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$displayHour:$minute $period';
  }
}

class _ScheduleFormSheet extends StatefulWidget {
  final DateTime selectedDate;
  final List<TeamMember> workers;
  final List<TerritoryAssignment> territories;
  final ScheduleEntry? existingEntry;
  final Function(String workerId, String workerName, String territoryId, String territoryName, String startTime, String endTime) onSave;

  const _ScheduleFormSheet({
    required this.selectedDate,
    required this.workers,
    required this.territories,
    this.existingEntry,
    required this.onSave,
  });

  @override
  State<_ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedWorkerId;
  String? _selectedTerritoryId;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _selectedWorkerId = widget.existingEntry!.workerId;
      _selectedTerritoryId = widget.existingEntry!.territoryId;
      // Parse "HH:MM" string to TimeOfDay
      _startTime = _parseTimeString(widget.existingEntry!.startTime);
      _endTime = _parseTimeString(widget.existingEntry!.endTime);
    }
  }

  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                widget.existingEntry != null ? 'Edit Schedule' : 'New Schedule',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Worker selection
              Text(
                'Light Squad',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedWorkerId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: widget.workers.isEmpty ? 'No workers available' : 'Select a worker',
                ),
                items: widget.workers.map((worker) {
                  return DropdownMenuItem(
                    value: worker.userId,
                    child: Text(worker.displayName ?? worker.email ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: widget.workers.isEmpty ? null : (value) {
                  setState(() {
                    _selectedWorkerId = value;
                  });
                },
                validator: (value) {
                  if (value == null) return 'Please select a worker';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Territory selection
              Text(
                'Territory',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTerritoryId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: widget.territories.isEmpty ? 'No territories assigned' : 'Select a territory',
                ),
                items: widget.territories.map((territory) {
                  final name = territory.entityName ?? territory.territorySolid;
                  return DropdownMenuItem(
                    value: territory.territoryId,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: widget.territories.isEmpty ? null : (value) {
                  setState(() {
                    _selectedTerritoryId = value;
                  });
                },
                validator: (value) {
                  if (value == null) return 'Please select a territory';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Time selection
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Time',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (picked != null) {
                              setState(() {
                                _startTime = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 20),
                                const SizedBox(width: 8),
                                Text(_formatTimeOfDay(_startTime)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Time',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _endTime,
                            );
                            if (picked != null) {
                              setState(() {
                                _endTime = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 20),
                                const SizedBox(width: 8),
                                Text(_formatTimeOfDay(_endTime)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveSchedule,
                  child: Text(widget.existingEntry != null ? 'Update Schedule' : 'Create Schedule'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _saveSchedule() {
    if (_formKey.currentState!.validate()) {
      final worker = widget.workers.firstWhere((w) => w.userId == _selectedWorkerId);
      final territory = widget.territories.firstWhere((t) => t.territoryId == _selectedTerritoryId);

      final workerName = worker.displayName ?? worker.email ?? 'Unknown';
      final territoryName = territory.entityName ?? territory.territorySolid;

      // Format time as "HH:MM" string
      final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

      widget.onSave(
        _selectedWorkerId!,
        workerName,
        _selectedTerritoryId!,
        territoryName,
        startTimeStr,
        endTimeStr,
      );
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
