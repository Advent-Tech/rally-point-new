part of 'worker_schedule_bloc.dart';

abstract class WorkerScheduleState extends Equatable {
  const WorkerScheduleState();

  @override
  List<Object?> get props => [];
}

class WorkerScheduleInitial extends WorkerScheduleState {}

class WorkerScheduleLoading extends WorkerScheduleState {}

class WorkerScheduleLoaded extends WorkerScheduleState {
  final List<ScheduleEntry> schedules;
  final DateTime selectedDate;

  const WorkerScheduleLoaded({
    required this.schedules,
    required this.selectedDate,
  });

  /// Get the current or next upcoming schedule for today
  ScheduleEntry? get currentOrNextSchedule {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todaySchedules = schedules.where((s) {
      final scheduleDate = DateTime(
        s.scheduledDate.year,
        s.scheduledDate.month,
        s.scheduledDate.day,
      );
      return scheduleDate == today && s.status != 'cancelled' && s.status != 'missed';
    }).toList();

    if (todaySchedules.isEmpty) return null;

    // First check for in_progress
    final inProgress = todaySchedules.where((s) => s.status == 'in_progress').toList();
    if (inProgress.isNotEmpty) return inProgress.first;

    // Then check for upcoming scheduled
    final upcoming = todaySchedules.where((s) =>
      s.status == 'scheduled' && s.startDateTime.isAfter(now)
    ).toList();
    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      return upcoming.first;
    }

    // Return first scheduled even if past time
    final scheduled = todaySchedules.where((s) => s.status == 'scheduled').toList();
    if (scheduled.isNotEmpty) return scheduled.first;

    return null;
  }

  /// Get today's schedules
  List<ScheduleEntry> get todaySchedules {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return schedules.where((s) {
      final scheduleDate = DateTime(
        s.scheduledDate.year,
        s.scheduledDate.month,
        s.scheduledDate.day,
      );
      return scheduleDate == today;
    }).toList();
  }

  @override
  List<Object?> get props => [schedules, selectedDate];
}

class WorkerScheduleRangeLoaded extends WorkerScheduleState {
  final List<ScheduleEntry> schedules;
  final DateTime startDate;
  final DateTime endDate;

  const WorkerScheduleRangeLoaded({
    required this.schedules,
    required this.startDate,
    required this.endDate,
  });

  /// Group schedules by date
  Map<DateTime, List<ScheduleEntry>> get schedulesByDate {
    final map = <DateTime, List<ScheduleEntry>>{};
    for (final schedule in schedules) {
      final date = DateTime(
        schedule.scheduledDate.year,
        schedule.scheduledDate.month,
        schedule.scheduledDate.day,
      );
      map[date] ??= [];
      map[date]!.add(schedule);
    }
    return map;
  }

  @override
  List<Object?> get props => [schedules, startDate, endDate];
}

class WorkerScheduleError extends WorkerScheduleState {
  final String message;

  const WorkerScheduleError({required this.message});

  @override
  List<Object?> get props => [message];
}

class WorkerScheduleSessionStarted extends WorkerScheduleState {
  final String scheduleId;

  const WorkerScheduleSessionStarted({required this.scheduleId});

  @override
  List<Object?> get props => [scheduleId];
}

class WorkerScheduleSessionCompleted extends WorkerScheduleState {
  final String scheduleId;

  const WorkerScheduleSessionCompleted({required this.scheduleId});

  @override
  List<Object?> get props => [scheduleId];
}

class WorkerScheduleTimeToStart extends WorkerScheduleState {
  final ScheduleEntry schedule;

  const WorkerScheduleTimeToStart({required this.schedule});

  @override
  List<Object?> get props => [schedule];
}
