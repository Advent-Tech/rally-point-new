part of 'schedule_bloc.dart';

abstract class ScheduleState extends Equatable {
  const ScheduleState();

  @override
  List<Object?> get props => [];
}

class ScheduleInitial extends ScheduleState {}

class ScheduleLoading extends ScheduleState {}

class ScheduleLoaded extends ScheduleState {
  final List<TeamMember> workers;
  final List<TerritoryAssignment> territories;
  final List<ScheduleEntry> schedules;
  final DateTime selectedDate;
  final String teamId;

  const ScheduleLoaded({
    required this.workers,
    required this.territories,
    required this.schedules,
    required this.selectedDate,
    required this.teamId,
  });

  ScheduleLoaded copyWith({
    List<TeamMember>? workers,
    List<TerritoryAssignment>? territories,
    List<ScheduleEntry>? schedules,
    DateTime? selectedDate,
    String? teamId,
  }) {
    return ScheduleLoaded(
      workers: workers ?? this.workers,
      territories: territories ?? this.territories,
      schedules: schedules ?? this.schedules,
      selectedDate: selectedDate ?? this.selectedDate,
      teamId: teamId ?? this.teamId,
    );
  }

  @override
  List<Object?> get props => [workers, territories, schedules, selectedDate, teamId];
}

class ScheduleError extends ScheduleState {
  final String message;

  const ScheduleError({required this.message});

  @override
  List<Object?> get props => [message];
}

class ScheduleEntry {
  final String id;
  final String teamId;
  final String workerId;
  final String workerName;
  final String? territoryId;
  final String? territoryName;
  final DateTime scheduledDate;
  final String startTime; // "HH:MM" format
  final String endTime;   // "HH:MM" format
  final String status;
  final String? notes;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;

  const ScheduleEntry({
    required this.id,
    required this.teamId,
    required this.workerId,
    required this.workerName,
    this.territoryId,
    this.territoryName,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
    this.actualStartTime,
    this.actualEndTime,
  });

  /// Get start time as DateTime on the scheduled date
  DateTime get startDateTime {
    final parts = startTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
  }

  /// Get end time as DateTime on the scheduled date
  DateTime get endDateTime {
    final parts = endTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
  }

  /// Formatted time range (e.g., "9:00 AM - 5:00 PM")
  String get formattedTimeRange {
    String formatTime(String time) {
      final parts = time.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts.length > 1 ? parts[1] : '00';
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }
    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }

  /// Check if schedule is currently active
  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(startDateTime) && now.isBefore(endDateTime) &&
           now.year == scheduledDate.year &&
           now.month == scheduledDate.month &&
           now.day == scheduledDate.day;
  }

  /// Check if schedule is upcoming today
  bool get isUpcomingToday {
    final now = DateTime.now();
    return now.isBefore(startDateTime) &&
           now.year == scheduledDate.year &&
           now.month == scheduledDate.month &&
           now.day == scheduledDate.day;
  }

  ScheduleEntry copyWith({
    String? id,
    String? teamId,
    String? workerId,
    String? workerName,
    String? territoryId,
    String? territoryName,
    DateTime? scheduledDate,
    String? startTime,
    String? endTime,
    String? status,
    String? notes,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
  }) {
    return ScheduleEntry(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      territoryId: territoryId ?? this.territoryId,
      territoryName: territoryName ?? this.territoryName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
    );
  }

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    // Parse date - could be ISO8601 datetime or just date string
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      final str = value.toString();
      // If it has T, it's ISO8601 format
      if (str.contains('T')) {
        // Convert to local time to ensure consistent date comparison
        return DateTime.parse(str).toLocal();
      }
      // Otherwise it's just a date like "2024-12-22"
      return DateTime.parse('${str}T00:00:00');
    }

    return ScheduleEntry(
      id: json['id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      workerId: json['worker_id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? 'Unknown',
      territoryId: json['territory_id']?.toString(),
      territoryName: json['territory_name']?.toString(),
      scheduledDate: parseDate(json['date'] ?? json['scheduled_date']),
      startTime: json['start_time']?.toString() ?? '09:00',
      endTime: json['end_time']?.toString() ?? '17:00',
      status: json['status']?.toString() ?? 'scheduled',
      notes: json['notes']?.toString(),
      actualStartTime: json['actual_start_time'] != null
          ? DateTime.tryParse(json['actual_start_time'].toString())
          : null,
      actualEndTime: json['actual_end_time'] != null
          ? DateTime.tryParse(json['actual_end_time'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'worker_id': workerId,
      'worker_name': workerName,
      'territory_id': territoryId,
      'territory_name': territoryName,
      'date': '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'notes': notes,
    };
  }
}
