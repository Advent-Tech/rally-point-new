part of 'schedule_bloc.dart';

abstract class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

class ScheduleLoadData extends ScheduleEvent {
  final String teamId;

  const ScheduleLoadData({required this.teamId});

  @override
  List<Object?> get props => [teamId];
}

class ScheduleRefresh extends ScheduleEvent {
  const ScheduleRefresh();
}

class ScheduleSelectDate extends ScheduleEvent {
  final DateTime date;

  const ScheduleSelectDate({required this.date});

  @override
  List<Object?> get props => [date];
}

class ScheduleCreate extends ScheduleEvent {
  final String workerId;
  final String workerName;
  final String? territoryId;
  final String? territoryName;
  final DateTime date;
  final String startTime; // "HH:MM" format
  final String endTime;   // "HH:MM" format
  final String? notes;

  const ScheduleCreate({
    required this.workerId,
    required this.workerName,
    this.territoryId,
    this.territoryName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.notes,
  });

  @override
  List<Object?> get props => [workerId, workerName, territoryId, territoryName, date, startTime, endTime, notes];
}

class ScheduleUpdate extends ScheduleEvent {
  final String scheduleId;
  final String? workerId;
  final String? workerName;
  final String? territoryId;
  final String? territoryName;
  final DateTime? date;
  final String? startTime; // "HH:MM" format
  final String? endTime;   // "HH:MM" format
  final String? status;
  final String? notes;

  const ScheduleUpdate({
    required this.scheduleId,
    this.workerId,
    this.workerName,
    this.territoryId,
    this.territoryName,
    this.date,
    this.startTime,
    this.endTime,
    this.status,
    this.notes,
  });

  @override
  List<Object?> get props => [scheduleId, workerId, workerName, territoryId, territoryName, date, startTime, endTime, status, notes];
}

class ScheduleDelete extends ScheduleEvent {
  final String scheduleId;

  const ScheduleDelete({required this.scheduleId});

  @override
  List<Object?> get props => [scheduleId];
}
