part of 'worker_schedule_bloc.dart';

abstract class WorkerScheduleEvent extends Equatable {
  const WorkerScheduleEvent();

  @override
  List<Object?> get props => [];
}

class WorkerScheduleLoad extends WorkerScheduleEvent {
  final DateTime date;

  const WorkerScheduleLoad({required this.date});

  @override
  List<Object?> get props => [date];
}

class WorkerScheduleLoadRange extends WorkerScheduleEvent {
  final DateTime startDate;
  final DateTime endDate;

  const WorkerScheduleLoadRange({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [startDate, endDate];
}

class WorkerScheduleRefresh extends WorkerScheduleEvent {
  const WorkerScheduleRefresh();
}

class WorkerScheduleStartSession extends WorkerScheduleEvent {
  final String scheduleId;

  const WorkerScheduleStartSession({required this.scheduleId});

  @override
  List<Object?> get props => [scheduleId];
}

class WorkerScheduleCompleteSession extends WorkerScheduleEvent {
  final String scheduleId;

  const WorkerScheduleCompleteSession({required this.scheduleId});

  @override
  List<Object?> get props => [scheduleId];
}

class WorkerScheduleCheckTime extends WorkerScheduleEvent {
  const WorkerScheduleCheckTime();
}
