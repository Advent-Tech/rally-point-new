part of 'worker_tracking_bloc.dart';

abstract class WorkerTrackingEvent extends Equatable {
  const WorkerTrackingEvent();

  @override
  List<Object?> get props => [];
}

class WorkerTrackingLoadWorkers extends WorkerTrackingEvent {
  final String teamId;

  const WorkerTrackingLoadWorkers({required this.teamId});

  @override
  List<Object?> get props => [teamId];
}

class WorkerTrackingLoadTrail extends WorkerTrackingEvent {
  final String workerId;
  final String workerName;
  final DateTime? startTime;
  final DateTime? endTime;

  const WorkerTrackingLoadTrail({
    required this.workerId,
    required this.workerName,
    this.startTime,
    this.endTime,
  });

  @override
  List<Object?> get props => [workerId, workerName, startTime, endTime];
}

class WorkerTrackingChangeDate extends WorkerTrackingEvent {
  final DateTime date;

  const WorkerTrackingChangeDate({required this.date});

  @override
  List<Object?> get props => [date];
}

class WorkerTrackingRefreshWorkers extends WorkerTrackingEvent {
  const WorkerTrackingRefreshWorkers();
}
